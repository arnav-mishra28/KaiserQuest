# KaiserQuest — Unity Setup Guide

## 1. Open the Project
1. Open Unity Hub
2. Click **Add** → **Add project from disk**
3. Navigate to this folder (KaiserQuest_Assets)
4. Select the folder — Unity will open it (requires Unity 2021.3 LTS or newer)

## 2. Open the Scene
1. In the Project window → **Assets/Scenes/Main.unity**
2. Double-click to open
3. If the scene is empty, create an empty GameObject and attach **Bootstrap.cs** to it

## 3. Quick Setup (if scene is blank)
1. In the Hierarchy: Right-click → **Create Empty**
2. Name it `Bootstrap`
3. In Inspector: **Add Component** → search `Bootstrap` → click it
4. Press ▶ **Play**

## 4. Controls
| Key | Action |
|-----|--------|
| Arrow Keys / WASD | Move player |
| Enter / Space | Interact / confirm |
| Escape | Back / Menu |
| F5 | Reset all data |
| Mouse Click | Click answers in battles |

## 5. Game Flow
```
Title Screen
  → Enter Name
    → Choose Subject (Math / Languages / Music)
      → Choose Branch (Algebra / English / Theory)
        → World Map
          → Talk to Teachers for XP
          → Fight Duels to earn XP
          → Reach Level 5 → Challenge Gym 1
          → Beat Gym → earn Badge
          → 20 Badges + Level 100 → Silver Mountain
            → Beat Kaiser → Become KAISER
```

## 6. Subjects Available
- **Mathematics → Algebra** (18 questions, 5 named gym leaders)
- **Languages → English** (11 questions)
- **Languages → Spanish** (7 questions)
- **Music → Theory** (11 questions)

## 7. No errors expected
All 20 C# scripts compile clean. No external dependencies.
Backend (Python) is optional — game runs fully offline.
