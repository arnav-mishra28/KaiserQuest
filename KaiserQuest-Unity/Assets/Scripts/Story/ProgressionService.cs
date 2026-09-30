using System;
using System.Collections.Generic;
using KaiserQuest.Knowledge;

namespace KaiserQuest.Story
{
    /// <summary>Where one concept stands against a gate, named for the player.</summary>
    public class ConceptStatus
    {
        public string Concept;
        public string Name;
        public float Mastery;
    }

    /// <summary>Everything standing between the player and one milestone.</summary>
    public class EntryCheck
    {
        public bool Allowed;
        public List<string> Reasons = new List<string>();
        public float Coverage;
        public float Gate;
        public List<string> Concepts = new List<string>();
        public List<ConceptStatus> Unmet = new List<ConceptStatus>();
    }

    /// <summary>The full verdict on a trial attempt.</summary>
    public class MilestoneOutcome
    {
        public int MilestoneIndex;
        public bool Passed;
        public float ScorePercent;
        public float RequiredPercent;
        public float MasteryCoverage;
        public List<ConceptStatus> BlockedBy = new List<ConceptStatus>();
        public string Feedback = string.Empty;

        /// <summary>The milestone index this attempt unlocked, or 0 for none.</summary>
        public int Unlocked;

        public string Badge;
        public bool ClearedTheRealm;

        /// <summary>
        /// Scored enough, but does not actually know it. The instructive case, and
        /// the one the feedback line is written for.
        /// </summary>
        public bool FailedOnMastery
        {
            get { return !Passed && ScorePercent >= RequiredPercent; }
        }
    }

    /// <summary>
    /// Progression.
    ///
    /// The v0.1 game gated its gyms on player level: requiredLevel = gymIndex * 5.
    /// That is the design the vision rejects, and it is worth being explicit about
    /// why. A level gate says "you have spent enough time here". A mastery gate says
    /// "you understand this". The first is satisfied by grinding; the second cannot be.
    ///
    /// So progression is derived entirely from the knowledge trace:
    ///
    ///   * You may enter milestone N when you have *passed* N-1 and you still hold
    ///     the concepts N-1 taught.
    ///   * You pass a milestone by meeting its trial's required score *and* by
    ///     actually holding the concepts that milestone teaches.
    ///
    /// Two properties of that design are worth stating, because the obvious versions
    /// of both are wrong.
    ///
    /// **The entry check is local, not cumulative.** Requiring mastery of everything
    /// ever taught would collide head-on with the forgetting mechanic: concepts
    /// decay, so a player who took a fortnight off would be locked out by chapter
    /// three. By checking only the milestone just completed, holding everything
    /// becomes enforced *transitively* — you could not have reached N-1 without
    /// holding N-2 — while the remedy for a lapse is always a single milestone's
    /// worth of review.
    ///
    /// **The gate is reachable within the trial.** A gate of 80% cannot be cleared
    /// with two questions on a concept; TrialRunner therefore guarantees enough
    /// questions on the concepts a milestone introduces to make its own gate
    /// attainable. A gate the trial cannot satisfy is not a standard, it is a bug.
    ///
    /// A direct port of engine/progression.py.
    /// </summary>
    public class ProgressionService
    {
        /// <summary>
        /// Fraction of the previous milestone's concepts that must be held to enter
        /// the next one. Half, not all: one shaky idea is a recap, not a wall.
        /// </summary>
        public const float EntryCoverage = 0.5f;

        /// <summary>Fraction of a milestone's own concepts that must reach its gate to pass.</summary>
        public const float PassCoverage = 0.5f;

        /// <summary>
        /// A concept the question bank cannot examine is a content gap, not a player
        /// failure. Without this, a thin concept would make its milestone
        /// unpassable and the campaign unfinishable.
        /// </summary>
        public const int MinimumBankCoverage = 2;

        private readonly KnowledgeEngine _engine;

        public ProgressionService(KnowledgeEngine engine)
        {
            _engine = engine;
        }

        private ConceptGraph Graph { get { return _engine != null ? _engine.Graph : null; } }
        private KnowledgeTracer Tracer { get { return _engine != null ? _engine.Tracer : null; } }

        /// <summary>The concepts among `conceptIds` the bank can actually test.</summary>
        public List<string> Gradeable(ICollection<string> conceptIds)
        {
            List<string> result = new List<string>();
            if (conceptIds == null) return result;
            foreach (string concept in conceptIds)
            {
                if (_engine.QuestionCount(concept) >= MinimumBankCoverage) result.Add(concept);
            }
            return result;
        }

        public string ConceptName(string conceptId)
        {
            ConceptData concept = Graph != null ? Graph.Concept(conceptId) : null;
            return concept != null ? concept.name : conceptId;
        }

        // ------------------------------------------------------------------
        // Admission
        // ------------------------------------------------------------------
        /// <summary>
        /// Everything standing between the player and this milestone, as structured
        /// data rather than a bool — so the keeper can say the actual reason out
        /// loud, "you may not enter until Proportions is solid", instead of showing
        /// a padlock.
        /// </summary>
        public EntryCheck EntryCheck(
            IList<Milestone> milestones, Milestone milestone, RealmProgressData progress)
        {
            EntryCheck check = new EntryCheck();

            if (milestone.Index == 1)
            {
                check.Allowed = true;
                return check;
            }

            Milestone previous = MilestoneAt(milestones, milestone.Index - 1);
            if (previous == null)
            {
                // A campaign gap is not the player's fault; let them through.
                check.Allowed = true;
                return check;
            }

            bool passedPrevious = progress != null && progress.HasPassed(previous.Index);
            if (!passedPrevious)
            {
                check.Reasons.Add(
                    "You have not yet cleared " + previous.Name + ", and " + milestone.Keeper
                    + " will not open the way.");
            }

            check.Concepts = Gradeable(previous.Concepts);
            check.Gate = EntryGateFor(previous);

            if (check.Concepts.Count > 0)
            {
                check.Coverage = Coverage(check.Concepts, check.Gate, check.Unmet);
                if (check.Coverage < EntryCoverage)
                {
                    check.Reasons.Add(
                        "What you were just taught has faded below the standard needed to build on it. "
                        + milestone.Keeper + " sends you back to review it.");
                }
            }
            else
            {
                check.Coverage = 1f;
            }

            check.Allowed = check.Reasons.Count == 0;
            return check;
        }

        /// <summary>
        /// Holding what you were just taught is checked slightly more leniently than
        /// mastering it in the moment: the point of the entry gate is to stop a
        /// player walking into new material on top of material they have lost.
        /// </summary>
        public static float EntryGateFor(Milestone previous)
        {
            return Math.Max(35f, previous.MasteryGate - 10f);
        }

        // ------------------------------------------------------------------
        // Outcomes
        // ------------------------------------------------------------------
        /// <summary>
        /// Judge a trial attempt on two independent axes: the score, and whether the
        /// player actually knows the material.
        ///
        /// `conceptsEvaluated` is what the trial actually examined. An empty
        /// collection means nothing was examinable, so mastery is not gated on at all
        /// — judging a player on a concept they were never asked about is exactly the
        /// failure mode this whole design exists to prevent.
        /// </summary>
        public MilestoneOutcome Evaluate(
            IList<Milestone> milestones,
            Milestone milestone,
            TrialResult result,
            RealmProgressData progress,
            ICollection<string> conceptsEvaluated)
        {
            float required = milestone.Mode != null ? milestone.Mode.passRatio * 100f : 100f;

            List<string> gated = conceptsEvaluated != null
                ? new List<string>(conceptsEvaluated)
                : Gradeable(milestone.Concepts);

            List<ConceptStatus> unmet = new List<ConceptStatus>();
            float coverage = gated.Count > 0 ? Coverage(gated, milestone.MasteryGate, unmet) : 1f;

            bool scoredEnough = result != null && result.Ratio >= milestone.Mode.passRatio;
            bool knowsEnough = gated.Count == 0 || coverage >= PassCoverage;

            MilestoneOutcome outcome = new MilestoneOutcome();
            outcome.MilestoneIndex = milestone.Index;
            outcome.ScorePercent = result != null ? result.ScorePercent : 0f;
            outcome.RequiredPercent = required;
            outcome.MasteryCoverage = coverage;

            if (scoredEnough && knowsEnough)
            {
                bool already = progress != null && progress.HasPassed(milestone.Index);
                if (progress != null) progress.MarkPassed(milestone.Index, milestone.BadgeName);

                outcome.Passed = true;
                outcome.Badge = milestone.BadgeName;
                outcome.Feedback = milestone.Success;
                if (already) outcome.Feedback = "You have already earned this sigil. " + outcome.Feedback;

                int total = milestones != null ? milestones.Count : 0;
                if (milestone.Index < total)
                {
                    outcome.Unlocked = milestone.Index + 1;
                    if (progress != null && outcome.Unlocked > progress.lastSaveIndex)
                        progress.lastSaveIndex = outcome.Unlocked;
                }
                else
                {
                    outcome.ClearedTheRealm = true;
                    if (progress != null) progress.completed = true;
                }
                return outcome;
            }

            outcome.Passed = false;
            outcome.BlockedBy = unmet;

            if (scoredEnough && !knowsEnough)
            {
                outcome.Feedback =
                    "The score was enough, but " + milestone.Keeper + " is not satisfied. You reached "
                    + "the right answers without holding the ideas underneath them. That is not mastery, "
                    + "and it will not carry you further.";
            }
            else
            {
                outcome.Feedback = milestone.Failure;
            }
            return outcome;
        }

        // ------------------------------------------------------------------
        // Status
        // ------------------------------------------------------------------
        /// <summary>Every milestone with its current state, for the map screen.</summary>
        public List<MilestoneState> Status(IList<Milestone> milestones, RealmProgressData progress)
        {
            List<MilestoneState> states = new List<MilestoneState>();
            if (milestones == null) return states;

            Milestone current = FirstUnpassed(milestones, progress);

            for (int i = 0; i < milestones.Count; i++)
            {
                Milestone milestone = milestones[i];
                MilestoneState state = new MilestoneState();
                state.Index = milestone.Index;
                state.Id = milestone.Id;
                state.Name = milestone.Name;
                state.Place = milestone.Place;
                state.Keeper = milestone.Keeper;
                state.Kind = milestone.Kind;
                state.Mode = milestone.Mode != null ? milestone.Mode.id : string.Empty;
                state.Attempts = progress != null ? progress.AttemptsFor(milestone.Index) : 0;
                state.BestScore = progress != null ? progress.BestScoreFor(milestone.Index) : 0f;

                if (progress != null && progress.HasPassed(milestone.Index))
                {
                    state.State = "cleared";
                }
                else if (current != null && milestone.Index == current.Index)
                {
                    EntryCheck entry = EntryCheck(milestones, milestone, progress);
                    state.State = entry.Allowed ? "available" : "locked";
                    state.Entry = entry;
                }
                else
                {
                    state.State = "locked";
                }
                states.Add(state);
            }
            return states;
        }

        public Milestone FirstUnpassed(IList<Milestone> milestones, RealmProgressData progress)
        {
            if (milestones == null || milestones.Count == 0) return null;
            for (int i = 0; i < milestones.Count; i++)
            {
                if (progress == null || !progress.HasPassed(milestones[i].Index)) return milestones[i];
            }
            return milestones[milestones.Count - 1];
        }

        // ------------------------------------------------------------------
        // Helpers
        // ------------------------------------------------------------------
        /// <summary>
        /// Fraction of `conceptIds` at or above `gate` mastery, plus the ones that
        /// are not. This is the primitive every progression gate is built from.
        /// </summary>
        private float Coverage(ICollection<string> conceptIds, float gate, List<ConceptStatus> unmet)
        {
            if (conceptIds == null || conceptIds.Count == 0) return 1f;
            int passed = 0;
            int total = 0;
            foreach (string concept in conceptIds)
            {
                total++;
                float mastery = Tracer.Get(concept).Mastery();
                if (mastery >= gate)
                {
                    passed++;
                }
                else if (unmet != null)
                {
                    ConceptStatus status = new ConceptStatus();
                    status.Concept = concept;
                    status.Name = ConceptName(concept);
                    status.Mastery = mastery;
                    unmet.Add(status);
                }
            }
            return total > 0 ? (float)passed / total : 1f;
        }

        private static Milestone MilestoneAt(IList<Milestone> milestones, int index)
        {
            if (milestones == null) return null;
            for (int i = 0; i < milestones.Count; i++)
            {
                if (milestones[i].Index == index) return milestones[i];
            }
            return null;
        }
    }

    /// <summary>One milestone as the map screen needs it.</summary>
    public class MilestoneState
    {
        /// <summary>"cleared" | "available" | "locked"</summary>
        public string State;
        public int Index;
        public string Id;
        public string Name;
        public string Place;
        public string Keeper;
        public string Kind;
        public string Mode;
        public int Attempts;
        public float BestScore;
        public EntryCheck Entry;
    }
}
