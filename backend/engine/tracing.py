"""
Knowledge tracing.

Two estimators stacked on top of each other:

1. Bayesian Knowledge Tracing (Corbett & Anderson, 1995). Each concept carries
   four parameters — prior, learn-rate, guess, slip — and every attempt updates
   P(known). This is the classic, cheap, well-understood model, which is exactly
   what a 2 GB Android device needs. It is deliberately the *first* model: the
   KnowledgeTracer interface is narrow enough that a Deep Knowledge Tracing or
   transformer implementation can be substituted without touching callers.

2. Forgetting. BKT alone never forgets, so a player who mastered fractions in
   April would still be "94% fractions" in September. Kaiser Quest needs the
   opposite, and the vision asks for it explicitly ("what you have forgotten"),
   so P(known) is decayed by an exponential retention curve keyed to the time
   since last practice.

On top of that the engine derives what a game actually needs to act on:
mastery percentage, a confidence bucket (Strong / Moderate / Weak), whether the
estimate is trustworthy yet, and how heavy a given attempt should count.
"""

from __future__ import annotations

import logging
import math
import time
from dataclasses import dataclass, field
from typing import Dict, Iterable, List, Optional, Tuple

from engine.attempts import Attempt, AttemptOutcome
from engine.concepts import ConceptGraph, get_concept_graph

logger = logging.getLogger("kaiserquest.engine.tracing")

# ---------------------------------------------------------------------------
# Tuning constants. These are the knobs a curriculum designer would touch.
# ---------------------------------------------------------------------------

#: Confidence buckets, by decayed P(known) with enough evidence behind them.
STRONG_THRESHOLD = 0.80
MODERATE_THRESHOLD = 0.55

#: Attempts needed before an estimate is trusted at all, before it can be called
#: Moderate, and before it can be called Strong. One answer is never more than
#: Weak, however right it was; six are needed before anything is Strong.
MIN_EVIDENCE = 3
MODERATE_EVIDENCE = 2
STRONG_EVIDENCE = 6

#: Mastery gate for a milestone: the average mastery a milestone's concepts must
#: reach for the milestone to be considered passed even if a run goes badly.
MASTERY_GATE = 70.0

#: What "mastered" means internally (feeding the prereq frontier).
MASTERED_P_KNOWN = 0.80

#: Retention half-life in days, per difficulty band. Harder ideas decay faster
#: because they are held together by more fragile chains of reasoning.
HALF_LIFE_BY_LEVEL = {1: 21.0, 2: 14.0, 3: 10.0, 4: 7.0, 5: 5.0}

#: Retention never quite reaches zero — the trace remembers *something*. A
#: concept mastered long ago settles at this fraction of its peak, which reads
#: as "rusty, needs a recap" rather than "never learned".
RETENTION_FLOOR = 0.15


@dataclass
class BKTParams:
    """Classic four-parameter BKT, with sensible defaults per concept level."""

    p_init: float = 0.25
    p_learn: float = 0.18
    p_guess: float = 0.20
    p_slip: float = 0.10

    @classmethod
    def for_level(cls, level: int) -> "BKTParams":
        """
        Harder concepts start further from known and are learned more slowly in
        a single sitting; they are also guessed less often because they have
        fewer plausible options.
        """
        level = max(1, min(5, int(level)))
        return cls(
            p_init=max(0.08, 0.30 - 0.04 * level),
            p_learn=max(0.10, 0.24 - 0.025 * level),
            p_guess=max(0.10, 0.24 - 0.025 * level),
            p_slip=0.10,
        )

    def to_dict(self) -> dict:
        return {
            "p_init": self.p_init,
            "p_learn": self.p_learn,
            "p_guess": self.p_guess,
            "p_slip": self.p_slip,
        }


def _clamp(value: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return max(lo, min(hi, value))


@dataclass
class ConceptKnowledge:
    """
    The engine's belief about one concept for one player.

    `p_known` is always the *undecayed* belief; decay is applied on read so the
    stored value stays the last thing actually observed.

    `mastery` deliberately reads lower than `p_known` on thin evidence: p_known
    is the estimator's best guess, mastery is a claim the player can act on, and
    a claim should require something to stand on.
    """

    concept_id: str
    params: BKTParams = field(default_factory=BKTParams)
    p_known: float = 0.0
    attempts: int = 0
    correct: int = 0
    hints: int = 0
    fast_errors: int = 0
    last_practiced: float = 0.0
    first_practiced: float = 0.0
    difficulty_ceiling: int = 0
    reference_level: int = 2
    stability: float = 0.0

    def __post_init__(self) -> None:
        if self.p_known == 0.0 and self.attempts == 0:
            self.p_known = self.params.p_init

    # ------------------------------------------------------------------
    # Reading the belief
    # ------------------------------------------------------------------
    @property
    def level(self) -> int:
        """
        The difficulty this concept is normally encountered at.

        The player's demonstrated ceiling once they have one, otherwise the
        level the concept is taught at in the curriculum. Using the curriculum
        level as the reference matters: without it, the very first attempt on a
        concept would have no baseline to be 'harder than', and the difficulty
        adjustment would be inert exactly when a new player meets new material.
        """
        return max(1, min(5, self.difficulty_ceiling or self.reference_level))

    @property
    def half_life_days(self) -> float:
        return HALF_LIFE_BY_LEVEL.get(self.level, 12.0)

    def retention(self, now: Optional[float] = None) -> float:
        """Fraction of the learned memory still available, 0..1."""
        if self.last_practiced <= 0 or self.attempts == 0:
            return 0.0
        now = now if now is not None else time.time()
        days = max(0.0, (now - self.last_practiced) / 86400.0)
        if days <= 0:
            return 1.0
        return 0.5 ** (days / self.half_life_days)

    def p_known_now(self, now: Optional[float] = None) -> float:
        """
        Decayed P(known): what the player can actually still do today.

        Floored so that a long absence degrades a concept to "rusted" rather
        than "never learned" — the recap should say "you've lost the edge on
        this", not "you never knew this".
        """
        if self.attempts == 0:
            return self.params.p_init
        retained = self.p_known * self.retention(now)
        return _clamp(max(retained, self.p_known * RETENTION_FLOOR))

    @property
    def evidence(self) -> float:
        """0..1 confidence in the estimate, driven by how much we have seen."""
        return _clamp(min(self.attempts / 8.0, 1.0) * (1.0 / (1.0 + 2.0 / max(1, self.attempts))))

    def mastery(self, now: Optional[float] = None) -> float:
        """
        Player-facing mastery, 0..100.

        Blends three things a mastery percentage ought to mean: how likely the
        player is to know it *today*, how deep their success goes relative to
        what the curriculum asks of this concept, and whether they proved it
        unaided.

        Depth is measured against the concept's own reference level rather than
        against 5. Otherwise mastering a level-1 idea would be impossible to
        score well on — you cannot answer a 'what is a variable' question at
        difficulty 5 — which would make the early chapters of every realm
        permanently incomplete.
        """
        p = self.p_known_now(now)
        if self.attempts == 0:
            return 0.0
        depth = _clamp(self.difficulty_ceiling / max(1, self.reference_level))
        support = 1.0 - _clamp(self.hints / max(1, self.attempts)) * 0.4
        # Evidence: a mastery figure should not read 100% off a single answer.
        # One correct response is encouraging; it is not mastery, and saying so
        # is the difference between a model the player can trust and one they
        # learn to ignore.
        evidence = 0.45 + 0.55 * _clamp(self.attempts / 4.0)
        return round(100.0 * p * (0.70 + 0.30 * depth) * support * evidence, 2)

    def confidence(self, now: Optional[float] = None) -> str:
        """
        'Strong' | 'Moderate' | 'Weak' — the bucket the profile displays.

        Buckets require evidence, not just probability. A single correct answer
        produces a high P(known) but is a Weak *claim*, and the profile should say
        so: the player will act on this display.
        """
        if self.attempts < MODERATE_EVIDENCE:
            return "Weak"
        p = self.p_known_now(now)
        if p >= STRONG_THRESHOLD and self.attempts >= STRONG_EVIDENCE:
            return "Strong"
        if p >= MODERATE_THRESHOLD:
            return "Moderate"
        return "Weak"

    @property
    def is_mastered(self) -> bool:
        return self.p_known_now() >= MASTERED_P_KNOWN and self.attempts >= MIN_EVIDENCE

    @property
    def is_rusty(self) -> bool:
        """Was learned properly once, but has decayed below the mastery bar."""
        return (
            self.attempts >= STRONG_EVIDENCE
            and self.p_known >= MASTERED_P_KNOWN
            and self.p_known_now() < MASTERED_P_KNOWN
        )

    # ------------------------------------------------------------------
    # Learning from an attempt
    # ------------------------------------------------------------------
    def observe(self, attempt: Attempt, now: Optional[float] = None) -> Tuple[float, float]:
        """
        Fold one attempt into the belief. Returns (p_before, p_after).

        The BKT update is run with *difficulty-adjusted* guess and slip rates:
        getting a question well above your level right is strong evidence (low
        guess rate), and getting an easy one wrong is a weak signal of not
        knowing (high slip rate).
        """
        now = now if now is not None else time.time()
        p_before = self.p_known

        # Decay first: the player arrives having forgotten some of it, and the
        # update must apply to what they actually brought to the question.
        prior = self.p_known_now(now)

        guess, slip = self._effective_rates(attempt)
        if attempt.correct:
            numerator = prior * (1.0 - slip)
            denominator = numerator + (1.0 - prior) * guess
        else:
            numerator = prior * slip
            denominator = numerator + (1.0 - prior) * (1.0 - guess)
        posterior = numerator / denominator if denominator > 0 else prior

        # Learning opportunity, scaled by how much attention the attempt got.
        weight = attempt.evidence_weight
        learn = self.params.p_learn * weight
        if attempt.correct:
            updated = posterior + (1.0 - posterior) * learn
        else:
            # A wrong answer is not a learning event, but re-reading it is: a
            # small amount of learning leaks in from the corrected feedback.
            updated = posterior + (1.0 - posterior) * learn * 0.35

        # Hints make a "correct" much weaker evidence of knowing.
        if attempt.is_helped:
            updated = posterior + (updated - posterior) * 0.5

        self.p_known = _clamp(updated)
        self.attempts += 1
        self.hints += attempt.hints_used
        if attempt.correct:
            self.correct += 1
            self.difficulty_ceiling = max(self.difficulty_ceiling, attempt.difficulty)
        if attempt.is_fast_error:
            self.fast_errors += 1
        self.first_practiced = self.first_practiced or now
        self.last_practiced = now

        # Stability: how long this belief has held together across sessions. A
        # concept hit correctly across many separated days is *owned*.
        span_days = max(0.0, (self.last_practiced - self.first_practiced) / 86400.0)
        self.stability = _clamp(min(span_days / 14.0, 1.0))
        return p_before, self.p_known

    def _effective_rates(self, attempt: Attempt) -> Tuple[float, float]:
        """Difficulty- and behaviour-adjusted (guess, slip) for one attempt."""
        concept_level = self.difficulty_ceiling or self.reference_level
        gap = attempt.difficulty - concept_level  # >0 means harder than usual
        guess = _clamp(self.params.p_guess * (1.0 - 0.13 * gap), 0.02, 0.6)
        slip = _clamp(self.params.p_slip * (1.0 + 0.13 * gap), 0.02, 0.6)
        guess = _clamp(guess + 0.05 * attempt.hints_used, 0.02, 0.7)
        if attempt.tries > 1:
            guess = _clamp(guess + 0.04, 0.02, 0.7)
        if attempt.is_fast_error:
            slip = _clamp(slip * 1.5, 0.02, 0.75)
        return guess, slip

    def to_dict(self, now: Optional[float] = None) -> dict:
        # p_known is stored at full precision: it is estimator state, not a
        # display value, and rounding it would make every save/load cycle shift
        # the estimate slightly.
        return {
            "concept": self.concept_id,
            "p_known": self.p_known,
            "p_known_now": self.p_known_now(now),
            "mastery": self.mastery(now),
            "confidence": self.confidence(now),
            "attempts": self.attempts,
            "correct": self.correct,
            "accuracy": round(self.correct / self.attempts, 4) if self.attempts else 0.0,
            "hints": self.hints,
            "fast_errors": self.fast_errors,
            "difficulty_ceiling": self.difficulty_ceiling,
            "reference_level": self.reference_level,
            "retention": round(self.retention(now), 4),
            "stability": round(self.stability, 4),
            "is_mastered": self.is_mastered,
            "is_rusty": self.is_rusty,
            "last_practiced": self.last_practiced,
            "params": self.params.to_dict(),
        }

    @classmethod
    def from_dict(cls, data: dict) -> "ConceptKnowledge":
        params = data.get("params") or {}
        knowledge = cls(
            concept_id=data["concept"],
            params=BKTParams(
                p_init=params.get("p_init", 0.25),
                p_learn=params.get("p_learn", 0.18),
                p_guess=params.get("p_guess", 0.20),
                p_slip=params.get("p_slip", 0.10),
            ),
            p_known=float(data.get("p_known", 0.0)),
            attempts=int(data.get("attempts", 0)),
            correct=int(data.get("correct", 0)),
            hints=int(data.get("hints", 0)),
            fast_errors=int(data.get("fast_errors", 0)),
            last_practiced=float(data.get("last_practiced", 0.0)),
            first_practiced=float(data.get("first_practiced", 0.0)),
            difficulty_ceiling=int(data.get("difficulty_ceiling", 0)),
            reference_level=int(data.get("reference_level", 2)),
            stability=float(data.get("stability", 0.0)),
        )
        return knowledge


class KnowledgeTracer:
    """
    Per-player knowledge state across every concept of a realm.

    Also acts as the "player model" half of the learner record: the attempt log
    and the belief state are kept together because neither is useful alone.
    """

    def __init__(
        self,
        player_id: str,
        graph: Optional[ConceptGraph] = None,
        knowledge: Optional[Dict[str, ConceptKnowledge]] = None,
    ):
        self.player_id = player_id
        self.graph = graph or get_concept_graph()
        self._knowledge: Dict[str, ConceptKnowledge] = dict(knowledge or {})

    # ------------------------------------------------------------------
    # Access
    # ------------------------------------------------------------------
    @property
    def concepts(self) -> Dict[str, ConceptKnowledge]:
        return self._knowledge

    def get(self, concept_id: str) -> ConceptKnowledge:
        """Look up knowledge state, creating a fresh (prior-only) one if new."""
        existing = self._knowledge.get(concept_id)
        if existing:
            return existing
        try:
            concept = self.graph.concept(concept_id)
        except KeyError:
            # Unknown concepts are still tracked: the graph is the curriculum,
            # not a cage, and the content pipeline may tag things ahead of it.
            concept = None
        level = concept.level if concept else 2
        created = ConceptKnowledge(
            concept_id=concept_id,
            params=BKTParams.for_level(level),
            reference_level=level,
        )
        self._knowledge[concept_id] = created
        return created

    def p_known(self, concept_id: str, decayed: bool = True) -> float:
        knowledge = self.get(concept_id)
        return knowledge.p_known_now() if decayed else knowledge.p_known

    def mastery(self, concept_id: str) -> float:
        return self.get(concept_id).mastery()

    def confidence(self, concept_id: str) -> str:
        return self.get(concept_id).confidence()

    # ------------------------------------------------------------------
    # Learning
    # ------------------------------------------------------------------
    def observe(self, attempt: Attempt, now: Optional[float] = None) -> AttemptOutcome:
        knowledge = self.get(attempt.concept)
        mastery_before = knowledge.mastery(now)
        confidence_before = knowledge.confidence(now)
        p_before, p_after = knowledge.observe(attempt, now=now)
        return AttemptOutcome(
            concept=attempt.concept,
            correct=attempt.correct,
            p_known_before=p_before,
            p_known_after=p_after,
            mastery_before=mastery_before,
            mastery_after=knowledge.mastery(now),
            confidence_before=confidence_before,
            confidence_after=knowledge.confidence(now),
            is_fast_error=attempt.is_fast_error,
        )

    # ------------------------------------------------------------------
    # Whole-realm views
    # ------------------------------------------------------------------
    def known_concepts(self, threshold: float = MASTERED_P_KNOWN) -> List[str]:
        return [c.concept_id for c in self._knowledge.values() if c.p_known_now() >= threshold]

    def mastered_concepts(self) -> List[str]:
        return [c.concept_id for c in self._knowledge.values() if c.is_mastered]

    def rusty_concepts(self) -> List[str]:
        return [c.concept_id for c in self._knowledge.values() if c.is_rusty]

    def weakest(self, realm_id: Optional[str] = None, limit: int = 10, min_attempts: int = 1) -> List[Tuple[str, float]]:
        """(concept, mastery) pairs, weakest first, restricted to a realm."""
        pairs: List[Tuple[str, float]] = []
        for concept_id, knowledge in self._knowledge.items():
            if realm_id and not self._in_realm(concept_id, realm_id):
                continue
            if knowledge.attempts < min_attempts:
                continue
            pairs.append((concept_id, knowledge.mastery()))
        pairs.sort(key=lambda pair: pair[1])
        return pairs[:limit]

    def strongest(self, realm_id: Optional[str] = None, limit: int = 10) -> List[Tuple[str, float]]:
        pairs: List[Tuple[str, float]] = []
        for concept_id, knowledge in self._knowledge.items():
            if realm_id and not self._in_realm(concept_id, realm_id):
                continue
            if knowledge.attempts == 0:
                continue
            pairs.append((concept_id, knowledge.mastery()))
        pairs.sort(key=lambda pair: -pair[1])
        return pairs[:limit]

    def frontier(self, realm_id: Optional[str] = None) -> List[str]:
        known = set(self.known_concepts())
        frontier = self.graph.frontier(known)
        if realm_id:
            frontier = [c for c in frontier if self._in_realm(c, realm_id)]
        return frontier

    def suggested_next(self, realm_id: Optional[str] = None, limit: int = 5) -> List[str]:
        """
        What to teach next.

        Frontier concepts first (prereqs satisfied), then rusty concepts that
        used to be solid — because forgetting is the most actionable thing the
        engine knows about.
        """
        suggestions: List[str] = []
        for concept_id in self.rusty_concepts():
            if realm_id and not self._in_realm(concept_id, realm_id):
                continue
            suggestions.append(concept_id)
        for concept_id in self.frontier(realm_id):
            if concept_id not in suggestions:
                suggestions.append(concept_id)
        return suggestions[:limit]

    def _in_realm(self, concept_id: str, realm_id: str) -> bool:
        if not self.graph.has_concept(concept_id):
            return True
        return self.graph.concept(concept_id).realm == realm_id

    def realm_mastery(self, realm_id: str) -> float:
        """
        Mean mastery across the realm's *entire* concept list, unsampled
        concepts counting as zero. This is the honest number: it measures how
        much of the realm you know, not how well you did on what you happened
        to attempt.
        """
        concepts = self.graph.realm(realm_id).concepts
        if not concepts:
            return 0.0
        total = sum(self.get(c.id).mastery() for c in concepts)
        return round(total / len(concepts), 2)

    # ------------------------------------------------------------------
    # Serialisation
    # ------------------------------------------------------------------
    def to_dict(self) -> dict:
        return {
            "player_id": self.player_id,
            "knowledge": {cid: k.to_dict() for cid, k in self._knowledge.items()},
        }

    @classmethod
    def from_dict(cls, data: dict, graph: Optional[ConceptGraph] = None) -> "KnowledgeTracer":
        knowledge = {
            cid: ConceptKnowledge.from_dict(payload)
            for cid, payload in (data.get("knowledge") or {}).items()
        }
        return cls(
            player_id=data.get("player_id", ""),
            graph=graph or get_concept_graph(),
            knowledge=knowledge,
        )

    # ------------------------------------------------------------------
    # Introspection helper: is the mastery gate satisfied for a concept set?
    # ------------------------------------------------------------------
    def coverage(self, concept_ids: Iterable[str], gate: float = MASTERY_GATE) -> Tuple[float, List[str]]:
        """
        Fraction of `concept_ids` at or above `gate` mastery, plus the ones that
        are not. This is the primitive every progression gate is built from.
        """
        ids = [c for c in concept_ids]
        if not ids:
            return 1.0, []
        passed = [c for c in ids if self.get(c).mastery() >= gate]
        unmet = [c for c in ids if c not in passed]
        return round(len(passed) / len(ids), 4), unmet
