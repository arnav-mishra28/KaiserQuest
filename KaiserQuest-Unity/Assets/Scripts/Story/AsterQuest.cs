using System;
using System.Collections.Generic;
using KaiserQuest.Knowledge;
using UnityEngine;

namespace KaiserQuest.Story
{
    /// <summary>
    /// Aster Town's first quest: the eastern gate has stopped responding.
    ///
    /// This is the game stating its own thesis, physically. The player does not meet
    /// a quiz; they meet a mechanism that will not move, and the thing that moves it
    /// is a question drawn from the verified bank *through the Knowledge Engine*.
    /// The answer is deliberately never written down in this file: the story layer
    /// asks the engine what to ask and what an answer meant, and knows nothing else.
    ///
    /// The encounter is deliberately not a trial. Trials are the campaign's formal
    /// examinations, and the first of those is milestone 1. This is the thing that
    /// teaches the player what the game is before it starts examining them by it.
    /// </summary>
    public static class AsterQuest
    {
        public const string TownName = "Aster Town";
        public const string GateId = "aster.east_gate";

        /// <summary>The gate's mechanism has been solved; the road east is open.</summary>
        public const string GateOpenFlag = "aster.east_gate.open";

        /// <summary>The player has been told what is wrong with the gate.</summary>
        public const string GateToldFlag = "aster.gate.told";

        // ------------------------------------------------------------------
        // Story flags
        //
        // They live inside the existing save, because a second place to remember
        // things is a second place to disagree with the first.
        // ------------------------------------------------------------------
        public static bool Has(SaveGameData save, string flag)
        {
            if (save == null || string.IsNullOrEmpty(flag) || save.storyFlags == null) return false;
            return save.storyFlags.Contains(flag);
        }

        public static void Set(SaveGameData save, string flag)
        {
            if (save == null || string.IsNullOrEmpty(flag)) return;
            if (save.storyFlags == null) save.storyFlags = new List<string>();
            if (!save.storyFlags.Contains(flag)) save.storyFlags.Add(flag);
        }

        // ------------------------------------------------------------------
        // What the gate asks
        // ------------------------------------------------------------------
        /// <summary>
        /// The concept the opening gate interrogates.
        ///
        /// The first concept of the first milestone that the verified bank can
        /// actually examine. Resolved from content rather than named here, so a realm
        /// whose bank changes shape cannot leave the player at a gate with nothing to
        /// ask — which would be a soft-lock in the first thirty seconds of the game.
        /// </summary>
        public static string OpeningConcept(KnowledgeEngine engine, Milestone milestone)
        {
            if (engine == null || milestone == null || milestone.Concepts == null) return null;
            for (int i = 0; i < milestone.Concepts.Count; i++)
            {
                if (engine.QuestionCount(milestone.Concepts[i]) > 0) return milestone.Concepts[i];
            }
            return null;
        }

        public static string ConceptName(KnowledgeEngine engine, string conceptId)
        {
            if (engine == null || engine.Graph == null) return conceptId;
            ConceptData concept = engine.Graph.Concept(conceptId);
            return concept != null ? concept.name : conceptId;
        }

        // ------------------------------------------------------------------
        // Player-facing language
        //
        // The engine's numbers are for the engine. What reaches the screen is a
        // sentence about the idea, never a probability or a mastery figure.
        // ------------------------------------------------------------------
        public static string Voice(ConceptKnowledge knowledge)
        {
            if (knowledge == null || knowledge.Attempts == 0)
                return "You have not met this idea before. The gate does not mind \u2014 it only asks.";

            if (knowledge.IsRusty)
                return "That idea seems rusty. It held once, and it needs a minute of use.";

            if (knowledge.IsMastered)
                return "You have this one, and it is holding.";

            if (knowledge.Confidence() == "Moderate")
                return "You\u2019re getting the hang of this.";

            return "You haven\u2019t mastered this yet \u2014 which is exactly what the gate is for.";
        }

        /// <summary>The line the keeper-shaped voice says when the mechanism finally turns.</summary>
        public static string Solved(string conceptName)
        {
            return "The mechanism turns. Somewhere behind the stone, a counterweight you cannot see "
                 + "accepts \u201c" + conceptName + "\u201d as true, and the gate is no longer a wall.";
        }
    }

    /// <summary>
    /// One knowledge encounter: a mechanism, one question at a time.
    ///
    /// Deliberately not a MonoBehaviour and with no reference to any UI, for the same
    /// reason TrialRunner is not: the encounter must be testable, and the OpenEvent
    /// must be able to run it without a screen attached. It owns no answer key — it
    /// asks the Knowledge Engine for an item and hands the player's answer straight
    /// back, so a wrong answer teaches and updates the trace exactly as a trial does.
    /// </summary>
    public class KnowledgeEncounter
    {
        public const string TrialId = "aster";

        private readonly List<string> _seen = new List<string>();

        private KnowledgeEngine _engine;
        private string _concept;
        private string _realm;
        private BankQuestion _question;
        private bool _begun;

        /// <summary>The item currently in front of the player.</summary>
        public BankQuestion Question { get { return _question; } }

        public string Concept { get { return _concept; } }

        public string ConceptName { get { return AsterQuest.ConceptName(_engine, _concept); } }

        public bool Begun { get { return _begun; } }

        public bool Solved { get; private set; }

        public int Attempts { get; private set; }

        /// <summary>The last verdict, carrying the teaching the screen shows.</summary>
        public GradedAnswer Last { get; private set; }

        /// <summary>What to say to the player right now, in their language.</summary>
        public string Feedback { get; private set; }

        /// <summary>
        /// Put a question in front of the player.
        ///
        /// Returns false when the bank has nothing to ask, which is a content gap and
        /// not a player failure — the caller must say so rather than show an empty
        /// mechanism. A gate that cannot ask is a gate that cannot open, so this is
        /// checked by the caller before the encounter is opened at all.
        /// </summary>
        public bool Begin(KnowledgeEngine engine, string conceptId, string realmId, ICollection<string> recentIds = null)
        {
            _engine = engine;
            _concept = conceptId;
            _realm = realmId;
            Solved = false;
            Attempts = 0;
            Last = null;
            Feedback = string.Empty;
            _seen.Clear();

            _begun = Draw(recentIds);
            return _begun;
        }

        /// <summary>
        /// Grade one answer.
        ///
        /// A correct answer solves the mechanism. A wrong one does not, but it is
        /// still a real attempt: it goes through the same engine call as a trial
        /// answer, so the trace learns from it and the next question is chosen with
        /// that knowledge. The player is then shown the explanation the bank ships
        /// with the item, and the misconception their distractor names, if it names
        /// one.
        /// </summary>
        public GradedAnswer Answer(string chosen, float responseTimeMs, int hintsUsed = 0)
        {
            if (!_begun || _question == null || Solved) return null;

            GradedAnswer graded = _engine.Grade(
                _question.id, chosen, responseTimeMs, hintsUsed, 1, TrialId);
            if (graded == null)
            {
                Feedback = "The mechanism did not register that. Try it once more.";
                return null;
            }

            Last = graded;
            Attempts++;
            _seen.Add(_question.id);

            if (graded.Correct)
            {
                Solved = true;
                Feedback = AsterQuest.Solved(graded.ConceptName);
                return graded;
            }

            Feedback = Teach(graded);
            // A fresh item on the next attempt, so a retry is a second attempt at the
            // idea rather than a memory test of what was just said.
            Draw(null);
            return graded;
        }

        private string Teach(GradedAnswer graded)
        {
            string line = "Not yet. " + graded.Explanation;

            Detection detection = null;
            for (int i = 0; i < graded.Detections.Count; i++)
            {
                if (!string.IsNullOrEmpty(graded.Detections[i].MisconceptionId)) { detection = graded.Detections[i]; break; }
            }

            if (detection != null && _engine != null && _engine.Detector != null)
            {
                MisconceptionData named = _engine.Detector.Get(detection.MisconceptionId);
                if (named != null && !string.IsNullOrEmpty(named.remedy))
                {
                    line += "\n\n" + named.remedy;
                }
            }

            ConceptKnowledge knowledge = _engine.Tracer.Get(graded.Concept);
            line += "\n\n" + AsterQuest.Voice(knowledge);
            return line;
        }

        private bool Draw(ICollection<string> recentIds)
        {
            if (_engine == null || string.IsNullOrEmpty(_concept)) return false;

            List<string> pool = new List<string>();
            pool.Add(_concept);

            List<string> exclude = new List<string>();
            for (int i = 0; i < _seen.Count; i++) exclude.Add(_seen[i]);
            if (recentIds != null) foreach (string id in recentIds) exclude.Add(id);

            List<string> preference = _engine.ActiveMisconceptionIds(_realm);

            QuestionSelection selection = _engine.Select(pool, 1, exclude, preference, null);
            if (selection == null || selection.Questions.Count == 0)
            {
                // The bank may be too small for the exclusion list — the concepts the
                // first milestone teaches are the thinnest in the game. Repeating an
                // item is a far better outcome than a mechanism that has stopped
                // answering questions.
                selection = _engine.Select(pool, 1, null, preference, null);
            }
            if (selection == null || selection.Questions.Count == 0) return false;

            _question = selection.Questions[0];
            return true;
        }
    }

    /// <summary>
    /// The keeper-shaped voice of Aster Town's first quest: an NPC who is worried
    /// about something and says so plainly, because a quest the player does not
    /// understand is a fetch quest with extra steps.
    /// </summary>
    public class QuestGiver : MonoBehaviour, IInteractable
    {
        public string speakerName = "Maren";
        public int milestoneIndex = 1;
        public string realmId;

        public void Interact(PlayerController player)
        {
            StoryModeManager story = StoryModeManager.Instance;
            StoryUI ui = StoryUI.Instance;
            if (story == null || !story.Ready || ui == null) return;

            story.SetStoryFlag(AsterQuest.GateToldFlag);
            story.SaveNow();

            List<string> lines = new List<string>();
            lines.Add("You picked a fine day to walk in. The eastern gate has stopped responding.");
            lines.Add("It is a mechanism, not a lock. It was built by the Archivists to open for "
                      + "someone who could show it a thing was true \u2014 and this morning it will "
                      + "not show anyone anything.");
            lines.Add("The road past it is the only way to " + NextPlace(story) + ", so nothing "
                      + "leaves Aster Town until it moves.");
            lines.Add("Go and look at it. Read what it asks. It is a fair question, and it does not "
                      + "care how long you take.");

            ui.ShowDialogue(speakerName, lines);
        }

        private string NextPlace(StoryModeManager story)
        {
            string realm = !string.IsNullOrEmpty(realmId) ? realmId : story.ActiveRealmId;
            List<Milestone> milestones = story.Campaign(realm);
            if (milestones.Count > 1) return milestones[1].Place;
            if (milestones.Count > 0) return milestones[0].Place;
            return "the road";
        }
    }

    /// <summary>
    /// A town signpost. Scenery with something to say, so a settlement reads as a
    /// place somebody wrote directions in rather than a field with props on it.
    /// </summary>
    public class TownSign : MonoBehaviour, IInteractable
    {
        [TextArea]
        public string text = "";

        public void Interact(PlayerController player)
        {
            StoryUI ui = StoryUI.Instance;
            if (ui == null) return;
            ui.ShowDialogue("Signpost", new List<string> { text });
        }
    }

    /// <summary>
    /// The eastern gate, and the first piece of the world learning buys.
    ///
    /// The gate holds no question of its own. When the player faces it, the gate asks
    /// the Knowledge Engine for an item on the concept its milestone opens with; when
    /// the player answers, the gate asks the engine what that answer meant. Its open
    /// state is a flag in the save, so a gate that was opened is still open after the
    /// player quits and comes back — which is the whole difference between a world
    /// that changes and a cutscene.
    /// </summary>
    public class KnowledgeGate : MonoBehaviour, IInteractable
    {
        public string gateId = AsterQuest.GateId;
        public int milestoneIndex = 1;
        public string realmId;

        private SpriteRenderer _renderer;
        private BoxCollider2D _collider;
        private float _pulse;

        public bool IsOpen { get; private set; }

        private void Awake()
        {
            _renderer = GetComponent<SpriteRenderer>();
            _collider = GetComponent<BoxCollider2D>();
        }

        /// <summary>
        /// Reflect the save's flag. Called when the world is populated, so a returning
        /// player finds the gate as they left it.
        ///
        /// A seized gate is solid — a gate that never stopped anything is a door frame
        /// — and opening it is therefore something the player can see from across the
        /// plaza: the wall in the road is gone.
        /// </summary>
        public void ApplySavedState(bool open)
        {
            IsOpen = open;
            if (_collider != null) _collider.enabled = !open;
            if (_renderer != null)
            {
                _renderer.color = open
                    ? new Color(0.8f, 0.95f, 0.85f, 1f)
                    : new Color(0.75f, 0.72f, 0.66f, 1f);
            }
        }

        public void Interact(PlayerController player)
        {
            StoryModeManager story = StoryModeManager.Instance;
            StoryUI ui = StoryUI.Instance;
            if (story == null || !story.Ready || ui == null) return;

            // The save decides, not this component's cached state — the same rule
            // Reconcile applies, read at the moment the player touches the gate.
            if (AsterQuest.Has(story.Save, AsterQuest.GateOpenFlag))
            {
                ApplySavedState(true);
                ui.ShowDialogue("The eastern gate",
                    new List<string>
                    {
                        "The mechanism sits quiet and open. Whatever it was waiting to be told, "
                        + "it has been told, and the road east is clear."
                    });
                return;
            }

            ui.ShowEncounter(this);
        }

        /// <summary>
        /// Open the gate, and remember it.
        ///
        /// One place decides what solving the mechanism means, so the save flag, the
        /// visual and the write to disk can never disagree with each other.
        /// </summary>
        public bool Open()
        {
            StoryModeManager story = StoryModeManager.Instance;
            if (story == null || !story.Ready) return false;

            AsterQuest.Set(story.Save, AsterQuest.GateOpenFlag);
            ApplySavedState(true);
            story.SaveNow();

            SoundManager.PlaySfx("menu_confirm");
            Debug.Log("[AsterGate] The eastern gate opens.");
            return true;
        }

        /// <summary>
        /// The milestone whose concept this gate interrogates. Resolved at interact
        /// time from the campaign actually being played, never cached at spawn time:
        /// a player can start a new character in another realm without the game
        /// restarting, and the gate they then walk up to must ask about the realm
        /// they are now in.
        /// </summary>
        public Milestone MilestoneFor(StoryModeManager story)
        {
            string realm = !string.IsNullOrEmpty(realmId) ? realmId : story.ActiveRealmId;
            List<Milestone> milestones = story.Campaign(realm);
            for (int i = 0; i < milestones.Count; i++)
            {
                if (milestones[i].Index == milestoneIndex) return milestones[i];
            }
            return milestones.Count > 0 ? milestones[0] : null;
        }

        private void Update()
        {
            Reconcile();

            // A seized mechanism breathes, so the player can tell it is waiting for
            // them rather than merely being part of the wall.
            if (_renderer == null || IsOpen) return;
            _pulse += Time.deltaTime * 1.6f;
            float glow = 0.72f + 0.12f * Mathf.Sin(_pulse);
            _renderer.color = new Color(glow + 0.08f, glow, glow - 0.06f, 1f);
        }

        /// <summary>
        /// Keep the gate's state equal to the save's.
        ///
        /// The gate is built once, but the save underneath it can be replaced: a
        /// player who opens this road and then starts a new character begins with no
        /// history at all. A gate still holding the previous character's state would
        /// stand open \u2014 and, worse, *walkable* \u2014 for someone who was never asked
        /// anything, which would let the first quest in the game be skipped by
        /// strolling east. So the flag is the authority and this component merely
        /// agrees with it. The check is a lookup among a handful of flags with no
        /// allocation, and it does nothing at all while nothing has changed.
        /// </summary>
        private void Reconcile()
        {
            if (_renderer == null && _collider == null) return;

            StoryModeManager story = StoryModeManager.Instance;
            if (story == null || !story.Ready || story.Save == null) return;

            bool open = AsterQuest.Has(story.Save, AsterQuest.GateOpenFlag);
            if (open != IsOpen) ApplySavedState(open);
        }
    }
}
