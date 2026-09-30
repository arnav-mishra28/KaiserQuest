"""
Misconception detection.

A misconception is a coherent rule the learner is applying that happens to be
wrong — "I expanded 3(x+4) and only multiplied the 3 into the x" is a rule, not
noise. The vision calls this out explicitly, and it is the single highest-value
thing an educational game can know, because it turns a wrong answer into a
*specific* next lesson instead of "study harder".

Two detection paths, deliberately layered:

1. Exact. Pipeline-generated questions carry a distractor -> misconception map,
   because the generator that built the wrong option knows exactly which broken
   rule produces it. This path is certain (confidence 1.0).

2. Statistical. Behavioural fingerprints over the attempt history that hold for
   any content, hand-written or generated: rushing, chance-level guessing, and
   repeatedly landing on the same wrong answer.

The detections are advisory: the engine never blocks on them, it queues them.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence

from engine.attempts import Attempt, AttemptLog

logger = logging.getLogger("kaiserquest.engine.misconceptions")

DATA_PATH = Path(__file__).resolve().parent.parent / "data" / "knowledge" / "misconceptions.json"

#: Detection ids for behavioural (not content) patterns.
RUSHING = "gen.rushing_unread_question"
GUESSING = "gen.guessing_under_uncertainty"

#: A behavioural pattern must be seen at least this many times to be reported.
MIN_PATTERN_OCCURRENCES = 3


@dataclass(frozen=True)
class Misconception:
    id: str
    name: str
    concept: str
    pattern: str
    remedy: str
    drills: Sequence[str] = ()
    severity: int = 3

    @property
    def is_general(self) -> bool:
        """Behavioural rather than content-specific ('*' matches any concept)."""
        return self.concept == "*"

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "name": self.name,
            "concept": self.concept,
            "pattern": self.pattern,
            "remedy": self.remedy,
            "drills": list(self.drills),
            "severity": self.severity,
        }


@dataclass
class Detection:
    """A believed misconception, with how sure the engine is and why."""

    misconception_id: str
    concept: str
    confidence: float
    occurrences: int
    evidence: str

    @property
    def is_certain(self) -> bool:
        return self.confidence >= 0.95

    def to_dict(self) -> dict:
        return {
            "misconception_id": self.misconception_id,
            "concept": self.concept,
            "confidence": round(self.confidence, 3),
            "occurrences": self.occurrences,
            "evidence": self.evidence,
        }


class MisconceptionCatalog:
    def __init__(self, items: Iterable[Misconception]):
        self._items: Dict[str, Misconception] = {m.id: m for m in items}
        self._by_concept: Dict[str, List[Misconception]] = {}
        for misconception in self._items.values():
            self._by_concept.setdefault(misconception.concept, []).append(misconception)

    @classmethod
    def from_file(cls, path: Optional[Path] = None) -> "MisconceptionCatalog":
        path = path or DATA_PATH
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
        items = [
            Misconception(
                id=raw["id"],
                name=raw["name"],
                concept=raw.get("concept", "*"),
                pattern=raw.get("pattern", ""),
                remedy=raw.get("remedy", ""),
                drills=tuple(raw.get("drills", [])),
                severity=int(raw.get("severity", 3)),
            )
            for raw in data.get("misconceptions", [])
        ]
        return cls(items)

    def __len__(self) -> int:
        return len(self._items)

    def __iter__(self):
        return iter(self._items.values())

    def get(self, misconception_id: str) -> Optional[Misconception]:
        return self._items.get(misconception_id)

    def require(self, misconception_id: str) -> Misconception:
        found = self.get(misconception_id)
        if found is None:
            raise KeyError(f"Unknown misconception '{misconception_id}'")
        return found

    def __contains__(self, misconception_id: object) -> bool:
        return misconception_id in self._items

    def all(self) -> List[Misconception]:
        return list(self._items.values())

    def for_concept(self, concept_id: str) -> List[Misconception]:
        return list(self._by_concept.get(concept_id, []))

    def ids(self) -> List[str]:
        return list(self._items.keys())


class MisconceptionDetector:
    """Turns attempts into named, actionable misconceptions."""

    def __init__(self, catalog: Optional[MisconceptionCatalog] = None):
        self.catalog = catalog or get_misconception_catalog()

    # ------------------------------------------------------------------
    # Per-attempt detection
    # ------------------------------------------------------------------
    def detect(
        self,
        attempt: Attempt,
        log: AttemptLog,
        question: Optional[dict] = None,
    ) -> List[Detection]:
        """
        Detections justified by this attempt plus the history behind it.

        Called after every answer, so it stays cheap: the exact path is a dict
        lookup and the behavioural paths are O(attempts on this concept).
        """
        detections: List[Detection] = []

        exact = self._detect_exact(attempt, log, question)
        if exact:
            detections.append(exact)

        rushing = self._detect_rushing(attempt, log)
        if rushing:
            detections.append(rushing)

        guessing = self._detect_guessing(attempt, log)
        if guessing:
            detections.append(guessing)

        repeated = self._detect_repeated_distractor(attempt, log)
        if repeated:
            detections.append(repeated)

        return detections

    def _detect_exact(
        self, attempt: Attempt, log: AttemptLog, question: Optional[dict]
    ) -> Optional[Detection]:
        """
        The generator told us which distractor encodes which broken rule.
        """
        if attempt.correct:
            return None
        mapping: Dict[str, str] = {}
        if question:
            mapping = question.get("misconceptions") or {}
        if attempt.misconception_id and attempt.misconception_id in self.catalog:
            mapping = {str(attempt.chosen): attempt.misconception_id}
        if not mapping or attempt.chosen is None:
            return None
        misconception_id = mapping.get(str(attempt.chosen))
        if not misconception_id or misconception_id not in self.catalog:
            return None
        occurrences = 1 + sum(
            1 for a in log.for_concept(attempt.concept) if a.misconception_id == misconception_id
        )
        return Detection(
            misconception_id=misconception_id,
            concept=attempt.concept,
            confidence=1.0,
            occurrences=occurrences,
            evidence=f"Chose the distractor that encodes this rule on {attempt.question_id}.",
        )

    def _detect_rushing(self, attempt: Attempt, log: AttemptLog) -> Optional[Detection]:
        """
        Repeated very-fast wrong answers. Deliberately concept-agnostic: it is
        one habit, so it is reported once against the concept it surfaced on and
        remedies point at pacing, not content.
        """
        if not attempt.is_fast_error:
            return None
        fast = [a for a in log.fast_errors(attempt.concept)]
        if len(fast) < MIN_PATTERN_OCCURRENCES:
            return None
        return Detection(
            misconception_id=RUSHING,
            concept=attempt.concept,
            confidence=min(0.9, 0.3 + 0.12 * len(fast)),
            occurrences=len(fast),
            evidence=(
                f"{len(fast)} answers on this concept were wrong in under "
                f"{int(attempt.time_ratio * 100)}% of the time it takes to read the question."
            ),
        )

    def _detect_guessing(self, attempt: Attempt, log: AttemptLog) -> Optional[Detection]:
        if attempt.correct or not log.guess_like(attempt.concept):
            return None
        return Detection(
            misconception_id=GUESSING,
            concept=attempt.concept,
            confidence=0.7,
            occurrences=len(log.for_concept(attempt.concept)),
            evidence=(
                f"Accuracy is at chance level ({log.accuracy(attempt.concept):.0%}) while "
                f"answers come at {log.median_time_ratio(attempt.concept):.0%} of expected reading time."
            ),
        )

    def _detect_repeated_distractor(self, attempt: Attempt, log: AttemptLog) -> Optional[Detection]:
        """
        The same wrong answer chosen twice or more. Even without a tagged
        distractor this is strong evidence of one consistent broken rule, so it
        is surfaced as a concept-local pattern for a human (or an LLM) to name.
        """
        if attempt.correct or not attempt.chosen:
            return None
        repeated = log.repeated_choices(attempt.concept, minimum=2)
        count = repeated.get(attempt.chosen, 0)
        if count < 2:
            return None
        return Detection(
            misconception_id="",
            concept=attempt.concept,
            confidence=min(0.75, 0.35 + 0.1 * count),
            occurrences=count,
            evidence=f"Chose '{attempt.chosen}' as a wrong answer {count} times on this concept.",
        )

    # ------------------------------------------------------------------
    # History-wide roll-up
    # ------------------------------------------------------------------
    def summarize(self, log: AttemptLog, concept: Optional[str] = None, limit: int = 5) -> List[Detection]:
        """
        All misconceptions currently visible in a history, most likely first.

        Exact detections dominate; behavioural ones are aggregated so the recap
        says "3 rushing errors" once instead of three times.
        """
        pool = [a for a in log if concept is None or a.concept == concept]
        by_id: Dict[str, Detection] = {}
        for attempt in sorted(pool, key=lambda a: -a.timestamp):
            for detection in self.detect(attempt, log):
                if not detection.misconception_id:
                    # Untagged repeated-distractor patterns are kept only as
                    # evidence text for the concept; they have no remedy to run.
                    by_id.setdefault(
                        f"unlabelled:{detection.concept}",
                        Detection(
                            misconception_id="",
                            concept=detection.concept,
                            confidence=detection.confidence,
                            occurrences=detection.occurrences,
                            evidence=detection.evidence,
                        ),
                    )
                    continue
                existing = by_id.get(detection.misconception_id)
                if existing is None or detection.confidence > existing.confidence:
                    if existing:
                        detection.occurrences = max(detection.occurrences, existing.occurrences)
                    by_id[detection.misconception_id] = detection

        ordered = sorted(
            by_id.values(),
            key=lambda d: (-self._severity(d.misconception_id), -d.confidence),
        )
        return ordered[:limit]

    def _severity(self, misconception_id: str) -> int:
        found = self.catalog.get(misconception_id)
        return found.severity if found else 2

    # ------------------------------------------------------------------
    # Remediation
    # ------------------------------------------------------------------
    def remedy_plan(self, detections: Sequence[Detection]) -> List[dict]:
        """
        Ordered micro-lessons the game should put in front of the player.

        Ordering is by severity and confidence, and drills are deduplicated so a
        player with three arithmetic misconceptions does not drill the same
        prerequisite three times.
        """
        plan: List[dict] = []
        seen_drills: set[str] = set()
        for detection in sorted(
            detections, key=lambda d: (-self._severity(d.misconception_id), -d.confidence)
        ):
            misconception = self.catalog.get(detection.misconception_id)
            if misconception is None:
                continue
            drills = [d for d in misconception.drills if d not in seen_drills]
            seen_drills.update(drills)
            plan.append(
                {
                    "misconception_id": misconception.id,
                    "name": misconception.name,
                    "concept": misconception.concept,
                    "severity": misconception.severity,
                    "confidence": round(detection.confidence, 3),
                    "occurrences": detection.occurrences,
                    "evidence": detection.evidence,
                    "remedy": misconception.remedy,
                    "drills": drills,
                }
            )
        return plan


@lru_cache(maxsize=1)
def get_misconception_catalog(path: str | None = None) -> MisconceptionCatalog:
    catalog = MisconceptionCatalog.from_file(Path(path) if path else None)
    logger.info("Misconception catalog loaded: %d entries", len(catalog))
    return catalog
