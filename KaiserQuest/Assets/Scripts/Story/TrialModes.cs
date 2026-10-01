using System;
using System.Collections.Generic;
using UnityEngine;

namespace KaiserQuest.Story
{
    /// <summary>
    /// A way of examining someone.
    ///
    /// Twenty identical quizzes with different names is the failure mode this whole
    /// design exists to avoid, so each milestone runs a different mechanic: a guided
    /// lesson, a mechanism you solve to open the world, a duel against a clock,
    /// reasoning that must be justified, a bracket, an investigation, a diagnosis of
    /// broken working, an endurance run, a chain, a construction, a boss, and a
    /// championship.
    /// </summary>
    [Serializable]
    public class TrialMode
    {
        public string id;
        public int questions;
        public float passRatio;
        public int secondsPerQuestion;
        public int hintsAllowed;
        public string stakes;
        public string mechanic;
        public string description;

        public int RequiredCorrect
        {
            get { return Mathf.Max(1, Mathf.CeilToInt(questions * passRatio)); }
        }
    }

    public static class TrialModes
    {
        private static readonly Dictionary<string, TrialMode> Table = Build();

        public static TrialMode Get(string id)
        {
            TrialMode mode;
            return Table.TryGetValue(id, out mode) ? mode : Table["applied"];
        }

        public static bool Has(string id)
        {
            return Table.ContainsKey(id);
        }

        public static ICollection<string> Ids
        {
            get { return Table.Keys; }
        }

        private static Dictionary<string, TrialMode> Build()
        {
            Dictionary<string, TrialMode> table = new Dictionary<string, TrialMode>();

            table["guided"] = Mode("guided", 4, 0.5f, 0, 9, "none", "teach_then_ask",
                "A keeper walks you through each idea, then asks it straight back. You cannot fail.");

            table["applied"] = Mode("applied", 5, 0.6f, 0, 1, "world", "solve_to_open",
                "The answers are the mechanism. Solve the puzzle and the world physically opens.");

            table["timed"] = Mode("timed", 6, 0.7f, 20, 0, "duel", "countdown_duel",
                "A duel against a clock. Fluency is the thing being tested here.");

            table["reasoning"] = Mode("reasoning", 5, 0.7f, 0, 1, "puzzle", "justify_step",
                "Several answers could work. You must say which step is justified and why.");

            table["tournament"] = Mode("tournament", 8, 0.7f, 0, 1, "tournament", "mixed_bracket",
                "Everything learned so far, shuffled, in brackets. Breadth over depth.");

            table["investigation"] = Mode("investigation", 5, 0.7f, 0, 1, "mystery", "assemble_clues",
                "Clues are strewn through the scene. Each correct answer reveals the next.");

            table["diagnosis"] = Mode("diagnosis", 5, 0.7f, 0, 1, "repair", "find_the_error",
                "Worked solutions are placed in front of you, each with one flaw. Find it.");

            table["gauntlet"] = Mode("gauntlet", 12, 0.75f, 0, 0, "health", "escalating_run",
                "A long run. Every question harder than the last, no hints, real cost to failing.");

            table["chain"] = Mode("chain", 6, 0.7f, 0, 1, "ritual", "seeded_chain",
                "Each answer becomes part of the next question. A mistake propagates.");

            table["construct"] = Mode("construct", 4, 0.7f, 0, 1, "craft", "order_the_steps",
                "Knowledge is not just recognition: you assemble the steps into a working whole.");

            table["boss"] = Mode("boss", 10, 0.8f, 0, 0, "boss", "boss_encounter",
                "A named adversary who is testing exactly what you are weakest at.");

            table["champion"] = Mode("champion", 15, 0.85f, 0, 0, "championship", "championship",
                "The realm championship: every domain, at the hardest level you can hold.");

            table["grand_tournament"] = Mode("grand_tournament", 10, 0.8f, 0, 0, "tournament", "mixed_bracket",
                "The regional bracket: every chapter of the realm, drawn at random, at full difficulty.");

            return table;
        }

        private static TrialMode Mode(
            string id, int questions, float passRatio, int secondsPerQuestion, int hintsAllowed,
            string stakes, string mechanic, string description)
        {
            TrialMode mode = new TrialMode();
            mode.id = id;
            mode.questions = questions;
            mode.passRatio = passRatio;
            mode.secondsPerQuestion = secondsPerQuestion;
            mode.hintsAllowed = hintsAllowed;
            mode.stakes = stakes;
            mode.mechanic = mechanic;
            mode.description = description;
            return mode;
        }
    }
}
