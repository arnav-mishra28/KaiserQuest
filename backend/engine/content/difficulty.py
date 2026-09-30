"""
Difficulty estimation.

The vision asks for the pipeline to estimate difficulty, and the project already
has 375 questions with *human* difficulty labels. That is a small supervised
dataset, so the estimator is deliberately modest: a handful of interpretable
features, and a ridge regression fitted on the human labels. Two uses:

1. Generated questions get a difficulty that is consistent with the hand-written
   bank rather than with whatever a template felt like emitting.
2. Curated questions whose human label disagrees with the model by 2+ bands get
   flagged for review. That is the "human/content verification" step of the
   pipeline doing real work rather than being a checkbox.

Ridge rather than a gradient booster on purpose: with ~375 samples and ten
features, a regularised linear model generalises better, is instant to fit, and
its coefficients can be read and argued with.
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

try:  # pragma: no cover - exercised by absence in minimal installs
    import numpy as np
    from sklearn.linear_model import Ridge

    SKLEARN_AVAILABLE = True
except ImportError:  # pragma: no cover
    np = None  # type: ignore[assignment]
    SKLEARN_AVAILABLE = False

logger = logging.getLogger("kaiserquest.engine.content.difficulty")

MIN_DIFFICULTY = 1
MAX_DIFFICULTY = 5

FEATURE_NAMES: Tuple[str, ...] = (
    "length_chars",
    "option_count",
    "operator_count",
    "max_number_log",
    "has_fraction",
    "has_variable",
    "has_negative",
    "is_word_problem",
    "reasoning_cue",
    "concept_level",
)

_NUMBER_RE = re.compile(r"-?\d+(?:\.\d+)?")
_OPERATOR_RE = re.compile(r"[+\-*/^×÷]|\*\*")
_REASONING_CUES = (
    "why",
    "explain",
    "which statement",
    "best describes",
    "justif",
    "implies",
    "infer",
    "prove",
    "conclusion",
    "therefore",
)


def _clamp_difficulty(value: float) -> int:
    return int(max(MIN_DIFFICULTY, min(MAX_DIFFICULTY, round(value))))


def extract_features(
    question_text: str,
    options: Optional[Sequence[str]] = None,
    concept_level: int = 2,
) -> List[float]:
    """Turn one question into the feature vector the estimator consumes."""
    text = question_text or ""
    lowered = text.lower()
    numbers = [abs(float(n)) for n in _NUMBER_RE.findall(text)]
    max_number = max(numbers) if numbers else 0.0
    if np is not None:
        max_number_log = float(np.log1p(max_number))
    else:  # pragma: no cover
        import math

        max_number_log = math.log1p(max_number)

    return [
        float(len(text)),
        float(len(options or [])),
        float(len(_OPERATOR_RE.findall(text))),
        max_number_log,
        1.0 if ("/" in text or "fraction" in lowered) else 0.0,
        1.0 if re.search(r"\b[a-z]\b(?=[^a-z]|$)", lowered) and re.search(r"[a-z]\s*[-+*/^=]|\d\s*[a-z]", lowered) else 0.0,
        1.0 if re.search(r"(^|[\s(=])-\s*\d|negative|minus", lowered) else 0.0,
        1.0 if len(text) > 110 else 0.0,
        1.0 if any(cue in lowered for cue in _REASONING_CUES) else 0.0,
        float(concept_level),
    ]


@dataclass
class TrainingReport:
    samples: int = 0
    backend: str = "rule"
    mae: float = 0.0
    coefficients: Dict[str, float] = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "samples": self.samples,
            "backend": self.backend,
            "mae": round(self.mae, 4),
            "coefficients": {k: round(v, 4) for k, v in self.coefficients.items()},
        }


class DifficultyEstimator:
    """Rule-based by default; fitted from human labels when available."""

    def __init__(self, concept_level_lookup=None):
        self._model = None
        self._concept_level_lookup = concept_level_lookup or (lambda concept_id: 2)
        self._report = TrainingReport()

    @property
    def backend(self) -> str:
        return self._report.backend

    @property
    def report(self) -> TrainingReport:
        return self._report

    @property
    def is_fitted(self) -> bool:
        return self._model is not None

    # ------------------------------------------------------------------
    # The interpretable fallback — always available, and the baseline the
    # model has to beat to be used at all.
    # ------------------------------------------------------------------
    def rule_score(
        self,
        question_text: str,
        options: Optional[Sequence[str]] = None,
        concept_level: int = 2,
    ) -> float:
        features = extract_features(question_text, options, concept_level)
        length, option_count, operators, max_number, fraction, variable, negative, word, reasoning, level = features
        score = 1.0
        score += 0.6 * (level - 1) / 4.0 * 3.0
        score += min(operators, 6) * 0.18
        score += min(max_number / 20.0, 1.5) * 0.6
        score += 0.45 if fraction else 0.0
        score += 0.30 if variable else 0.0
        score += 0.30 if negative else 0.0
        score += 0.55 if word else 0.0
        score += 0.55 if reasoning else 0.0
        score += 0.10 if option_count >= 5 else 0.0
        score += 0.25 if length > 200 else 0.0
        return _clamp_difficulty(score)

    def estimate(
        self,
        question_text: str,
        options: Optional[Sequence[str]] = None,
        concept_level: int = 2,
    ) -> int:
        if self._model is None:
            return self.rule_score(question_text, options, concept_level)
        features = extract_features(question_text, options, concept_level)
        prediction = float(self._model.predict(np.asarray([features], dtype=float))[0])
        return _clamp_difficulty(prediction)

    def estimate_question(self, question: dict) -> int:
        concept_level = self._concept_level_lookup(question.get("concept", ""))
        return self.estimate(question.get("question", ""), question.get("options"), concept_level)

    def predict_training_sample(
        self,
        question_text: str,
        options: Optional[Sequence[str]],
        concept_level: int,
    ) -> float:
        """Raw (unrounded) prediction — used to flag label disagreements."""
        if self._model is not None:
            features = extract_features(question_text, options, concept_level)
            return float(self._model.predict(np.asarray([features], dtype=float))[0])
        return float(self.rule_score(question_text, options, concept_level))

    # ------------------------------------------------------------------
    # Training
    # ------------------------------------------------------------------
    def fit(self, samples: Iterable[Tuple[str, Optional[Sequence[str]], int, int]]) -> TrainingReport:
        """
        Fit on (question_text, options, concept_level, human_difficulty) tuples.

        Falls back to the rule-based scorer if scikit-learn is unavailable or the
        dataset is too small to be worth fitting.
        """
        rows = list(samples)
        if not SKLEARN_AVAILABLE or len(rows) < 40:
            self._report = TrainingReport(samples=len(rows), backend="rule")
            logger.info(
                "Difficulty estimator staying rule-based (%d samples%s)",
                len(rows),
                "" if SKLEARN_AVAILABLE else ", sklearn unavailable",
            )
            return self._report

        X = np.asarray([extract_features(text, options, level) for text, options, level, _ in rows], dtype=float)
        y = np.asarray([label for *_, label in rows], dtype=float)

        model = Ridge(alpha=1.0)
        model.fit(X, y)
        predictions = model.predict(X)
        mae = float(np.mean(np.abs(predictions - y)))

        self._model = model
        self._report = TrainingReport(
            samples=len(rows),
            backend="Ridge",
            mae=mae,
            coefficients=dict(zip(FEATURE_NAMES, model.coef_.tolist())),
        )
        logger.info(
            "Difficulty estimator fitted on %d human-labelled questions (MAE %.3f, backend Ridge)",
            len(rows),
            mae,
        )
        return self._report

    def label_disagreements(
        self,
        samples: Iterable[Tuple[str, Optional[Sequence[str]], int, int]],
        tolerance: int = 2,
    ) -> List[dict]:
        """
        Curated questions whose human label is far from the estimate. These are
        the ones a reviewer should look at: either the label is wrong, or the
        features are missing something real.
        """
        flagged: List[dict] = []
        for text, options, level, label in samples:
            predicted = self.predict_training_sample(text, options, level)
            if abs(predicted - label) >= tolerance:
                flagged.append(
                    {
                        "question": text[:120],
                        "human_difficulty": label,
                        "estimated_difficulty": round(predicted, 2),
                        "delta": round(predicted - label, 2),
                    }
                )
        flagged.sort(key=lambda item: -abs(item["delta"]))
        return flagged
