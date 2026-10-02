using System.Collections;
using System.Collections.Generic;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;
using UnityEngine.Tilemaps;

/// <summary>
/// The world the player stands in: tiles that exist, a collision layer that
/// actually collides, and a player that can see the things it is meant to talk to.
///
/// These three are the difference between a playable game and a black screen, and
/// each of them has been broken at least once in this project's history.
/// </summary>
public class WorldRuntimeTests
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
        yield return null;
    }

    [UnityTest]
    public IEnumerator TheTilesetBuildsEveryTileAndOnlyTheWallIsSolid()
    {
        _spawned.Add(new GameObject("Test_PixelSpriteGenerator"));
        _spawned[0].AddComponent<PixelSpriteGenerator>();
        yield return null; // let Awake publish the singleton

        RuntimeTileset.Build();

        Assert.IsNotNull(RuntimeTileset.Grass, "no grass tile was built");
        Assert.IsNotNull(RuntimeTileset.Path, "no path tile was built");
        Assert.IsNotNull(RuntimeTileset.Water, "no water tile was built");
        Assert.IsNotNull(RuntimeTileset.Tree, "no tree tile was built");
        Assert.IsNotNull(RuntimeTileset.Wall, "no collision tile was built");

        Assert.AreEqual(Tile.ColliderType.None, ((Tile)RuntimeTileset.Grass).colliderType,
            "the ground should not collide");
        Assert.AreEqual(Tile.ColliderType.Grid, ((Tile)RuntimeTileset.Wall).colliderType,
            "the collision tile must carry a collider, or water and trees stop nobody");
    }

    [UnityTest]
    public IEnumerator TheWorldGeneratorActuallyPaintsGroundAndPlacesCities()
    {
        _spawned.Add(new GameObject("Test_PixelSpriteGenerator"));
        _spawned[0].AddComponent<PixelSpriteGenerator>();
        yield return null;

        // A small world: the point is whether the generator paints, not how fast.
        GameObject gridObj = new GameObject("Test_Grid");
        _spawned.Add(gridObj);
        gridObj.AddComponent<Grid>();
        Tilemap ground = MakeTilemap(gridObj.transform, "GroundTilemap", 0);
        Tilemap path = MakeTilemap(gridObj.transform, "PathTilemap", 1);
        Tilemap decoration = MakeTilemap(gridObj.transform, "DecorationTilemap", 2);
        Tilemap water = MakeTilemap(gridObj.transform, "WaterTilemap", 3);
        Tilemap collision = MakeTilemap(gridObj.transform, "CollisionTilemap", 4);

        GameObject generatorObj = new GameObject("Test_WorldGenerator");
        _spawned.Add(generatorObj);
        ProceduralWorldGenerator generator = generatorObj.AddComponent<ProceduralWorldGenerator>();
        generator.worldWidth = 48;
        generator.worldHeight = 48;
        generator.groundTilemap = ground;
        generator.pathTilemap = path;
        generator.decorationTilemap = decoration;
        generator.waterTilemap = water;
        generator.collisionTilemap = collision;

        RuntimeTileset.Build();
        RuntimeTileset.ApplyTo(generator);

        generator.GenerateWorld();
        yield return null;

        Assert.IsNotNull(generator.grassTile, "the generator was left with no grass tile to paint");
        Assert.Greater(CountTiles(ground) + CountTiles(water), 0,
            "the generator painted nothing at all — the world would be an empty void");
        Assert.Greater(generator.generatedCities.Count, 0,
            "the generator placed no cities, so the story has nowhere to stand");
    }

    [UnityTest]
    public IEnumerator ThePlayerCanSeeAndReachWhatItWalksUpTo()
    {
        _spawned.Add(new GameObject("Test_Player"));
        GameObject player = _spawned[_spawned.Count - 1];
        player.AddComponent<PlayerController>();

        // Start runs on the next frame; an unassigned LayerMask is the bug these
        // masks exist to prevent.
        yield return null;

        PlayerController controller = player.GetComponent<PlayerController>();

        Assert.AreNotEqual(0, controller.collisionLayer.value,
            "the player collides with nothing, so it can walk through the world");
        Assert.AreNotEqual(0, controller.npcLayer.value,
            "the player's interaction raycast hits nothing, so keepers can never be spoken to");
        Assert.AreNotEqual(0, controller.interactableLayer.value,
            "the player's interactable layer is empty, so save shards and landmarks are invisible to it");
    }

    private static Tilemap MakeTilemap(Transform parent, string name, int order)
    {
        GameObject obj = new GameObject(name);
        obj.transform.SetParent(parent, false);
        Tilemap map = obj.AddComponent<Tilemap>();
        TilemapRenderer renderer = obj.AddComponent<TilemapRenderer>();
        renderer.sortingOrder = order;
        return map;
    }

    private static int CountTiles(Tilemap map)
    {
        int count = 0;
        BoundsInt bounds = map.cellBounds;
        foreach (Vector3Int cell in bounds.allPositionsWithin)
        {
            if (map.HasTile(cell)) count++;
        }
        return count;
    }
}
