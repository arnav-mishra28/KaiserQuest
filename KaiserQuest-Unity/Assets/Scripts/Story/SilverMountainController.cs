using System;
using System.Collections.Generic;
using KaiserQuest.Knowledge;

namespace KaiserQuest.Story
{
    /// <summary>One concept the final exam will test, with the reason it was chosen.</summary>
    public class ExamSlot
    {
        public string Concept;
        public string ConceptName;
        public int Difficulty;
        public float Mastery;

        /// <summary>"weak" | "mid" | "strong"</summary>
        public string Band;
        public string Reason;
    }

    /// <summary>Whether the mountain will have you, and why not if it will not.</summary>
    public class Admission
    {
        public bool Allowed;
        public string Reason = string.Empty;
        public List<int> MilestonesRemaining = new List<int>();
        public int MilestonesPassed;
        public int MilestonesTotal;
    }

    /// <summary>The state of the summit right now.</summary>
    public class MountainStatus
    {
        public bool Allowed;
        public bool CanChallenge;
        public int AttemptsRemaining;
        public int AttemptsTotal = SilverMountainData.AttemptsPerWindow;
        public double CooldownUntil;
        public double CooldownRemainingSeconds;
        public bool CooldownJustExpired;
        public bool Cleared;
        public string Reason = string.Empty;
        public int MilestonesPassed;
        public int MilestonesTotal;
        public int ExamQuestions;
        public float ExamPassRatio;
        public int ExamRequiredCorrect;
        public List<ArchivistAttemptData> History = new List<ArchivistAttemptData>();

        public double CooldownHoursRemaining
        {
            get { return CooldownRemainingSeconds / 3600.0; }
        }
    }

    /// <summary>The Archivist's verdict on one climb, and what happens next.</summary>
    public class ArchivistVerdict
    {
        public bool Passed;
        public bool Cleared;
        public int AttemptsRemaining;
        public double CooldownUntil;
        public double CooldownHours;
        public bool ReturnToSave;
        public float ScorePercent;
        public List<string> ArchivistLines = new List<string>();
        public List<RecapStepData> Recap = new List<RecapStepData>();
    }

    /// <summary>A personalized Mastery Recap, exactly as the player is sent to read it.</summary>
    public class Recap
    {
        public string Realm;
        public List<RecapStepData> Steps = new List<RecapStepData>();
        public string Summary = string.Empty;
        public double CooldownUntil;
        public int AttemptsRemaining;
        public int AttemptsTotal = SilverMountainData.AttemptsPerWindow;
    }

    /// <summary>The exam as it is handed to the player.</summary>
    public class ExamPaper
    {
        public bool Granted;
        public string Reason = string.Empty;
        public MountainStatus Status;
        public List<ExamSlot> Slots = new List<ExamSlot>();
        public List<BankQuestion> Questions = new List<BankQuestion>();
        public List<string> ArchivistLines = new List<string>();
        public int RequiredCorrect;
        public float PassRatio;
    }

    /// <summary>
    /// Silver Mountain and the Archivist.
    ///
    /// The final region, and the place where the Knowledge Engine stops being a
    /// background system and becomes the antagonist.
    ///
    /// Design constraints, all taken from the vision:
    ///
    ///   * Access requires the full realm's milestones cleared, not a level.
    ///   * Three attempts per window. Fail all three and you return to your last save
    ///     point with a 24-hour cooldown — but the recap you are sent to is
    ///     *specific*: it names the concepts you failed on and the misconceptions you
    ///     exhibited, and it ends with a drill sequence, not "study more".
    ///   * The exam itself is assembled from the player's own knowledge profile. It is
    ///     not a fixed test: roughly 60% of it is aimed at their weakest concepts, 25%
    ///     at the middle, and 15% at their strongest — because a final exam that never
    ///     asks what you know best is not an examination, it is an ambush.
    ///
    /// The Archivist is given a voice rather than a scoreboard: his dialogue is
    /// generated from the actual diagnosis, so he can say what he knows.
    ///
    /// A direct port of engine/silver_mountain.py.
    /// </summary>
    public class SilverMountainController
    {
        public const int AttemptsPerWindow = 3;
        public const double CooldownHours = 24.0;
        public const int ExamQuestions = 25;
        public const float ExamPassRatio = 0.80f;

        /// <summary>How the exam is weighted across the player's own strength profile.</summary>
        public const float WeakShare = 0.60f;
        public const float MidShare = 0.25f;

        private readonly KnowledgeEngine _engine;

        public SilverMountainController(KnowledgeEngine engine)
        {
            _engine = engine;
        }

        private ConceptGraph Graph { get { return _engine != null ? _engine.Graph : null; } }

        public static int RequiredCorrect
        {
            get { return (int)Math.Ceiling(ExamQuestions * ExamPassRatio); }
        }

        // ------------------------------------------------------------------
        // Who may climb
        // ------------------------------------------------------------------
        /// <summary>
        /// The Archivist examines your record before he examines you.
        ///
        /// Gate: every milestone in the realm cleared. Not a level, not a badge count
        /// used as a proxy for one — the milestones themselves.
        /// </summary>
        public Admission AdmissionOf(IList<Milestone> milestones, RealmProgressData progress, double now)
        {
            Admission admission = new Admission();
            admission.MilestonesTotal = milestones != null ? milestones.Count : 0;
            admission.MilestonesPassed = progress != null ? progress.PassedCount : 0;

            if (milestones == null || progress == null || admission.MilestonesPassed < admission.MilestonesTotal)
            {
                if (milestones != null)
                {
                    for (int i = 0; i < milestones.Count; i++)
                    {
                        if (!progress.HasPassed(milestones[i].Index)) admission.MilestonesRemaining.Add(milestones[i].Index);
                    }
                }
                int remaining = admission.MilestonesRemaining.Count;
                admission.Allowed = false;
                admission.Reason = "The Archivist does not raise his eyes. 'The realm is not finished. "
                    + remaining + (remaining == 1 ? " trial remains.'" : " trials remain.'");
                return admission;
            }

            admission.Allowed = true;
            admission.Reason = "The Archivist looks up. 'So you have walked the whole realm.'";
            return admission;
        }

        // ------------------------------------------------------------------
        // Status
        // ------------------------------------------------------------------
        public MountainStatus Status(
            IList<Milestone> milestones, RealmProgressData progress, SilverMountainData state, double now)
        {
            MountainStatus status = new MountainStatus();
            bool justReset = state.Refresh(now);
            Admission admission = AdmissionOf(milestones, progress, now);

            status.Allowed = admission.Allowed;
            status.Cleared = state.cleared;
            status.AttemptsRemaining = state.attemptsRemaining;
            status.CooldownUntil = state.cooldownUntil;
            status.CooldownRemainingSeconds = state.CooldownRemaining(now);
            status.CooldownJustExpired = justReset;
            status.MilestonesPassed = admission.MilestonesPassed;
            status.MilestonesTotal = admission.MilestonesTotal;
            status.ExamQuestions = ExamQuestions;
            status.ExamPassRatio = ExamPassRatio;
            status.ExamRequiredCorrect = RequiredCorrect;
            status.History = new List<ArchivistAttemptData>(state.history);

            status.CanChallenge = admission.Allowed && state.attemptsRemaining > 0 && state.cooldownUntil <= 0.0;
            if (state.cleared) status.CanChallenge = admission.Allowed;

            status.Reason = admission.Reason;
            if (admission.Allowed)
            {
                if (state.cleared)
                {
                    status.Reason = "You have cleared Silver Mountain. The Archivist will still test you, if you wish.";
                }
                else if (state.cooldownUntil > 0.0)
                {
                    status.Reason = "The Archivist turns his back. 'Return when you have learned what you failed to "
                        + string.Format("learn. ({0:0.0} hours remain)'", status.CooldownHoursRemaining);
                }
                else if (state.attemptsRemaining <= 0)
                {
                    status.Reason = "No attempts remain in this window.";
                }
            }
            return status;
        }

        // ------------------------------------------------------------------
        // Exam assembly
        // ------------------------------------------------------------------
        /// <summary>
        /// Build the final exam from the player's own profile.
        ///
        /// Weakest concepts take the largest share; the strongest are included on
        /// purpose. An exam you can pass without ever being asked what you are good at
        /// is not measuring the realm.
        /// </summary>
        public List<ExamSlot> AssembleExam(KnowledgeProfile profile, string realm)
        {
            List<ExamSlot> slots = new List<ExamSlot>();
            List<ConceptData> concepts = Graph.ConceptsOfRealm(realm);
            if (concepts.Count == 0) return slots;

            List<ScoredConcept> scored = new List<ScoredConcept>();
            for (int i = 0; i < concepts.Count; i++)
            {
                ConceptKnowledge knowledge = profile.Tracer.Get(concepts[i].id);
                ScoredConcept item = new ScoredConcept();
                item.Concept = concepts[i].id;
                item.Level = concepts[i].level;
                // Concepts never attempted count as maximally weak: the Archivist
                // will find them, and that is the correct behaviour.
                item.Mastery = knowledge.Attempts > 0 ? knowledge.Mastery() : 0f;
                scored.Add(item);
            }

            scored.Sort(delegate (ScoredConcept a, ScoredConcept b) { return a.Mastery.CompareTo(b.Mastery); });

            int size = scored.Count;
            int weakCut = Math.Max(1, (int)(size * 0.5));
            int midCut = Math.Max(weakCut + 1, (int)(size * 0.75));
            if (midCut > size) midCut = size;
            if (weakCut > size) weakCut = size;

            List<ScoredConcept> weakPool = scored.GetRange(0, weakCut);
            List<ScoredConcept> midPool = scored.GetRange(weakCut, Math.Max(0, midCut - weakCut));
            List<ScoredConcept> strongPool = scored.GetRange(midCut, Math.Max(0, size - midCut));

            int weakCount = (int)Math.Round(ExamQuestions * WeakShare);
            int midCount = (int)Math.Round(ExamQuestions * MidShare);
            int strongCount = ExamQuestions - weakCount - midCount;

            slots.AddRange(DrawBand(weakPool, weakCount, "weak", profile));
            slots.AddRange(DrawBand(midPool, midCount, "mid", profile));
            slots.AddRange(DrawBand(strongPool, strongCount, "strong", profile));

            // Top up from the weakest band if a band was too small to fill its share.
            if (slots.Count < ExamQuestions)
            {
                HashSet<string> already = new HashSet<string>();
                for (int i = 0; i < slots.Count; i++) already.Add(slots[i].Concept);
                for (int i = 0; i < scored.Count && slots.Count < ExamQuestions; i++)
                {
                    if (already.Contains(scored[i].Concept)) continue;
                    already.Add(scored[i].Concept);
                    slots.Add(MakeSlot(scored[i], "weak", profile));
                }
            }

            if (slots.Count > ExamQuestions) slots.RemoveRange(ExamQuestions, slots.Count - ExamQuestions);
            return slots;
        }

        private List<ExamSlot> DrawBand(
            List<ScoredConcept> pool, int count, string band, KnowledgeProfile profile)
        {
            List<ExamSlot> slots = new List<ExamSlot>();
            if (count <= 0 || pool == null || pool.Count == 0) return slots;

            List<ScoredConcept> ordered = new List<ScoredConcept>(pool);
            if (band == "strong")
            {
                ordered.Sort(delegate (ScoredConcept a, ScoredConcept b) { return b.Mastery.CompareTo(a.Mastery); });
            }
            else if (band == "mid")
            {
                ordered.Sort(delegate (ScoredConcept a, ScoredConcept b) { return a.Mastery.CompareTo(b.Mastery); });
            }

            int index = 0;
            while (slots.Count < count && ordered.Count > 0)
            {
                ScoredConcept item = ordered[index % ordered.Count];
                index++;
                slots.Add(MakeSlot(item, band, profile));
                if (index > count * 3) break;
            }
            return slots;
        }

        private ExamSlot MakeSlot(ScoredConcept item, string band, KnowledgeProfile profile)
        {
            ConceptKnowledge knowledge = profile.Tracer.Get(item.Concept);
            ExamSlot slot = new ExamSlot();
            slot.Concept = item.Concept;
            ConceptData concept = Graph.Concept(item.Concept);
            slot.ConceptName = concept != null ? concept.name : item.Concept;
            slot.Mastery = (float)Math.Round(item.Mastery, 2);
            slot.Band = band;

            if (band == "weak")
            {
                if (knowledge.Attempts == 0)
                    slot.Reason = "Never attempted. The Archivist has noticed the gap.";
                else if (knowledge.IsRusty)
                    slot.Reason = "Learned once, then faded \u2014 only "
                        + (int)Math.Round(knowledge.Retention() * 100) + "% retained.";
                else
                    slot.Reason = "The concept you are least sure of.";
            }
            else if (band == "mid")
            {
                slot.Reason = "Held shakily. One more push would settle it.";
            }
            else
            {
                slot.Reason = "Your strongest ground. The Archivist does not skip what you know best.";
            }

            // Test just above current level, but never below the concept's own band.
            slot.Difficulty = Math.Max(item.Level, Math.Min(5, item.Level + (item.Mastery >= 80f ? 1 : 0)));
            return slot;
        }

        /// <summary>
        /// Gather the actual questions for an exam paper.
        ///
        /// One question per slot, and one slot per concept deliberately: the exam is
        /// 25 stations across the whole realm, not 25 chances at the same thing.
        /// </summary>
        public ExamPaper Challenge(
            IList<Milestone> milestones,
            RealmProgressData progress,
            SilverMountainData state,
            List<string> recentQuestionIds,
            double now)
        {
            ExamPaper paper = new ExamPaper();
            paper.Status = Status(milestones, progress, state, now);
            paper.PassRatio = ExamPassRatio;
            paper.RequiredCorrect = RequiredCorrect;

            if (!paper.Status.CanChallenge)
            {
                paper.Granted = false;
                paper.Reason = paper.Status.Reason;
                return paper;
            }

            KnowledgeProfile profile = _engine.ProfileFor(state.realm);
            paper.Slots = AssembleExam(profile, state.realm);

            List<string> used = new List<string>();
            int start = Math.Max(0, recentQuestionIds.Count - 60);
            for (int i = start; i < recentQuestionIds.Count; i++) used.Add(recentQuestionIds[i]);

            for (int i = 0; i < paper.Slots.Count; i++)
            {
                ExamSlot slot = paper.Slots[i];
                List<string> pool = new List<string>();
                pool.Add(slot.Concept);

                Dictionary<string, int> targets = new Dictionary<string, int>();
                targets[slot.Concept] = slot.Difficulty;

                for (int q = 0; q < paper.Questions.Count; q++) used.Add(paper.Questions[q].id);

                QuestionSelection picked = _engine.Select(pool, 1, used, null, targets);
                if (picked != null && picked.Questions != null && picked.Questions.Count > 0)
                    paper.Questions.Add(picked.Questions[0]);
            }

            paper.ArchivistLines.Add("You have collected knowledge. But knowledge collected is not knowledge mastered.");
            paper.ArchivistLines.Add("I will ask you about the things you are worst at, and about the things you think you are best at.");
            paper.ArchivistLines.Add("Begin.");
            paper.Granted = paper.Questions.Count > 0;
            if (!paper.Granted)
                paper.Reason = "No verified questions are available for the summit's slots.";
            return paper;
        }

        // ------------------------------------------------------------------
        // The challenge
        // ------------------------------------------------------------------
        /// <summary>
        /// Apply the outcome of one climb.
        ///
        /// Failing the third attempt closes the mountain for 24 hours and returns a
        /// personalised recap. Passing clears the story.
        /// </summary>
        public ArchivistVerdict RecordAttempt(
            SilverMountainData state, bool passed, float ratio, KnowledgeProfile profile, double now)
        {
            state.Refresh(now);

            ArchivistAttemptData attempt = new ArchivistAttemptData();
            attempt.number = state.history.Count + 1;
            attempt.passed = passed;
            attempt.scorePercent = (float)Math.Round(ratio * 100f, 1);
            attempt.timestamp = now;
            state.history.Add(attempt);

            ArchivistVerdict verdict = new ArchivistVerdict();
            verdict.ScorePercent = (float)Math.Round(ratio * 100f, 1);

            if (passed)
            {
                state.cleared = true;
                state.clearedAt = now;
                state.recap = new List<RecapStepData>();

                verdict.Passed = true;
                verdict.Cleared = true;
                verdict.AttemptsRemaining = state.attemptsRemaining;
                verdict.ArchivistLines = VictoryLines(ratio);
                return verdict;
            }

            state.attemptsRemaining = Math.Max(0, state.attemptsRemaining - 1);
            List<RecapStepData> recap = BuildRecap(profile, 6);
            state.recap = recap;

            verdict.AttemptsRemaining = state.attemptsRemaining;
            verdict.Recap = recap;
            verdict.Passed = false;
            verdict.Cleared = false;

            if (state.attemptsRemaining <= 0)
            {
                state.cooldownUntil = now + CooldownHours * 3600.0;
                verdict.CooldownUntil = state.cooldownUntil;
                verdict.CooldownHours = CooldownHours;
                verdict.ReturnToSave = true;
                verdict.ArchivistLines = DefeatLines(profile, ratio, true);
            }
            else
            {
                verdict.ReturnToSave = false;
                verdict.ArchivistLines = DefeatLines(profile, ratio, false);
            }
            return verdict;
        }

        // ------------------------------------------------------------------
        // The recap
        // ------------------------------------------------------------------
        /// <summary>
        /// The personalised Mastery Recap.
        ///
        /// Ordered so the player does the most valuable thing first: named
        /// misconceptions (there is a specific fix), then the weakest concepts, then
        /// anything that has visibly decayed. Every step says why it is there.
        /// </summary>
        public List<RecapStepData> BuildRecap(KnowledgeProfile profile, int limit)
        {
            List<RecapStepData> steps = new List<RecapStepData>();
            int order = 1;

            List<RemedyStep> plan = profile.MisconceptionPlan(3);
            for (int i = 0; i < plan.Count; i++)
            {
                RemedyStep item = plan[i];
                string conceptId = Graph.HasConcept(item.Concept) ? item.Concept : string.Empty;

                RecapStepData step = new RecapStepData();
                step.order = order++;
                step.kind = "remedy";
                step.concept = conceptId;
                step.conceptName = conceptId.Length > 0 ? ConceptNameOf(conceptId) : item.Name;
                step.title = item.Name;
                string body = item.Evidence + " " + item.Remedy;
                if (item.Drills != null && item.Drills.Count > 0)
                    body += " Then drill: " + string.Join(", ", item.Drills.ToArray()) + ".";
                step.body = body.Trim();
                step.mastery = conceptId.Length > 0 ? profile.Tracer.Mastery(conceptId) : 0f;
                steps.Add(step);
            }

            List<ConceptView> weak = profile.WeakConcepts(65f, 4);
            for (int i = 0; i < weak.Count; i++)
            {
                if (ContainsConcept(steps, weak[i].Id)) continue;
                RecapStepData step = new RecapStepData();
                step.order = order++;
                step.kind = "concept";
                step.concept = weak[i].Id;
                step.conceptName = weak[i].Name;
                step.title = "Rework: " + weak[i].Name;
                step.body = "Mastery " + ((int)weak[i].Mastery) + "% across " + weak[i].Attempts
                    + " attempts. The Archivist asked about this and you did not have it. "
                    + "Next time he asks, this is the answer he wants.";
                step.mastery = weak[i].Mastery;
                steps.Add(step);
            }

            List<ConceptView> rusty = profile.RustyConcepts();
            for (int i = 0; i < rusty.Count; i++)
            {
                if (steps.Count >= limit) break;
                if (ContainsConcept(steps, rusty[i].Id)) continue;
                RecapStepData step = new RecapStepData();
                step.order = order++;
                step.kind = "drill";
                step.concept = rusty[i].Id;
                step.conceptName = rusty[i].Name;
                step.title = "Refresh: " + rusty[i].Name;
                step.body = "You knew this once \u2014 " + (int)Math.Round(rusty[i].Retention * 100)
                    + "% of it has faded. A short drill restores it; it will be on the next climb.";
                step.mastery = rusty[i].Mastery;
                steps.Add(step);
            }

            if (steps.Count == 0)
            {
                RecapStepData step = new RecapStepData();
                step.order = 1;
                step.kind = "drill";
                step.concept = string.Empty;
                step.conceptName = profile.RealmId;
                step.title = "A short drill on the whole realm";
                step.body = "Your knowledge is broadly in place; what failed you at the summit was endurance "
                    + "rather than any single gap. Work a mixed set under time.";
                step.mastery = profile.OverallMastery;
                steps.Add(step);
            }

            if (steps.Count > limit) steps.RemoveRange(limit, steps.Count - limit);
            return steps;
        }

        /// <summary>The one-line version, for the save-point screen.</summary>
        public string RecapSummary(KnowledgeProfile profile)
        {
            List<string> parts = new List<string>();

            List<ConceptView> weak = profile.WeakConcepts(65f, 3);
            if (weak.Count > 0)
            {
                List<string> names = new List<string>();
                for (int i = 0; i < weak.Count; i++) names.Add(weak[i].Name.ToLowerInvariant());
                parts.Add("You struggled with " + string.Join(", ", names.ToArray()) + ".");
            }

            List<RemedyStep> plan = profile.MisconceptionPlan(1);
            if (plan.Count > 0) parts.Add("And you kept " + plan[0].Name.ToLowerInvariant() + ".");

            if (parts.Count == 0)
                parts.Add("Your knowledge is broadly sound; the summit tested your stamina.");

            return string.Join(" ", parts.ToArray());
        }

        /// <summary>The recap the player is sent to, stored one if there is one.</summary>
        public Recap Recap(IList<Milestone> milestones, RealmProgressData progress, SilverMountainData state, double now)
        {
            Recap recap = new Recap();
            recap.Realm = state.realm;
            recap.CooldownUntil = state.cooldownUntil;
            recap.AttemptsRemaining = state.attemptsRemaining;

            KnowledgeProfile profile = _engine.ProfileFor(state.realm);
            recap.Steps = state.recap != null && state.recap.Count > 0 ? state.recap : BuildRecap(profile, 6);
            recap.Summary = RecapSummary(profile);
            return recap;
        }

        // ------------------------------------------------------------------
        // The Archivist speaks
        // ------------------------------------------------------------------
        private List<string> VictoryLines(float ratio)
        {
            List<string> lines = new List<string>();
            lines.Add("You have collected knowledge. But knowledge collected is not knowledge mastered.");
            lines.Add("You answered " + (int)Math.Round(ratio * 100f) + "% of it. You have mastered enough of it.");
            lines.Add("Then the realm is yours. I have been the Archivist of this summit for a long time, "
                + "and I do not say this often: you understand the material.");
            lines.Add("Go home. Teach someone. That is the last trial, and there is no badge for it.");
            return lines;
        }

        private List<string> DefeatLines(KnowledgeProfile profile, float ratio, bool final)
        {
            List<string> lines = new List<string>();
            lines.Add("You have collected knowledge. But knowledge collected is not knowledge mastered.");
            lines.Add("You answered " + (int)Math.Round(ratio * 100f) + "% of what I asked.");

            List<ConceptView> weakest = profile.WeakConcepts(65f, 3);
            if (weakest.Count > 0)
            {
                List<string> names = new List<string>();
                for (int i = 0; i < weakest.Count; i++) names.Add(weakest[i].Name);
                lines.Add("I asked about " + string.Join(", ", names.ToArray()) + ". You guessed.");
            }

            List<RemedyStep> plan = profile.MisconceptionPlan(2);
            if (plan.Count > 0)
                lines.Add("And you are still doing this: " + plan[0].Name.ToLowerInvariant() + ".");

            if (final)
            {
                lines.Add("Three attempts, as promised. Go back to the last place you rested. "
                    + "Come to the mountain again in a day, and bring the answers with you.");
            }
            else
            {
                lines.Add("Again. And this time, think before you answer.");
            }
            return lines;
        }

        private string ConceptNameOf(string conceptId)
        {
            ConceptData concept = Graph.Concept(conceptId);
            return concept != null ? concept.name : conceptId;
        }

        private static bool ContainsConcept(List<RecapStepData> steps, string concept)
        {
            for (int i = 0; i < steps.Count; i++) if (steps[i].concept == concept) return true;
            return false;
        }

        private class ScoredConcept
        {
            public string Concept;
            public float Mastery;
            public int Level;
        }
    }
}
