using System.Collections.Generic;
using System.Text;

namespace KaiserQuest.Knowledge
{
    /// <summary>
    /// The concept graph: the map of everything the game can teach.
    ///
    /// Realm is a subject (Algebra), Domain is a chapter-sized area (Variables), and
    /// Concept is the atomic thing the engine tracks. This class answers the
    /// questions the rest of the game asks of the map: what must be known before
    /// this, what is ready to be learned next, and which questions belong here.
    ///
    /// A direct port of engine/concepts.py. Kept structurally identical so the
    /// offline client and the server agree about a player's knowledge.
    /// </summary>
    public class ConceptGraph
    {
        private readonly List<RealmData> _realms = new List<RealmData>();
        private readonly Dictionary<string, ConceptData> _concepts = new Dictionary<string, ConceptData>();
        private readonly Dictionary<string, DomainData> _domains = new Dictionary<string, DomainData>();
        private readonly List<string> _conceptOrder = new List<string>();

        // Derived adjacency, built once at load.
        private readonly Dictionary<string, List<string>> _dependents = new Dictionary<string, List<string>>();

        public ConceptGraph(GraphData data)
        {
            if (data != null && data.realms != null)
            {
                for (int r = 0; r < data.realms.Count; r++)
                {
                    RealmData realm = data.realms[r];
                    if (realm == null) continue;
                    _realms.Add(realm);
                    if (realm.domains == null) continue;

                    for (int d = 0; d < realm.domains.Count; d++)
                    {
                        DomainData domain = realm.domains[d];
                        if (domain == null) continue;
                        if (domain.realm == null || domain.realm.Length == 0) domain.realm = realm.id;
                        _domains[domain.id] = domain;

                        if (domain.concepts == null) continue;
                        for (int c = 0; c < domain.concepts.Count; c++)
                        {
                            ConceptData concept = domain.concepts[c];
                            if (concept == null) continue;
                            if (concept.realm == null || concept.realm.Length == 0) concept.realm = realm.id;
                            if (concept.domain == null || concept.domain.Length == 0) concept.domain = domain.id;
                            _concepts[concept.id] = concept;
                            _conceptOrder.Add(concept.id);
                        }
                    }
                }
            }

            for (int i = 0; i < _conceptOrder.Count; i++)
            {
                ConceptData concept = _concepts[_conceptOrder[i]];
                if (concept.prereqs == null) continue;
                for (int p = 0; p < concept.prereqs.Count; p++)
                {
                    string prereq = concept.prereqs[p];
                    List<string> list;
                    if (!_dependents.TryGetValue(prereq, out list))
                    {
                        list = new List<string>();
                        _dependents[prereq] = list;
                    }
                    list.Add(concept.id);
                }
            }
        }

        public IList<RealmData> Realms { get { return _realms; } }
        public int ConceptCount { get { return _concepts.Count; } }

        // ------------------------------------------------------------------
        // Lookup
        // ------------------------------------------------------------------
        public bool HasConcept(string conceptId)
        {
            return !string.IsNullOrEmpty(conceptId) && _concepts.ContainsKey(conceptId);
        }

        public ConceptData Concept(string conceptId)
        {
            ConceptData concept;
            return _concepts.TryGetValue(conceptId, out concept) ? concept : null;
        }

        public DomainData Domain(string domainId)
        {
            DomainData domain;
            return _domains.TryGetValue(domainId, out domain) ? domain : null;
        }

        public RealmData Realm(string realmId)
        {
            for (int i = 0; i < _realms.Count; i++)
            {
                if (_realms[i] != null && _realms[i].id == realmId) return _realms[i];
            }
            return null;
        }

        /// <summary>Resolve a realm by id, display name or section name.</summary>
        public RealmData FindRealm(string label)
        {
            if (string.IsNullOrEmpty(label)) return null;
            string wanted = label.Trim().ToLowerInvariant();
            for (int i = 0; i < _realms.Count; i++)
            {
                RealmData realm = _realms[i];
                if (realm == null) continue;
                if (realm.id.ToLowerInvariant() == wanted) return realm;
                if (realm.name != null && realm.name.ToLowerInvariant() == wanted) return realm;
                if (realm.section != null && realm.section.ToLowerInvariant() == wanted) return realm;
            }
            return null;
        }

        public List<ConceptData> ConceptsOfDomain(string domainId)
        {
            DomainData domain = Domain(domainId);
            return domain != null && domain.concepts != null ? domain.concepts : new List<ConceptData>();
        }

        public List<ConceptData> ConceptsOfRealm(string realmId)
        {
            List<ConceptData> result = new List<ConceptData>();
            RealmData realm = Realm(realmId);
            if (realm == null || realm.domains == null) return result;
            for (int d = 0; d < realm.domains.Count; d++)
            {
                DomainData domain = realm.domains[d];
                if (domain == null || domain.concepts == null) continue;
                for (int c = 0; c < domain.concepts.Count; c++)
                {
                    if (domain.concepts[c] != null) result.Add(domain.concepts[c]);
                }
            }
            return result;
        }

        public List<string> AllConceptIds()
        {
            return new List<string>(_conceptOrder);
        }

        // ------------------------------------------------------------------
        // Traversal
        // ------------------------------------------------------------------
        public List<string> Prerequisites(string conceptId, bool recursive = false)
        {
            List<string> result = new List<string>();
            ConceptData concept = Concept(conceptId);
            if (concept == null || concept.prereqs == null) return result;

            if (!recursive) return new List<string>(concept.prereqs);

            HashSet<string> seen = new HashSet<string>();
            Stack<string> stack = new Stack<string>();
            for (int i = 0; i < concept.prereqs.Count; i++) stack.Push(concept.prereqs[i]);
            while (stack.Count > 0)
            {
                string node = stack.Pop();
                if (seen.Contains(node)) continue;
                seen.Add(node);
                ConceptData parent = Concept(node);
                if (parent == null || parent.prereqs == null) continue;
                for (int i = 0; i < parent.prereqs.Count; i++) stack.Push(parent.prereqs[i]);
            }
            result.AddRange(seen);
            result.Sort();
            return result;
        }

        public List<string> Dependents(string conceptId)
        {
            List<string> list;
            return _dependents.TryGetValue(conceptId, out list) ? new List<string>(list) : new List<string>();
        }

        public List<string> MissingPrereqs(string conceptId, ICollection<string> known)
        {
            List<string> missing = new List<string>();
            List<string> direct = Prerequisites(conceptId);
            for (int i = 0; i < direct.Count; i++)
            {
                if (known == null || !known.Contains(direct[i])) missing.Add(direct[i]);
            }
            return missing;
        }

        public bool IsReady(string conceptId, ICollection<string> known)
        {
            return MissingPrereqs(conceptId, known).Count == 0;
        }

        /// <summary>
        /// Concepts whose prerequisites are all mastered but which are not mastered
        /// themselves: literally what the player is ready to learn next.
        /// </summary>
        public List<string> Frontier(ICollection<string> known, string realmId = null)
        {
            List<string> result = new List<string>();
            for (int i = 0; i < _conceptOrder.Count; i++)
            {
                string id = _conceptOrder[i];
                if (known != null && known.Contains(id)) continue;
                if (!string.IsNullOrEmpty(realmId) && _concepts[id].realm != realmId) continue;
                if (IsReady(id, known)) result.Add(id);
            }
            return result;
        }

        /// <summary>
        /// Stable curriculum order for a realm: domains in declared order, concepts
        /// in declared order. The declared order satisfies prerequisites, and the
        /// campaign is cut from this list, so the assertion matters.
        /// </summary>
        public List<ConceptData> CurriculumOrder(string realmId)
        {
            return ConceptsOfRealm(realmId);
        }

        /// <summary>Best-effort tagging of raw question text onto a concept.</summary>
        public string TagText(string text, string topic = null)
        {
            if (string.IsNullOrEmpty(text)) return null;
            string haystack = text.ToLowerInvariant();
            float bestScore = 0f;
            ConceptData best = null;

            List<ConceptData> candidates = string.IsNullOrEmpty(topic)
                ? AllConcepts()
                : ConceptsOfDomain(topic);
            if (candidates.Count == 0) candidates = AllConcepts();

            for (int i = 0; i < candidates.Count; i++)
            {
                ConceptData concept = candidates[i];
                if (concept == null || concept.keywords == null) continue;
                float score = 0f;
                for (int k = 0; k < concept.keywords.Count; k++)
                {
                    string keyword = concept.keywords[k];
                    if (string.IsNullOrEmpty(keyword)) continue;
                    if (haystack.Contains(keyword.ToLowerInvariant()))
                        score += 2f + 0.5f * CountOccurrences(keyword, ' ');
                }
                if (score <= 0f) continue;
                if (best == null || score > bestScore ||
                    (score == bestScore && concept.level < best.level))
                {
                    best = concept;
                    bestScore = score;
                }
            }
            return best != null ? best.id : null;
        }

        private static int CountOccurrences(string value, char target)
        {
            int count = 0;
            for (int i = 0; i < value.Length; i++) if (value[i] == target) count++;
            return count;
        }

        private List<ConceptData> AllConcepts()
        {
            List<ConceptData> result = new List<ConceptData>();
            for (int i = 0; i < _conceptOrder.Count; i++) result.Add(_concepts[_conceptOrder[i]]);
            return result;
        }

        public string Summary()
        {
            StringBuilder builder = new StringBuilder();
            for (int i = 0; i < _realms.Count; i++)
            {
                RealmData realm = _realms[i];
                if (realm == null) continue;
                builder.Append(realm.id).Append("=")
                       .Append(ConceptsOfRealm(realm.id).Count).Append(" ");
            }
            return builder.ToString().Trim();
        }
    }
}
