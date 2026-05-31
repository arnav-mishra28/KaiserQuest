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

        Debug.Log("[GameBootstrap] All managers initialized.");
    }

    private void Start()
    {
        // Generate pixel art tiles
        SetupTiles();

        // Generate world if needed
        if (generateWorldOnStart && worldGenerator != null)
        {
            worldGenerator.GenerateWorld();
        }

        // Spawn player
        SpawnPlayer();

        Debug.Log("[GameBootstrap] Game ready!");
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
}
