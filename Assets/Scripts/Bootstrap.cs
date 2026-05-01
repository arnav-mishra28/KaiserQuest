// Bootstrap.cs  –  Programmatic Unity scene builder.
// Attach to ONE empty GameObject.  No prefabs needed.
using UnityEngine;

public class Bootstrap : MonoBehaviour
{
    // Screen controller refs
    TitleScreen           _title;
    NameEntryScreen       _nameEntry;
    SubjectSelectScreen   _subSelect;
    WorldController       _world;
    BattleManager         _battle;
    DuelManager           _duel;
    SilverMountainManager _silver;
    KaiserScreen          _kaiser;

    void Awake()
    {
        // ── Persistent singletons ──────────────────────────────────────────────
        EnsureSingleton<GameManager>();
        EnsureSingleton<AdaptiveAI>();
        EnsureSingleton<GameScreenManager>();
        EnsureSingleton<DialogBox>();
        EnsureSingleton<HUD>();

        // ── Scene-local managers ───────────────────────────────────────────────
        EnsureComponent<WorldManager>();
        EnsureComponent<BattleManager>();
        EnsureComponent<DuelManager>();
        EnsureComponent<SilverMountainManager>();

        // ── Screen controllers ─────────────────────────────────────────────────
        _title     = MakeScreen<TitleScreen>    ("Screen_Title");
        _nameEntry = MakeScreen<NameEntryScreen>("Screen_NameEntry");
        _subSelect = MakeScreen<SubjectSelectScreen>("Screen_SubjectSelect");
        _world     = MakeScreen<WorldController>("Screen_World");
        _battle    = MakeScreen<BattleManager>  ("Screen_Battle");
        _duel      = MakeScreen<DuelManager>    ("Screen_Duel");
        _silver    = MakeScreen<SilverMountainManager>("Screen_Silver");
        _kaiser    = MakeScreen<KaiserScreen>   ("Screen_Kaiser");

        // ── Main camera setup ──────────────────────────────────────────────────
        SetupCamera();

        // ── Screen router ──────────────────────────────────────────────────────
        if (GameScreenManager.Instance != null)
            GameScreenManager.Instance.OnScreenChanged += (_, next) => SwitchTo(next);

        // ── First screen ──────────────────────────────────────────────────────
        SwitchTo(GameScreen.Title);
    }

    void SetupCamera()
    {
        Camera cam = Camera.main;
        if (cam == null) {
            var go = new GameObject("MainCamera"); go.tag="MainCamera";
            cam = go.AddComponent<Camera>();
        }
        cam.orthographic     = true;
        cam.orthographicSize = 160f;
        cam.transform.position = new Vector3(240f, 160f, -10f);
        cam.backgroundColor  = new Color(0.04f, 0.04f, 0.08f);
        cam.clearFlags       = CameraClearFlags.SolidColor;
        cam.nearClipPlane    = -10f;
        cam.farClipPlane     = 100f;
    }

    void SwitchTo(GameScreen screen)
    {
        SetEnabled(_title,     screen == GameScreen.Title);
        SetEnabled(_nameEntry, screen == GameScreen.NameEntry);
        SetEnabled(_subSelect, screen == GameScreen.SubjectSelect);
        SetEnabled(_world,     screen == GameScreen.World);
        SetEnabled(_battle,    screen == GameScreen.Battle);
        SetEnabled(_duel,      screen == GameScreen.Duel);
        SetEnabled(_silver,    screen == GameScreen.Silver);
        SetEnabled(_kaiser,    screen == GameScreen.Kaiser);
    }

    static void SetEnabled<T>(T comp, bool on) where T : MonoBehaviour
    { if (comp != null) comp.enabled = on; }

    T EnsureSingleton<T>() where T : MonoBehaviour
    {
        var e = FindObjectOfType<T>();
        if (e != null) return e;
        var go = new GameObject(typeof(T).Name);
        DontDestroyOnLoad(go);
        return go.AddComponent<T>();
    }

    T EnsureComponent<T>() where T : MonoBehaviour
    {
        var e = FindObjectOfType<T>();
        return e ?? gameObject.AddComponent<T>();
    }

    T MakeScreen<T>(string name) where T : MonoBehaviour
    {
        var e = FindObjectOfType<T>();
        if (e != null) { e.enabled = false; return e; }
        var go = new GameObject(name);
        var c  = go.AddComponent<T>();
        c.enabled = false;
        return c;
    }

    void Update()
    {
        if (Input.GetKeyDown(KeyCode.F5)) {
            GameManager.Instance?.ResetAll();
            UnityEngine.SceneManagement.SceneManager
                .LoadScene(UnityEngine.SceneManagement.SceneManager.GetActiveScene().buildIndex);
        }
    }
}

// ── Name Entry Screen ─────────────────────────────────────────────────────────
public class NameEntryScreen : MonoBehaviour
{
    string _name = "";
    float  _blinkT;
    bool   _blink = true;

    void OnEnable() { _name = ""; _blinkT = 0f; }

    void Update()
    {
        if (GameScreenManager.Instance?.Current != GameScreen.NameEntry) return;
        _blinkT += Time.deltaTime;
        if (_blinkT >= 0.5f) { _blinkT=0f; _blink=!_blink; }

        if (Input.GetKeyDown(KeyCode.Backspace) && _name.Length > 0)
            _name = _name.Substring(0, _name.Length-1);
        else if ((Input.GetKeyDown(KeyCode.Return)||Input.GetKeyDown(KeyCode.KeypadEnter))
                  && _name.Trim().Length > 0) {
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
        if (GameScreenManager.Instance?.Current != GameScreen.NameEntry) return;
        PixelRenderer.BeginFrame();
        int W=PixelRenderer.W, H=PixelRenderer.H;

        // BG
        for (int gy=0;gy<H;gy+=4) for (int gx=0;gx<W;gx+=4)
            PixelRenderer.DrawRect(gx,gy,4,4,
                ((gx/4+gy/4)%2)==0
                ? new Color(0.31f,0.58f,0.16f)
                : new Color(0.27f,0.52f,0.14f));

        // Dialog box
        PixelRenderer.DrawRect(55,60,370,200, PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(57,62,366,196, PixelRenderer.COL_WHITE);
        PixelRenderer.DrawBorder(57,62,366,196,PixelRenderer.COL_BLACK,2f);
        // Title bar
        PixelRenderer.DrawRect(57,62,366,18,new Color(0.12f,0.38f,0.63f));
        PixelRenderer.DrawString(66,75,"What is your name?",15,Color.white,true);

        // Input box
        PixelRenderer.DrawRect(75,94,250,32,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(77,96,246,28,Color.white);
        PixelRenderer.DrawBorder(77,96,246,28,PixelRenderer.COL_BLACK,1.5f);
        PixelRenderer.DrawString(85,114,_name+(_blink?"█":" "),18,PixelRenderer.COL_BLACK,true);

        PixelRenderer.DrawString(66,136,"Type your name and press ENTER",12,new Color(0.3f,0.3f,0.45f));
        PixelRenderer.DrawString(66,154,"(Max 10 letters)",11,new Color(0.5f,0.5f,0.55f));
        PixelRenderer.DrawString(66,186,"\"Your journey to become a Kaiser begins!\"",12,new Color(0.06f,0.38f,0.19f));
        PixelRenderer.DrawString(66,220,"ENTER to confirm",13,PixelRenderer.COL_BLACK,true);

        PixelRenderer.EndFrame();
    }
}
