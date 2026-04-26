// World3DRenderer.cs — 2.5D World Renderer
// Sets up a perspective camera, renders tile quads on a ground plane,
// and places axis-aligned billboard sprites for trees, buildings, and characters.
using UnityEngine;
using System.Collections.Generic;

public class World3DRenderer : MonoBehaviour
{
    public static World3DRenderer Instance { get; private set; }
    void Awake() { Instance = this; }

    // ── Public NPC data struct ────────────────────────────────────────────────
    public struct NPCInfo
    {
        public Vector2Int pos;
        public Color      shirt;
        public bool       isTeacher;
        public bool       isDuel;
    }

    // ── Camera parameters ─────────────────────────────────────────────────────
    // Pokemon HG/SS style: slightly behind and above, ~43° tilt.
    const float CAM_FOV  = 55f;
    const float CAM_Y    = 7.5f;
    const float CAM_Z    = -2.5f;   // behind tile Z=0
    const int   COLS     = 15;
    const int   ROWS     = 10;

    static Vector3 CamPos    => new(COLS*0.5f, CAM_Y, CAM_Z);
    static Vector3 CamTarget => new(COLS*0.5f, 0f,    ROWS*0.48f);

    // ── Scene objects ─────────────────────────────────────────────────────────
    Camera     _cam;
    GameObject _groundGO;
    readonly List<GameObject> _sceneObjects = new();
    GameObject _playerGO;
    readonly List<GameObject> _npcGOs = new();
    GameObject _itemGO;
    float      _itemTime;

    // ── Build API ─────────────────────────────────────────────────────────────
    public void Init(int[,] map, Color subjectColor, NPCInfo[] npcs,
                     bool hasItem, Vector2Int itemPos)
    {
        Cleanup();
        SetupCamera();
        BuildGround(map, subjectColor);
        BuildVerticalObjects(map, subjectColor);
        BuildNPCs(npcs);
        BuildPlayer(new Vector2Int(7, 8));
        if (hasItem) BuildItem(itemPos, subjectColor);
    }

    public void SetCameraActive(bool on)
    {
        if (_cam != null) _cam.enabled = on;
    }

    // Call every frame from WorldController with the player's pixel-space position.
    public void UpdatePlayer(Vector2 pixelPos, bool hasItem, Vector2Int itemPos)
    {
        const float PIX = 32f; // TS
        if (_playerGO != null) {
            float wx = pixelPos.x / PIX + 0.5f;
            float wz = pixelPos.y / PIX + 0.5f;
            var tgt = new Vector3(wx, 0f, wz);
            _playerGO.transform.position =
                Vector3.Lerp(_playerGO.transform.position, tgt, Time.deltaTime * 30f);
        }
        // Pulse item sparkle
        if (_itemGO != null) {
            _itemTime += Time.deltaTime;
            float sc = 0.85f + 0.15f * Mathf.Sin(_itemTime * 4f);
            _itemGO.transform.localScale = new Vector3(sc, sc, 1f);
            if (!hasItem) _itemGO.SetActive(false);
        }
    }

    // ── Internal setup ────────────────────────────────────────────────────────
    void SetupCamera()
    {
        var go = new GameObject("World3DCam");
        _cam = go.AddComponent<Camera>();
        _cam.fieldOfView    = CAM_FOV;
        _cam.nearClipPlane  = 0.1f;
        _cam.farClipPlane   = 60f;
        _cam.clearFlags     = CameraClearFlags.Depth; // render ON TOP of background cam
        _cam.depth          = 1;
        _cam.orthographic   = false;
        go.transform.position = CamPos;
        go.transform.LookAt(CamTarget);
    }

    void BuildGround(int[,] map, Color subjectColor)
    {
        var tex = TexGen.BuildTilemap(map, subjectColor);
        _groundGO = MakeQuad("Ground",
            new Vector3(COLS*0.5f, 0f, ROWS*0.5f),
            Quaternion.Euler(90, 0, 0),
            new Vector3(COLS, ROWS, 1f),
            tex, false);
    }

    void BuildVerticalObjects(int[,] map, Color subjectColor)
    {
        for (int r = 0; r < ROWS; r++)
        for (int c = 0; c < COLS; c++) {
            int tile = map[r, c];
            float wx = c + 0.5f, wz = r + 0.5f;
            switch (tile) {
                case 1: // Tree
                    AddSprite(TexGen.MakeTree(),
                        new Vector3(wx, 0f, wz), 1.0f, 1.8f);
                    break;
                case 2: // House — only build from left cell of each pair
                    if (c == 0 || map[r, c-1] != 2)
                        AddSprite(TexGen.MakeHouse(subjectColor),
                            new Vector3(wx + 0.5f, 0f, wz), 2.0f, 1.6f);
                    break;
                case 5: // Gym wall
                    AddSprite(TexGen.MakeGymSprite(subjectColor, false),
                        new Vector3(wx, 0f, wz), 1.0f, 2.0f);
                    break;
                case 6: // Gym door
                    AddSprite(TexGen.MakeGymSprite(subjectColor, true),
                        new Vector3(wx, 0f, wz), 1.0f, 2.0f);
                    break;
                case 11: // Fence
                    AddSprite(TexGen.MakeFencePost(),
                        new Vector3(wx, 0f, wz), 1.0f, 0.75f);
                    break;
                case 12: // Door / building entrance
                    AddSprite(TexGen.MakeDoorSprite(),
                        new Vector3(wx, 0f, wz), 0.6f, 1.4f);
                    break;
            }
        }
    }

    void BuildNPCs(NPCInfo[] npcs)
    {
        if (npcs == null) return;
        foreach (var npc in npcs) {
            var tex = TexGen.MakeNPC(npc.shirt, npc.isTeacher, npc.isDuel);
            var go = AddSprite(tex,
                new Vector3(npc.pos.x + 0.5f, 0f, npc.pos.y + 0.5f),
                0.75f, 1.3f);
            _npcGOs.Add(go);
        }
    }

    void BuildPlayer(Vector2Int startPos)
    {
        var tex = TexGen.MakePlayerBack();
        _playerGO = AddSprite(tex,
            new Vector3(startPos.x + 0.5f, 0f, startPos.y + 0.5f),
            0.75f, 1.3f);
        _playerGO.name = "Player3D";
    }

    void BuildItem(Vector2Int pos, Color col)
    {
        var tex = TexGen.MakeItemSparkle(col);
        _itemGO = AddSprite(tex,
            new Vector3(pos.x + 0.5f, 0.1f, pos.y + 0.5f),
            0.6f, 0.6f);
        _itemGO.name = "Item3D";
    }

    // ── Primitive builders ────────────────────────────────────────────────────
    static Material _unlitMat, _spriteMat;

    static Material GetUnlit()
    {
        if (_unlitMat != null) return _unlitMat;
        _unlitMat = new Material(Shader.Find("Unlit/Texture"));
        return _unlitMat;
    }

    static Material GetSpriteMat()
    {
        if (_spriteMat != null) return _spriteMat;
        // Use Sprites/Default which handles alpha blending properly
        var sh = Shader.Find("Sprites/Default")
              ?? Shader.Find("Unlit/Transparent")
              ?? Shader.Find("Transparent/Diffuse");
        _spriteMat = new Material(sh);
        return _spriteMat;
    }

    GameObject MakeQuad(string name, Vector3 pos, Quaternion rot, Vector3 scale,
                        Texture2D tex, bool alpha)
    {
        var go = GameObject.CreatePrimitive(PrimitiveType.Quad);
        
        go.name = name;
        go.transform.position    = pos;
        go.transform.rotation    = rot;
        go.transform.localScale  = scale;
        var mr  = go.GetComponent<MeshRenderer>();
        var mat = new Material(alpha ? GetSpriteMat() : GetUnlit());
        mat.mainTexture = tex;
        if (!alpha) mr.receiveShadows = false;
        mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        mr.material = mat;
        return go;
    }

    // Add a vertical billboard sprite. Sprites face -Z (toward camera).
    GameObject AddSprite(Texture2D tex, Vector3 basePos, float width, float height)
    {
        // Place pivot at base (feet), center = base + (0, height/2, 0)
        var center = basePos + new Vector3(0f, height * 0.5f + 0.01f, 0f);
        // Rotation: Euler(0,180,0) → quad faces -Z (toward camera in our scene)
        var go = MakeQuad("Sprite", center,
            Quaternion.Euler(0, 180, 0),
            new Vector3(width, height, 1f),
            tex, true);
        _sceneObjects.Add(go);
        return go;
    }

    // ── LateUpdate: axis-aligned Y billboard ──────────────────────────────────
    void LateUpdate()
    {
        if (_cam == null || !_cam.enabled) return;
        // For all billboard sprites: keep them vertical, facing camera on Y axis.
        // Camera never rotates on Y in this game so this is constant, but
        // we compute it dynamically in case camera changes.
        Vector3 cf = _cam.transform.forward;
        cf.y = 0f;
        if (cf.sqrMagnitude < 0.001f) return;
        cf.Normalize();
        var billboardRot = Quaternion.LookRotation(-cf, Vector3.up);

        foreach (var go in _sceneObjects)
            if (go != null) go.transform.rotation = billboardRot;
        if (_playerGO != null) _playerGO.transform.rotation = billboardRot;
        if (_itemGO   != null) _itemGO  .transform.rotation = billboardRot;
    }

    // ── Cleanup ───────────────────────────────────────────────────────────────
    public void Cleanup()
    {
        if (_cam      != null) { Destroy(_cam.gameObject);  _cam      = null; }
        if (_groundGO != null) { Destroy(_groundGO);        _groundGO = null; }
        if (_playerGO != null) { Destroy(_playerGO);        _playerGO = null; }
        if (_itemGO   != null) { Destroy(_itemGO);          _itemGO   = null; }
        foreach (var go in _sceneObjects) if (go != null) Destroy(go);
        _sceneObjects.Clear();
        foreach (var go in _npcGOs)       if (go != null) Destroy(go);
        _npcGOs.Clear();
        _unlitMat = null; _spriteMat = null;
    }

    void OnDestroy() => Cleanup();
}
