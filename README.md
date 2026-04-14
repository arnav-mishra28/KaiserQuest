# ⚔️ KaiserQuest v1.1
## Learn. Battle. Become Kaiser.

> A 2.5D pixel RPG where knowledge is your weapon.  
> Built with **Godot 4.2** · **FastAPI** · **PyTorch**

---

## 🚀 Quick Start

### Step 1 — Install Godot 4.2+
Download free from **https://godotengine.org**  
Extract and run — no installation needed.

### Step 2 — Open Project
1. Launch Godot Engine
2. Click **Import** → navigate to `KaiserQuest/` folder
3. Select `project.godot` → click **Import & Edit**
4. Press **F5** or the ▶ Play button

### Step 3 — Name Your Character
Type your name and press **ENTER** to begin your journey.

---

## 🎮 Controls

| Key | Action |
|-----|--------|
| **Arrow Keys** | Move (hold for continuous movement) |
| **ENTER / Space** | Interact with NPCs · Confirm answers |
| **↑ / ↓** | Navigate answer options in battle |
| **ESC** | Return to World Map |
| **F5** | Reset all save data |
| **F4** | Force return to World Map |

---

## 🗺️ Game Flow

```
Title Screen  →  Name Entry  →  World Map
      ↓
Enter a City (Mathopolis / Lexicon City / Harmonia)
      ↓
Explore Town:
  • Talk to ? Teacher NPCs   → +75 XP each (3 teachers = 225 XP)
  • Talk to regular NPCs     → +50 XP first time (5 NPCs = 250 XP)
  • Collect glowing items    → +100 XP each (3 items = 300 XP)
  • Accept item gift NPC     → +150 XP (one-time)
  • Complete side quest      → +200 XP + 50 Gold
  • Win Knowledge Duel (⚔)  → +150 XP each (2 duels = 300 XP)
      ↓
Reach Level 5 (400 XP needed) + Learn 1 Teacher Lesson
      ↓
Enter Gym → Knowledge Battle
  Correct answer → YOU attack enemy
  Wrong answer   → Enemy attacks YOU
      ↓
Win → Badge Earned → World Map
```

---

## 💡 How to Reach Level 5 Fast

Level 5 requires **400 XP**. Here's the fastest route:

| Action | XP Gained |
|--------|-----------|
| Talk to 3 Teacher NPCs (? icon) | **225 XP** |
| Talk to 5 regular NPCs | **250 XP** |
| ✅ **Already at Level 5!** | |
| Collect 3 items | +300 XP bonus |
| Win 2 duels | +300 XP bonus |
| Complete side quest | +200 XP bonus |
| Item trade NPC | +150 XP bonus |
| **Total possible per town** | **~1,425 XP** |

---

## ⚔️ Battle System

The gym battle is **turn-based** with an HP system:

- **Correct answer** → You attack the enemy (red slash animation, enemy loses HP)
- **Wrong answer** → Enemy attacks you (screen flash, you lose HP)
- When **enemy HP reaches 0** → You win the badge!
- When **your HP reaches 0** → You lose and must train more

Your HP **restores** on level-up and at rest towns on the World Map.

---

## 👥 NPC Types

| Icon | Type | What they do |
|------|------|-------------|
| **?** (yellow) | Teacher | Full lesson + **75 XP** (first time) |
| **!** (yellow) | Quest Giver | Starts a collection quest → **200 XP** reward |
| **⚔** (red) | Duel Challenger | Knowledge duel → **150 XP** if you win |
| (no icon) | Regular NPC | Chat → **50 XP** first time |
| (brown coat) | Item Keeper | One-time item gift → **150 XP** |

---

## 🌍 The Three Worlds

| World | City | Gym Name | Leader | Subject |
|-------|------|----------|--------|---------|
| ➗ Math | Mathopolis | Variable Citadel | Prof. Axiom | Algebra |
| 📘 Language | Lexicon City | Noun Sanctum | Lexis | English |
| 🎵 Music | Harmonia | Harmony Hall | Maestro Resonus | Music Theory |

Each world has 3 Teacher NPCs, 5 regular NPCs, 3 collectibles, 1 quest, 2 duels, and 1 item trade.

---

## 🐛 Bugs Fixed in v1.1

### Bug 1: Player going out of bounds
**Root cause:** Player's `_is_walkable()` only checked the blocked tile list, not the actual map grid dimensions.  
**Fix:** Added hard bounds check `if p.x < 0 or p.x >= map_cols or p.y < 0 or p.y >= map_rows` as the first check. Also passes `map_cols` and `map_rows` from World to Player on init.

### Bug 2: Camera following player out of bounds
**Root cause:** Camera was computed from player pixel position but not clamped to the world pixel dimensions.  
**Fix:** Camera calculation now uses `clamp(px.x - 240, 0, COLS*TS - 480)` — hard-capped to visible area.

### Bug 3: Infinite NPC dialog loop
**Root cause:** Duel NPCs were launching a new dialog inside the previous dialog's callback, creating a loop. Also, `_dialog_open` flag was cleared before the callback ran.  
**Fix:**
1. Added `_busy` re-entrant guard in `DialogBox.show_lines()` — if already open, silently ignores new calls
2. Duel NPCs now use a **timer** (0.8s delay) to launch the duel scene, NOT a dialog callback
3. Added `_interact_cool` cooldown (0.3s) after dialog closes to prevent immediate re-trigger
4. Callback cleared BEFORE being called to prevent double-fire

---

## 🏗️ Tech Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Game Engine | **Godot 4.2** | 2.5D pixel rendering, physics, input |
| Scripting | **GDScript** | All game logic |
| Visuals | `draw_rect()` + Gen 2 palette | No external art assets needed |
| Backend | **FastAPI** (Python) | AI question server |
| AI Layer | **PyTorch** (via backend) | Adaptive difficulty |
| Save System | JSON → `user://` | Cross-platform persistence |

---

## 🤖 Backend Setup (FastAPI + PyTorch)

The game works fully offline. The backend enables AI-adaptive questions.

### Install & Run

```bash
cd KaiserQuest/backend/

# Install dependencies
pip install fastapi uvicorn torch numpy pydantic

# Start the server
uvicorn main:app --reload --port 8000
```

The server runs at **http://localhost:8000**

### API Reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Health check |
| `/health` | GET | Status + timestamp |
| `/questions/adaptive` | POST | Get AI-selected questions |
| `/session/start` | POST | Start player session |
| `/session/answer` | POST | Record answer + update AI |
| `/session/{id}/end` | POST | End session, get summary |
| `/leaderboard/{world}` | GET | Top players |

### Example: Get Adaptive Questions

```bash
curl -X POST http://localhost:8000/questions/adaptive \
  -H "Content-Type: application/json" \
  -d '{
    "player_id": "player_1",
    "world": "math",
    "level": 3,
    "count": 5,
    "weak_topics": ["variables"],
    "accuracy": 0.4,
    "avg_time_ms": 8000
  }'
```

---

## 🔗 Godot ↔ Backend Connection

The Godot game connects to the backend via HTTP (built-in `HTTPRequest` node).  
Located in `scripts/autoload/AdaptiveAI.gd` — when `GameManager.use_backend = true`, it calls the FastAPI server for questions instead of the local question bank.

**To enable:**
1. Start the backend server (see above)
2. In game, the `GameManager.use_backend` flag (default `false`) can be set to `true`

**The backend is free** — runs locally on your machine, no cloud needed.

---

## 🧠 AI Pipeline

```
Player answers question
        ↓
AdaptiveAI.record_answer(topic, correct)
        ↓
Tracks: accuracy per topic | avg answer speed
        ↓
get_weak_topics() → topics below 60% accuracy
        ↓
adaptive_select() → prioritizes weak topics in next battle
        ↓ (if backend running)
POST /questions/adaptive → PyTorch model predicts difficulty
        ↓
Player gets questions matched to their level
```

---

## 📁 Project Structure

```
KaiserQuest/
├── project.godot
├── assets/
│   └── icon.svg
├── scenes/
│   └── Main.tscn                  ← Entry point
├── scripts/
│   ├── Main.gd                    ← Scene orchestrator
│   ├── autoload/
│   │   ├── GameManager.gd         ← HP, XP, Gold, badges, save/load
│   │   ├── AdaptiveAI.gd          ← Weak topic tracking + backend bridge
│   │   └── QuestManager.gd        ← Quest state queries
│   ├── player/
│   │   └── Player.gd              ← Hold-to-move (FIXED), bounds check
│   ├── npc/
│   │   └── NPC.gd                 ← Teacher/Quest/Duel NPC sprites
│   ├── world/
│   │   ├── World.gd               ← Town map, camera (FIXED), NPC loop (FIXED)
│   │   └── TileRenderer.gd        ← Image-based tile generator
│   ├── battle/
│   │   ├── BattleSystem.gd        ← Gym battle (correct=attack, wrong=damage)
│   │   └── DuelSystem.gd          ← Knowledge duel with timer + XP
│   ├── ui/
│   │   ├── DialogBox.gd           ← FIXED: re-entrant guard, no infinite loop
│   │   ├── HUD.gd                 ← HP/XP/Gold bars
│   │   ├── TitleScreen.gd         ← Animated title screen
│   │   └── WorldMap.gd            ← Kanto-style scrolling region map
│   └── data/
│       ├── AlgebraQuestions.gd    ← Math question bank (12 questions)
│       ├── EnglishQuestions.gd    ← Language question bank (12 questions)
│       └── MusicQuestions.gd      ← Music theory bank (12 questions)
└── backend/
    ├── main.py                    ← FastAPI + PyTorch adaptive server
    └── requirements.txt
```

---

## 🔮 What's Planned Next

| Phase | Feature |
|-------|---------|
| Phase 7 | Free pixel art assets (Kenney RPG pack integration) |
| Phase 8 | 20 Gym leaders per world (full badge chain) |
| Phase 9 | Silver Mountain final boss |
| Phase 10 | Kaiser certification screen |
| Phase 11 | Sound effects + music |
| Phase 12 | Mobile export (Android) |

---

## 🎨 Visual Style

The game uses **2.5D isometric-lite** rendering — all tiles drawn in GDScript:

- **Painter's algorithm**: tiles + objects rendered back-to-front per row
- **Front face trick**: buildings show a visible front wall below the roof (classic Gen 1/2 Pokémon technique)
- **Gen 2 palette**: 4-tone checkered grass, rounded tree crowns, layered shadows
- **Per-world palettes**: Math = GBC green, English = sandy warm, Music = deep purple
- **Zero external assets**: every pixel generated via `draw_rect()` at runtime

---

*KaiserQuest v1.1 — Built with Godot 4.2 · FastAPI · PyTorch · Zero Budget*
