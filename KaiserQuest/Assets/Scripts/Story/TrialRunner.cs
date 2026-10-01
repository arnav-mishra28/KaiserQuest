using System;
using System.Collections.Generic;
using KaiserQuest.Knowledge;

namespace KaiserQuest.Story
{
    /// <summary>One graded trial attempt. Mirrors TrialResult in engine/progression.py.</summary>
    public class TrialResult
    {
        public int MilestoneIndex;
        public int Correct;
        public int Total;
        public float DurationSeconds;
        public int HintsUsed;
        public List<string> ConceptsAttempted = new List<string>();

        public float Ratio
        {
            get { return Total > 0 ? (float)Correct / Total : 0f; }
        }

        public float ScorePercent
        {
            get { return (float)Math.Round(100f * Ratio, 1); }
        }
    }

    /// <summary>One question in a trial, with the hidden reasoning behind its selection.</summary>
    public class TrialStep
    {
        /// <summary>The item itself.</summary>
        public BankQuestion Question;

        /// <summary>The concept being examined, which is what the mastery gate reads.</summary>
        public string Concept;

        /// <summary>The hidden adaptive difficulty this item was chosen at.</summary>
        public int Difficulty;

        /// <summary>1-based position in the trial as the player experiences it.</summary>
        public int Position;

        /// <summary>Round of a bracket, link of a chain, station of a construction.</summary>
        public int Round;

        /// <summary>Why this concept was chosen. Shown when the trial ends.</summary>
        public string Reason;

        /// <summary>Asked again because the mechanic propagates mistakes (chain, clues, steps).</summary>
        public bool IsRebound;

        /// <summary>The in-world framing the UI puts above the question.</summary>
        public string Prompt;
    }

    /// <summary>
    /// The rules a mechanic plays by.
    ///
    /// A trial is not a quiz with a different title bar. What actually differs
    /// between the twenty milestones is the *policy*: which concepts are fair game,
    /// how hard they come at you, whether a mistake costs you the next question or
    /// only this one, and whether you are allowed to be helped. All of that is
    /// decided here; the UI only decides how it looks.
    /// </summary>
    public class TrialRules
    {
        /// <summary>Draw on everything taught so far, not just this milestone.</summary>
        public bool Breadth;

        /// <summary>A wrong answer re-asks the same concept before the trial moves on.</summary>
        public bool ReboundOnWrong;

        /// <summary>You cannot get past a concept until you have answered it.</summary>
        public bool BlocksOnWrong;

        /// <summary>Shifts every question's difficulty: -1 gentler, +1 harder.</summary>
        public int DifficultyOffset;

        /// <summary>Difficulty climbs across the trial, so the last item is the hardest.</summary>
        public bool Ramps;

        /// <summary>Fixed mechanical difficulty (the dials are set; they are not adapted to you).</summary>
        public bool PinToLevel;

        /// <summary>Prefer items whose wrong options name a specific broken rule.</summary>
        public bool PreferTagged;

        /// <summary>Aim the extras at the player's weakest chapters.</summary>
        public bool AimWeakest;
    }

    /// <summary>
    /// Runs one trial of one milestone.
    ///
    /// Deliberately not a MonoBehaviour and with no reference to any UI: it is a
    /// sequencer that turns a milestone into a series of questions, feeds every
    /// answer straight into the Knowledge Engine, and reports a result the
    /// progression gate can judge. That keeps the mechanics testable and keeps the
    /// 2 GB Android target happy.
    ///
    /// The guarantee carried over from the Python implementation: the concepts this
    /// milestone *introduces* are always examined, and examined first. A tournament
    /// drawn from thirty-four concepts could otherwise skip the new chapter
    /// entirely, and the player would then be failed by the mastery gate for
    /// something they were never asked about.
    /// </summary>
    public class TrialRunner
    {
        /// <summary>
        /// A trial may grow to twice its planned length when errors propagate
        /// (chains, clues, ordered steps). Bounded so the mechanic cannot punish
        /// a player forever for one early mistake.
        /// </summary>
        public const int MaxQuestionMultiplier = 2;

        private readonly List<TrialStep> _steps = new List<TrialStep>();
        private readonly List<GradedAnswer> _graded = new List<GradedAnswer>();
        private readonly HashSet<string> _usedIds = new HashSet<string>();
        private readonly List<string> _conceptsAnswered = new List<string>();

        private KnowledgeEngine _engine;
        private Milestone _milestone;
        private TrialMode _mode;
        private TrialRules _rules;
        private List<string> _recentIds = new List<string>();

        private int _position;
        private int _round;
        private int _hintsUsed;
        private float _elapsedMs;
        private TrialStep _current;
        private bool _finished;

        // ------------------------------------------------------------------
        // State
        // ------------------------------------------------------------------
        public bool Begun { get; private set; }
        public bool IsComplete { get { return !Begun || _finished; } }
        public TrialStep Current { get { return _current; } }
        public Milestone Milestone { get { return _milestone; } }
        public TrialMode Mode { get { return _mode; } }
        public string Mechanic { get { return _mode != null ? _mode.mechanic : string.Empty; } }
        public string Stakes { get { return _mode != null ? _mode.stakes : string.Empty; } }
        public int PlannedTotal { get { return _mode != null ? _mode.questions : 0; } }
        public int Answered { get { return _graded.Count; } }
        public int CorrectCount
        {
            get
            {
                int correct = 0;
                for (int i = 0; i < _graded.Count; i++) if (_graded[i].Correct) correct++;
                return correct;
            }
        }
        public int HintsUsed { get { return _hintsUsed; } }
        public bool IsTimed { get { return _mode != null && _mode.secondsPerQuestion > 0; } }
        public int SecondsPerQuestion { get { return _mode != null ? _mode.secondsPerQuestion : 0; } }
        public int HintsAllowed { get { return _mode != null ? _mode.hintsAllowed : 0; } }
        public IList<GradedAnswer> Graded { get { return _graded; } }

        /// <summary>Every question the trial will ask, including links added mid-run.</summary>
        public IList<TrialStep> Steps { get { return _steps; } }

        public int RequiredCorrect
        {
            get
            {
                if (_mode == null) return 0;
                int ceiling = _mode.questions * MaxQuestionMultiplier;
                return Math.Min(Math.Max(1, (int)Math.Ceiling(ceiling * _mode.passRatio)), ceiling);
            }
        }

        // ------------------------------------------------------------------
        // Rules
        // ------------------------------------------------------------------
        /// <summary>The policy table. One entry per mechanic in TrialModes.</summary>
        public static TrialRules RulesFor(string mechanic)
        {
            TrialRules rules = new TrialRules();
            switch (mechanic)
            {
                case "teach_then_ask":
                    // A keeper walks you through it, so it comes in gently and
                    // there is no cost to being taught.
                    rules.DifficultyOffset = -1;
                    break;

                case "solve_to_open":
                    // The mechanism was set to fixed values before you arrived.
                    // Nothing here adapts to you, which is what makes it a puzzle.
                    rules.PinToLevel = true;
                    break;

                case "countdown_duel":
                    // Normal difficulty, short clock. Fluency is the subject.
                    break;

                case "justify_step":
                    // Several answers look workable; only one step is justified.
                    rules.PreferTagged = true;
                    break;

                case "mixed_bracket":
                    rules.Breadth = true;
                    break;

                case "assemble_clues":
                    // A wrong answer means the clues do not assemble yet, so the
                    // same thread is laid out again.
                    rules.ReboundOnWrong = true;
                    break;

                case "find_the_error":
                    // The flaws have to be nameable for the mechanic to work, so
                    // items whose distractors carry a named misconception are used.
                    rules.PreferTagged = true;
                    break;

                case "escalating_run":
                    rules.Ramps = true;
                    break;

                case "seeded_chain":
                    rules.Breadth = true;
                    rules.ReboundOnWrong = true;
                    rules.BlocksOnWrong = true;
                    break;

                case "order_the_steps":
                    rules.BlocksOnWrong = true;
                    break;

                case "boss_encounter":
                    rules.Breadth = true;
                    rules.AimWeakest = true;
                    rules.DifficultyOffset = 1;
                    break;

                case "championship":
                    rules.Breadth = true;
                    rules.AimWeakest = true;
                    rules.DifficultyOffset = 1;
                    break;

                case "mixed_bracket_full":
                    rules.Breadth = true;
                    rules.DifficultyOffset = 1;
                    break;
            }
            return rules;
        }

        // ------------------------------------------------------------------
        // Beginning
        // ------------------------------------------------------------------
        /// <summary>
        /// Assemble and start a trial. Returns false when there is nothing to ask,
        /// which is a content gap rather than a player failure — the caller should
        /// report it, not fail the player.
        /// </summary>
        public bool Begin(
            Milestone milestone,
            IList<Milestone> milestones,
            KnowledgeEngine engine,
            ICollection<string> recentQuestionIds = null)
        {
            _milestone = milestone;
            _engine = engine;
            _recentIds = new List<string>();
            if (recentQuestionIds != null) foreach (string id in recentQuestionIds) _recentIds.Add(id);

            if (milestone == null || engine == null || engine.Graph == null)
            {
                return false;
            }

            _mode = milestone.Mode ?? TrialModes.Get("applied");
            _rules = RulesFor(_mode.mechanic);
            if (_mode.mechanic == "mixed_bracket" && _mode.id == "grand_tournament")
            {
                // The regional bracket is run at the realm's highest standard.
                _rules.DifficultyOffset = 1;
            }

            List<string> own = OwnConcepts(engine, milestone);
            if (own.Count == 0) return false;

            List<string> extra = ExtraConcepts(engine, milestone, milestones, own);

            List<string> preference = engine.ActiveMisconceptionIds(milestone.Realm);

            List<BankQuestion> guaranteedItems = Draw(
                engine, own, GuaranteedCount(own.Count, _mode.questions), preference, false);

            if (guaranteedItems.Count < GuaranteedCount(own.Count, _mode.questions))
            {
                // Retrying a trial must not run the bank dry: allow the player's
                // recent items back in rather than refusing them entry.
                guaranteedItems.AddRange(Draw(
                    engine, own,
                    GuaranteedCount(own.Count, _mode.questions) - guaranteedItems.Count,
                    preference, true));
            }

            Append(guaranteedItems, "introduced by this milestone", false);

            int remaining = _mode.questions - _steps.Count;
            if (remaining > 0)
            {
                List<string> pool = FillPool(engine, own, extra);
                List<BankQuestion> more = Draw(engine, pool, remaining, preference, false);
                if (more.Count < remaining)
                {
                    more.AddRange(Draw(engine, pool, remaining - more.Count, preference, true));
                }
                Append(more, DescribeSource(pool, own), false);
            }

            if (_steps.Count == 0) return false;

            Sequence(milestone, milestones);
            Begun = true;
            _finished = false;
            _position = 0;
            _current = _steps[0];
            _current.Position = 1;
            return true;
        }

        /// <summary>Give up on a trial in progress without recording a result.</summary>
        public void Abandon()
        {
            Begun = false;
            _finished = true;
            _current = null;
        }

        // ------------------------------------------------------------------
        // Answering
        // ------------------------------------------------------------------
        /// <summary>
        /// Grade one answer and advance.
        ///
        /// The knowledge trace is updated here, immediately, before the next
        /// question is chosen — so the very next item is aimed at what this answer
        /// just revealed, which is the whole point of an adaptive system.
        /// </summary>
        public GradedAnswer Answer(string chosen, float responseTimeMs, int hintsUsedForThisQuestion = 0)
        {
            if (IsComplete || _current == null) return null;

            int hints = Math.Max(0, hintsUsedForThisQuestion);
            _hintsUsed += hints;
            _elapsedMs += Math.Max(0f, responseTimeMs);

            GradedAnswer graded = _engine.Grade(
                _current.Question.id, chosen, responseTimeMs, hints, 1,
                _milestone != null ? _milestone.Id : null);

            if (graded == null)
            {
                // An ungradeable item must never strand the player mid-trial.
                Advance();
                return null;
            }

            _graded.Add(graded);
            if (!_conceptsAnswered.Contains(graded.Concept)) _conceptsAnswered.Add(graded.Concept);
            _usedIds.Add(_current.Question.id);

            if (!graded.Correct && (_rules.ReboundOnWrong || _rules.BlocksOnWrong))
            {
                InsertRebound(graded.Concept);
            }

            Advance();
            return graded;
        }

        /// <summary>The result so far. Valid mid-trial, which is what the HUD wants.</summary>
        public TrialResult Result()
        {
            TrialResult result = new TrialResult();
            result.MilestoneIndex = _milestone != null ? _milestone.Index : 0;
            result.Correct = CorrectCount;
            result.Total = _graded.Count;
            result.DurationSeconds = _elapsedMs / 1000f;
            result.HintsUsed = _hintsUsed;
            for (int i = 0; i < _conceptsAnswered.Count; i++) result.ConceptsAttempted.Add(_conceptsAnswered[i]);
            result.ConceptsAttempted.Sort(StringComparer.Ordinal);
            return result;
        }

        // ------------------------------------------------------------------
        // Assembly
        // ------------------------------------------------------------------
        private List<string> OwnConcepts(KnowledgeEngine engine, Milestone milestone)
        {
            List<string> own = new List<string>();
            if (milestone.Concepts != null)
            {
                for (int i = 0; i < milestone.Concepts.Count; i++)
                {
                    if (engine.QuestionCount(milestone.Concepts[i]) > 0) own.Add(milestone.Concepts[i]);
                }
            }
            if (own.Count > 0) return own;

            // Content gap: fall back to the rest of the milestone's domain so the
            // trial still runs against something relevant, instead of refusing the
            // player entry to a milestone they have already reached.
            List<ConceptData> domain = engine.Graph.ConceptsOfDomain(milestone.Domain);
            for (int i = 0; i < domain.Count; i++)
            {
                if (engine.QuestionCount(domain[i].id) > 0) own.Add(domain[i].id);
            }
            return own;
        }

        private List<string> ExtraConcepts(
            KnowledgeEngine engine, Milestone milestone, IList<Milestone> milestones, List<string> own)
        {
            List<string> extra = new List<string>();
            if (!_rules.Breadth || milestones == null) return extra;

            List<string> through = MilestoneCatalog.ConceptsThrough(new List<Milestone>(milestones), milestone.Index);
            for (int i = 0; i < through.Count; i++)
            {
                string concept = through[i];
                if (own.Contains(concept)) continue;
                if (engine.QuestionCount(concept) <= 0) continue;
                if (extra.Contains(concept)) continue;
                extra.Add(concept);
            }

            // Aim the breadth questions at whatever the player is worst at.
            if (_rules.AimWeakest)
            {
                KnowledgeTracer tracer = engine.Tracer;
                extra.Sort(delegate (string a, string b)
                {
                    return tracer.Get(a).Mastery().CompareTo(tracer.Get(b).Mastery());
                });
            }
            return extra;
        }

        private List<string> FillPool(KnowledgeEngine engine, List<string> own, List<string> extra)
        {
            if (extra.Count == 0) return own;
            if (!_rules.AimWeakest) return extra;

            // A boss or championship looks at everything taught so far, weakest
            // chapter first, so the new material competes with the rusty material.
            List<string> combined = new List<string>(own);
            for (int i = 0; i < extra.Count; i++) if (!combined.Contains(extra[i])) combined.Add(extra[i]);
            KnowledgeTracer tracer = engine.Tracer;
            combined.Sort(delegate (string a, string b)
            {
                return tracer.Get(a).Mastery().CompareTo(tracer.Get(b).Mastery());
            });
            return combined;
        }

        /// <summary>
        /// How many questions this milestone's own concepts must get.
        ///
        /// Two questions per concept tops out around 65% mastery, so a milestone
        /// gating at 80 must ask about that concept more than twice — otherwise its
        /// own gate is unpassable by construction, which is a bug rather than a
        /// standard.
        /// </summary>
        private static int GuaranteedCount(int ownCount, int plannedQuestions)
        {
            int byConcept = 2 * ownCount;
            int byShare = (int)Math.Round(plannedQuestions * 0.5);
            return Math.Min(plannedQuestions, Math.Max(byConcept, byShare));
        }

        private void Append(List<BankQuestion> questions, string reason, bool rebound)
        {
            for (int i = 0; i < questions.Count; i++)
            {
                BankQuestion question = questions[i];
                if (question == null) continue;
                if (_usedIds.Contains(question.id)) continue;
                _usedIds.Add(question.id);

                TrialStep step = new TrialStep();
                step.Question = question;
                step.Concept = question.concept;
                step.Reason = reason;
                step.IsRebound = rebound;
                step.Difficulty = question.difficulty;
                _steps.Add(step);
            }
        }

        private string DescribeSource(List<string> pool, List<string> own)
        {
            if (_rules.AimWeakest) return "your weakest chapter so far";
            if (pool.Count > own.Count) return "everything taught so far";
            return "the chapter just taught";
        }

        private List<BankQuestion> Draw(
            KnowledgeEngine engine,
            List<string> pool,
            int count,
            List<string> preferMisconceptions,
            bool allowRecent)
        {
            List<BankQuestion> picked = new List<BankQuestion>();
            if (count <= 0 || pool == null || pool.Count == 0) return picked;

            List<string> exclude = new List<string>();
            if (!allowRecent)
            {
                // Keep the last few trials from repeating their items verbatim.
                int start = Math.Max(0, _recentIds.Count - 60);
                for (int i = start; i < _recentIds.Count; i++) exclude.Add(_recentIds[i]);
            }
            foreach (string id in _usedIds) exclude.Add(id);

            Dictionary<string, int> targets = new Dictionary<string, int>();
            for (int i = 0; i < pool.Count; i++)
            {
                if (!targets.ContainsKey(pool[i])) targets[pool[i]] = TargetDifficulty(engine, pool[i]);
            }

            QuestionSelection selection = engine.Select(pool, count, exclude, preferMisconceptions, targets);
            if (selection != null && selection.Questions != null) picked.AddRange(selection.Questions);
            return picked;
        }

        /// <summary>
        /// The hidden difficulty for one concept in this trial.
        ///
        /// The base is the engine's adaptive estimate. The mechanic then tilts it:
        /// a lesson comes in softer, a championship harder, and the endurance run
        /// climbs from the first item to the last.
        /// </summary>
        private int TargetDifficulty(KnowledgeEngine engine, string concept)
        {
            int baseTarget;
            if (_rules.PinToLevel)
            {
                ConceptData data = engine.Graph.Concept(concept);
                baseTarget = data != null ? data.level : 2;
            }
            else
            {
                baseTarget = engine.TargetDifficulty(concept);
            }

            if (_rules.Ramps)
            {
                int planned = Math.Max(1, _mode.questions);
                float span = (float)_steps.Count / Math.Max(1, planned - 1);
                baseTarget = 1 + (int)Math.Round(4f * span);
            }

            return Clamp(baseTarget + _rules.DifficultyOffset, 1, 5);
        }

        // ------------------------------------------------------------------
        // Sequencing
        // ------------------------------------------------------------------
        /// <summary>
        /// Order the assembled steps according to the mechanic.
        ///
        /// Reordering never changes *what* is asked, only when. Only the mechanics
        /// that are explicitly about sequence or escalation touch it, and the
        /// milestone's own concepts keep their early positions.
        /// </summary>
        private void Sequence(Milestone milestone, IList<Milestone> milestones)
        {
            if (_rules.Ramps)
            {
                _steps.Sort(delegate (TrialStep a, TrialStep b) { return a.Difficulty.CompareTo(b.Difficulty); });
                for (int i = 0; i < _steps.Count; i++) _steps[i].Round = i + 1;
                return;
            }

            if (_mode.mechanic == "seeded_chain" || _mode.mechanic == "assemble_clues")
            {
                // Cycle the concepts so consecutive items are not the same idea
                // twice, which is what makes a chain feel like a chain.
                List<TrialStep> ordered = new List<TrialStep>();
                List<string> seen = new List<string>();
                for (int pass = 0; pass < 4; pass++)
                {
                    for (int i = 0; i < _steps.Count; i++)
                    {
                        TrialStep step = _steps[i];
                        if (ordered.Contains(step)) continue;
                        if (seen.Contains(step.Concept)) continue;
                        seen.Add(step.Concept);
                        ordered.Add(step);
                    }
                    seen.Clear();
                }
                for (int i = 0; i < _steps.Count; i++) if (!ordered.Contains(_steps[i])) ordered.Add(_steps[i]);
                _steps.Clear();
                _steps.AddRange(ordered);
                for (int i = 0; i < _steps.Count; i++) _steps[i].Round = i + 1;
                return;
            }

            if (_mode.mechanic == "order_the_steps")
            {
                // Curriculum order: the steps of the working, in the order the
                // realm teaches them. You cannot skip a step.
                _steps.Sort(delegate (TrialStep a, TrialStep b)
                {
                    int order = CurriculumIndex(milestone, a.Concept).CompareTo(CurriculumIndex(milestone, b.Concept));
                    return order != 0 ? order : string.CompareOrdinal(a.Question.id, b.Question.id);
                });
                for (int i = 0; i < _steps.Count; i++) _steps[i].Round = i + 1;
                return;
            }

            if (_mode.mechanic == "mixed_bracket")
            {
                // Pairs of questions form the rounds of the bracket. The pairing is
                // presentation, but the player should be told which round they are
                // in, so it is computed here rather than guessed at by the UI.
                for (int i = 0; i < _steps.Count; i++) _steps[i].Round = (i / 2) + 1;
            }
        }

        private static int CurriculumIndex(Milestone milestone, string concept)
        {
            if (milestone.Concepts == null) return int.MaxValue;
            int index = milestone.Concepts.IndexOf(concept);
            return index >= 0 ? index : int.MaxValue;
        }

        /// <summary>
        /// Re-ask the concept that was just missed, with a fresh item.
        ///
        /// This is how a propagated mistake works: the chain did not merely lose a
        /// point, the link has to be rebuilt before the trial continues. Returns
        /// false when the bank has nothing else for that concept, because a content
        /// gap must not turn into a soft-lock.
        /// </summary>
        private bool InsertRebound(string concept)
        {
            if (_steps.Count >= _mode.questions * MaxQuestionMultiplier) return false;

            Dictionary<string, int> targets = new Dictionary<string, int>();
            targets[concept] = _current != null ? _current.Difficulty : TargetDifficulty(_engine, concept);

            List<string> pool = new List<string>();
            pool.Add(concept);

            List<BankQuestion> drawn = Draw(_engine, pool, 1, _engine.ActiveMisconceptionIds(_milestone.Realm), true);
            if (drawn.Count == 0) return false;

            TrialStep rebound = new TrialStep();
            rebound.Question = drawn[0];
            rebound.Concept = concept;
            rebound.Difficulty = drawn[0].difficulty;
            rebound.IsRebound = true;
            rebound.Reason = "the link broke here and must be rebuilt";
            rebound.Round = _round;

            _steps.Insert(_position + 1, rebound);
            _usedIds.Add(drawn[0].id);
            return true;
        }

        private void Advance()
        {
            _position++;
            while (_position < _steps.Count)
            {
                TrialStep step = _steps[_position];
                if (step.Question == null || string.IsNullOrEmpty(step.Question.id))
                {
                    _position++;
                    continue;
                }
                step.Position = _position + 1;
                if (step.Round <= 0) step.Round = Math.Max(1, _round);
                _round = step.Round;
                step.Prompt = PromptFor(step);
                _current = step;
                return;
            }

            _current = null;
            _finished = true;
        }

        // ------------------------------------------------------------------
        // Framing
        // ------------------------------------------------------------------
        /// <summary>The scene-setting line that turns a question into an event.</summary>
        public string Intro()
        {
            if (_milestone == null || _mode == null) return string.Empty;
            string place = _milestone.Place;
            string keeper = _milestone.Keeper;
            switch (_mode.mechanic)
            {
                case "teach_then_ask":
                    return keeper + " does not test you. " + keeper + " explains, then asks it straight back.";
                case "solve_to_open":
                    return "The mechanisms at " + place + " are seized. Nothing moves until the values are right.";
                case "countdown_duel":
                    return "The clock at " + place + " starts when the first question does. " + keeper + " is timing fluency.";
                case "justify_step":
                    return "At " + place + ", more than one answer will look workable. Only one step is justified.";
                case "mixed_bracket":
                    return "The bracket at " + place + " is drawn from everything you have learned.";
                case "assemble_clues":
                    return "The clues at " + place + " do not reveal themselves in order. Each right answer opens the next.";
                case "find_the_error":
                    return "Every solution in " + place + "'s record has been broken in one way. Name the break.";
                case "escalating_run":
                    return "The path out of " + place + " is long, and it gets harder the further you go. Begin rested.";
                case "seeded_chain":
                    return "A chain of keepers waits along the road from " + place + ". Your answer is the next one's question.";
                case "order_the_steps":
                    return keeper + " hands you the steps of a working thing, out of order. Build it.";
                case "boss_encounter":
                    return keeper + " takes the field at " + place + " to find out what you actually kept.";
                case "championship":
                    return "The realm puts its championship at " + place + " in front of you: every domain, at the hardest level you can hold.";
                default:
                    return _mode.description;
            }
        }

        private string PromptFor(TrialStep step)
        {
            if (step.IsRebound)
            {
                return "The link broke. " + _milestone.Keeper + " holds it out again:";
            }

            switch (_mode.mechanic)
            {
                case "assemble_clues":
                    return "Clue " + step.Position + " of " + _steps.Count + " \u2014 drawn from " + DisplayConcept(step) + ".";
                case "seeded_chain":
                    return "Link " + step.Position + " of " + _steps.Count + " \u2014 " + DisplayConcept(step) + ".";
                case "order_the_steps":
                    return "Step " + step.Position + " of " + _steps.Count + " \u2014 " + DisplayConcept(step) + ".";
                case "mixed_bracket":
                    return "Bracket round " + step.Round + " \u2014 " + DisplayConcept(step) + ".";
                case "escalating_run":
                    return "Station " + step.Position + " of " + _steps.Count + ". It will not get easier.";
                case "find_the_error":
                    return "Find the break \u2014 " + DisplayConcept(step) + ".";
                case "countdown_duel":
                    return SecondsPerQuestion + " seconds. " + DisplayConcept(step) + ".";
                case "justify_step":
                    return "Which step is justified? \u2014 " + DisplayConcept(step) + ".";
                case "championship":
                case "boss_encounter":
                    return DisplayConcept(step) + " \u2014 " + step.Reason + ".";
                default:
                    return DisplayConcept(step);
            }
        }

        private string DisplayConcept(TrialStep step)
        {
            ConceptData concept = _engine != null ? _engine.Graph.Concept(step.Concept) : null;
            return concept != null ? concept.name : step.Concept;
        }

        private static int Clamp(int value, int lo, int hi)
        {
            return value < lo ? lo : (value > hi ? hi : value);
        }
    }
}
