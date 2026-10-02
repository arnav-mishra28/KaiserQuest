using System.Collections;
using System.Collections.Generic;
using KaiserQuest.Story;
using NUnit.Framework;
using UnityEngine.TestTools;

/// <summary>
/// The mastery gate, as a player meets it: one open milestone, the rest shut, and
/// a refusal that says why. These are the rules the whole campaign rests on — a
/// level gate would let a player grind past a chapter they never understood, and
/// the game is not allowed to become that.
/// </summary>
public class MasteryGateTests
{
    [UnityTearDown]
    public IEnumerator TearDown()
    {
        StoryTestBed.Shutdown();
        yield return null;
    }

    [UnityTest]
    public IEnumerator AFreshCampaignHasTwentyMilestonesAndOnlyTheFirstIsOpen()
    {
        yield return StoryTestBed.Boot();

        CampaignDetail detail = StoryTestBed.Story.CampaignDetail(StoryTestBed.Realm);

        Assert.AreEqual(20, detail.Total, "the campaign is not twenty milestones long");
        Assert.IsNotNull(detail.Current, "the campaign has no current milestone");
        Assert.AreEqual(1, detail.Current.Index, "a new campaign does not start at the first milestone");

        int open = 0;
        for (int i = 0; i < detail.Milestones.Count; i++)
        {
            if (detail.Milestones[i].State == "available") open++;
            if (detail.Milestones[i].State == "cleared")
                Assert.Fail("a new campaign already has a cleared milestone");
        }

        Assert.AreEqual(1, open, "more than one milestone is open at the start of the campaign");
    }

    [UnityTest]
    public IEnumerator TheFirstMilestoneIsAlwaysEnterable()
    {
        yield return StoryTestBed.Boot();

        EntryCheck entry;
        string error;
        TrialRunner runner = StoryTestBed.Story.StartTrial(StoryTestBed.Realm, 1, out entry, out error);

        Assert.IsTrue(entry.Allowed, "the first milestone refused entry: " + error);
        Assert.IsNotNull(runner, "the first milestone could not start: " + error);
    }

    [UnityTest]
    public IEnumerator SkippingAheadIsRefusedInWordsNotPadlocks()
    {
        yield return StoryTestBed.Boot();

        EntryCheck entry;
        string error;
        TrialRunner runner = StoryTestBed.Story.StartTrial(StoryTestBed.Realm, 7, out entry, out error);

        Assert.IsNull(runner, "the seventh milestone opened while the first is unpassed");
        Assert.IsNotNull(entry, "a refused entry produced no explanation at all");
        Assert.IsFalse(entry.Allowed, "the entry check allowed a milestone it should have shut");
        Assert.IsNotEmpty(entry.Reasons, "the gate refused entry without saying why");
        Assert.IsNotEmpty(error, "the refusal gave the caller nothing to say to the player");
    }

    [UnityTest]
    public IEnumerator PassingTheFirstMilestoneOpensTheRoad()
    {
        yield return StoryTestBed.Boot();

        StoryModeManager story = StoryTestBed.Story;
        TrialSettlement settlement = StoryTestBed.PlayTrial(StoryTestBed.Realm, 1, true);
        Assert.IsTrue(settlement.Passed, "a flawless first trial did not pass: " + settlement.Outcome.Feedback);

        CampaignDetail detail = story.CampaignDetail(StoryTestBed.Realm);

        Assert.IsTrue(story.Progress(StoryTestBed.Realm).HasPassed(1),
            "the campaign does not remember that the first milestone was passed");
        Assert.Greater(detail.PassedCount, 0, "the campaign detail reports nothing passed");
        Assert.GreaterOrEqual(detail.Current.Index, 2, "the campaign did not move past the first milestone");

        List<MilestoneState> states = detail.Milestones;
        Assert.AreEqual("cleared", states[0].State, "the passed milestone is not marked cleared");
        Assert.AreNotEqual("locked", states[1].State,
            "the milestone right after a passed one is still locked, so the road never opens");
    }
}
