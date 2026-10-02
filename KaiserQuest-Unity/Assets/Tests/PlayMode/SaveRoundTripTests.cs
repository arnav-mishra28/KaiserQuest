using System.Collections;
using KaiserQuest.Story;
using NUnit.Framework;
using UnityEngine.TestTools;

/// <summary>
/// The save is the player's knowledge, and it must survive being written and read
/// back — including the save *point*, which is a place in the world the player is
/// returned to rather than a bookmark in a menu.
/// </summary>
public class SaveRoundTripTests
{
    [UnityTearDown]
    public IEnumerator TearDown()
    {
        StoryTestBed.Shutdown();
        yield return null;
    }

    [UnityTest]
    public IEnumerator ANewGameWritesASaveThatReadsBackIdentical()
    {
        yield return StoryTestBed.Boot();

        StoryModeManager story = StoryTestBed.Story;
        SaveGameData created = story.Save;

        Assert.IsNotNull(created, "a new game produced no save data");
        Assert.IsTrue(story.SaveNow(), "the save could not be written");
        Assert.IsTrue(story.HasSave(StoryTestBed.Slot), "the written save is not on disk");

        SaveGameData read = story.LoadGame(StoryTestBed.Slot);

        Assert.IsNotNull(read, "the save on disk could not be read back");
        Assert.AreEqual(created.playerName, read.playerName, "the player's name did not survive the round trip");
        Assert.AreEqual(created.appearanceId, read.appearanceId, "the chosen appearance did not survive");
        Assert.AreEqual(created.realm, read.realm, "the realm did not survive");
        Assert.IsNotNull(read.savePoint, "the save came back with no save point");
        Assert.AreEqual(created.savePoint.place, read.savePoint.place, "the save point's place changed");
        Assert.AreEqual(created.savePoint.milestoneIndex, read.savePoint.milestoneIndex,
            "the save point's milestone changed");
    }

    [UnityTest]
    public IEnumerator PassingAMilestoneIsStillTrueAfterAReload()
    {
        yield return StoryTestBed.Boot();

        StoryModeManager story = StoryTestBed.Story;
        TrialSettlement settlement = StoryTestBed.PlayTrial(StoryTestBed.Realm, 1, true);
        Assert.IsTrue(settlement.Passed, "a flawless first trial did not pass");

        SavePointData banked = story.Save.savePoint;
        Assert.IsTrue(story.SaveNow(), "the save after passing could not be written");

        story.LoadGame(StoryTestBed.Slot);

        Assert.IsTrue(story.Progress(StoryTestBed.Realm).HasPassed(1),
            "the passed milestone was forgotten on reload");
        Assert.AreEqual(banked.milestoneIndex, story.Save.savePoint.milestoneIndex,
            "the save point moved on reload");
        Assert.AreEqual(banked.place, story.Save.savePoint.place, "the save point's place changed on reload");
    }

    [UnityTest]
    public IEnumerator DeletingASaveRemovesIt()
    {
        yield return StoryTestBed.Boot();

        StoryModeManager story = StoryTestBed.Story;
        story.SaveNow();
        Assert.IsTrue(story.HasSave(StoryTestBed.Slot), "the save was never written");

        Assert.IsTrue(SaveSystem.Delete(StoryTestBed.Slot), "the save could not be deleted");
        Assert.IsFalse(story.HasSave(StoryTestBed.Slot), "the deleted save is still reported as present");
    }
}
