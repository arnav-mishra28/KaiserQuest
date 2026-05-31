"""
KaiserQuest - Adaptive Difficulty Model
Uses scikit-learn to predict optimal question difficulty based on player performance.
Features: accuracy, avg_response_time, current_streak, topic_mastery, player_level.
"""

from __future__ import annotations

import logging
import numpy as np
from typing import Dict, List, Optional, Tuple

logger = logging.getLogger("kaiserquest.difficulty_adapter")

# ---------------------------------------------------------------------------
# Try importing sklearn; fall back to a rule-based system if unavailable
# ---------------------------------------------------------------------------
try:
    from sklearn.ensemble import GradientBoostingRegressor
    from sklearn.preprocessing import StandardScaler
    SKLEARN_AVAILABLE = True
except ImportError:
    SKLEARN_AVAILABLE = False
    logger.warning("scikit-learn not installed — using rule-based difficulty adapter")


# Difficulty levels: 1 (easy) to 5 (expert)
MIN_DIFFICULTY = 1
MAX_DIFFICULTY = 5
DEFAULT_DIFFICULTY = 2


def _clamp(value: float, lo: float = MIN_DIFFICULTY, hi: float = MAX_DIFFICULTY) -> float:
    return max(lo, min(hi, value))


# ---------------------------------------------------------------------------
# Rule-based fallback adapter
# ---------------------------------------------------------------------------
class _RuleBasedAdapter:
    """Simple heuristic adapter when sklearn is not available."""

    def predict_difficulty(
        self,
        accuracy: float,
        avg_response_time_ms: float,
        current_streak: int,
        topic_mastery: float,
        player_level: int,
    ) -> float:
        base = DEFAULT_DIFFICULTY

        # Accuracy adjustments
        if accuracy >= 0.9:
            base += 1.0
        elif accuracy >= 0.75:
            base += 0.5
        elif accuracy < 0.4:
            base -= 1.0
        elif accuracy < 0.55:
            base -= 0.5

        # Streak bonus
        if current_streak >= 5:
            base += 0.5
        elif current_streak >= 10:
            base += 1.0

        # Speed bonus — fast answers suggest higher skill
        if avg_response_time_ms > 0 and avg_response_time_ms < 3000:
            base += 0.3
        elif avg_response_time_ms > 15000:
            base -= 0.3

        # Mastery scaling
        if topic_mastery >= 70:
            base += 0.5
        elif topic_mastery < 30:
            base -= 0.5

        # Player level scaling
        base += (player_level - 1) * 0.1

        return _clamp(round(base))


# ---------------------------------------------------------------------------
# ML-based adapter (Gradient Boosting Regressor)
# ---------------------------------------------------------------------------
class _MLAdapter:
    """
    Learns optimal difficulty from synthetic + real gameplay data.
    Features: [accuracy, avg_response_time_ms, current_streak, topic_mastery, player_level]
    Target: ideal difficulty (1-5).
    """

    def __init__(self):
        self.model = GradientBoostingRegressor(
            n_estimators=100,
            max_depth=4,
            learning_rate=0.1,
            random_state=42,
        )
        self.scaler = StandardScaler()
        self._is_trained = False
        self._training_X: List[List[float]] = []
        self._training_y: List[float] = []
        # Bootstrap with synthetic data
        self._bootstrap_train()

    def _bootstrap_train(self):
        """Generate synthetic training data covering the feature space."""
        np.random.seed(42)
        n = 500
        accuracies = np.random.uniform(0.0, 1.0, n)
        response_times = np.random.uniform(1000, 30000, n)
        streaks = np.random.randint(0, 15, n).astype(float)
        masteries = np.random.uniform(0, 100, n)
        levels = np.random.randint(1, 30, n).astype(float)

        # Target: a blend formula that mimics good pedagogical difficulty selection
        targets = (
            1.0
            + accuracies * 2.0                       # higher accuracy → harder
            + (streaks / 15) * 0.8                    # streaks → slight bump
            - (response_times / 30000) * 0.6          # slow → easier
            + (masteries / 100) * 1.0                 # mastery → harder
            + (levels / 30) * 0.5                      # level → slight bump
            + np.random.normal(0, 0.2, n)             # noise
        )
        targets = np.clip(targets, MIN_DIFFICULTY, MAX_DIFFICULTY)

        X = np.column_stack([accuracies, response_times, streaks, masteries, levels])
        self._training_X = X.tolist()
        self._training_y = targets.tolist()

        X_scaled = self.scaler.fit_transform(X)
        self.model.fit(X_scaled, targets)
        self._is_trained = True
        logger.info("ML difficulty adapter bootstrapped with %d synthetic samples", n)

    def add_training_sample(self, features: List[float], ideal_difficulty: float):
        """Add a real gameplay observation to retrain periodically."""
        self._training_X.append(features)
        self._training_y.append(ideal_difficulty)
        # Retrain every 50 new real samples
        if len(self._training_X) % 50 == 0:
            self._retrain()

    def _retrain(self):
        X = np.array(self._training_X)
        y = np.array(self._training_y)
        X_scaled = self.scaler.fit_transform(X)
        self.model.fit(X_scaled, y)
        logger.info("ML adapter retrained with %d total samples", len(y))

    def predict_difficulty(
        self,
        accuracy: float,
        avg_response_time_ms: float,
        current_streak: int,
        topic_mastery: float,
        player_level: int,
    ) -> float:
        features = np.array([[accuracy, avg_response_time_ms, current_streak, topic_mastery, player_level]])
        features_scaled = self.scaler.transform(features)
        prediction = self.model.predict(features_scaled)[0]
        return _clamp(round(prediction))


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
class DifficultyAdapter:
    """
    Facade that picks the best available backend (ML or rule-based).
    Provides a simple predict_difficulty() interface used by the battle and
    question services.
    """

    def __init__(self):
        if SKLEARN_AVAILABLE:
            self._backend = _MLAdapter()
            self._backend_name = "GradientBoostingRegressor"
        else:
            self._backend = _RuleBasedAdapter()
            self._backend_name = "RuleBased"
        logger.info("DifficultyAdapter initialised with backend: %s", self._backend_name)

    @property
    def backend_name(self) -> str:
        return self._backend_name

    def predict_difficulty(
        self,
        accuracy: float = 0.5,
        avg_response_time_ms: float = 8000.0,
        current_streak: int = 0,
        topic_mastery: float = 0.0,
        player_level: int = 1,
    ) -> int:
        """Return the recommended integer difficulty 1-5."""
        raw = self._backend.predict_difficulty(
            accuracy, avg_response_time_ms, current_streak, topic_mastery, player_level,
        )
        return int(_clamp(round(raw)))

    def recommend_for_player(self, player, subject: str, topic: str) -> int:
        """Convenience: extract features from a PlayerModel and predict."""
        from models.player_model import PlayerModel
        if not isinstance(player, PlayerModel):
            return DEFAULT_DIFFICULTY

        subj_stats = player.get_subject(subject)
        topic_stats = subj_stats.get_topic(topic)

        return self.predict_difficulty(
            accuracy=topic_stats.accuracy,
            avg_response_time_ms=topic_stats.avg_response_time_ms,
            current_streak=topic_stats.current_streak,
            topic_mastery=topic_stats.mastery_score,
            player_level=player.level,
        )

    def record_outcome(
        self,
        accuracy: float,
        avg_response_time_ms: float,
        current_streak: int,
        topic_mastery: float,
        player_level: int,
        was_correct: bool,
        question_difficulty: int,
    ):
        """
        Feed back an actual gameplay outcome so the ML model can learn.
        The 'ideal' difficulty is estimated: if the player got it right quickly,
        the ideal was probably higher; if wrong, probably lower.
        """
        if not isinstance(self._backend, _MLAdapter if SKLEARN_AVAILABLE else type(None)):
            return
        # Heuristic for ideal difficulty based on outcome
        if was_correct:
            ideal = min(question_difficulty + 0.5, MAX_DIFFICULTY)
        else:
            ideal = max(question_difficulty - 0.5, MIN_DIFFICULTY)

        features = [accuracy, avg_response_time_ms, current_streak, topic_mastery, player_level]
        if SKLEARN_AVAILABLE and isinstance(self._backend, _MLAdapter):
            self._backend.add_training_sample(features, ideal)


# Singleton
difficulty_adapter = DifficultyAdapter()
