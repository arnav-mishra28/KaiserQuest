"""
KaiserQuest - Battle Service
Handles PvE battle logic: HP, damage calculation, XP rewards, combo streaks.
"""

from __future__ import annotations

import logging
import math
import random
import time
import uuid
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional

from models.player_model import PlayerModel, get_or_create_player
from models.question_generator import get_single_question, check_answer
from models.difficulty_adapter import difficulty_adapter

logger = logging.getLogger("kaiserquest.battle_service")


class BattleState(str, Enum):
    WAITING = "waiting"
    ACTIVE = "active"
    PLAYER_WON = "player_won"
    PLAYER_LOST = "player_lost"


@dataclass
class BattleEnemy:
    """NPC enemy in a PvE battle."""
    name: str
    max_hp: int
    current_hp: int
    attack_power: int
    defense: int
    level: int
    sprite: str = "default_enemy"

    def take_damage(self, amount: int) -> int:
        """Apply damage after defense. Returns actual damage dealt."""
        actual = max(1, amount - self.defense // 3)
        self.current_hp = max(0, self.current_hp - actual)
        return actual

    @property
    def is_defeated(self) -> bool:
        return self.current_hp <= 0

    def to_dict(self) -> dict:
        return {
            "name": self.name,
            "max_hp": self.max_hp,
            "current_hp": self.current_hp,
            "attack_power": self.attack_power,
            "defense": self.defense,
            "level": self.level,
            "sprite": self.sprite,
            "is_defeated": self.is_defeated,
        }


@dataclass
class BattleSession:
    """Active PvE battle session."""
    battle_id: str
    player_id: str
    enemy: BattleEnemy
    subject: str
    topic: str
    difficulty: int
    state: BattleState = BattleState.ACTIVE
    player_hp: int = 100
    player_max_hp: int = 100
    combo_streak: int = 0
    questions_answered: int = 0
    correct_answers: int = 0
    total_damage_dealt: int = 0
    total_damage_taken: int = 0
    xp_earned: int = 0
    current_question: Optional[dict] = None
    question_start_time: float = 0.0
    used_question_ids: List[str] = field(default_factory=list)
    created_at: float = field(default_factory=time.time)

    def to_dict(self) -> dict:
        q = None
        if self.current_question:
            q = {
                "id": self.current_question.get("id"),
                "question": self.current_question.get("question"),
                "options": self.current_question.get("options"),
                "difficulty": self.current_question.get("difficulty"),
                "topic": self.current_question.get("topic"),
            }
        return {
            "battle_id": self.battle_id,
            "player_id": self.player_id,
            "state": self.state.value,
            "player_hp": self.player_hp,
            "player_max_hp": self.player_max_hp,
            "combo_streak": self.combo_streak,
            "questions_answered": self.questions_answered,
            "correct_answers": self.correct_answers,
            "total_damage_dealt": self.total_damage_dealt,
            "total_damage_taken": self.total_damage_taken,
            "xp_earned": self.xp_earned,
            "enemy": self.enemy.to_dict(),
            "current_question": q,
        }


# Enemy templates by difficulty tier
ENEMY_TEMPLATES = [
    {"name": "Slime Scholar", "base_hp": 40, "atk": 5, "defense": 1, "sprite": "slime", "tier": 1},
    {"name": "Goblin Grammarian", "base_hp": 60, "atk": 8, "defense": 2, "sprite": "goblin", "tier": 1},
    {"name": "Skeleton Scribe", "base_hp": 80, "atk": 10, "defense": 3, "sprite": "skeleton", "tier": 2},
    {"name": "Orc Algebrist", "base_hp": 100, "atk": 13, "defense": 5, "sprite": "orc", "tier": 2},
    {"name": "Dark Mage Melodist", "base_hp": 120, "atk": 15, "defense": 6, "sprite": "dark_mage", "tier": 3},
    {"name": "Dragon Theorist", "base_hp": 150, "atk": 18, "defense": 8, "sprite": "dragon", "tier": 3},
    {"name": "Lich Logician", "base_hp": 180, "atk": 20, "defense": 10, "sprite": "lich", "tier": 4},
    {"name": "Archdemon Analyst", "base_hp": 220, "atk": 24, "defense": 12, "sprite": "archdemon", "tier": 5},
]

# In-memory battle store
_active_battles: Dict[str, BattleSession] = {}


def _select_enemy(difficulty: int, player_level: int) -> BattleEnemy:
    """Pick an enemy template scaled to difficulty and player level."""
    tier = min(difficulty, 5)
    candidates = [e for e in ENEMY_TEMPLATES if e["tier"] <= tier]
    if not candidates:
        candidates = ENEMY_TEMPLATES[:2]
    template = random.choice(candidates)

    # Scale HP and attack with player level
    level_scale = 1.0 + (player_level - 1) * 0.1
    return BattleEnemy(
        name=template["name"],
        max_hp=int(template["base_hp"] * level_scale),
        current_hp=int(template["base_hp"] * level_scale),
        attack_power=int(template["atk"] * level_scale),
        defense=int(template["defense"] * level_scale),
        level=max(1, player_level + random.randint(-1, 1)),
        sprite=template["sprite"],
    )


def calculate_player_damage(
    difficulty: int,
    response_time_ms: float,
    combo_streak: int,
) -> int:
    """
    Damage the player deals to the enemy for a correct answer.
    Base damage = 10 + difficulty * 5
    Speed bonus: up to 50% extra for fast answers (< 5 seconds)
    Combo bonus: +10% per streak, capped at +100%
    """
    base = 10 + difficulty * 5
    # Speed bonus (faster = more damage, max at 0ms, 0 bonus at 15s+)
    speed_factor = max(0.0, 1.0 - response_time_ms / 15000)
    speed_bonus = base * speed_factor * 0.5

    # Combo streak bonus
    combo_bonus = base * min(combo_streak * 0.1, 1.0)

    total = int(base + speed_bonus + combo_bonus)
    return max(5, total)


def calculate_enemy_damage(enemy: BattleEnemy) -> int:
    """Damage the enemy deals to the player on a wrong answer."""
    base = enemy.attack_power
    variance = random.randint(-2, 2)
    return max(3, base + variance)


def calculate_xp_reward(
    difficulty: int,
    correct_answers: int,
    total_questions: int,
    combo_best: int,
    enemy_level: int,
) -> int:
    """Calculate XP earned from a battle."""
    base = 20 * difficulty
    accuracy_bonus = int(correct_answers / max(total_questions, 1) * 30)
    combo_bonus = combo_best * 3
    level_bonus = enemy_level * 5
    return base + accuracy_bonus + combo_bonus + level_bonus


def start_battle(
    player_id: str,
    subject: str,
    topic: str,
    difficulty: Optional[int] = None,
) -> BattleSession:
    """Start a new PvE battle."""
    player = get_or_create_player(player_id)

    # Use adaptive difficulty if not specified
    if difficulty is None:
        difficulty = difficulty_adapter.recommend_for_player(player, subject, topic)

    enemy = _select_enemy(difficulty, player.level)

    # Scale player HP with level
    player_max_hp = 100 + (player.level - 1) * 10

    battle = BattleSession(
        battle_id=str(uuid.uuid4()),
        player_id=player_id,
        enemy=enemy,
        subject=subject,
        topic=topic,
        difficulty=difficulty,
        player_hp=player_max_hp,
        player_max_hp=player_max_hp,
    )

    # Fetch first question
    _serve_next_question(battle)

    _active_battles[battle.battle_id] = battle
    logger.info(
        "Battle %s started: %s vs %s (d=%d)",
        battle.battle_id, player_id, enemy.name, difficulty,
    )
    return battle


def _serve_next_question(battle: BattleSession):
    """Load the next question into the battle session."""
    q = get_single_question(
        battle.subject,
        battle.topic,
        difficulty=battle.difficulty,
        exclude_ids=battle.used_question_ids,
    )
    if q:
        battle.current_question = q
        battle.used_question_ids.append(q["id"])
        battle.question_start_time = time.time()
    else:
        # Widen difficulty range
        q = get_single_question(battle.subject, battle.topic, exclude_ids=battle.used_question_ids)
        if q:
            battle.current_question = q
            battle.used_question_ids.append(q["id"])
            battle.question_start_time = time.time()
        else:
            battle.current_question = None
            logger.warning("No more questions available for %s/%s", battle.subject, battle.topic)


def process_battle_answer(
    battle_id: str,
    player_answer: str,
) -> Dict[str, Any]:
    """
    Process a player's answer during a battle.
    Returns result dict with damage, HP changes, XP, etc.
    """
    battle = _active_battles.get(battle_id)
    if not battle:
        return {"error": "Battle not found", "battle_id": battle_id}
    if battle.state != BattleState.ACTIVE:
        return {"error": "Battle is not active", "state": battle.state.value}
    if not battle.current_question:
        return {"error": "No current question"}

    response_time_ms = (time.time() - battle.question_start_time) * 1000
    is_correct = check_answer(battle.current_question, player_answer)
    battle.questions_answered += 1

    result: Dict[str, Any] = {
        "battle_id": battle_id,
        "correct": is_correct,
        "correct_answer": battle.current_question.get("correct_answer"),
        "explanation": battle.current_question.get("explanation"),
        "response_time_ms": round(response_time_ms),
    }

    # Get the player model for recording
    player = get_or_create_player(battle.player_id)
    player.record_answer(
        subject=battle.subject,
        topic=battle.topic,
        correct=is_correct,
        response_time_ms=response_time_ms,
        difficulty=battle.difficulty,
    )

    if is_correct:
        battle.correct_answers += 1
        battle.combo_streak += 1

        # Player attacks enemy
        damage = calculate_player_damage(battle.difficulty, response_time_ms, battle.combo_streak)
        actual_damage = battle.enemy.take_damage(damage)
        battle.total_damage_dealt += actual_damage

        result["player_damage"] = actual_damage
        result["combo_streak"] = battle.combo_streak
        result["enemy_hp"] = battle.enemy.current_hp
        result["player_hp"] = battle.player_hp

        if battle.enemy.is_defeated:
            # Player wins!
            battle.state = BattleState.PLAYER_WON
            xp = calculate_xp_reward(
                battle.difficulty, battle.correct_answers,
                battle.questions_answered, battle.combo_streak,
                battle.enemy.level,
            )
            battle.xp_earned = xp
            leveled_up = player.add_xp(xp)
            player.record_battle_result(won=True, xp_earned=0)  # XP already added

            result["battle_over"] = True
            result["result"] = "victory"
            result["xp_earned"] = xp
            result["leveled_up"] = leveled_up
            result["new_level"] = player.level
            logger.info("Battle %s: Player %s won!", battle_id, battle.player_id)
    else:
        battle.combo_streak = 0

        # Enemy attacks player
        enemy_dmg = calculate_enemy_damage(battle.enemy)
        battle.player_hp = max(0, battle.player_hp - enemy_dmg)
        battle.total_damage_taken += enemy_dmg

        result["enemy_damage"] = enemy_dmg
        result["combo_streak"] = 0
        result["enemy_hp"] = battle.enemy.current_hp
        result["player_hp"] = battle.player_hp

        if battle.player_hp <= 0:
            # Player loses
            battle.state = BattleState.PLAYER_LOST
            xp = max(5, calculate_xp_reward(
                battle.difficulty, battle.correct_answers,
                battle.questions_answered, 0,
                battle.enemy.level,
            ) // 3)
            battle.xp_earned = xp
            player.add_xp(xp)
            player.record_battle_result(won=False, xp_earned=0)

            result["battle_over"] = True
            result["result"] = "defeat"
            result["xp_earned"] = xp
            logger.info("Battle %s: Player %s lost.", battle_id, battle.player_id)

    # Serve next question if battle continues
    if battle.state == BattleState.ACTIVE:
        _serve_next_question(battle)
        result["battle_over"] = False

    # Record outcome for adaptive difficulty
    topic_stats = player.get_subject(battle.subject).get_topic(battle.topic)
    difficulty_adapter.record_outcome(
        accuracy=topic_stats.accuracy,
        avg_response_time_ms=topic_stats.avg_response_time_ms,
        current_streak=topic_stats.current_streak,
        topic_mastery=topic_stats.mastery_score,
        player_level=player.level,
        was_correct=is_correct,
        question_difficulty=battle.difficulty,
    )

    result["battle_state"] = battle.to_dict()
    return result


def get_battle(battle_id: str) -> Optional[BattleSession]:
    return _active_battles.get(battle_id)


def cleanup_old_battles(max_age_seconds: int = 3600):
    """Remove battles older than max_age_seconds."""
    now = time.time()
    expired = [
        bid for bid, b in _active_battles.items()
        if now - b.created_at > max_age_seconds
    ]
    for bid in expired:
        del _active_battles[bid]
    if expired:
        logger.info("Cleaned up %d expired battles", len(expired))
