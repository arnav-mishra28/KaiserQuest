#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;
using UnityEngine.Tilemaps;
using UnityEditor.SceneManagement;

/// <summary>
/// KaiserQuestSetup — Editor tool to set up the project on first open.
/// Run from menu: KaiserQuest > Setup Project
/// </summary>
public class KaiserQuestSetup : EditorWindow
{
    [MenuItem("KaiserQuest/Setup Project")]
    public static void ShowWindow()
    {
        GetWindow<KaiserQuestSetup>("KaiserQuest Setup");
    }

    [MenuItem("KaiserQuest/Create Overworld Scene")]
    public static void CreateOverworldScene()
    {
        // Create a new scene
        var scene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);

        // === CAMERA SETUP ===
        Camera cam = Camera.main;
        cam.orthographic = true;
        cam.orthographicSize = 8f;
        cam.backgroundColor = new Color(0.1f, 0.1f, 0.15f);

        // Add CameraFollow
        CameraFollow camFollow = cam.gameObject.AddComponent<CameraFollow>();

        // === CREATE GRID FOR TILEMAPS ===
        GameObject gridObj = new GameObject("Grid");
        Grid grid = gridObj.AddComponent<Grid>();
        grid.cellSize = new Vector3(1, 1, 0);

        // Ground Tilemap
        GameObject groundObj = new GameObject("Ground");
        groundObj.transform.parent = gridObj.transform;
        Tilemap groundTilemap = groundObj.AddComponent<Tilemap>();
        TilemapRenderer groundRenderer = groundObj.AddComponent<TilemapRenderer>();
        groundRenderer.sortingLayerName = "Default";
        groundRenderer.sortingOrder = 0;

        // Path Tilemap
        GameObject pathObj = new GameObject("Path");
        pathObj.transform.parent = gridObj.transform;
        Tilemap pathTilemap = pathObj.AddComponent<Tilemap>();
        TilemapRenderer pathRenderer = pathObj.AddComponent<TilemapRenderer>();
        pathRenderer.sortingLayerName = "Default";
        pathRenderer.sortingOrder = 1;

        // Decoration Tilemap
        GameObject decoObj = new GameObject("Decoration");
        decoObj.transform.parent = gridObj.transform;
        Tilemap decoTilemap = decoObj.AddComponent<Tilemap>();
        TilemapRenderer decoRenderer = decoObj.AddComponent<TilemapRenderer>();
        decoRenderer.sortingLayerName = "Default";
        decoRenderer.sortingOrder = 2;

        // Water Tilemap
        GameObject waterObj = new GameObject("Water");
        waterObj.transform.parent = gridObj.transform;
        Tilemap waterTilemap = waterObj.AddComponent<Tilemap>();
        TilemapRenderer waterRenderer = waterObj.AddComponent<TilemapRenderer>();
        waterRenderer.sortingLayerName = "Default";
        waterRenderer.sortingOrder = 0;

        // Collision Tilemap (invisible)
        GameObject colObj = new GameObject("Collision");
        colObj.transform.parent = gridObj.transform;
        Tilemap colTilemap = colObj.AddComponent<Tilemap>();
        TilemapRenderer colRenderer = colObj.AddComponent<TilemapRenderer>();
        colRenderer.enabled = false;
        TilemapCollider2D colCollider = colObj.AddComponent<TilemapCollider2D>();

        // === MANAGERS ===
        // GameBootstrap
        GameObject bootstrapObj = new GameObject("GameBootstrap");
        GameBootstrap bootstrap = bootstrapObj.AddComponent<GameBootstrap>();
        bootstrap.groundTilemap = groundTilemap;
        bootstrap.pathTilemap = pathTilemap;
        bootstrap.decorationTilemap = decoTilemap;
        bootstrap.collisionTilemap = colTilemap;
        bootstrap.waterTilemap = waterTilemap;

        // World Generator
        GameObject worldGenObj = new GameObject("WorldGenerator");
        ProceduralWorldGenerator worldGen = worldGenObj.AddComponent<ProceduralWorldGenerator>();
        worldGen.groundTilemap = groundTilemap;
        worldGen.pathTilemap = pathTilemap;
        worldGen.decorationTilemap = decoTilemap;
        worldGen.collisionTilemap = colTilemap;
        worldGen.waterTilemap = waterTilemap;
        bootstrap.worldGenerator = worldGen;

        // World Manager
        GameObject worldMgrObj = new GameObject("WorldManager");
        worldMgrObj.AddComponent<WorldManager>();

        // === UI CANVAS ===
        // Dialog System
        CreateDialogCanvas();

        // Battle Canvas
        CreateBattleCanvas();

        // HUD Canvas
        CreateHUDCanvas();

        // Save scene
        EditorSceneManager.SaveScene(scene, "Assets/Scenes/Overworld.unity");
        Debug.Log("[Setup] Overworld scene created and saved!");
    }

    [MenuItem("KaiserQuest/Create Main Menu Scene")]
    public static void CreateMainMenuScene()
    {
        var scene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);

        Camera cam = Camera.main;
        cam.backgroundColor = new Color(0.05f, 0.05f, 0.1f);

        // Create UI
        GameObject canvasObj = new GameObject("MainMenuCanvas");
        Canvas canvas = canvasObj.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvasObj.AddComponent<UnityEngine.UI.CanvasScaler>();
        canvasObj.AddComponent<UnityEngine.UI.GraphicRaycaster>();

        // Add MainMenuUI
        MainMenuUI menuUI = canvasObj.AddComponent<MainMenuUI>();

        // Event System
        if (FindObjectOfType<UnityEngine.EventSystems.EventSystem>() == null)
        {
            GameObject eventSystem = new GameObject("EventSystem");
            eventSystem.AddComponent<UnityEngine.EventSystems.EventSystem>();
            eventSystem.AddComponent<UnityEngine.EventSystems.StandaloneInputModule>();
        }

        EditorSceneManager.SaveScene(scene, "Assets/Scenes/MainMenu.unity");
        Debug.Log("[Setup] Main Menu scene created and saved!");
    }

    private static void CreateDialogCanvas()
    {
        GameObject canvasObj = new GameObject("DialogCanvas");
        Canvas canvas = canvasObj.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = 100;
        var scaler = canvasObj.AddComponent<UnityEngine.UI.CanvasScaler>();
        scaler.uiScaleMode = UnityEngine.UI.CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(960, 640);
        canvasObj.AddComponent<UnityEngine.UI.GraphicRaycaster>();

        // Dialog System component
        DialogSystem dialogSystem = canvasObj.AddComponent<DialogSystem>();

        // Dialog Panel (bottom of screen)
        GameObject panel = CreateUIPanel(canvasObj.transform, "DialogPanel", 
            new Vector2(0, 0), new Vector2(1, 0.3f), new Color(0.1f, 0.1f, 0.2f, 0.95f));
        dialogSystem.dialogPanel = panel;

        Debug.Log("[Setup] Dialog Canvas created.");
    }

    private static void CreateBattleCanvas()
    {
        GameObject canvasObj = new GameObject("BattleCanvas");
        Canvas canvas = canvasObj.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = 50;
        var scaler = canvasObj.AddComponent<UnityEngine.UI.CanvasScaler>();
        scaler.uiScaleMode = UnityEngine.UI.CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(960, 640);
        canvasObj.AddComponent<UnityEngine.UI.GraphicRaycaster>();

        BattleManager battleManager = canvasObj.AddComponent<BattleManager>();
        battleManager.battleCanvas = canvasObj;

        canvasObj.SetActive(false);

        Debug.Log("[Setup] Battle Canvas created.");
    }

    private static void CreateHUDCanvas()
    {
        GameObject canvasObj = new GameObject("HUDCanvas");
        Canvas canvas = canvasObj.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvas.sortingOrder = 10;
        var scaler = canvasObj.AddComponent<UnityEngine.UI.CanvasScaler>();
        scaler.uiScaleMode = UnityEngine.UI.CanvasScaler.ScaleMode.ScaleWithScreenSize;
        scaler.referenceResolution = new Vector2(960, 640);
        canvasObj.AddComponent<UnityEngine.UI.GraphicRaycaster>();

        canvasObj.AddComponent<HUD>();

        Debug.Log("[Setup] HUD Canvas created.");
    }

    private static GameObject CreateUIPanel(Transform parent, string name, Vector2 anchorMin, Vector2 anchorMax, Color color)
    {
        GameObject panel = new GameObject(name);
        panel.transform.SetParent(parent, false);

        RectTransform rect = panel.AddComponent<RectTransform>();
        rect.anchorMin = anchorMin;
        rect.anchorMax = anchorMax;
        rect.offsetMin = Vector2.zero;
        rect.offsetMax = Vector2.zero;

        UnityEngine.UI.Image img = panel.AddComponent<UnityEngine.UI.Image>();
        img.color = color;

        return panel;
    }

    private void OnGUI()
    {
        GUILayout.Label("KaiserQuest Project Setup", EditorStyles.boldLabel);
        GUILayout.Space(10);

        GUILayout.Label("Click buttons to set up the project:", EditorStyles.label);
        GUILayout.Space(5);

        if (GUILayout.Button("1. Create Main Menu Scene", GUILayout.Height(30)))
        {
            CreateMainMenuScene();
        }

        if (GUILayout.Button("2. Create Overworld Scene", GUILayout.Height(30)))
        {
            CreateOverworldScene();
        }

        GUILayout.Space(20);
        GUILayout.Label("After creating scenes, add them to Build Settings:", EditorStyles.label);
        GUILayout.Label("File > Build Settings > Add Open Scenes", EditorStyles.miniLabel);

        GUILayout.Space(10);
        if (GUILayout.Button("Open Build Settings", GUILayout.Height(25)))
        {
            EditorWindow.GetWindow(System.Type.GetType("UnityEditor.BuildPlayerWindow,UnityEditor"));
        }
    }
}
#endif
