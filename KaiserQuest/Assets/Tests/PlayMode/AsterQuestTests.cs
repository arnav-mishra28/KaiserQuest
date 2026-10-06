using System.Collections;
using System.Collections.Generic;
using KaiserQuest.Knowledge;
using KaiserQuest.Story;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;

/// <summary>
/// The first thirty minutes, asserted.
///
/// The vertical slice is: Aster Town exists and is a place, an NPC hands you a
/// reason to go east, the eastern gate asks a real question from the verified bank,
/// a wrong answer teaches without opening it, a right answer opens it for good, and
/// clearing the first trial earns a sigil that is still there after a reload.
///
/// Every one of these is a behaviour a player feels, so every one of them is
/// asserted against the real engine and the real bank rather than a mock.
/// </summary>
public class AsterQuestTests
{
    private readonly List<GameObject> _spawned = new List<GameObject>();

    [UnityTearDown]
    public IEnumerator TearDown()
    {
        for (int i = 0; i < _spawned.Count; i++)
        {
            if (_spawned[i] != null) Object.DestroyImmediate(_spawned[i]);
        }
        _spawned.Clear();
        ProceduralWorldGeneratorHub.Cities = null;
        StoryTestBed.Shutdown();
        yield return null;
    }

    // ------------------------------------------------------------------
    // Aster Town
    // ------------------------------------------------------------------
    [UnityTest]
    public IEnumerator AsterTownBuildsAPlaceRatherThanAClearing()
    {
        yield return StoryTestBed.Boot(false);

        StoryModeManager story = StoryTestBed.Story;
        string realm = StoryTestBed.Realm;

        AsterTownLayout town = AsterTown.Build(
            Root().transform, realm, story.Campaign(realm), City(new Vector2(4f, -60f)));

        Assert.IsNotNull(town, "Aster Town was not built at all");
        Assert.IsTrue(town.HasGate, "Aster Town has no eastern gate, so there is nothing to walk into");
        Assert.IsTrue(town.HasQuestGiver, "Aster Town has nobody to explain the gate, so there is no quest");
        Assert.GreaterOrEqual(town.BuildingCount, 4,
            "Aster Town is a clearing with props, not a settlement: it has " + town.BuildingCount + " buildings");
        Assert.GreaterOrEqual(town.Signs.Count, 2,
            "Aster Town has no readable signage, so the player cannot tell where they are");
        Assert.IsNotNull(town.Monument, "Aster Town has no landmark to orient by");

        // Every building must be solid. A town the player can walk through is the
        // single clearest sign that a place was never really built.
        for (int i = 0; i < town.Buildings.Count; i++)
        {
            BoxCollider2D collider = town.Buildings[i].GetComponent<BoxCollider2D>();
            Assert.IsNotNull(collider, "a building in Aster Town has no collider — its walls are scenery");
            Assert.IsFalse(collider.isTrigger, "a building in Aster Town is a trigger, so the player walks through it");
        }
    }

    [UnityTest]
    public IEnumerator TheWorldPopulatorStandsAsterTownInTheStartingCity()
    {
        yield return StoryTestBed.Boot();

        List<GeneratedCity> cities = new List<GeneratedCity>();
        cities.Add(City(new Vector2(0f, 0f)));
        cities.Add(City(new Vector2(40f, 40f)));
        ProceduralWorldGeneratorHub.Cities = cities;

        Add(new GameObject("Test_WorldPopulator")).AddComponent<KaiserWorldPopulator>();

        yield return StoryTestBed.WaitUntil(
            () => GameObject.Find("AsterTown") != null, 20f,
            "the world was populated without building Aster Town in the starting settlement");

        KnowledgeGate gate = Object.FindObjectOfType<KnowledgeGate>();
        Assert.IsNotNull(gate, "Aster Town was built without its eastern gate");
        Assert.IsFalse(gate.IsOpen, "the eastern gate starts open, so the first quest has nothing to ask");
        Assert.IsTrue(gate.GetComponent<BoxCollider2D>().enabled,
            "the seized gate is not solid, so it was never really blocking anything");

        Assert.IsNotNull(Object.FindObjectOfType<QuestGiver>(),
            "Aster Town was built without the NPC who starts the first quest");
    }

    [UnityTest]
    public IEnumerator TheCampaignOpensInAsterTown()
    {
        yield return StoryTestBed.Boot(false);

        KnowledgeEngine engine = StoryTestBed.Engine;
        Assert.IsNotEmpty(engine.Graph.Realms, "the concept graph has no realms");

        for (int r = 0; r < engine.Graph.Realms.Count; r++)
        {
            string realm = engine.Graph.Realms[r].id;
            List<Milestone> milestones = MilestoneCatalog.Build(engine.Graph, realm);
            Assert.IsNotEmpty(milestones, "realm '" + realm + "' has no campaign");

            Assert.AreEqual(AsterTown.Name, milestones[0].Place,
                "realm '" + realm + "' does not open in " + AsterTown.Name
                + ", so the town the player walks into is not the place the campaign names");
        }
    }

    // ------------------------------------------------------------------
    // The first knowledge encounter
    // ------------------------------------------------------------------
    [UnityTest]
    public IEnumerator TheGateInterrogatesAConceptTheBankCanActuallyExamine()
    {
        yield return StoryTestBed.Boot();

        StoryModeManager story = StoryTestBed.Story;
        KnowledgeEngine engine = StoryTestBed.Engine;

        AsterTownLayout town = AsterTown.Build(
            Root().transform, StoryTestBed.Realm, story.Campaign(StoryTestBed.Realm), City(Vector2.zero));

        Milestone opening = town.EastGate.MilestoneFor(story);
        Assert.IsNotNull(opening, "the eastern gate belongs to no milestone");

        string concept = AsterQuest.OpeningConcept(engine, opening);
        Assert.IsFalse(string.IsNullOrEmpty(concept),
            "the gate has no concept it can examine, so it could never open");
        Assert.Greater(engine.QuestionCount(concept), 0,
            "the gate's concept has no questions behind it, so the gate is unopenable by construction");
    }

    [UnityTest]
    public IEnumerator TheGateAsksOnlyQuestionsFromTheVerifiedBank()
    {
        yield return StoryTestBed.Boot();

        KnowledgeEngine engine = StoryTestBed.Engine;
        string concept = AsterQuest.OpeningConcept(
            engine, StoryTestBed.Story.Campaign(StoryTestBed.Realm)[0]);

        KnowledgeEncounter encounter = new KnowledgeEncounter();
        bool begun = encounter.Begin(
            engine, concept, StoryTestBed.Realm, StoryTestBed.Story.Save.recentQuestionIds);

        Assert.IsTrue(begun, "the gate could not put a question in front of the player");
        Assert.IsNotNull(encounter.Question, "the encounter began with no question");
        Assert.AreEqual(concept, encounter.Question.concept,
            "the gate asked about a concept other than the one it said it was asking about");

        // The item must be one the bank actually holds. A question invented by the
        // story layer is a question nobody verified.
        BankQuestion fromBank = engine.GetQuestion(encounter.Question.id);
        Assert.IsNotNull(fromBank, "the gate's question is not in the verified bank");
        Assert.AreSame(encounter.Question, fromBank, "the gate did not use the bank's own item");
    }

    [UnityTest]
    public IEnumerator TheRightAnswerOpensTheMechanismAndIsRecordedAsLearning()
    {
        yield return StoryTestBed.Boot();

        KnowledgeEngine engine = StoryTestBed.Engine;
        StoryModeManager story = StoryTestBed.Story;

        string concept = AsterQuest.OpeningConcept(engine, story.Campaign(StoryTestBed.Realm)[0]);
        int attemptsBefore = engine.Tracer.Get(concept).Attempts;

        KnowledgeEncounter encounter = new KnowledgeEncounter();
        Assert.IsTrue(encounter.Begin(engine, concept, StoryTestBed.Realm, null), "the encounter did not begin");

        GradedAnswer graded = encounter.Answer(encounter.Question.correctAnswer, 1500f, 0);

        Assert.IsNotNull(graded, "the mechanism did not grade the answer");
        Assert.IsTrue(graded.Correct, "the bank's own answer was graded as wrong");
        Assert.IsTrue(encounter.Solved, "a correct answer did not satisfy the mechanism");
        Assert.AreEqual(attemptsBefore + 1, engine.Tracer.Get(concept).Attempts,
            "answering the gate did not update the learning state");
    }

    [UnityTest]
    public IEnumerator AWrongAnswerTeachesDoesNotOpenAndUpdatesTheLearningState()
    {
        yield return StoryTestBed.Boot();

        KnowledgeEngine engine = StoryTestBed.Engine;
        StoryModeManager story = StoryTestBed.Story;

        string concept = AsterQuest.OpeningConcept(engine, story.Campaign(StoryTestBed.Realm)[0]);
        int attemptsBefore = engine.Tracer.Get(concept).Attempts;
        int loggedBefore = engine.Log.All.Count;

        KnowledgeEncounter encounter = new KnowledgeEncounter();
        Assert.IsTrue(encounter.Begin(engine, concept, StoryTestBed.Realm, null), "the encounter did not begin");

        string firstQuestion = encounter.Question.id;
        GradedAnswer graded = encounter.Answer(StoryTestBed.WrongAnswerFor(encounter.Question), 900f, 0);

        Assert.IsNotNull(graded, "the mechanism did not grade a wrong answer");
        Assert.IsFalse(graded.Correct, "a wrong answer was graded as correct");
        Assert.IsFalse(encounter.Solved, "a wrong answer opened the mechanism");

        // A wrong answer must teach, not merely mark. The player gets the bank's own
        // explanation and a sentence about where the idea stands.
        Assert.IsFalse(string.IsNullOrEmpty(graded.Explanation),
            "a wrong answer came with no explanation");
        Assert.IsTrue(encounter.Feedback.Contains(graded.Explanation),
            "the mechanism did not pass the explanation on to the player");
        Assert.IsFalse(string.IsNullOrEmpty(encounter.Feedback), "the mechanism said nothing at all");

        Assert.AreEqual(attemptsBefore + 1, engine.Tracer.Get(concept).Attempts,
            "a wrong answer did not reach the learning state");
        Assert.AreEqual(loggedBefore + 1, engine.Log.All.Count,
            "a wrong answer was not recorded in the attempt log");

        // And the retry must be a second attempt at the idea, not a memory test of
        // the sentence that was just read out.
        Assert.IsNotNull(encounter.Question, "the mechanism has no question for the retry");
        Assert.AreNotEqual(firstQuestion, encounter.Question.id,
            "the mechanism re-asked the identical question, so the retry tests recall rather than the idea");
    }

    [UnityTest]
    public IEnumerator AMechanismWithNothingToAskRefusesRatherThanSoftLocking()
    {
        yield return StoryTestBed.Boot();

        KnowledgeEngine engine = StoryTestBed.Engine;

        Milestone barren = new Milestone();
        barren.Concepts.Add("not.a.concept.that.exists");
        Assert.IsNull(AsterQuest.OpeningConcept(engine, barren),
            "the gate claims a concept it cannot examine, which is an unopenable gate");

        KnowledgeEncounter encounter = new KnowledgeEncounter();
        Assert.IsFalse(encounter.Begin(engine, "not.a.concept.that.exists", StoryTestBed.Realm, null),
            "the encounter began on a concept with no questions, so it would hang on a blank screen");
        Assert.IsFalse(encounter.Begun, "an empty encounter reported itself as begun");
    }

    // ------------------------------------------------------------------
    // Persistence and the reward
    // ------------------------------------------------------------------
    [UnityTest]
    public IEnumerator AnOpenedGateIsStillOpenAfterAReload()
    {
        yield return StoryTestBed.Boot();

        StoryModeManager story = StoryTestBed.Story;

        AsterTownLayout town = AsterTown.Build(
            Root().transform, StoryTestBed.Realm, story.Campaign(StoryTestBed.Realm), City(Vector2.zero));
        KnowledgeGate gate = town.EastGate;

        Assert.IsFalse(gate.IsOpen, "a new game starts with the eastern gate already open");

        Assert.IsTrue(gate.Open(), "the gate could not be opened");
        Assert.IsTrue(gate.IsOpen, "the gate did not change when it was opened");
        Assert.IsFalse(gate.GetComponent<BoxCollider2D>().enabled,
            "the opened gate is still solid, so the road did not actually open");
        Assert.IsTrue(story.HasStoryFlag(AsterQuest.GateOpenFlag),
            "opening the gate was not remembered");

        Assert.IsTrue(story.SaveNow(), "the save could not be written");
        story.LoadGame(StoryTestBed.Slot);

        Assert.IsTrue(AsterQuest.Has(story.Save, AsterQuest.GateOpenFlag),
            "the opened gate was forgotten when the save was read back — the world did not really change");

        // And the world rebuilds in the state the save describes.
        AsterTownLayout reopened = AsterTown.Build(
            Root().transform, StoryTestBed.Realm, story.Campaign(StoryTestBed.Realm), City(Vector2.zero));
        Assert.IsTrue(reopened.EastGate.IsOpen,
            "the rebuilt world put a seized gate back in a road the player had already opened");
    }

    [UnityTest]
    public IEnumerator ANewCharacterDoesNotInheritTheLastOnesOpenedGate()
    {
        yield return StoryTestBed.Boot();

        StoryModeManager story = StoryTestBed.Story;

        AsterTownLayout town = AsterTown.Build(
            Root().transform, StoryTestBed.Realm, story.Campaign(StoryTestBed.Realm), City(Vector2.zero));
        KnowledgeGate gate = town.EastGate;

        Assert.IsTrue(gate.Open(), "the gate could not be opened");
        Assert.IsFalse(gate.GetComponent<BoxCollider2D>().enabled,
            "the opened gate is still solid, so the road never really opened");

        // A new character begins with no history — including none of the previous
        // character's. The world they walk into has already been built, so the gate
        // must notice on its own rather than trusting what it was told at spawn.
        story.NewGame("Second Explorer", CharacterCreation.DefaultAppearanceId, StoryTestBed.Realm);
        Assert.IsFalse(AsterQuest.Has(story.Save, AsterQuest.GateOpenFlag),
            "a new character inherited the previous character's story history");

        yield return null;

        Assert.IsFalse(gate.IsOpen,
            "the eastern gate stayed open for a character who never opened it \u2014 the first quest "
            + "of the game can be skipped by walking east");
        Assert.IsTrue(gate.GetComponent<BoxCollider2D>().enabled,
            "the gate is still passable, so a new character can walk past the first quest entirely");
    }

    [UnityTest]
    public IEnumerator TheFirstSigilIsEarnedAndSurvivesAReload()
    {
        yield return StoryTestBed.Boot();

        StoryModeManager story = StoryTestBed.Story;
        TrialSettlement settled = StoryTestBed.PlayTrial(StoryTestBed.Realm, 1, true);

        Assert.IsTrue(settled.Passed, "the first trial was not passed on flawless answers");
        Assert.IsNotNull(settled.Outcome, "passing produced no verdict");
        Assert.IsFalse(string.IsNullOrEmpty(settled.Outcome.Badge),
            "passing a milestone earned no sigil, so there was nothing to show the player");
        Assert.AreEqual(settled.Milestone.BadgeName, settled.Outcome.Badge,
            "the sigil awarded is not the one the milestone promises");

        RealmProgressData progress = story.Progress(StoryTestBed.Realm);
        Assert.Contains(settled.Outcome.Badge, progress.badges,
            "the earned sigil is not on the player's record");

        Assert.IsTrue(story.SaveNow(), "the save after the sigil could not be written");
        story.LoadGame(StoryTestBed.Slot);

        RealmProgressData reloaded = story.Progress(StoryTestBed.Realm);
        Assert.IsTrue(reloaded.HasPassed(1), "the passed milestone was forgotten on reload");
        Assert.Contains(settled.Outcome.Badge, reloaded.badges, "the earned sigil was forgotten on reload");
    }

    [UnityTest]
    public IEnumerator TheVictoryNamesTheSigilAndTheRoadItOpens()
    {
        yield return StoryTestBed.Boot();

        StoryModeManager story = StoryTestBed.Story;
        TrialSettlement settled = StoryTestBed.PlayTrial(StoryTestBed.Realm, 1, true);
        Assert.IsTrue(settled.Passed, "the first trial was not passed on flawless answers");

        MilestoneOutcome outcome = settled.Outcome;
        Assert.AreEqual(2, outcome.Unlocked,
            "passing the first milestone did not open the second, so the victory screen would have nothing to promise");

        List<Milestone> milestones = story.Campaign(settled.Realm);
        Milestone next = null;
        for (int i = 0; i < milestones.Count; i++)
        {
            if (milestones[i].Index == outcome.Unlocked) next = milestones[i];
        }
        Assert.IsNotNull(next, "the unlocked milestone does not exist in the campaign");

        Assert.IsTrue(settled.MovedSavePoint,
            "passing a milestone did not move the save point, so the victory screen has no place to name");
        Assert.AreEqual(settled.Milestone.Place, settled.SavePoint.place,
            "the save point moved somewhere other than the place that was just cleared");
        Assert.IsFalse(string.IsNullOrEmpty(next.Place), "the next milestone names no place to walk to");
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    private GameObject Root()
    {
        return Add(new GameObject("Test_AsterTownRoot"));
    }

    private GameObject Add(GameObject obj)
    {
        _spawned.Add(obj);
        return obj;
    }

    private static GeneratedCity City(Vector2 position)
    {
        GeneratedCity city = new GeneratedCity();
        city.cityName = AsterTown.Name;
        city.position = position;
        city.size = 12;
        return city;
    }
}
