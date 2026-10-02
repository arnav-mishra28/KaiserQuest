using System.Collections;
using KaiserQuest.Knowledge;
using KaiserQuest.Story;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.TestTools;
using UnityEngine.Tilemaps;

/// <summary>
/// Boots the real GameBootstrap in an empty scene — the exact path a player's
/// first Play press takes — and asserts the game actually appears: a camera, the
/// tilemaps, a generated world, a player to walk, and a story screen waiting.
/// Every other test boots the story loop directly; this one boots the game.
/// </summary>
public class BootSmokeTests
{
    private Scene testScene;
    private Scene previousScene;

    [UnitySetUp]
    public IEnumerator SetUp()
    {
        previousScene = SceneManager.GetActiveScene();
        testScene = SceneManager.CreateScene("boot-smoke");
        SceneManager.SetActiveScene(testScene);
        yield return null;
    }

    [UnityTearDown]
    public IEnumerator TearDown()
    {
        if (testScene.IsValid() && testScene.isLoaded)
            yield return SceneManager.UnloadSceneAsync(testScene);
        if (previousScene.IsValid())
            SceneManager.SetActiveScene(previousScene);
        // No save cleanup: ContinueStory only reads saves, never writes them.
    }

    [UnityTest]
    public IEnumerator TheGameBootsFromAnEmptyScene()
    {
        GameObject bootstrapObj = new GameObject("GameBootstrap");
        GameBootstrap bootstrap = bootstrapObj.AddComponent<GameBootstrap>();

        yield return StoryTestBed.WaitUntil(() =>
                KnowledgeEngine.Instance != null && KnowledgeEngine.Instance.Graph != null,
            60f, "boot never produced a knowledge engine with a concept graph");

        yield return StoryTestBed.WaitUntil(() =>
                StoryModeManager.Instance != null && StoryModeManager.Instance.Progression != null,
            30f, "boot never bound the story manager to the engine");

        yield return StoryTestBed.WaitUntil(() => KnowledgeEngine.Instance.BankSize > 0,
            30f, "boot never loaded the verified question banks");

        // The world: a camera to see it, a road with cities, tiles that publish.
        Assert.IsNotNull(Camera.main, "boot never created a camera");
        yield return StoryTestBed.WaitUntil(() =>
                bootstrap.worldGenerator != null && bootstrap.worldGenerator.generatedCities.Count > 0,
            30f, "boot never generated a world with cities");
        Assert.IsNotNull(ProceduralWorldGeneratorHub.Ground, "runtime tiles were never published to the hub");
        Assert.IsNotNull(ProceduralWorldGeneratorHub.Collision, "the collision tilemap was never published to the hub");

        Tilemap collision = ProceduralWorldGeneratorHub.Collision;
        Assert.IsNotNull(collision.GetComponent<TilemapCollider2D>(),
            "the collision tilemap has no collider — nothing in the world is solid");
        TilemapRenderer collisionRenderer = collision.GetComponent<TilemapRenderer>();
        Assert.IsTrue(collisionRenderer == null || !collisionRenderer.enabled,
            "the collision tilemap is drawn — it would paint over the water and trees it stops");

        // The player: present, controllable, animated, and actually visible.
        yield return StoryTestBed.WaitUntil(() => GameObject.FindWithTag("Player") != null,
            30f, "boot never spawned a player");
        GameObject player = GameObject.FindWithTag("Player");
        Assert.IsNotNull(player.GetComponent<PlayerController>(), "the player has no controller");
        Assert.IsNotNull(player.GetComponent<PlayerSpriteAnimator>(), "the player has no walk animator");
        Assert.IsNotNull(player.GetComponent<OverworldHUD>(), "the player has no HUD");
        Transform body = player.transform.Find("Body");
        Assert.IsNotNull(body, "the player has no body child");
        SpriteRenderer bodyRenderer = body.GetComponent<SpriteRenderer>();
        Assert.IsNotNull(bodyRenderer, "the player body has no sprite renderer");
        Assert.IsNotNull(bodyRenderer.sprite, "the player body has no sprite — you would be invisible");

        // And a story screen waiting in front of it all.
        Assert.IsNotNull(StoryUI.Instance, "boot never opened a story screen");
    }

    [UnityTest]
    public IEnumerator ThePlayerSpawnsSomewhereWalkable()
    {
        GameObject bootstrapObj = new GameObject("GameBootstrap");
        bootstrapObj.AddComponent<GameBootstrap>();

        yield return StoryTestBed.WaitUntil(() => GameObject.FindWithTag("Player") != null,
            60f, "boot never spawned a player");

        GameObject player = GameObject.FindWithTag("Player");
        Tilemap collision = ProceduralWorldGeneratorHub.Collision;
        Assert.IsNotNull(collision, "no collision tilemap was published");

        Vector3Int cell = collision.WorldToCell(player.transform.position);
        Assert.IsNull(collision.GetTile(cell),
            "the player spawns inside a solid tile — stuck on frame one");
    }
}
