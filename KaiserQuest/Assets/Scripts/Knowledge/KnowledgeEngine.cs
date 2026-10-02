using System;
using System.Collections.Generic;
using UnityEngine;

namespace KaiserQuest.Knowledge
{
    /// <summary>The verdict and the teaching attached to one graded answer.</summary>
    public class GradedAnswer
    {
        public string QuestionId;
        public string Concept;
        public string ConceptName;
        public bool Correct;
        public string Chosen;
        public string CorrectAnswer;
        public string Explanation;
        public int Difficulty;
        public float MasteryBefore;
        public float MasteryAfter;
        public string ConfidenceAfter;
        public bool IsFastError;
        public float TimeRatio;
        public List<Detection> Detections = new List<Detection>();
    }

    /// <summary>An assembled set of questions for a trial.</summary>
    public class QuestionSelection
    {
        public List<BankQuestion> Questions = new List<BankQuestion>();
        public Dictionary<string, int> TargetDifficulty = new Dictionary<string, int>();
    }

    /// <summary>
    /// The Unity-side Knowledge Engine.
    ///
    /// A full client-side port of the server's engine, and deliberately the
    /// authority for play: the game must run on a 2 GB Android device with no
    /// network at all. The Python engine remains the authority for content
    /// generation, validation and fleet-level analytics — the parts that genuinely
    /// want a server — while everything a player feels (adaptive difficulty, named
    /// misconceptions, mastery gates, the Archivist's exam) happens here, instantly.
    ///
    /// Both implementations are kept structurally identical so they agree about a
    /// player's knowledge.
    /// </summary>
    public class KnowledgeEngine : MonoBehaviour
    {
        public static KnowledgeEngine Instance { get; private set; }

        [Header("Knowledge Data (Resources paths, no extension)")]
        public string conceptGraphPath = "Knowledge/concepts";
        public string misconceptionPath = "Knowledge/misconceptions";

        [Header("Bank paths")]
        public string bankPathPrefix = "Questions/bank_";

        /// <summary>
        /// Which bank file holds each realm's questions, exported by the content
        /// pipeline. Banks are named by subject ('math') and realms are named by
        /// campaign ('algebra'), so this is the only place that knows the two are
        /// the same material.
        /// </summary>
        public string bankMapPath = "Knowledge/banks";

        public ConceptGraph Graph { get; private set; }
        public MisconceptionDetector Detector { get; private set; }
        public KnowledgeTracer Tracer { get; private set; }
        public AttemptLog Log { get; private set; }

        private readonly Dictionary<string, List<BankQuestion>> _byConcept =
            new Dictionary<string, List<BankQuestion>>();
        private readonly Dictionary<string, BankQuestion> _byId =
            new Dictionary<string, BankQuestion>();
        private int _bankSize;

        public int BankSize { get { return _bankSize; } }

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }
            Instance = this;
            DontDestroyOnLoad(gameObject);
            LoadAll();
        }

        // ------------------------------------------------------------------
        // Loading
        // ------------------------------------------------------------------
        public void LoadAll()
        {
            GraphData graphData = LoadJson<GraphData>(conceptGraphPath);
            Graph = new ConceptGraph(graphData);

            MisconceptionFile misconceptionFile = LoadJson<MisconceptionFile>(misconceptionPath);
            Detector = new MisconceptionDetector(misconceptionFile);

            Log = Log ?? new AttemptLog();
            Tracer = new KnowledgeTracer("local", Graph);
            LoadBanks();

            Debug.Log("[KnowledgeEngine] Loaded " + Graph.ConceptCount + " concepts, "
                      + _bankSize + " questions, " + Detector.Count + " misconceptions.");

            // No questions means no trial can start anywhere in the campaign: the
            // player can create a character and walk the world, and then every
            // keeper turns them away. Say so once, loudly, at the point it happens.
            if (_bankSize == 0)
            {
                Debug.LogError("[KnowledgeEngine] No questions loaded at all — every trial will "
                               + "refuse to start. Run the content pipeline so Resources/"
                               + bankPathPrefix + "*.json and Resources/" + bankMapPath + ".json exist.");
            }
        }

        private void LoadBanks()
        {
            _byConcept.Clear();
            _byId.Clear();
            _bankSize = 0;
            if (Graph == null) return;

            BankMap map = LoadJson<BankMap>(bankMapPath);
            HashSet<string> loaded = new HashSet<string>();

            for (int r = 0; r < Graph.Realms.Count; r++)
            {
                RealmData realm = Graph.Realms[r];
                if (realm == null) continue;

                List<string> subjects = map != null ? map.SubjectsFor(realm.id) : null;
                // Without a published mapping, a realm named like its bank still
                // works — that is how this read before the mapping existed.
                if (subjects == null || subjects.Count == 0) subjects = new List<string> { realm.id };

                for (int s = 0; s < subjects.Count; s++)
                {
                    string subject = subjects[s];
                    // Two realms may share a bank; read each file once.
                    if (!loaded.Add(subject)) continue;

                    BankFile bank = LoadJson<BankFile>(bankPathPrefix + subject);
                    if (bank == null || bank.questions == null)
                    {
                        // An error, not a warning: an empty bank is not a missing
                        // nicety, it is a campaign nobody can play.
                        Debug.LogError("[KnowledgeEngine] No question bank at Resources/"
                                       + bankPathPrefix + subject + " for realm '" + realm.id
                                       + "'. Run the content pipeline to export it.");
                        continue;
                    }

                    IndexBank(bank);
                }
            }
        }

        private void IndexBank(BankFile bank)
        {
            for (int q = 0; q < bank.questions.Count; q++)
            {
                BankQuestion question = bank.questions[q];
                if (question == null) continue;
                _bankSize++;

                if (!string.IsNullOrEmpty(question.id)) _byId[question.id] = question;

                string concept = question.concept;
                if (string.IsNullOrEmpty(concept))
                    concept = Graph.TagText(question.question, question.topic);
                if (string.IsNullOrEmpty(concept)) continue;

                List<BankQuestion> list;
                if (!_byConcept.TryGetValue(concept, out list))
                {
                    list = new List<BankQuestion>();
                    _byConcept[concept] = list;
                }
                list.Add(question);
            }
        }

        private static T LoadJson<T>(string resourcePath) where T : class
        {
            TextAsset asset = Resources.Load<TextAsset>(resourcePath);
            if (asset == null)
            {
                Debug.LogWarning("[KnowledgeEngine] Missing resource: " + resourcePath);
                return null;
            }
            try
            {
                return JsonUtility.FromJson<T>(asset.text);
            }
            catch (Exception error)
            {
                Debug.LogError("[KnowledgeEngine] Failed to parse " + resourcePath + ": " + error.Message);
                return null;
            }
        }

        // ------------------------------------------------------------------
        // Bank queries
        // ------------------------------------------------------------------
        public List<BankQuestion> ForConcept(string conceptId)
        {
            List<BankQuestion> list;
            return _byConcept.TryGetValue(conceptId, out list) ? list : new List<BankQuestion>();
        }

        public int QuestionCount(string conceptId)
        {
            List<BankQuestion> list;
            return _byConcept.TryGetValue(conceptId, out list) ? list.Count : 0;
        }

        public BankQuestion GetQuestion(string questionId)
        {
            BankQuestion question;
            return !string.IsNullOrEmpty(questionId) && _byId.TryGetValue(questionId, out question)
                ? question
                : null;
        }

        public List<string> RealmIds()
        {
            List<string> ids = new List<string>();
            if (Graph == null) return ids;
            for (int i = 0; i < Graph.Realms.Count; i++) ids.Add(Graph.Realms[i].id);
            return ids;
        }

        // ------------------------------------------------------------------
        // Adaptive difficulty
        // ------------------------------------------------------------------
        /// <summary>
        /// The hidden adaptive difficulty.
        ///
        /// Derived from P(known) so a player who is solid gets stretched and a player
        /// who is struggling gets solid ground to stand on. The player is never shown
        /// a number; they simply find the questions meet them.
        /// </summary>
        public int TargetDifficulty(string conceptId)
        {
            ConceptKnowledge knowledge = Tracer.Get(conceptId);
            if (knowledge.Attempts == 0)
            {
                ConceptData concept = Graph.Concept(conceptId);
                int level = concept != null ? concept.level : 2;
                return Mathf.Clamp(level, 1, 5);
            }

            float p = knowledge.PKnownNow();
            float target = 1f + 4f * p;
            if (knowledge.Attempts < 4) target -= 0.4f;   // gentle while the estimate is noisy
            return Mathf.Clamp(Mathf.RoundToInt(target + 0.25f), 1, 5);
        }

        // ------------------------------------------------------------------
        // Selection
        // ------------------------------------------------------------------
        /// <summary>
        /// Choose `count` questions spread across `concepts`.
        ///
        /// Round-robins across concepts rather than sampling globally, so a trial that
        /// covers two concepts asks about both. Within a concept, difficulty comes from
        /// the adaptive target, and questions that can surface one of the player's
        /// active misconceptions are taken first.
        /// </summary>
        public QuestionSelection Select(
            List<string> concepts,
            int count,
            ICollection<string> excludeIds = null,
            ICollection<string> preferMisconceptions = null,
            Dictionary<string, int> targets = null)
        {
            QuestionSelection selection = new QuestionSelection();
            if (concepts == null || concepts.Count == 0 || count <= 0) return selection;

            List<string> viable = new List<string>();
            for (int i = 0; i < concepts.Count; i++)
            {
                if (QuestionCount(concepts[i]) > 0) viable.Add(concepts[i]);
            }
            if (viable.Count == 0) return selection;

            HashSet<string> excluded = new HashSet<string>();
            if (excludeIds != null) foreach (string id in excludeIds) excluded.Add(id);
            HashSet<string> wanted = new HashSet<string>();
            if (preferMisconceptions != null) foreach (string id in preferMisconceptions) wanted.Add(id);

            HashSet<string> used = new HashSet<string>();
            int cursor = 0;
            int attempts = 0;
            int maxAttempts = count * 30;

            while (selection.Questions.Count < count && attempts < maxAttempts)
            {
                attempts++;
                string concept = viable[cursor % viable.Count];
                cursor++;

                int difficulty = TargetDifficulty(concept);
                if (targets != null && targets.ContainsKey(concept)) difficulty = targets[concept];

                List<BankQuestion> pool = new List<BankQuestion>();
                List<BankQuestion> available = ForConcept(concept);
                for (int i = 0; i < available.Count; i++)
                {
                    string id = available[i].id;
                    if (excluded.Contains(id) || used.Contains(id)) continue;
                    pool.Add(available[i]);
                }
                if (pool.Count == 0) continue;

                BankQuestion picked = Pick(pool, difficulty, wanted);
                if (picked == null) continue;

                used.Add(picked.id);
                selection.Questions.Add(picked);
                selection.TargetDifficulty[concept] = picked.difficulty;
            }
            return selection;
        }

        private static BankQuestion Pick(List<BankQuestion> pool, int difficulty, HashSet<string> wanted)
        {
            int bestHit = -1;
            int bestDistance = int.MinValue;
            for (int i = 0; i < pool.Count; i++)
            {
                int hit = SurfacesMisconception(pool[i], wanted) ? 1 : 0;
                int distance = -Math.Abs(pool[i].difficulty - difficulty);
                if (hit > bestHit || (hit == bestHit && distance > bestDistance))
                {
                    bestHit = hit;
                    bestDistance = distance;
                }
            }

            // Shortlist the top tier, then pick at random so a retried trial is not
            // identical while still respecting the difficulty target.
            List<BankQuestion> shortlist = new List<BankQuestion>();
            for (int i = 0; i < pool.Count; i++)
            {
                int hit = SurfacesMisconception(pool[i], wanted) ? 1 : 0;
                int distance = -Math.Abs(pool[i].difficulty - difficulty);
                if (hit == bestHit && distance >= bestDistance - 1) shortlist.Add(pool[i]);
            }
            return shortlist.Count > 0 ? shortlist[UnityEngine.Random.Range(0, shortlist.Count)] : null;
        }

        private static bool SurfacesMisconception(BankQuestion question, HashSet<string> wanted)
        {
            if (wanted == null || wanted.Count == 0) return false;
            if (question.misconceptionTags == null) return false;
            for (int i = 0; i < question.misconceptionTags.Count; i++)
            {
                if (wanted.Contains(question.misconceptionTags[i].misconceptionId)) return true;
            }
            return false;
        }

        // ------------------------------------------------------------------
        // Grading
        // ------------------------------------------------------------------
        /// <summary>
        /// Grade one answer and fold it into the knowledge trace.
        ///
        /// Called immediately after the player answers, before the next question is
        /// shown, so the trace is always current and the very next selection is aimed
        /// at what the player just revealed.
        /// </summary>
        public GradedAnswer Grade(
            string questionId,
            string chosen,
            float responseTimeMs,
            int hintsUsed = 0,
            int tries = 1,
            string trialId = null)
        {
            BankQuestion question = GetQuestion(questionId);
            if (question == null) return null;

            bool correct = question.IsCorrect(chosen);
            string concept = question.concept;
            if (string.IsNullOrEmpty(concept)) return null;

            float expected = question.expectedTimeMs > 0f
                ? question.expectedTimeMs
                : EstimateExpectedTime(question.question, question.options != null ? question.options.Count : 4);

            string misconceptionId = correct ? null : question.MisconceptionFor(chosen);

            Attempt attempt = new Attempt();
            attempt.concept = concept;
            attempt.questionId = questionId;
            attempt.correct = correct;
            attempt.difficulty = question.difficulty;
            attempt.responseTimeMs = responseTimeMs;
            attempt.expectedTimeMs = expected;
            attempt.hintsUsed = hintsUsed;
            attempt.tries = tries;
            attempt.chosen = chosen;
            attempt.correctAnswer = question.correctAnswer;
            attempt.misconceptionId = misconceptionId;
            attempt.domain = question.topic;
            ConceptData conceptData = Graph.Concept(concept);
            attempt.realm = conceptData != null ? conceptData.realm : null;

            ConceptKnowledge knowledge = Tracer.Get(concept);
            float masteryBefore = knowledge.Mastery();

            Log.Add(attempt);
            Tracer.Observe(attempt);

            List<Detection> detections = Detector.Detect(attempt, Log, question);

            GradedAnswer graded = new GradedAnswer();
            graded.QuestionId = questionId;
            graded.Concept = concept;
            graded.ConceptName = conceptData != null ? conceptData.name : concept;
            graded.Correct = correct;
            graded.Chosen = chosen;
            graded.CorrectAnswer = question.correctAnswer;
            graded.Explanation = question.explanation;
            graded.Difficulty = question.difficulty;
            graded.MasteryBefore = masteryBefore;
            graded.MasteryAfter = knowledge.Mastery();
            graded.ConfidenceAfter = knowledge.Confidence();
            graded.IsFastError = attempt.IsFastError;
            graded.TimeRatio = attempt.TimeRatio;
            graded.Detections = detections;
            return graded;
        }

        /// <summary>Baseline time a competent reader needs for one item.</summary>
        public static float EstimateExpectedTime(string question, int options)
        {
            int length = question != null ? question.Length : 0;
            return 2500f + 28f * length + 450f * Mathf.Max(0, options);
        }

        /// <summary>Misconceptions currently being applied, most severe first.</summary>
        public List<string> ActiveMisconceptionIds(string realmId = null, int limit = 4)
        {
            List<Detection> detections = Detector.Summarize(Log, null, limit);
            List<string> ids = new List<string>();
            for (int i = 0; i < detections.Count; i++)
            {
                if (string.IsNullOrEmpty(detections[i].MisconceptionId)) continue;
                if (realmId != null && !Tracer.IsInRealm(detections[i].Concept, realmId)) continue;
                ids.Add(detections[i].MisconceptionId);
            }
            return ids;
        }

        public KnowledgeProfile ProfileFor(string realmId)
        {
            return new KnowledgeProfile("local", realmId, Tracer, Log, Graph, Detector);
        }

        /// <summary>Replace the trace and history, e.g. when a save is loaded.</summary>
        public void RestoreKnowledge(List<ConceptKnowledgeData> knowledge, List<AttemptData> attempts)
        {
            Tracer = new KnowledgeTracer("local", Graph);
            Tracer.LoadData(knowledge);
            Log = new AttemptLog();
            Log.LoadData(attempts);
        }
    }
}
