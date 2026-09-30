"""
The Knowledge Profile.

This is the object the vision shows to the player and to the game:

    Algebra
    ├── Variables ........ 94%
    ├── Linear equations . 88%
    ├── Functions ........ 71%
    ├── Graphs ........... 63%
    └── Word problems .... 79%

    Confidence
    ├── Strong ........... 72%
    ├── Moderate ......... 18%
    └── Weak ............. 10%

It is a pure aggregator: it reads a KnowledgeTracer, an AttemptLog and the
concept graph, and derives the roll-ups, buckets and diagnoses the rest of the
game (progression gates, Silver Mountain, the recap) consumes.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List, Optional, Sequence, Tuple

from engine.attempts import AttemptLog
from engine.concepts import ConceptGraph, get_concept_graph
from engine.misconceptions import Detection, MisconceptionDetector, get_misconception_catalog
from engine.tracing import MASTERED_P_KNOWN, STRONG_THRESHOLD, ConceptKnowledge, KnowledgeTracer

#: Below this retention a concept is flagged as actively decaying knowledge.
FORGETTING_RISK_RETENTION = 0.55


@dataclass
class ConceptView:
    """One concept, as the profile presents it."""

    id: str
    name: str
    domain: str
    mastery: float
    confidence: str
    p_known: float
    attempts: int
    accuracy: float
    retention: float
    is_mastered: bool
    is_rusty: bool
    difficulty_ceiling: int

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "domain": self.domain,
            "mastery": self.mastery,
            "confidence": self.confidence,
            "p_known": round(self.p_known, 4),
            "attempts": self.attempts,
            "accuracy": self.accuracy,
            "retention": self.retention,
            "is_mastered": self.is_mastered,
            "is_rusty": self.is_rusty,
            "difficulty_ceiling": self.difficulty_ceiling,
        }


class KnowledgeProfile:
    """Read-only view over a tracer that answers 'what does this player know?'"""

    def __init__(
        self,
        player_id: str,
        realm_id: str,
        tracer: KnowledgeTracer,
        log: Optional[AttemptLog] = None,
        graph: Optional[ConceptGraph] = None,
        detector: Optional[MisconceptionDetector] = None,
    ):
        self.player_id = player_id
        self.realm_id = realm_id
        self.tracer = tracer
        self.log = log or AttemptLog()
        self.graph = graph or tracer.graph or get_concept_graph()
        self.detector = detector or MisconceptionDetector(get_misconception_catalog())

    # ------------------------------------------------------------------
    # Concept-level
    # ------------------------------------------------------------------
    def concept_view(self, concept_id: str) -> ConceptView:
        concept = self.graph.concept(concept_id)
        knowledge = self.tracer.get(concept_id)
        return ConceptView(
            id=concept.id,
            name=concept.name,
            domain=concept.domain,
            mastery=knowledge.mastery(),
            confidence=knowledge.confidence(),
            p_known=knowledge.p_known_now(),
            attempts=knowledge.attempts,
            accuracy=round(knowledge.correct / knowledge.attempts, 4) if knowledge.attempts else 0.0,
            retention=round(knowledge.retention(), 4),
            is_mastered=knowledge.is_mastered,
            is_rusty=knowledge.is_rusty,
            difficulty_ceiling=knowledge.difficulty_ceiling,
        )

    # ------------------------------------------------------------------
    # Domain roll-ups
    # ------------------------------------------------------------------
    def domain_mastery(self) -> List[Tuple[str, str, float]]:
        """(domain_id, domain_name, mastery) for every domain in the realm."""
        rows: List[Tuple[str, str, float]] = []
        for domain in self.graph.realm(self.realm_id).domains:
            rows.append((domain.id, domain.name, self.domain_score(domain.id)))
        return rows

    def domain_score(self, domain_id: str) -> float:
        """
        Mean mastery across every concept in the domain. Unseen concepts count
        as zero on purpose: a domain is only known to the extent you know all
        of it, and it keeps the number comparable between domains.
        """
        concepts = self.graph.concepts_of_domain(domain_id)
        if not concepts:
            return 0.0
        total = sum(self.tracer.get(c.id).mastery() for c in concepts)
        return round(total / len(concepts), 2)

    def domain_view(self, domain_id: str) -> dict:
        domain = self.graph.domain(domain_id)
        return {
            "id": domain.id,
            "name": domain.name,
            "mastery": self.domain_score(domain_id),
            "concepts": [self.concept_view(c.id).to_dict() for c in domain.concepts],
        }

    # ------------------------------------------------------------------
    # Realm-level
    # ------------------------------------------------------------------
    @property
    def overall_mastery(self) -> float:
        return self.tracer.realm_mastery(self.realm_id)

    def confidence_distribution(self) -> Dict[str, int]:
        """
        Percentage of the realm's concepts in each bucket. Untouched concepts
        count as Weak — which is exactly the point of the display: it shrinks as
        you work through the realm.
        """
        concepts = self.graph.realm(self.realm_id).concepts
        if not concepts:
            return {"Strong": 0, "Moderate": 0, "Weak": 0}
        counts = {"Strong": 0, "Moderate": 0, "Weak": 0}
        for concept in concepts:
            counts[self.tracer.get(concept.id).confidence()] += 1
        total = len(concepts)
        # Largest-remainder rounding so the three buckets always total 100.
        exact = {k: 100.0 * v / total for k, v in counts.items()}
        floored = {k: int(v) for k, v in exact.items()}
        remainder = 100 - sum(floored.values())
        for key in sorted(exact, key=lambda k: -(exact[k] - floored[k]))[: max(0, remainder)]:
            floored[key] += 1
        return floored

    def weak_concepts(self, threshold: float = 60.0, limit: int = 10) -> List[ConceptView]:
        """Concepts the player has actually attempted but does not hold."""
        views = [
            self.concept_view(c.id)
            for c in self.graph.realm(self.realm_id).concepts
            if self.tracer.get(c.id).attempts > 0
        ]
        weak = [v for v in views if v.mastery < threshold]
        weak.sort(key=lambda v: (v.mastery, -v.attempts))
        return weak[:limit]

    def strong_concepts(self, limit: int = 10) -> List[ConceptView]:
        views = [
            self.concept_view(c.id)
            for c in self.graph.realm(self.realm_id).concepts
            if self.tracer.get(c.id).attempts > 0
        ]
        strong = [v for v in views if v.mastery >= 80.0]
        strong.sort(key=lambda v: -v.mastery)
        return strong[:limit]

    def rusty_concepts(self) -> List[ConceptView]:
        """Learned properly once, decaying now. The most actionable list here."""
        return [self.concept_view(c.id) for c in self.tracer.rusty_concepts() if self._in_realm(c.id)]

    def forgetting_risk(self, limit: int = 8) -> List[ConceptView]:
        """
        Concepts known but with poor retention — the "what you have forgotten"
        feed. Narrower than rusty: these are still above the mastery bar but
        visibly slipping.
        """
        views = [
            self.concept_view(c.id)
            for c in self.graph.realm(self.realm_id).concepts
            if self.tracer.get(c.id).attempts >= 3
        ]
        at_risk = [
            v for v in views
            if v.p_known >= MASTERED_P_KNOWN and v.retention < FORGETTING_RISK_RETENTION
        ]
        at_risk.sort(key=lambda v: v.retention)
        return at_risk[:limit]

    def next_up(self, limit: int = 5) -> List[dict]:
        """
        What to learn next, with the reason attached. The reason matters: the
        game surfaces it in dialogue ("you're solid on variables — ready for
        one-step equations").
        """
        known = set(self.tracer.known_concepts())
        frontier = [
            self.graph.concept(concept_id)
            for concept_id in self.graph.frontier(known)
            if self._in_realm(concept_id)
        ]
        frontier.sort(key=lambda c: (c.level, c.domain))
        result: List[dict] = []
        for concept in frontier[:limit]:
            result.append(
                {
                    "concept": concept.id,
                    "name": concept.name,
                    "domain": concept.domain,
                    "level": concept.level,
                    "reason": "All prerequisites are mastered — this is ready to teach.",
                }
            )
        if len(result) < limit:
            for concept_id in self.tracer.rusty_concepts():
                if len(result) >= limit or not self._in_realm(concept_id):
                    continue
                if any(r["concept"] == concept_id for r in result):
                    continue
                concept = self.graph.concept(concept_id)
                result.append(
                    {
                        "concept": concept.id,
                        "name": concept.name,
                        "domain": concept.domain,
                        "level": concept.level,
                        "reason": "Learned before but faded — a short recap brings it back.",
                    }
                )
        return result[:limit]

    def misconceptions(self, limit: int = 6) -> List[Detection]:
        pool = [
            a for a in self.log if self._in_realm(a.concept)
        ]
        return self.detector.summarize(AttemptLog(pool), limit=limit)

    def misconception_plan(self, limit: int = 5) -> List[dict]:
        return self.detector.remedy_plan(self.misconceptions(limit=limit))

    def mastery_gate_report(self, concept_ids: Sequence[str], gate: float = 70.0) -> dict:
        """Per-concept pass/fail against a mastery gate, for a milestone."""
        passed, unmet = self.tracer.coverage(concept_ids, gate)
        return {
            "gate": gate,
            "coverage": passed,
            "required": len(list(concept_ids)),
            "unmet": [
                {
                    "concept": c,
                    "name": self.graph.concept(c).name if self.graph.has_concept(c) else c,
                    "mastery": self.tracer.get(c).mastery(),
                }
                for c in unmet
            ],
        }

    # ------------------------------------------------------------------
    # Serialisation
    # ------------------------------------------------------------------
    def to_dict(self) -> dict:
        realm = self.graph.realm(self.realm_id)
        return {
            "player_id": self.player_id,
            "realm": {
                "id": realm.id,
                "name": realm.name,
                "section": realm.section,
                "sigil": realm.sigil,
                "accent": realm.accent,
            },
            "overall_mastery": self.overall_mastery,
            "confidence": self.confidence_distribution(),
            "domains": [self.domain_view(d.id) for d in realm.domains],
            "weak": [v.to_dict() for v in self.weak_concepts()],
            "strong": [v.to_dict() for v in self.strong_concepts()],
            "rusty": [v.to_dict() for v in self.rusty_concepts()],
            "forgetting_risk": [v.to_dict() for v in self.forgetting_risk()],
            "next_up": self.next_up(),
            "misconceptions": [d.to_dict() for d in self.misconceptions()],
            "remedy_plan": self.misconception_plan(),
            "concept_count": len(realm.concepts),
            "attempts": len(self.log),
        }

    def render_ascii(self) -> str:
        """The profile exactly as the vision draws it. Used by the CLI and tests."""
        realm = self.graph.realm(self.realm_id)
        lines: List[str] = [f"{realm.name} — {self.overall_mastery:.0f}% overall", ""]

        rows = self.domain_mastery()
        width = max((len(name) for _, name, _ in rows), default=0)
        for index, (_, name, score) in enumerate(rows):
            branch = "└──" if index == len(rows) - 1 else "├──"
            dots = "." * max(3, width - len(name) + 2)
            lines.append(f"{branch} {name} {dots} {score:5.0f}%")

        lines.append("")
        lines.append("Confidence")
        buckets = self.confidence_distribution()
        for index, (label, value) in enumerate(buckets.items()):
            branch = "└──" if index == len(buckets) - 1 else "├──"
            dots = "." * max(3, 12 - len(label) + 2)
            lines.append(f"{branch} {label} {dots} {value:5d}%")

        rusty = self.rusty_concepts()
        if rusty:
            lines.append("")
            lines.append("Forgotten / fading")
            for view in rusty[:5]:
                lines.append(f"├── {view.name} ({view.mastery:.0f}%, {view.retention:.0%} retained)")

        plan = self.misconception_plan()
        if plan:
            lines.append("")
            lines.append("Named misconceptions")
            for item in plan[:5]:
                lines.append(f"├── {item['name']} — seen {item['occurrences']}×")
                lines.append(f"│     remedy: {item['remedy']}")

        return "\n".join(lines)

    # ------------------------------------------------------------------
    def _in_realm(self, concept_id: str) -> bool:
        if not self.graph.has_concept(concept_id):
            return True
        return self.graph.concept(concept_id).realm == self.realm_id
