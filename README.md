# ⚔️ KaiserQuest — MVP v0.1
## Learn Through Adventure · Become Kaiser

---

## 🚀 Setup (5 minutes)

### 1. Install Godot 4
- Download **Godot 4.2+** (Standard version) from https://godotengine.org
- No installation needed — just extract and run

### 2. Open the Project
1. Launch Godot
2. Click **"Import"** → navigate to the `KaiserQuest/` folder
3. Select `project.godot` → click **"Import & Edit"**

### 3. Run the Game
- Press **F5** (or click the ▶ Play button)
- First run will ask you to confirm the main scene — click **OK**

---

## 🎮 Controls

| Key | Action |
|-----|--------|
| Arrow Keys | Move player |
| Enter / Space | Interact with NPCs · Advance dialog · Confirm answer |
| ↑ ↓ | Select answer in battle |
| F5 | **Dev:** Reset save data & restart |

---

## 🗺️ What's In This Build (Phase 1 MVP)

### Mathopolis — Starter Town
- **15×10 tile pixel map** drawn entirely in GDScript (no external assets)
- Top-down movement, tile-based grid, smooth tweened walking
- 4 NPCs to talk to (each gives +50 XP on first meeting)
- 1 collectible **Algebra Scroll** item (+200 XP)
- Pokémon-style dialog box with typewriter effect

### Getting to the Gym
You start at **Level 1**. To challenge the gym you need **Level 5**.
- Talk to all 4 NPCs → +200 XP
- Collect the glowing scroll east of the path → +200 XP
- Total: **400 XP = Level 5** ✓

### Algebra Gym — Variable Keep
- Gym Leader: **Professor Axiom**
- Topic: **Variables** (Algebra Gym 1)
- 5 questions, 3 lives
- Arrow keys to select answers, Enter to confirm
- Win → earn the **Variable Badge** + 250 XP

### Systems Working
- ✅ Level & XP system (with HUD bar)
- ✅ Badge tracking
- ✅ Persistent save/load (auto-saves to user data)
- ✅ NPC one-time XP rewards
- ✅ Item collection
- ✅ Gym level gate (Level 5 required)
- ✅ Knowledge battle with feedback & explanations

---

## 🔮 Roadmap (Future Phases)

| Phase | What Gets Added |
|-------|-----------------|
| 2 | Camera scrolling + larger world map |
| 3 | 3 knowledge subjects (Algebra, English, Music Theory) |
| 4 | All 20 Gym Leaders per subject |
| 5 | Side quests + NPC stories |
| 6 | Silver Mountain Final Boss |
| 7 | Pixel art sprite replacement |
| 8 | Mobile export + sound |
| 9 | Kaiser certification screen |

---

## 📁 Project Structure

```
KaiserQuest/
├── project.godot              ← Godot project config
├── icon.svg
├── scenes/
│   └── Main.tscn              ← Root scene (loads Main.gd)
└── scripts/
    ├── Main.gd                ← Scene coordinator
    ├── TitleScreen.gd         ← Title screen
    ├── Overworld.gd           ← World map + player movement
    ├── DialogBox.gd           ← Typewriter dialog system
    ├── HUD.gd                 ← Level/XP/Badge overlay
    ├── BattleScene.gd         ← Quiz battle engine
    ├── autoload/
    │   └── GameManager.gd     ← Global state + save/load
    └── data/
        └── AlgebraQuestions.gd ← Question bank
```

---

## 🐛 Known Issues (MVP)
- Sprites are placeholder colored rectangles — pixel art to come in Phase 2
- No sound/music yet
- Battle intro dialog requires the DialogBox to be registered in group `dialog_box`

---

*Built with Godot 4 · GDScript · No external assets required*
