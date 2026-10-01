using System;
using System.Collections.Generic;

namespace KaiserQuest.Knowledge
{
    /// <summary>
    /// Classic four-parameter Bayesian Knowledge Tracing, with the parameters
    /// scaled by how hard the concept is. Deliberately cheap: this must run on a
    /// 2 GB Android device while a battle animation is playing.
    ///
    /// The interface is narrow enough that a Deep Knowledge Tracing or transformer
    /// model could replace it later without touching any caller.
    /// </summary>
    [Serializable]
    public class BKTParams
    {
        public const float DefaultPInit = 0.25f;
        public const float DefaultPLearn = 0.18f;
        public const float DefaultPGuess = 0.20f;
        public const float DefaultPSlip = 0.10f;

        public float pInit = DefaultPInit;
        public float pLearn = DefaultPLearn;
        public float pGuess = DefaultPGuess;
        public float pSlip = DefaultPSlip;

        public static BKTParams ForLevel(int level)
        {
            int clamped = Math.Max(1, Math.Min(5, level));
            BKTParams p = new BKTParams();
            p.pInit = Math.Max(0.08f, 0.30f - 0.04f * clamped);
            p.pLearn = Math.Max(0.10f, 0.24f - 0.025f * clamped);
            p.pGuess = Math.Max(0.10f, 0.24f - 0.025f * clamped);
            p.pSlip = 0.10f;
            return p;
        }
    }

    /// <summary>
    /// What the engine believes about one concept for one player.
    ///
    /// `pKnown` is always the undecayed belief; forgetting is applied on read so the
    /// stored value stays the last thing actually observed.
    /// </summary>
    public class ConceptKnowledge
    {
        public const float StrongThreshold = 0.80f;
        public const float ModerateThreshold = 0.55f;
        public const int MinEvidence = 3;
        public const int ModerateEvidence = 2;
        public const int StrongEvidence = 6;
        public const float MasteredPKnown = 0.80f;

        /// <summary>
        /// Retention never quite reaches zero: a concept mastered long ago settles at
        /// this fraction, which reads as "rusty, needs a recap" rather than "never
        /// learned".
        /// </summary>
        public const float RetentionFloor = 0.15f;

        private static readonly float[] HalfLives = { 21f, 14f, 10f, 7f, 5f };

        public string ConceptId;
        public BKTParams Params = new BKTParams();
        public float PKnown;
        public int Attempts;
        public int Correct;
        public int Hints;
        public int FastErrors;
        public double LastPracticed;
        public double FirstPracticed;
        public int DifficultyCeiling;
        public int ReferenceLevel = 2;
        public float Stability;

        public ConceptKnowledge(string conceptId, BKTParams parameters = null, int referenceLevel = 2)
        {
            ConceptId = conceptId;
            Params = parameters ?? new BKTParams();
            ReferenceLevel = referenceLevel;
            PKnown = Params.pInit;
        }

        /// <summary>
        /// The difficulty this concept is normally encountered at: the player's
        /// demonstrated ceiling once they have one, otherwise the level the
        /// curriculum teaches it at. Without the curriculum fallback, the very first
        /// attempt on a concept would have no baseline to be harder than.
        /// </summary>
        public int Level
        {
            get { return Math.Max(1, Math.Min(5, DifficultyCeiling > 0 ? DifficultyCeiling : ReferenceLevel)); }
        }

        public float HalfLifeDays
        {
            get { return HalfLives[Level - 1]; }
        }

        /// <summary>Fraction of the learned memory still available, 0..1.</summary>
        public float Retention(double? now = null)
        {
            if (LastPracticed <= 0.0 || Attempts == 0) return 0f;
            double days = Clock.DaysBetween(LastPracticed, now ?? Clock.Now);
            if (days <= 0.0) return 1f;
            return (float)Math.Pow(0.5, days / HalfLifeDays);
        }

        /// <summary>Decayed P(known): what the player can actually still do today.</summary>
        public float PKnownNow(double? now = null)
        {
            if (Attempts == 0) return Params.pInit;
            float retained = PKnown * Retention(now);
            return Clamp01(Math.Max(retained, PKnown * RetentionFloor));
        }

        /// <summary>
        /// Player-facing mastery, 0..100.
        ///
        /// Blends how likely the player is to know it today, how deep their success
        /// goes relative to what the curriculum asks, whether they proved it unaided,
        /// and how much evidence stands behind the claim. A mastery figure should not
        /// read 100% off a single answer.
        /// </summary>
        public float Mastery(double? now = null)
        {
            if (Attempts == 0) return 0f;
            float p = PKnownNow(now);
            float depth = Clamp01((float)DifficultyCeiling / Math.Max(1, ReferenceLevel));
            float support = 1f - Clamp01((float)Hints / Math.Max(1, Attempts)) * 0.4f;
            float evidence = 0.45f + 0.55f * Clamp01(Attempts / 4f);
            return (float)Math.Round(100f * p * (0.70f + 0.30f * depth) * support * evidence, 2);
        }

        /// <summary>'Strong' | 'Moderate' | 'Weak' — buckets require evidence, not just probability.</summary>
        public string Confidence(double? now = null)
        {
            if (Attempts < ModerateEvidence) return "Weak";
            float p = PKnownNow(now);
            if (p >= StrongThreshold && Attempts >= StrongEvidence) return "Strong";
            if (p >= ModerateThreshold) return "Moderate";
            return "Weak";
        }

        public bool IsMastered
        {
            get { return PKnownNow() >= MasteredPKnown && Attempts >= MinEvidence; }
        }

        /// <summary>Was learned properly once, but has decayed below the mastery bar.</summary>
        public bool IsRusty
        {
            get
            {
                return Attempts >= StrongEvidence
                       && PKnown >= MasteredPKnown
                       && PKnownNow() < MasteredPKnown;
            }
        }

        /// <summary>Fold one attempt into the belief. Returns (pBefore, pAfter).</summary>
        public void Observe(Attempt attempt, double? now = null)
        {
            double stamp = now ?? Clock.Now;
            float prior = PKnownNow(stamp);

            float guess, slip;
            EffectiveRates(attempt, out guess, out slip);

            float posterior;
            if (attempt.correct)
            {
                float numerator = prior * (1f - slip);
                float denominator = numerator + (1f - prior) * guess;
                posterior = denominator > 0f ? numerator / denominator : prior;
            }
            else
            {
                float numerator = prior * slip;
                float denominator = numerator + (1f - prior) * (1f - guess);
                posterior = denominator > 0f ? numerator / denominator : prior;
            }

            float weight = attempt.EvidenceWeight;
            float learn = Params.pLearn * weight;
            float updated;
            if (attempt.correct)
            {
                updated = posterior + (1f - posterior) * learn;
            }
            else
            {
                // A wrong answer is not a learning event, but re-reading the
                // correction is: a little learning leaks in from the feedback.
                updated = posterior + (1f - posterior) * learn * 0.35f;
            }

            if (attempt.IsHelped)
                updated = posterior + (updated - posterior) * 0.5f;

            PKnown = Clamp01(updated);
            Attempts++;
            Hints += attempt.hintsUsed;
            if (attempt.correct)
            {
                Correct++;
                if (attempt.difficulty > DifficultyCeiling) DifficultyCeiling = attempt.difficulty;
            }
            if (attempt.IsFastError) FastErrors++;
            if (FirstPracticed <= 0.0) FirstPracticed = stamp;
            LastPracticed = stamp;

            double spanDays = Clock.DaysBetween(FirstPracticed, LastPracticed);
            Stability = Clamp01((float)(spanDays / 14.0));
        }

        /// <summary>Difficulty- and behaviour-adjusted (guess, slip) for one attempt.</summary>
        private void EffectiveRates(Attempt attempt, out float guess, out float slip)
        {
            int conceptLevel = DifficultyCeiling > 0 ? DifficultyCeiling : ReferenceLevel;
            float gap = attempt.difficulty - conceptLevel;
            guess = Clamp(Params.pGuess * (1f - 0.13f * gap), 0.02f, 0.6f);
            slip = Clamp(Params.pSlip * (1f + 0.13f * gap), 0.02f, 0.6f);
            guess = Clamp(guess + 0.05f * attempt.hintsUsed, 0.02f, 0.7f);
            if (attempt.tries > 1) guess = Clamp(guess + 0.04f, 0.02f, 0.7f);
            if (attempt.IsFastError) slip = Clamp(slip * 1.5f, 0.02f, 0.75f);
        }

        public ConceptKnowledgeData ToData()
        {
            ConceptKnowledgeData data = new ConceptKnowledgeData();
            data.concept = ConceptId;
            data.pKnown = PKnown;
            data.attempts = Attempts;
            data.correct = Correct;
            data.hints = Hints;
            data.fastErrors = FastErrors;
            data.lastPracticed = LastPracticed;
            data.firstPracticed = FirstPracticed;
            data.difficultyCeiling = DifficultyCeiling;
            data.referenceLevel = ReferenceLevel;
            data.stability = Stability;
            data.pInit = Params.pInit;
            data.pLearn = Params.pLearn;
            data.pGuess = Params.pGuess;
            data.pSlip = Params.pSlip;
            return data;
        }

        public static ConceptKnowledge FromData(ConceptKnowledgeData data)
        {
            if (data == null) return null;
            BKTParams parameters = new BKTParams();
            parameters.pInit = data.pInit;
            parameters.pLearn = data.pLearn;
            parameters.pGuess = data.pGuess;
            parameters.pSlip = data.pSlip;

            ConceptKnowledge knowledge = new ConceptKnowledge(data.concept, parameters, data.referenceLevel);
            knowledge.PKnown = data.pKnown;
            knowledge.Attempts = data.attempts;
            knowledge.Correct = data.correct;
            knowledge.Hints = data.hints;
            knowledge.FastErrors = data.fastErrors;
            knowledge.LastPracticed = data.lastPracticed;
            knowledge.FirstPracticed = data.firstPracticed;
            knowledge.DifficultyCeiling = data.difficultyCeiling;
            knowledge.Stability = data.stability;
            return knowledge;
        }

        private static float Clamp(float value, float lo, float hi)
        {
            return value < lo ? lo : (value > hi ? hi : value);
        }

        private static float Clamp01(float value)
        {
            return Clamp(value, 0f, 1f);
        }
    }

    /// <summary>
    /// Per-player knowledge state across every concept of a realm, plus the
    /// whole-realm views the campaign and the Archivist need.
    /// </summary>
    public class KnowledgeTracer
    {
        public const float MasteryGate = 70f;

        private readonly Dictionary<string, ConceptKnowledge> _knowledge =
            new Dictionary<string, ConceptKnowledge>();

        public string PlayerId;
        public ConceptGraph Graph;

        public KnowledgeTracer(string playerId, ConceptGraph graph)
        {
            PlayerId = playerId;
            Graph = graph;
        }

        public Dictionary<string, ConceptKnowledge> All { get { return _knowledge; } }

        /// <summary>
        /// Look up knowledge state, creating a fresh (prior-only) one if new.
        /// Unknown concepts are still tracked: the graph is the curriculum, not a
        /// cage, and content may be tagged ahead of it.
        /// </summary>
        public ConceptKnowledge Get(string conceptId)
        {
            ConceptKnowledge existing;
            if (_knowledge.TryGetValue(conceptId, out existing)) return existing;

            int level = 2;
            ConceptData concept = Graph != null ? Graph.Concept(conceptId) : null;
            if (concept != null) level = concept.level;

            ConceptKnowledge created = new ConceptKnowledge(conceptId, BKTParams.ForLevel(level), level);
            _knowledge[conceptId] = created;
            return created;
        }

        public float PKnown(string conceptId, bool decayed = true)
        {
            ConceptKnowledge knowledge = Get(conceptId);
            return decayed ? knowledge.PKnownNow() : knowledge.PKnown;
        }

        public float Mastery(string conceptId)
        {
            return Get(conceptId).Mastery();
        }

        public string Confidence(string conceptId)
        {
            return Get(conceptId).Confidence();
        }

        public void Observe(Attempt attempt)
        {
            Get(attempt.concept).Observe(attempt);
        }

        public List<string> KnownConcepts(float threshold = ConceptKnowledge.MasteredPKnown)
        {
            List<string> result = new List<string>();
            foreach (KeyValuePair<string, ConceptKnowledge> pair in _knowledge)
            {
                if (pair.Value.PKnownNow() >= threshold) result.Add(pair.Key);
            }
            return result;
        }

        public List<string> MasteredConcepts()
        {
            List<string> result = new List<string>();
            foreach (KeyValuePair<string, ConceptKnowledge> pair in _knowledge)
            {
                if (pair.Value.IsMastered) result.Add(pair.Key);
            }
            return result;
        }

        public List<string> RustyConcepts()
        {
            List<string> result = new List<string>();
            foreach (KeyValuePair<string, ConceptKnowledge> pair in _knowledge)
            {
                if (pair.Value.IsRusty) result.Add(pair.Key);
            }
            return result;
        }

        public List<KeyValuePair<string, float>> Weakest(string realmId = null, int limit = 10, int minAttempts = 1)
        {
            List<KeyValuePair<string, float>> pairs = new List<KeyValuePair<string, float>>();
            foreach (KeyValuePair<string, ConceptKnowledge> pair in _knowledge)
            {
                if (!IsInRealm(pair.Key, realmId)) continue;
                if (pair.Value.Attempts < minAttempts) continue;
                pairs.Add(new KeyValuePair<string, float>(pair.Key, pair.Value.Mastery()));
            }
            pairs.Sort(delegate (KeyValuePair<string, float> a, KeyValuePair<string, float> b)
            {
                return a.Value.CompareTo(b.Value);
            });
            if (pairs.Count > limit) pairs.RemoveRange(limit, pairs.Count - limit);
            return pairs;
        }

        public List<KeyValuePair<string, float>> Strongest(string realmId = null, int limit = 10)
        {
            List<KeyValuePair<string, float>> pairs = new List<KeyValuePair<string, float>>();
            foreach (KeyValuePair<string, ConceptKnowledge> pair in _knowledge)
            {
                if (!IsInRealm(pair.Key, realmId)) continue;
                if (pair.Value.Attempts == 0) continue;
                pairs.Add(new KeyValuePair<string, float>(pair.Key, pair.Value.Mastery()));
            }
            pairs.Sort(delegate (KeyValuePair<string, float> a, KeyValuePair<string, float> b)
            {
                return b.Value.CompareTo(a.Value);
            });
            if (pairs.Count > limit) pairs.RemoveRange(limit, pairs.Count - limit);
            return pairs;
        }

        public List<string> Frontier(string realmId = null)
        {
            if (Graph == null) return new List<string>();
            HashSet<string> known = new HashSet<string>(KnownConcepts());
            return Graph.Frontier(known, realmId);
        }

        /// <summary>Frontier first, then rusty concepts that used to be solid.</summary>
        public List<string> SuggestedNext(string realmId = null, int limit = 5)
        {
            List<string> suggestions = new List<string>();
            List<string> rusty = RustyConcepts();
            for (int i = 0; i < rusty.Count; i++)
            {
                if (!IsInRealm(rusty[i], realmId)) continue;
                suggestions.Add(rusty[i]);
            }
            List<string> frontier = Frontier(realmId);
            for (int i = 0; i < frontier.Count; i++)
            {
                if (!suggestions.Contains(frontier[i])) suggestions.Add(frontier[i]);
            }
            if (suggestions.Count > limit) suggestions.RemoveRange(limit, suggestions.Count - limit);
            return suggestions;
        }

        /// <summary>
        /// Mean mastery across the realm's entire concept list, unsampled concepts
        /// counting as zero. This is the honest number: it measures how much of the
        /// realm you know, not how well you did on what you happened to attempt.
        /// </summary>
        public float RealmMastery(string realmId)
        {
            if (Graph == null) return 0f;
            List<ConceptData> concepts = Graph.ConceptsOfRealm(realmId);
            if (concepts.Count == 0) return 0f;
            float total = 0f;
            for (int i = 0; i < concepts.Count; i++) total += Get(concepts[i].id).Mastery();
            return (float)Math.Round(total / concepts.Count, 2);
        }

        /// <summary>
        /// Fraction of `conceptIds` at or above `gate` mastery, plus the ones that are
        /// not. This is the primitive every progression gate is built from.
        /// </summary>
        public float Coverage(List<string> conceptIds, float gate, out List<string> unmet)
        {
            unmet = new List<string>();
            if (conceptIds == null || conceptIds.Count == 0) return 1f;
            int passed = 0;
            for (int i = 0; i < conceptIds.Count; i++)
            {
                if (Get(conceptIds[i]).Mastery() >= gate) passed++;
                else unmet.Add(conceptIds[i]);
            }
            return (float)passed / conceptIds.Count;
        }

        public bool IsInRealm(string conceptId, string realmId)
        {
            if (string.IsNullOrEmpty(realmId)) return true;
            if (Graph == null) return true;
            ConceptData concept = Graph.Concept(conceptId);
            return concept == null || concept.realm == realmId;
        }

        // ------------------------------------------------------------------
        // Persistence
        // ------------------------------------------------------------------
        public List<ConceptKnowledgeData> ToData()
        {
            List<ConceptKnowledgeData> data = new List<ConceptKnowledgeData>();
            foreach (KeyValuePair<string, ConceptKnowledge> pair in _knowledge)
                data.Add(pair.Value.ToData());
            return data;
        }

        public void LoadData(List<ConceptKnowledgeData> data)
        {
            _knowledge.Clear();
            if (data == null) return;
            for (int i = 0; i < data.Count; i++)
            {
                ConceptKnowledge knowledge = ConceptKnowledge.FromData(data[i]);
                if (knowledge != null) _knowledge[knowledge.ConceptId] = knowledge;
            }
        }
    }
}
