using System;
using System.Collections.Generic;
using KaiserQuest.Knowledge;
using UnityEngine;

namespace KaiserQuest.Story
{
    /// <summary>
    /// Which overlay StoryUI is currently drawing.
    ///
    /// Overworld is "no overlay": the map is behind the walking-around world, and the
    /// rest are the screens the story plays through.
    /// </summary>
    public enum StoryScreen
    {
        None,
        Title,
        CharacterCreation,
        CampaignMap,
        Trial,
        Victory,
        Dialogue,
        Encounter,
        MountainGate,
        Exam,
        Recap,
        ContentMissing
    }

    /// <summary>One exam answer collected by the exam screen.</summary>
    public class ExamAnswerInput
    {
        public string QuestionId;
        public string Chosen;
        public float ResponseTimeMs;
        public int HintsUsed;
    }

    /// <summary>
    /// The entire story-mode user interface.
    ///
    /// Drawn with IMGUI on purpose. The 2 GB Android target has to load this project
    /// with no prefabs, no scenes wired by hand and no Canvas tree to forget; IMGUI
    /// code that compiles is code that works, and it composes over the tile world
    /// exactly like a Pokémon menu does.
    ///
    /// It contains no rules. Entry checks, trial assembly, grading, mastery gates,
    /// the Archivist's verdict — all of it is asked of StoryModeManager and the
    /// Knowledge Engine. This class is how their decisions reach the screen.
    /// </summary>
    public class StoryUI : MonoBehaviour
    {
        public static StoryUI Instance { get; private set; }

        [Header("Display")]
        public int fontSize = 15;
        public float maxWidth = 900f;
        public float maxHeight = 620f;

        private StoryScreen _screen = StoryScreen.None;
        private Vector2 _scroll;
        private string _statusLine = "";
        private GUIStyle _big, _head, _body, _dim, _btn, _btnChosen, _box, _boxChosen;

        // --- character creation state ---
        private string _nameField = KaiserQuest.Story.CharacterCreation.DefaultName;
        private int _appearanceIndex;
        private int _realmIndex;

        // --- trial session state ---
        private TrialRunner _trial;
        private string _trialRealm;
        private string _trialTitle = "";
        private string _trialIntro = "";
        private string _feedback = "";
        private float _questionShownAt;
        private int _hintsThisQuestion;

        // --- exam session state ---
        private ExamPaper _paper;
        private List<ExamAnswerInput> _examAnswers;
        private int _examIndex;
        private float _examShownAt;
        private int _examHints;

        private ExamResult _examResult;

        // --- victory state ---
        private TrialSettlement _victory;
        private Texture2D _badgeTexture;

        // --- dialogue state ---
        private string _dialogueSpeaker = "";
        private List<string> _dialogueLines;
        private int _dialogueIndex;

        // --- world encounter state ---
        private KnowledgeEncounter _encounter;
        private KnowledgeGate _encounterGate;
        private float _encounterShownAt;

        private StoryModeManager Story { get { return StoryModeManager.Instance; } }
        private GameManager Game { get { return GameManager.Instance; } }

        public bool IsOpen { get { return _screen != StoryScreen.None; } }

        /// <summary>True while a story screen holds the world: walking and X are suspended.</summary>
        public static bool BlocksWorldInput
        {
            get { return Instance != null && Instance.IsOpen; }
        }

        // ------------------------------------------------------------------
        // Lifecycle
        // ------------------------------------------------------------------
        private void Awake()
        {
            if (Instance != null && Instance != this) { Destroy(gameObject); return; }
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }

        private void Update()
        {
            if (_screen != StoryScreen.None && Game != null && Game.currentState != GameState.Paused)
                Game.SetGameState(GameState.Paused);
        }

        /// <summary>
        /// Open the title screen. Called by GameBootstrap on every launch: a save
        /// continues from where it was left, otherwise creation runs first.
        /// </summary>
        public void Boot()
        {
            if (Story == null || !Story.Ready)
            {
                Debug.LogWarning("[StoryUI] Boot called before the story layer was ready — showing why.");
                ShowContentMissing(
                    "The Knowledge Engine could not load the concept graph and question banks from Resources. "
                    + "The game cannot run without them: the mastery gates have nothing to read and the trials "
                    + "have nothing to ask.");
                return;
            }

            // Ready only means the graph and a save are in hand. A graph with no
            // questions behind it is a campaign that lets the player create a
            // character and then refuses every keeper — better said on the first
            // screen than discovered at the first trial.
            KnowledgeEngine engine = KnowledgeEngine.Instance;
            if (engine != null && engine.BankSize == 0)
            {
                Debug.LogWarning("[StoryUI] The question banks are empty — no trial can start.");
                ShowContentMissing(
                    "The concept graph loaded, but no questions came with it, so no milestone could be "
                    + "examined and every keeper would turn you away. The verified banks are missing from "
                    + "Assets/Resources/Questions/ (or the realm-to-bank mapping is missing from "
                    + "Assets/Resources/Knowledge/). Run the content pipeline, then press Try again.");
                return;
            }

            if (Story.HasSave(Story.saveSlotId))
            {
                ShowTitle();
            }
            else
            {
                BeginCreation();
            }
        }

        // ------------------------------------------------------------------
        // Screen openers (the vocabulary the rest of the game calls)
        // ------------------------------------------------------------------
        public void ShowTitle()
        {
            CloseAndResume();
            _screen = StoryScreen.Title;
        }

        public void BeginCreation()
        {
            CloseAndResume();
            _screen = StoryScreen.CharacterCreation;
            _nameField = KaiserQuest.Story.CharacterCreation.DefaultName;
            _appearanceIndex = 0;
            _realmIndex = 0;
            _statusLine = "";
        }

        public void ShowCampaign()
        {
            if (!StoryReady()) return;
            CloseAndResume();
            _screen = StoryScreen.CampaignMap;
            _statusLine = "";
        }

        /// <summary>Open the trial for a milestone, after the keeper's entry check.</summary>
        public void ShowTrial(string realmId, int milestoneIndex)
        {
            StoryModeManager story = Story;
            if (!StoryReady() || story == null) return;

            EntryCheck entry;
            string error;
            TrialRunner runner = story.StartTrial(realmId, milestoneIndex, out entry, out error);
            if (runner == null)
            {
                // ShowCampaign clears the status line, so the keeper's reason goes
                // on the map afterwards, not before.
                ShowCampaign();
                _statusLine = error;
                return;
            }

            CloseAndResume();
            _screen = StoryScreen.Trial;
            _trial = runner;
            _trialRealm = story.ActiveRealm;
            _trialTitle = "Trial " + runner.Milestone.Index + " \u2014 " + runner.Milestone.Name
                + "  (" + runner.Milestone.Place + ")";
            _trialIntro = runner.Intro() + "\n\n" + runner.Milestone.Setup;
            _feedback = "";
            _questionShownAt = Time.unscaledTime;
            _hintsThisQuestion = 0;

            if (Game != null) Game.playerData.playerName = story.Save.playerName;
            SoundManager.PlaySfx("menu_confirm");
        }

        public void ShowMountainGate()
        {
            if (!StoryReady()) return;
            CloseAndResume();
            _screen = StoryScreen.MountainGate;
            _statusLine = "";
        }

        /// <summary>Take the Archivist's exam, after the gate screen's confirmation.</summary>
        public void ShowExam()
        {
            StoryModeManager story = Story;
            if (!StoryReady() || story == null) return;

            ExamPaper paper = story.ChallengeSilver(story.ActiveRealmId);
            if (paper == null || !paper.Granted)
            {
                _statusLine = paper != null ? paper.Reason : "The Archivist will not grant the climb.";
                return;
            }

            _screen = StoryScreen.Exam;
            _paper = paper;
            _examAnswers = new List<ExamAnswerInput>();
            _examIndex = 0;
            _examShownAt = Time.unscaledTime;
            _examHints = 0;
            SoundManager.PlaySfx("menu_confirm");
        }

        /// <summary>Open the recap at a save point, after a failed window.</summary>
        public void ShowRecap()
        {
            if (!StoryReady()) return;
            CloseAndResume();
            _screen = StoryScreen.Recap;
        }

        /// <summary>
        /// Somebody says something. Used by the town's people and its signposts.
        ///
        /// Dialogue is a screen of its own rather than a line printed over the map
        /// because the first quest is explained in it, and an explanation the player
        /// can read at their own pace is the difference between a quest and a rumour.
        /// </summary>
        public void ShowDialogue(string speaker, List<string> lines)
        {
            CloseAndResume();
            _screen = StoryScreen.Dialogue;
            _dialogueSpeaker = speaker;
            _dialogueLines = lines != null ? lines : new List<string>();
            _dialogueIndex = 0;
            SoundManager.PlaySfx("dialog_beep");
        }

        /// <summary>
        /// Face a world mechanism that wants a relationship solved.
        ///
        /// The question is drawn from the verified bank through the Knowledge Engine
        /// every time this opens; the story layer neither holds a question nor knows
        /// an answer. When the bank genuinely has nothing to ask, the player is told
        /// that the fault is the town's and not theirs, because a mechanism that has
        /// silently stopped working is the worst possible first impression.
        /// </summary>
        public void ShowEncounter(KnowledgeGate gate)
        {
            StoryModeManager story = Story;
            if (!StoryReady() || story == null || gate == null) return;

            KnowledgeEngine engine = KnowledgeEngine.Instance;
            Milestone milestone = gate.MilestoneFor(story);
            string concept = AsterQuest.OpeningConcept(engine, milestone);

            KnowledgeEncounter encounter = new KnowledgeEncounter();
            bool begun = !string.IsNullOrEmpty(concept)
                && encounter.Begin(engine, concept, story.ActiveRealmId, story.Save.recentQuestionIds);

            if (!begun)
            {
                ShowDialogue("The eastern gate", new List<string>
                {
                    "You put your hand on the mechanism and it gives nothing back \u2014 not "
                    + "refusal, but nothing at all.",
                    "A keeper passing behind you looks at it a while. \u201cThat one is waiting "
                    + "for a question, and there isn\u2019t one in it any more. That is our fault, "
                    + "not yours. Walk on; the Archivists will restock it.\u201d"
                });
                return;
            }

            CloseAndResume();
            _screen = StoryScreen.Encounter;
            _encounter = encounter;
            _encounterGate = gate;
            _encounterShownAt = Time.unscaledTime;
            SoundManager.PlaySfx("menu_confirm");
        }

        /// <summary>
        /// The moment the reward lands.
        ///
        /// A milestone that quietly updates a counter has not been *earned*; the
        /// player has to see the sigil, be told what changed, and be told where the
        /// road goes next. This is the screen the whole mastery-gate design exists to
        /// make worth reaching.
        /// </summary>
        public void ShowVictory(TrialSettlement settled)
        {
            CloseAndResume();
            _screen = StoryScreen.Victory;
            _victory = settled;
            _badgeTexture = null;
        }

        public void Close()
        {
            CloseAndResume();
        }

        /// <summary>
        /// The honest screen: shown when the Knowledge Engine could not find its
        /// data in Resources. Every other failure in this file is a message; this
        /// one is a wall of text because the player can fix it, by running the
        /// generator once in the Editor.
        /// </summary>
        public void ShowContentMissing(string why)
        {
            _contentMissingWhy = why;
            CloseAndResume();
            _screen = StoryScreen.ContentMissing;
        }

        private string _contentMissingWhy = "";

        private void CloseAndResume()
        {
            if (Game != null) Game.SetGameState(GameState.Overworld);
        }

        private bool StoryReady()
        {
            if (Story == null || !Story.Ready)
            {
                Debug.LogWarning("[StoryUI] Story layer not ready (KnowledgeEngine + a loaded save are required).");
                return false;
            }
            return true;
        }

        // ------------------------------------------------------------------
        // Drawing
        // ------------------------------------------------------------------
        private void OnGUI()
        {
            if (Event.current.type == EventType.KeyDown && Event.current.keyCode == KeyCode.Escape)
            {
                OnEscape();
                Event.current.Use();
                return;
            }

            EnsureStyles();

            Rect full = new Rect(0, 0, Screen.width, Screen.height);
            GUI.Box(full, GUIContent.none);

            Rect area = Centered();
            GUILayout.BeginArea(area);
            try
            {
                switch (_screen)
                {
                    case StoryScreen.Title: DrawTitle(); break;
                    case StoryScreen.CharacterCreation: DrawCreation(); break;
                    case StoryScreen.CampaignMap: DrawCampaign(); break;
                    case StoryScreen.Trial: DrawTrial(); break;
                    case StoryScreen.Victory: DrawVictory(); break;
                    case StoryScreen.Dialogue: DrawDialogue(); break;
                    case StoryScreen.Encounter: DrawEncounter(); break;
                    case StoryScreen.MountainGate: DrawMountainGate(); break;
                    case StoryScreen.Exam: DrawExam(); break;
                    case StoryScreen.Recap: DrawRecap(); break;
                    case StoryScreen.ContentMissing: DrawContentMissing(); break;
                }
            }
            finally
            {
                GUILayout.EndArea();
            }
        }

        private Rect Centered()
        {
            float w = Mathf.Min(maxWidth, Screen.width - 16f);
            float h = Mathf.Min(maxHeight, Screen.height - 16f);
            return new Rect((Screen.width - w) / 2f, (Screen.height - h) / 2f, w, h);
        }

        private void EnsureStyles()
        {
            if (_body != null && _body.fontSize == fontSize) return;

            int big = Mathf.Max(24, Mathf.RoundToInt(fontSize * 2.1f));
            int head = Mathf.Max(17, Mathf.RoundToInt(fontSize * 1.3f));

            _big = Make(big, TextAnchor.UpperCenter, FontStyle.Bold, new Color(0.92f, 0.95f, 1f));
            _head = Make(head, TextAnchor.UpperLeft, FontStyle.Bold, new Color(0.9f, 0.93f, 1f));
            _body = Make(fontSize, TextAnchor.UpperLeft, FontStyle.Normal, new Color(0.92f, 0.92f, 0.95f));
            _body.wordWrap = true;
            _dim = Make(Mathf.Max(12, fontSize - 2), TextAnchor.UpperLeft, FontStyle.Italic, new Color(0.68f, 0.7f, 0.76f));
            _dim.wordWrap = true;
            _btn = Make(fontSize, TextAnchor.MiddleCenter, FontStyle.Normal, new Color(0.88f, 0.9f, 0.95f));
            _btnChosen = Make(fontSize, TextAnchor.MiddleCenter, FontStyle.Bold, Color.white);
            _box = Make(fontSize, TextAnchor.UpperLeft, FontStyle.Normal, new Color(0.9f, 0.9f, 0.93f));
            _box.wordWrap = true;
            _box.padding = new RectOffset(10, 10, 8, 8);
            _boxChosen = Make(fontSize, TextAnchor.UpperLeft, FontStyle.Bold, new Color(1f, 0.95f, 0.75f));
            _boxChosen.wordWrap = true;
            _boxChosen.padding = _box.padding;
        }

        private static GUIStyle Make(int size, TextAnchor anchor, FontStyle style, Color color)
        {
            GUIStyle s = new GUIStyle(GUI.skin.label);
            s.fontSize = size;
            s.fontStyle = style;
            s.alignment = anchor;
            s.normal.textColor = color;
            s.richText = false;
            return s;
        }

        private bool Button(string label, float height = 34f, bool chosen = false)
        {
            GUIStyle style = chosen ? _btnChosen : _btn;
            GUILayout.BeginHorizontal();
            GUILayout.FlexibleSpace();
            bool clicked = GUILayout.Button(label, style, GUILayout.Height(height), GUILayout.Width(Centered().width * 0.62f));
            GUILayout.FlexibleSpace();
            GUILayout.EndHorizontal();
            if (clicked) SoundManager.PlaySfx("menu_select");
            return clicked;
        }

        private void OnEscape()
        {
            StoryModeManager story = Story;

            switch (_screen)
            {
                case StoryScreen.Trial:
                    if (_trial != null) _trial.Abandon();
                    if (story != null && story.Save != null) story.SaveNow();
                    ShowCampaign();
                    break;
                case StoryScreen.Dialogue:
                    AdvanceDialogue();
                    break;
                case StoryScreen.Victory:
                    Close();
                    break;
                case StoryScreen.Encounter:
                    // Walking away is allowed and costs nothing: the mechanism is not
                    // going anywhere, and answers already given were already learned
                    // from. What it must not do is trap the player in front of it.
                    _encounter = null;
                    _encounterGate = null;
                    if (story != null && story.Save != null) story.SaveNow();
                    Close();
                    break;
                case StoryScreen.Exam:
                    // An exam cannot be walked out of: the attempt counts.
                    _statusLine = "The Archivist watches. There is no leaving mid-exam \u2014 answer or be scored.";
                    break;
                case StoryScreen.CharacterCreation:
                case StoryScreen.Title:
                    break;
                default:
                    ShowCampaign();
                    break;
            }
        }

        // ==================================================================
        // Content missing
        // ==================================================================
        private void DrawContentMissing()
        {
            ScrollStart();
            GUILayout.Label("THE KNOWLEDGE IS MISSING", _big);
            GUILayout.Label("a generator step was not run", _dim);
            GUILayout.Space(8);

            GUILayout.Label(_contentMissingWhy, _body);
            GUILayout.Space(8);

            GUILayout.Label("How to fix it", _head);
            GUILayout.Label(
                "1. Open this project in Unity 2022.3.20f1 and wait for the compile to finish.\n"
                + "2. Menu bar: KaiserQuest \u25b8 Generate All Assets (builds the concept graph, the question "
                + "banks and the audio).\n"
                + "3. Press Play. This screen will not appear again.", _body);
            GUILayout.Space(4);
            GUILayout.Label(
                "The game is deliberately offline: every question, every mastery gate and the Archivist's "
                + "exam are read from Resources at startup, so a phone with 2 GB of memory can run the whole "
                + "story with no server. That is why the data has to exist here, now.", _dim);

            GUILayout.Space(10);
            if (Button("Try again"))
            {
                StoryModeManager story = Story;
                if (story != null)
                {
                    story.Rebuild();
                    KnowledgeEngine engine = KnowledgeEngine.Instance;
                    if (engine != null) engine.LoadAll();
                    Boot();
                    return;
                }
            }
            ScrollEnd();
        }

        // ==================================================================
        // Title
        // ==================================================================
        private void DrawTitle()
        {
            StoryModeManager story = Story;
            if (story == null) return;

            if (story.Save == null)
            {
                // The title can be reached without a loaded save (the recovery
                // path re-boots the UI after the engine reloads). Load it, or fall
                // through to creation when there is nothing to load.
                if (story.HasSave(story.saveSlotId)) story.LoadGame(story.saveSlotId);
                else { BeginCreation(); return; }
            }

            GUILayout.FlexibleSpace();
            GUILayout.Label("KAISERQUEST", _big);
            GUILayout.Label("learning is the way the world is saved", _dim);
            GUILayout.FlexibleSpace();

            SaveGameData save = Story.Save;
            GUILayout.Label(
                save.playerName + " of " + RegionOf(save.realm)
                + " \u2014 resting at " + Where(save), _body);
            GUILayout.Space(12);

            if (Button("Continue")) ShowCampaign();
            if (Button("New character")) BeginCreation();
            if (Button("Delete save"))
            {
                SaveSystem.Delete(story.saveSlotId);
                BeginCreation();
            }
            if (Button("Quit"))
            {
#if UNITY_EDITOR
                UnityEditor.EditorApplication.isPlaying = false;
#else
                Application.Quit();
#endif
            }
            GUILayout.FlexibleSpace();
        }

        private string RegionOf(string realm)
        {
            RealmFlavor flavor = MilestoneCatalog.FlavorFor(realm);
            return flavor != null ? flavor.Region : realm;
        }

        private string Where(SaveGameData save)
        {
            return save.savePoint != null && !string.IsNullOrEmpty(save.savePoint.place)
                ? save.savePoint.place
                : "the beginning";
        }

        // ==================================================================
        // Character creation
        // ==================================================================
        private void DrawCreation()
        {
            ScrollStart();
            GUILayout.Label("A new explorer", _big);
            GUILayout.Space(4);
            GUILayout.Label(
                "You will not pick a class, a level or a difficulty. The only thing that grows in Kaiserland "
                + "is what you understand.", _dim);
            GUILayout.Space(8);

            GUILayout.Label("Your name", _head);
            _nameField = GUILayout.TextField(_nameField);
            string cleaned = KaiserQuest.Story.CharacterCreation.ValidateName(_nameField);
            if (cleaned != _nameField) GUILayout.Label("Will travel as: " + cleaned, _dim);

            GUILayout.Space(8);
            GUILayout.Label("How you look", _head);
            List<AppearancePreset> looks = KaiserQuest.Story.CharacterCreation.Appearances;
            _appearanceIndex = Mathf.Clamp(_appearanceIndex, 0, looks.Count - 1);
            AppearancePreset look = looks[_appearanceIndex];
            GUILayout.Label(look.name + " \u2014 " + look.description, _body);
            GUILayout.BeginHorizontal();
            if (GUILayout.Button("<", GUILayout.Width(46))) { _appearanceIndex = (_appearanceIndex + looks.Count - 1) % looks.Count; SoundManager.PlaySfx("menu_select"); }
            GUILayout.FlexibleSpace();
            GUILayout.Label((_appearanceIndex + 1) + " / " + looks.Count, _body);
            GUILayout.FlexibleSpace();
            if (GUILayout.Button(">", GUILayout.Width(46))) { _appearanceIndex = (_appearanceIndex + 1) % looks.Count; SoundManager.PlaySfx("menu_select"); }
            GUILayout.EndHorizontal();

            GUILayout.Space(8);
            GUILayout.Label("Which realm first?", _head);
            List<RealmChoice> realms = KaiserQuest.Story.CharacterCreation.Realms(KnowledgeEngine.Instance);
            if (realms.Count > 0)
            {
                _realmIndex = Mathf.Clamp(_realmIndex, 0, realms.Count - 1);
                RealmChoice realm = realms[_realmIndex];
                GUILayout.Label(
                    realm.Name + "  " + realm.Sigil + "\n" + realm.Tagline + "\n"
                    + realm.ConceptCount + " concepts \u00b7 " + MilestoneCatalog.ArcNames.Length + " milestones",
                    _body);
                GUILayout.BeginHorizontal();
                if (GUILayout.Button("<", GUILayout.Width(46))) { _realmIndex = (_realmIndex + realms.Count - 1) % realms.Count; SoundManager.PlaySfx("menu_select"); }
                GUILayout.FlexibleSpace();
                GUILayout.Label((_realmIndex + 1) + " / " + realms.Count, _body);
                GUILayout.FlexibleSpace();
                if (GUILayout.Button(">", GUILayout.Width(46))) { _realmIndex = (_realmIndex + 1) % realms.Count; SoundManager.PlaySfx("menu_select"); }
                GUILayout.EndHorizontal();
            }

            GUILayout.Space(12);
            if (Button("Set out  \u25b8"))
            {
                StoryModeManager story = Story;
                SaveGameData save = story.NewGame(cleaned, look.id, realms.Count > 0 ? realms[_realmIndex].Id : "algebra");
                if (Game != null) Game.playerData.playerName = save.playerName;
                Debug.Log("[StoryUI] New game: " + save.playerName + " enters " + RegionOf(save.realm));
                ShowCampaign();
            }
            ScrollEnd();
        }

        // ==================================================================
        // Campaign map
        // ==================================================================
        private void DrawCampaign()
        {
            StoryModeManager story = Story;
            CampaignDetail detail = story.CampaignDetail();

            ScrollStart();
            GUILayout.Label(detail.RealmName, _big);
            GUILayout.Label(
                RegionOf(detail.Realm) + " \u00b7 " + detail.PassedCount + " / " + detail.Total
                + " milestones \u00b7 realm mastery " + Percent(detail.OverallMastery), _dim);
            GUILayout.Space(6);

            // The road: every milestone, in order.
            _scroll = GUILayout.BeginScrollView(_scroll, GUILayout.Height(Centered().height * 0.56f));
            for (int i = 0; i < detail.Milestones.Count; i++)
            {
                MilestoneState m = detail.Milestones[i];
                string line = m.State == "cleared" ? "[x] " : (m.State == "available" ? " \u25b8 " : "   ");
                line += m.Index + ". " + m.Name + " \u2014 " + m.Place;
                if (m.State == "cleared") line += "  (best " + Percent(m.BestScore / 100f) + ")";
                if (m.Attempts > 0 && m.State != "cleared") line += "  \u00b7 " + m.Attempts + " attempt" + (m.Attempts == 1 ? "" : "s");

                if (m.State == "available" && Button(line, 30))
                {
                    TrialBrief(m);
                    return;
                }
                else if (m.State == "available")
                {
                    GUILayout.Label("      " + m.Keeper + " \u00b7 " + m.Kind, _dim);
                }
                else if (m.State == "locked" && m.Entry != null && m.Entry.Reasons.Count > 0)
                {
                    // A locked milestone says why it is locked, never just a padlock.
                    GUILayout.Label(line, _dim);
                    GUILayout.Label("      " + m.Entry.Reasons[0], _dim);
                }
                else
                {
                    GUILayout.Label(line, m.State == "cleared" ? _body : _dim);
                }
            }

            if (detail.Completed)
            {
                GUILayout.Space(6);
                GUILayout.Label("The realm is finished. Silver Mountain waits to the north.", _body);
            }
            GUILayout.EndScrollView();

            GUILayout.Space(8);

            MountainStatus status = story.SilverStatus(detail.Realm);
            if (status.CanChallenge && Button(" \u25b2 Silver Mountain \u2014 " + status.AttemptsRemaining + " attempt"
                + (status.AttemptsRemaining == 1 ? "" : "s") + " in this window", 34))
            {
                ShowMountainGate();
                return;
            }
            if (detail.Completed && !status.CanChallenge && GUILayout.Button(" \u25b2 Silver Mountain \u2014 " + status.Reason, _btn))
            {
                ShowMountainGate();
                return;
            }

            if (_statusLine.Length > 0) GUILayout.Label(_statusLine, _dim);

            GUILayout.Space(6);
            GUILayout.BeginHorizontal();
            if (GUILayout.Button("Rest & save here", _btn, GUILayout.Height(30)))
            {
                SavePointData point = story.SavePoint(detail.Realm, SaveIndexOf(detail), Where(story.Save));
                _statusLine = "Resting at " + point.place + ". The journey is written down.";
            }
            if (GUILayout.Button("World (walk)", _btn, GUILayout.Height(30)))
            {
                CloseAndResume();
                return;
            }
            if (GUILayout.Button("Title", _btn, GUILayout.Height(30))) { ShowTitle(); return; }
            GUILayout.EndHorizontal();
            ScrollEnd();
        }

        private int SaveIndexOf(CampaignDetail detail)
        {
            if (detail.Completed) return detail.Total;
            return detail.Current != null ? detail.Current.Index : 1;
        }

        private void TrialBrief(MilestoneState m)
        {
            // The entry check has already allowed this; the brief is the invitation.
            _statusLine = "";
            ShowTrial(Story.ActiveRealmId, m.Index);
        }

        // ==================================================================
        // Trial
        // ==================================================================
        private void DrawTrial()
        {
            TrialRunner runner = _trial;
            if (runner == null) { ShowCampaign(); return; }

            if (runner.IsComplete)
            {
                SettleAndReport(runner);
                return;
            }

            TrialStep step = runner.Current;
            if (step == null || step.Question == null) { SettleAndReport(runner); return; }

            ScrollStart();
            GUILayout.Label(_trialTitle, _head);
            if (_feedback.Length > 0) GUILayout.Label(_feedback, _dim);
            GUILayout.Space(2);

            float progress = runner.PlannedTotal > 0
                ? Mathf.Min(1f, runner.Answered / (float)runner.PlannedTotal)
                : 0f;
            GUILayout.HorizontalScrollbar(progress, 0.05f, 0, 1, GUILayout.Height(12));
            GUILayout.Label(
                runner.Mechanic.Replace('_', ' ') + " \u00b7 " + runner.Answered + " asked \u00b7 "
                + runner.CorrectCount + " right \u00b7 need " + runner.RequiredCorrect
                + (runner.HintsAllowed > 0 ? " \u00b7 hints " + _hintsThisQuestion + "/" + runner.HintsAllowed : ""),
                _dim);
            GUILayout.Space(4);

            GUILayout.Label(step.Prompt, _body);
            GUILayout.Space(4);
            GUILayout.Label(step.Question.question, _box);
            GUILayout.Space(6);

            List<string> options = step.Question.options;
            for (int i = 0; i < options.Count; i++)
            {
                string option = options[i];
                if (Button((char)('A' + i) + ".  " + option, 30))
                {
                    AnswerTrial(runner, option);
                    return;
                }
            }

            if (runner.HintsAllowed > 0 && _hintsThisQuestion < runner.HintsAllowed
                && GUILayout.Button("Ask for a hint (" + (runner.HintsAllowed - _hintsThisQuestion) + " left)", _btn))
            {
                _hintsThisQuestion++;
                _statusLine = HintFor(step);
            }
            if (_statusLine.Length > 0) GUILayout.Label(_statusLine, _dim);

            if (GUILayout.Button("Retreat from the trial (no result recorded)", _dim))
            {
                OnEscape();
                return;
            }
            ScrollEnd();
        }

        private void AnswerTrial(TrialRunner runner, string chosen)
        {
            float elapsed = (Time.unscaledTime - _questionShownAt) * 1000f;
            GradedAnswer graded = runner.Answer(chosen, elapsed, _hintsThisQuestion);
            _hintsThisQuestion = 0;
            _questionShownAt = Time.unscaledTime;
            _statusLine = "";

            if (graded != null)
            {
                _feedback = (graded.Correct ? "\u2713 Right. " : "\u2717 Not right. ")
                    + graded.ConceptName + ": " + graded.Explanation;
                SoundManager.PlaySfx(graded.Correct ? "correct" : "wrong");
            }
        }

        private string HintFor(TrialStep step)
        {
            BankQuestion q = step.Question;
            if (q.misconceptionTags != null && q.misconceptionTags.Count > 0)
            {
                return "Careful: one of the wrong options is a mistake people actually make.";
            }
            return "Read it once more slowly, then answer \u2014 the question is more literal than it looks.";
        }

        /// <summary>Judge the finished trial and report what it changed.</summary>
        private void SettleAndReport(TrialRunner runner)
        {
            TrialSettlement settled = Story.SettleTrial(runner);
            _trial = null;
            if (settled == null)
            {
                ShowCampaign();
                return;
            }

            SoundManager.PlaySfx(settled.Passed ? "victory" : "defeat");

            // Passing is a moment, not a line of small print on the map: the player
            // earned a sigil and needs to see it. Failing is information, and belongs
            // beside the road it happened on, with the reason attached.
            if (settled.Passed)
            {
                ShowVictory(settled);
                return;
            }

            ShowCampaign();

            MilestoneOutcome outcome = settled.Outcome;
            _statusLine =
                (outcome.Passed ? "PASSED \u2014 " : "NOT PASSED \u2014 ")
                + "score " + Percent(outcome.ScorePercent / 100f) + " (needed "
                + Percent(outcome.RequiredPercent / 100f) + "), mastery coverage "
                + Percent(outcome.MasteryCoverage) + ".\n"
                + outcome.Feedback
                + (outcome.Passed && settled.MovedSavePoint
                    ? "\nYour save point moves to " + settled.Milestone.Place + "."
                    : "")
                + (outcome.BlockedBy.Count > 0
                    ? "\nWeak under the gate: " + NameList(outcome.BlockedBy) + "."
                    : "");
        }

        private static string NameList(List<ConceptStatus> concepts)
        {
            List<string> names = new List<string>();
            for (int i = 0; i < concepts.Count; i++) names.Add(concepts[i].Name);
            return string.Join(", ", names.ToArray());
        }

        private static string Percent(float fraction)
        {
            return Mathf.RoundToInt(Mathf.Clamp01(fraction) * 100f) + "%";
        }

        // ==================================================================
        // Silver Mountain
        // ==================================================================
        private void DrawMountainGate()
        {
            StoryModeManager story = Story;
            MountainStatus status = story.SilverStatus(story.ActiveRealmId);

            ScrollStart();
            GUILayout.Label("SILVER MOUNTAIN", _big);
            GUILayout.Label("The last region. The Archivist keeps it.", _dim);
            GUILayout.Space(8);

            GUILayout.Label(status.Reason, _body);
            GUILayout.Space(4);
            GUILayout.Label(
                "Cleared trials: " + status.MilestonesPassed + " / " + status.MilestonesTotal
                + "  \u00b7  Attempts left in this window: " + status.AttemptsRemaining + " / " + status.AttemptsTotal
                + "  \u00b7  The exam is " + status.ExamQuestions + " questions and needs "
                + status.ExamRequiredCorrect + " right.", _body);

            if (status.History.Count > 0)
            {
                GUILayout.Space(4);
                GUILayout.Label("Your climbs:", _head);
                for (int i = 0; i < status.History.Count; i++)
                {
                    ArchivistAttemptData attempt = status.History[i];
                    GUILayout.Label(
                        "  #" + attempt.number + " \u2014 " + Percent(attempt.scorePercent / 100f)
                        + (attempt.passed ? "  (passed)" : ""), _dim);
                }
            }

            GUILayout.Space(10);
            if (_statusLine.Length > 0) GUILayout.Label(_statusLine, _dim);

            if (status.CanChallenge && Button("Face the Archivist"))
            {
                ShowExam();
                return;
            }

            Recap recap = story.Recap(story.ActiveRealmId);
            if (recap != null && recap.Steps.Count > 0 && GUILayout.Button("Read the Mastery Recap", _btn))
            {
                ShowRecap();
                return;
            }
            if (GUILayout.Button("Back to the map", _btn)) { ShowCampaign(); return; }
            ScrollEnd();
        }

        // ==================================================================
        // Exam
        // ==================================================================
        private void DrawExam()
        {
            ExamPaper paper = _paper;
            if (paper == null) { ShowMountainGate(); return; }

            if (_examIndex >= paper.Questions.Count)
            {
                SubmitExam();
                return;
            }

            BankQuestion question = paper.Questions[_examIndex];
            ScrollStart();
            GUILayout.Label("SILVER MOUNTAIN \u2014 THE EXAM", _big);
            GUILayout.Space(2);
            GUILayout.HorizontalScrollbar(_examIndex, 0.04f, 0, paper.Questions.Count, GUILayout.Height(12));

            // A slot the bank could not fill has no question, so Questions can run
            // shorter than Slots; never pair a station with the wrong slot's label.
            string station = "Station " + (_examIndex + 1) + " of " + paper.Questions.Count;
            if (_examIndex < paper.Slots.Count)
            {
                station += "  \u00b7  " + paper.Slots[_examIndex].ConceptName
                    + "  \u00b7  " + paper.Slots[_examIndex].Reason;
            }
            GUILayout.Label(station, _dim);
            GUILayout.Space(4);
            GUILayout.Label(question.question, _box);
            GUILayout.Space(6);

            for (int i = 0; i < question.options.Count; i++)
            {
                string option = question.options[i];
                if (Button((char)('A' + i) + ".  " + option, 30))
                {
                    _examAnswers.Add(new ExamAnswerInput
                    {
                        QuestionId = question.id,
                        Chosen = option,
                        ResponseTimeMs = (Time.unscaledTime - _examShownAt) * 1000f,
                        HintsUsed = _examHints
                    });
                    _examHints = 0;
                    _examShownAt = Time.unscaledTime;
                    _examIndex++;
                    SoundManager.PlaySfx("menu_confirm");
                    return;
                }
            }

            if (_statusLine.Length > 0) GUILayout.Label(_statusLine, _dim);

            if (GUILayout.Button("Skip \u2014 leave this one blank", _dim))
            {
                _examAnswers.Add(new ExamAnswerInput
                {
                    QuestionId = question.id,
                    Chosen = "",
                    ResponseTimeMs = (Time.unscaledTime - _examShownAt) * 1000f,
                    HintsUsed = 0
                });
                _examShownAt = Time.unscaledTime;
                _examIndex++;
                return;
            }
            ScrollEnd();
        }

        private void SubmitExam()
        {
            StoryModeManager story = Story;
            List<AnswerInput> inputs = new List<AnswerInput>();
            for (int i = 0; i < _examAnswers.Count; i++)
            {
                ExamAnswerInput a = _examAnswers[i];
                inputs.Add(new AnswerInput
                {
                    QuestionId = a.QuestionId,
                    Chosen = a.Chosen,
                    ResponseTimeMs = a.ResponseTimeMs,
                    HintsUsed = a.HintsUsed
                });
            }

            _examResult = story.SubmitSilver(story.ActiveRealmId, inputs);
            _paper = null;
            _examAnswers = null;

            if (_examResult == null || !_examResult.Graded)
            {
                _statusLine = _examResult != null ? _examResult.Reason : "The climb could not be graded.";
                ShowMountainGate();
                return;
            }
            if (Game != null && story.Save != null) Game.playerData.playerName = story.Save.playerName;
            SoundManager.PlaySfx(_examResult.Verdict.Passed ? "victory" : "defeat");
            ShowRecap();
        }

        // ==================================================================
        // Mastery Recap
        // ==================================================================
        private void DrawRecap()
        {
            StoryModeManager story = Story;
            ExamResult result = _examResult;
            Recap recap = result != null && result.Verdict != null ? WrapVerdict(result) : story.Recap(story.ActiveRealmId);

            ScrollStart();
            if (result != null && result.Verdict != null)
            {
                GUILayout.Label(result.Verdict.Passed ? "THE MOUNTAIN IS CLEARED" : "THE MOUNTAIN STANDS", _big);
            }
            else
            {
                GUILayout.Label("MASTERY RECAP", _big);
            }
            GUILayout.Label("at the save point, where failed climbs end", _dim);
            GUILayout.Space(6);

            if (result != null && result.Verdict != null)
            {
                GUILayout.Label(
                    "You answered " + result.Correct + " / " + result.Total
                    + " (" + Percent(result.Ratio) + "). Needed " + Percent(SilverMountainController.ExamPassRatio) + ".",
                    _body);
                GUILayout.Space(4);
                for (int i = 0; i < result.Verdict.ArchivistLines.Count; i++)
                {
                    GUILayout.Label("\u201c" + result.Verdict.ArchivistLines[i] + "\u201d", _box);
                    GUILayout.Space(2);
                }
                GUILayout.Space(4);
                if (result.Verdict.ReturnToSave)
                {
                    GUILayout.Label(
                        "You are returned to " + Where(story.Save) + ". The mountain closes for "
                        + result.Verdict.CooldownHours.ToString("0") + " hours. The recap below is what it left you.",
                        _body);
                }
                else if (!result.Verdict.Passed)
                {
                    GUILayout.Label(
                        "Attempts remaining in this window: " + result.Verdict.AttemptsRemaining + ".", _body);
                }
                GUILayout.Space(6);
            }

            GUILayout.Label("What to do next, in order", _head);
            for (int i = 0; i < recap.Steps.Count; i++)
            {
                RecapStepData step = recap.Steps[i];
                GUILayout.Label(
                    step.order + ". " + step.title + "  (" + Percent(step.mastery / 100f) + ")\n" + step.body,
                    _box);
                GUILayout.Space(3);
            }

            if (result != null && result.Verdict != null && result.Verdict.Passed)
            {
                GUILayout.Space(6);
                GUILayout.Label(
                    "The realm is yours. " + story.Save.playerName
                    + ", Champion \u2014 the other realms of Kaiserland still need an explorer.",
                    _body);
            }

            GUILayout.Space(10);
            if (result != null && result.Verdict != null && result.Verdict.Passed)
            {
                if (Button("Return to the world"))
                {
                    _examResult = null;
                    ShowCampaign();
                    return;
                }
            }
            else if (Button("Back to the gate"))
            {
                _examResult = null;
                ShowMountainGate();
                return;
            }
            ScrollEnd();
        }

        private static Recap WrapVerdict(ExamResult result)
        {
            Recap recap = new Recap();
            recap.Realm = "";
            recap.Steps = result.Verdict.Recap;
            recap.CooldownUntil = result.Verdict.CooldownUntil;
            recap.AttemptsRemaining = result.Verdict.AttemptsRemaining;
            return recap;
        }

        // ==================================================================
        // Dialogue
        // ==================================================================
        private void DrawDialogue()
        {
            if (_dialogueLines == null || _dialogueLines.Count == 0) { Close(); return; }
            _dialogueIndex = Mathf.Clamp(_dialogueIndex, 0, _dialogueLines.Count - 1);

            ScrollStart();
            GUILayout.FlexibleSpace();
            GUILayout.Label(_dialogueSpeaker, _head);
            GUILayout.Space(4);
            GUILayout.Label(_dialogueLines[_dialogueIndex], _box);
            GUILayout.Space(6);
            GUILayout.Label((_dialogueIndex + 1) + " / " + _dialogueLines.Count, _dim);
            GUILayout.Space(6);
            if (Button(_dialogueIndex < _dialogueLines.Count - 1 ? "Continue  \u25b8" : "Close"))
            {
                AdvanceDialogue();
            }
            GUILayout.FlexibleSpace();
            ScrollEnd();
        }

        private void AdvanceDialogue()
        {
            if (_dialogueLines == null || _dialogueIndex >= _dialogueLines.Count - 1)
            {
                Close();
                return;
            }
            _dialogueIndex++;
            SoundManager.PlaySfx("dialog_beep");
        }

        // ==================================================================
        // The world's first knowledge encounter
        // ==================================================================
        private void DrawEncounter()
        {
            KnowledgeEncounter encounter = _encounter;
            if (encounter == null || encounter.Question == null) { Close(); return; }

            ScrollStart();

            if (encounter.Solved)
            {
                GUILayout.FlexibleSpace();
                GUILayout.Label("THE EASTERN GATE", _head);
                GUILayout.Label("the mechanism turns", _dim);
                GUILayout.Space(8);
                GUILayout.Label(encounter.Feedback, _box);
                GUILayout.Space(6);
                GUILayout.Label(
                    "It asked about " + encounter.ConceptName + ", and you were able to tell it "
                    + "something true. That is the whole of what this world asks of you.", _body);
                GUILayout.Space(12);
                if (Button("Step through  \u25b8"))
                {
                    _encounter = null;
                    _encounterGate = null;
                    Close();
                }
                GUILayout.FlexibleSpace();
                ScrollEnd();
                return;
            }

            GUILayout.Label("THE EASTERN GATE", _head);
            GUILayout.Label(
                "A keeper\u2019s mechanism, set into the road. It has one question and asks it "
                + "without hurry: answer it, and the road opens.", _dim);
            GUILayout.Space(6);
            GUILayout.Label("It is asking about " + encounter.ConceptName + ".", _body);

            if (encounter.Feedback.Length > 0)
            {
                GUILayout.Space(4);
                GUILayout.Label(encounter.Feedback, _box);
            }

            GUILayout.Space(6);
            GUILayout.Label(encounter.Question.question, _box);
            GUILayout.Space(6);

            List<string> options = encounter.Question.options;
            for (int i = 0; i < options.Count; i++)
            {
                string option = options[i];
                if (Button((char)('A' + i) + ".  " + option, 30))
                {
                    AnswerEncounter(option);
                    return;
                }
            }

            GUILayout.Space(8);
            if (GUILayout.Button("Step back from the mechanism", _dim))
            {
                _encounter = null;
                _encounterGate = null;
                Close();
                return;
            }
            ScrollEnd();
        }

        private void AnswerEncounter(string chosen)
        {
            KnowledgeEncounter encounter = _encounter;
            if (encounter == null) return;

            float elapsed = (Time.unscaledTime - _encounterShownAt) * 1000f;
            GradedAnswer graded = encounter.Answer(chosen, elapsed, 0);
            _encounterShownAt = Time.unscaledTime;

            if (graded == null) return;
            SoundManager.PlaySfx(graded.Correct ? "correct" : "wrong");

            // The gate opens the moment the mechanism is satisfied. Everything the
            // world needs to know is a flag in the save, so this cannot be lost by a
            // player who closes the game on the next screen.
            if (graded.Correct && _encounterGate != null) _encounterGate.Open();
        }

        // ==================================================================
        // Victory — the sigil
        // ==================================================================
        private void DrawVictory()
        {
            TrialSettlement settled = _victory;
            if (settled == null || settled.Milestone == null) { Close(); return; }

            Milestone milestone = settled.Milestone;

            ScrollStart();
            GUILayout.Label("SIGIL EARNED", _big);
            GUILayout.Label(milestone.Place + "  \u00b7  " + milestone.DomainName, _dim);
            GUILayout.Space(4);

            DrawBadge(milestone);
            GUILayout.Label(milestone.BadgeName, _head);
            GUILayout.Space(6);

            GUILayout.Label(milestone.Success, _box);
            GUILayout.Space(6);

            if (settled.Outcome != null)
            {
                GUILayout.Label(
                    "Trial " + milestone.Index + " \u2014 " + milestone.Name + ": you met "
                    + Percent(settled.Outcome.ScorePercent / 100f) + " of what the trial asked for, "
                    + "and it asked for " + Percent(settled.Outcome.RequiredPercent / 100f) + ".",
                    _body);
            }

            if (settled.MovedSavePoint)
            {
                GUILayout.Space(4);
                GUILayout.Label(
                    "Your journey is now written down at " + milestone.Place + ". If the road ever "
                    + "sends you back, that is where you will wake \u2014 not at the beginning.", _body);
            }

            GUILayout.Space(6);
            Milestone next = NextMilestone(settled);
            if (next != null)
            {
                GUILayout.Label("The road opens.", _head);
                GUILayout.Label(
                    "Milestone " + next.Index + " \u2014 " + next.Name + ". " + next.Keeper
                    + " is waiting at " + next.Place + ".", _body);
            }
            else
            {
                GUILayout.Label(
                    "Every chapter of this realm is yours. Silver Mountain is the last road, and "
                    + "the Archivist has heard about you.", _body);
            }

            GUILayout.Space(12);
            if (Button("Back to the world"))
            {
                _victory = null;
                _badgeTexture = null;
                Close();
                return;
            }
            if (GUILayout.Button("Campaign map", _btn))
            {
                _victory = null;
                _badgeTexture = null;
                ShowCampaign();
                return;
            }
            ScrollEnd();
        }

        private Milestone NextMilestone(TrialSettlement settled)
        {
            StoryModeManager story = Story;
            if (story == null || settled == null || settled.Milestone == null) return null;

            List<Milestone> milestones = story.Campaign(settled.Realm);
            for (int i = 0; i < milestones.Count; i++)
            {
                if (milestones[i].Index == settled.Milestone.Index + 1) return milestones[i];
            }
            return null;
        }

        /// <summary>
        /// Draw the sigil, generated in the chapter's own colour.
        ///
        /// Built once per victory and cached, because a texture allocated inside
        /// OnGUI would be allocated on every repaint.
        /// </summary>
        private void DrawBadge(Milestone milestone)
        {
            if (_badgeTexture == null)
            {
                PixelSpriteGenerator sprites = PixelSpriteGenerator.Instance;
                if (sprites != null)
                {
                    Sprite badge = sprites.GenerateBadgeSprite(
                        OverworldDecor.AccentFor(milestone.Realm, milestone.Index));
                    if (badge != null) _badgeTexture = badge.texture;
                }
            }
            if (_badgeTexture == null) return;

            GUILayout.BeginHorizontal();
            GUILayout.FlexibleSpace();
            Rect rect = GUILayoutUtility.GetRect(
                GUIContent.none, GUIStyle.none, GUILayout.Width(96f), GUILayout.Height(96f));
            GUI.DrawTexture(rect, _badgeTexture, ScaleMode.ScaleToFit, true);
            GUILayout.FlexibleSpace();
            GUILayout.EndHorizontal();
        }

        // ------------------------------------------------------------------
        // Scroll helpers
        // ------------------------------------------------------------------
        private void ScrollStart()
        {
            GUILayout.BeginVertical();
        }

        private void ScrollEnd()
        {
            GUILayout.EndVertical();
        }
    }
}
