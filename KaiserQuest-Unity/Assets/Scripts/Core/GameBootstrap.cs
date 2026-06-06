using UnityEngine;
using UnityEngine.Tilemaps;

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

        // Create managers if they don't exist
        EnsureManager<GameManager>("GameManager");
        EnsureManager<SceneLoader>("SceneLoader");
        EnsureManager<QuestionBank>("QuestionBank");
        EnsureManager<AIClient>("AIClient");
        EnsureManager<PvPManager>("PvPManager");
        EnsureManager<SideQuestManager>("SideQuestManager");
        EnsureManager<PixelSpriteGenerator>("PixelSpriteGenerator");
        EnsureManager<SoundManager>("SoundManager");
        EnsureManager<WorldManager>("WorldManager");

        // DialogSystem, BattleManager, HUD need Canvas — create in-scene
        EnsureSceneManager<DialogSystem>("DialogSystem");
        EnsureSceneManager<BattleManager>("BattleManager");
        EnsureSceneManager<HUD>("HUD");

        Debug.Log("[GameBootstrap] All managers initialized.");
    }

    private void Start()
    {
        // Auto-discover tilemaps from Grid in scene
        AutoDiscoverTilemaps();

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
        }

        // Spawn player
        SpawnPlayer();

        // Start music
        if (SoundManager.Instance != null)
            SoundManager.Instance.PlayMusic("overworld");

        // Set game state
        if (GameManager.Instance != null)
            GameManager.Instance.SetGameState(GameState.Overworld);

        Debug.Log("[GameBootstrap] Game ready!");
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
        if (worldGenerator == null) return;

        // Create runtime tiles from generated sprites
        if (worldGenerator.grassTile == null)
            worldGenerator.grassTile = CreateTileFromSprite(PixelSpriteGenerator.Instance.GenerateGrassTile());
        if (worldGenerator.pathTile == null)
            worldGenerator.pathTile = CreateTileFromSprite(PixelSpriteGenerator.Instance.GeneratePathTile());
        if (worldGenerator.waterTile == null)
            worldGenerator.waterTile = CreateTileFromSprite(PixelSpriteGenerator.Instance.GenerateWaterTile());
        if (worldGenerator.treeTile == null)
            worldGenerator.treeTile = CreateTileFromSprite(PixelSpriteGenerator.Instance.GenerateTreeTile());
        if (worldGenerator.wallTile == null)
            worldGenerator.wallTile = CreateTileFromSprite(PixelSpriteGenerator.Instance.GenerateWallTile());

        Debug.Log("[GameBootstrap] Runtime tiles generated.");
    }

    private UnityEngine.Tilemaps.Tile CreateTileFromSprite(Sprite sprite)
    {
        var tile = ScriptableObject.CreateInstance<UnityEngine.Tilemaps.Tile>();
        tile.sprite = sprite;
        tile.colliderType = UnityEngine.Tilemaps.Tile.ColliderType.None;
        return tile;
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

            // Add SpriteRenderer
            SpriteRenderer sr = playerObj.AddComponent<SpriteRenderer>();
            sr.sortingOrder = 10;

            // Generate player sprite
            if (PixelSpriteGenerator.Instance != null)
            {
                sr.sprite = PixelSpriteGenerator.Instance.GeneratePlayerSprite(PlayerDirection.Down);
            }

            // Add PlayerController
            PlayerController pc = playerObj.AddComponent<PlayerController>();
            pc.spriteRenderer = sr;

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
