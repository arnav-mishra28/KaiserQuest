# ⚔️ KaiserQuest Unity v1.0
## Learn · Level Up · Become Kaiser
### Pokemon Fire Ash / Gen 1/2 Style · 2.5D · Unity 2022.3 LTS

---

## 🚀 Quick Start (3 steps)

1. **Install Unity 2022.3.20f1 LTS** from https://unity.com/download
   - Install to: `D:\Unity\Editors`
   - No extra modules needed

2. **Open the project**
   - Unity Hub → Projects → Open → `D:\MY WORK\KaiserQuest\KaiserQuestUnity`
   - Wait ~2 min for first compile

3. **One-time scene setup**
   - Open `Assets/Scenes/Main.unity`
   - Hierarchy → right-click → **Create Empty** → name it `KaiserQuestBootstrap`
   - Inspector → **Add Component** → type `Bootstrap` → click it
   - Press **▶ Play**

---

## 🎮 Controls

| Action | Key |
|--------|-----|
| Move player | Arrow keys |
| Interact / Confirm | Enter or Space |
| Select answer | Arrow keys + Enter |
| **Click answer box** | Left Mouse Button |
| Back to Subject Select | ESC |
| Dev: Reset save | F5 |

---

## 📚 Game Flow

```
Title Screen (any key)
    ↓
Enter Your Name (type + Enter)
    ↓
CHOOSE SUBJECT (← → Enter)
  Mathematics | Languages | Music
    ↓
CHOOSE BRANCH (← → Enter)
  Math:  Algebra | Geometry | Calculus
  Lang:  English | Spanish  | French
  Music: Theory  | Composition | History
    ↓
CITY (15×10 tiles, no scrolling)
  ? Teacher NPCs → lessons (+75 XP)
  Circle NPCs    → tips (+50 XP)
  VS NPCs        → Knowledge Duel (+150 XP)
  Sparkle items  → collect (+200 XP)
  Blue Gym Door  → Challenge Gym
    ↓
20 GYMS per branch (each branch is independent)
    ↓
Silver Mountain (Level 100 + 20 badges)
  Oracle Boss = 15 mixed questions
  3 attempts before 24h cooldown
    ↓
★ KAISER OF KNOWLEDGE ★
```

---

## 🏆 20 Gym Structure

| Act | Gyms | Difficulty | Questions |
|-----|------|-----------|-----------|
| **ACT 1 — Beginning** | 1–5 | Easy, friendly mentor | 3–6 Q |
| **ACT 2 — Rising** | 6–12 | Medium, rival appears | 6–8 Q |
| **ACT 3 — Mastery** | 13–20 | Hard, mixed, timed | 9–12 Q |
| **FINAL — Oracle** | Silver Mtn | All subjects | 15 Q |

**Each branch is fully independent** — Algebra and Geometry save separately.

---

## 🏗️ Architecture

### Unity Scripts (19 C# files)

| Script | Purpose |
|--------|---------|
| `Bootstrap.cs` | **Attach to empty GameObject** — creates all systems automatically |
| `Core/GameManager.cs` | Singleton, per-branch state, XP/HP/badges |
| `Core/SaveSystem.cs` | JSON save to AppData/LocalLow |
| `Core/SubjectDB.cs` | All subjects, branches, questions, 20 gym leaders |
| `Core/AdaptiveAI.cs` | Learning engine — weak topics, difficulty scaling, XP multiplier |
| `Rendering/PixelRenderer.cs` | 480×320 OnGUI canvas, Gen 1/2 HP bars, dialog boxes |
| `Rendering/SpriteDrawer.cs` | All sprites: player, NPC, tiles, gym door, gym wall |
| `UI/GameScreenManager.cs` | Central screen state machine |
| `UI/TitleScreen.cs` | Animated Pokemon-style title |
| `UI/SubjectSelectScreen.cs` | Subject → Branch selection with stats |
| `UI/DialogBox.cs` | Context-aware: World=bottom bar, Battle=top compact |
| `UI/HUD.cs` | Gen 1/2 HP/XP/badge overlay + AI difficulty dots |
| `World/WorldManager.cs` | 15×10 tile map rendering + NPC + gym logic |
| `World/WorldController.cs` | Grid movement, input, smooth animation |
| `Battle/BattleManager.cs` | Gen 1/2 battle: FIGHT/HINT/SKIP, click-to-answer, avatars |
| `Battle/DuelManager.cs` | PvP-style knowledge duel |
| `Silver/SilverMountainManager.cs` | Cinematic entry + Oracle boss + 3-attempt rule |
| `Silver/KaiserScreen.cs` | Animated golden seal victory screen |
| `Network/BackendClient.cs` | WebSocket PvP + REST API (TTS/STT/NPC AI) |

---

## 🤖 Adaptive AI

Tracks **per subject:branch**:
- **Topic accuracy** → weak topics appear more in future questions
- **Answer speed** → fast correct answers → XP multiplier up to **2.5×**
- **Difficulty tier** → auto-scales 1→4 (85%+ acc = harder, <40% = easier)

HUD shows: `Diff: ●●○○` (difficulty) and `x3` (streak)

---

## 🌐 Backend (Optional — Multiplayer + Voice AI)

### Setup
```bash
cd KaiserQuestUnity/backend
pip install fastapi uvicorn websockets python-multipart pydantic gtts
pip install openai-whisper          # Optional: Voice STT (~150MB)
uvicorn main:app --host 0.0.0.0 --port 8000
```

Verify: `http://localhost:8000/health` → `{"status":"ok"}`

### API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `ws://localhost:8000/pvp/{name}?world=math:algebra` | WebSocket | PvP matchmaking |
| `POST /voice/transcribe` | POST (audio) | Speech → Text (Whisper) |
| `POST /voice/speak` | POST (json) | Text → Speech MP3 (gTTS) |
| `POST /npc/respond` | POST (json) | AI NPC chat response |
| `GET /world/generate?seed=42` | GET | Procedural map (Perlin noise) |
| `GET /leaderboard` | GET | Top scores |

### PvP Logic
- Both players get the same question simultaneously
- Faster correct answer = more damage to opponent
- Combo streaks multiply damage
- First to reduce opponent HP to 0 wins

---

## 🐛 Errors Fixed in This Build

| Error | Cause | Fix |
|-------|-------|-----|
| 70× `D3D11 Failed to create RenderTexture` | Creating new Texture2D per color per frame | Single white texture + GUI.color |
| `R/Rb/Rn takes 6 arguments` | Local lambda missing `bool border` param | Added `bool b=false` optional param |
| `'W' does not exist` (TitleScreen:113) | W out of scope in DrawTriFill | Replaced with `PixelRenderer.W` |
| `DialogBox.SetDialogOpen` not defined | Method never existed | Removed call; Dialog handles state internally |
| `UnityWebRequest` not found (BackendClient) | Missing `using UnityEngine.Networking` | Added using + unitywebrequest modules |
| `Color.gamma` doesn't exist | GDScript carry-over | Replaced with `Color(r*0.85, g*0.85, b*0.85)` |
| `Color*Color` multiplication | C# doesn't support Color*Color | Replaced with manual `new Color(r,g,b,a)` |
| `Dictionary<> not serializable` | Unity JsonUtility limitation | Replaced with parallel List<string>/List<int> |
| Various `assigned but never used` warnings | Dead code | Removed `_pvictory`, `H`, `W`, `_animT`, `_prev` |

---

## 📁 Project Structure

```
D:\MY WORK\KaiserQuest\KaiserQuestUnity\
├── README.md                          ← This file
├── SETUP_GUIDE.md                     ← Detailed setup guide
├── Assets\
│   ├── Scenes\Main.unity              ← Open in Unity
│   └── Scripts\
│       ├── Bootstrap.cs               ← ATTACH TO EMPTY GAMEOBJECT
│       ├── Core\
│       │   ├── GameManager.cs
│       │   ├── SaveSystem.cs
│       │   ├── SubjectDB.cs
│       │   └── AdaptiveAI.cs
│       ├── Rendering\
│       │   ├── PixelRenderer.cs
│       │   └── SpriteDrawer.cs
│       ├── UI\
│       │   ├── GameScreenManager.cs
│       │   ├── TitleScreen.cs
│       │   ├── SubjectSelectScreen.cs
│       │   ├── DialogBox.cs
│       │   └── HUD.cs
│       ├── World\
│       │   ├── WorldManager.cs
│       │   └── WorldController.cs
│       ├── Battle\
│       │   ├── BattleManager.cs
│       │   └── DuelManager.cs
│       ├── Silver\
│       │   ├── SilverMountainManager.cs
│       │   └── KaiserScreen.cs
│       └── Network\
│           └── BackendClient.cs
├── backend\
│   ├── main.py
│   └── requirements.txt
├── Packages\manifest.json
└── ProjectSettings\
    ├── ProjectSettings.asset
    └── ProjectVersion.txt (2022.3.20f1)
```

---

## 🆓 All Free Tools

| Tool | License |
|------|---------|
| Unity 2022.3 LTS | Unity Personal (Free) |
| FastAPI + Uvicorn | MIT |
| OpenAI Whisper | MIT |
| gTTS | MIT |

---

*KaiserQuest v1.0 Unity — "Knowledge is power. The world needs you."*
