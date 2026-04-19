# ⚔️ KaiserQuest 1.0
## Learn · Battle · Become Kaiser

---

## 🚀 Setup (2 minutes)

1. Download **Godot 4.2+** from https://godotengine.org (free, ~40MB)
2. Extract the ZIP → Open Godot → **Import** → select `project.godot`
3. Press **F5** to play

---

## 🎮 Controls

| Action | Key | Also works |
|--------|-----|-----------|
| Move   | Arrow keys | WASD |
| Interact / Confirm | Enter / Space | Mouse click |
| Select answer | Arrow keys | **Click the answer box** |
| Hover answer | — | Move mouse over option |
| World Map | ESC | F4 (dev) |
| Reset save | — | F5 (dev) |

---

## 🌍 Game Flow

```
Title Screen → Enter Name → World Map (Kalos Region)
     ↓
Choose World: Math / Language / Music
     ↓
Town (Mathopolis / Lexicon City / Harmonia)
     ↓
Talk to ? Teachers (+75 XP each)    ←── Learn concepts
Talk to NPCs (+50 XP each)          ←── Side quests + duels
Collect items (sparkle spots)       ←── +100-200 XP
     ↓
Reach Level 5 → Challenge Gym 1
Reach Level 10 → Challenge Gym 2
Reach Level 15 → Challenge Gym 3
     ↓
(More gyms in future regions)
     ↓
Level 100 + 20 badges → Silver Mountain Final Boss → KAISER
```

---

## ⚔️ Battle System

**In battles and duels:** click any answer box OR use ↑↓ arrow keys + Enter.

- **FIGHT** → show answer options → click or arrow+Enter to answer
- **HINT** → reveals first 3 letters of correct answer
- **SKIP** → skip this question (no damage, no gain)

**HP system:** Wrong answers reduce your HP. Run out = lose.

---

## 🤖 Adaptive AI

The game tracks:
- **Accuracy per topic** — weak topics get prioritised in future questions
- **Answer speed** — fast correct answers → higher XP multiplier (up to 2.5×)
- **Difficulty tier** — auto-scales 1→4 based on session performance (85%+ acc = promote)
- **Streak** — consecutive correct answers shown as 🔥 in the HUD

The HUD (top-right panel) shows:
- Level + HP bar + XP bar
- Badges earned
- Difficulty dots + streak
- Current weak topic

---

## 📚 Question Banks

| World | Gym 1 | Gym 2 | Gym 3 |
|-------|-------|-------|-------|
| Math | Variables (5Q) | Linear Equations (6Q) | Functions (7Q) |
| Language | Nouns (5Q) | Verbs (6Q) | Sentences (7Q) |
| Music | Staff & Clefs (5Q) | Notes & Chords (6Q) | Scales & Time (7Q) |

Each world has **40+ questions** across 4 difficulty tiers for adaptive selection.

---

## 🗺️ World Map (Kalos Region)

30×20 tile region with:
- 3 Subject Cities  + Silver Mountain
- Mountains, forests, rivers, bridges
- Minimap in corner

---

## 🐛 Bugs Fixed in v0.5

- ✅ World is now **static** — player walks on screen, nothing scrolls in towns
- ✅ Click-to-answer works in battles and duels
- ✅ Mouse hover highlights answer options
- ✅ GYM_DOOR_POS fixed (was y=10, out of 10-row map bounds)
- ✅ Player spawn position fixed (was y=7 → y=8, valid path tile)
- ✅ NPC positions clamped to map bounds
- ✅ Multi-gym support (3 gyms per city unlock progressively)
