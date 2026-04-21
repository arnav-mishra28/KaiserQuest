// Bootstrap.cs — Programmatic Scene Creator
// Attach this to a single empty GameObject in your Unity scene.
// It creates ALL managers and screens at runtime — no prefabs needed.
using UnityEngine;
using UnityEngine.SceneManagement;

public class Bootstrap : MonoBehaviour
{
    // ── Scene state ────────────────────────────────────────────────────────────

    // ── Screen components ──────────────────────────────────────────────────────
    TitleScreen         _title;
    UI.NameEntryScreen  _nameEntry;
    SubjectSelectScreen _subSelect;
    WorldController     _world;
    BattleManager       _battle;
    DuelManager         _duel;
    SilverMountainManager _silver;
    KaiserScreen        _kaiser;

    void Awake()
    {
        // One-time core singletons
        EnsureSingleton<GameManager>();
        EnsureSingleton<AdaptiveAI>();
        EnsureSingleton<GameScreenManager>();
        EnsureSingleton<DialogBox>();
        EnsureSingleton<HUD>();
        EnsureSingleton<BackendClient>();

        // Sub managers (not singletons, but scene-persistent)
        EnsureComponent<WorldManager>();
        EnsureComponent<BattleManager>();
        EnsureComponent<DuelManager>();
        EnsureComponent<SilverMountainManager>();
        EnsureComponent<KaiserScreen>();

        // Screen GameObjects (enabled/disabled by state)
        _title     = EnsureScreen<TitleScreen>("Screen_Title");
        _nameEntry = EnsureScreen<UI.NameEntryScreen>("Screen_NameEntry");
        _subSelect = EnsureScreen<SubjectSelectScreen>("Screen_SubjectSelect");
        _world     = EnsureScreen<WorldController>("Screen_World");
        _battle    = EnsureScreen<BattleManager>("Screen_Battle");
        _duel      = EnsureScreen<DuelManager>("Screen_Duel");
        _silver    = EnsureScreen<SilverMountainManager>("Screen_Silver");
        _kaiser    = EnsureScreen<KaiserScreen>("Screen_Kaiser");

        // Camera setup (no scrolling — fixed 480×320 viewport)
        SetupCamera();

        // Screen changed handler
        if (GameScreenManager.Instance != null)
            GameScreenManager.Instance.OnScreenChanged += OnScreenChanged;

        // Start at title
        SetScreen(GameScreen.Title);
    }

    void SetupCamera()
    {
        var cam = Camera.main ?? new GameObject("Main Camera").AddComponent<Camera>();
        cam.tag              = "MainCamera";
        cam.orthographic     = true;
        cam.orthographicSize  = 160f;           // 320/2 — fits 320px height
        cam.transform.position= new Vector3(240,160,-10); // center of 480×320
        cam.backgroundColor  = Color.black;
        cam.clearFlags       = CameraClearFlags.SolidColor;
        cam.nearClipPlane    = -10f;
        cam.farClipPlane     = 100f;
    }

    void OnScreenChanged(GameScreen prev, GameScreen next)
    {
        SetScreen(next);
    }

    void SetScreen(GameScreen screen)
    {
        // Disable all
        SafeSetActive(_title,     false);
        SafeSetActive(_nameEntry, false);
        SafeSetActive(_subSelect, false);
        SafeSetActive(_world,     false);
        SafeSetActive(_battle,    false);
        SafeSetActive(_duel,      false);
        SafeSetActive(_silver,    false);
        SafeSetActive(_kaiser,    false);

        switch (screen) {
            case GameScreen.Title:        SafeSetActive(_title,     true); break;
            case GameScreen.NameEntry:    SafeSetActive(_nameEntry, true); break;
            case GameScreen.SubjectSelect:SafeSetActive(_subSelect, true); break;
            case GameScreen.World:        SafeSetActive(_world,     true); break;
            case GameScreen.Battle:       SafeSetActive(_battle,    true); break;
            case GameScreen.Duel:         SafeSetActive(_duel,      true); break;
            case GameScreen.Silver:       SafeSetActive(_silver,    true); break;
            case GameScreen.Kaiser:       SafeSetActive(_kaiser,    true); break;
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
        if (existing != null) { existing.enabled=false; return existing; }
        var go = new GameObject(name);
        var comp = go.AddComponent<T>();
        comp.enabled = false;
        return comp;
    }

    void Update()
    {
        // Global hotkeys
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
            _blinkT+=Time.deltaTime; if(_blinkT>=.5f){_blinkT=0f;_blink=!_blink;}

            if (Input.GetKeyDown(KeyCode.Backspace) && _name.Length>0)
                _name=_name.Substring(0,_name.Length-1);
            else if ((Input.GetKeyDown(KeyCode.Return)||Input.GetKeyDown(KeyCode.KeypadEnter)) && _name.Trim().Length>0){
                _done=true; GameManager.Instance.PlayerName=_name.Trim();
                GameScreenManager.Instance?.GoTo(GameScreen.SubjectSelect);
            } else {
                string typed=Input.inputString;
                foreach(char c in typed)
                    if(char.IsLetter(c)&&_name.Length<10) _name+=(_name.Length==0)?char.ToUpper(c):c;
            }
        }

        void OnGUI()
        {
            PixelRenderer.BeginFrame();
            int W=PixelRenderer.W,H=PixelRenderer.H;
            // Gen 2 green checkered background
            for(int gy=0;gy<H;gy+=4)for(int gx=0;gx<W;gx+=4)
                PixelRenderer.DrawRect(gx,gy,4,4,((gx/4+gy/4)%2)==0?new Color(.608f,.737f,.059f):new Color(.545f,.675f,.059f));
            // Dialog box
            PixelRenderer.DrawDialogBox(60,85,360,150);
            PixelRenderer.DrawRect(61,86,358,16,new Color(.12f,.38f,.63f));
            PixelRenderer.DrawString(70,98,"What is your name?",14,Color.white,true);
            // Input field
            PixelRenderer.DrawRect(78,116,244,30,PixelRenderer.COL_BLACK);
            PixelRenderer.DrawRect(79,117,242,28,Color.white);
            PixelRenderer.DrawString(86,133,_name+(_blink?"█":" "),18,PixelRenderer.COL_BLACK,true);
            PixelRenderer.DrawString(70,158,"Type name — press ENTER to confirm",12,new Color(.3f,.3f,.4f));
            PixelRenderer.DrawString(70,196,"Your journey to become Kaiser begins!",12,new Color(.06f,.38f,.19f));
            PixelRenderer.EndFrame();
        }
    }
}
