using System.Collections;
using System.Collections.Generic;
using KaiserQuest.Knowledge;
using KaiserQuest.Story;
using NUnit.Framework;
using UnityEngine.TestTools;

/// <summary>
/// The content has to arrive. The game shipped once loading `bank_algebra.json` —
/// a file that does not exist, because banks are named by subject (`math`) while
/// campaigns are played by realm (`algebra`) — and the result was a game that
/// booted, let you create a character, walk the world, and then refused every
/// keeper for want of questions. Nothing in the suite noticed, because nothing
/// asserted that a trial could actually start.
/// </summary>
public class ContentLoadingTests
{
    [UnityTearDown]
    public IEnumerator TearDown()
    {
        StoryTestBed.Shutdown();
        yield return null;
    }

    [UnityTest]
    public IEnumerator TheVerifiedBankIsLoaded()
    {
        yield return StoryTestBed.Boot(false);

        KnowledgeEngine engine = StoryTestBed.Engine;
        Assert.Greater(engine.BankSize, 0,
            "the engine loaded no questions at all: every trial would be refused");
        Assert.Greater(engine.Graph.ConceptCount, 0, "the concept graph is empty");
    }

    [UnityTest]
    public IEnumerator EveryRealmHasQuestionsForItsConcepts()
    {
        yield return StoryTestBed.Boot(false);

        KnowledgeEngine engine = StoryTestBed.Engine;
        List<string> barren = new List<string>();

        foreach (RealmData realm in engine.Graph.Realms)
        {
            int questions = 0;
            foreach (ConceptData concept in engine.Graph.ConceptsOfRealm(realm.id))
                questions += engine.QuestionCount(concept.id);

            if (questions == 0) barren.Add(realm.id + " (" + realm.name + ")");
        }

        Assert.IsEmpty(barren,
            "these realms have no questions for any of their concepts, so their campaigns cannot "
            + "be played at all: " + string.Join(", ", barren));
    }

    [UnityTest]
    public IEnumerator EveryRealmCanStartItsFirstMilestone()
    {
        yield return StoryTestBed.Boot();

        StoryModeManager story = StoryTestBed.Story;
        KnowledgeEngine engine = StoryTestBed.Engine;
        List<string> refused = new List<string>();

        foreach (RealmData realm in engine.Graph.Realms)
        {
            story.NewGame("Test Explorer", CharacterCreation.DefaultAppearanceId, realm.id);

            EntryCheck entry;
            string error;
            TrialRunner runner = story.StartTrial(realm.id, 1, out entry, out error);

            if (runner == null) refused.Add(realm.id + ": " + error);
            else if (runner.PlannedTotal == 0) refused.Add(realm.id + ": the trial planned no questions");
        }

        Assert.IsEmpty(refused,
            "these realms cannot open their own first milestone: " + string.Join(" | ", refused));
    }
}
