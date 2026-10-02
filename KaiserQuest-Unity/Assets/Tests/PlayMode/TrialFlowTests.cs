using System.Collections;
using KaiserQuest.Story;
using NUnit.Framework;
using UnityEngine.TestTools;

/// <summary>
/// Playing a trial, end to end, against the real engine and the real bank.
/// </summary>
public class TrialFlowTests
{
    [UnityTearDown]
    public IEnumerator TearDown()
    {
        StoryTestBed.Shutdown();
        yield return null;
    }

    [UnityTest]
    public IEnumerator AFlawlessTrialPassesAndMovesTheSavePoint()
    {
        yield return StoryTestBed.Boot();

        StoryModeManager story = StoryTestBed.Story;
        TrialSettlement settlement = StoryTestBed.PlayTrial(StoryTestBed.Realm, 1, true);

        Assert.IsTrue(settlement.Passed,
            "a flawless trial of the first milestone did not pass: " + Describe(settlement));
        Assert.IsTrue(settlement.MovedSavePoint,
            "passing a milestone must move the save point; that is what makes the world the map");
        Assert.AreEqual(1, story.Save.savePoint.milestoneIndex,
            "the save point did not move to the milestone that was just passed");
        Assert.IsTrue(story.Progress(StoryTestBed.Realm).HasPassed(1),
            "the passed milestone was not recorded in the realm's progress");
    }

    [UnityTest]
    public IEnumerator AQuestionCannotBeAnsweredTwiceAndAnswersCarryTheConcept()
    {
        yield return StoryTestBed.Boot();

        EntryCheck entry;
        string error;
        TrialRunner runner = StoryTestBed.Story.StartTrial(StoryTestBed.Realm, 1, out entry, out error);
        Assert.IsNotNull(runner, "the first trial did not start: " + error);

        int answered = 0;
        while (!runner.IsComplete && answered < 400)
        {
            Assert.IsNotNull(runner.Current, "the trial ended without a step to answer");
            Assert.IsNotNull(runner.Current.Question, "a step arrived with no question");

            // Every item must name the concept it examines: the mastery gate and the
            // mastery recap are both built from that name, and a question that cannot
            // say what it tests can never be used to teach anything.
            Assert.IsFalse(string.IsNullOrEmpty(runner.Current.Concept),
                "a trial step did not name the concept it examines");

            var graded = runner.Answer(runner.Current.Question.correctAnswer, 1200f, 0);
            Assert.IsTrue(graded.Correct, "the bank's own answer was graded as wrong");
            Assert.IsFalse(string.IsNullOrEmpty(graded.ConceptName),
                "a graded answer did not report the concept it was about");
            Assert.GreaterOrEqual(graded.MasteryAfter, 0f);

            answered++;
            Assert.AreEqual(answered, runner.Answered, "the runner did not count the answer");
        }

        Assert.IsTrue(runner.IsComplete, "the trial did not finish");
        Assert.Greater(runner.PlannedTotal, 0, "the trial planned no questions");
    }

    [UnityTest]
    public IEnumerator AFailedTrialIsNotPassedAndDoesNotMoveTheSavePoint()
    {
        yield return StoryTestBed.Boot();

        StoryModeManager story = StoryTestBed.Story;
        int startIndex = story.Save.savePoint.milestoneIndex;

        TrialSettlement settlement = StoryTestBed.PlayTrial(StoryTestBed.Realm, 1, false);

        Assert.IsNotNull(settlement.Outcome, "a failed trial produced no verdict");
        Assert.IsFalse(settlement.Passed, "answering everything wrong passed a milestone");
        Assert.IsFalse(settlement.MovedSavePoint, "a failed trial moved the save point");
        Assert.AreEqual(startIndex, story.Save.savePoint.milestoneIndex,
            "a failed trial moved the player somewhere else");
        Assert.GreaterOrEqual(story.Progress(StoryTestBed.Realm).AttemptsFor(1), 1,
            "the failed attempt was not recorded against the milestone");
    }

    [UnityTest]
    public IEnumerator AWrongAnswerTeachesRatherThanMerelyMarking()
    {
        yield return StoryTestBed.Boot();

        EntryCheck entry;
        string error;
        TrialRunner runner = StoryTestBed.Story.StartTrial(StoryTestBed.Realm, 1, out entry, out error);
        Assert.IsNotNull(runner, "the first trial did not start: " + error);

        var graded = runner.Answer(StoryTestBed.WrongAnswerFor(runner.Current.Question), 900f, 0);

        Assert.IsFalse(graded.Correct, "a wrong answer was graded correct");
        Assert.IsFalse(string.IsNullOrEmpty(graded.CorrectAnswer),
            "a wrong answer did not report what the right answer was");
        Assert.IsFalse(string.IsNullOrEmpty(graded.Explanation),
            "a wrong answer came with no explanation; the game is supposed to teach, not just mark");
    }

    private static string Describe(TrialSettlement settlement)
    {
        if (settlement == null || settlement.Outcome == null) return "no verdict was produced";

        MilestoneOutcome outcome = settlement.Outcome;
        return "score " + outcome.ScorePercent.ToString("0.#") + "% (needed "
               + outcome.RequiredPercent.ToString("0.#") + "%), mastery coverage "
               + outcome.MasteryCoverage.ToString("0.#") + ", blocked by "
               + outcome.BlockedBy.Count + " concept(s). " + outcome.Feedback;
    }
}
