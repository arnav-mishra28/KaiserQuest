# 🎮 KaiserQuest v1.0 — Complete Setup Guide (100% FREE)

---

## ⚡ QUICK START (Game only, 3 minutes)

```
1. Download Godot 4.2 → https://godotengine.org/download  (free, ~60MB)
2. Extract ZIP → Open Godot → Import → select project.godot
3. Press F5 to play!
```

---

## 🕹️ GAME CONTROLS

| Action | Keyboard | Mouse |
|--------|----------|-------|
| Move player | Arrow keys | — |
| Interact / Confirm | Enter / Space | — |
| Select answer | Arrow keys | **Click answer box** |
| Hover answer | — | Move mouse |
| Back to Subject Menu | ESC | — |
| Dev reset save | F5 | — |

---

## 📚 GAME FLOW

```
Title Screen
    ↓ ENTER
Enter Your Name
    ↓ ENTER
┌─────────────────────────────────┐
│  CHOOSE SUBJECT                 │
│  Mathematics | Languages | Music│
└─────────────────────────────────┘
    ↓ ENTER
┌──────────────────────────────────────┐
│  CHOOSE BRANCH                       │
│  Math:  Algebra | Geometry | Calculus│
│  Lang:  English | Spanish | French   │
│  Music: Theory  | Composition | Hist │
└──────────────────────────────────────┘
    ↓ ENTER
╔══════════════════════════════════╗
║  CITY (your branch's home town)  ║
║  • Talk to ? Teachers (+75 XP)   ║
║  • Talk to NPCs (+50 XP)         ║
║  • Collect sparkle items (+200)  ║
║  • VS Duel NPCs (+150 XP)       ║
║  • Challenge Gym (needs Lv5+)    ║
╚══════════════════════════════════╝
    ↓ Beat all 20 gyms
⛰️  SILVER MOUNTAIN (Lv100 + 20 badges)
    ↓ Beat the Oracle
★ KAISER OF KNOWLEDGE ★
```

---

## 🏆 20 GYM PROGRESSION

| Act | Gyms | Focus | Lives |
|-----|------|-------|-------|
| ACT 1 — Beginning | 1–5 | Basics, easy | 3 lives, 3–5 Q |
| ACT 2 — Rising | 6–12 | Harder, rival | 3 lives, 6–8 Q |
| ACT 3 — Mastery | 13–20 | Mixed, timed | 3 lives, 10–12 Q |
| FINAL | Oracle | All subjects | 3 lives, 15 Q |

Each branch (e.g. Algebra) has its own independent 20-gym progression.
Progress is saved **per branch** — Algebra and Geometry are separate journeys.

---

## 🤖 ADAPTIVE AI — How it works

The game tracks 3 things per branch:
1. **Accuracy per topic** — wrong answers → that topic appears more often
2. **Answer speed** — fast correct answers → XP multiplier up to **2.5×**  
3. **Difficulty tier** — 85%+ accuracy = harder questions next session

The HUD (top-right) shows:
- `Diff: ●●○○` — your current difficulty level
- `x3` — your current correct-answer streak
- Weak topic in red at bottom

---

## 🌐 BACKEND — Multiplayer + Voice AI (Optional)

### Step 1: Install Python 3.10+
```bash
# Windows: https://python.org/downloads
# macOS:   brew install python
# Linux:   sudo apt install python3 python3-pip
```

### Step 2: Install backend dependencies
```bash
cd KaiserQuest/backend
pip install fastapi uvicorn websockets python-multipart gtts

# For Voice AI (optional, large download ~150MB):
pip install openai-whisper
```

### Step 3: Start the server
```bash
cd KaiserQuest/backend
uvicorn main:app --host 0.0.0.0 --port 8000
```

### Step 4: Verify it's running
Open browser: http://localhost:8000/health
You should see: `{"status":"ok","version":"1.0"}`

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `ws://localhost:8000/pvp/{name}?world=math:algebra` | WebSocket | PvP matchmaking |
| `POST /voice/transcribe` | POST (audio file) | Speech → Text |
| `POST /voice/speak` | POST (json text) | Text → Speech MP3 |
| `POST /npc/respond` | POST (json) | AI NPC chat response |
| `GET /world/generate?width=30&height=20&seed=42` | GET | Procedural map |
| `GET /leaderboard` | GET | Top scores |
| `GET /health` | GET | Server status |

---

## 🎯 MULTIPLAYER — How PvP Works

1. Two players connect to `ws://server:8000/pvp/{player_name}?world=math:algebra`
2. Server auto-matches players on the same world
3. Both players get the same question simultaneously
4. **Faster** correct answer = more damage to opponent
5. Combo streaks increase damage multiplier
6. First to reduce opponent HP to 0 wins

**Test locally:**
```python
# Open 2 terminals and run this in each:
python -c "
import asyncio, websockets, json
async def play():
    async with websockets.connect('ws://localhost:8000/pvp/Player1') as ws:
        while True:
            msg = json.loads(await ws.recv())
            print(msg)
            if msg['type'] == 'question':
                await ws.send(json.dumps({'type':'answer','idx':0}))
asyncio.run(play())
"
```

---

## 🎤 VOICE AI — How to Use

```python
import requests

# Speech-to-Text (send a .wav file)
with open("recording.wav","rb") as f:
    r = requests.post("http://localhost:8000/voice/transcribe", files={"audio":f})
    print(r.json()["text"])  # → "x plus three equals nine"

# Text-to-Speech
r = requests.post("http://localhost:8000/voice/speak", json={"text":"Welcome, young scholar!"})
with open("response.mp3","wb") as f: f.write(r.content)
# Play with: vlc response.mp3  OR  mpg123 response.mp3
```

---

## 🗺️ PROCEDURAL GENERATION

```bash
# Generate a random world map
curl "http://localhost:8000/world/generate?width=30&height=20&seed=42&subject=math&branch=algebra"
# Returns a JSON grid of tile IDs you can render in any engine
```

---

## 📁 PROJECT STRUCTURE

```
KaiserQuest/
├── project.godot              ← Open this in Godot
├── scenes/Main.tscn           ← Entry scene
├── assets/icon.svg
├── scripts/
│   ├── Main.gd                ← Master coordinator
│   ├── autoload/
│   │   ├── GameManager.gd     ← Global state (subject:branch save)
│   │   ├── AdaptiveAI.gd      ← Learning engine
│   │   └── SubjectDB.gd       ← All subjects, branches, questions, leaders
│   ├── ui/
│   │   ├── TitleScreen.gd
│   │   ├── SubjectSelectScreen.gd  ← Choose Subject → Branch
│   │   ├── DialogBox.gd       ← Context-aware (world/battle)
│   │   └── HUD.gd
│   ├── world/
│   │   ├── World.gd           ← Town map (15×10 static)
│   │   └── Player.gd          ← CharacterBody2D (no camera scroll)
│   ├── battle/
│   │   ├── BattleSystem.gd    ← Gen 1/2 battle + animated avatars
│   │   └── DuelSystem.gd      ← PvP duel (click-to-answer)
│   ├── silver/
│   │   ├── SilverMountain.gd  ← Story + 3-attempt Oracle
│   │   └── KaiserScreen.gd    ← Victory screen
│   └── data/                  ← (legacy; SubjectDB.gd handles everything)
└── backend/
    ├── main.py                ← FastAPI server
    └── requirements.txt
```

---

## 🐛 TROUBLESHOOTING

| Problem | Fix |
|---------|-----|
| Player invisible in city | Press F5 to reset save (old save had wrong grid_pos) |
| Dialog covers battle | Fixed in v1.0 — battle uses compact top banner |
| Click on answer doesn't work | Make sure you're clicking inside the answer box borders |
| Backend won't start | `pip install fastapi uvicorn` then try again |
| Whisper very slow | Use `model="tiny"` in main.py for faster (less accurate) STT |
| "Scene not found" | Make sure you opened `project.godot` (not a folder) in Godot |

---

## 🆓 ALL FREE RESOURCES USED

- **Godot 4.2** — https://godotengine.org (MIT license)
- **FastAPI** — https://fastapi.tiangolo.com (MIT license)
- **OpenAI Whisper** — https://github.com/openai/whisper (MIT license)
- **gTTS** — https://gtts.readthedocs.io (MIT license)
- **Kenney Assets** — https://kenney.nl (CC0 license — free for any use)
- **OpenGameArt** — https://opengameart.org (various free licenses)

---

*KaiserQuest v1.0 — Knowledge is power. The world needs you.*
