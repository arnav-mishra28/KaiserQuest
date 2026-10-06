using System.Collections.Generic;
using KaiserQuest.Story;
using UnityEngine;

/// <summary>
/// MilestoneKeeper — the keeper NPC standing at a milestone's place.
///
/// In the old build, gym leaders lived behind a level gate and spoke in padlocks.
/// In story mode the keeper is the gate and the guide at once: they say exactly
/// what the entry check says, walk you through the idea when the milestone teaches
/// (teach_then_ask), and send you into the trial when you are ready. Beating them
/// is not the point; understanding the chapter is, and they are the first to say so.
///
/// Interact with Z / Enter / Space, like every NPC.
/// </summary>
public class MilestoneKeeper : MonoBehaviour, IInteractable
{
    public int milestoneIndex;
    public string realmId;
    public string keeperName = "Keeper";
    public string placeName = "";

    private SpriteRenderer _renderer;

    private void Awake()
    {
        _renderer = GetComponent<SpriteRenderer>();
    }

    public void Interact(PlayerController player)
    {
        StoryModeManager story = StoryModeManager.Instance;
        StoryUI ui = StoryUI.Instance;
        if (story == null || ui == null || !story.Ready) return;

        // The realm is resolved at interact time, not spawn time: the player can
        // create a new character in another realm, and the keeper they then talk
        // to must open the current story's milestone, not a stale one.
        string realm = story.ActiveRealmId;
        List<Milestone> milestones = story.Campaign(realm);
        Milestone milestone = null;
        for (int i = 0; i < milestones.Count; i++)
        {
            if (milestones[i].Index == milestoneIndex) { milestone = milestones[i]; break; }
        }
        if (milestone == null) return;

        EntryCheck entry = story.Progression.EntryCheck(milestones, milestone, story.Progress(realm));
        Debug.Log("[MilestoneKeeper] " + keeperName + " at " + placeName + " \u2014 allowed: " + entry.Allowed);

        // The keeper says what the gate says, then the trial screen says the rest.
        ui.ShowTrial(realm, milestone.Index);
    }

    /// <summary>Keepers of cleared chapters stand a shade quieter.</summary>
    public void SetClearedVisual(bool cleared)
    {
        if (_renderer != null) _renderer.color = cleared ? new Color(0.85f, 0.9f, 1f, 0.9f) : Color.white;
    }
}

/// <summary>
/// SavePointObject — a place in the world where the journey is written down.
///
/// The save point is the architectural load-bearing wall of the endgame: failing
/// all three Silver Mountain attempts does not send you to a menu, it sends you
/// *here*. So save points are real objects at real places, and resting at one is
/// what moves the respawn point forward.
/// </summary>
public class SavePointObject : MonoBehaviour, IInteractable
{
    public int milestoneIndex = 1;
    public string realmId;
    public string placeName = "";

    private SpriteRenderer _renderer;
    private float _pulse;

    private void Awake()
    {
        _renderer = GetComponent<SpriteRenderer>();
    }

    private void Update()
    {
        // The shard breathes, so a player can spot it from across the town.
        if (_renderer != null)
        {
            _pulse += Time.deltaTime * 2f;
            float glow = 0.85f + 0.15f * Mathf.Sin(_pulse);
            _renderer.color = new Color(glow, glow, Mathf.Min(1f, glow + 0.1f), 1f);
        }
    }

    public void Interact(PlayerController player)
    {
        StoryModeManager story = StoryModeManager.Instance;
        if (story == null || !story.Ready) return;

        // As with the keepers: the shard saves into whichever realm is being played.
        string realm = story.ActiveRealmId;
        SavePointData point = story.SavePoint(realm, milestoneIndex, placeName);
        if (point == null) return;

        Debug.Log("[SavePoint] Rested at " + point.place + ".");
        SoundManager.PlaySfx("menu_confirm");

        if (_renderer != null)
        {
            _renderer.color = new Color(0.7f, 0.85f, 1f, 1f);
        }
    }

    public void KneelToSave()
    {
        if (_renderer != null) _renderer.color = new Color(0.6f, 0.6f, 0.7f, 1f);
    }
}

/// <summary>
/// ArchivistNPC — the legendary NPC who keeps Silver Mountain.
///
/// He is not a final boss fight. He is the examiner: he checks the record before
/// he checks you, grants the climb only to a finished realm, and on the third
/// failure he is the one who hands you the Mastery Recap and turns his back for a
/// day. Every line he speaks is generated from the actual knowledge diagnosis.
/// </summary>
public class ArchivistNPC : MonoBehaviour, IInteractable
{
    private SpriteRenderer _renderer;

    private void Awake()
    {
        _renderer = GetComponent<SpriteRenderer>();
    }

    public void Interact(PlayerController player)
    {
        StoryModeManager story = StoryModeManager.Instance;
        StoryUI ui = StoryUI.Instance;
        if (story == null || ui == null || !story.Ready) return;

        MountainStatus status = story.SilverStatus(story.ActiveRealmId);
        Debug.Log("[Archivist] canChallenge: " + status.CanChallenge + " \u2014 " + status.Reason);
        ui.ShowMountainGate();
    }
}

/// <summary>
/// KaiserWorldPopulator — turns the generated map into the story's world.
///
/// The v0.2 generator cleared building plots for cities but had nothing to put in
/// them: every prefab reference was null in a fresh project, so the world spawned
/// empty and there was no way into a battle, a gym, or the story at all. That was
/// the "game isn't working".
///
/// This component fills the world with the story instead of with prefabs: one
/// keeper at each milestone place along the road, a save shard in every milestone
/// town, and the Archivist on the summit. It also places the player at their save
/// point when a story is resumed, because a save point you do not wake up at is
/// just a bookmark.
/// </summary>
public class KaiserWorldPopulator : MonoBehaviour
{
    private const float KeeperSpacing = 4f;

    private GameObject _root;
    private string _populatedRealm;

    private void Start()
    {
        // One frame after bootstrap, so the world and the player both exist.
        StartCoroutine(PopulateWhenReady());
    }

    private System.Collections.IEnumerator PopulateWhenReady()
    {
        while (StoryModeManager.Instance == null || !StoryModeManager.Instance.Ready
               || ProceduralWorldGeneratorHub.Cities == null || ProceduralWorldGeneratorHub.Cities.Count == 0)
        {
            yield return null;
        }
        Populate();
    }

    private void Update()
    {
        // A new character can pick a different realm, and the road's keepers are
        // per-realm — so when the story's realm changes, the world changes with it.
        StoryModeManager story = StoryModeManager.Instance;
        if (story != null && story.Ready && _populatedRealm != null
            && _populatedRealm != story.ActiveRealmId)
        {
            Populate();
        }
    }

    private void Populate()
    {
        StoryModeManager story = StoryModeManager.Instance;
        List<GeneratedCity> cities = ProceduralWorldGeneratorHub.Cities;
        string realm = story.ActiveRealmId;
        List<Milestone> milestones = story.Campaign(realm);

        if (_root != null) Destroy(_root);
        _root = new GameObject("StoryWorld");
        _populatedRealm = realm;

        Transform player = GameObject.FindWithTag("Player") != null
            ? GameObject.FindWithTag("Player").transform
            : null;

        int placed = 0;
        for (int i = 0; i < milestones.Count && i < cities.Count; i++)
        {
            Milestone milestone = milestones[i];
            Vector2 basePos = cities[i].position;

            SpawnKeeper(_root.transform, milestone, realm, new Vector2(basePos.x - KeeperSpacing, basePos.y));
            SpawnSaveShard(_root.transform, milestone, realm, new Vector2(basePos.x + KeeperSpacing, basePos.y));
            placed++;
        }

        // The Archivist stands at the top of the world.
        if (cities.Count > 0)
        {
            SpawnArchivist(_root.transform, cities[cities.Count - 1].position + new Vector2(0f, 3f));
        }

        // Aster Town: the handcrafted starting settlement, stood on the generated
        // terrain of the first city. The generator still decides where the town is
        // and what the ground under it is made of; what it contains is authored,
        // because the first twenty minutes of a game are not a good place for a
        // clearing with three rectangles in it.
        if (cities.Count > 0)
        {
            AsterTown.Build(_root.transform, realm, milestones, cities[0]);
        }

        // Landmarks, plazas and scenery: the campaign made visible on the ground,
        // so the player can see which way the story goes before walking it. The
        // starting settlement is skipped — Aster Town has already dressed it.
        OverworldDecor.Decorate(_root.transform, realm, milestones, cities, 1);

        // A resumed story wakes where it was left — at the save point, by its keeper.
        if (player != null && story.Save != null && story.Save.savePoint != null)
        {
            int index = Mathf.Max(1, story.Save.savePoint.milestoneIndex) - 1;
            if (index < cities.Count)
            {
                Vector2 home = cities[index].position;
                Vector2 bed = home + new Vector2(0f, -2f);
                // The player is placed, not walked, so the ground under them must be
                // clear before they arrive — a wake-up inside a lake is a softlock.
                OverworldDecor.ClearGround(bed, 1);
                player.position = new Vector3(bed.x, bed.y, 0f);
                Debug.Log("[KaiserWorld] " + story.Save.playerName + " wakes at "
                          + story.Save.savePoint.place + ".");
            }
        }

        Debug.Log("[KaiserWorld] Placed " + placed + " milestone keepers, "
                  + placed + " save shards and the Archivist for realm '" + realm + "'.");
    }

    private static void SpawnKeeper(Transform parent, Milestone milestone, string realm, Vector2 position)
    {
        // A keeper the player cannot reach is a milestone they cannot enter.
        OverworldDecor.ClearGround(position, 1);

        GameObject keeperObj = new GameObject("Keeper_M" + milestone.Index.ToString("00") + "_" + milestone.Keeper);
        keeperObj.transform.SetParent(parent, false);
        keeperObj.transform.position = new Vector3(position.x, position.y, 0f);

        SpriteRenderer renderer = keeperObj.AddComponent<SpriteRenderer>();
        renderer.sortingOrder = 10;
        if (PixelSpriteGenerator.Instance != null)
        {
            Color shirt = Hue(milestone.Domain, 0.55f, 0.45f);
            Color hair = Hue(milestone.Domain, 0.3f, 0.25f);
            renderer.sprite = PixelSpriteGenerator.Instance.GenerateNPCSprite(shirt, hair);
        }

        keeperObj.AddComponent<BoxCollider2D>();

        MilestoneKeeper keeper = keeperObj.AddComponent<MilestoneKeeper>();
        keeper.milestoneIndex = milestone.Index;
        keeper.realmId = realm;
        keeper.keeperName = milestone.Keeper;
        keeper.placeName = milestone.Place;
    }

    private static void SpawnSaveShard(Transform parent, Milestone milestone, string realm, Vector2 position)
    {
        OverworldDecor.ClearGround(position, 1);

        GameObject shardObj = new GameObject("SavePoint_M" + milestone.Index.ToString("00"));
        shardObj.transform.SetParent(parent, false);
        shardObj.transform.position = new Vector3(position.x, position.y, 0f);

        SpriteRenderer renderer = shardObj.AddComponent<SpriteRenderer>();
        renderer.sortingOrder = 9;
        renderer.sprite = ShardSprite();

        BoxCollider2D collider = shardObj.AddComponent<BoxCollider2D>();
        collider.isTrigger = true;

        SavePointObject shard = shardObj.AddComponent<SavePointObject>();
        shard.milestoneIndex = milestone.Index;
        shard.realmId = realm;
        shard.placeName = milestone.Place;
    }

    private static void SpawnArchivist(Transform parent, Vector2 position)
    {
        OverworldDecor.ClearGround(position, 1);

        GameObject archivistObj = new GameObject("Archivist");
        archivistObj.transform.SetParent(parent, false);
        archivistObj.transform.position = new Vector3(position.x, position.y, 0f);

        SpriteRenderer renderer = archivistObj.AddComponent<SpriteRenderer>();
        renderer.sortingOrder = 10;
        if (PixelSpriteGenerator.Instance != null)
        {
            // Silver and shadow — the summit's keeper dresses like the mountain.
            renderer.sprite = PixelSpriteGenerator.Instance.GenerateNPCSprite(
                new Color(0.78f, 0.82f, 0.92f), new Color(0.16f, 0.17f, 0.22f));
        }

        archivistObj.AddComponent<BoxCollider2D>();
        archivistObj.AddComponent<ArchivistNPC>();
    }

    /// <summary>A small crystal, drawn pixel by pixel: the mark of a save point.</summary>
    private static Sprite ShardSprite()
    {
        Texture2D tex = new Texture2D(12, 16, TextureFormat.RGBA32, false);
        tex.filterMode = FilterMode.Point;

        Color clear = Color.clear;
        Color body = new Color(0.65f, 0.8f, 1f, 1f);
        Color edge = new Color(0.85f, 0.94f, 1f, 1f);

        for (int x = 0; x < 12; x++)
        {
            for (int y = 0; y < 16; y++)
            {
                int distance = Mathf.Abs(x - 6) + Mathf.Abs(y - 8);
                if (distance <= 5)
                {
                    tex.SetPixel(x, y, distance >= 4 ? edge : body);
                }
                else
                {
                    tex.SetPixel(x, y, clear);
                }
            }
        }
        tex.Apply();
        return Sprite.Create(tex, new Rect(0, 0, 12, 16), new Vector2(0.5f, 0.5f), 16f);
    }

    /// <summary>A stable colour per domain, so each chapter's keeper reads distinctly.</summary>
    private static Color Hue(string seed, float saturation, float value)
    {
        int hash = 0;
        for (int i = 0; i < seed.Length; i++) hash = hash * 31 + seed[i];
        float hue = (hash % 1000) / 1000f;
        return Color.HSVToRGB(hue, saturation, value);
    }

    private void OnGUI()
    {
        // The interaction hint, Pokémon-style: what Z will do, right here.
        GameObject playerObj = GameObject.FindWithTag("Player");
        if (playerObj == null) return;

        IInteractable nearest = null;
        float best = 2.2f;
        Collider2D[] nearby = Physics2D.OverlapCircleAll(playerObj.transform.position, 2.2f);
        for (int i = 0; i < nearby.Length; i++)
        {
            IInteractable candidate = nearby[i].GetComponent<IInteractable>();
            if (candidate == null) continue;
            float distance = Vector2.Distance(nearby[i].transform.position, playerObj.transform.position);
            if (distance < best) { best = distance; nearest = candidate; }
        }
        if (nearest == null)
        {
            ShowPlaceName(playerObj);
            return;
        }

        string label;
        if (nearest is MilestoneKeeper) label = "Z \u2014 speak with " + ((MilestoneKeeper)nearest).keeperName;
        else if (nearest is SavePointObject) label = "Z \u2014 rest at the save shard";
        else if (nearest is ArchivistNPC) label = "Z \u2014 approach the Archivist";
        else if (nearest is KnowledgeGate) label = ((KnowledgeGate)nearest).IsOpen
            ? "Z \u2014 the open gate"
            : "Z \u2014 examine the seized mechanism";
        else if (nearest is QuestGiver) label = "Z \u2014 speak with " + ((QuestGiver)nearest).speakerName;
        else if (nearest is TownSign) label = "Z \u2014 read the sign";
        else return;

        GUI.Box(new Rect((Screen.width - 320f) / 2f, Screen.height - 64f, 320f, 30f), label);
    }

    /// <summary>
    /// With nothing to interact with, name the place. Walking past a monument and
    /// being told "Belhaven — Milestone 4" is what turns scenery into a map.
    /// </summary>
    private static void ShowPlaceName(GameObject playerObj)
    {
        Collider2D[] nearby = Physics2D.OverlapCircleAll(playerObj.transform.position, 4.5f);
        Landmark closest = null;
        float best = float.MaxValue;

        for (int i = 0; i < nearby.Length; i++)
        {
            Landmark landmark = nearby[i].GetComponent<Landmark>();
            if (landmark == null) continue;

            float distance = Vector2.Distance(nearby[i].transform.position, playerObj.transform.position);
            if (distance < best) { best = distance; closest = landmark; }
        }

        if (closest == null) return;

        GUI.Box(new Rect((Screen.width - 360f) / 2f, Screen.height - 92f, 360f, 26f),
                closest.placeName + "  ·  Milestone " + closest.milestoneIndex);
    }
}

/// <summary>
/// Where the world generator publishes what it built.
///
/// The generator builds its city list at runtime, and the populator needs that
/// list without owning the generator. A tiny static hub keeps the two decoupled —
/// no cross-reference, no singleton ordering traps.
/// </summary>
public static class ProceduralWorldGeneratorHub
{
    public static List<GeneratedCity> Cities { get; set; }

    //: The tilemaps the world was generated into. The bootstrap owns them, the
    //: decorator needs them to pave plazas, so they are published here rather
    //: than searched for by name (which breaks the moment a scene renames one).
    public static UnityEngine.Tilemaps.Tilemap Ground { get; set; }
    public static UnityEngine.Tilemaps.Tilemap Path { get; set; }
    public static UnityEngine.Tilemaps.Tilemap Decoration { get; set; }
    public static UnityEngine.Tilemaps.Tilemap Water { get; set; }
    public static UnityEngine.Tilemaps.Tilemap Collision { get; set; }
}
