"""
Progression.

The v0.1 game gated its gyms on player level: ``requiredLevel = gymIndex * 5``.
That is the design the vision rejects, and it is worth being explicit about why.
A level gate says "you have spent enough time here". A mastery gate says "you
understand this". The first is satisfied by grinding; the second cannot be.

So progression is derived entirely from the knowledge trace:      * You may enter milestone N when you have *passed* N-1 and you still hold
        the concepts N-1 taught.
      * You pass a milestone by meeting its trial's required score *and* by
        actually holding the concepts that milestone teaches.

Two properties of that design are worth stating, because the obvious versions
of both are wrong.

**The entry check is local, not cumulative.** Requiring mastery of everything
ever taught would collide head-on with the forgetting mechanic: concepts decay,
so a player who took a fortnight off would be locked out by chapter three. By
checking only the milestone just completed, holding everything becomes enforced
*transitively* — you could not have reached N-1 without holding N-2 — while the
remedy for a lapse is always a single milestone's worth of review.

**The gate is reachable within the trial.** A gate of 80% cannot be cleared with
two questions on a concept; the trial therefore guarantees enough questions on
the concepts it introduces to make its own gate attainable. A gate the trial
cannot satisfy is not a standard, it is a bug.
"""

from __future__ import annotations

import logging
import time
from dataclasses import dataclass, field
from typing import Callable, Dict, Iterable, List, Optional, Sequence, Tuple

from engine.campaign import Campaign, Milestone, get_campaign
from engine.concepts import ConceptGraph, get_concept_graph
from engine.profile import KnowledgeProfile
from engine.tracing import MASTERY_GATE, KnowledgeTracer

logger = logging.getLogger("kaiserquest.engine.progression")

#: Correct answers scored on a trial attempt.
@dataclass
class TrialResult:
    milestone_index: int
    correct: int
    total: int
    duration_seconds: float = 0.0
    hints_used: int = 0
    concepts_attempted: Tuple[str, ...] = ()
    timestamp: float = field(default_factory=time.time)

    @property
    def ratio(self) -> float:
        return self.correct / self.total if self.total else 0.0

    @property
    def score_percent(self) -> float:
        return round(100.0 * self.ratio, 1)

    def to_dict(self) -> dict:
        return {
            "milestone_index": self.milestone_index,
            "correct": self.correct,
            "total": self.total,
            "score_percent": self.score_percent,
            "duration_seconds": round(self.duration_seconds, 1),
            "hints_used": self.hints_used,
            "timestamp": self.timestamp,
        }


@dataclass
class MilestoneOutcome:
    """The full verdict on a trial attempt."""

    milestone_index: int
    passed: bool
    score_percent: float
    required_percent: float
    mastery_report: dict
    blocked_by: List[str]
    feedback: str
    unlocked: Optional[int] = None
    badge: Optional[str] = None

    @property
    def failed_on_mastery(self) -> bool:
        """Scored enough, but does not actually know it. The instructive case."""
        return (not self.passed) and self.score_percent >= self.required_percent

    def to_dict(self) -> dict:
        return {
            "milestone_index": self.milestone_index,
            "passed": self.passed,
            "score_percent": self.score_percent,
            "required_percent": self.required_percent,
            "mastery_report": self.mastery_report,
            "blocked_by": self.blocked_by,
            "feedback": self.feedback,
            "unlocked": self.unlocked,
            "badge": self.badge,
            "failed_on_mastery": self.failed_on_mastery,
        }


@dataclass
class RealmProgress:
    """How far a player has got in one realm."""

    realm: str
    passed: List[int] = field(default_factory=list)
    attempts: Dict[int, int] = field(default_factory=dict)
    best_score: Dict[int, float] = field(default_factory=dict)
    badges: List[str] = field(default_factory=list)
    last_save_index: int = 1
    completed: bool = False

    @property
    def passed_count(self) -> int:
        return len(self.passed)

    def has_passed(self, index: int) -> bool:
        return index in self.passed

    def record_attempt(self, index: int, score: float) -> None:
        self.attempts[index] = self.attempts.get(index, 0) + 1
        self.best_score[index] = max(self.best_score.get(index, 0.0), score)

    def mark_passed(self, index: int, badge: str) -> None:
        if index not in self.passed:
            self.passed.append(index)
            self.passed.sort()
        if badge not in self.badges:
            self.badges.append(badge)

    def to_dict(self) -> dict:
        return {
            "realm": self.realm,
            "passed": list(self.passed),
            "passed_count": self.passed_count,
            "attempts": {str(k): v for k, v in sorted(self.attempts.items())},
            "best_score": {str(k): v for k, v in sorted(self.best_score.items())},
            "badges": list(self.badges),
            "last_save_index": self.last_save_index,
            "completed": self.completed,
        }

    @classmethod
    def from_dict(cls, data: dict) -> "RealmProgress":
        return cls(
            realm=data.get("realm", ""),
            passed=[int(i) for i in data.get("passed", [])],
            attempts={int(k): int(v) for k, v in (data.get("attempts") or {}).items()},
            best_score={int(k): float(v) for k, v in (data.get("best_score") or {}).items()},
            badges=list(data.get("badges", [])),
            last_save_index=int(data.get("last_save_index", 1)),
            completed=bool(data.get("completed", False)),
        )


class ProgressionService:
    """Reads knowledge, decides what the player has earned access to."""

    #: Fraction of the previous milestone's concepts that must be held to enter
    #: the next one. Half, not all: one shaky idea is a recap, not a wall.
    ENTRY_COVERAGE = 0.5

    #: Fraction of a milestone's own concepts that must reach its gate to pass.
    PASS_COVERAGE = 0.5

    def __init__(
        self,
        graph: Optional[ConceptGraph] = None,
        coverage_lookup: Optional[Callable[[str], int]] = None,
        minimum_bank_coverage: int = 2,
    ):
        self.graph = graph or get_concept_graph()
        # A concept the question bank cannot examine is a content gap, not a
        # player failure. Without this, a thin concept would make its milestone
        # unpassable and the campaign unfinishable.
        self._coverage_lookup = coverage_lookup or (lambda concept_id: minimum_bank_coverage)
        self._minimum_bank_coverage = minimum_bank_coverage

    def gradeable(self, concept_ids: Iterable[str]) -> List[str]:
        """The concepts among `concept_ids` the bank can actually test."""
        return [c for c in concept_ids if self._coverage_lookup(c) >= self._minimum_bank_coverage]

    # ------------------------------------------------------------------
    # Admission
    # ------------------------------------------------------------------
    def entry_requirement(self, campaign: Campaign, milestone: Milestone, progress: RealmProgress) -> dict:
        """
        Everything standing between the player and this milestone.

        Returned as structured data rather than a bool so the NPC can say the
        actual reason out loud — "you may not enter until Proportions is solid"
        — instead of showing a padlock.
        """
        reasons: List[str] = []

        if milestone.index == 1:
            return {"allowed": True, "reasons": [], "concepts": [], "gate": 0.0}

        previous_index = milestone.index - 1
        if not progress.has_passed(previous_index):
            previous = campaign.milestone(previous_index)
            reasons.append(
                f"You have not yet cleared {previous.name}, and {milestone.keeper} will not open the way."
            )

        previous = campaign.milestone(previous_index)
        return {
            "allowed": not reasons,
            "reasons": reasons,
            "concepts": self.gradeable(previous.concepts),
            "gate": self.entry_gate_for(previous),
        }

    @staticmethod
    def entry_gate_for(previous: Milestone) -> float:
        """
        Holding what you were just taught is checked slightly more leniently than
        mastering it in the moment: the point of the entry gate is to stop a
        player walking into new material on top of material they have lost.
        """
        return max(35.0, previous.mastery_gate - 10.0)

    def entry_check(
        self,
        campaign: Campaign,
        milestone: Milestone,
        progress: RealmProgress,
        tracer: KnowledgeTracer,
    ) -> dict:
        """Entry requirement plus how much mastery the player actually has."""
        requirement = self.entry_requirement(campaign, milestone, progress)
        concepts = requirement["concepts"]
        gate = requirement["gate"]
        coverage, unmet = tracer.coverage(concepts, gate)
        holds_enough = (not concepts) or coverage >= self.ENTRY_COVERAGE
        detail = {
            "allowed": requirement["allowed"] and holds_enough,
            "reasons": list(requirement["reasons"]),
            "coverage": coverage,
            "gate": gate,
            "concepts": list(concepts),
            "unmet": [
                {
                    "concept": c,
                    "name": self.graph.concept(c).name if self.graph.has_concept(c) else c,
                    "mastery": tracer.mastery(c),
                }
                for c in unmet
            ],
        }
        if requirement["allowed"] and not holds_enough:
            detail["reasons"].append(
                "What you were just taught has faded below the standard needed to build on it. "
                f"{milestone.keeper} sends you back to review it."
            )
        return detail

    # ------------------------------------------------------------------
    # Outcomes
    # ------------------------------------------------------------------
    def evaluate(
        self,
        campaign: Campaign,
        milestone: Milestone,
        result: TrialResult,
        progress: RealmProgress,
        tracer: KnowledgeTracer,
        concepts_evaluated: Optional[Sequence[str]] = None,
    ) -> MilestoneOutcome:
        """
        Judge a trial attempt on two independent axes: the score, and whether the
        player actually knows the material.
        """
        required = milestone.mode.pass_ratio * 100.0
        # Judge the player on the concepts this milestone teaches that the bank
        # can actually examine.
        # None means "work it out from the milestone"; an empty list means
        # "nothing was examinable, so do not gate on mastery at all".
        gated = (
            self.gradeable(milestone.concepts)
            if concepts_evaluated is None
            else list(concepts_evaluated)
        )
        mastery_report = tracer.coverage(list(gated), milestone.mastery_gate)
        coverage, unmet = mastery_report

        scored_enough = result.ratio >= milestone.mode.pass_ratio
        knows_enough = (not gated) or coverage >= self.PASS_COVERAGE

        blocked_by = [
            {
                "concept": c,
                "name": self.graph.concept(c).name if self.graph.has_concept(c) else c,
                "mastery": tracer.mastery(c),
            }
            for c in unmet
        ]

        if scored_enough and knows_enough:
            already = progress.has_passed(milestone.index)
            progress.mark_passed(milestone.index, milestone.badge_name)
            next_index = milestone.index + 1 if milestone.index < len(campaign.milestones) else None
            if next_index:
                progress.last_save_index = max(progress.last_save_index, next_index)
            else:
                progress.completed = True
            feedback = milestone.success
            if already:
                feedback = "You have already earned this sigil. " + feedback
            return MilestoneOutcome(
                milestone_index=milestone.index,
                passed=True,
                score_percent=result.score_percent,
                required_percent=required,
                mastery_report=self._mastery_dict(mastery_report),
                blocked_by=[],
                feedback=feedback,
                unlocked=next_index,
                badge=milestone.badge_name,
            )

        if scored_enough and not knows_enough:
            feedback = (
                f"The score was enough, but {milestone.keeper} is not satisfied. "
                "You reached the right answers without holding the ideas underneath them. "
                "That is not mastery, and it will not carry you further."
            )
        else:
            feedback = milestone.failure

        return MilestoneOutcome(
            milestone_index=milestone.index,
            passed=False,
            score_percent=result.score_percent,
            required_percent=required,
            mastery_report=self._mastery_dict(mastery_report),
            blocked_by=blocked_by,
            feedback=feedback,
            unlocked=None,
            badge=None,
        )

    def _mastery_dict(self, report: Tuple[float, List[str]]) -> dict:
        coverage, unmet = report
        return {
            "coverage": coverage,
            "unmet": [
                {
                    "concept": c,
                    "name": self.graph.concept(c).name if self.graph.has_concept(c) else c,
                }
                for c in unmet
            ],
        }

    # ------------------------------------------------------------------
    # Status
    # ------------------------------------------------------------------
    def status(self, campaign: Campaign, progress: RealmProgress, tracer: KnowledgeTracer) -> dict:
        milestones = campaign.milestones
        passed = set(progress.passed)
        current = campaign.first_unpassed(progress.passed)

        entries: List[dict] = []
        for milestone in milestones:
            if milestone.index in passed:
                state = "cleared"
            elif milestone.index == current.index:
                entry = self.entry_check(campaign, milestone, progress, tracer)
                state = "available" if entry["allowed"] else "locked"
            else:
                state = "locked"
            entries.append(
                {
                    "index": milestone.index,
                    "id": milestone.id,
                    "name": milestone.name,
                    "kind": milestone.kind,
                    "mode": milestone.mode.id,
                    "state": state,
                    "score": progress.best_score.get(milestone.index),
                    "attempts": progress.attempts.get(milestone.index, 0),
                }
            )

        return {
            "realm": campaign.realm.id,
            "region": campaign.flavor.region,
            "current": {
                "index": current.index,
                "id": current.id,
                "name": current.name,
                "place": current.place,
                "keeper": current.keeper,
                "setup": current.setup,
                "trial": current.mode.to_dict(),
                "concepts": [
                    {
                        "id": c,
                        "name": self.graph.concept(c).name if self.graph.has_concept(c) else c,
                        "mastery": tracer.mastery(c),
                    }
                    for c in current.concepts
                ],
            },
            "passed_count": progress.passed_count,
            "total": len(milestones),
            "badges": list(progress.badges),
            "completed": progress.completed,
            "milestones": entries,
        }
