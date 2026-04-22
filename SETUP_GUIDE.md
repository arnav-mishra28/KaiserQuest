# 🎮 KaiserQuest Unity — Complete Setup & Run Guide
## Pokemon Fire Ash / Gen 1/2 Style · 2.5D · Unity 2022.3 LTS

---

## ⚡ QUICK START (5 minutes)

### Step 1 — Install Unity Hub + Editor
1. Download **Unity Hub** from: https://unity.com/download  
   → Install to: `D:\Unity\Hub`
2. Open Unity Hub → **Installs** → **Install Editor**
3. Choose **Unity 2022.3.20f1 LTS** (Long Term Support)  
   → Install to: `D:\Unity\Editors`
4. Modules to add: ✅ **Windows Build Support** (already selected by default)

### Step 2 — Open the Project
1. Copy the `KaiserQuestUnity` folder to `D:\MY WORK\KaiserQuest\`
2. Open Unity Hub → **Projects** → **Open** → Browse to `D:\MY WORK\KaiserQuest\KaiserQuestUnity`
3. Unity will import and compile. First open takes ~2 minutes.

### Step 3 — One-Time Scene Setup
1. In Unity, open **File → Open Scene → Assets/Scenes/Main.unity**
2. In the **Hierarchy** (left panel): right-click → **Create Empty**
3. Name it: `KaiserQuestBootstrap`
4. In the **Inspector** (right panel): **Add Component** → search `Bootstrap` → click it
5. Press **F5** (or the ▶ Play button) to start the game!

> 🎯 **That's it!** The Bootstrap script creates all managers and screens automatically.

---

## 🎮 CONTROLS

| Action | Key |
|--------|-----|
| Move player | **Arrow keys** |
| Interact / Confirm answer | **Enter** or **Space** |
| Select menu item | **Arrow keys** |
| **Click answer box** | **Left Mouse Button** |
| Hover answer | Move mouse |
| Back to Subject Menu | **ESC** |
| Dev: Reset save | **F5** |

---

## 📐 DISPLAY SETTINGS (Pixel-Perfect)

The game renders at a logical **480×320** resolution (2× Game Boy Advance).  
Unity auto-scales to fit any window size.

To set the Game view to the right resolution:
1. **Game** tab → click the resolution dropdown (default "Free Aspect")
2. Click **+** → add: **Name:** `KaiserQuest`, **Width:** 960, **Height:** 640
3. This gives you a clean 2× pixel-perfect view

---

## 📚 GAME FLOW

```
Title Screen (Space/Enter)
    ↓
Enter Name (type, then Enter)
    ↓
CHOOSE SUBJECT             ← Use ← → arrows, Enter
  Mathematics | Languages | Music
    ↓
CHOOSE BRANCH              ← Use ← → arrows, Enter  
  (Algebra/Geometry/Calculus | English/Spanish/French | Theory/Composition/History)
    ↓
CITY MAP (15×10 tiles, no camera scroll)
  ? Teachers = lessons (+75 XP each)     ← Press Enter near them
  NPCs       = tips (+50 XP)             ← Press Enter near them
  ★ Items    = sparkle pickup (+200 XP)  ← Walk onto them
  VS Duels   = Knowledge Duel (+150 XP)  ← Press Enter or walk into them
  GYM DOOR   = Challenge Gym            ← Press Enter at the blue door
    ↓
GYM BATTLE (need Level 5×gym_number + 1 teacher talked to)
  FIGHT = choose answer
  HINT  = see first 4 chars of answer
  SKIP  = skip question (no XP)
  Click any answer box OR use arrow keys
    ↓
20 GYMS per branch (each branch is independent)
    ↓
SILVER MOUNTAIN (need Level 100 + 20 badges)
  Oracle Boss = 15 mixed questions from all subjects
  3 attempts before 24h cooldown
    ↓
★ KAISER SCREEN ★
```

---

## 🏆 20 GYM STRUCTURE

| Act | Gyms | Theme | Questions |
|-----|------|-------|-----------|
| ACT 1 — Beginning | 1–5 | Basics, friendly | 3–6 Q |
| ACT 2 — Rising | 6–12 | Harder, rival | 6–8 Q |
| ACT 3 — Mastery | 13–20 | Mixed, timed | 9–12 Q |
| FINAL | Oracle | All subjects | 15 Q |

**Each branch is fully independent** — Algebra and Geometry progress separately.  
Save data is stored per `subject:branch` key in `AppData/LocalLow/KaiserStudios/KaiserQuest/kq_save.json`.

---

## 🌐 BACKEND SETUP (Multiplayer + Voice AI)

### Step 1 — Install Python 3.10+
```
https://python.org/downloads
```
✅ Check "Add Python to PATH" during install.

### Step 2 — Install dependencies
Open **Command Prompt** and run:
```bash
pip install fastapi uvicorn websockets python-multipart pydantic gtts
```
For Voice AI (Whisper STT — optional, ~150MB):
```bash
pip install openai-whisper
```

### Step 3 — Start the backend
```bash
cd D:\MY WORK\KaiserQuest\KaiserQuestUnity\backend
uvicorn main:app --host 0.0.0.0 --port 8000
```
Open browser: `http://localhost:8000/health`  
You should see: `{"status":"ok","version":"1.0"}`

### Step 4 — Connect in Unity
The game auto-tries to connect on startup.  
`BackendClient` in the game reads `ServerURL = "http://localhost:8000"`.

---

## ⚔️ MULTIPLAYER PvP

Two players connect on the same network:

**Player 1** (your PC):
```bash
# Backend already running on port 8000
# Open game → Play normally
```

**Player 2** (same network, or same PC second window):
```
ServerURL in BackendClient: http://YOUR_LOCAL_IP:8000
```

Find your local IP: `ipconfig` → look for IPv4 Address (e.g. 192.168.1.5)

### PvP Flow:
1. Both players enter the same world (e.g. `math:algebra`)
2. Backend auto-matches them
3. Same question sent to both simultaneously
4. **Faster correct answer = more damage to opponent**
5. Combo streaks (consecutive correct answers) increase damage multiplier
6. First player to reduce opponent HP to 0 wins

---

## 🎤 VOICE AI

### Speech-to-Text (talk to NPCs):
```python
# Test from command line:
curl -X POST "http://localhost:8000/voice/transcribe" \
  -F "audio=@your_recording.wav"
```

### Text-to-Speech (NPC responses):
```python
curl -X POST "http://localhost:8000/voice/speak" \
  -H "Content-Type: application/json" \
  -d '{"text":"Welcome to KaiserQuest, young scholar!"}' \
  --output response.mp3
```

---

## 🗺️ PROCEDURAL WORLD GENERATION

Generate random worlds via the API:
```
http://localhost:8000/world/generate?width=30&height=20&seed=42&subject=math&branch=algebra
```
Returns a JSON tile grid using Perlin noise with towns and gyms placed automatically.

---

## 🤖 ADAPTIVE AI — How It Works

The `AdaptiveAI` system tracks **per-branch**:
- **Accuracy per topic** → weak topics appear more in future questions
- **Answer speed** → faster = XP multiplier up to **2.5×**
- **Difficulty tier** → 85%+ acc = harder questions; <40% = easier questions

HUD (top-right) shows:
- `Diff: ●●○○` = current difficulty tier (1–4)  
- `x3` = current consecutive correct streak  
- Red weak-topic text

---

## 📁 FILE STRUCTURE

```
D:\MY WORK\KaiserQuest\KaiserQuestUnity\
├── Assets\
│   ├── Scenes\Main.unity          ← Open this in Unity
│   └── Scripts\
│       ├── Bootstrap.cs           ← ATTACH TO EMPTY GAMEOBJECT
│       ├── Core\
│       │   ├── GameManager.cs     ← Singleton, per-branch save
│       │   ├── SaveSystem.cs      ← JSON persistence
│       │   ├── SubjectDB.cs       ← All subjects, questions, leaders
│       │   └── AdaptiveAI.cs      ← Learning engine
│       ├── Rendering\
│       │   ├── PixelRenderer.cs   ← Core draw (480×320 OnGUI)
│       │   └── SpriteDrawer.cs    ← All pixel sprites (no external assets)
│       ├── UI\
│       │   ├── GameScreenManager.cs
│       │   ├── TitleScreen.cs
│       │   ├── SubjectSelectScreen.cs
│       │   ├── DialogBox.cs       ← World=bottom bar, Battle=top compact
│       │   └── HUD.cs
│       ├── World\
│       │   ├── WorldManager.cs    ← 15×10 tile map + NPCs
│       │   └── WorldController.cs ← Input + movement
│       ├── Battle\
│       │   ├── BattleManager.cs   ← Gen 1/2 battle + click-to-answer + avatars
│       │   └── DuelManager.cs     ← PvP duel
│       ├── Silver\
│       │   ├── SilverMountainManager.cs
│       │   └── KaiserScreen.cs
│       └── Network\
│           └── BackendClient.cs   ← WebSocket + REST API
├── backend\
│   ├── main.py                    ← FastAPI server
│   └── requirements.txt
├── Packages\manifest.json
└── ProjectSettings\
    ├── ProjectSettings.asset
    └── ProjectVersion.txt         ← Unity 2022.3.20f1
```

---

## 🐛 TROUBLESHOOTING

| Problem | Fix |
|---------|-----|
| "No scripts in namespace" | Right-click Assets → **Reimport All** |
| Blank game screen | Make sure Bootstrap.cs is attached to a GameObject |
| Player invisible | Press F5 (reset save) — old save has invalid grid position |
| Dialog covers battle | Already fixed — battle uses top compact 44px banner |
| Backend connection failed | Start backend first: `uvicorn main:app --port 8000` |
| Whisper install fails | Try: `pip install openai-whisper --no-cache-dir` |
| Resolution blurry | In Game view dropdown, add 960×640 resolution |
| "Error CS0246: type not found" | Unity version mismatch — use exactly 2022.3 LTS |

---

## 🆓 ALL FREE TOOLS USED

| Tool | Use | Link |
|------|-----|------|
| Unity 2022.3 LTS | Game engine | https://unity.com |
| FastAPI | Backend API | https://fastapi.tiangolo.com |
| Uvicorn | Python server | https://www.uvicorn.org |
| OpenAI Whisper | Voice STT | https://github.com/openai/whisper |
| gTTS | Voice TTS | https://gtts.readthedocs.io |

---

*KaiserQuest v1.0 Unity — Knowledge is power. The world needs you.*
