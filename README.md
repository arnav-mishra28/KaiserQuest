# ⚔️ KaiserQuest— Learn. Battle. Become Kaiser.

## 🚀 Quick Start (5 minutes)

### 1. Install Godot 4.2+
Download from https://godotengine.org (free, ~80MB)
No install needed — just extract and run.

### 2. Open the Game
1. Launch Godot Engine
2. Click **Import** → select the `KaiserQuest/` folder → `project.godot`
3. Press **F5** (or ▶ Play)

### 3. Start Playing
- **Arrow Keys / WASD** — Move player (hold to keep moving!)
- **ENTER / Space** — Interact with NPCs, advance dialog, confirm answers
- **↑↓** — Select answers in battle
- **ESC** — Return to World Map
- **F5** — Reset save data
- **F4** — Force return to world map

---

## 🎮 How to Reach Level 5 (Unlock the Gym)

You need **400 XP** to reach Level 5. Here's how to get it fast:

| Source | XP | Notes |
|--------|-----|-------|
| Teacher lessons (×3) | 75 each = **225 XP** | Talk to NPCs with **?** icons |
| Regular NPC chats (×5) | 50 each = **250 XP** | Talk to everyone! |
| Collect 3 items | 100 each = **300 XP** | Glowing items on the map |
| Win a duel | **150 XP** | Challenge ⚔ NPCs |
| Item trade NPC | **150 XP** | One-time gift |
| Random walk bonus | 5-15 XP/step | Small chance per step |
| Quest completion | **200 XP** | Find all 3 quest items |

**Talk to ALL NPCs first** — that's 475 XP right there, well past Level 5!

---

## 🌍 Game Structure

```
Title Screen
    ↓ ENTER
Name Entry (type your name)
    ↓
World Map (Kanto-style region)
    ↓ walk to city
Town (Mathopolis / Lexicon City / Harmonia)
    ↓ explore + learn
Gym Battle (Level 5 required + 1 teacher lesson)
    ↓ win
Badge earned → back to World Map
```

## ⚔️ Battle System

- **Correct answer → You attack** (enemy loses HP, red flash)
- **Wrong answer → You take damage** (player loses HP, blue flash)
- **3 lives** before game over
- Enemy HP depleted = Victory + Badge + XP

## 👥 NPC Types

| Icon | Type | Reward |
|------|------|--------|
| **?** | Teacher | Full lesson + 75 XP (once) |
| **!** | Quest Giver | Quest + 200 XP on completion |
| **⚔** | Duel Challenger | 150 XP if you win |
| (none) | Regular NPC | 50 XP first talk |

---

## 🏗️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Game Engine | **Godot 4.2** — 2.5D pixel RPG |
| Language | **GDScript** — Python-like, fast |
| Rendering | Pure `draw_rect()` — no external assets! |
| Backend | **FastAPI** (Python) |
| AI | **PyTorch** adaptive difficulty model |
| Save | JSON files in user data directory |

---

## 🤖 FastAPI Backend (Optional)

The game works standalone. For AI-powered adaptive questions:

```bash
cd backend/
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

Then in Godot, set `GameManager.use_backend = true`

API endpoints:
- `GET  /` — Health check
- `POST /questions/adaptive` — Get AI-selected questions
- `POST /session/start` — Start a learning session
- `POST /session/answer` — Record an answer
- `POST /session/{id}/end` — End session, get summary
- `GET  /leaderboard/{world}` — Top players

---

## 📁 Project Structure

```
KaiserQuest/
├── project.godot
├── assets/icon.svg
├── scenes/Main.tscn
├── scripts/
│   ├── Main.gd                    ← Scene orchestrator
│   ├── autoload/
│   │   ├── GameManager.gd         ← Global state, HP, XP, save/load
│   │   ├── AdaptiveAI.gd          ← Weak topic detection
│   │   └── QuestManager.gd        ← Quest state
│   ├── player/
│   │   └── Player.gd              ← Hold-to-move, pixel art sprite
│   ├── npc/
│   │   └── NPC.gd                 ← Teacher/Quest/Duel NPCs
│   ├── world/
│   │   └── World.gd               ← 2.5D town, all NPCs, interactions
│   ├── battle/
│   │   ├── BattleSystem.gd        ← Gym battle (correct=attack)
│   │   └── DuelSystem.gd          ← PvP knowledge duel with timer
│   ├── ui/
│   │   ├── DialogBox.gd           ← Typewriter dialog
│   │   ├── HUD.gd                 ← HP/XP/Gold bars
│   │   ├── TitleScreen.gd         ← Animated title
│   │   └── WorldMap.gd            ← Kanto-style region map
│   └── data/
│       ├── AlgebraQuestions.gd
│       ├── EnglishQuestions.gd
│       └── MusicQuestions.gd
└── backend/
    ├── main.py                    ← FastAPI + PyTorch server
    └── requirements.txt
```

---

## 🔮 XP Sources Summary

With all NPCs + quests + duels in ONE town, you can earn **1,800+ XP** — 
that's **Level 22+** before even touching the gym!

The gym only requires Level 5 (400 XP). You'll hit it quickly.

---

*KaiserQuest v1.0 — Built with Godot 4 · FastAPI · PyTorch*
