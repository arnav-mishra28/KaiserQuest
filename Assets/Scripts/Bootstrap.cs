// Bootstrap.cs — Programmatic Scene Creator
// Attach this to a single empty GameObject in your Unity scene.
using UnityEngine;
using UnityEngine.SceneManagement;

public class Bootstrap : MonoBehaviour
{
    TitleScreen           _title;
    UI.NameEntryScreen    _nameEntry;
    SubjectSelectScreen   _subSelect;
    WorldController       _world;
    BattleManager         _battle;
    DuelManager           _duel;
    SilverMountainManager _silver;
    KaiserScreen          _kaiser;

    void Awake()
    {
        // Core singletons
        EnsureSingleton<GameManager>();
        EnsureSingleton<AdaptiveAI>();
        EnsureSingleton<GameScreenManager>();
        EnsureSingleton<DialogBox>();
        EnsureSingleton<HUD>();
        EnsureSingleton<BackendClient>();

        // Sub-managers
        EnsureComponent<WorldManager>();
        EnsureComponent<BattleManager>();
        EnsureComponent<DuelManager>();
        EnsureComponent<SilverMountainManager>();
        EnsureComponent<KaiserScreen>();
        EnsureComponent<World3DRenderer>();   // ← 2.5D renderer

        // Screens
        _title     = EnsureScreen<TitleScreen>("Screen_Title");
        _nameEntry = EnsureScreen<UI.NameEntryScreen>("Screen_NameEntry");
        _subSelect = EnsureScreen<SubjectSelectScreen>("Screen_SubjectSelect");
        _world     = EnsureScreen<WorldController>("Screen_World");
        _battle    = EnsureScreen<BattleManager>("Screen_Battle");
        _duel      = EnsureScreen<DuelManager>("Screen_Duel");
        _silver    = EnsureScreen<SilverMountainManager>("Screen_Silver");
        _kaiser    = EnsureScreen<KaiserScreen>("Screen_Kaiser");

        SetupBackgroundCamera();

        if (GameScreenManager.Instance != null)
            GameScreenManager.Instance.OnScreenChanged += OnScreenChanged;

        SetScreen(GameScreen.Title);
    }

    // Background / GUI camera — orthographic, used ONLY for OnGUI-based 2D screens.
    // The 2.5D world gets its own perspective camera created by World3DRenderer.
    void SetupBackgroundCamera()
    {
        var cam = Camera.main;
        if (cam == null) {
            var go = new GameObject("Main Camera");
            go.tag = "MainCamera";
            cam = go.AddComponent<Camera>();
        }
        cam.orthographic     = true;
        cam.orthographicSize = 160f;
        cam.transform.position = new Vector3(240, 160, -10);
        cam.backgroundColor  = new Color(0.04f, 0.04f, 0.08f);
        cam.clearFlags       = CameraClearFlags.SolidColor;
        cam.nearClipPlane    = -10f;
        cam.farClipPlane     = 100f;
        cam.depth            = 0;  // background; World3DCam renders on depth=1
    }

    void OnScreenChanged(GameScreen prev, GameScreen next) => SetScreen(next);

    void SetScreen(GameScreen screen)
    {
        SafeSetActive(_title,     false);
        SafeSetActive(_nameEntry, false);
        SafeSetActive(_subSelect, false);
        SafeSetActive(_world,     false);
        SafeSetActive(_battle,    false);
        SafeSetActive(_duel,      false);
        SafeSetActive(_silver,    false);
        SafeSetActive(_kaiser,    false);

        switch (screen) {
            case GameScreen.Title:         SafeSetActive(_title,     true); break;
            case GameScreen.NameEntry:     SafeSetActive(_nameEntry, true); break;
            case GameScreen.SubjectSelect: SafeSetActive(_subSelect, true); break;
            case GameScreen.World:         SafeSetActive(_world,     true); break;
            case GameScreen.Battle:        SafeSetActive(_battle,    true); break;
            case GameScreen.Duel:          SafeSetActive(_duel,      true); break;
            case GameScreen.Silver:        SafeSetActive(_silver,    true); break;
            case GameScreen.Kaiser:        SafeSetActive(_kaiser,    true); break;
        }
    }

    static void SafeSetActive<T>(T comp, bool active) where T : MonoBehaviour
    {
        if (comp != null) comp.enabled = active;
    }

    T EnsureSingleton<T>() where T : MonoBehaviour
    {
        var existing = FindObjectOfType<T>();
        if (existing != null) return existing;
        var go = new GameObject(typeof(T).Name);
        DontDestroyOnLoad(go);
        return go.AddComponent<T>();
    }

    T EnsureComponent<T>() where T : MonoBehaviour
    {
        var existing = FindObjectOfType<T>();
        if (existing != null) return existing;
        return gameObject.AddComponent<T>();
    }

    T EnsureScreen<T>(string name) where T : MonoBehaviour
    {
        var existing = FindObjectOfType<T>();
        if (existing != null) { existing.enabled = false; return existing; }
        var go   = new GameObject(name);
        var comp = go.AddComponent<T>();
        comp.enabled = false;
        return comp;
    }

    void Update()
    {
        if (Input.GetKeyDown(KeyCode.F5)) {
            GameManager.Instance?.ResetAll();
            SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex);
        }
    }
}

// ── Namespace for simple screens ───────────────────────────────────────────────
namespace UI
{
    public class NameEntryScreen : MonoBehaviour
    {
        string _name = "Arix";
        float  _blinkT;
        bool   _blink = true;
        bool   _done  = false;

        void OnEnable() { _name="Arix"; _done=false; _blinkT=0f; }

        void Update()
        {
            if (_done) return;
            _blinkT += Time.deltaTime;
            if (_blinkT >= 0.5f) { _blinkT=0f; _blink=!_blink; }

            if (Input.GetKeyDown(KeyCode.Backspace) && _name.Length>0)
                _name = _name.Substring(0, _name.Length-1);
            else if ((Input.GetKeyDown(KeyCode.Return)||Input.GetKeyDown(KeyCode.KeypadEnter))
                     && _name.Trim().Length > 0) {
                _done = true;
                GameManager.Instance.PlayerName = _name.Trim();
                GameScreenManager.Instance?.GoTo(GameScreen.SubjectSelect);
            } else {
                foreach (char c in Input.inputString)
                    if (char.IsLetter(c) && _name.Length < 10)
                        _name += (_name.Length==0) ? char.ToUpper(c) : c;
            }
        }

        void OnGUI()
        {
            PixelRenderer.BeginFrame();
            int W=PixelRenderer.W, H=PixelRenderer.H;

            // Gen 2 green checkerboard background
            for (int gy=0;gy<H;gy+=4)
            for (int gx=0;gx<W;gx+=4)
                PixelRenderer.DrawRect(gx,gy,4,4,
                    ((gx/4+gy/4)%2)==0
                    ? new Color(0.608f,0.737f,0.059f)
                    : new Color(0.545f,0.675f,0.059f));

            // Main dialog box
            PixelRenderer.DrawDialogBox(60, 80, 360, 160);
            PixelRenderer.DrawRect(62, 82, 356, 18, new Color(0.12f,0.38f,0.63f));

            PixelRenderer.DrawString(70, 97,  "What is your name?",  15, Color.white, true);

            // Input field
            PixelRenderer.DrawRect(78,  118, 244, 32, PixelRenderer.COL_BLACK);
            PixelRenderer.DrawRect(80,  120, 240, 28, Color.white);
            PixelRenderer.DrawBorder(80, 120, 240, 28, PixelRenderer.COL_BLACK, 1.5f);
            PixelRenderer.DrawString(88, 137, _name + (_blink ? "█" : " "), 18,
                PixelRenderer.COL_BLACK, true);

            PixelRenderer.DrawString(70, 162, "Type your name — then press ENTER", 12,
                new Color(0.2f,0.2f,0.35f));
            PixelRenderer.DrawString(70, 204, "Your journey to become Kaiser begins!", 12,
                new Color(0.06f,0.38f,0.19f));

            PixelRenderer.EndFrame();
        }
    }
}
