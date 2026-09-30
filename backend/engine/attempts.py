"""
Attempt records: the raw behavioural signal the Knowledge Engine learns from.

The vision is explicit that a right answer is not 1 and a wrong answer is not 0.
Every observation keeps the signals we can actually act on:

    response time       -> rushed errors vs. genuine thinking
    tries on one item   -> persistence, second-guessing
    hints used          -> how much support was needed to reach the answer
    question difficulty -> was this a stretch, a warm-up, or right at level
    chosen answer       -> which distractor, which misconception
    timestamp           -> spacing, and therefore forgetting

Everything downstream (tracing, misconceptions, Silver Mountain assembly) reads
Attempts and nothing else, so a future DKT/transformer model can be dropped in
without touching the rest of the engine.
"""

from __future__ import annotations

import statistics
import time
from dataclasses import dataclass, field
from typing import Dict, Iterable, List, Optional, Sequence

# Rough reading-speed constants used when a question has no measured baseline.
MS_PER_CHARACTER = 28.0
MS_PER_OPTION = 450.0
BASE_READ_MS = 2500.0

# A wrong answer given in under this fraction of the expected time is a speed
# error, not a knowledge error. The engine treats those very differently.
FAST_ERROR_RATIO = 0.4


def estimate_expected_time_ms(question: str, options: Optional[Sequence[str]] = None) -> float:
    """
    Baseline time a competent reader needs for one item.

    Deliberately simple and deterministic: the engine compares a player against
    *their own* baseline far more than against this number, so precision here is
    not important — stability is.
    """
    text = question or ""
    expected = BASE_READ_MS + MS_PER_CHARACTER * len(text)
    if options:
        expected += MS_PER_OPTION * len(options)
    return float(expected)


@dataclass
class Attempt:
    """One answered question. The atom of the learner model."""

    player_id: str
    concept: str
    question_id: str
    correct: bool
    difficulty: int = 2
    response_time_ms: float = 0.0
    expected_time_ms: float = 0.0
    hints_used: int = 0
    tries: int = 1
    chosen: Optional[str] = None
    correct_answer: Optional[str] = None
    misconception_id: Optional[str] = None
    domain: Optional[str] = None
    realm: Optional[str] = None
    trial_id: Optional[str] = None
    timestamp: float = field(default_factory=time.time)

    # ------------------------------------------------------------------
    # Derived signals
    # ------------------------------------------------------------------
    @property
    def time_ratio(self) -> float:
        """Response time relative to expectation. 1.0 means 'as expected'."""
        if self.expected_time_ms <= 0:
            return 1.0
        return self.response_time_ms / self.expected_time_ms

    @property
    def is_fast_error(self) -> bool:
        """Wrong, and answered faster than the question could reasonably be read."""
        return (not self.correct) and self.time_ratio < FAST_ERROR_RATIO

    @property
    def is_helped(self) -> bool:
        """Answered correctly only after hints — partial credit, weaker evidence."""
        return self.correct and self.hints_used > 0

    @property
    def evidence_weight(self) -> float:
        """
        How much this observation should move the knowledge estimate (0..1).

        Correct answers reached unaided and unhurried count double a correct
        answer squeezed out of hints; a fast wrong answer counts for less than a
        considered wrong answer, because it tells us about haste, not knowledge.
        """
        weight = 1.0
        if self.is_helped:
            weight *= 0.55
        if self.tries > 1:
            weight *= max(0.4, 1.0 - 0.2 * (self.tries - 1))
        if self.is_fast_error:
            weight *= 0.5
        return max(0.15, min(1.0, weight))

    @property
    def age_days(self) -> float:
        return max(0.0, (time.time() - self.timestamp) / 86400.0)

    def to_dict(self) -> dict:
        return {
            "player_id": self.player_id,
            "concept": self.concept,
            "question_id": self.question_id,
            "correct": self.correct,
            "difficulty": self.difficulty,
            "response_time_ms": round(self.response_time_ms, 1),
            "expected_time_ms": round(self.expected_time_ms, 1),
            "hints_used": self.hints_used,
            "tries": self.tries,
            "chosen": self.chosen,
            "correct_answer": self.correct_answer,
            "misconception_id": self.misconception_id,
            "domain": self.domain,
            "realm": self.realm,
            "trial_id": self.trial_id,
            "timestamp": self.timestamp,
        }

    @classmethod
    def from_dict(cls, data: dict) -> "Attempt":
        return cls(
            player_id=data.get("player_id", ""),
            concept=data.get("concept", ""),
            question_id=data.get("question_id", ""),
            correct=bool(data.get("correct", False)),
            difficulty=int(data.get("difficulty", 2)),
            response_time_ms=float(data.get("response_time_ms", 0.0)),
            expected_time_ms=float(data.get("expected_time_ms", 0.0)),
            hints_used=int(data.get("hints_used", 0)),
            tries=int(data.get("tries", 1)),
            chosen=data.get("chosen"),
            correct_answer=data.get("correct_answer"),
            misconception_id=data.get("misconception_id"),
            domain=data.get("domain"),
            realm=data.get("realm"),
            trial_id=data.get("trial_id"),
            timestamp=float(data.get("timestamp", time.time())),
        )


@dataclass
class AttemptOutcome:
    """What a single graded answer did to the model (returned to the caller)."""

    concept: str
    correct: bool
    p_known_before: float
    p_known_after: float
    mastery_before: float
    mastery_after: float
    confidence_before: str
    confidence_after: str
    is_fast_error: bool
    detections: List[str] = field(default_factory=list)

    @property
    def delta(self) -> float:
        return self.p_known_after - self.p_known_before

    def to_dict(self) -> dict:
        return {
            "concept": self.concept,
            "correct": self.correct,
            "p_known_before": round(self.p_known_before, 4),
            "p_known_after": round(self.p_known_after, 4),
            "mastery_before": round(self.mastery_before, 2),
            "mastery_after": round(self.mastery_after, 2),
            "confidence_before": self.confidence_before,
            "confidence_after": self.confidence_after,
            "is_fast_error": self.is_fast_error,
            "detections": list(self.detections),
        }


class AttemptLog:
    """Append-only history of attempts, with the queries the engine needs."""

    def __init__(self, attempts: Optional[Iterable[Attempt]] = None):
        self._attempts: List[Attempt] = list(attempts or [])

    def __len__(self) -> int:
        return len(self._attempts)

    def __iter__(self):
        return iter(self._attempts)

    @property
    def all(self) -> List[Attempt]:
        return list(self._attempts)

    def add(self, attempt: Attempt) -> None:
        self._attempts.append(attempt)

    def since(self, timestamp: float) -> List[Attempt]:
        return [a for a in self._attempts if a.timestamp >= timestamp]

    def for_concept(self, concept: str) -> List[Attempt]:
        return [a for a in self._attempts if a.concept == concept]

    def for_question(self, question_id: str) -> List[Attempt]:
        return [a for a in self._attempts if a.question_id == question_id]

    def last_for_concept(self, concept: str) -> Optional[Attempt]:
        matches = self.for_concept(concept)
        return max(matches, key=lambda a: a.timestamp) if matches else None

    def accuracy(self, concept: str) -> float:
        matches = self.for_concept(concept)
        if not matches:
            return 0.0
        return sum(1 for a in matches if a.correct) / len(matches)

    def recent_accuracy(self, concept: str, window: int = 6) -> float:
        """Accuracy over just the most recent attempts — catches live recovery."""
        matches = sorted(self.for_concept(concept), key=lambda a: a.timestamp)[-window:]
        if not matches:
            return 0.0
        return sum(1 for a in matches if a.correct) / len(matches)

    def median_time_ratio(self, concept: str) -> float:
        ratios = [a.time_ratio for a in self.for_concept(concept)]
        return statistics.median(ratios) if ratios else 1.0

    def fastest_error_ratio(self, concept: str) -> float:
        ratios = [a.time_ratio for a in self.for_concept(concept) if not a.correct]
        return min(ratios) if ratios else 1.0

    def fast_errors(self, concept: Optional[str] = None) -> List[Attempt]:
        pool = self.for_concept(concept) if concept else self._attempts
        return [a for a in pool if a.is_fast_error]

    def misconception_counts(self, concept: Optional[str] = None) -> Dict[str, int]:
        counts: Dict[str, int] = {}
        pool = self.for_concept(concept) if concept else self._attempts
        for attempt in pool:
            if attempt.misconception_id:
                counts[attempt.misconception_id] = counts.get(attempt.misconception_id, 0) + 1
        return dict(sorted(counts.items(), key=lambda kv: -kv[1]))

    def repeated_choices(self, concept: str, minimum: int = 2) -> Dict[str, int]:
        """Distractor strings chosen more than once on the same concept."""
        counts: Dict[str, int] = {}
        for attempt in self.for_concept(concept):
            if attempt.correct or not attempt.chosen:
                continue
            counts[attempt.chosen] = counts.get(attempt.chosen, 0) + 1
        return {k: v for k, v in counts.items() if v >= minimum}

    def guess_like(self, concept: str, min_attempts: int = 8) -> bool:
        """
        Chance-level accuracy at very low response times: the statistical
        fingerprint of guessing rather than reasoning.
        """
        attempts = self.for_concept(concept)
        if len(attempts) < min_attempts:
            return False
        accuracy = self.accuracy(concept)
        if not 0.10 <= accuracy <= 0.38:
            return False
        return self.median_time_ratio(concept) <= 0.55

    def to_list(self) -> List[dict]:
        return [a.to_dict() for a in self._attempts]

    @classmethod
    def from_list(cls, data: Iterable[dict]) -> "AttemptLog":
        return cls(Attempt.from_dict(d) for d in data or [])
