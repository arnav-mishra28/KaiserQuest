using System;
using System.Collections.Generic;
using KaiserQuest.Knowledge;
using UnityEngine;

namespace KaiserQuest.Story
{
    /// <summary>One milestone: a place, a keeper, a trial, and the concepts it teaches.</summary>
    public class Milestone
    {
        public int Index;
        public string Id;
        public string Realm;
        public string Kind;
        public TrialMode Mode;
        public string Name;
        public string Place;
        public string Keeper;
        public string Domain;
        public string DomainName;
        public List<string> Concepts = new List<string>();
        public string Setup;
        public string Success;
        public string Failure;
        public float EntryGate = 60f;
        public float MasteryGate = 60f;

        public string BadgeName
        {
            get { return DomainName + " Sigil"; }
        }

        /// <summary>The name of the first concept this milestone introduces.</summary>
        public string FirstConceptName;

        public string TrialDescription
        {
            get { return Mode != null ? Mode.description : string.Empty; }
        }
    }

    /// <summary>The fixed twenty-step escalation, before any realm flavour is applied.</summary>
    public class MilestoneArchetype
    {
        public int Index;
        public string Kind;
        public string Mode;
        public string Title;
        public string Setup;
        public string Success;
        public string Failure;

        /// <summary>
        /// The mastery a milestone's concepts must hold for it to count as passed.
        /// It rises with the escalation on purpose: the initiation asks you to
        /// understand, the championship asks you to hold it.
        /// </summary>
        public float MasteryGate = 60f;
    }

    /// <summary>Names, places and keepers for one realm.</summary>
    public class RealmFlavor
    {
        public string Realm;
        public string Region;
        public string[] Places;
        public string[] Keepers;
        public string[] Names;

        public string Place(int index) { return Places[(index - 1) % Places.Length]; }
        public string Keeper(int index) { return Keepers[(index - 1) % Keepers.Length]; }
        public string Name(int index) { return Names[(index - 1) % Names.Length]; }
    }

    /// <summary>
    /// Builds the 20-milestone campaign for a realm from the concept graph.
    ///
    /// The arc is shared, the flavour is not. Concepts are apportioned across the
    /// twenty milestones in proportion to how many each domain actually has, so
    /// milestone 9 of Algebra tests exactly what the player has been taught by
    /// milestone 9. Add a concept to the graph and the campaign re-cuts itself; no
    /// concept can silently go untested.
    /// </summary>
    public static class MilestoneCatalog
    {
        public static readonly string[] ArcNames = new string[]
        {
            "First Light", "The Broken Village", "Duel of Wits", "Ruins of Reason",
            "The Open Tournament", "The Corrupted Record", "Trial of Proof", "The Long Climb",
            "Relay of Chapters", "The Midway Gauntlet", "Vault of Riddles", "The Craft Hall",
            "House of Errors", "Mastery Trial", "The Quickening", "The Tribunal",
            "Chain of Reason", "The Grand Tournament", "The Last Trial", "Knowledge Champion"
        };

        private static readonly string[] ArcKinds = new string[]
        {
            "initiation", "village_trial", "duel", "puzzle_ruins", "tournament", "investigation",
            "trial_of_proof", "endurance", "relay", "midpoint_gauntlet", "riddle_vault", "craft",
            "diagnosis", "mastery_trial", "speedrun", "tribunal", "chain", "grand_tournament",
            "final_mastery", "knowledge_champion"
        };

        private static readonly string[] ArcModes = new string[]
        {
            "guided", "applied", "timed", "reasoning", "tournament", "investigation",
            "reasoning", "gauntlet", "chain", "boss", "reasoning", "construct",
            "diagnosis", "boss", "timed", "investigation", "chain", "grand_tournament",
            "boss", "champion"
        };

        private static readonly float[] ArcGates = new float[]
        {
            45f, 50f, 60f, 60f, 60f, 60f, 60f, 60f, 60f, 70f,
            60f, 60f, 60f, 72f, 60f, 60f, 60f, 75f, 78f, 80f
        };

        private static readonly string[] ArcSetup = new string[]
        {
            "{keeper} finds you at {place} and does not ask you to prove anything yet. {keeper} only asks questions, and waits.",
            "The mechanisms that hold {place} together have seized. Nobody knows the values they were set to. {keeper} hands you the dials.",
            "A challenger steps out at {place} and says, flatly, that you are too slow.",
            "The old stones at {place} were built to reward the right reasoning, not the right guess. Several answers will seem to work. Only one is justified.",
            "Every traveller who has passed through {place} is entered in this bracket, and so are you. Everything you have learned is fair game.",
            "Something at {place} has been altered, and the alteration is sitting in plain sight. {keeper} says the evidence is in the numbers, if you look properly.",
            "At {place} it is not enough to be right. You must show the step that makes you right, and {keeper} will pick at it.",
            "There is no trick to the path out of {place}. It is long, and it gets harder the further you go. {keeper} warns you not to start tired.",
            "A chain of keepers waits along the road from {place}, each holding one link. Your answer becomes the next keeper's question.",
            "{keeper} has been watching you since the first step, and takes the field at {place} to find out what you actually kept.",
            "The vault at {place} opens for reasoning, never for answers. {keeper} has never seen it open on a lucky guess.",
            "{keeper} hands you the steps of a working thing, out of order, and asks you to build it.",
            "At {place}, every solution in the record has been broken in one specific way. {keeper} wants them found and named.",
            "{keeper} does not fence. {keeper} assembles a trial aimed exactly at what you have been getting wrong.",
            "At {place} the clock is shorter and the questions are not easier. {keeper} says fluency is what separates knowing from having known.",
            "A claim is put to you at {place}, and {keeper} is not on your side. Evidence from everything you have learned is the only thing that counts.",
            "This is the relay again, longer, and every link is drawn from a different part of the realm. {keeper} says a single weak link will find you out.",
            "The whole region gathers at {place}. This bracket is run at the highest standard the realm allows.",
            "{keeper} has been holding this one back. It is the hardest thing the realm has asked you to do, and it is built entirely from your own history.",
            "The realm puts its championship in front of you at {place}: every domain, every chapter, at the hardest level you can hold."
        };

        private static readonly string[] ArcSuccess = new string[]
        {
            "{keeper} nods. The first door of the realm opens on its own.",
            "The mechanism turns. {place} breathes again, and the road onward is open.",
            "The challenger concedes. Speed, it turns out, is a kind of knowing.",
            "The stones accept your reasoning and shift aside.",
            "You take the bracket. {keeper} is not surprised.",
            "You name the alteration. {keeper} looks at you differently now.",
            "{keeper} cannot fault the proof.",
            "You reach the top of the climb with nothing left. {keeper} meets you there.",
            "The chain holds all the way to the end.",
            "You hold. Nobody at {place} doubts you now.",
            "The vault opens. Whatever was locked behind it is yours.",
            "It works. You built it, which is different from recognising it.",
            "You find and name them all. {keeper} is impressed that you could name them.",
            "You clear it. The trial was aimed at your weaknesses and you did not have them any more.",
            "You finish with time left on the clock.",
            "You make the case and it holds.",
            "The whole chain holds, across every chapter of the realm.",
            "You win the Grand Tournament. {keeper} announces it to the region.",
            "You pass the last trial. {keeper} tells you there is a mountain.",
            "You are the Champion of the realm. The road to Silver Mountain is open."
        };

        private static readonly string[] ArcFailure = new string[]
        {
            "There is nothing to fail here. {keeper} simply explains it again.",
            "The dials hold firm. {keeper} walks you back through the idea before you try again.",
            "You lose on time, not on knowledge. {keeper} tells you so, and means it kindly.",
            "The stones reject a guess that would have been right by accident. Justify it next time.",
            "You fall in the middle of the bracket. Everything you have learned comes back for review.",
            "The clues do not assemble yet. {keeper} lays them out again for you.",
            "Your answer was right and your reasoning was not. That is not a pass. Try again.",
            "The climb beats you back down to {place}. Rest, and start again.",
            "The chain breaks. A mistake early makes the later links unsolvable \u2014 that is the lesson.",
            "You are sent back to the last place you rested, with the order given cleanly: learn it, then come back.",
            "The vault stays shut. It is not being unfair; it is being exact.",
            "It does not work yet, and {keeper} shows you precisely which step you misplaced.",
            "You found the wrong errors. Knowing how something is broken is half of knowing how it works.",
            "The trial found the gaps. That is its job, and it will find them again.",
            "The clock wins. {keeper} says this is only a speed problem, and speed is trainable.",
            "The claim defeats your evidence. {keeper} shows you which part did not hold up.",
            "One link failed and the chain came apart. {keeper} shows you exactly which one.",
            "You do not take the bracket. {keeper} suggests you spend time on your weakest chapter.",
            "Not yet. {keeper} tells you what to revisit, precisely, and sends you back.",
            "The championship is not yours yet. {keeper} will keep the title in trust."
        };

        private static readonly Dictionary<string, RealmFlavor> Flavors = BuildFlavors();

        public static RealmFlavor FlavorFor(string realmId)
        {
            RealmFlavor flavor;
            return Flavors.TryGetValue(realmId, out flavor) ? flavor : null;
        }

        public static List<Milestone> Build(ConceptGraph graph, string realmId)
        {
            List<Milestone> milestones = new List<Milestone>();
            RealmData realm = graph != null ? graph.Realm(realmId) : null;
            RealmFlavor flavor = FlavorFor(realmId);
            if (realm == null || flavor == null || realm.domains == null)
            {
                Debug.LogError("[MilestoneCatalog] Cannot build campaign for realm '" + realmId + "'");
                return milestones;
            }

            // Slots in authored curriculum order. The order the domains are declared
            // in the graph IS the curriculum order, and the client cannot verify that,
            // so the pipeline asserts it server-side.
            List<ConceptData> slots = new List<ConceptData>();
            for (int d = 0; d < realm.domains.Count; d++)
            {
                DomainData domain = realm.domains[d];
                if (domain == null || domain.concepts == null) continue;
                for (int c = 0; c < domain.concepts.Count; c++) slots.Add(domain.concepts[c]);
            }

            if (slots.Count < ArcNames.Length)
            {
                Debug.LogError("[MilestoneCatalog] Realm '" + realmId + "' has only " + slots.Count
                               + " concepts, too few to fill " + ArcNames.Length + " milestones.");
                return milestones;
            }

            List<int> allocation = Apportion(CountsPerDomain(realm), ArcNames.Length, 1);
            List<List<ConceptData>> chunks = SplitEvenly(slots, ArcNames.Length);

            for (int i = 0; i < ArcNames.Length; i++)
            {
                Milestone milestone = new Milestone();
                int index = i + 1;
                milestone.Index = index;
                milestone.Id = realmId + ".m" + index.ToString("00");
                milestone.Realm = realmId;
                milestone.Kind = ArcKinds[i];
                milestone.Mode = TrialModes.Get(ArcModes[i]);
                milestone.Name = flavor.Name(index);
                milestone.Place = flavor.Place(index);
                milestone.Keeper = flavor.Keeper(index);

                List<ConceptData> chunk = chunks[i];
                for (int c = 0; c < chunk.Count; c++) milestone.Concepts.Add(chunk[c].id);
                milestone.Domain = chunk.Count > 0 ? chunk[0].domain : string.Empty;
                DomainData domain = graph.Domain(milestone.Domain);
                milestone.DomainName = domain != null ? domain.name : milestone.Domain;
                milestone.FirstConceptName = chunk.Count > 0 ? chunk[0].name : string.Empty;

                milestone.Setup = Fill(ArcSetup[i], milestone);
                milestone.Success = Fill(ArcSuccess[i], milestone);
                milestone.Failure = Fill(ArcFailure[i], milestone);
                milestone.MasteryGate = ArcGates[i];
                milestone.EntryGate = EntryGateFor(ArcGates[i]);

                milestones.Add(milestone);
            }

            // The allocation is only used to sanity-check the cut; the cut itself is
            // contiguous over the curriculum so no concept is skipped or repeated.
            int allocated = 0;
            for (int i = 0; i < allocation.Count; i++) allocated += allocation[i];
            if (allocated != ArcNames.Length)
                Debug.LogWarning("[MilestoneCatalog] Apportionment sums to " + allocated + ", not " + ArcNames.Length);

            return milestones;
        }

        /// <summary>Mastery required to enter the milestone after this one.</summary>
        public static float EntryGateFor(float masteryGate)
        {
            return Mathf.Max(35f, masteryGate - 10f);
        }

        private static string Fill(string template, Milestone milestone)
        {
            return template
                .Replace("{place}", milestone.Place)
                .Replace("{keeper}", milestone.Keeper)
                .Replace("{domain}", milestone.DomainName)
                .Replace("{concept}", milestone.FirstConceptName ?? string.Empty);
        }

        private static List<int> CountsPerDomain(RealmData realm)
        {
            List<int> counts = new List<int>();
            for (int d = 0; d < realm.domains.Count; d++)
            {
                DomainData domain = realm.domains[d];
                counts.Add(domain != null && domain.concepts != null ? domain.concepts.Count : 0);
            }
            return counts;
        }

        /// <summary>
        /// Hamilton's largest-remainder apportionment; always sums exactly to `total`.
        /// Keeps the split proportional to how much there actually is to learn in each
        /// domain, while giving every domain at least one milestone.
        /// </summary>
        public static List<int> Apportion(List<int> counts, int total, int minimum = 1)
        {
            List<int> result = new List<int>();
            if (counts == null || counts.Count == 0) return result;

            int n = counts.Count;
            for (int i = 0; i < n; i++) result.Add(minimum);

            int remaining = total - minimum * n;
            if (remaining <= 0) return result;

            int totalCount = 0;
            for (int i = 0; i < n; i++) totalCount += counts[i];
            if (totalCount <= 0) totalCount = n;

            List<float> quotas = new List<float>();
            List<int> baseValues = new List<int>();
            for (int i = 0; i < n; i++)
            {
                float quota = (float)remaining * counts[i] / totalCount;
                quotas.Add(quota);
                baseValues.Add((int)quota);
                result[i] += (int)quota;
            }

            int assigned = 0;
            for (int i = 0; i < n; i++) assigned += result[i];
            int leftover = total - assigned;

            List<int> order = new List<int>();
            for (int i = 0; i < n; i++) order.Add(i);
            order.Sort(delegate (int a, int b)
            {
                return (quotas[b] - baseValues[b]).CompareTo(quotas[a] - baseValues[a]);
            });
            for (int i = 0; i < leftover && i < order.Count; i++) result[order[i]]++;

            return result;
        }

        /// <summary>Cut a sequence into `groups` contiguous chunks as evenly as possible.</summary>
        public static List<List<T>> SplitEvenly<T>(List<T> items, int groups)
        {
            List<List<T>> chunks = new List<List<T>>();
            if (items == null || groups <= 0) return chunks;
            if (groups >= items.Count)
            {
                for (int i = 0; i < items.Count; i++) chunks.Add(new List<T> { items[i] });
                return chunks;
            }

            int size = items.Count / groups;
            int extra = items.Count % groups;
            int start = 0;
            for (int i = 0; i < groups; i++)
            {
                int length = size + (i < extra ? 1 : 0);
                List<T> chunk = new List<T>();
                for (int j = 0; j < length; j++) chunk.Add(items[start + j]);
                chunks.Add(chunk);
                start += length;
            }
            return chunks;
        }

        /// <summary>Every concept taught by milestone `index` and all before it.</summary>
        public static List<string> ConceptsThrough(List<Milestone> milestones, int index)
        {
            List<string> seen = new List<string>();
            for (int i = 0; i < milestones.Count && milestones[i].Index <= index; i++)
            {
                for (int c = 0; c < milestones[i].Concepts.Count; c++)
                {
                    if (!seen.Contains(milestones[i].Concepts[c])) seen.Add(milestones[i].Concepts[c]);
                }
            }
            return seen;
        }

        public static Milestone ForConcept(List<Milestone> milestones, string conceptId)
        {
            for (int i = 0; i < milestones.Count; i++)
            {
                if (milestones[i].Concepts.Contains(conceptId)) return milestones[i];
            }
            return null;
        }

        public static Milestone FirstUnpassed(List<Milestone> milestones, ICollection<int> passed)
        {
            for (int i = 0; i < milestones.Count; i++)
            {
                if (passed == null || !passed.Contains(milestones[i].Index)) return milestones[i];
            }
            return milestones.Count > 0 ? milestones[milestones.Count - 1] : null;
        }

        private static Dictionary<string, RealmFlavor> BuildFlavors()
        {
            Dictionary<string, RealmFlavor> flavors = new Dictionary<string, RealmFlavor>();

            flavors["algebra"] = MakeFlavor(
                "algebra",
                "Kaiserland \u2014 the Numeric Marches",
                new string[]
                {
                    "Aster Town", "the stone bridge over the Axiom", "Equaton",
                    "the Ruins of the Variable", "Functionburg", "the Ledger House",
                    "Graphton", "the Long Climb", "Polynova", "Quadralis",
                    "the Vault of Riddles", "the Craft Hall", "the House of Errors",
                    "Prosdia", "the Quickening Fields", "the Tribunal Hall",
                    "the Chain Road", "the Grand Coliseum", "the Last Gate",
                    "the Champion's Court"
                },
                new string[]
                {
                    "Keeper Veran", "Keeper Solis", "the Duelist Brek", "Keeper Halla",
                    "the Challenger Ondo", "Inspector Maro", "the Prover Tessa",
                    "Keeper Rufus", "the Relay-Master Ilo", "Gauntlet-Lord Sabin",
                    "the Vault Keeper Nia", "the Craftsman Duro", "the Diagnostician Pell",
                    "Trial-Master Osric", "the Quickening Judge", "the Advocate Rell",
                    "the Chain-Keeper Yune", "Grandmaster Castor", "Arch-Trialist Vex",
                    "the Champion Arbiter"
                },
                new string[]
                {
                    "The First Unknown", "The Broken Bridge", "Duel of Wits",
                    "Ruins of the Variable", "The Open Tournament", "The Corrupted Ledger",
                    "Trial of Proof", "The Long Climb", "Relay of Chapters",
                    "The Midway Gauntlet", "Vault of Riddles", "The Craft Hall",
                    "House of Errors", "Mastery Trial", "The Quickening",
                    "The Tribunal", "Chain of Reason", "The Grand Tournament",
                    "The Last Trial", "Champion of Algebra"
                });

            flavors["english"] = MakeFlavor(
                "english",
                "Kaiserland \u2014 the Plain of Tongues",
                new string[]
                {
                    "Aster Town", "the Mended Message Inn", "Eloqua", "the Ruins of the Sentence",
                    "the Tongue-Mart", "the Scriptorium", "Inkfield", "the Long Climb",
                    "the Relay Road", "the Halfway Hall", "the Vault of Riddles",
                    "the Scriptorium Deep", "the House of Misprints", "the Court of Register",
                    "the Quickening Quill", "the Tribunal of Evidence", "the Chain Road",
                    "the Grand Amphitheatre", "the Last Page", "the Champion's Reading Room"
                },
                new string[]
                {
                    "Keeper Ilyse", "the Innkeep Bron", "the Duelist Cato", "Keeper Nara",
                    "the Challenger Vero", "Inspector Quill", "the Prover Melis",
                    "Keeper Dunne", "the Relay-Master Aul", "Gauntlet-Lady Sable",
                    "the Vault Keeper Oris", "the Scribe Delver", "the Diagnostician Ferro",
                    "Trial-Master Ysolde", "the Quickening Judge", "the Advocate Corvin",
                    "the Chain-Keeper Muse", "Grandmaster Thale", "Arch-Trialist Wren",
                    "the Champion Arbiter"
                },
                new string[]
                {
                    "First Words", "The Mended Message", "Duel of Wits",
                    "Ruins of the Sentence", "The Open Tournament", "The Corrupted Letter",
                    "Trial of Proof", "The Long Climb", "Relay of Chapters",
                    "The Midway Gauntlet", "Vault of Riddles", "The Scriptorium",
                    "House of Misprints", "Mastery Trial", "The Quickening",
                    "The Tribunal", "Chain of Reason", "The Grand Tournament",
                    "The Last Page", "Champion of English"
                });

            flavors["music"] = MakeFlavor(
                "music",
                "Kaiserland \u2014 the Resonant Valleys",
                new string[]
                {
                    "Aster Town", "the Dissonant Village", "Fortissimo", "the Ruins of the Scale",
                    "the Song-Market", "the Composer's Hall", "Chordwell", "the Long Climb",
                    "the Relay Road", "the Halfway Concert Hall", "the Vault of Riddles",
                    "the Craft Hall of Instruments", "the House of Wrong Notes",
                    "the Court of Cadence", "the Quickening Stage", "the Tribunal of Ears",
                    "the Chain Road", "the Grand Amphitheatre", "the Last Chord",
                    "the Champion's Podium"
                },
                new string[]
                {
                    "Keeper Doremi", "the Village Fiddler", "the Duelist Kaba", "Keeper Lyra",
                    "the Challenger Osta", "Inspector Tone", "the Prover Mira",
                    "Keeper Ghent", "the Relay-Master Ansa", "Gauntlet-Lord Rezo",
                    "the Vault Keeper Faun", "the Instrument-Maker Bela", "the Diagnostician Coda",
                    "Trial-Master Vesper", "the Quickening Judge", "the Advocate Aria",
                    "the Chain-Keeper Orin", "Grandmaster Maestro", "Arch-Trialist Seris",
                    "the Champion Arbiter"
                },
                new string[]
                {
                    "First Sound", "The Dissonant Village", "Duel of Wits",
                    "Ruins of the Scale", "The Open Tournament", "The Corrupted Score",
                    "Trial of Proof", "The Long Climb", "Relay of Chapters",
                    "The Midway Gauntlet", "Vault of Riddles", "The Composer's Hall",
                    "House of Wrong Notes", "Mastery Trial", "The Quickening",
                    "The Tribunal", "Chain of Reason", "The Grand Tournament",
                    "The Last Chord", "Champion of Music"
                });

            return flavors;
        }

        private static RealmFlavor MakeFlavor(
            string realm, string region, string[] places, string[] keepers, string[] names)
        {
            RealmFlavor flavor = new RealmFlavor();
            flavor.Realm = realm;
            flavor.Region = region;
            flavor.Places = places;
            flavor.Keepers = keepers;
            flavor.Names = names;
            return flavor;
        }
    }
}
