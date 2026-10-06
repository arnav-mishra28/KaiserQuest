using System.Collections.Generic;
using KaiserQuest.Story;
using UnityEngine;

/// <summary>
/// What Aster Town turned out to be.
///
/// Returned rather than merely spawned so the caller — and the tests — can ask a
/// settlement what it contains instead of hunting the scene graph for it. A town is
/// data; this is its shape.
/// </summary>
public class AsterTownLayout
{
    public string Realm;
    public string Name = AsterTown.Name;
    public Vector2 Center;
    public GameObject Root;

    public KnowledgeGate EastGate;
    public QuestGiver Giver;
    public Landmark Monument;

    public readonly List<GameObject> Buildings = new List<GameObject>();
    public readonly List<TownSign> Signs = new List<TownSign>();

    public bool HasGate { get { return EastGate != null; } }
    public bool HasQuestGiver { get { return Giver != null; } }
    public int BuildingCount { get { return Buildings.Count; } }
}

/// <summary>
/// Aster Town — the handcrafted settlement the campaign opens in.
///
/// The procedural world generator carves out a clearing for its first city and
/// leaves it bare; a bare clearing is not a place, and the first twenty minutes of
/// a game are spent in this one. So the starting settlement is *authored* on top of
/// the generated terrain: a plaza, houses with walls you cannot walk through, a
/// signpost that says where you are, a monument that names the chapter, a shop, and
/// the eastern gate that has stopped responding.
///
/// Nothing here replaces the procedural world: the terrain, the road and the
/// settlement's position still come from the generator, and the story populator
/// still stands the keeper and the save shard in the plaza this file paves. Aster
/// Town is the layer on top — handcrafted placement on a generated map, which is
/// exactly what the architecture was built to allow.
///
/// Every position is fixed rather than sampled, because the player has to be able to
/// learn where things are.
/// </summary>
public static class AsterTown
{
    public const string Name = "Aster Town";

    //: The paved heart of the town. The player wakes inside this, at the save point
    //: the campaign set for milestone 1, and the keeper and the save shard both stand
    //: in it — so it is deliberately large enough to hold all three.
    private const int PlazaRadius = 5;

    //: Houses and the shop sit outside the plaza on a fixed rectangle. A building
    //: inside the plaza would stand on the keeper's spot, and a keeper you cannot
    //: reach is a milestone you cannot enter.
    private static readonly Vector2[] BuildingSpots = new Vector2[]
    {
        new Vector2(-7f, 5f),
        new Vector2(-7f, -5f),
        new Vector2(7f, -5f),
        new Vector2(7f, 5f)
    };

    private static readonly string[] BuildingNames = new string[]
    {
        "Maren's house", "The Aster Inn", "The Widow's Cottage", "Curio Shop"
    };

    /// <summary>Where the eastern gate stands, just past the town's edge.</summary>
    private static readonly Vector2 GateSpot = new Vector2(9f, 0f);

    /// <summary>
    /// Build the settlement around the starting city.
    ///
    /// `city` is the generator's first settlement; the town is laid out in offsets
    /// from its centre so the road the generator drew still runs through the middle
    /// of it. Returns the layout, or null when there is nothing to build on.
    /// </summary>
    public static AsterTownLayout Build(
        Transform parent, string realm, List<Milestone> milestones, GeneratedCity city)
    {
        if (parent == null || city == null) return null;

        AsterTownLayout layout = new AsterTownLayout();
        layout.Realm = realm;
        layout.Center = city.position;

        GameObject root = new GameObject("AsterTown");
        root.transform.SetParent(parent, false);
        root.transform.position = Vector3.zero;
        layout.Root = root;

        Milestone opening = milestones != null && milestones.Count > 0 ? milestones[0] : null;

        // The plaza first, so everything stood later stands on paving rather than on
        // whatever the noise function left there — water and trees are solid, and an
        // NPC placed in one is an NPC nobody can talk to.
        Pad(layout.Center, PlazaRadius);

        // The road out of town, east and south, so the gate is a thing on a road
        // rather than a thing in a field.
        PaveRoad(layout.Center, new Vector2(GateSpot.x + 2f, GateSpot.y));
        PaveRoad(layout.Center, new Vector2(layout.Center.x, layout.Center.y - 9f));

        layout.Monument = SpawnMonument(root.transform, realm, opening, layout.Center + new Vector2(0f, 6f));

        for (int i = 0; i < BuildingSpots.Length; i++)
        {
            layout.Buildings.Add(SpawnBuilding(
                root.transform, layout.Center + BuildingSpots[i], BuildingNames[i], i == BuildingNames.Length - 1));
        }

        // Readable signage: where you are, and which way the campaign goes.
        layout.Signs.Add(SpawnSign(root.transform, layout.Center + new Vector2(0f, -7.5f),
            "ASTER TOWN\nthe road east is shut"));
        layout.Signs.Add(SpawnSign(root.transform, layout.Center + new Vector2(-3f, -3.5f),
            "ASTER TOWN\na quiet place to learn what you are made of"));
        layout.Signs.Add(SpawnSign(root.transform, layout.Center + new Vector2(4f, -3.5f),
            "EAST GATE \u2192\nthe mechanism is not answering"));

        layout.Giver = SpawnQuestGiver(root.transform, realm, opening, layout.Center + new Vector2(6f, 2f));

        // The gate itself. It is left closed unless the save says it was opened, so a
        // returning player walks back into a town that remembers them.
        layout.EastGate = SpawnGate(root.transform, realm, opening, layout.Center + GateSpot);

        ScatterProps(root.transform, realm, layout.Center);

        Debug.Log("[AsterTown] Built " + Name + " at " + layout.Center
                  + " for realm '" + realm + "': " + layout.Buildings.Count + " buildings, "
                  + layout.Signs.Count + " signs, a monument, a quest giver and the east gate.");
        return layout;
    }

    // ------------------------------------------------------------------
    // Pieces
    // ------------------------------------------------------------------
    private static Landmark SpawnMonument(
        Transform parent, string realm, Milestone opening, Vector2 position)
    {
        if (opening == null) return null;

        Pad(position, 1);

        GameObject obj = new GameObject("Monument_" + opening.Place);
        obj.transform.SetParent(parent, false);
        obj.transform.position = new Vector3(position.x, position.y, 0f);

        SpriteRenderer renderer = obj.AddComponent<SpriteRenderer>();
        renderer.sortingOrder = 5;
        if (PixelSpriteGenerator.Instance != null)
        {
            renderer.sprite = PixelSpriteGenerator.Instance.GenerateLandmarkSprite(
                LandmarkKind.Beacon, OverworldDecor.AccentFor(realm, opening.Index));
        }

        // A trigger, not a wall: the monument names the chapter, it does not fence it.
        BoxCollider2D collider = obj.AddComponent<BoxCollider2D>();
        collider.isTrigger = true;
        collider.size = new Vector2(1.6f, 2f);
        collider.offset = new Vector2(0f, 1f);

        Landmark landmark = obj.AddComponent<Landmark>();
        landmark.milestoneIndex = opening.Index;
        landmark.placeName = opening.Place;
        landmark.keeperName = opening.Keeper;
        landmark.kindLabel = "Monument";
        return landmark;
    }

    /// <summary>
    /// A house. Solid on purpose: a building the player can walk through is scenery,
    /// not a building, and the first thing a player tests in a town is whether the
    /// walls are real.
    /// </summary>
    private static GameObject SpawnBuilding(
        Transform parent, Vector2 position, string buildingName, bool isShop)
    {
        Pad(position, 2);

        GameObject obj = new GameObject("Building_" + buildingName.Replace(" ", "_"));
        obj.transform.SetParent(parent, false);
        obj.transform.position = new Vector3(position.x, position.y, 0f);

        SpriteRenderer renderer = obj.AddComponent<SpriteRenderer>();
        renderer.sortingOrder = 8;
        if (PixelSpriteGenerator.Instance != null)
        {
            Color wall = isShop
                ? new Color(0.86f, 0.80f, 0.62f)
                : new Color(0.82f, 0.74f, 0.62f);
            Color roof = isShop
                ? new Color(0.42f, 0.30f, 0.55f)
                : new Color(0.62f, 0.28f, 0.24f);
            renderer.sprite = PixelSpriteGenerator.Instance.GenerateBuildingSprite(wall, roof, isShop);
        }

        // The 32x32 building sprite is two tiles wide and two tall, drawn from its
        // base upward. Only the lower half is solid, so the player can stand in front
        // of a roof overhang without clipping into it.
        BoxCollider2D collider = obj.AddComponent<BoxCollider2D>();
        collider.size = new Vector2(1.9f, 1.4f);
        collider.offset = new Vector2(0f, 0.7f);

        return obj;
    }

    private static TownSign SpawnSign(Transform parent, Vector2 position, string text)
    {
        Pad(position, 1);

        GameObject obj = new GameObject("Sign_" + text.Split('\n')[0].Replace(" ", "_"));
        obj.transform.SetParent(parent, false);
        obj.transform.position = new Vector3(position.x, position.y, 0f);

        SpriteRenderer renderer = obj.AddComponent<SpriteRenderer>();
        renderer.sortingOrder = 7;
        if (PixelSpriteGenerator.Instance != null)
            renderer.sprite = PixelSpriteGenerator.Instance.GenerateSignSprite();

        BoxCollider2D collider = obj.AddComponent<BoxCollider2D>();
        collider.isTrigger = true;
        collider.size = new Vector2(1f, 1.2f);
        collider.offset = new Vector2(0f, 0.4f);

        TownSign sign = obj.AddComponent<TownSign>();
        sign.text = text;
        return sign;
    }

    private static QuestGiver SpawnQuestGiver(
        Transform parent, string realm, Milestone opening, Vector2 position)
    {
        Pad(position, 1);

        GameObject obj = new GameObject("QuestGiver_" + Name);
        obj.transform.SetParent(parent, false);
        obj.transform.position = new Vector3(position.x, position.y, 0f);

        SpriteRenderer renderer = obj.AddComponent<SpriteRenderer>();
        renderer.sortingOrder = 10;
        if (PixelSpriteGenerator.Instance != null)
        {
            // Weathered green: somebody who has stood on this road a long time.
            renderer.sprite = PixelSpriteGenerator.Instance.GenerateNPCSprite(
                new Color(0.35f, 0.5f, 0.4f), new Color(0.32f, 0.26f, 0.2f));
        }

        obj.AddComponent<BoxCollider2D>();

        QuestGiver giver = obj.AddComponent<QuestGiver>();
        giver.realmId = realm;
        giver.milestoneIndex = opening != null ? opening.Index : 1;
        giver.speakerName = "Maren";
        return giver;
    }

    private static KnowledgeGate SpawnGate(
        Transform parent, string realm, Milestone opening, Vector2 position)
    {
        Pad(position, 1);

        GameObject obj = new GameObject("KnowledgeGate_" + AsterQuest.GateId);
        obj.transform.SetParent(parent, false);
        obj.transform.position = new Vector3(position.x, position.y, 0f);

        SpriteRenderer renderer = obj.AddComponent<SpriteRenderer>();
        renderer.sortingOrder = 9;
        if (PixelSpriteGenerator.Instance != null)
        {
            // A gate is an arch: two posts and a lintel, which is exactly what the
            // arch monument primitive draws.
            renderer.sprite = PixelSpriteGenerator.Instance.GenerateLandmarkSprite(
                LandmarkKind.Arch, OverworldDecor.AccentFor(realm, opening != null ? opening.Index : 1));
        }

        // Solid while it is seized — a gate that never stopped anything is a door
        // frame — and unsealed when it opens.
        BoxCollider2D collider = obj.AddComponent<BoxCollider2D>();
        collider.size = new Vector2(2f, 2f);
        collider.offset = new Vector2(0f, 1f);

        KnowledgeGate gate = obj.AddComponent<KnowledgeGate>();
        gate.gateId = AsterQuest.GateId;
        gate.realmId = realm;
        gate.milestoneIndex = opening != null ? opening.Index : 1;

        StoryModeManager story = StoryModeManager.Instance;
        bool open = story != null && story.Save != null && AsterQuest.Has(story.Save, AsterQuest.GateOpenFlag);
        gate.ApplySavedState(open);

        return gate;
    }

    /// <summary>
    /// A deterministic scatter of trees and boulders outside the plaza, so the town
    /// has an edge and the walk out of it looks like countryside rather than a void.
    /// </summary>
    private static void ScatterProps(Transform parent, string realm, Vector2 centre)
    {
        PixelSpriteGenerator sprites = PixelSpriteGenerator.Instance;
        if (sprites == null) return;

        Sprite tree = sprites.GenerateTreeSprite();
        Sprite rock = sprites.GenerateRockSprite();

        for (int i = 0; i < 18; i++)
        {
            int seed = StableHash(realm + ":aster:" + i);

            float angle = (i / 18f) * Mathf.PI * 2f + (seed % 100) / 100f;
            float radius = 10.5f + (seed % 25) / 10f;

            Vector2 offset = new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * radius;

            // Keep the way out of town clear, and keep well off the keeper's and the
            // shard's ground at the plaza's own width.
            if (Mathf.Abs(offset.y) < 2.5f && offset.x > 0f) continue;
            if (Mathf.Abs(offset.x) < 2.5f && offset.y < 0f) continue;

            GameObject obj = new GameObject("TownScenery_" + i);
            obj.transform.SetParent(parent, false);
            obj.transform.position = new Vector3(centre.x + offset.x, centre.y + offset.y, 0f);

            SpriteRenderer renderer = obj.AddComponent<SpriteRenderer>();
            renderer.sortingOrder = 3;
            renderer.sprite = (seed % 3 == 0) ? rock : tree;
            float shade = 0.88f + (seed % 12) / 100f;
            renderer.color = new Color(shade, shade, shade, 1f);
        }
    }

    // ------------------------------------------------------------------
    // Ground
    // ------------------------------------------------------------------
    private static void Pad(Vector2 centre, int radius)
    {
        // Publishes a walkable, paved pad. Shared with the world decorator, so there
        // is one answer to "how does a thing get placed somewhere reachable".
        OverworldDecor.ClearGround(centre, radius);
    }

    private static void PaveRoad(Vector2 from, Vector2 to)
    {
        float distance = Vector2.Distance(from, to);
        int steps = Mathf.Max(1, Mathf.CeilToInt(distance));
        for (int i = 0; i <= steps; i++)
        {
            Vector2 point = Vector2.Lerp(from, to, i / (float)steps);
            Pad(new Vector2(Mathf.Round(point.x), Mathf.Round(point.y)), 1);
        }
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
