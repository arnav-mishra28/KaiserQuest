# backend/main.py — KaiserQuest FastAPI + PyTorch backend
# Run: pip install fastapi uvicorn torch numpy pydantic
# Start: uvicorn main:app --reload --port 8000

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import json, random, time, math

app = FastAPI(title="KaiserQuest AI Backend", version="1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Question banks ────────────────────────────────────────────────────────────
QUESTION_BANK = {
    "math": [
        {"id":"m1","topic":"variables","difficulty":1,"q":"What does x represent in algebra?",
         "opts":["A fixed number","An unknown value","A math operation","A constant"],"ans":1},
        {"id":"m2","topic":"variables","difficulty":1,"q":"Solve: x + 4 = 9",
         "opts":["x=4","x=5","x=13","x=2"],"ans":1},
        {"id":"m3","topic":"linear","difficulty":2,"q":"Solve: 2x = 14",
         "opts":["x=7","x=12","x=28","x=2"],"ans":0},
        {"id":"m4","topic":"linear","difficulty":2,"q":"Solve: 3x + 1 = 10",
         "opts":["x=3","x=4","x=9","x=11"],"ans":0},
        {"id":"m5","topic":"functions","difficulty":3,"q":"If f(x) = 2x+1, find f(3)",
         "opts":["5","6","7","8"],"ans":2},
    ],
    "english": [
        {"id":"e1","topic":"nouns","difficulty":1,"q":"What is a noun?",
         "opts":["Action word","Describing word","Person/place/thing/idea","Connecting word"],"ans":2},
        {"id":"e2","topic":"nouns","difficulty":1,"q":"Which is a proper noun?",
         "opts":["city","river","London","book"],"ans":2},
        {"id":"e3","topic":"verbs","difficulty":2,"q":"Which is a verb?",
         "opts":["beautiful","quickly","London","ran"],"ans":3},
    ],
    "music": [
        {"id":"mu1","topic":"staff","difficulty":1,"q":"How many lines on a musical staff?",
         "opts":["3","4","5","6"],"ans":2},
        {"id":"mu2","topic":"notes","difficulty":1,"q":"How many beats does a whole note get?",
         "opts":["1","2","3","4"],"ans":3},
        {"id":"mu3","topic":"time","difficulty":2,"q":"In 4/4 time, beats per measure?",
         "opts":["2","3","4","8"],"ans":2},
    ],
}

# ── Player session storage (in-memory; use Redis/DB in production) ────────────
player_sessions = {}

# ── Simple PyTorch-inspired adaptive difficulty model ─────────────────────────
# Uses a basic weighted scoring system (no full neural net needed for MVP)
class AdaptiveModel:
    """Lightweight difficulty adapter — simulates PyTorch model behavior"""

    def __init__(self):
        # Weights: [accuracy_weight, speed_weight, difficulty_bias]
        self.weights = [0.6, 0.2, 0.2]

    def predict_difficulty(self, accuracy: float, avg_time_ms: float, current_level: int) -> int:
        """Returns suggested difficulty level 1-3"""
        # Normalize inputs
        acc_score   = accuracy                          # 0.0 - 1.0
        speed_score = max(0, 1 - avg_time_ms / 15000)  # fast = high score
        level_score = min(current_level / 20.0, 1.0)   # level contribution

        composite = (self.weights[0] * acc_score +
                     self.weights[1] * speed_score +
                     self.weights[2] * level_score)

        if composite < 0.35:   return 1
        elif composite < 0.65: return 2
        else:                   return 3

    def select_questions(self, pool: list, weak_topics: list, difficulty: int, count: int) -> list:
        """Prioritize weak topics, then filter by difficulty"""
        weak_q  = [q for q in pool if q["topic"] in weak_topics and q["difficulty"] <= difficulty + 1]
        normal_q = [q for q in pool if q["topic"] not in weak_topics and q["difficulty"] <= difficulty + 1]
        random.shuffle(weak_q); random.shuffle(normal_q)
        selected = weak_q + normal_q
        return selected[:count] if len(selected) >= count else (selected + pool)[:count]

adaptive_model = AdaptiveModel()

# ── Pydantic models ───────────────────────────────────────────────────────────
class SessionData(BaseModel):
    player_id: str
    world: str
    level: int
    accuracy: float = 0.5
    avg_time_ms: float = 5000.0
    weak_topics: List[str] = []

class AnswerRecord(BaseModel):
    player_id: str
    world: str
    question_id: str
    topic: str
    correct: bool
    time_ms: float

class QuestionRequest(BaseModel):
    player_id: str
    world: str
    level: int
    count: int = 5
    weak_topics: List[str] = []
    accuracy: float = 0.5
    avg_time_ms: float = 5000.0

# ── API Endpoints ─────────────────────────────────────────────────────────────
@app.get("/")
def root():
    return {"status": "KaiserQuest AI Backend running", "version": "1.0"}

@app.get("/health")
def health():
    return {"status": "healthy", "timestamp": time.time()}

@app.post("/questions/adaptive")
def get_adaptive_questions(req: QuestionRequest):
    """Returns AI-selected questions based on player performance"""
    pool = QUESTION_BANK.get(req.world, [])
    if not pool:
        raise HTTPException(404, f"No questions for world: {req.world}")

    diff = adaptive_model.predict_difficulty(req.accuracy, req.avg_time_ms, req.level)
    selected = adaptive_model.select_questions(pool, req.weak_topics, diff, req.count)

    return {
        "questions": selected,
        "suggested_difficulty": diff,
        "adapted_for": {
            "accuracy": req.accuracy,
            "weak_topics": req.weak_topics,
            "level": req.level
        }
    }

@app.post("/session/start")
def start_session(data: SessionData):
    """Initialize or retrieve player session"""
    player_sessions[data.player_id] = {
        "world": data.world,
        "level": data.level,
        "accuracy": data.accuracy,
        "avg_time_ms": data.avg_time_ms,
        "weak_topics": data.weak_topics,
        "answers": [],
        "started_at": time.time()
    }
    return {"status": "session_started", "player_id": data.player_id}

@app.post("/session/answer")
def record_answer(record: AnswerRecord):
    """Record a player's answer and update adaptive model"""
    pid = record.player_id
    if pid not in player_sessions:
        player_sessions[pid] = {"answers": [], "world": record.world}

    session = player_sessions[pid]
    session["answers"].append({
        "question_id": record.question_id,
        "topic": record.topic,
        "correct": record.correct,
        "time_ms": record.time_ms,
        "timestamp": time.time()
    })

    # Recompute accuracy
    answers = session["answers"]
    correct_count = sum(1 for a in answers if a["correct"])
    session["accuracy"] = correct_count / len(answers)

    # Update weak topics
    topic_stats = {}
    for a in answers:
        t = a["topic"]
        if t not in topic_stats: topic_stats[t] = [0, 0]
        topic_stats[t][1] += 1
        if a["correct"]: topic_stats[t][0] += 1

    session["weak_topics"] = [
        t for t, (c, total) in topic_stats.items()
        if total > 0 and c / total < 0.6
    ]

    return {
        "recorded": True,
        "session_accuracy": session["accuracy"],
        "weak_topics": session["weak_topics"]
    }

@app.get("/session/{player_id}")
def get_session(player_id: str):
    if player_id not in player_sessions:
        raise HTTPException(404, "Session not found")
    return player_sessions[player_id]

@app.post("/session/{player_id}/end")
def end_session(player_id: str):
    if player_id not in player_sessions:
        raise HTTPException(404, "Session not found")
    session = player_sessions.pop(player_id)
    answers = session.get("answers", [])
    correct = sum(1 for a in answers if a["correct"])
    return {
        "summary": {
            "total_questions": len(answers),
            "correct": correct,
            "accuracy": correct / max(len(answers), 1),
            "weak_topics": session.get("weak_topics", []),
            "xp_earned": correct * 30
        }
    }

@app.get("/leaderboard/{world}")
def get_leaderboard(world: str):
    """Simple mock leaderboard (connect to DB in production)"""
    return {
        "world": world,
        "top_players": [
            {"rank": 1, "name": "Arix", "level": 50, "badges": 5},
            {"rank": 2, "name": "Scholar", "level": 42, "badges": 4},
            {"rank": 3, "name": "Novice", "level": 20, "badges": 2},
        ]
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
