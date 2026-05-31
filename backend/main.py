"""
KaiserQuest Backend - FastAPI Server
A Pokemon-style educational RPG backend with adaptive difficulty,
PvE/PvP battles, and voice AI integration.

Run with: uvicorn main:app --reload --host 0.0.0.0 --port 8000
"""

from __future__ import annotations

import logging
import time
import uuid
from contextlib import asynccontextmanager
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, HTTPException, Query, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# ---------------------------------------------------------------------------
# Configure logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(name)-30s | %(levelname)-7s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("kaiserquest.main")

# ---------------------------------------------------------------------------
# Local imports (models & services)
# ---------------------------------------------------------------------------
from models.player_model import (
    PlayerModel,
    get_or_create_player,
    get_player,
    list_players,
)
from models.question_generator import (
    get_questions,
    get_single_question,
    check_answer,
    get_available_subjects,
    reload_banks,
)
from models.difficulty_adapter import difficulty_adapter
from services.battle_service import (
    start_battle,
    process_battle_answer,
    get_battle,
    cleanup_old_battles,
)
from services.pvp_service import pvp_manager
from services.voice_service import speech_to_text, text_to_speech, voice_answer


# ---------------------------------------------------------------------------
# Application lifespan
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("=" * 60)
    logger.info("  KaiserQuest Backend starting up")
    logger.info("=" * 60)
    # Pre-load question banks
    subjects = get_available_subjects()
    total_topics = sum(len(v) for v in subjects.values())
    logger.info("Loaded %d subjects with %d topics", len(subjects), total_topics)
    for subj, topics in subjects.items():
        logger.info("  %s: %s", subj, ", ".join(topics))
    logger.info("Difficulty adapter backend: %s", difficulty_adapter.backend_name)
    yield
    logger.info("KaiserQuest Backend shutting down")
    cleanup_old_battles()


# ---------------------------------------------------------------------------
# FastAPI app
# ---------------------------------------------------------------------------
app = FastAPI(
    title="KaiserQuest API",
    description=(
        "Backend for KaiserQuest — a Pokemon-style educational RPG. "
        "Covers Math (Algebra), English, and Music Theory with adaptive "
        "difficulty, PvE battles, PvP WebSocket battles, and voice AI."
    ),
    version="1.0.0",
    lifespan=lifespan,
)

# CORS — allow Unity WebGL and localhost dev
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ═══════════════════════════════════════════════════════════════════════════
# Pydantic request / response models
# ═══════════════════════════════════════════════════════════════════════════
class AnswerRequest(BaseModel):
    question_id: str = Field(..., description="The ID of the question being answered")
    player_id: str = Field(..., description="The player's unique ID")
    subject: str = Field(..., description="Subject: math, english, or music")
    topic: str = Field(..., description="Topic within the subject")
    answer: str = Field(..., description="The player's answer")
    response_time_ms: float = Field(0, description="Time taken to answer in milliseconds")
    difficulty: int = Field(2, ge=1, le=5, description="Difficulty level of the question")


class BattleStartRequest(BaseModel):
    player_id: str
    subject: str = "math"
    topic: str = "variables"
    difficulty: Optional[int] = Field(None, ge=1, le=5, description="Override difficulty (None = adaptive)")


class BattleAnswerRequest(BaseModel):
    battle_id: str
    player_answer: str


class PlayerUpdateRequest(BaseModel):
    username: Optional[str] = None
    xp_add: Optional[int] = None


class PlayerCreateRequest(BaseModel):
    player_id: Optional[str] = None
    username: str = ""


class VoiceSTTRequest(BaseModel):
    audio_base64: str = Field(..., description="Base64-encoded audio data")
    language: str = "en"


class VoiceTTSRequest(BaseModel):
    text: str = Field(..., description="Text to convert to speech")
    language: str = "en"


# ═══════════════════════════════════════════════════════════════════════════
# Health / Info
# ═══════════════════════════════════════════════════════════════════════════
@app.get("/", tags=["Health"])
async def root():
    """Health check and API info."""
    return {
        "name": "KaiserQuest API",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "questions": "/questions/{subject}/{topic}",
            "answer": "/answer",
            "battle_start": "/battle/start",
            "battle_answer": "/battle/answer",
            "pvp": "ws://host/pvp/battle",
            "player_stats": "/player/{id}/stats",
            "adaptive": "/adaptive/difficulty/{player_id}",
            "subjects": "/subjects",
        },
    }


@app.get("/subjects", tags=["Questions"])
async def list_subjects():
    """List all available subjects and their topics."""
    return get_available_subjects()


# ═══════════════════════════════════════════════════════════════════════════
# Questions
# ═══════════════════════════════════════════════════════════════════════════
@app.get("/questions/{subject}/{topic}", tags=["Questions"])
async def get_questions_endpoint(
    subject: str,
    topic: str,
    difficulty: Optional[int] = Query(None, ge=1, le=5, description="Difficulty 1-5"),
    count: int = Query(5, ge=1, le=20, description="Number of questions"),
    player_id: Optional[str] = Query(None, description="Player ID for adaptive difficulty"),
):
    """
    Retrieve questions for a given subject and topic.
    If player_id is provided and difficulty is not, uses adaptive difficulty.
    """
    # Use adaptive difficulty if player_id given and no explicit difficulty
    if player_id and difficulty is None:
        player = get_player(player_id)
        if player:
            difficulty = difficulty_adapter.recommend_for_player(player, subject, topic)
            logger.info("Adaptive difficulty for %s on %s/%s: %d", player_id, subject, topic, difficulty)

    questions = get_questions(subject, topic, difficulty=difficulty, count=count)
    if not questions:
        raise HTTPException(
            status_code=404,
            detail=f"No questions found for {subject}/{topic} at difficulty {difficulty}",
        )

    # Strip correct answers from response (don't reveal to client)
    safe_questions = []
    for q in questions:
        safe_q = {
            "id": q["id"],
            "question": q["question"],
            "options": q.get("options", []),
            "difficulty": q.get("difficulty"),
            "topic": q.get("topic", topic),
            "subject": q.get("subject", subject),
        }
        safe_questions.append(safe_q)

    return {
        "subject": subject,
        "topic": topic,
        "difficulty": difficulty,
        "count": len(safe_questions),
        "questions": safe_questions,
    }


# ═══════════════════════════════════════════════════════════════════════════
# Answer Submission
# ═══════════════════════════════════════════════════════════════════════════
@app.post("/answer", tags=["Questions"])
async def submit_answer(req: AnswerRequest):
    """
    Submit an answer to a question and get immediate feedback.
    Updates player stats and returns correctness, explanation, and XP.
    """
    # Look up the question from the bank to verify the correct answer
    questions = get_questions(req.subject, req.topic, count=50)
    question = next((q for q in questions if q["id"] == req.question_id), None)

    if not question:
        raise HTTPException(status_code=404, detail=f"Question {req.question_id} not found")

    is_correct = check_answer(question, req.answer)

    # Update player model
    player = get_or_create_player(req.player_id)
    player.record_answer(
        subject=req.subject,
        topic=req.topic,
        correct=is_correct,
        response_time_ms=req.response_time_ms,
        difficulty=req.difficulty,
    )

    # Award XP
    xp = 0
    leveled_up = False
    if is_correct:
        xp = 5 + req.difficulty * 3
        topic_stats = player.get_subject(req.subject).get_topic(req.topic)
        if topic_stats.current_streak >= 3:
            xp += topic_stats.current_streak * 2  # Streak bonus
        leveled_up = player.add_xp(xp)

    # Feed back to adaptive model
    topic_stats = player.get_subject(req.subject).get_topic(req.topic)
    difficulty_adapter.record_outcome(
        accuracy=topic_stats.accuracy,
        avg_response_time_ms=topic_stats.avg_response_time_ms,
        current_streak=topic_stats.current_streak,
        topic_mastery=topic_stats.mastery_score,
        player_level=player.level,
        was_correct=is_correct,
        question_difficulty=req.difficulty,
    )

    return {
        "correct": is_correct,
        "correct_answer": question.get("correct_answer"),
        "explanation": question.get("explanation", ""),
        "xp_earned": xp,
        "leveled_up": leveled_up,
        "new_level": player.level if leveled_up else None,
        "streak": topic_stats.current_streak,
        "topic_accuracy": round(topic_stats.accuracy, 4),
        "topic_mastery": round(topic_stats.mastery_score, 2),
    }


# ═══════════════════════════════════════════════════════════════════════════
# Player Management
# ═══════════════════════════════════════════════════════════════════════════
@app.post("/player/create", tags=["Player"])
async def create_player(req: PlayerCreateRequest):
    """Create a new player or return existing."""
    pid = req.player_id or str(uuid.uuid4())
    player = get_or_create_player(pid, req.username)
    if req.username:
        player.username = req.username
    return {"player_id": player.player_id, "username": player.username, "level": player.level}


@app.get("/player/{player_id}/stats", tags=["Player"])
async def get_player_stats(player_id: str):
    """Get comprehensive player statistics."""
    player = get_player(player_id)
    if not player:
        raise HTTPException(status_code=404, detail=f"Player {player_id} not found")
    return player.to_dict()


@app.post("/player/{player_id}/update", tags=["Player"])
async def update_player(player_id: str, req: PlayerUpdateRequest):
    """Update player profile (username, add XP, etc.)."""
    player = get_player(player_id)
    if not player:
        raise HTTPException(status_code=404, detail=f"Player {player_id} not found")

    if req.username:
        player.username = req.username
    leveled_up = False
    if req.xp_add and req.xp_add > 0:
        leveled_up = player.add_xp(req.xp_add)

    return {
        "player_id": player.player_id,
        "username": player.username,
        "level": player.level,
        "xp": player.xp,
        "leveled_up": leveled_up,
    }


@app.get("/players", tags=["Player"])
async def get_all_players():
    """List all players (for leaderboard / debug)."""
    players = list_players()
    return {
        "count": len(players),
        "players": [
            {
                "player_id": p.player_id,
                "username": p.username,
                "level": p.level,
                "pvp_rating": p.pvp_rating,
                "overall_accuracy": round(p.overall_accuracy, 4),
            }
            for p in sorted(players, key=lambda x: x.pvp_rating, reverse=True)
        ],
    }


# ═══════════════════════════════════════════════════════════════════════════
# Adaptive Difficulty
# ═══════════════════════════════════════════════════════════════════════════
@app.get("/adaptive/difficulty/{player_id}", tags=["Adaptive"])
async def get_adaptive_difficulty(
    player_id: str,
    subject: str = Query("math", description="Subject"),
    topic: str = Query("variables", description="Topic"),
):
    """Get the ML-recommended difficulty level for a player on a specific topic."""
    player = get_player(player_id)
    if not player:
        raise HTTPException(status_code=404, detail=f"Player {player_id} not found")

    recommended = difficulty_adapter.recommend_for_player(player, subject, topic)
    topic_stats = player.get_subject(subject).get_topic(topic)

    return {
        "player_id": player_id,
        "subject": subject,
        "topic": topic,
        "recommended_difficulty": recommended,
        "model_backend": difficulty_adapter.backend_name,
        "player_stats": {
            "accuracy": round(topic_stats.accuracy, 4),
            "avg_response_time_ms": round(topic_stats.avg_response_time_ms, 1),
            "current_streak": topic_stats.current_streak,
            "mastery_score": round(topic_stats.mastery_score, 2),
            "total_attempts": topic_stats.total_attempts,
        },
    }


# ═══════════════════════════════════════════════════════════════════════════
# PvE Battle
# ═══════════════════════════════════════════════════════════════════════════
@app.post("/battle/start", tags=["Battle"])
async def battle_start(req: BattleStartRequest):
    """Start a new PvE battle against an NPC enemy."""
    # Validate subject/topic
    subjects = get_available_subjects()
    if req.subject not in subjects:
        raise HTTPException(status_code=400, detail=f"Unknown subject: {req.subject}")
    if req.topic not in subjects.get(req.subject, []):
        raise HTTPException(
            status_code=400,
            detail=f"Unknown topic '{req.topic}' for subject '{req.subject}'. Available: {subjects.get(req.subject, [])}",
        )

    battle = start_battle(
        player_id=req.player_id,
        subject=req.subject,
        topic=req.topic,
        difficulty=req.difficulty,
    )
    return battle.to_dict()


@app.post("/battle/answer", tags=["Battle"])
async def battle_answer(req: BattleAnswerRequest):
    """Submit an answer during a PvE battle."""
    battle = get_battle(req.battle_id)
    if not battle:
        raise HTTPException(status_code=404, detail=f"Battle {req.battle_id} not found")

    result = process_battle_answer(req.battle_id, req.player_answer)
    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error"])

    return result


@app.get("/battle/{battle_id}", tags=["Battle"])
async def battle_status(battle_id: str):
    """Get the current state of a battle."""
    battle = get_battle(battle_id)
    if not battle:
        raise HTTPException(status_code=404, detail=f"Battle {battle_id} not found")
    return battle.to_dict()


# ═══════════════════════════════════════════════════════════════════════════
# PvP WebSocket Battle
# ═══════════════════════════════════════════════════════════════════════════
@app.websocket("/pvp/battle")
async def pvp_battle_ws(websocket: WebSocket):
    """
    WebSocket endpoint for PvP battles.

    Protocol:
    1. Client connects and sends: {"type": "join", "player_id": "...", "subject": "...", "topic": "..."}
    2. Server queues player for matchmaking or starts a battle if opponent found.
    3. Both players receive questions simultaneously.
    4. Client sends answers: {"type": "answer", "battle_id": "...", "answer": "..."}
    5. Server resolves and sends results to both players.
    """
    await websocket.accept()
    player_id = None

    try:
        while True:
            data = await websocket.receive_json()
            msg_type = data.get("type", "")

            if msg_type == "join":
                player_id = data.get("player_id", str(uuid.uuid4()))
                subject = data.get("subject", "math")
                topic = data.get("topic", "variables")
                await pvp_manager.join_queue(player_id, websocket, subject, topic)

            elif msg_type == "answer":
                battle_id = data.get("battle_id", "")
                answer = data.get("answer", "")
                if battle_id and answer:
                    await pvp_manager.handle_answer(battle_id, player_id or "", answer)

            elif msg_type == "leave":
                if player_id:
                    pvp_manager.leave_queue(player_id)
                await websocket.send_json({"type": "left_queue"})

            elif msg_type == "ping":
                await websocket.send_json({"type": "pong"})

    except WebSocketDisconnect:
        logger.info("WebSocket disconnected: %s", player_id)
        if player_id:
            await pvp_manager.handle_disconnect(player_id)
    except Exception as e:
        logger.exception("WebSocket error for %s: %s", player_id, e)
        if player_id:
            await pvp_manager.handle_disconnect(player_id)


@app.get("/pvp/queue", tags=["PvP"])
async def pvp_queue_status():
    """Get the current PvP matchmaking queue size."""
    return {"queue_size": pvp_manager.get_queue_size()}


# ═══════════════════════════════════════════════════════════════════════════
# Voice AI (STT + TTS stubs)
# ═══════════════════════════════════════════════════════════════════════════
@app.post("/voice/stt", tags=["Voice"])
async def voice_stt(req: VoiceSTTRequest):
    """
    Speech-to-Text: Convert audio to text.
    Accepts base64-encoded audio. Returns transcribed text.
    """
    import base64
    try:
        audio_bytes = base64.b64decode(req.audio_base64)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid base64 audio data")

    result = await speech_to_text(audio_bytes, req.language)
    return result


@app.post("/voice/tts", tags=["Voice"])
async def voice_tts(req: VoiceTTSRequest):
    """
    Text-to-Speech: Convert text to audio.
    Returns base64-encoded MP3 audio.
    """
    if not req.text.strip():
        raise HTTPException(status_code=400, detail="Text cannot be empty")

    result = await text_to_speech(req.text, req.language)
    return result


# ═══════════════════════════════════════════════════════════════════════════
# Admin / Debug
# ═══════════════════════════════════════════════════════════════════════════
@app.post("/admin/reload-questions", tags=["Admin"])
async def admin_reload_questions():
    """Force reload of all question banks from disk."""
    reload_banks()
    subjects = get_available_subjects()
    return {"message": "Question banks reloaded", "subjects": subjects}


@app.get("/admin/difficulty-test", tags=["Admin"])
async def admin_difficulty_test(
    accuracy: float = Query(0.7, ge=0, le=1),
    avg_response_time_ms: float = Query(5000, ge=0),
    current_streak: int = Query(3, ge=0),
    topic_mastery: float = Query(50, ge=0, le=100),
    player_level: int = Query(5, ge=1),
):
    """Test the difficulty adapter with custom parameters."""
    recommended = difficulty_adapter.predict_difficulty(
        accuracy=accuracy,
        avg_response_time_ms=avg_response_time_ms,
        current_streak=current_streak,
        topic_mastery=topic_mastery,
        player_level=player_level,
    )
    return {
        "input": {
            "accuracy": accuracy,
            "avg_response_time_ms": avg_response_time_ms,
            "current_streak": current_streak,
            "topic_mastery": topic_mastery,
            "player_level": player_level,
        },
        "recommended_difficulty": recommended,
        "backend": difficulty_adapter.backend_name,
    }


# ═══════════════════════════════════════════════════════════════════════════
# Run directly
# ═══════════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info",
    )
