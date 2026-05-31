"""
KaiserQuest - PvP WebSocket Battle Service
Manages real-time player-vs-player battles over WebSocket connections.
Both players receive the same question; faster correct answer = more damage.
Combo streaks give bonus damage.
"""

from __future__ import annotations

import asyncio
import json
import logging
import time
import uuid
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional, Set

from fastapi import WebSocket

from models.player_model import PlayerModel, get_or_create_player
from models.question_generator import get_single_question, check_answer
from models.difficulty_adapter import difficulty_adapter

logger = logging.getLogger("kaiserquest.pvp_service")


class PvPState(str, Enum):
    MATCHMAKING = "matchmaking"
    COUNTDOWN = "countdown"
    ACTIVE = "active"
    FINISHED = "finished"


@dataclass
class PvPPlayer:
    """A player in a PvP battle."""
    player_id: str
    websocket: WebSocket
    hp: int = 100
    max_hp: int = 100
    combo_streak: int = 0
    best_combo: int = 0
    correct_answers: int = 0
    total_answers: int = 0
    total_damage_dealt: int = 0
    has_answered_current: bool = False
    current_answer_time: float = 0.0
    current_answer_correct: bool = False

    def to_dict(self) -> dict:
        return {
            "player_id": self.player_id,
            "hp": self.hp,
            "max_hp": self.max_hp,
            "combo_streak": self.combo_streak,
            "correct_answers": self.correct_answers,
            "total_answers": self.total_answers,
            "total_damage_dealt": self.total_damage_dealt,
        }


@dataclass
class PvPBattle:
    """Active PvP battle session between two players."""
    battle_id: str
    player1: PvPPlayer
    player2: PvPPlayer
    subject: str
    topic: str
    difficulty: int
    state: PvPState = PvPState.COUNTDOWN
    current_question: Optional[dict] = None
    question_number: int = 0
    max_questions: int = 10
    question_start_time: float = 0.0
    question_timeout_seconds: float = 30.0
    used_question_ids: List[str] = field(default_factory=list)
    created_at: float = field(default_factory=time.time)

    def get_opponent(self, player_id: str) -> Optional[PvPPlayer]:
        if self.player1.player_id == player_id:
            return self.player2
        elif self.player2.player_id == player_id:
            return self.player1
        return None

    def get_player(self, player_id: str) -> Optional[PvPPlayer]:
        if self.player1.player_id == player_id:
            return self.player1
        elif self.player2.player_id == player_id:
            return self.player2
        return None

    def both_answered(self) -> bool:
        return self.player1.has_answered_current and self.player2.has_answered_current

    def to_dict(self) -> dict:
        return {
            "battle_id": self.battle_id,
            "state": self.state.value,
            "question_number": self.question_number,
            "max_questions": self.max_questions,
            "player1": self.player1.to_dict(),
            "player2": self.player2.to_dict(),
            "subject": self.subject,
            "topic": self.topic,
            "difficulty": self.difficulty,
        }


# ---------------------------------------------------------------------------
# Matchmaking queue and active PvP battles
# ---------------------------------------------------------------------------
@dataclass
class QueueEntry:
    player_id: str
    websocket: WebSocket
    subject: str
    topic: str
    joined_at: float = field(default_factory=time.time)

_matchmaking_queue: List[QueueEntry] = []
_active_pvp_battles: Dict[str, PvPBattle] = {}
_player_to_battle: Dict[str, str] = {}  # player_id -> battle_id


class PvPManager:
    """Manages PvP matchmaking, battles, and WebSocket communication."""

    async def send_to_player(self, ws: WebSocket, data: dict):
        """Send JSON data to a player's WebSocket."""
        try:
            await ws.send_json(data)
        except Exception as e:
            logger.error("Failed to send to WebSocket: %s", e)

    async def broadcast_to_battle(self, battle: PvPBattle, data: dict):
        """Send data to both players in a battle."""
        await asyncio.gather(
            self.send_to_player(battle.player1.websocket, data),
            self.send_to_player(battle.player2.websocket, data),
        )

    async def join_queue(
        self,
        player_id: str,
        websocket: WebSocket,
        subject: str = "math",
        topic: str = "variables",
    ) -> Optional[PvPBattle]:
        """
        Add player to matchmaking queue. If a match is found, create and
        return a PvP battle. Otherwise return None (player waits).
        """
        # Check if already in a battle
        if player_id in _player_to_battle:
            await self.send_to_player(websocket, {
                "type": "error",
                "message": "Already in an active PvP battle",
            })
            return None

        # Look for a compatible opponent in the queue
        match_entry: Optional[QueueEntry] = None
        for entry in _matchmaking_queue:
            if entry.player_id != player_id and entry.subject == subject and entry.topic == topic:
                match_entry = entry
                break

        if match_entry:
            _matchmaking_queue.remove(match_entry)
            battle = await self._create_battle(
                match_entry.player_id, match_entry.websocket,
                player_id, websocket,
                subject, topic,
            )
            return battle
        else:
            # Add to queue
            _matchmaking_queue.append(QueueEntry(
                player_id=player_id,
                websocket=websocket,
                subject=subject,
                topic=topic,
            ))
            await self.send_to_player(websocket, {
                "type": "matchmaking",
                "message": "Searching for an opponent...",
                "queue_position": len(_matchmaking_queue),
            })
            logger.info("Player %s joined matchmaking queue for %s/%s", player_id, subject, topic)
            return None

    async def _create_battle(
        self,
        p1_id: str, p1_ws: WebSocket,
        p2_id: str, p2_ws: WebSocket,
        subject: str, topic: str,
    ) -> PvPBattle:
        """Create a new PvP battle between two players."""
        # Average difficulty between both players
        p1 = get_or_create_player(p1_id)
        p2 = get_or_create_player(p2_id)
        d1 = difficulty_adapter.recommend_for_player(p1, subject, topic)
        d2 = difficulty_adapter.recommend_for_player(p2, subject, topic)
        difficulty = max(1, (d1 + d2) // 2)

        player_hp = 100

        battle = PvPBattle(
            battle_id=str(uuid.uuid4()),
            player1=PvPPlayer(player_id=p1_id, websocket=p1_ws, hp=player_hp, max_hp=player_hp),
            player2=PvPPlayer(player_id=p2_id, websocket=p2_ws, hp=player_hp, max_hp=player_hp),
            subject=subject,
            topic=topic,
            difficulty=difficulty,
        )

        _active_pvp_battles[battle.battle_id] = battle
        _player_to_battle[p1_id] = battle.battle_id
        _player_to_battle[p2_id] = battle.battle_id

        logger.info(
            "PvP Battle %s created: %s vs %s (%s/%s d=%d)",
            battle.battle_id, p1_id, p2_id, subject, topic, difficulty,
        )

        # Notify both players
        await self.broadcast_to_battle(battle, {
            "type": "match_found",
            "battle_id": battle.battle_id,
            "opponent": {"player1": p1_id, "player2": p2_id},
            "subject": subject,
            "topic": topic,
            "difficulty": difficulty,
        })

        # Countdown then start
        await self._countdown_and_start(battle)
        return battle

    async def _countdown_and_start(self, battle: PvPBattle):
        """3-2-1 countdown then serve first question."""
        for i in range(3, 0, -1):
            await self.broadcast_to_battle(battle, {
                "type": "countdown",
                "seconds": i,
            })
            await asyncio.sleep(1)

        battle.state = PvPState.ACTIVE
        await self._serve_question(battle)

    async def _serve_question(self, battle: PvPBattle):
        """Send the same question to both players."""
        battle.question_number += 1
        q = get_single_question(
            battle.subject, battle.topic,
            difficulty=battle.difficulty,
            exclude_ids=battle.used_question_ids,
        )
        if not q:
            q = get_single_question(battle.subject, battle.topic, exclude_ids=battle.used_question_ids)

        if not q:
            await self._end_battle(battle, reason="no_questions")
            return

        battle.current_question = q
        battle.used_question_ids.append(q["id"])
        battle.question_start_time = time.time()
        battle.player1.has_answered_current = False
        battle.player2.has_answered_current = False

        question_data = {
            "type": "question",
            "question_number": battle.question_number,
            "max_questions": battle.max_questions,
            "question": {
                "id": q["id"],
                "question": q["question"],
                "options": q["options"],
                "difficulty": q.get("difficulty"),
            },
            "timeout_seconds": battle.question_timeout_seconds,
        }
        await self.broadcast_to_battle(battle, question_data)

        # Schedule timeout
        asyncio.create_task(self._question_timeout(battle, battle.question_number))

    async def _question_timeout(self, battle: PvPBattle, question_num: int):
        """Auto-resolve after timeout if not both answered."""
        await asyncio.sleep(battle.question_timeout_seconds)
        if battle.state != PvPState.ACTIVE:
            return
        if battle.question_number != question_num:
            return  # Already moved on
        # Force resolve
        if not battle.player1.has_answered_current:
            battle.player1.has_answered_current = True
            battle.player1.current_answer_correct = False
            battle.player1.current_answer_time = battle.question_timeout_seconds * 1000
        if not battle.player2.has_answered_current:
            battle.player2.has_answered_current = True
            battle.player2.current_answer_correct = False
            battle.player2.current_answer_time = battle.question_timeout_seconds * 1000
        await self._resolve_question(battle)

    async def handle_answer(self, battle_id: str, player_id: str, answer: str):
        """Process a player's answer in PvP."""
        battle = _active_pvp_battles.get(battle_id)
        if not battle or battle.state != PvPState.ACTIVE:
            return
        if not battle.current_question:
            return

        player = battle.get_player(player_id)
        if not player or player.has_answered_current:
            return

        response_time_ms = (time.time() - battle.question_start_time) * 1000
        is_correct = check_answer(battle.current_question, answer)

        player.has_answered_current = True
        player.current_answer_correct = is_correct
        player.current_answer_time = response_time_ms
        player.total_answers += 1

        if is_correct:
            player.correct_answers += 1
            player.combo_streak += 1
            player.best_combo = max(player.best_combo, player.combo_streak)
        else:
            player.combo_streak = 0

        # Notify the answering player that their answer was received
        await self.send_to_player(player.websocket, {
            "type": "answer_received",
            "waiting_for_opponent": not battle.both_answered(),
        })

        # Record in player model
        pm = get_or_create_player(player_id)
        pm.record_answer(
            battle.subject, battle.topic,
            is_correct, response_time_ms, battle.difficulty,
        )

        if battle.both_answered():
            await self._resolve_question(battle)

    async def _resolve_question(self, battle: PvPBattle):
        """Both players answered — resolve damage and advance."""
        p1 = battle.player1
        p2 = battle.player2
        q = battle.current_question

        # Calculate damage for each player
        p1_damage = 0
        p2_damage = 0

        if p1.current_answer_correct:
            base = 10 + battle.difficulty * 5
            speed_factor = max(0.0, 1.0 - p1.current_answer_time / 15000)
            combo_bonus = min(p1.combo_streak * 0.1, 1.0)
            p1_damage = int(base * (1.0 + speed_factor * 0.5 + combo_bonus))

        if p2.current_answer_correct:
            base = 10 + battle.difficulty * 5
            speed_factor = max(0.0, 1.0 - p2.current_answer_time / 15000)
            combo_bonus = min(p2.combo_streak * 0.1, 1.0)
            p2_damage = int(base * (1.0 + speed_factor * 0.5 + combo_bonus))

        # Apply damage (each player's correct answer damages the opponent)
        if p1_damage > 0:
            p2.hp = max(0, p2.hp - p1_damage)
            p1.total_damage_dealt += p1_damage
        if p2_damage > 0:
            p1.hp = max(0, p1.hp - p2_damage)
            p2.total_damage_dealt += p2_damage

        # Also: wrong answer costs 5 HP self-damage
        if not p1.current_answer_correct:
            p1.hp = max(0, p1.hp - 5)
        if not p2.current_answer_correct:
            p2.hp = max(0, p2.hp - 5)

        resolve_data = {
            "type": "question_result",
            "correct_answer": q.get("correct_answer") if q else None,
            "explanation": q.get("explanation") if q else None,
            "player1": {
                "correct": p1.current_answer_correct,
                "response_time_ms": round(p1.current_answer_time),
                "damage_dealt": p1_damage,
                "combo_streak": p1.combo_streak,
                "hp": p1.hp,
            },
            "player2": {
                "correct": p2.current_answer_correct,
                "response_time_ms": round(p2.current_answer_time),
                "damage_dealt": p2_damage,
                "combo_streak": p2.combo_streak,
                "hp": p2.hp,
            },
        }
        await self.broadcast_to_battle(battle, resolve_data)

        # Check for battle end
        if p1.hp <= 0 or p2.hp <= 0 or battle.question_number >= battle.max_questions:
            await self._end_battle(battle)
        else:
            # Short delay then next question
            await asyncio.sleep(2)
            await self._serve_question(battle)

    async def _end_battle(self, battle: PvPBattle, reason: str = "normal"):
        """End the PvP battle and determine winner."""
        battle.state = PvPState.FINISHED
        p1, p2 = battle.player1, battle.player2

        if p1.hp > p2.hp:
            winner_id = p1.player_id
            loser_id = p2.player_id
        elif p2.hp > p1.hp:
            winner_id = p2.player_id
            loser_id = p1.player_id
        else:
            # Tie — whoever had more correct answers wins, else whoever was faster
            if p1.correct_answers > p2.correct_answers:
                winner_id = p1.player_id
                loser_id = p2.player_id
            elif p2.correct_answers > p1.correct_answers:
                winner_id = p2.player_id
                loser_id = p1.player_id
            else:
                winner_id = p1.player_id  # Default p1 wins on perfect tie
                loser_id = p2.player_id

        # Update player models
        w = get_or_create_player(winner_id)
        l = get_or_create_player(loser_id)
        w_xp = 50 + battle.difficulty * 10
        l_xp = 15 + battle.difficulty * 3
        w.record_battle_result(won=True, xp_earned=w_xp)
        l.record_battle_result(won=False, xp_earned=l_xp)
        w.update_pvp_rating(l.pvp_rating, won=True)
        l.update_pvp_rating(w.pvp_rating, won=False)

        end_data = {
            "type": "battle_end",
            "reason": reason,
            "winner": winner_id,
            "battle_summary": battle.to_dict(),
            "rewards": {
                "winner_xp": w_xp,
                "loser_xp": l_xp,
            },
        }
        await self.broadcast_to_battle(battle, end_data)

        # Cleanup
        _player_to_battle.pop(p1.player_id, None)
        _player_to_battle.pop(p2.player_id, None)
        # Keep battle record for a while
        logger.info("PvP Battle %s ended. Winner: %s", battle.battle_id, winner_id)

    def leave_queue(self, player_id: str):
        """Remove a player from the matchmaking queue."""
        global _matchmaking_queue
        _matchmaking_queue = [e for e in _matchmaking_queue if e.player_id != player_id]

    async def handle_disconnect(self, player_id: str):
        """Handle player disconnection."""
        self.leave_queue(player_id)
        battle_id = _player_to_battle.get(player_id)
        if battle_id:
            battle = _active_pvp_battles.get(battle_id)
            if battle and battle.state == PvPState.ACTIVE:
                opponent = battle.get_opponent(player_id)
                if opponent:
                    await self.send_to_player(opponent.websocket, {
                        "type": "opponent_disconnected",
                        "message": "Your opponent has disconnected. You win!",
                    })
                await self._end_battle(battle, reason="disconnect")

    def get_queue_size(self) -> int:
        return len(_matchmaking_queue)


# Singleton
pvp_manager = PvPManager()
