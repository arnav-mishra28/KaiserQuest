# 🏰 KaiserQuest

**A Pokemon-style educational RPG where knowledge is power.**

Learn Mathematics, English, and Music Theory by exploring the Kaiserland region, battling trainers with knowledge questions, defeating 20 Gym Leaders, and conquering Silver Mountain to become a **Kaiser** — a true master of knowledge.

---

## 🎮 Game Overview

You play as **Arix**, a young scholar in the Kaiserland region. Knowledge is fading from the world, and only by mastering subjects across Mathematics, Languages, and Music can you restore it. Travel through 22 cities, challenge 20 Gym Leaders, and prove your mastery at Silver Mountain.

### Core Mechanics
- **Pokemon-style exploration** — Grid-based top-down movement through a procedurally generated world
- **Knowledge battles** — Answer questions to deal damage to opponents; wrong answers hurt you
- **20 Gyms** — Each gym tests a specific topic (level-gated at multiples of 5)
- **Silver Mountain** — Final boss requires Level 100 + all 20 badges (3 attempts, 24hr cooldown)
- **Adaptive AI** — ML-powered difficulty scaling based on your performance
- **PvP Duels** — Challenge other players via WebSocket multiplayer

### Subjects & Topics
| Mathematics | Languages | Music |
|------------|-----------|-------|
| Variables | Grammar | Notes |
| Linear Equations | Vocabulary | Scales |
| Quadratics | Writing | Chords |
| Functions | Sentence Structure | Rhythm |
| Graphs | Word Forms | Time Signatures |
| Polynomials | Advanced English | Composition |

---

## 📁 Project Structure

```
KaiserQuest/
├── KaiserQuest-Unity/          # Unity 2022.3.20f1 Game
│   ├── Assets/
│   │   ├── Scenes/             # 3 scenes: MainMenu, SubjectSelect, Overworld
│   │   ├── Scripts/
│   │   │   ├── AI/             # AIClient.cs — Backend communication
│   │   │   ├── Battle/         # BattleManager.cs, QuestionBank.cs
│   │   │   ├── Camera/         # CameraFollow.cs — Pixel-perfect follow
│   │   │   ├── Core/           # GameManager, GameBootstrap, SceneLoader,
│   │   │   │   │               # PixelSpriteGenerator, SoundManager
│   │   │   │   └── Editor/     # TilesetGenerator, AudioGenerator, KaiserQuestSetup
│   │   │   ├── Gym/            # GymSystem.cs — 20-gym framework
│   │   │   ├── Multiplayer/    # PvPManager.cs — Knowledge duels
│   │   │   ├── NPC/            # DialogSystem.cs, NPCController.cs (8 NPC types)
│   │   │   ├── Player/         # PlayerController.cs — Grid movement
│   │   │   ├── Quests/         # SideQuestManager.cs — 7 side quests
│   │   │   ├── UI/             # UIManager.cs — MainMenu, HUD
│   │   │   └── World/          # ProceduralWorldGenerator, WorldManager
│   │   └── Resources/
│   │       └── Questions/      # 3 JSON question banks (~50+ questions each)
│   ├── Packages/               # Unity package manifest
│   └── ProjectSettings/        # 13 Unity settings files
│
├── Backend/                    # Python FastAPI Server
│   ├── main.py                 # 18+ API endpoints
│   ├── requirements.txt        # Dependencies
│   ├── models/                 # Player model, difficulty adapter (ML), question generator
│   ├── services/               # Battle service, PvP WebSocket, voice AI stubs
│   └── data/questions/         # 375 educational questions (15 topics × 25 each)
│       ├── math/               # 6 topic files
│       ├── english/            # 4 topic files
│       └── music/              # 5 topic files
│
└── README.md
```

---

## 🚀 Quick Start

### Prerequisites
- **Unity 2022.3.20f1** (LTS) — [Download](https://unity.com/releases/editor/whats-new/2022.3.20)
- **Python 3.9+** (for backend, optional)

### Step 1: Open Unity Project

1. Open **Unity Hub**
2. Click **"Add"** → Browse to `KaiserQuest-Unity/`
3. Select Unity **2022.3.20f1** as editor version
4. Click **Open** (first import takes ~3-5 minutes)

### Step 2: Generate Assets (First Time Only)

In Unity's menu bar:
1. **KaiserQuest > Generate All Assets** — Creates pixel art tilesets, characters, UI sprites
2. **KaiserQuest > Generate Audio** — Creates retro 8-bit sound effects and music

Or use the setup wizard:
- **KaiserQuest > Setup Project** — Guided setup window

### Step 3: Play!

1. Open `Assets/Scenes/Overworld.unity`
2. Press **Play ▶️**
3. Controls:
   - **WASD / Arrow Keys** — Move
   - **Z / Enter / Space** — Interact / Advance dialog
   - **M** — Toggle world map
   - **Esc** — Pause

### Step 4: Start Backend (Optional)

The backend provides adaptive AI difficulty and multiplayer:

```bash
cd Backend
pip install -r requirements.txt
python main.py
```

- Server: `http://localhost:8000`
- API Docs: `http://localhost:8000/docs`

---

## 🏗️ Architecture

### Unity Game (Frontend)
```
GameBootstrap → Creates all singletons → Generates world → Spawns player
     ↓
GameManager (global state) ←→ QuestionBank (loads JSON questions)
     ↓
ProceduralWorldGenerator → Perlin noise terrain + 22 cities + paths
     ↓
PlayerController ←→ NPCController → DialogSystem → BattleManager
     ↓                                                    ↓
CameraFollow (pixel-perfect)                    GymSystem (20 gyms)
     ↓                                                    ↓
SoundManager (SFX + Music)              SilverMountain (final boss)
```

### Python Backend
```
FastAPI Server
├── /questions/{subject}/{topic}  → Adaptive question selection
├── /answer                       → Answer validation + XP
├── /battle/start + /battle/answer → PvE battle logic
├── /pvp/battle (WebSocket)       → Real-time PvP duels
├── /adaptive/difficulty          → ML difficulty recommendation
└── /player/*                     → Player stats + leaderboard
```

### Adaptive AI (ML)
- **GradientBoostingRegressor** trained on player performance data
- Features: accuracy, speed, streak, topic mastery
- Auto-retrains every 50 gameplay observations
- Graceful fallback to rule-based system if sklearn unavailable

---

## 🎨 Asset Generation

All visual and audio assets are **procedurally generated** at runtime or via editor tools:

| System | What it generates |
|--------|------------------|
| **TilesetGenerator** | Grass, path, water tiles; trees, flowers, rocks, fences; houses, shops, gym buildings; player & NPC sprite sheets; UI elements; battle backgrounds |
| **AudioGenerator** | 15 SFX (menu clicks, correct/wrong, hit, level up, badge, victory/defeat, footsteps) + 4 music themes (overworld, battle, gym, menu) |
| **PixelSpriteGenerator** | Runtime fallback sprites for player, NPCs, gym leaders, tiles |

---

## 🌍 World Map — Kaiserland Region

```
                    ⛰️ Silver Mountain (Final Boss)
                          |
                    [Omnium] — Gym 20 (Mixed)
                   /       \
          [Fortissimo]    [Eloqua]
             |               |
       [Composia]      [Integra]
          |               |
     [Morphia]      [Functionburg]
        |               |
    [Chordwell]    [Prosdia]
       |               |
   [Graphton]     [Scalara]
      |               |
  [Syntaxia]    [Polynova]
     |               |
  [Rhythmia]    [Quadralis]
     |               |
   [Verbum]     [Harmonia]
     |               |
   [Lexicon]    [Equaton]
          \       /
        [Numeria] — Gym 1
            |
     🏡 Origin Village
```

---

## 📊 Question Banks

### Unity (Client-side)
- `math_questions.json` — 50+ questions (Variables → Graphs)
- `english_questions.json` — 50+ questions (Grammar → Writing)
- `music_questions.json` — 50+ questions (Notes → Composition)

### Backend (Server-side)
- **375 hand-crafted questions** across 15 topics
- Difficulty levels 1-5 per topic
- Full explanations for every answer
- Procedural math question generation for infinite variety

---

## 🛠️ Tech Stack

| Component | Technology |
|-----------|-----------|
| Game Engine | Unity 2022.3.20f1 (C#) |
| Rendering | 2D Tilemap + Pixel Perfect |
| Backend | Python FastAPI |
| ML/AI | scikit-learn (GradientBoosting) |
| Multiplayer | WebSocket (uvicorn) |
| Audio | Procedural WAV generation |
| Art | Procedural pixel art (Kenney.nl style) |

---

## 📜 License

This project is for educational purposes.

---

*Built with ❤️ for learners everywhere.*
