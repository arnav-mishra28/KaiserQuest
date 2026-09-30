"""
Silver Mountain and the Archivist.

The final region, and the place where the Knowledge Engine stops being a
background system and becomes the antagonist.

Design constraints, all taken from the vision:

  * Access requires the full realm's milestones cleared, not a level.
  * Three attempts per window. Fail all three and you return to your last save
    point with a 24-hour cooldown — but the recap you are sent to is *specific*:
    it names the concepts you failed on and the misconceptions you exhibited,
    and it ends with a drill sequence, not "study more".
  * The exam itself is assembled from the player's own knowledge profile. It is
    not a fixed test: roughly 60% of it is aimed at their weakest concepts, 25%
    at the middle, and 15% at their strongest — because a final exam that never
    asks what you know best is not an examination, it is an ambush.

The Archivist is given a voice rather than a scoreboard: dialogue is generated
from the actual diagnosis, so it can say what it knows.
"""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Sequence, Tuple

from engine.campaign import Campaign, get_campaign
from engine.concepts import ConceptGraph, get_concept_graph
from engine.profile import KnowledgeProfile
from engine.progression import RealmProgress
from engine.tracing import MASTERY_GATE, KnowledgeTracer

logger = logging.getLogger("kaiserquest.engine.silver_mountain")

#: The rules of the summit.
ATTEMPTS_PER_WINDOW = 3
COOLDOWN_HOURS = 24
EXAM_QUESTIONS = 25
EXAM_PASS_RATIO = 0.80

#: How the exam is weighted across the player's own strength profile.
WEAK_SHARE = 0.60
MID_SHARE = 0.25
STRONG_SHARE = 0.15

#: Mastery a concept must exceed for the Archivist to accept the realm as held.
REALM_CLEAR_MASTERY = 75.0


@dataclass
class ExamSlot:
    """One concept the exam will test, with the reason it was chosen."""

    concept: str
    concept_name: str
    difficulty: int
    mastery: float
    band: str        # "weak" | "mid" | "strong"
    reason: str

    def to_dict(self) -> dict:
        return {
            "concept": self.concept,
            "concept_name": self.concept_name,
            "difficulty": self.difficulty,
            "mastery": self.mastery,
            "band": self.band,
            "reason": self.reason,
        }


@dataclass
class ArchivistAttempt:
    number: int
    passed: bool
    ratio: float
    timestamp: float

    def to_dict(self) -> dict:
        return {
            "number": self.number,
            "passed": self.passed,
            "score_percent": round(self.ratio * 100, 1),
            "timestamp": self.timestamp,
        }


@dataclass
class RecapStep:
    """One station of the Mastery Recap the player is sent to after failing."""

    order: int
    kind: str            # "remedy" | "drill" | "concept"
    concept: str
    concept_name: str
    title: str
    body: str
    mastery: float

    def to_dict(self) -> dict:
        return {
            "order": self.order,
            "kind": self.kind,
            "concept": self.concept,
            "concept_name": self.concept_name,
            "title": self.title,
            "body": self.body,
            "mastery": self.mastery,
        }


@dataclass
class SilverMountainState:
    """Persistent state of the summit for one player."""

    realm: str
    attempts_remaining: int = ATTEMPTS_PER_WINDOW
    cooldown_until: float = 0.0
    cleared: bool = False
    cleared_at: float = 0.0
    history: List[ArchivistAttempt] = field(default_factory=list)
    last_recap: List[RecapStep] = field(default_factory=list)

    def refresh(self, now: Optional[float] = None) -> bool:
        """Expire a cooldown and restore the attempts. Returns True if it expired."""
        now = now if now is not None else time.time()
        if self.cooldown_until and now >= self.cooldown_until:
            self.cooldown_until = 0.0
            self.attempts_remaining = ATTEMPTS_PER_WINDOW
            return True
        return False

    def to_dict(self, now: Optional[float] = None) -> dict:
        now = now if now is not None else time.time()
        return {
            "realm": self.realm,
            "attempts_remaining": self.attempts_remaining,
            "cooldown_until": self.cooldown_until,
            "cooldown_remaining_seconds": max(0.0, self.cooldown_until - now) if self.cooldown_until else 0.0,
            "cleared": self.cleared,
            "cleared_at": self.cleared_at,
            "history": [a.to_dict() for a in self.history],
            "recap": [step.to_dict() for step in self.last_recap],
        }

    @classmethod
    def from_dict(cls, data: dict) -> "SilverMountainState":
        return cls(
            realm=data.get("realm", ""),
            attempts_remaining=int(data.get("attempts_remaining", ATTEMPTS_PER_WINDOW)),
            cooldown_until=float(data.get("cooldown_until", 0.0)),
            cleared=bool(data.get("cleared", False)),
            cleared_at=float(data.get("cleared_at", 0.0)),
            history=[
                ArchivistAttempt(
                    number=int(item.get("number", 0)),
                    passed=bool(item.get("passed", False)),
                    ratio=float(item.get("score_percent", 0.0)) / 100.0,
                    timestamp=float(item.get("timestamp", 0.0)),
                )
                for item in (data.get("history") or [])
            ],
            last_recap=[
                RecapStep(
                    order=int(item.get("order", 0)),
                    kind=item.get("kind", "concept"),
                    concept=item.get("concept", ""),
                    concept_name=item.get("concept_name", ""),
                    title=item.get("title", ""),
                    body=item.get("body", ""),
                    mastery=float(item.get("mastery", 0.0)),
                )
                for item in (data.get("recap") or [])
            ],
        )


class SilverMountain:
    """The Archivist's summit: assembly, judgement and the recap."""

    def __init__(self, graph: Optional[ConceptGraph] = None):
        self.graph = graph or get_concept_graph()

    # ------------------------------------------------------------------
    # Who may climb
    # ------------------------------------------------------------------
    def admission(self, campaign: Campaign, progress: RealmProgress, now: Optional[float] = None) -> dict:
        """
        The Archivist examines your record before he examines you.

        Gate: every milestone in the realm cleared. Not a level, not a badge
        count used as a proxy for one — the milestones themselves.
        """
        now = now if now is not None else time.time()
        total = len(campaign.milestones)
        passed = progress.passed_count
        if passed < total:
            missing = [m for m in campaign.milestones if not progress.has_passed(m.index)]
            return {
                "allowed": False,
                "reason": (
                    f"The Archivist does not raise his eyes. 'The realm is not finished. "
                    f"{len(missing)} trial{'s' if len(missing) != 1 else ''} remain.'"
                ),
                "milestones_remaining": [m.index for m in missing],
                "milestones_passed": passed,
                "milestones_total": total,
            }
        return {
            "allowed": True,
            "reason": "The Archivist looks up. 'So you have walked the whole realm.'",
            "milestones_passed": passed,
            "milestones_total": total,
        }

    # ------------------------------------------------------------------
    # Status
    # ------------------------------------------------------------------
    def status(
        self,
        campaign: Campaign,
        progress: RealmProgress,
        state: SilverMountainState,
        now: Optional[float] = None,
    ) -> dict:
        now = now if now is not None else time.time()
        just_reset = state.refresh(now)
        admission = self.admission(campaign, progress, now)

        can_challenge = admission["allowed"] and state.attempts_remaining > 0 and not state.cooldown_until
        if state.cleared:
            can_challenge = admission["allowed"]

        reason = admission["reason"]
        if admission["allowed"]:
            if state.cleared:
                reason = "You have cleared Silver Mountain. The Archivist will still test you, if you wish."
            elif state.cooldown_until:
                hours = max(0.0, state.cooldown_until - now) / 3600.0
                reason = (
                    "The Archivist turns his back. 'Return when you have learned what you failed to learn.' "
                    f"({hours:.1f} hours remain)"
                )
            elif state.attempts_remaining <= 0:
                reason = "No attempts remain in this window."

        return {
            "realm": campaign.realm.id,
            "region": "Silver Mountain",
            "allowed": admission["allowed"],
            "can_challenge": can_challenge,
            "attempts_remaining": state.attempts_remaining,
            "attempts_total": ATTEMPTS_PER_WINDOW,
            "cooldown_until": state.cooldown_until,
            "cooldown_remaining_seconds": max(0.0, state.cooldown_until - now) if state.cooldown_until else 0.0,
            "cooldown_just_expired": just_reset,
            "cleared": state.cleared,
            "reason": reason,
            "milestones_passed": admission["milestones_passed"],
            "milestones_total": admission["milestones_total"],
            "exam": {
                "questions": EXAM_QUESTIONS,
                "pass_ratio": EXAM_PASS_RATIO,
                "required_correct": int(EXAM_QUESTIONS * EXAM_PASS_RATIO + 0.999),
            },
            "history": [a.to_dict() for a in state.history],
        }

    # ------------------------------------------------------------------
    # Exam assembly
    # ------------------------------------------------------------------
    def assemble_exam(self, profile: KnowledgeProfile, realm: str) -> List[ExamSlot]:
        """
        Build the final exam from the player's own profile.

        Weakest concepts take the largest share; the strongest are included on
        purpose. An exam you can pass without ever being asked what you are good
        at is not measuring the realm.
        """
        concepts = [c for c in self.graph.realm(realm).concepts]
        scored: List[Tuple[str, float, int]] = []
        for concept in concepts:
            knowledge = profile.tracer.get(concept.id)
            # Concepts never attempted count as maximally weak: the Archivist
            # will find them, and that is the correct behaviour.
            mastery = knowledge.mastery() if knowledge.attempts else 0.0
            scored.append((concept.id, mastery, concept.level))

        scored.sort(key=lambda item: item[1])
        weak_pool, mid_pool, strong_pool = self._split_bands(scored)

        weak_count = int(round(EXAM_QUESTIONS * WEAK_SHARE))
        mid_count = int(round(EXAM_QUESTIONS * MID_SHARE))
        strong_count = EXAM_QUESTIONS - weak_count - mid_count

        slots: List[ExamSlot] = []
        slots.extend(self._draw(weak_pool, weak_count, "weak", profile))
        slots.extend(self._draw(mid_pool, mid_count, "mid", profile))
        slots.extend(self._draw(strong_pool, strong_count, "strong", profile))

        # Top up from the weakest band if a band was too small to fill its share.
        if len(slots) < EXAM_QUESTIONS:
            already = {slot.concept for slot in slots}
            for concept_id, mastery, level in scored:
                if len(slots) >= EXAM_QUESTIONS:
                    break
                if concept_id in already:
                    continue
                slots.append(self._slot(concept_id, mastery, level, "weak", profile))
        return slots[:EXAM_QUESTIONS]

    def _split_bands(self, scored: List[Tuple[str, float, int]]):
        size = len(scored)
        weak_cut = max(1, int(size * 0.5))
        mid_cut = max(weak_cut + 1, int(size * 0.75))
        return scored[:weak_cut], scored[weak_cut:mid_cut], scored[mid_cut:]

    def _draw(
        self,
        pool: Sequence[Tuple[str, float, int]],
        count: int,
        band: str,
        profile: KnowledgeProfile,
    ) -> List[ExamSlot]:
        if count <= 0 or not pool:
            return []
        ordered = list(pool)
        if band == "strong":
            ordered.sort(key=lambda item: -item[1])
        elif band == "mid":
            ordered.sort(key=lambda item: item[1])
        slots: List[ExamSlot] = []
        index = 0
        while len(slots) < count and ordered:
            concept_id, mastery, level = ordered[index % len(ordered)]
            index += 1
            slots.append(self._slot(concept_id, mastery, level, band, profile))
            if index > count * 3:
                break
        return slots

    def _slot(self, concept_id: str, mastery: float, level: int, band: str, profile: KnowledgeProfile) -> ExamSlot:
        name = self.graph.concept(concept_id).name if self.graph.has_concept(concept_id) else concept_id
        knowledge = profile.tracer.get(concept_id)
        if band == "weak":
            if knowledge.attempts == 0:
                reason = "Never attempted. The Archivist has noticed the gap."
            elif knowledge.is_rusty:
                reason = f"Learned once, then faded — only {knowledge.retention():.0%} retained."
            else:
                reason = "The concept you are least sure of."
        elif band == "mid":
            reason = "Held shakily. One more push would settle it."
        else:
            reason = "Your strongest ground. The Archivist does not skip what you know best."
        # Test just above current level, but never below the concept's own band.
        difficulty = max(level, min(5, level + (1 if mastery >= 80 else 0)))
        return ExamSlot(
            concept=concept_id,
            concept_name=name,
            difficulty=difficulty,
            mastery=round(mastery, 2),
            band=band,
            reason=reason,
        )

    # ------------------------------------------------------------------
    # The challenge
    # ------------------------------------------------------------------
    def record_attempt(
        self,
        state: SilverMountainState,
        passed: bool,
        ratio: float,
        profile: KnowledgeProfile,
        now: Optional[float] = None,
    ) -> dict:
        """
        Apply the outcome of one climb.

        Failing the third attempt closes the mountain for 24 hours and returns a
        personalised recap. Passing clears the story.
        """
        now = now if now is not None else time.time()
        state.refresh(now)

        attempt = ArchivistAttempt(
            number=len(state.history) + 1,
            passed=passed,
            ratio=ratio,
            timestamp=now,
        )
        state.history.append(attempt)

        if passed:
            state.cleared = True
            state.cleared_at = now
            state.last_recap = []
            return {
                "passed": True,
                "cleared": True,
                "attempts_remaining": state.attempts_remaining,
                "cooldown_until": 0.0,
                "archivist": self._victory_lines(profile, ratio),
                "recap": [],
                "score_percent": round(ratio * 100, 1),
            }

        state.attempts_remaining = max(0, state.attempts_remaining - 1)
        recap = self.build_recap(profile)

        if state.attempts_remaining <= 0:
            state.cooldown_until = now + COOLDOWN_HOURS * 3600
            state.last_recap = recap
            return {
                "passed": False,
                "cleared": False,
                "attempts_remaining": 0,
                "cooldown_until": state.cooldown_until,
                "cooldown_hours": COOLDOWN_HOURS,
                "archivist": self._defeat_lines(profile, ratio, final=True),
                "recap": [step.to_dict() for step in recap],
                "score_percent": round(ratio * 100, 1),
                "return_to_save": True,
            }

        state.last_recap = recap
        return {
            "passed": False,
            "cleared": False,
            "attempts_remaining": state.attempts_remaining,
            "cooldown_until": 0.0,
            "archivist": self._defeat_lines(profile, ratio, final=False),
            "recap": [step.to_dict() for step in recap],
            "score_percent": round(ratio * 100, 1),
            "return_to_save": False,
        }

    # ------------------------------------------------------------------
    # The recap
    # ------------------------------------------------------------------
    def build_recap(self, profile: KnowledgeProfile, limit: int = 6) -> List[RecapStep]:
        """
        The personalised Mastery Recap.

        Ordered so the player does the most valuable thing first: named
        misconceptions (there is a specific fix), then the weakest concepts, then
        anything that has visibly decayed. Every step says why it is there.
        """
        steps: List[RecapStep] = []
        order = 1

        for item in profile.misconception_plan(limit=3):
            concept_id = item["concept"] if self.graph.has_concept(item["concept"]) else ""
            concept_name = (
                self.graph.concept(concept_id).name if concept_id else item["name"]
            )
            steps.append(
                RecapStep(
                    order=order,
                    kind="remedy",
                    concept=concept_id,
                    concept_name=concept_name,
                    title=item["name"],
                    body=(
                        f"{item['evidence']} {item['remedy']} "
                        + (f"Then drill: {', '.join(item['drills'])}." if item["drills"] else "")
                    ).strip(),
                    mastery=profile.tracer.mastery(concept_id) if concept_id else 0.0,
                )
            )
            order += 1

        for view in profile.weak_concepts(threshold=65.0, limit=4):
            if any(step.concept == view.id for step in steps):
                continue
            steps.append(
                RecapStep(
                    order=order,
                    kind="concept",
                    concept=view.id,
                    concept_name=view.name,
                    title=f"Rework: {view.name}",
                    body=(
                        f"Mastery {view.mastery:.0f}% across {view.attempts} attempts. "
                        f"The Archivist asked about this and you did not have it. "
                        f"Next time he asks, this is the answer he wants."
                    ),
                    mastery=view.mastery,
                )
            )
            order += 1

        for view in profile.rusty_concepts():
            if len(steps) >= limit or any(step.concept == view.id for step in steps):
                continue
            steps.append(
                RecapStep(
                    order=order,
                    kind="drill",
                    concept=view.id,
                    concept_name=view.name,
                    title=f"Refresh: {view.name}",
                    body=(
                        f"You knew this once — {view.retention:.0%} of it has faded. "
                        f"A short drill restores it; it will be on the next climb."
                    ),
                    mastery=view.mastery,
                )
            )
            order += 1

        if not steps:
            steps.append(
                RecapStep(
                    order=1,
                    kind="drill",
                    concept="",
                    concept_name=profile.realm_id,
                    title="A short drill on the whole realm",
                    body=(
                        "Your knowledge is broadly in place; what failed you at the summit was "
                        "endurance rather than any single gap. Work a mixed set under time."
                    ),
                    mastery=profile.overall_mastery,
                )
            )
        return steps[:limit]

    # ------------------------------------------------------------------
    # The Archivist speaks
    # ------------------------------------------------------------------
    def _victory_lines(self, profile: KnowledgeProfile, ratio: float) -> List[str]:
        return [
            "You have collected knowledge. But knowledge collected is not knowledge mastered.",
            f"You answered {ratio:.0%} of it. You have mastered enough of it.",
            "Then the realm is yours. I have been the Archivist of this summit for a long time, "
            "and I do not say this often: you understand the material.",
            "Go home. Teach someone. That is the last trial, and there is no badge for it.",
        ]

    def _defeat_lines(self, profile: KnowledgeProfile, ratio: float, final: bool) -> List[str]:
        lines = [
            "You have collected knowledge. But knowledge collected is not knowledge mastered.",
            f"You answered {ratio:.0%} of what I asked.",
        ]

        weakest = profile.weak_concepts(threshold=65.0, limit=3)
        if weakest:
            names = ", ".join(view.name for view in weakest)
            lines.append(f"I asked about {names}. You guessed.")
        plan = profile.misconception_plan(limit=2)
        if plan:
            lines.append(f"And you are still doing this: {plan[0]['name'].lower()}.")

        if final:
            lines.append(
                "Three attempts, as promised. Go back to the last place you rested. "
                "Come to the mountain again in a day, and bring the answers with you."
            )
        else:
            lines.append("Again. And this time, think before you answer.")
        return lines


def get_silver_mountain(graph: Optional[ConceptGraph] = None) -> SilverMountain:
    return SilverMountain(graph or get_concept_graph())
