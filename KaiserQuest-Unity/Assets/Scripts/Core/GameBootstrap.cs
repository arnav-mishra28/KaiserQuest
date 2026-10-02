using UnityEngine;
using UnityEngine.Tilemaps;
using KaiserQuest.Knowledge;
using KaiserQuest.Story;

/// <summary>
/// GameBootstrap — Initializes the game on startup.
/// Creates all manager singletons, generates initial sprites, and sets up the world.
/// Attach this to a persistent GameObject in the first scene.
/// </summary>
public class GameBootstrap : MonoBehaviour
{
    [Header("Prefab References (Optional - auto-creates if null)")]
    public GameObject gameManagerPrefab;
    public GameObject sceneLoaderPrefab;
    public GameObject questionBankPrefab;
    public GameObject aiClientPrefab;
    public GameObject pvpManagerPrefab;
    public GameObject sideQuestManagerPrefab;
    public GameObject dialogSystemPrefab;
    public GameObject battleManagerPrefab;
    public GameObject spriteGeneratorPrefab;

    [Header("World Generation")]
    public bool generateWorldOnStart = true;
    public ProceduralWorldGenerator worldGenerator;

    [Header("Story")]
    [Tooltip("Continue the existing story save on launch, if there is one.")]
    public bool loadSaveOnStart = true;

    [Header("Tilemaps")]
    public Tilemap groundTilemap;
    public Tilemap pathTilemap;
    public Tilemap decorationTilemap;
    public Tilemap collisionTilemap;
    public Tilemap waterTilemap;

    [Header("Player")]
    public GameObject playerPrefab;

    private void Awake()
    {
        Debug.Log("[GameBootstrap] Initializing KaiserQuest...");

        // Create managers if they don't exist.
        //
        // KnowledgeEngine and StoryModeManager come first and in this order: the
        // knowledge engine loads the concept graph, the verified question banks and the
        // player's trace from Resources, and Story Mode binds to it on creation. On a
        // 2 GB device there is no server to ask, so this is the whole brain of the game
        // starting up in-process.
        EnsureManager<GameManager>("GameManager");
        EnsureManager<KnowledgeEngine>("KnowledgeEngine");
        EnsureManager<StoryModeManager>("StoryModeManager");
        EnsureManager<StoryUI>("StoryUI");
        EnsureManager<SceneLoader>("SceneLoader");
        EnsureManager<QuestionBank>("QuestionBank");
        EnsureManager<AIClient>("AIClient");
        EnsureManager<PvPManager>("PvPManager");
        EnsureManager<SideQuestManager>("SideQuestManager");
        EnsureManager<PixelSpriteGenerator>("PixelSpriteGenerator");
        EnsureManager<SoundManager>("SoundManager");
        EnsureManager<WorldManager>("WorldManager");

        // The populator stands the story up inside the generated world (keepers,
        // save shards, the Archivist). Scene-scoped: the world is re-populated per scene.
        EnsureSceneManager<KaiserWorldPopulator>("KaiserWorldPopulator");

        // DialogSystem, BattleManager, HUD need Canvas — create in-scene
        EnsureSceneManager<DialogSystem>("DialogSystem");
        EnsureSceneManager<BattleManager>("BattleManager");
        EnsureSceneManager<HUD>("HUD");

        Debug.Log("[GameBootstrap] All managers initialized.");
    }

    private void Start()
    {
        // A scene may contain nothing at all (the menu scenes ship bare), so the
        // bootstrap builds its own camera and tilemaps before anything needs them.
        EnsureWorldInfrastructure();

        // Auto-discover tilemaps from Grid in scene
        AutoDiscoverTilemaps();

        // Water and trees are painted into the collision tilemap; without a
        // collider on it, that work is decorative and the player wades through
        // lakes. Solid it up before anything reads it.
        MakeCollisionTilemapSolid();

        // Generate pixel art tiles
        SetupTiles();

        // Auto-create WorldGenerator if needed
        if (generateWorldOnStart && worldGenerator == null)
        {
            worldGenerator = FindObjectOfType<ProceduralWorldGenerator>();
            if (worldGenerator == null)
            {
                GameObject wgObj = new GameObject("WorldGenerator");
                worldGenerator = wgObj.AddComponent<ProceduralWorldGenerator>();
            }
        }

        // Connect tilemaps to world generator
        if (worldGenerator != null)
        {
            if (worldGenerator.groundTilemap == null) worldGenerator.groundTilemap = groundTilemap;
            if (worldGenerator.pathTilemap == null) worldGenerator.pathTilemap = pathTilemap;
            if (worldGenerator.decorationTilemap == null) worldGenerator.decorationTilemap = decorationTilemap;
            if (worldGenerator.collisionTilemap == null) worldGenerator.collisionTilemap = collisionTilemap;
            if (worldGenerator.waterTilemap == null) worldGenerator.waterTilemap = waterTilemap;
        }

        // Generate runtime tiles from sprites
        GenerateRuntimeTiles();

        // Generate world if needed
        if (generateWorldOnStart && worldGenerator != null)
        {
            worldGenerator.GenerateWorld();

            // Publish what was built so the story populator can stand keepers and
            // save shards along the road the generator drew.
            ProceduralWorldGeneratorHub.Cities = worldGenerator.generatedCities;
        }

        // Spawn player
        SpawnPlayer();

        // Start music
        if (SoundManager.Instance != null)
            SoundManager.Instance.PlayMusic("overworld");

        // Continue the story where it was left, if it was left anywhere.
        // ContinueStory also opens the first story screen: creation for a new
        // player, the title for a returning one.
        ContinueStory();

        // Set game state (the story overlay, if open, holds the game paused)
        if (GameManager.Instance != null)
            GameManager.Instance.SetGameState(GameState.Overworld);

        Debug.Log("[GameBootstrap] Game ready!");
    }

    /// <summary>
    /// Make sure a camera and a Grid with the five tilemaps exist, creating them
    /// when the scene does not have them. This is what lets the same bootstrap run
    /// in the Overworld scene, the menu scenes, or an empty scene.
    /// </summary>
    private void EnsureWorldInfrastructure()
    {
        if (Camera.main == null)
        {
            GameObject camObj = new GameObject("Main Camera");
            camObj.tag = "MainCamera";
            Camera cam = camObj.AddComponent<Camera>();
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.08f, 0.09f, 0.13f, 1f);
            cam.orthographic = true;
            cam.orthographicSize = 8f;
            camObj.AddComponent<CameraFollow>();
            Debug.Log("[GameBootstrap] No camera in scene — created one.");
        }

        UnityEngine.Grid grid = FindObjectOfType<UnityEngine.Grid>();
        if (grid == null)
        {
            GameObject gridObj = new GameObject("Grid");
            gridObj.AddComponent<UnityEngine.Grid>();
            AddTilemapChild(gridObj.transform, "GroundTilemap", 0);
            AddTilemapChild(gridObj.transform, "PathTilemap", 1);
            AddTilemapChild(gridObj.transform, "DecorationTilemap", 2);
            AddTilemapChild(gridObj.transform, "WaterTilemap", 3);
            AddTilemapChild(gridObj.transform, "CollisionTilemap", 4);
            Debug.Log("[GameBootstrap] No Grid in scene — created tilemaps.");
        }
    }

    private static void AddTilemapChild(Transform parent, string name, int sortingOrder)
    {
        GameObject obj = new GameObject(name);
        obj.transform.SetParent(parent, false);
        obj.AddComponent<Tilemap>();
        TilemapRenderer renderer = obj.AddComponent<TilemapRenderer>();
        renderer.sortingOrder = sortingOrder;

        // The collision tilemap carries the colliders; its tiles exist to be solid,
        // not to be seen. Drawing them would paint over the water and trees that are
        // the visible reason the player is being stopped.
        if (name == "CollisionTilemap")
        {
            renderer.enabled = false;
            obj.AddComponent<TilemapCollider2D>();
        }
    }

    /// <summary>Make sure whatever collision tilemap the scene has will actually stop the player.</summary>
    private void MakeCollisionTilemapSolid()
    {
        if (collisionTilemap == null) return;

        if (collisionTilemap.GetComponent<TilemapCollider2D>() == null)
            collisionTilemap.gameObject.AddComponent<TilemapCollider2D>();

        TilemapRenderer renderer = collisionTilemap.GetComponent<TilemapRenderer>();
        if (renderer != null) renderer.enabled = false;
    }

    private void AutoDiscoverTilemaps()
    {
        if (groundTilemap != null) return; // Already assigned

        // Find the Grid object and its tilemap children
        UnityEngine.Grid grid = FindObjectOfType<UnityEngine.Grid>();
        if (grid == null) return;

        foreach (Transform child in grid.transform)
        {
            Tilemap tm = child.GetComponent<Tilemap>();
            if (tm == null) continue;

            string name = child.name.ToLower();
            if (name.Contains("ground")) groundTilemap = tm;
            else if (name.Contains("path")) pathTilemap = tm;
            else if (name.Contains("water")) waterTilemap = tm;
            else if (name.Contains("decor")) decorationTilemap = tm;
            else if (name.Contains("collis")) collisionTilemap = tm;
        }

        Debug.Log("[GameBootstrap] Tilemaps auto-discovered from Grid.");
    }

    private void GenerateRuntimeTiles()
    {
        if (PixelSpriteGenerator.Instance == null) return;

        // The palette lives in RuntimeTileset so the collision tile can carry a real
        // collider (ColliderType.Grid) instead of the None the inline version used —
        // which made the wall tile invisible *and* inert, so water and trees never
        // actually stopped anyone.
        RuntimeTileset.Build();
        RuntimeTileset.ApplyTo(worldGenerator);

        // Publish the tilemaps: the story decorator paves plazas into them, and it
        // has no business hunting the scene graph for them by name.
        ProceduralWorldGeneratorHub.Ground = groundTilemap;
        ProceduralWorldGeneratorHub.Path = pathTilemap;
        ProceduralWorldGeneratorHub.Decoration = decorationTilemap;
        ProceduralWorldGeneratorHub.Water = waterTilemap;
        ProceduralWorldGeneratorHub.Collision = collisionTilemap;

        Debug.Log("[GameBootstrap] Runtime tiles generated.");
    }

    private void SetupTiles()
    {
        if (PixelSpriteGenerator.Instance == null) return;

        // Create runtime tiles from generated sprites
        // These will be used by the tilemap system

        Debug.Log("[GameBootstrap] Pixel art tiles ready.");
    }

    private void SpawnPlayer()
    {
        if (playerPrefab == null)
        {
            // Create player from scratch
            GameObject playerObj = new GameObject("Player");
            playerObj.tag = "Player";
            playerObj.layer = LayerMask.NameToLayer("Default");

            // The sprite lives on a child "Body" so the walk bob can move it
            // without fighting the controller's grid snapping, which owns the root.
            GameObject bodyObj = new GameObject("Body");
            bodyObj.transform.SetParent(playerObj.transform, false);

            SpriteRenderer sr = bodyObj.AddComponent<SpriteRenderer>();
            // Above keepers, shards and monuments, so the player is never hidden
            // behind the thing they are walking up to.
            sr.sortingOrder = 12;

            // Generate player sprite
            if (PixelSpriteGenerator.Instance != null)
            {
                sr.sprite = PixelSpriteGenerator.Instance.GeneratePlayerSprite(PlayerDirection.Down);
            }

            // Add PlayerController
            PlayerController pc = playerObj.AddComponent<PlayerController>();
            pc.spriteRenderer = sr;
            pc.gridSize = 1f;

            // Add Collider
            BoxCollider2D col = playerObj.AddComponent<BoxCollider2D>();
            col.size = new Vector2(0.8f, 0.8f);
            col.offset = new Vector2(0, 0.2f);

            // Add Rigidbody2D (kinematic for grid-based movement)
            Rigidbody2D rb = playerObj.AddComponent<Rigidbody2D>();
            rb.bodyType = RigidbodyType2D.Kinematic;
            rb.gravityScale = 0;

            // Position at starter town
            if (worldGenerator != null && worldGenerator.generatedCities.Count > 0)
            {
                playerObj.transform.position = new Vector3(
                    worldGenerator.generatedCities[0].position.x,
                    worldGenerator.generatedCities[0].position.y,
                    0
                );
            }
            else
            {
                playerObj.transform.position = Vector3.zero;
            }

            // The body: draws the created appearance, faces the walking direction,
            // and bobs on the spot while moving.
            PlayerSpriteAnimator animator = playerObj.AddComponent<PlayerSpriteAnimator>();
            animator.body = bodyObj.transform;

            // The status plate: who you are, where the campaign has you, and the controls.
            playerObj.AddComponent<OverworldHUD>();

            // Setup camera to follow player
            Camera mainCam = Camera.main;
            if (mainCam != null)
            {
                CameraFollow camFollow = mainCam.GetComponent<CameraFollow>();
                if (camFollow == null)
                    camFollow = mainCam.gameObject.AddComponent<CameraFollow>();
                camFollow.target = playerObj.transform;
                camFollow.SnapToTarget();
            }

            Debug.Log("[GameBootstrap] Player spawned.");
        }
    }

    /// <summary>
    /// Pick up the last story save.
    ///
    /// A save knows its own realm and its own save point, so the player is returned to
    /// the place they rested rather than to a menu — which is exactly what the Silver
    /// Mountain rule requires to be meaningful.
    /// </summary>
    private void ContinueStory()
    {
        if (!loadSaveOnStart) return;

        StoryModeManager story = StoryModeManager.Instance;
        if (story == null) return;

        if (!story.HasSave(story.saveSlotId))
        {
            Debug.Log("[GameBootstrap] No story save yet — character creation is due.");
            if (StoryUI.Instance != null) StoryUI.Instance.Boot();
            return;
        }

        SaveGameData save = story.LoadGame(story.saveSlotId);
        if (save == null)
        {
            Debug.LogWarning("[GameBootstrap] Story save could not be read; starting fresh.");
            return;
        }

        Debug.Log("[GameBootstrap] Resumed " + save.playerName + " in " + save.realm
                  + " at " + (save.savePoint != null ? save.savePoint.place : "the beginning") + ".");

        if (GameManager.Instance != null)
            GameManager.Instance.playerData.playerName = save.playerName;

        // A returning player gets the title screen: continue, new character, or
        // delete — the world is already standing behind it.
        if (StoryUI.Instance != null) StoryUI.Instance.Boot();
    }

    private void EnsureManager<T>(string name) where T : MonoBehaviour
    {
        if (FindObjectOfType<T>() == null)
        {
            GameObject obj = new GameObject(name);
            obj.AddComponent<T>();
            DontDestroyOnLoad(obj);
        }
    }

    private void EnsureSceneManager<T>(string name) where T : MonoBehaviour
    {
        if (FindObjectOfType<T>() == null)
        {
            GameObject obj = new GameObject(name);
            obj.AddComponent<T>();
            // Scene managers stay in scene, not DontDestroyOnLoad
        }
    }
}
