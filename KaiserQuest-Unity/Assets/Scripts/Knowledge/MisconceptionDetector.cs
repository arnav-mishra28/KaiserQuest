using System;
using System.Collections.Generic;

namespace KaiserQuest.Knowledge
{
    /// <summary>A believed misconception, with how sure the engine is and why.</summary>
    public class Detection
    {
        public string MisconceptionId;
        public string Concept;
        public float Confidence;
        public int Occurrences;
        public string Evidence;

        public bool IsCertain { get { return Confidence >= 0.95f; } }
    }

    /// <summary>One step of remediation, ready to be shown to the player.</summary>
    public class RemedyStep
    {
        public string MisconceptionId;
        public string Name;
        public string Concept;
        public int Severity;
        public float Confidence;
        public int Occurrences;
        public string Evidence;
        public string Remedy;
        public List<string> Drills = new List<string>();
    }

    /// <summary>
    /// Turns attempts into named, actionable misconceptions.
    ///
    /// A misconception is a coherent rule the learner is applying that happens to be
    /// wrong — "I expanded 3(x+4) and only multiplied the 3 into the x" is a rule, not
    /// noise. Naming it turns a wrong answer into a specific next lesson instead of
    /// "study harder", which is the single highest-value thing an educational game
    /// can know.
    /// </summary>
    public class MisconceptionDetector
    {
        public const string Rushing = "gen.rushing_unread_question";
        public const string Guessing = "gen.guessing_under_uncertainty";
        public const int MinPatternOccurrences = 3;

        private readonly Dictionary<string, MisconceptionData> _catalog =
            new Dictionary<string, MisconceptionData>();

        public MisconceptionDetector(MisconceptionFile file)
        {
            if (file == null || file.misconceptions == null) return;
            for (int i = 0; i < file.misconceptions.Count; i++)
            {
                MisconceptionData item = file.misconceptions[i];
                if (item != null && !string.IsNullOrEmpty(item.id)) _catalog[item.id] = item;
            }
        }

        public int Count { get { return _catalog.Count; } }

        public MisconceptionData Get(string id)
        {
            MisconceptionData item;
            return !string.IsNullOrEmpty(id) && _catalog.TryGetValue(id, out item) ? item : null;
        }

        public List<MisconceptionData> All()
        {
            return new List<MisconceptionData>(_catalog.Values);
        }

        // ------------------------------------------------------------------
        // Per-attempt detection
        // ------------------------------------------------------------------
        /// <summary>
        /// Detections justified by this attempt plus the history behind it. Called
        /// after every answer, so it stays cheap: the exact path is a lookup and the
        /// behavioural paths are linear in the attempts on this concept.
        /// </summary>
        public List<Detection> Detect(Attempt attempt, AttemptLog log, BankQuestion question = null)
        {
            List<Detection> detections = new List<Detection>();

            Detection exact = DetectExact(attempt, log, question);
            if (exact != null) detections.Add(exact);

            Detection rushing = DetectRushing(attempt, log);
            if (rushing != null) detections.Add(rushing);

            Detection guessing = DetectGuessing(attempt, log);
            if (guessing != null) detections.Add(guessing);

            Detection repeated = DetectRepeatedDistractor(attempt, log);
            if (repeated != null) detections.Add(repeated);

            return detections;
        }

        private Detection DetectExact(Attempt attempt, AttemptLog log, BankQuestion question)
        {
            if (attempt.correct) return null;

            string mappedId = null;
            if (question != null) mappedId = question.MisconceptionFor(attempt.chosen);
            if (string.IsNullOrEmpty(mappedId) && !string.IsNullOrEmpty(attempt.misconceptionId))
                mappedId = attempt.misconceptionId;

            if (string.IsNullOrEmpty(mappedId) || !_catalog.ContainsKey(mappedId)) return null;

            int occurrences = 1;
            List<Attempt> history = log.ForConcept(attempt.concept);
            for (int i = 0; i < history.Count; i++)
            {
                if (history[i].misconceptionId == mappedId) occurrences++;
            }

            Detection detection = new Detection();
            detection.MisconceptionId = mappedId;
            detection.Concept = attempt.concept;
            detection.Confidence = 1f;
            detection.Occurrences = occurrences;
            detection.Evidence = "Chose the distractor that encodes this rule on " + attempt.questionId + ".";
            return detection;
        }

        private Detection DetectRushing(Attempt attempt, AttemptLog log)
        {
            if (!attempt.IsFastError) return null;
            List<Attempt> fast = log.FastErrors(attempt.concept);
            if (fast.Count < MinPatternOccurrences) return null;

            Detection detection = new Detection();
            detection.MisconceptionId = Rushing;
            detection.Concept = attempt.concept;
            detection.Confidence = Math.Min(0.9f, 0.3f + 0.12f * fast.Count);
            detection.Occurrences = fast.Count;
            detection.Evidence = fast.Count + " answers on this concept were wrong in under "
                + (int)(attempt.TimeRatio * 100) + "% of the time it takes to read the question.";
            return detection;
        }

        private Detection DetectGuessing(Attempt attempt, AttemptLog log)
        {
            if (attempt.correct || !log.GuessLike(attempt.concept)) return null;

            Detection detection = new Detection();
            detection.MisconceptionId = Guessing;
            detection.Concept = attempt.concept;
            detection.Confidence = 0.7f;
            detection.Occurrences = log.ForConcept(attempt.concept).Count;
            detection.Evidence = "Accuracy is at chance level (" + (int)(log.Accuracy(attempt.concept) * 100)
                + "%) while answers come at " + (int)(log.MedianTimeRatio(attempt.concept) * 100)
                + "% of expected reading time.";
            return detection;
        }

        /// <summary>
        /// The same wrong answer chosen twice or more. Even without a tagged
        /// distractor this is strong evidence of one consistent broken rule, so it is
        /// surfaced for a human (or an LLM) to name.
        /// </summary>
        private Detection DetectRepeatedDistractor(Attempt attempt, AttemptLog log)
        {
            if (attempt.correct || string.IsNullOrEmpty(attempt.chosen)) return null;
            Dictionary<string, int> repeated = log.RepeatedChoices(attempt.concept, 2);
            int count;
            if (!repeated.TryGetValue(attempt.chosen, out count) || count < 2) return null;

            Detection detection = new Detection();
            detection.MisconceptionId = string.Empty;
            detection.Concept = attempt.concept;
            detection.Confidence = Math.Min(0.75f, 0.35f + 0.1f * count);
            detection.Occurrences = count;
            detection.Evidence = "Chose '" + attempt.chosen + "' as a wrong answer " + count
                + " times on this concept.";
            return detection;
        }

        // ------------------------------------------------------------------
        // History-wide roll-up
        // ------------------------------------------------------------------
        public List<Detection> Summarize(AttemptLog log, string concept = null, int limit = 5)
        {
            Dictionary<string, Detection> byId = new Dictionary<string, Detection>();
            List<Attempt> pool = new List<Attempt>();
            for (int i = 0; i < log.All.Count; i++)
            {
                if (concept == null || log.All[i].concept == concept) pool.Add(log.All[i]);
            }
            pool.Sort(delegate (Attempt a, Attempt b) { return b.timestamp.CompareTo(a.timestamp); });

            for (int i = 0; i < pool.Count; i++)
            {
                List<Detection> detections = Detect(pool[i], log);
                for (int d = 0; d < detections.Count; d++)
                {
                    Detection detection = detections[d];
                    if (string.IsNullOrEmpty(detection.MisconceptionId))
                    {
                        string key = "unlabelled:" + detection.Concept;
                        if (!byId.ContainsKey(key)) byId[key] = detection;
                        continue;
                    }

                    Detection existing;
                    if (!byId.TryGetValue(detection.MisconceptionId, out existing)
                        || detection.Confidence > existing.Confidence)
                    {
                        if (existing != null)
                            detection.Occurrences = Math.Max(detection.Occurrences, existing.Occurrences);
                        byId[detection.MisconceptionId] = detection;
                    }
                }
            }

            List<Detection> ordered = new List<Detection>(byId.Values);
            ordered.Sort(delegate (Detection a, Detection b)
            {
                int severity = Severity(b.MisconceptionId).CompareTo(Severity(a.MisconceptionId));
                if (severity != 0) return severity;
                return b.Confidence.CompareTo(a.Confidence);
            });
            if (ordered.Count > limit) ordered.RemoveRange(limit, ordered.Count - limit);
            return ordered;
        }

        public int Severity(string misconceptionId)
        {
            MisconceptionData item = Get(misconceptionId);
            return item != null ? item.severity : 2;
        }

        /// <summary>
        /// Ordered micro-lessons the game should put in front of the player, with
        /// drills de-duplicated so three arithmetic misconceptions do not drill the
        /// same prerequisite three times.
        /// </summary>
        public List<RemedyStep> RemedyPlan(List<Detection> detections)
        {
            List<RemedyStep> plan = new List<RemedyStep>();
            if (detections == null) return plan;

            List<Detection> sorted = new List<Detection>(detections);
            sorted.Sort(delegate (Detection a, Detection b)
            {
                int severity = Severity(b.MisconceptionId).CompareTo(Severity(a.MisconceptionId));
                if (severity != 0) return severity;
                return b.Confidence.CompareTo(a.Confidence);
            });

            HashSet<string> usedDrills = new HashSet<string>();
            for (int i = 0; i < sorted.Count; i++)
            {
                MisconceptionData item = Get(sorted[i].MisconceptionId);
                if (item == null) continue;

                RemedyStep step = new RemedyStep();
                step.MisconceptionId = item.id;
                step.Name = item.name;
                step.Concept = item.concept;
                step.Severity = item.severity;
                step.Confidence = sorted[i].Confidence;
                step.Occurrences = sorted[i].Occurrences;
                step.Evidence = sorted[i].Evidence;
                step.Remedy = item.remedy;
                if (item.drills != null)
                {
                    for (int d = 0; d < item.drills.Count; d++)
                    {
                        if (usedDrills.Contains(item.drills[d])) continue;
                        usedDrills.Add(item.drills[d]);
                        step.Drills.Add(item.drills[d]);
                    }
                }
                plan.Add(step);
            }
            return plan;
        }
    }
}
