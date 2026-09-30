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
├── KaiserQuest-Unity/                  # Unity 2022.3.20f1
│   ├── Assets/Scripts/
│   │   ├── Knowledge/                  # The engine port (offline authority for play)
│   │   │   ├── ConceptGraph.cs         # 88 concepts, prereq closure, frontier
│   │   │   ├── KnowledgeTracer.cs      # BKT, mastery, confidence, forgetting
│   │   │   ├── MisconceptionDetector.cs
│   │   │   ├── KnowledgeProfile.cs     # domains, confidence buckets, next-up
│   │   │   ├── KnowledgeEngine.cs      # loading, adaptive select, grading
│   │   │   ├── AttemptLog.cs, KnowledgeData.cs
│   │   ├── Story/                      # The campaign
│   │   │   ├── TrialModes.cs           # 13 trial modes
│   │   │   ├── MilestoneCatalog.cs     # the 20-milestone arc, per-realm flavour
│   │   │   ├── TrialRunner.cs          # the mechanics, as selection/grading policy
│   │   │   ├── ProgressionService.cs   # entry + pass gates
│   │   │   ├── SilverMountainController.cs  # exam assembly, attempts, recap
│   │   │   ├── StoryModeManager.cs     # orchestrator
│   │   │   ├── CharacterCreation.cs    # name, appearance presets, starting realm
│   │   │   ├── SaveSystem.cs           # versioned, atomic JSON saves
│   │   │   └── StoryProgress.cs        # the save format
│   │   ├── Core/                       # GameManager, GameBootstrap, sprite/audio/tiles
│   │   ├── AI/ Battle/ Camera/ Gym/ Multiplayer/ NPC/ Player/ Quests/ UI/ World/
│   │   │                               # v0.2 systems still present; see Status below
│   │   └── Core/Editor/                # TilesetGenerator, AudioGenerator, setup wizard
│   └── Assets/Resources/
│       ├── Knowledge/                  # concepts.json, misconceptions.json (exported)
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
    └── tests/                          # 193 tests — the executable specification
```

---

## Running it

### Backend

```bash
cd backend
pip install -r requirements.txt
python main.py                      # http://localhost:8000  ·  /docs
```

### Tests

```bash
cd backend
PYTHONIOENCODING=utf-8 python -m unittest discover -s tests
```

`PYTHONIOENCODING=utf-8` matters on Windows: the console's default codepage chokes on the
box-drawing characters in the profile renderer.

### Regenerate content (and the Unity export)

```bash
cd backend
PYTHONIOENCODING=utf-8 python -m engine.content.pipeline
```

This writes `data/banks/`, then exports into `KaiserQuest-Unity/Assets/Resources/`
(`Knowledge/concepts.json`, `Knowledge/misconceptions.json`, `Questions/bank_<realm>.json`).
The pipeline reports `coverage_gaps` honestly: currently **956 verified questions, 0
quarantined, 88/88 concepts covered**, with 24 concepts still below the 6-question target.
Concepts the bank cannot examine are excluded from mastery gates rather than held against
the player.

### Unity

1. Open `KaiserQuest-Unity/` in **Unity 2022.3.20f1**.
2. **KaiserQuest → Generate All Assets**, then **KaiserQuest → Generate Audio**.
3. Open `Assets/Scenes/Overworld.unity` and press Play.
4. WASD/arrows to move, Z/Enter/Space to interact, Esc to pause.

`GameBootstrap` starts `KnowledgeEngine` → `StoryModeManager` in that order and resumes the
last story save, so a player returns to the place they rested — which is exactly what makes
the Silver Mountain rule mean anything.

---

## Status

| Area | State |
|------|-------|
| Backend engine, campaign, progression, Silver Mountain, pipeline | **Done** — 193 tests passing |
| Verified question banks | **956 items**, 88/88 concepts covered |
| Unity knowledge layer (`Knowledge/*.cs`) | **Compiles clean** against Unity 2022.3 assemblies |
| Unity story layer (`Story/*.cs`) | **Compiles clean** against Unity 2022.3 assemblies |
| Scripted trial / Silver Mountain **UI screens** | Not built — the layer is headless by design and awaits presentation |
| World integration (keepers in the overworld, save-point objects) | Pending |
| Legacy v0.2 scripts (`BattleManager`, `GymSystem`, `AIClient`, `PvPManager`, `UI/`, `World/`) | Superseded; still in the tree. `GameManager`'s level gate has been replaced with the mastery gate |

Compilation was verified with Unity's own Roslyn compiler and 2022.3 assemblies rather than
inside the Editor; the four legacy UI scripts resolve `UnityEngine.UI`/TextMeshPro package
assemblies, which only exist after an Editor import.

---

## Tech

| Component | Technology |
|-----------|-----------|
| Engine | Unity 2022.3.20f1, C# |
| Rendering | 2D Tilemap, pixel-perfect, low-spec first |
| Backend | Python + FastAPI |
| Learner modelling | Bayesian Knowledge Tracing (sklearn for difficulty estimation) |
| Content | Generator → validator → difficulty → human verification → bank |
| Art / audio | Procedurally generated pixel art and 8-bit audio |

---

*Built so that the game knows what you've learned, what you've forgotten, what you're
struggling with, and what you're ready to learn next — and so the player never feels like
they are sitting an exam. They feel like they are becoming stronger in the world.*
