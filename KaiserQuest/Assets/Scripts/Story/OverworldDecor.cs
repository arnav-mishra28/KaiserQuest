using System.Collections.Generic;
using KaiserQuest.Story;
using UnityEngine;
using UnityEngine.Tilemaps;

/// <summary>What kind of structure marks a milestone on the overworld.</summary>
public enum LandmarkKind
{
    Beacon,
    Arch,
    Shrine,
    Grove,
    Tower
}

/// <summary>
/// A milestone's monument. Scenery with a name, so a place on the map reads as a
/// place on the ground: the player can see where they are going before they get
/// there, which is the whole point of walking a road instead of picking entries
/// from a list.
/// </summary>
public class Landmark : MonoBehaviour
{
    public int milestoneIndex;
    public string placeName;
    public string keeperName;
    public string kindLabel;
}

/// <summary>
/// Dresses the generated world so the campaign is visible from the saddle.
///
/// The world generator produces terrain and cities; the story populator stands
/// keepers and save shards in them. Neither draws attention to *which* place
/// matters. This adds a monument per milestone, paves a plaza at each city
/// centre so settlements read as settlements, and scatters scenery so the road
/// between them is not a featureless field.
///
/// Everything here is deterministic from the milestone index and realm, because a
/// world that looks different every launch makes it impossible to learn the
/// terrain — and learning the terrain is what walking it is for.
/// </summary>
public static class OverworldDecor
{
    private const int PropsPerPlace = 8;

    public static void Decorate(Transform root, string realm, List<Milestone> milestones, List<GeneratedCity> cities)
    {
        if (root == null || milestones == null || cities == null) return;

        int places = Mathf.Min(milestones.Count, cities.Count);
        for (int i = 0; i < places; i++)
        {
            Vector2 city = cities[i].position;
            Milestone milestone = milestones[i];

            PavePlaza(city);
            SpawnLandmark(root, realm, milestone, city + new Vector2(0f, 2.6f));
            ScatterScenery(root, realm, city, i);
        }

        Debug.Log("[KaiserWorld] Decorated " + places + " milestone places in '" + realm + "'.");
    }

    /// <summary>Lay a paved square so the city centre is a place, not a grass cell.</summary>
    private static void PavePlaza(Vector2 centre)
    {
        ClearGround(centre, 2);
    }

    /// <summary>
    /// Clear a small pad of walkable, paved ground.
    ///
    /// Terrain is generated before any place exists, so a keeper, a save shard or
    /// the Archivist can end up standing in a lake or inside a tree — and because
    /// water and trees are solid, an NPC in one is an NPC the player can never
    /// reach. Every story object is given a pad, so a keeper is always reachable
    /// by construction rather than by luck of the noise function.
    /// </summary>
    public static void ClearGround(Vector2 centre, int radius = 1)
    {
        Tilemap path = ProceduralWorldGeneratorHub.Path;
        Tilemap ground = ProceduralWorldGeneratorHub.Ground;
        Tilemap water = ProceduralWorldGeneratorHub.Water;
        Tilemap collision = ProceduralWorldGeneratorHub.Collision;

        for (int dx = -radius; dx <= radius; dx++)
        {
            for (int dy = -radius; dy <= radius; dy++)
            {
                Vector3Int cell = new Vector3Int(Mathf.RoundToInt(centre.x) + dx, Mathf.RoundToInt(centre.y) + dy, 0);

                // The pad reclaims land: water is removed, not merely covered, so a
                // plaza at a shoreline does not leave a solid cell under the paving.
                if (water != null) water.SetTile(cell, null);
                if (collision != null) collision.SetTile(cell, null);

                if (path != null && RuntimeTileset.Path != null) path.SetTile(cell, RuntimeTileset.Path);
                else if (ground != null && RuntimeTileset.Grass != null) ground.SetTile(cell, RuntimeTileset.Grass);
            }
        }
    }

    private static void SpawnLandmark(Transform parent, string realm, Milestone milestone, Vector2 position)
    {
        GameObject obj = new GameObject("Landmark_M" + milestone.Index.ToString("00") + "_" + milestone.Place);
        obj.transform.SetParent(parent, false);
        obj.transform.position = new Vector3(position.x, position.y, 0f);

        LandmarkKind kind = KindFor(milestone.Index);

        SpriteRenderer renderer = obj.AddComponent<SpriteRenderer>();
        // Behind the player and the keepers, in front of the ground: a monument
        // the player walks in front of, never one they stand behind.
        renderer.sortingOrder = 5;

        if (PixelSpriteGenerator.Instance != null)
            renderer.sprite = PixelSpriteGenerator.Instance.GenerateLandmarkSprite(kind, AccentFor(realm, milestone.Index));

        // A trigger, not a wall: the monument is scenery the player can walk to and
        // name, never something that blocks the road to its own keeper. The overlap
        // is what the proximity nameplate detects.
        BoxCollider2D collider = obj.AddComponent<BoxCollider2D>();
        collider.isTrigger = true;
        collider.size = new Vector2(1.6f, 2f);
        collider.offset = new Vector2(0f, 1f);

        Landmark landmark = obj.AddComponent<Landmark>();
        landmark.milestoneIndex = milestone.Index;
        landmark.placeName = milestone.Place;
        landmark.keeperName = milestone.Keeper;
        landmark.kindLabel = kind.ToString();
    }

    private static void ScatterScenery(Transform parent, string realm, Vector2 centre, int placeIndex)
    {
        PixelSpriteGenerator sprites = PixelSpriteGenerator.Instance;
        if (sprites == null) return;

        Sprite tree = sprites.GenerateTreeSprite();
        Sprite rock = sprites.GenerateRockSprite();

        for (int i = 0; i < PropsPerPlace; i++)
        {
            int seed = StableHash(realm + ":" + placeIndex + ":" + i);

            // On a ring around the plaza, so scenery frames the place instead of
            // covering the keeper the player came to talk to.
            float angle = (i / (float)PropsPerPlace) * Mathf.PI * 2f + (seed % 100) / 100f;
            float radius = 3.4f + (seed % 17) / 10f;

            Vector2 offset = new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * radius;

            // The four compass points are where the keeper, the save shard and the
            // Archivist stand — keep them clear.
            if (Mathf.Abs(offset.x) < 1.2f || Mathf.Abs(offset.y) < 1.2f) continue;

            GameObject obj = new GameObject("Scenery_" + i);
            obj.transform.SetParent(parent, false);
            obj.transform.position = new Vector3(centre.x + offset.x, centre.y + offset.y, 0f);

            SpriteRenderer renderer = obj.AddComponent<SpriteRenderer>();
            renderer.sortingOrder = 3;
            renderer.sprite = (seed % 3 == 0) ? rock : tree;
            // A little variation, so a row of identical trees does not look tiled.
            float shade = 0.86f + (seed % 15) / 100f;
            renderer.color = new Color(shade, shade, shade, 1f);
        }
    }

    private static LandmarkKind KindFor(int milestoneIndex)
    {
        switch (milestoneIndex % 5)
        {
            case 0: return LandmarkKind.Tower;   // every fifth chapter is a hall, not a hut
            case 1: return LandmarkKind.Beacon;
            case 2: return LandmarkKind.Arch;
            case 3: return LandmarkKind.Shrine;
            default: return LandmarkKind.Grove;
        }
    }

    /// <summary>A steady colour per realm and chapter, so places are recognisable.</summary>
    public static Color AccentFor(string realm, int milestoneIndex)
    {
        int hash = StableHash(realm) + milestoneIndex * 37;
        float hue = (hash % 1000) / 1000f;
        return Color.HSVToRGB(hue, 0.5f, 0.62f);
    }

    private static int StableHash(string text)
    {
        unchecked
        {
            int hash = 17;
            for (int i = 0; i < text.Length; i++) hash = hash * 31 + text[i];
            return Mathf.Abs(hash);
        }
    }
}
