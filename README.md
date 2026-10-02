# 🏰 Kaiser Quest

**A 2.5D pixel-art educational RPG where learning *is* the game mechanic.**

Kaiser Quest is not a quiz with Pokémon-shaped packaging. The world makes you need
Algebra, English, or Music Theory to get anywhere, and it keeps a live model of what
you actually understand — so it can tell the difference between *you got it right* and
*you know it*.

---

## The idea

The player never reads "now study Algebra". Instead:

- **Explore** a top-down pixel world.
- **Learn** a concept because a mechanism, a keeper, or a road will not open without it.
- **Face a trial** — but twenty identical quizzes with different names is the failure
  mode this design exists to avoid, so each of the 20 milestones runs a *different
  mechanic*: a guided lesson, a mechanism you solve to open the world, a duel against a
  clock, reasoning that must be justified, a bracket, an investigation, a diagnosis of
  broken working, an endurance run, a chain, a construction, a boss, a championship.
- **Be judged on mastery, not on effort.** Then climb Silver Mountain.

### Silver Mountain

Clear all twenty milestones and the Archivist — an ancient figure said to have mastered
every realm — will examine you. You get **three attempts**. Fail all three and you are
returned to the **last place you rested**, with a **24-hour cooldown** and a *personalised
Mastery Recap* that names the concepts you failed on and the misconceptions you exhibited,
ending in a drill sequence rather than "study more".

The exam is not a fixed test. It is assembled from your own knowledge profile:
**60% aimed at your weakest concepts, 25% at the middle, 15% at your strongest** — because
a final exam that never asks what you know best is not an examination, it is an ambush.

---

## Progression: mastery gates, not level gates

The v0.1 prototype gated its gyms on player level (`requiredLevel = gymIndex * 5`). That
design is rejected outright. A level gate says *"you have spent enough time here"*; a
mastery gate says *"you understand this"*. The first is satisfied by grinding. The second
cannot be.

Progression is therefore derived entirely from the knowledge trace:

- You may **enter** milestone N when you have *passed* N-1 **and** you still hold the
  concepts N-1 taught.
- You **pass** a milestone by meeting its trial's score **and** by actually holding the
  concepts that milestone teaches. Reaching the right answers without the ideas underneath
  them is not mastery, and the gate says so.

Two properties of that design are deliberate, because the obvious versions of both are wrong:

- **The entry check is local, not cumulative.** Requiring mastery of everything ever taught
  would collide head-on with the forgetting mechanic — concepts decay, so a player who took
  a fortnight off would be locked out by chapter three. Checking only the milestone just
  completed enforces holding everything *transitively*, while the remedy for a lapse is
  always a single milestone's worth of review.
- **The gate is reachable within the trial.** A gate of 80% cannot be cleared with two
  questions on a concept, so a trial guarantees enough questions on the concepts it
  introduces to make its own gate attainable. A gate the trial cannot satisfy is not a
  standard, it is a bug.

---

## The Knowledge Engine

Not `right = 1`, `wrong = 0`. The engine reads response time relative to the question's
expected reading time, hints used, tries, question difficulty, *which distractor* was
chosen (which is what names a misconception), concept dependencies, consistency, and
forgetting over time.

| Piece | What it does |
|-------|--------------|
| **Bayesian Knowledge Tracing** | Four-parameter BKT with guess/slip rates scaled by concept difficulty and by how hard the item was relative to the concept's level. Cheap enough to run on a 2 GB device mid-animation. |
| **Adaptive difficulty** | Derived from P(known) so a solid player gets stretched and a struggling one gets solid ground. The player is never shown a number; the questions simply meet them. |
| **Forgetting** | Half-life by curriculum level (21/14/10/7/5 days) with a retention floor, so a decayed concept reads as *rusty — needs a recap*, never as *never learned*. |
| **Named misconceptions** | A misconception is a coherent rule that happens to be wrong. Naming it turns a wrong answer into a specific next lesson instead of "study harder". |
| **Mastery** | `100 · p_known · (0.70 + 0.30·depth) · support · evidence`. Evidence grows with attempts, so one lucky answer cannot read as 100%. |

The interface is narrow enough that Deep Knowledge Tracing or a transformer could replace
BKT later without touching a single caller.

---

## Architecture

The educational content is **not** hard-coded into Unity.

```
                         KAISER QUEST
                              │
                  ┌───────────┴───────────┐
             GAME ENGINE              KNOWLEDGE ENGINE
                (Unity)                  (Python)
                  │                         │
      world · NPCs · UI · save      content pipeline · validation
      rendering · input             difficulty estimation · analytics
                  │                    fleet-level learner models
                  └──── identical logic ────┘
```

**Why both sides implement the engine.** The Unity client is the authority *for play*: the
game must run a full campaign on a 2 GB Android device with no network at all, so adaptive
difficulty, named misconceptions, mastery gates and the Archivist's exam all happen
in-process, instantly. The Python engine is the authority for the parts that genuinely want
a server — content **generation**, **validation**, difficulty estimation and analytics. Both
implementations are kept structurally identical so they agree about a player's knowledge.

### Content pipeline

Generated questions never enter the game unchecked:

```
AI generation ─▶ validation ─▶ difficulty estimation ─▶ human verification ─▶ bank ─▶ game
```

Every item is re-derived and checked against the concept it claims to teach. Corrupted
answers are caught by mutation tests; failures go to `_quarantine.json` instead of the bank.

---

## Layout

```
KaiserQuest/
├── KaiserQuest/                        # ◀ THE LIVE UNITY 6 PROJECT — open this one
│   └── Assets/Scripts/                 # (same layout as below)
├── KaiserQuest-Unity/                  # Unity 2022.3.20f1
│   │   ├── Knowledge/                  # The engine port (offline authority for play)
│   │   │   ├── ConceptGraph.cs         # 88 concepts, prereq closure, frontier
│   │   │   ├── KnowledgeTracer.cs      # BKT, mastery, confidence, forgetting
│   │   │   ├── MisconceptionDetector.cs
│   │   │   ├── KnowledgeProfile.cs     # domains, confidence buckets, next-up
│   │   │   ├── KnowledgeEngine.cs      # loading, adaptive select, grading
│   │   │   ├── AttemptLog.cs, KnowledgeData.cs
│   │   ├── Story/                      # The campaign + its presentation
│   │   │   ├── TrialModes.cs           # 13 trial modes
│   │   │   ├── MilestoneCatalog.cs     # the 20-milestone arc, per-realm flavour
│   │   │   ├── TrialRunner.cs          # the mechanics, as selection/grading policy
│   │   │   ├── ProgressionService.cs   # entry + pass gates
│   │   │   ├── SilverMountainController.cs  # exam assembly, attempts, recap
│   │   │   ├── StoryModeManager.cs     # orchestrator
│   │   │   ├── CharacterCreation.cs    # name, appearance presets, starting realm
│   │   │   ├── SaveSystem.cs           # versioned, atomic JSON saves
│   │   │   ├── StoryProgress.cs        # the save format
│   │   │   ├── StoryUI.cs              # title · creation · map · trial · summit · recap (IMGUI)
│   │   │   ├── StoryWorld.cs           # keepers, save shards, Archivist, world populator
│   │   │   ├── OverworldDecor.cs       # plazas, landmarks, scenery, ground clearing
│   │   │   └── Boot.cs                 # RuntimeInitializeOnLoadMethod entry point
│   │   ├── Core/                       # GameManager, GameBootstrap, sprite/audio/tiles
│   │   ├── World/RuntimeTileset.cs     # the runtime tile palette (only walls collide)
│   │   ├── Player/                     # PlayerController, walk-bob animator, overworld HUD
│   │   ├── AI/ Battle/ Camera/ Gym/ Multiplayer/ NPC/ Quests/ UI/ World/
│   │   │                               # v0.2 systems still present; see Status below
│   │   └── Core/Editor/                # TilesetGenerator, AudioGenerator, setup wizard
│   └── Assets/Tests/PlayMode/          # 19 PlayMode tests — the game's executable spec
│   └── Assets/Resources/
│       ├── Knowledge/                  # concepts.json, misconceptions.json, banks.json (exported)
│       └── Questions/                  # bank_{math,english,music}.json (exported, verified)
│
└── backend/                            # Python — the server-side Knowledge Engine
    ├── main.py                         # FastAPI: /story/*, /concepts, /content/*
    ├── engine/
    │   ├── concepts.py                 # the concept graph (source of truth)
    │   ├── tracing.py                  # BKT
    │   ├── misconceptions.py
    │   ├── profile.py                  # KnowledgeProfile + ASCII render
    │   ├── campaign.py                 # ARC: 20 archetypes × 3 realms, 13 trial modes
    │   ├── progression.py              # mastery gates
    │   ├── silver_mountain.py          # the Archivist
    │   ├── bank.py                     # adaptive selection + grading
    │   ├── templates.py                # authored item banks
    │   └── content/                    # safemath, generator, validator, difficulty, pipeline
    ├── services/
    │   ├── story_service.py            # orchestrator
    │   └── save_store.py               # versioned atomic saves
    ├── data/
    │   ├── knowledge/                  # concepts.json (88), misconceptions.json (24)
    │   ├── banks/                      # generated + verified question banks
    │   └── questions/                  # legacy v0.2 banks
    └── tests/                          # 193 tests — the engine's executable specification
```

---

## Running it

### 1 · Unity (the game — this is the whole game, fully offline)

1. Install **Unity 6000.3.13f1** (Unity 6 — any Unity Hub can add that exact version).
2. Open the **`KaiserQuest/`** folder (the one directly inside the repo — *not*
   `KaiserQuest-Unity/`) as a project and wait for the compile to finish.
3. In the menu bar run **KaiserQuest → Generate All Assets**. This builds every
   procedurally-generated sprite, tile and font the world uses. Then run
   **KaiserQuest → Generate Audio** for the 8-bit music and sound effects. (If the
   menu is missing, the scripts are still compiling — give the Editor a moment.)
   Build Settings maintain themselves: on project open the game registers every scene in
   `Assets/Scenes` (MainMenu first) and prunes stale entries, so nothing needs adding by
   hand. `KaiserQuest → Sync Build Settings` re-runs it.
4. Press **Play**. Any scene works — press Play on whatever is open.

That is all. The game is self-booting: whichever scene is open, `Boot` creates the
bootstrap, the bootstrap creates every manager, the Knowledge Engine loads the verified
question banks from `Assets/Resources/` (via `Knowledge/banks.json`, which maps each realm
to its subject banks), the world generates itself, and the first story screen opens —
character creation for a new player, the title for a returning one.

#### What a session looks like

- **Create your explorer** — name, one of six looks, and which realm to enter first:
  Algebra (the Numeric Marches), English (the Plain of Tongues) or Music (the Resonant
  Valleys). No class, no level, no difficulty: the only thing that grows is what you
  understand.
- **The campaign map** is the road: 20 milestones, each with a place, a keeper and a
  different trial mechanic. The map always shows which milestone is open and — when one
  is locked — *why*, in words, never a bare padlock.
- **Close the map** to walk the overworld (WASD/arrows). Every milestone place is a
  **plaza** with a realm-tinted landmark (beacon, arch, shrine, grove or tower) and
  scattered scenery; each has a **keeper NPC** who opens that milestone's trial and a
  **save shard** where you rest. Ground is cleared under every character and landmark, so
  nothing spawns somewhere unreachable, and only walls block your path. Your sprite is
  generated from the appearance you chose and bobs as you walk.
- **A HUD plate** (top-left) names your realm, the region and its progress, and the
  current objective *in words* — including why a milestone is locked. A control legend
  sits bottom-left until you no longer need it; when nothing interactive is nearby, the
  world shows a place nameplate instead.
- **Trials** are multiple choice with the mechanic's framing: chains rebound on a wrong
  answer, duels are timed, boss trials aim at your weakest chapters. Answers feed the
  Knowledge Engine immediately, so the very next question adapts.
- **Clear a milestone and your save point moves there.** Pass milestone 20 and **Silver
  Mountain** opens: the Archivist's 25-question exam, three attempts per window, then a
  24-hour cooldown and a personalised Mastery Recap at your save point.

#### Controls

| Input | Action |
|-------|--------|
| WASD / arrow keys | Walk |
| Z / Enter / Space | Interact (talk to a keeper, rest at a shard, approach the Archivist) |
| Esc | Close the current story screen / pause |
| Mouse | Everything in the story screens is clickable |

#### Where saves live

Versioned JSON, written atomically, under `Application.persistentDataPath/saves/`
(on Windows: `%USERPROFILE%\AppData\LocalLow\<company>\KaiserQuest\saves\`). The
knowledge trace travels with the save, so the 24-hour cooldown survives a restart.

#### Troubleshooting

| Symptom | Fix |
|---------|-----|
| "THE KNOWLEDGE IS MISSING" screen at startup | The verified bank could not be loaded. If `Assets/Resources/Knowledge/banks.json` or `Questions/bank_*.json` are absent, run the pipeline export below; if they exist, make sure **KaiserQuest → Generate All Assets** has run. Then use the *Try again* button or press Play again. |
| Console shows `bank_*.json missing` or `BankSize == 0` | The realm-to-bank map is missing or stale. Re-run the export (section 4); `Knowledge/banks.json` tells the engine which subject banks each realm reads. |
| Console shows `Music clip not found` / silent game | Run **KaiserQuest → Generate Audio**. Missing audio never blocks play. |
| World looks empty (no keepers) | The world populator waits for the story layer to be ready; make sure the Resources JSONs exist (first row above). |
| Player walks through walls or cannot interact | The layer-mask fallbacks only apply at spawn; if you changed `PlayerController` masks in the Inspector, set them back to `Default` plus the NPC/interactable layers. |
| Milestone says it is locked | Read the reason on the map — it is the mastery gate telling you which concept has faded. Replay that milestone's trial to rebuild it. |

### 2 · Backend (optional — for content generation and analytics)

The game plays entirely offline. The Python side is the authority for *content*
(generation, validation, difficulty estimation) and fleet analytics, not for play:

```bash
cd backend
pip install -r requirements.txt
python main.py                      # http://localhost:8000  ·  /docs
```

### 3 · Tests

```bash
cd backend
PYTHONIOENCODING=utf-8 python -m unittest discover -s tests
```

`PYTHONIOENCODING=utf-8` matters on Windows: the console's default codepage chokes on the
box-drawing characters in the profile renderer. 193 tests pass — they are the executable
specification of the engine.

**Unity PlayMode tests.** 19 tests in `KaiserQuest/Assets/Tests/PlayMode/` boot the real
game loop — no mocks, a private save slot per run, deleted afterwards. They cover trial
flow (a flawless pass moves the save point; answers carry their concept; a wrong answer
teaches), mastery gates (twenty milestones with only the first open; skipping ahead is
refused in words), save round-trips, world runtime (the tileset builds with only walls
solid; the generator paints ground and places cities; raycast masks fall back to
something non-zero), and content loading — including the regression test for the
realm-to-bank mapping bug: *every realm can start its first milestone*. Two boot smoke
tests go further and run the real `GameBootstrap` in an empty scene — the exact path a
first Play press takes — and assert the game appears: camera, tilemaps, a generated
world, a visible animated player standing on walkable ground, and a story screen waiting.

In the Editor: **Window → General → Test Runner → PlayMode tab → Run All**.

Headless (CI-friendly — proven to work with no display):

```bash
"D:/Unity/Editors/6000.3.13f1/Editor/Unity.exe" -batchmode -nographics \
  -projectPath "<repo>/KaiserQuest" \
  -runTests -testPlatform PlayMode \
  -testResults "<repo>/Tools/out/playmode-results.xml" \
  -logFile "<repo>/Tools/out/unity-batch.log"
```

Exit code 0 means every test passed; failures are listed in the results XML with their
messages. The first run re-imports the project and takes a few minutes.

### 4 · Regenerate content (and the Unity export)

```bash
cd backend
PYTHONIOENCODING=utf-8 python -m engine.content.pipeline
```

This writes `data/banks/`, then exports into **every** Unity project in the repo —
`KaiserQuest/Assets/Resources/` and `KaiserQuest-Unity/Assets/Resources/` —
(`Knowledge/concepts.json`, `Knowledge/misconceptions.json`, `Knowledge/banks.json`,
`Questions/bank_<subject>.json`), so both copies stay in sync with what the server serves.
`Knowledge/banks.json` maps each realm to the subject banks it should read — realms and
subjects are not the same namespace (the English realm reads the English *and* math
banks), and deriving that mapping from content is what fixed "no questions ever loaded".
Pass `--unity-dir <path>` to target a single folder instead. The run is deterministic: the
same `--seed` produces byte-identical banks. The pipeline reports `coverage_gaps` honestly:
currently **956 verified questions, 0 quarantined, 88/88 concepts covered**, with 24
concepts still below the 6-question target. Concepts the bank cannot examine are excluded
from mastery gates rather than held against the player.

### 5 · Compile-checking C# without the Editor (maintainers)

```bash
bash Tools/compile-check.sh
```

Four Roslyn passes: the 2022 dev copy, the live Unity 6 runtime assembly, the live editor
assembly with `UNITY_EDITOR` defined, and the PlayMode tests against the NUnit framework.
Every pass references the **real Unity 6 assemblies** from
`KaiserQuest/Library/ScriptAssemblies/` — including uGUI, TextMeshPro and the Input
System — so the legacy v0.2 UI compiles against the actual package APIs, not guesses.
`--stubs` falls back to generated stubs (in `Tools/CompileCheck/`, outside `Assets/`,
never shipped) for use before a project's first import. All four passes are clean.

---

## Status

| Area | State |
|------|-------|
| Backend engine, campaign, progression, Silver Mountain, pipeline | **Done** — 193 tests passing |
| Verified question banks | **956 items**, 88/88 concepts covered |
| Story UI (title, character creation, campaign map, trials, Silver Mountain, Mastery Recap) | **Done** — drawn with IMGUI so it works with zero scene wiring |
| World integration (milestone keepers, save shards, the Archivist on the summit) | **Done** — spawned along the generated road at runtime |
| Overworld presentation (runtime tileset with solid walls, landmark plazas, scenery, ground clearing, place nameplates) | **Done** — milestones are places, not map pins |
| Player presentation (appearance-driven sprite, walk bob, HUD with objective in words, control legend) | **Done** — spawned and animated by the bootstrap |
| PlayMode test suite | **19 tests, all passing** — runs in the Editor or headlessly in batchmode; two of them boot the whole game from an empty scene |
| Self-booting entry (`Boot` + `GameBootstrap`) | **Done** — Play works from any scene, no hand-wiring |
| Full C# tree compiles (story, knowledge, world, tests, legacy v0.2 scripts) | **Verified** — 4-pass Roslyn harness against real Unity 6 assemblies |
| Legacy v0.2 battle/gym/UI scripts | Still in the tree and now compile-verified; superseded by the story layer, which no longer routes through them |

### How the pieces run at play time

```
Boot (RuntimeInitializeOnLoadMethod)
 └─ GameBootstrap
     ├─ GameManager · KnowledgeEngine · StoryModeManager · StoryUI
     ├─ SceneLoader · QuestionBank · AIClient · PvPManager · SideQuestManager
     ├─ PixelSpriteGenerator · SoundManager · WorldManager
     ├─ camera + tilemaps (created if the scene lacks them; runtime tileset applied)
     ├─ ProceduralWorldGenerator ─▶ ProceduralWorldGeneratorHub.Cities
     ├─ KaiserWorldPopulator ─▶ plazas + keeper NPCs + save shards + the Archivist
     ├─ Player ─▶ body sprite from the chosen appearance, walk-bob animator, HUD
     └─ ContinueStory ─▶ StoryUI.Boot ─▶ title or character creation
```

The story screens are modal: while one is open the world stops accepting input, and
answering a trial question and walking away can never happen in the same frame. The
PlayMode suite, the compile harness and the backend tests are the verification; inside
the Editor, the smoke test is the game itself: create → walk to milestone 1 → pass it.

---

## Tech

| Component | Technology |
|-----------|-----------|
| Engine | Unity 6000.3.13f1 (live project) · 2022.3.20f1 (dev copy), C# |
| Rendering | 2D Tilemap, pixel-perfect, low-spec first |
| Testing | Unity Test Framework (PlayMode, headless batchmode) · NUnit · unittest |
| Backend | Python + FastAPI |
| Learner modelling | Bayesian Knowledge Tracing (sklearn for difficulty estimation) |
| Content | Generator → validator → difficulty → human verification → bank |
| Art / audio | Procedurally generated pixel art and 8-bit audio |

---

*Built so that the game knows what you've learned, what you've forgotten, what you're
struggling with, and what you're ready to learn next — and so the player never feels like
they are sitting an exam. They feel like they are becoming stronger in the world.*
