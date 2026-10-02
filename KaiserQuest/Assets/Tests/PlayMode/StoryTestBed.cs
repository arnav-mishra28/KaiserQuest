using System;
using System.Collections;
using System.Collections.Generic;
using KaiserQuest.Knowledge;
using KaiserQuest.Story;
using NUnit.Framework;
using UnityEngine;

/// <summary>
/// Shared harness for the PlayMode tests.
///
/// Brings up the real knowledge engine and story manager — the same components the
/// game boots — on a private save slot, so the tests exercise the actual campaign
/// rather than a mock of it. The slot is deleted before and after every test, so
/// running the suite can never touch a player's save.
/// </summary>
public static class StoryTestBed
{
    public const string Slot = "playmode-test";
    public const string Realm = "algebra";

    public static KnowledgeEngine Engine { get { return KnowledgeEngine.Instance; } }
    public static StoryModeManager Story { get { return StoryModeManager.Instance; } }

    private static readonly List<GameObject> Spawned = new List<GameObject>();

    public static IEnumerator Boot(bool startNewGame = true)
    {
        SaveSystem.Delete(Slot);

        // The managers are singletons and may already be standing from a previous
        // test in the same play session; reuse them rather than fighting AddComponent.
        if (KnowledgeEngine.Instance == null)
            Spawned.Add(Spawn("Test_KnowledgeEngine", typeof(KnowledgeEngine)));

        yield return WaitUntil(() => KnowledgeEngine.Instance != null && KnowledgeEngine.Instance.Graph != null,
                               60f, "the knowledge engine never loaded its concept graph");

        if (StoryModeManager.Instance == null)
            Spawned.Add(Spawn("Test_StoryModeManager", typeof(StoryModeManager)));

        yield return WaitUntil(() => StoryModeManager.Instance != null && StoryModeManager.Instance.Progression != null,
                               15f, "the story manager never bound to the knowledge engine");

        StoryModeManager story = StoryModeManager.Instance;
        story.saveSlotId = Slot;

        if (startNewGame)
        {
            story.NewGame("Test Explorer", CharacterCreation.DefaultAppearanceId, Realm);
            yield return WaitUntil(() => story.Ready, 15f, "the story never became ready after a new game");
        }
    }

    /// <summary>
    /// Play one milestone's trial and answer every question correctly.
    /// Returns the settlement so callers can assert on the consequence.
    /// </summary>
    public static TrialSettlement PlayTrial(string realm, int index, bool answerCorrectly)
    {
        EntryCheck entry;
        string error;
        TrialRunner runner = Story.StartTrial(realm, index, out entry, out error);

        Assert.IsNotNull(runner, "the trial did not start: " + error);
        Assert.IsTrue(entry.Allowed, "the trial started but the entry check says otherwise");

        int guard = 0;
        while (!runner.IsComplete && guard < 400)
        {
            TrialStep step = runner.Current;
            Assert.IsNotNull(step, "the trial ran out of questions before it finished");

            string answer = answerCorrectly
                ? step.Question.correctAnswer
                : WrongAnswerFor(step.Question);

            runner.Answer(answer, 1500f, 0);
            guard++;
        }

        Assert.IsTrue(runner.IsComplete, "the trial never finished");
        Assert.Greater(guard, 0, "the trial asked no questions");

        TrialSettlement settlement = Story.SettleTrial(runner);
        Assert.IsNotNull(settlement, "the trial produced no settlement");
        return settlement;
    }

    /// <summary>An option that is not the right one, or the right one if there is no other.</summary>
    public static string WrongAnswerFor(BankQuestion question)
    {
        if (question == null || question.options == null) return string.Empty;

        for (int i = 0; i < question.options.Count; i++)
        {
            if (question.options[i] != question.correctAnswer) return question.options[i];
        }
        return question.correctAnswer;
    }

    public static IEnumerator WaitUntil(Func<bool> condition, float seconds, string message)
    {
        float deadline = Time.realtimeSinceStartup + seconds;
        while (!condition() && Time.realtimeSinceStartup < deadline)
            yield return null;

        if (!condition()) Assert.Fail(message);
    }

    private static GameObject Spawn(string name, params Type[] components)
    {
        GameObject obj = new GameObject(name);
        for (int i = 0; i < components.Length; i++) obj.AddComponent(components[i]);
        return obj;
    }

    /// <summary>Drop everything this harness created, and the test save with it.</summary>
    public static void Shutdown()
    {
        for (int i = 0; i < Spawned.Count; i++)
        {
            if (Spawned[i] != null) UnityEngine.Object.DestroyImmediate(Spawned[i]);
        }
        Spawned.Clear();
        SaveSystem.Delete(Slot);
    }
}
