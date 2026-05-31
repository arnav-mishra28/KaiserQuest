# 🎮 KaiserQuest

> **"Knowledge is fading from the world. You are the last learner who can restore it."**

A Pokemon Gen1/Gen2-style 2.5D pixel art educational RPG built in **Unity** with a **Python AI backend**. Learn Math, English, and Music Theory by exploring a pixel world, battling knowledge duels, conquering 20 gyms, and becoming a **Kaiser** — master of knowledge.

---

## 🚀 Quick Start Guide

### Prerequisites
- **Unity 2022.3.20f1** (LTS) — already installed at `D:\Unity\Editors\2022.3.20f1`
- **Python 3.9+** — for the AI backend
- **pip** — Python package manager

### Step 1: Open Unity Project

1. Open **Unity Hub**
2. Click **"Add"** → Browse to `D:\MY WORK\KaiserQuest\KaiserQuest-Unity`
3. Select Unity **2022.3.20f1** as the editor version
4. Click **Open** — Unity will import all packages (may take a few minutes)

### Step 2: Setup Scenes

Once Unity opens:

1. Go to menu: **KaiserQuest > Create Overworld Scene**
2. Go to menu: **KaiserQuest > Create Main Menu Scene**
3. Go to **File > Build Settings**
4. Add both scenes:
   - `Assets/Scenes/MainMenu.unity` (index 0)
   - `Assets/Scenes/Overworld.unity` (index 1)

### Step 3: Run the Game

1. Open `Assets/Scenes/Overworld.unity`
2. Press **Play** ▶️
3. Use **WASD** or **Arrow keys** to move
4. Press **Z/Enter/Space** to interact with NPCs
5. Press **ESC** to open pause menu
6. Press **M** to open world map

### Step 4: Start Python Backend (Optional)

```bash
cd "D:\MY WORK\KaiserQuest\Backend"
pip install -r requirements.txt
python main.py
```

The backend runs on `http://localhost:8000`. The game works offline too with built-in questions.

---

## 🎯 How to Play

### Controls
| Key | Action |
|-----|--------|
| WASD / Arrow Keys | Move (4-directional grid) |
| Z / Enter / Space | Interact / Advance dialog |
| ESC / X | Pause menu |
| M | World map |
| Mouse click | Select answers in battles |

### Gameplay Loop
1. **Explore** the pixel world
2. **Talk** to NPCs — they teach you subjects
3. **Battle** trainers in Knowledge Duels (click the correct answer!)
4. **Challenge Gyms** when you reach the required level
5. **Earn Badges** by defeating Gym Leaders
6. **Reach Silver Mountain** with Level 100 + 20 Badges
7. **Defeat the Guardian** to become a **Kaiser!**

### Level System
- Gym 1 requires Level **5**
- Gym 2 requires Level **10**
- ...
- Gym 20 requires Level **100**
- Silver Mountain requires Level **100** + all **20 badges**

### Silver Mountain Rules
- 3 attempts to beat the Guardian
- Failure = 24-hour cooldown
- Must review material before retrying

---

## 🌍 World Map — Kaiserland Region

| # | City | Gym Topic | Subject |
|---|------|-----------|---------|
| — | Origin Village | Starter Town | — |
| 1 | Numeria | Variables | Math |
| 2 | Equaton | Linear Equations | Math |
| 3 | Lexicon | Grammar | English |
| 4 | Harmonia | Notes | Music |
| 5 | Quadralis | Quadratics | Math |
| 6 | Verbum | Vocabulary | English |
| 7 | Rhythmia | Rhythm | Music |
| 8 | Polynova | Polynomials | Math |
| 9 | Syntaxia | Writing | English |
| 10 | Scalara | Scales | Music |
| 11 | Graphton | Graphs | Math |
| 12 | Prosdia | Sentence Structure | English |
| 13 | Chordwell | Chords | Music |
| 14 | Functionburg | Functions | Math |
| 15 | Morphia | Word Forms | English |
| 16 | Composia | Composition | Music |
| 17 | Integra | Advanced Algebra | Math |
| 18 | Eloqua | Advanced English | English |
| 19 | Fortissimo | Advanced Music | Music |
| 20 | Omnium | Mixed Mastery | All |
| ⛰️ | Silver Mountain | Final Boss | All |

---

## 🏗️ Project Structure

```
KaiserQuest/
├── KaiserQuest-Unity/          # Unity Project
│   ├── Assets/
│   │   ├── Scripts/
│   │   │   ├── Core/           # GameManager, SceneLoader, Bootstrap, SpriteGen
│   │   │   ├── Player/         # PlayerController (grid movement)
│   │   │   ├── Camera/         # CameraFollow (pixel-perfect)
│   │   │   ├── NPC/            # NPCController, DialogSystem
│   │   │   ├── Battle/         # BattleManager, QuestionBank
│   │   │   ├── Gym/            # GymSystem, GymData
│   │   │   ├── UI/             # MainMenu, SubjectSelect, HUD, PauseMenu
│   │   │   ├── World/          # WorldManager, ProceduralWorldGen
│   │   │   ├── Quests/         # SideQuestManager
│   │   │   ├── AI/             # AIClient (backend communication)
│   │   │   └── Multiplayer/    # PvPManager
│   │   ├── Sprites/            # Pixel art assets
│   │   ├── Scenes/             # Unity scenes
│   │   ├── Data/               # Question bank JSON files
│   │   └── Resources/          # Runtime-loadable assets
│   └── ProjectSettings/
├── Backend/                    # Python AI Backend
│   ├── main.py                 # FastAPI server
│   ├── models/                 # ML models
│   ├── data/                   # Question databases
│   ├── services/               # Game services
│   └── requirements.txt
└── README.md
```

---

## 🧠 AI Features

### Adaptive Difficulty
The system tracks your:
- **Accuracy** — how many answers you get right
- **Speed** — how fast you answer
- **Weak Topics** — where you struggle most
- **Streak** — consecutive correct answers

### Dynamic Questions
Questions are never the same twice (when using the backend). The AI generates questions based on your level and weak areas.

### Smart NPCs
NPCs explain concepts differently based on your knowledge level. Beginners get simpler explanations; advanced players get deeper insights.

---

## 🔧 Tech Stack

| Component | Technology |
|-----------|-----------|
| Game Engine | Unity 2022.3.20f1 (C#) |
| Rendering | 2D Tilemap + Sprite Renderer |
| AI Backend | Python FastAPI |
| ML Models | scikit-learn |
| PvP | WebSocket (simulated offline) |
| Data | JSON + SQLite |
| Sprites | Procedural pixel art generation |

---

## 📝 Development Roadmap

- [x] Core game engine (player movement, camera, tilemaps)
- [x] NPC dialog system (typewriter effect, choices)
- [x] Battle system (click-to-answer, HP bars, XP)
- [x] Gym system (20 gyms, badge collection)
- [x] Silver Mountain final boss
- [x] Question bank (50+ questions across 3 subjects)
- [x] Side quests for leveling
- [x] PvP knowledge duels (simulated)
- [x] Procedural world generation
- [x] Python AI backend
- [x] Adaptive difficulty model
- [ ] External pixel art tilesets (Kenney.nl, OpenGameArt)
- [ ] Sound effects and music
- [ ] Voice AI tutor (Whisper + TTS)
- [ ] Mobile export (Android)
- [ ] Real multiplayer server

---

## 📜 License

This project is for educational purposes.

---

*Built with ❤️ by the KaiserQuest Team*
