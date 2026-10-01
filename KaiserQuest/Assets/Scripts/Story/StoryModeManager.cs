using System;
using System.Collections.Generic;
using KaiserQuest.Knowledge;
using UnityEngine;

namespace KaiserQuest.Story
{
    /// <summary>One answer as submitted by the UI.</summary>
    public class AnswerInput
    {
        public string QuestionId;
        public string Chosen;
        public float ResponseTimeMs;
        public int HintsUsed;
    }

    /// <summary>The verdict on a trial, plus everything the next screen needs.</summary>
    public class TrialSettlement
    {
        public MilestoneOutcome Outcome;
        public Milestone Milestone;
        public string Realm;
        public float RealmMastery;
        public SavePointData SavePoint;
        public bool MovedSavePoint;

        public bool Passed { get { return Outcome != null && Outcome.Passed; } }
    }

    /// <summary>One concept as the trial-start screen shows it.</summary>
    public class ConceptBrief
    {
        public string Id;
        public string Name;
        public float Mastery;
    }

    /// <summary>Everything the campaign map needs for one realm.</summary>
    public class CampaignDetail
    {
        public string Realm;
        public string RealmName;
        public string Region;
        public string Sigil;
        public string Accent;
        public Milestone Current;
        public EntryCheck Entry;
        public List<ConceptBrief> CurrentConcepts = new List<ConceptBrief>();
        public List<MilestoneState> Milestones = new List<MilestoneState>();
        public int PassedCount;
        public int Total;
        public List<string> Badges = new List<string>();
        public bool Completed;
        public float OverallMastery;
        public bool MountainOpen;
    }

    /// <summary>The result of one climb of Silver Mountain.</summary>
    public class ExamResult
    {
        public bool Graded;
        public string Reason;
        public int Correct;
        public int Total;
        public float Ratio;
        public ArchivistVerdict Verdict;
        public MountainStatus Status;
        public Recap Recap;
        public SavePointData SavePoint;
        public bool ReturnToSave;
        public List<GradedAnswer> Answers = new List<GradedAnswer>();
    }

    /// <summary>
    /// Story Mode.
    ///
    /// The one place that knows how a campaign is actually played: which milestone is
    /// open, whether the player may enter it, what a trial attempt means, whether the
    /// mountain will have them, and where they are sent when it will not.
    ///
    /// The Knowledge Engine decides everything about *learning* — selection,
    /// difficulty, the trace, the diagnosis. This class decides nothing about
    /// knowledge and everything about consequence, which is the division the whole
    /// architecture exists to keep.
    ///
    /// A client-side mirror of services/story_service.py.
    /// </summary>
    public class StoryModeManager : MonoBehaviour
    {
        public static StoryModeManager Instance { get; private set; }

        [Header("Save slot")]
        public string saveSlotId = "local";

        public SaveGameData Save { get; private set; }
        public ProgressionService Progression { get; private set; }
        public SilverMountainController Mountain { get; private set; }

        /// <summary>The trial currently in progress, if any.</summary>
        public TrialRunner ActiveTrial { get; private set; }

        /// <summary>The realm the active trial belongs to.</summary>
        public string ActiveRealm { get; private set; }

        /// <summary>
        /// The realm the player has chosen but not yet saved into. Setting this from
        /// the subject-select screen is what "entering a story mode" means.
        /// </summary>
        public string ActiveRealmDraft
        {
            get { return ActiveRealm; }
            set { ActiveRealm = value; }
        }

        public ExamPaper ActiveExam { get; private set; }

        private readonly Dictionary<string, List<Milestone>> _campaigns =
            new Dictionary<string, List<Milestone>>();

        public event Action<TrialSettlement> OnTrialSettled;
        public event Action<ExamResult> OnExamSettled;
        public event Action OnSaved;

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
            DontDestroyOnLoad(gameObject);
            Rebuild();
        }

        /// <summary>Re-bind to the Knowledge Engine. Safe to call after it reloads.</summary>
        public void Rebuild()
        {
            KnowledgeEngine engine = KnowledgeEngine.Instance;
            Progression = new ProgressionService(engine);
            Mountain = new SilverMountainController(engine);
            _campaigns.Clear();
        }

        private KnowledgeEngine Engine { get { return KnowledgeEngine.Instance; } }

        public bool Ready
        {
            get { return Engine != null && Engine.Graph != null && Save != null; }
        }

        // ------------------------------------------------------------------
        // Campaigns
        // ------------------------------------------------------------------
        /// <summary>The twenty milestones of a realm, built once and cached.</summary>
        public List<Milestone> Campaign(string realmId)
        {
            if (string.IsNullOrEmpty(realmId)) return new List<Milestone>();
            List<Milestone> cached;
            if (_campaigns.TryGetValue(realmId, out cached)) return cached;

            List<Milestone> built = Engine != null && Engine.Graph != null
                ? MilestoneCatalog.Build(Engine.Graph, realmId)
                : new List<Milestone>();
            _campaigns[realmId] = built;
            return built;
        }

        /// <summary>
        /// Which realm the player is playing. A save knows its own realm, so the game
        /// reopens where it was left rather than asking again.
        /// </summary>
        public string ActiveRealmId
        {
            get
            {
                if (!string.IsNullOrEmpty(ActiveRealm)) return ActiveRealm;
                if (Save != null && !string.IsNullOrEmpty(Save.realm)) return Save.realm;
                return "algebra";
            }
        }

        public RealmProgressData Progress(string realmId)
        {
            return Save != null ? Save.RealmProgress(realmId) : new RealmProgressData();
        }

        public SilverMountainData MountainState(string realmId)
        {
            return Save != null ? Save.Mountain(realmId) : new SilverMountainData();
        }

        public CampaignDetail CampaignDetail(string realmId = null)
        {
            string realm = string.IsNullOrEmpty(realmId) ? ActiveRealmId : realmId;
            List<Milestone> milestones = Campaign(realm);
            RealmProgressData progress = Progress(realm);

            CampaignDetail detail = new CampaignDetail();
            detail.Realm = realm;
            detail.Total = milestones.Count;
            detail.PassedCount = progress.PassedCount;
            detail.Badges = new List<string>(progress.badges);
            detail.Completed = progress.completed;
            detail.OverallMastery = Engine != null && Engine.Tracer != null ? Engine.Tracer.RealmMastery(realm) : 0f;

            RealmData realmData = Engine != null && Engine.Graph != null ? Engine.Graph.Realm(realm) : null;
            detail.RealmName = realmData != null ? realmData.name : realm;
            detail.Sigil = realmData != null ? realmData.sigil : string.Empty;
            detail.Accent = realmData != null ? realmData.accent : string.Empty;

            RealmFlavor flavor = MilestoneCatalog.FlavorFor(realm);
            detail.Region = flavor != null ? flavor.Region : string.Empty;

            detail.Current = Progression.FirstUnpassed(milestones, progress);
            if (detail.Current != null)
            {
                detail.Entry = Progression.EntryCheck(milestones, detail.Current, progress);
                for (int i = 0; i < detail.Current.Concepts.Count; i++)
                {
                    string conceptId = detail.Current.Concepts[i];
                    ConceptData concept = Engine.Graph.Concept(conceptId);
                    ConceptBrief brief = new ConceptBrief();
                    brief.Id = conceptId;
                    brief.Name = concept != null ? concept.name : conceptId;
                    brief.Mastery = Engine.Tracer.Get(conceptId).Mastery();
                    detail.CurrentConcepts.Add(brief);
                }
            }

            detail.Milestones = Progression.Status(milestones, progress);
            detail.MountainOpen = milestones.Count > 0 && progress.PassedCount >= milestones.Count;
            return detail;
        }

        // ------------------------------------------------------------------
        // Trials
        // ------------------------------------------------------------------
        /// <summary>
        /// Begin a trial.
        ///
        /// Returns null when the player may not enter, when there is nothing to ask, or
        /// when the story is not loaded. `entry` always carries the reason, so the
        /// keeper can say it rather than the UI showing a padlock.
        /// </summary>
        public TrialRunner StartTrial(string realmId, int index, out EntryCheck entry, out string error)
        {
            entry = null;
            error = string.Empty;
            if (!Ready) { error = "No story is loaded."; return null; }

            string realm = string.IsNullOrEmpty(realmId) ? ActiveRealmId : realmId;
            List<Milestone> milestones = Campaign(realm);
            RealmProgressData progress = Progress(realm);
            if (milestones.Count == 0) { error = "This realm has no campaign."; return null; }

            Milestone milestone = index > 0
                ? MilestoneAt(milestones, index)
                : Progression.FirstUnpassed(milestones, progress);
            if (milestone == null) { error = "That milestone does not exist."; return null; }

            entry = Progression.EntryCheck(milestones, milestone, progress);
            if (!entry.Allowed)
            {
                error = entry.Reasons.Count > 0 ? entry.Reasons[0] : "You may not enter yet.";
                return null;
            }

            TrialRunner runner = new TrialRunner();
            if (!runner.Begin(milestone, milestones, Engine, Save.recentQuestionIds))
            {
                error = "No verified questions are available for this milestone's concepts.";
                return null;
            }

            ActiveTrial = runner;
            ActiveRealm = realm;

            RememberQuestions(runner);
            return runner;
        }

        /// <summary>
        /// Judge a finished trial and apply its consequences.
        ///
        /// Two independent axes decide it: the score, and whether the player actually
        /// holds the concepts the trial examined. Reaching the right answers without
        /// the ideas underneath them is not mastery, and the gate says so.
        /// </summary>
        public TrialSettlement SettleTrial(TrialRunner runner)
        {
            if (!Ready || runner == null || runner.Milestone == null) return null;

            string realm = runner.Milestone.Realm;
            List<Milestone> milestones = Campaign(realm);
            RealmProgressData progress = Progress(realm);
            Milestone milestone = runner.Milestone;

            TrialResult result = runner.Result();
            progress.RecordAttempt(milestone.Index, result.ScorePercent);

            // Hold the player only to concepts that were actually examined, and only
            // where the bank has enough material for the gate to be reachable.
            List<string> examined = new List<string>();
            for (int i = 0; i < result.ConceptsAttempted.Count; i++)
            {
                if (milestone.Concepts.Contains(result.ConceptsAttempted[i]))
                    examined.Add(result.ConceptsAttempted[i]);
            }
            List<string> gated = Progression.Gradeable(examined);

            MilestoneOutcome outcome = Progression.Evaluate(milestones, milestone, result, progress, gated);

            TrialSettlement settlement = new TrialSettlement();
            settlement.Outcome = outcome;
            settlement.Milestone = milestone;
            settlement.Realm = realm;
            settlement.RealmMastery = Engine.Tracer.RealmMastery(realm);

            if (outcome.Passed)
            {
                settlement.SavePoint = new SavePointData();
                settlement.SavePoint.realm = realm;
                settlement.SavePoint.milestoneIndex = milestone.Index;
                settlement.SavePoint.place = milestone.Place;
                settlement.SavePoint.savedAt = Clock.Now;
                Save.savePoint = settlement.SavePoint;
                settlement.MovedSavePoint = true;
            }

            RecallQuestions(runner);
            ActiveTrial = null;
            SaveNow();

            if (OnTrialSettled != null) OnTrialSettled(settlement);
            return settlement;
        }

        // ------------------------------------------------------------------
        // Silver Mountain
        // ------------------------------------------------------------------
        public MountainStatus SilverStatus(string realmId = null)
        {
            string realm = string.IsNullOrEmpty(realmId) ? ActiveRealmId : realmId;
            if (!Ready)
            {
                MountainStatus empty = new MountainStatus();
                empty.Reason = "No story is loaded.";
                return empty;
            }
            return Mountain.Status(Campaign(realm), Progress(realm), MountainState(realm), Clock.Now);
        }

        /// <summary>Assemble the Archivist's exam, or explain why he will not.</summary>
        public ExamPaper ChallengeSilver(string realmId = null)
        {
            string realm = string.IsNullOrEmpty(realmId) ? ActiveRealmId : realmId;
            if (!Ready) return null;

            ExamPaper paper = Mountain.Challenge(
                Campaign(realm), Progress(realm), MountainState(realm), Save.recentQuestionIds, Clock.Now);

            ActiveExam = paper.Granted ? paper : null;
            ActiveRealm = realm;

            for (int i = 0; i < paper.Questions.Count; i++)
            {
                if (Save.recentQuestionIds.Contains(paper.Questions[i].id)) continue;
                Save.recentQuestionIds.Insert(0, paper.Questions[i].id);
            }
            while (Save.recentQuestionIds.Count > 200)
                Save.recentQuestionIds.RemoveAt(Save.recentQuestionIds.Count - 1);

            return paper;
        }

        /// <summary>
        /// Grade a climb and apply the rules of the summit: three attempts, then 24
        /// hours back at the last save point with a personalised recap.
        /// </summary>
        public ExamResult SubmitSilver(string realmId, List<AnswerInput> answers)
        {
            string realm = string.IsNullOrEmpty(realmId) ? ActiveRealmId : realmId;
            ExamResult result = new ExamResult();
            if (!Ready) { result.Reason = "No story is loaded."; return result; }

            List<Milestone> milestones = Campaign(realm);
            RealmProgressData progress = Progress(realm);
            SilverMountainData state = MountainState(realm);

            MountainStatus status = Mountain.Status(milestones, progress, state, Clock.Now);
            if (!status.CanChallenge && !status.Cleared)
            {
                result.Graded = false;
                result.Status = status;
                result.Reason = status.Reason;
                return result;
            }

            result.Answers = GradeAnswers(answers);
            result.Total = result.Answers.Count > 0 ? result.Answers.Count : 1;
            for (int i = 0; i < result.Answers.Count; i++) if (result.Answers[i].Correct) result.Correct++;
            result.Ratio = (float)result.Correct / result.Total;

            bool passed = result.Ratio >= SilverMountainController.ExamPassRatio;
            KnowledgeProfile profile = Engine.ProfileFor(realm);
            result.Verdict = Mountain.RecordAttempt(state, passed, result.Ratio, profile, Clock.Now);
            result.Graded = true;

            if (result.Verdict.Passed)
            {
                progress.completed = true;
                result.SavePoint = new SavePointData();
                result.SavePoint.realm = realm;
                result.SavePoint.milestoneIndex = milestones.Count;
                result.SavePoint.place = "Silver Mountain";
                result.SavePoint.savedAt = Clock.Now;
                Save.savePoint = result.SavePoint;
            }
            else if (result.Verdict.ReturnToSave)
            {
                // Sent back to the last save point, exactly as the vision describes.
                if (Save.savePoint == null)
                {
                    Save.savePoint = new SavePointData();
                    Save.savePoint.realm = realm;
                    Save.savePoint.milestoneIndex = 1;
                    Save.savePoint.savedAt = Clock.Now;
                }
                result.SavePoint = Save.savePoint;
            }
            result.ReturnToSave = result.Verdict.ReturnToSave;

            result.Status = Mountain.Status(milestones, progress, state, Clock.Now);
            result.Recap = Mountain.Recap(milestones, progress, state, Clock.Now);
            SaveNow();

            if (OnExamSettled != null) OnExamSettled(result);
            return result;
        }

        /// <summary>The recap at the save point: stored one if the summit left one.</summary>
        public Recap Recap(string realmId = null)
        {
            string realm = string.IsNullOrEmpty(realmId) ? ActiveRealmId : realmId;
            if (!Ready)
            {
                Recap empty = new Recap();
                empty.Realm = realm;
                return empty;
            }
            return Mountain.Recap(Campaign(realm), Progress(realm), MountainState(realm), Clock.Now);
        }

        // ------------------------------------------------------------------
        // Save points and persistence
        // ------------------------------------------------------------------
        /// <summary>Rest at a save point. A save point is a place, not a bookmark.</summary>
        public SavePointData SavePoint(string realmId, int index, string place)
        {
            string realm = string.IsNullOrEmpty(realmId) ? ActiveRealmId : realmId;
            List<Milestone> milestones = Campaign(realm);
            if (milestones.Count == 0) return null;

            int clamped = Math.Max(1, Math.Min(milestones.Count, index));
            Milestone milestone = MilestoneAt(milestones, clamped);

            SavePointData point = new SavePointData();
            point.realm = realm;
            point.milestoneIndex = clamped;
            point.place = string.IsNullOrEmpty(place) ? (milestone != null ? milestone.Place : string.Empty) : place;
            point.savedAt = Clock.Now;
            Save.savePoint = point;

            SaveNow();
            return point;
        }

        /// <summary>
        /// Write everything out.
        ///
        /// The knowledge trace travels with the save: the 24-hour Silver Mountain
        /// cooldown only means anything if the record of what the player knows is still
        /// there when they come back.
        /// </summary>
        public bool SaveNow()
        {
            if (Save == null) return false;

            if (Engine != null && Engine.Tracer != null && Engine.Log != null)
            {
                Save.knowledge = Engine.Tracer.ToData();
                Save.attempts = Engine.Log.ToData();
            }

            bool written = SaveSystem.Save(Save);
            if (written && OnSaved != null) OnSaved();
            return written;
        }

        // ------------------------------------------------------------------
        // Starting and loading
        // ------------------------------------------------------------------
        public SaveGameData NewGame(string playerName, string appearanceId, string realmId)
        {
            Save = CharacterCreation.Create(playerName, appearanceId, realmId, saveSlotId);
            ActiveRealm = Save.realm;
            ActiveTrial = null;
            ActiveExam = null;
            RestoreKnowledge();
            return Save;
        }

        public SaveGameData LoadGame(string slotId)
        {
            string slot = string.IsNullOrEmpty(slotId) ? saveSlotId : slotId;
            SaveGameData loaded = SaveSystem.Load(slot);
            if (loaded == null) return null;

            Save = loaded;
            saveSlotId = loaded.playerId;
            ActiveRealm = loaded.realm;
            ActiveTrial = null;
            ActiveExam = null;
            RestoreKnowledge();
            return Save;
        }

        /// <summary>Is there a save in this slot?</summary>
        public bool HasSave(string slotId)
        {
            return SaveSystem.Exists(string.IsNullOrEmpty(slotId) ? saveSlotId : slotId);
        }

        public List<SaveSummary> Saves()
        {
            return SaveSystem.List();
        }

        public void RestoreKnowledge()
        {
            if (Save == null || Engine == null) return;
            Engine.RestoreKnowledge(Save.knowledge, Save.attempts);
        }

        // ------------------------------------------------------------------
        // Coverage (the honest report of what the content can and cannot test)
        // ------------------------------------------------------------------
        public class ConceptCoverage
        {
            public string Concept;
            public string Name;
            public int Questions;
        }

        /// <summary>
        /// Questions available per concept, and the concepts that fall short.
        ///
        /// Surfaced in the game deliberately: a concept with too few questions cannot
        /// be gated on, and the player is entitled to know that a gap is the content's
        /// fault rather than theirs.
        /// </summary>
        public List<ConceptCoverage> CoverageGaps(int target = 6)
        {
            List<ConceptCoverage> gaps = new List<ConceptCoverage>();
            if (!Ready) return gaps;

            List<string> concepts = Engine.Graph.AllConceptIds();
            for (int i = 0; i < concepts.Count; i++)
            {
                int count = Engine.QuestionCount(concepts[i]);
                if (count >= target) continue;
                ConceptData concept = Engine.Graph.Concept(concepts[i]);
                ConceptCoverage entry = new ConceptCoverage();
                entry.Concept = concepts[i];
                entry.Name = concept != null ? concept.name : concepts[i];
                entry.Questions = count;
                gaps.Add(entry);
            }

            gaps.Sort(delegate (ConceptCoverage a, ConceptCoverage b)
            {
                return a.Questions.CompareTo(b.Questions);
            });
            return gaps;
        }

        // ------------------------------------------------------------------
        // Helpers
        // ------------------------------------------------------------------
        private List<GradedAnswer> GradeAnswers(List<AnswerInput> answers)
        {
            List<GradedAnswer> graded = new List<GradedAnswer>();
            if (answers == null) return graded;

            for (int i = 0; i < answers.Count; i++)
            {
                AnswerInput input = answers[i];
                if (input == null || string.IsNullOrEmpty(input.QuestionId)) continue;
                GradedAnswer answer = Engine.Grade(
                    input.QuestionId, input.Chosen, input.ResponseTimeMs, input.HintsUsed, 1, "silver");
                if (answer != null) graded.Add(answer);
            }
            return graded;
        }

        /// <summary>
        /// Remember what was asked, so a retried trial is not the same paper twice.
        /// Only the head of the list is honoured, which is enough: a trial never
        /// needs to be kept away from items from twenty trials ago.
        /// </summary>
        private void RememberQuestions(TrialRunner runner)
        {
            if (Save == null || runner == null) return;
            IList<TrialStep> steps = runner.Steps;
            for (int i = steps.Count - 1; i >= 0; i--)
            {
                if (steps[i] != null && steps[i].Question != null) PushRecent(steps[i].Question.id);
            }
        }

        private void RecallQuestions(TrialRunner runner)
        {
            if (Save == null || runner == null) return;
            IList<GradedAnswer> graded = runner.Graded;
            for (int i = graded.Count - 1; i >= 0; i--)
            {
                if (graded[i] != null) PushRecent(graded[i].QuestionId);
            }
        }

        private void PushRecent(string questionId)
        {
            if (string.IsNullOrEmpty(questionId) || Save == null) return;
            Save.recentQuestionIds.Remove(questionId);
            Save.recentQuestionIds.Insert(0, questionId);
            while (Save.recentQuestionIds.Count > 200)
                Save.recentQuestionIds.RemoveAt(Save.recentQuestionIds.Count - 1);
        }

        private static Milestone MilestoneAt(List<Milestone> milestones, int index)
        {
            for (int i = 0; i < milestones.Count; i++)
            {
                if (milestones[i].Index == index) return milestones[i];
            }
            return null;
        }
    }
}
