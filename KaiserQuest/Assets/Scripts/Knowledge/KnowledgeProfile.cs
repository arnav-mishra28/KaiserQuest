using System;
using System.Collections.Generic;
using System.Text;

namespace KaiserQuest.Knowledge
{
    /// <summary>One concept, as the profile presents it.</summary>
    public class ConceptView
    {
        public string Id;
        public string Name;
        public string Domain;
        public float Mastery;
        public string Confidence;
        public float PKnown;
        public int Attempts;
        public float Accuracy;
        public float Retention;
        public bool IsMastered;
        public bool IsRusty;
        public int DifficultyCeiling;
    }

    /// <summary>One domain, rolled up.</summary>
    public class DomainView
    {
        public string Id;
        public string Name;
        public float Mastery;
        public List<ConceptView> Concepts = new List<ConceptView>();
    }

    /// <summary>
    /// The knowledge profile: what the player knows, forgets, confuses and is ready
    /// for. A pure aggregator over a KnowledgeTracer and an AttemptLog, and the
    /// object every screen in the game reads from.
    /// </summary>
    public class KnowledgeProfile
    {
        public const float ForgettingRiskRetention = 0.55f;

        public string PlayerId;
        public string RealmId;
        public KnowledgeTracer Tracer;
        public AttemptLog Log;
        public ConceptGraph Graph;
        public MisconceptionDetector Detector;

        public KnowledgeProfile(
            string playerId,
            string realmId,
            KnowledgeTracer tracer,
            AttemptLog log,
            ConceptGraph graph,
            MisconceptionDetector detector)
        {
            PlayerId = playerId;
            RealmId = realmId;
            Tracer = tracer;
            Log = log ?? new AttemptLog();
            Graph = graph;
            Detector = detector;
        }

        // ------------------------------------------------------------------
        // Concept level
        // ------------------------------------------------------------------
        public ConceptView ConceptViewOf(string conceptId)
        {
            ConceptData concept = Graph.Concept(conceptId);
            ConceptKnowledge knowledge = Tracer.Get(conceptId);

            ConceptView view = new ConceptView();
            view.Id = conceptId;
            view.Name = concept != null ? concept.name : conceptId;
            view.Domain = concept != null ? concept.domain : string.Empty;
            view.Mastery = knowledge.Mastery();
            view.Confidence = knowledge.Confidence();
            view.PKnown = knowledge.PKnownNow();
            view.Attempts = knowledge.Attempts;
            view.Accuracy = knowledge.Attempts > 0 ? (float)Math.Round((float)knowledge.Correct / knowledge.Attempts, 4) : 0f;
            view.Retention = (float)Math.Round(knowledge.Retention(), 4);
            view.IsMastered = knowledge.IsMastered;
            view.IsRusty = knowledge.IsRusty;
            view.DifficultyCeiling = knowledge.DifficultyCeiling;
            return view;
        }

        // ------------------------------------------------------------------
        // Domain roll-ups
        // ------------------------------------------------------------------
        /// <summary>
        /// Mean mastery across every concept in the domain. Unseen concepts count as
        /// zero on purpose: a domain is only known to the extent you know all of it,
        /// and it keeps the number comparable between domains.
        /// </summary>
        public float DomainScore(string domainId)
        {
            List<ConceptData> concepts = Graph.ConceptsOfDomain(domainId);
            if (concepts.Count == 0) return 0f;
            float total = 0f;
            for (int i = 0; i < concepts.Count; i++) total += Tracer.Get(concepts[i].id).Mastery();
            return (float)Math.Round(total / concepts.Count, 2);
        }

        public List<DomainView> Domains()
        {
            List<DomainView> result = new List<DomainView>();
            RealmData realm = Graph.Realm(RealmId);
            if (realm == null || realm.domains == null) return result;

            for (int d = 0; d < realm.domains.Count; d++)
            {
                DomainData domain = realm.domains[d];
                if (domain == null) continue;
                DomainView view = new DomainView();
                view.Id = domain.id;
                view.Name = domain.name;
                view.Mastery = DomainScore(domain.id);
                if (domain.concepts != null)
                {
                    for (int c = 0; c < domain.concepts.Count; c++)
                        view.Concepts.Add(ConceptViewOf(domain.concepts[c].id));
                }
                result.Add(view);
            }
            return result;
        }

        public float OverallMastery
        {
            get { return Tracer.RealmMastery(RealmId); }
        }

        /// <summary>
        /// Percentage of the realm's concepts in each bucket. Untouched concepts count
        /// as Weak, which is the point of the display: it shrinks as you work.
        /// </summary>
        public Dictionary<string, int> ConfidenceDistribution()
        {
            Dictionary<string, int> counts = new Dictionary<string, int>();
            counts["Strong"] = 0;
            counts["Moderate"] = 0;
            counts["Weak"] = 0;

            List<ConceptData> concepts = Graph.ConceptsOfRealm(RealmId);
            if (concepts.Count == 0) return counts;

            for (int i = 0; i < concepts.Count; i++)
                counts[Tracer.Get(concepts[i].id).Confidence()]++;

            // Largest-remainder rounding so the three buckets always total 100.
            List<string> keys = new List<string> { "Strong", "Moderate", "Weak" };
            Dictionary<string, float> exact = new Dictionary<string, float>();
            Dictionary<string, int> floored = new Dictionary<string, int>();
            int assigned = 0;
            for (int i = 0; i < keys.Count; i++)
            {
                float value = 100f * counts[keys[i]] / concepts.Count;
                exact[keys[i]] = value;
                floored[keys[i]] = (int)value;
                assigned += (int)value;
            }

            List<string> order = new List<string>(keys);
            order.Sort(delegate (string a, string b)
            {
                return (exact[b] - floored[b]).CompareTo(exact[a] - floored[a]);
            });
            int remainder = 100 - assigned;
            for (int i = 0; i < remainder && i < order.Count; i++) floored[order[i]]++;

            return floored;
        }

        public List<ConceptView> WeakConcepts(float threshold = 60f, int limit = 10)
        {
            List<ConceptView> views = AttemptedViews();
            List<ConceptView> weak = new List<ConceptView>();
            for (int i = 0; i < views.Count; i++)
            {
                if (views[i].Mastery < threshold) weak.Add(views[i]);
            }
            weak.Sort(delegate (ConceptView a, ConceptView b)
            {
                int mastery = a.Mastery.CompareTo(b.Mastery);
                return mastery != 0 ? mastery : b.Attempts.CompareTo(a.Attempts);
            });
            Trim(weak, limit);
            return weak;
        }

        public List<ConceptView> StrongConcepts(int limit = 10)
        {
            List<ConceptView> views = AttemptedViews();
            List<ConceptView> strong = new List<ConceptView>();
            for (int i = 0; i < views.Count; i++)
            {
                if (views[i].Mastery >= 80f) strong.Add(views[i]);
            }
            strong.Sort(delegate (ConceptView a, ConceptView b) { return b.Mastery.CompareTo(a.Mastery); });
            Trim(strong, limit);
            return strong;
        }

        /// <summary>Learned properly once, decaying now. The most actionable list here.</summary>
        public List<ConceptView> RustyConcepts()
        {
            List<ConceptView> result = new List<ConceptView>();
            List<string> rusty = Tracer.RustyConcepts();
            for (int i = 0; i < rusty.Count; i++)
            {
                if (!Tracer.IsInRealm(rusty[i], RealmId)) continue;
                result.Add(ConceptViewOf(rusty[i]));
            }
            return result;
        }

        /// <summary>
        /// Known but with poor retention: the "what you have forgotten" feed. Narrower
        /// than rusty — still above the mastery bar but visibly slipping.
        /// </summary>
        public List<ConceptView> ForgettingRisk(int limit = 8)
        {
            List<ConceptView> views = AttemptedViews();
            List<ConceptView> atRisk = new List<ConceptView>();
            for (int i = 0; i < views.Count; i++)
            {
                ConceptView view = views[i];
                if (view.Attempts >= 3 && view.PKnown >= ConceptKnowledge.MasteredPKnown
                    && view.Retention < ForgettingRiskRetention)
                {
                    atRisk.Add(view);
                }
            }
            atRisk.Sort(delegate (ConceptView a, ConceptView b) { return a.Retention.CompareTo(b.Retention); });
            Trim(atRisk, limit);
            return atRisk;
        }

        /// <summary>What to learn next, with the reason attached.</summary>
        public List<KeyValuePair<string, string>> NextUp(int limit = 5)
        {
            List<KeyValuePair<string, string>> result = new List<KeyValuePair<string, string>>();
            if (Graph == null) return result;

            HashSet<string> known = new HashSet<string>(Tracer.KnownConcepts());
            List<string> frontier = Graph.Frontier(known, RealmId);
            List<ConceptData> ordered = new List<ConceptData>();
            for (int i = 0; i < frontier.Count; i++)
            {
                ConceptData concept = Graph.Concept(frontier[i]);
                if (concept != null) ordered.Add(concept);
            }
            ordered.Sort(delegate (ConceptData a, ConceptData b)
            {
                int level = a.level.CompareTo(b.level);
                return level != 0 ? level : string.CompareOrdinal(a.domain, b.domain);
            });

            for (int i = 0; i < ordered.Count && result.Count < limit; i++)
            {
                result.Add(new KeyValuePair<string, string>(
                    ordered[i].name, "All prerequisites are mastered \u2014 this is ready to teach."));
            }

            List<string> rusty = Tracer.RustyConcepts();
            for (int i = 0; i < rusty.Count && result.Count < limit; i++)
            {
                if (!Tracer.IsInRealm(rusty[i], RealmId)) continue;
                ConceptData concept = Graph.Concept(rusty[i]);
                if (concept == null) continue;
                result.Add(new KeyValuePair<string, string>(
                    concept.name, "Learned before but faded \u2014 a short recap brings it back."));
            }
            return result;
        }

        public List<Detection> Misconceptions(int limit = 6)
        {
            AttemptLog scoped = new AttemptLog();
            for (int i = 0; i < Log.All.Count; i++)
            {
                if (Tracer.IsInRealm(Log.All[i].concept, RealmId)) scoped.Add(Log.All[i]);
            }
            return Detector.Summarize(scoped, null, limit);
        }

        public List<RemedyStep> MisconceptionPlan(int limit = 5)
        {
            List<Detection> detections = Misconceptions(limit);
            return Detector.RemedyPlan(detections);
        }

        // ------------------------------------------------------------------
        // Rendering
        // ------------------------------------------------------------------
        /// <summary>The profile exactly as the design document draws it.</summary>
        public string RenderAscii()
        {
            StringBuilder builder = new StringBuilder();
            RealmData realm = Graph.Realm(RealmId);
            string realmName = realm != null ? realm.name : RealmId;

            builder.Append(realmName).Append(" \u2014 ").Append((int)OverallMastery).Append("% overall\n\n");

            List<DomainView> domains = Domains();
            int width = 0;
            for (int i = 0; i < domains.Count; i++)
                if (domains[i].Name.Length > width) width = domains[i].Name.Length;

            for (int i = 0; i < domains.Count; i++)
            {
                builder.Append(i == domains.Count - 1 ? "\u2514\u2500\u2500 " : "\u251c\u2500\u2500 ")
                       .Append(domains[i].Name)
                       .Append(' ')
                       .Append(Dots(Math.Max(3, width - domains[i].Name.Length + 2)))
                       .Append(' ')
                       .Append(((int)domains[i].Mastery).ToString().PadLeft(3))
                       .Append("%\n");
            }

            builder.Append("\nConfidence\n");
            Dictionary<string, int> buckets = ConfidenceDistribution();
            List<string> keys = new List<string> { "Strong", "Moderate", "Weak" };
            for (int i = 0; i < keys.Count; i++)
            {
                builder.Append(i == keys.Count - 1 ? "\u2514\u2500\u2500 " : "\u251c\u2500\u2500 ")
                       .Append(keys[i])
                       .Append(' ')
                       .Append(Dots(Math.Max(3, 12 - keys[i].Length + 2)))
                       .Append(' ')
                       .Append(buckets[keys[i]].ToString().PadLeft(3))
                       .Append("%\n");
            }

            List<ConceptView> rusty = RustyConcepts();
            if (rusty.Count > 0)
            {
                builder.Append("\nForgotten / fading\n");
                for (int i = 0; i < rusty.Count && i < 5; i++)
                {
                    builder.Append("\u251c\u2500\u2500 ").Append(rusty[i].Name)
                           .Append(" (").Append((int)rusty[i].Mastery).Append("%, ")
                           .Append((int)(rusty[i].Retention * 100)).Append("% retained)\n");
                }
            }

            List<RemedyStep> plan = MisconceptionPlan();
            if (plan.Count > 0)
            {
                builder.Append("\nNamed misconceptions\n");
                for (int i = 0; i < plan.Count && i < 5; i++)
                {
                    builder.Append("\u251c\u2500\u2500 ").Append(plan[i].Name)
                           .Append(" \u2014 seen ").Append(plan[i].Occurrences).Append("\u00d7\n");
                    builder.Append("\u2502     remedy: ").Append(plan[i].Remedy).Append('\n');
                }
            }
            return builder.ToString();
        }

        private static string Dots(int count)
        {
            return new string('.', Math.Max(1, count));
        }

        private List<ConceptView> AttemptedViews()
        {
            List<ConceptView> views = new List<ConceptView>();
            List<ConceptData> concepts = Graph.ConceptsOfRealm(RealmId);
            for (int i = 0; i < concepts.Count; i++)
            {
                if (Tracer.Get(concepts[i].id).Attempts <= 0) continue;
                views.Add(ConceptViewOf(concepts[i].id));
            }
            return views;
        }

        private static void Trim<T>(List<T> list, int limit)
        {
            if (limit > 0 && list.Count > limit) list.RemoveRange(limit, list.Count - limit);
        }
    }
}
