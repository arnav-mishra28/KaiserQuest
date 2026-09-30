"""
KaiserQuest - Player Performance Tracking Model
Tracks accuracy, speed, streaks, weak topics, and overall mastery per subject.
"""

from __future__ import annotations

import time
import logging
from dataclasses import dataclass, field
from typing import Dict, List, Optional
from enum import Enum

logger = logging.getLogger("kaiserquest.player_model")


class Subject(str, Enum):
    MATH = "math"
    ENGLISH = "english"
    MUSIC = "music"


@dataclass
class TopicStats:
    """Performance stats for a single topic within a subject."""
    topic: str
    total_attempts: int = 0
    correct_answers: int = 0
    total_response_time_ms: float = 0.0
    current_streak: int = 0
    best_streak: int = 0
    difficulty_scores: List[float] = field(default_factory=list)

    @property
    def accuracy(self) -> float:
        if self.total_attempts == 0:
            return 0.0
        return self.correct_answers / self.total_attempts

    @property
    def avg_response_time_ms(self) -> float:
        if self.total_attempts == 0:
            return 0.0
        return self.total_response_time_ms / self.total_attempts

    @property
    def avg_difficulty(self) -> float:
        if not self.difficulty_scores:
            return 1.0
        return sum(self.difficulty_scores) / len(self.difficulty_scores)

    @property
    def mastery_score(self) -> float:
        """Composite mastery score 0-100 based on accuracy, streak, and difficulty."""
        if self.total_attempts == 0:
            return 0.0
        acc_component = self.accuracy * 40
        streak_component = min(self.best_streak / 10, 1.0) * 20
        diff_component = (self.avg_difficulty / 5.0) * 20
        volume_component = min(self.total_attempts / 50, 1.0) * 20
        return acc_component + streak_component + diff_component + volume_component

    def record_answer(self, correct: bool, response_time_ms: float, difficulty: float):
        self.total_attempts += 1
        self.total_response_time_ms += response_time_ms
        self.difficulty_scores.append(difficulty)
        # Keep only last 50 difficulty scores
        if len(self.difficulty_scores) > 50:
            self.difficulty_scores = self.difficulty_scores[-50:]
        if correct:
            self.correct_answers += 1
            self.current_streak += 1
            self.best_streak = max(self.best_streak, self.current_streak)
        else:
            self.current_streak = 0

    def to_dict(self) -> dict:
        return {
            "topic": self.topic,
            "total_attempts": self.total_attempts,
            "correct_answers": self.correct_answers,
            "accuracy": round(self.accuracy, 4),
            "avg_response_time_ms": round(self.avg_response_time_ms, 1),
            "current_streak": self.current_streak,
            "best_streak": self.best_streak,
            "avg_difficulty": round(self.avg_difficulty, 2),
            "mastery_score": round(self.mastery_score, 2),
        }


@dataclass
class SubjectStats:
    """Aggregate performance for a single subject (Math, English, Music)."""
    subject: Subject
    topics: Dict[str, TopicStats] = field(default_factory=dict)

    def get_topic(self, topic: str) -> TopicStats:
        if topic not in self.topics:
            self.topics[topic] = TopicStats(topic=topic)
        return self.topics[topic]

    @property
    def total_attempts(self) -> int:
        return sum(t.total_attempts for t in self.topics.values())

    @property
    def total_correct(self) -> int:
        return sum(t.correct_answers for t in self.topics.values())

    @property
    def accuracy(self) -> float:
        if self.total_attempts == 0:
            return 0.0
        return self.total_correct / self.total_attempts

    @property
    def avg_mastery(self) -> float:
        if not self.topics:
            return 0.0
        return sum(t.mastery_score for t in self.topics.values()) / len(self.topics)

    @property
    def weak_topics(self) -> List[str]:
        """Topics with accuracy below 60% and at least 3 attempts."""
        return [
            name for name, stats in self.topics.items()
            if stats.total_attempts >= 3 and stats.accuracy < 0.6
        ]

    @property
    def strong_topics(self) -> List[str]:
        """Topics with accuracy above 80% and at least 5 attempts."""
        return [
            name for name, stats in self.topics.items()
            if stats.total_attempts >= 5 and stats.accuracy > 0.8
        ]

    def to_dict(self) -> dict:
        return {
            "subject": self.subject.value,
            "total_attempts": self.total_attempts,
            "total_correct": self.total_correct,
            "accuracy": round(self.accuracy, 4),
            "avg_mastery": round(self.avg_mastery, 2),
            "weak_topics": self.weak_topics,
            "strong_topics": self.strong_topics,
            "topics": {name: stats.to_dict() for name, stats in self.topics.items()},
        }


@dataclass
class PlayerModel:
    """Complete player performance model across all subjects."""
    player_id: str
    username: str = ""
    level: int = 1
    xp: int = 0
    xp_to_next_level: int = 100
    total_battles_won: int = 0
    total_battles_lost: int = 0
    pvp_rating: int = 1000  # ELO-style rating
    subjects: Dict[str, SubjectStats] = field(default_factory=dict)
    created_at: float = field(default_factory=time.time)
    last_active: float = field(default_factory=time.time)

    def __post_init__(self):
        # Initialize all three subjects
        for subject in Subject:
            if subject.value not in self.subjects:
                self.subjects[subject.value] = SubjectStats(subject=subject)

    def get_subject(self, subject: str) -> SubjectStats:
        subject = subject.lower()
        if subject not in self.subjects:
            self.subjects[subject] = SubjectStats(subject=Subject(subject))
        return self.subjects[subject]

    def record_answer(
        self,
        subject: str,
        topic: str,
        correct: bool,
        response_time_ms: float,
        difficulty: float,
    ):
        """Record a single answer across the player model."""
        self.last_active = time.time()
        subject_stats = self.get_subject(subject)
        topic_stats = subject_stats.get_topic(topic)
        topic_stats.record_answer(correct, response_time_ms, difficulty)
        logger.info(
            f"Player {self.player_id} answered {'correctly' if correct else 'incorrectly'} "
            f"on {subject}/{topic} (d={difficulty}, t={response_time_ms:.0f}ms)"
        )

    def add_xp(self, amount: int) -> bool:
        """Add XP and return True if player leveled up."""
        self.xp += amount
        leveled_up = False
        while self.xp >= self.xp_to_next_level:
            self.xp -= self.xp_to_next_level
            self.level += 1
            self.xp_to_next_level = int(self.xp_to_next_level * 1.25)
            leveled_up = True
            logger.info(f"Player {self.player_id} leveled up to {self.level}!")
        return leveled_up

    def record_battle_result(self, won: bool, xp_earned: int):
        if won:
            self.total_battles_won += 1
        else:
            self.total_battles_lost += 1
        self.add_xp(xp_earned)

    def update_pvp_rating(self, opponent_rating: int, won: bool):
        """ELO rating update."""
        k = 32
        expected = 1.0 / (1.0 + 10 ** ((opponent_rating - self.pvp_rating) / 400))
        actual = 1.0 if won else 0.0
        self.pvp_rating = max(100, int(self.pvp_rating + k * (actual - expected)))

    @property
    def overall_accuracy(self) -> float:
        total_attempts = sum(s.total_attempts for s in self.subjects.values())
        total_correct = sum(s.total_correct for s in self.subjects.values())
        if total_attempts == 0:
            return 0.0
        return total_correct / total_attempts

    @property
    def all_weak_topics(self) -> Dict[str, List[str]]:
        return {
            name: stats.weak_topics
            for name, stats in self.subjects.items()
            if stats.weak_topics
        }

    def to_dict(self) -> dict:
        return {
            "player_id": self.player_id,
            "username": self.username,
            "level": self.level,
            "xp": self.xp,
            "xp_to_next_level": self.xp_to_next_level,
            "overall_accuracy": round(self.overall_accuracy, 4),
            "total_battles_won": self.total_battles_won,
            "total_battles_lost": self.total_battles_lost,
            "pvp_rating": self.pvp_rating,
            "all_weak_topics": self.all_weak_topics,
            "subjects": {name: stats.to_dict() for name, stats in self.subjects.items()},
            "last_active": self.last_active,
        }


# ---------------------------------------------------------------------------
# In-memory player store (swap for DB in production)
# ---------------------------------------------------------------------------
_player_store: Dict[str, PlayerModel] = {}


def get_or_create_player(player_id: str, username: str = "") -> PlayerModel:
    if player_id not in _player_store:
        _player_store[player_id] = PlayerModel(
            player_id=player_id,
            username=username or f"Kaiser_{player_id[:8]}",
        )
        logger.info(f"Created new player profile: {player_id}")
    return _player_store[player_id]


def get_player(player_id: str) -> Optional[PlayerModel]:
    return _player_store.get(player_id)


def list_players() -> List[PlayerModel]:
    return list(_player_store.values())
