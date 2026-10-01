using System;
using System.Collections.Generic;

namespace KaiserQuest.Knowledge
{
    /// <summary>Wall-clock time in seconds since the epoch, matching the backend.</summary>
    public static class Clock
    {
        private static readonly DateTime Epoch = new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);

        public static double Now
        {
            get { return (DateTime.UtcNow - Epoch).TotalSeconds; }
        }

        public static double DaysBetween(double from, double to)
        {
            return Math.Max(0.0, (to - from) / 86400.0);
        }
    }

    /// <summary>
    /// One answered question — the raw signal the engine learns from.
    ///
    /// A right answer is not 1 and a wrong answer is not 0. What gets kept is what
    /// can be acted on: how long it took relative to the question's expected
    /// reading time, how many hints were needed, how many tries, and which
    /// distractor was chosen (which is what names a misconception).
    /// </summary>
    public class Attempt
    {
        public string concept;
        public string questionId;
        public bool correct;
        public int difficulty = 2;
        public float responseTimeMs;
        public float expectedTimeMs;
        public int hintsUsed;
        public int tries = 1;
        public string chosen;
        public string correctAnswer;
        public string misconceptionId;
        public string domain;
        public string realm;
        public double timestamp = Clock.Now;

        /// <summary>A wrong answer given faster than the question can be read.</summary>
        public const float FastErrorRatio = 0.4f;

        public float TimeRatio
        {
            get { return expectedTimeMs <= 0f ? 1f : responseTimeMs / expectedTimeMs; }
        }

        public bool IsFastError
        {
            get { return !correct && TimeRatio < FastErrorRatio; }
        }

        public bool IsHelped
        {
            get { return correct && hintsUsed > 0; }
        }

        /// <summary>
        /// How much this observation should move the estimate, 0..1.
        ///
        /// Correct answers reached unaided and unhurried count double one squeezed
        /// out of hints; a rushed wrong answer counts for less than a considered
        /// one, because it tells us about haste rather than knowledge.
        /// </summary>
        public float EvidenceWeight
        {
            get
            {
                float weight = 1f;
                if (IsHelped) weight *= 0.55f;
                if (tries > 1) weight *= Math.Max(0.4f, 1f - 0.2f * (tries - 1));
                if (IsFastError) weight *= 0.5f;
                return Math.Max(0.15f, Math.Min(1f, weight));
            }
        }

        public double AgeDays
        {
            get { return Clock.DaysBetween(timestamp, Clock.Now); }
        }

        public AttemptData ToData()
        {
            AttemptData data = new AttemptData();
            data.concept = concept;
            data.questionId = questionId;
            data.correct = correct;
            data.difficulty = difficulty;
            data.responseTimeMs = responseTimeMs;
            data.expectedTimeMs = expectedTimeMs;
            data.hintsUsed = hintsUsed;
            data.tries = tries;
            data.chosen = chosen;
            data.correctAnswer = correctAnswer;
            data.misconceptionId = misconceptionId;
            data.domain = domain;
            data.realm = realm;
            data.timestamp = timestamp;
            return data;
        }

        public static Attempt FromData(AttemptData data)
        {
            Attempt attempt = new Attempt();
            if (data == null) return attempt;
            attempt.concept = data.concept;
            attempt.questionId = data.questionId;
            attempt.correct = data.correct;
            attempt.difficulty = data.difficulty;
            attempt.responseTimeMs = data.responseTimeMs;
            attempt.expectedTimeMs = data.expectedTimeMs;
            attempt.hintsUsed = data.hintsUsed;
            attempt.tries = data.tries;
            attempt.chosen = data.chosen;
            attempt.correctAnswer = data.correctAnswer;
            attempt.misconceptionId = data.misconceptionId;
            attempt.domain = data.domain;
            attempt.realm = data.realm;
            attempt.timestamp = data.timestamp;
            return attempt;
        }
    }

    /// <summary>Append-only attempt history, with the queries the engine needs.</summary>
    public class AttemptLog
    {
        private readonly List<Attempt> _attempts = new List<Attempt>();

        public int Count { get { return _attempts.Count; } }
        public IList<Attempt> All { get { return _attempts; } }

        public void Add(Attempt attempt)
        {
            if (attempt != null) _attempts.Add(attempt);
        }

        public void Clear()
        {
            _attempts.Clear();
        }

        public List<Attempt> ForConcept(string concept)
        {
            List<Attempt> result = new List<Attempt>();
            for (int i = 0; i < _attempts.Count; i++)
            {
                if (_attempts[i].concept == concept) result.Add(_attempts[i]);
            }
            return result;
        }

        public float Accuracy(string concept)
        {
            List<Attempt> matches = ForConcept(concept);
            if (matches.Count == 0) return 0f;
            int correct = 0;
            for (int i = 0; i < matches.Count; i++) if (matches[i].correct) correct++;
            return (float)correct / matches.Count;
        }

        /// <summary>Accuracy over just the most recent attempts — catches live recovery.</summary>
        public float RecentAccuracy(string concept, int window = 6)
        {
            List<Attempt> matches = SortByTime(ForConcept(concept));
            int start = Math.Max(0, matches.Count - window);
            int considered = matches.Count - start;
            if (considered == 0) return 0f;
            int correct = 0;
            for (int i = start; i < matches.Count; i++) if (matches[i].correct) correct++;
            return (float)correct / considered;
        }

        public float MedianTimeRatio(string concept)
        {
            List<Attempt> matches = ForConcept(concept);
            if (matches.Count == 0) return 1f;
            List<float> ratios = new List<float>();
            for (int i = 0; i < matches.Count; i++) ratios.Add(matches[i].TimeRatio);
            ratios.Sort();
            int mid = ratios.Count / 2;
            return ratios.Count % 2 == 0 ? (ratios[mid - 1] + ratios[mid]) * 0.5f : ratios[mid];
        }

        public List<Attempt> FastErrors(string concept = null)
        {
            List<Attempt> result = new List<Attempt>();
            for (int i = 0; i < _attempts.Count; i++)
            {
                Attempt attempt = _attempts[i];
                if (concept != null && attempt.concept != concept) continue;
                if (attempt.IsFastError) result.Add(attempt);
            }
            return result;
        }

        public Dictionary<string, int> MisconceptionCounts(string concept = null)
        {
            Dictionary<string, int> counts = new Dictionary<string, int>();
            for (int i = 0; i < _attempts.Count; i++)
            {
                Attempt attempt = _attempts[i];
                if (concept != null && attempt.concept != concept) continue;
                if (string.IsNullOrEmpty(attempt.misconceptionId)) continue;
                int existing;
                counts.TryGetValue(attempt.misconceptionId, out existing);
                counts[attempt.misconceptionId] = existing + 1;
            }
            return counts;
        }

        /// <summary>Distractor strings chosen more than once on the same concept.</summary>
        public Dictionary<string, int> RepeatedChoices(string concept, int minimum = 2)
        {
            Dictionary<string, int> counts = new Dictionary<string, int>();
            List<Attempt> matches = ForConcept(concept);
            for (int i = 0; i < matches.Count; i++)
            {
                Attempt attempt = matches[i];
                if (attempt.correct || string.IsNullOrEmpty(attempt.chosen)) continue;
                int existing;
                counts.TryGetValue(attempt.chosen, out existing);
                counts[attempt.chosen] = existing + 1;
            }

            Dictionary<string, int> filtered = new Dictionary<string, int>();
            foreach (KeyValuePair<string, int> pair in counts)
            {
                if (pair.Value >= minimum) filtered[pair.Key] = pair.Value;
            }
            return filtered;
        }

        /// <summary>
        /// Chance-level accuracy at very low response times: the statistical
        /// fingerprint of guessing rather than reasoning.
        /// </summary>
        public bool GuessLike(string concept, int minAttempts = 8)
        {
            List<Attempt> matches = ForConcept(concept);
            if (matches.Count < minAttempts) return false;
            float accuracy = Accuracy(concept);
            if (accuracy < 0.10f || accuracy > 0.38f) return false;
            return MedianTimeRatio(concept) <= 0.55f;
        }

        public Attempt LastForConcept(string concept)
        {
            Attempt last = null;
            for (int i = 0; i < _attempts.Count; i++)
            {
                if (_attempts[i].concept != concept) continue;
                if (last == null || _attempts[i].timestamp > last.timestamp) last = _attempts[i];
            }
            return last;
        }

        public List<AttemptData> ToData(int maxEntries = 3000)
        {
            int start = Math.Max(0, _attempts.Count - maxEntries);
            List<AttemptData> data = new List<AttemptData>();
            for (int i = start; i < _attempts.Count; i++) data.Add(_attempts[i].ToData());
            return data;
        }

        public void LoadData(List<AttemptData> data)
        {
            _attempts.Clear();
            if (data == null) return;
            for (int i = 0; i < data.Count; i++) _attempts.Add(Attempt.FromData(data[i]));
        }

        private static List<Attempt> SortByTime(List<Attempt> attempts)
        {
            attempts.Sort(delegate (Attempt a, Attempt b) { return a.timestamp.CompareTo(b.timestamp); });
            return attempts;
        }
    }
}
