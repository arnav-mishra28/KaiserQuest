// DuelManager.cs — Knowledge Duel (Player vs AI Opponent)
// FIX: Was blank because Setup() was called BEFORE GoTo(Duel), so OnGUI never
// ran while _qs was populated. Now Setup stores data and initialises properly
// regardless of screen state. Also added null-guards on every draw path.
using UnityEngine;
using System.Collections.Generic;

public class DuelManager : MonoBehaviour
{
    public static DuelManager Instance { get; private set; }
    void Awake() { Instance = this; }

    string         _world;
    GymLeaderData  _opp;
    float          _oppAccuracy;
    List<QuestionData> _qs = new();

    int   _qi, _sel, _pLives=3, _aLives=3;
    bool  _locked, _over, _setupDone;
    float _time, _qTime, _flashT;
    Color _flashCol = Color.clear;
    string _result = "";
    const float Q_LIMIT = 12f;

    static readonly Color BG1 = new(0.29f,0.45f,0.20f);
    static readonly Color BG2 = new(0.25f,0.40f,0.16f);
    static readonly Color BOX = new(0.95f,0.95f,0.89f);
    static readonly Color DK  = PixelRenderer.COL_BLACK;
    static readonly Color SEL = new(0.50f,0.78f,0.97f);
    static readonly Color GOLD= PixelRenderer.COL_GOLD;

    // ── Setup ─────────────────────────────────────────────────────────────────
    public void Setup(string world, GymLeaderData opp, float accuracy)
    {
        _world       = world;
        _opp         = opp;
        _oppAccuracy = accuracy;

        // Load questions
        var parts = world.Split(':');
        string sub = parts.Length > 0 ? parts[0] : "math";
        string br  = parts.Length > 1 ? parts[1] : "algebra";
        _qs = SubjectDB.GetGymQuestions(sub, br, GameManager.Instance.Badges.Count+1, 7);
        if (_qs.Count == 0) {
            var all = new List<QuestionData>(SubjectDB.GetQuestions(sub, br));
            Shuffle(all);
            _qs = all.Count > 7 ? all.GetRange(0, 7) : all;
        }

        // Reset all state
        _qi = 0; _sel = 0; _pLives = 3; _aLives = 3;
        _locked = true; _over = false; _setupDone = true;
        _flashT = 0f; _qTime = Q_LIMIT; _time = 0f;
        _result = ""; _flashCol = Color.clear;

        AdaptiveAI.Instance?.StartSession(world);

        // Show intro dialog — callback unlocks questions
        DialogBox.Instance?.ShowLines(new[]{
            (opp?.name ?? "Opponent") + " challenges you to a Knowledge Duel!",
            "7 questions  |  3 lives each",
            "Correct = opponent loses life.  Wrong = you lose life.",
            "Press ENTER to begin!"
        }, () => { _locked = false; }, DialogBox.Context.Battle);
    }

    void Shuffle<T>(List<T> l) {
        for (int i = l.Count-1; i > 0; i--) {
            int j = Random.Range(0, i+1);
            (l[j], l[i]) = (l[i], l[j]);
        }
    }

    // ── Update ────────────────────────────────────────────────────────────────
    void Update()
    {
        if (GameScreenManager.Instance?.Current != GameScreen.Duel) return;
        if (!_setupDone) return;

        _time += Time.deltaTime;

        if (!_locked && !_over) {
            _qTime -= Time.deltaTime;
            if (_qTime <= 0f) Timeout();
        }

        // Auto-advance after flash
        if (_locked && !_over) {
            _flashT += Time.deltaTime;
            if (_flashT >= 1.8f) Advance();
        }

        if (_over) return;
        if (_locked) return;
        if (DialogBox.Instance?.IsOpen == true) return;

        HandleInput();
    }

    void HandleInput()
    {
        if (_qs == null || _qi >= _qs.Count) return;
        int n = _qs[_qi].opts.Length;
        if (Input.GetKeyDown(KeyCode.UpArrow))    _sel = (_sel-1+n) % n;
        if (Input.GetKeyDown(KeyCode.DownArrow))  _sel = (_sel+1) % n;
        if (Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.KeypadEnter)) Submit();
    }

    // Mouse hit-test for 2x2 answer grid
    int HitIdx(Vector2 mp)
    {
        float sx=Screen.width/480f, sy=Screen.height/320f, s=Mathf.Min(sx,sy);
        float offX=(Screen.width-480*s)*0.5f, offY=(Screen.height-320*s)*0.5f;
        float lx=(mp.x-offX)/s, ly=(mp.y-offY)/s;
        ly = 320f - ly;  // flip Y
        const int AY=88, STEP=34;
        for (int i=0; i<4; i++) {
            int col=i%2, row=i/2;
            float cx=col==0?4f:242f, ry=AY+row*STEP;
            if (lx>=cx && lx<=cx+232 && ly>=ry && ly<=ry+32) return i;
        }
        return -1;
    }

    void Submit()
    {
        if (_qs == null || _qi >= _qs.Count) return;
        _locked = true;
        var q = _qs[_qi];
        bool ok = (q.ans == _sel);
        AdaptiveAI.Instance?.RecordAnswer(q.topic, ok);
        bool aiOk = Random.value < _oppAccuracy;
        if      (ok && !aiOk)  { _aLives--;  _result = "Correct!  Opponent loses a life."; }
        else if (!ok && aiOk)  { _pLives--;  _result = "Wrong!  You lose a life."; }
        else if (ok)             _result = "Both correct!";
        else                     _result = "Both wrong!";
        _flashCol = ok ? new Color(0,0.75f,0,0.18f) : new Color(0.8f,0,0,0.18f);
        _flashT = 0f;
    }

    void Timeout() {
        _locked = true; _pLives--;
        _result = "Time's up!  You lose a life.";
        _flashCol = new Color(0.8f,0.4f,0f,0.22f);
        _flashT = 0f;
    }

    void Advance()
    {
        _result = ""; _flashCol = Color.clear;
        if (_pLives <= 0) { EndDuel(false); return; }
        if (_aLives <= 0) { EndDuel(true);  return; }
        _qi++;
        if (_qi >= _qs.Count) { EndDuel(_pLives > _aLives); return; }
        _sel = 0; _locked = false; _qTime = Q_LIMIT;
    }

    void EndDuel(bool won)
    {
        _over = true; _locked = true; _setupDone = false;
        AdaptiveAI.Instance?.EndSession();
        int xp = won ? 150 : 25;
        GameManager.Instance.AddXP(xp);
        if (won) { GameManager.Instance.AddDuelWin(); HUD.Instance?.ShowXPGain(xp); }

        DialogBox.Instance?.ShowLines(
            won ? new[]{ "Duel Victory!", GameManager.Instance.PlayerName+" wins!", "+"+xp+" XP!",
                         "Total Duel Wins: "+GameManager.Instance.DuelWins }
                : new[]{ "Duel lost...", "Keep practicing!", "You earned +"+xp+" XP." },
            () => GameScreenManager.Instance?.GoTo(GameScreen.World),
            DialogBox.Context.World);
    }

    // ── OnGUI ─────────────────────────────────────────────────────────────────
    void OnGUI()
    {
        if (GameScreenManager.Instance?.Current != GameScreen.Duel) return;

        // Handle mouse input
        if (!_locked && !_over && _setupDone) {
            if (Event.current.type == EventType.MouseDown && Event.current.button == 0) {
                int ai = HitIdx(Event.current.mousePosition);
                if (ai >= 0) { _sel = ai; Submit(); }
            }
            if (Event.current.type == EventType.MouseMove) {
                int ai = HitIdx(Event.current.mousePosition);
                if (ai >= 0 && ai != _sel) _sel = ai;
            }
        }

        PixelRenderer.BeginFrame();
        DrawDuel();
        PixelRenderer.EndFrame();
    }

    void DrawDuel()
    {
        const int W=480, H=320;

        // ── Checkerboard background ──
        for (int gy=0; gy<H; gy+=4)
        for (int gx=0; gx<W; gx+=4)
            PixelRenderer.DrawRect(gx,gy,4,4, ((gx/4+gy/4)%2)==0 ? BG2 : BG1);

        // ── Top header bar ──
        PixelRenderer.DrawRect(0, 0, W, 36, DK);
        PixelRenderer.DrawRect(0, 0, W, 34, BOX);

        // Player side
        PixelRenderer.DrawRect(2, 2, 150, 30, new Color(0.12f,0.25f,0.60f,0.35f));
        PixelRenderer.DrawString(9, 15, GameManager.Instance.PlayerName.ToUpper(), 13, DK, true);
        string ph = ""; for(int i=0;i<3;i++) ph += i<_pLives ? "♥ " : "♡ ";
        PixelRenderer.DrawString(9, 30, ph.TrimEnd(), 13,
            _pLives > 1 ? PixelRenderer.COL_HP_G : PixelRenderer.COL_HP_R, true);

        // VS
        PixelRenderer.DrawString(W/2-14, 22, "VS", 18, GOLD, true);

        // Opponent side
        string oppName = _opp?.name ?? "Rival";
        PixelRenderer.DrawRect(W-155, 2, 153, 30, new Color(0.55f,0.10f,0.10f,0.5f));
        PixelRenderer.DrawString(W-150, 15, oppName.ToUpper(), 13, new Color(1f,0.6f,0.6f), true);
        string ah = ""; for(int i=0;i<3;i++) ah += i<_aLives ? "♥ " : "♡ ";
        PixelRenderer.DrawString(W-150, 30, ah.TrimEnd(), 13,
            _aLives > 1 ? PixelRenderer.COL_HP_G : PixelRenderer.COL_HP_R, true);

        // ── Timer bar ──
        float tf = Mathf.Clamp01(_locked ? 1f : _qTime / Q_LIMIT);
        Color tc = tf > 0.5f ? PixelRenderer.COL_HP_G : tf > 0.25f ? PixelRenderer.COL_HP_Y : PixelRenderer.COL_HP_R;
        PixelRenderer.DrawRect(0, 36, W, 6, DK);
        PixelRenderer.DrawRect(1, 37, W-2, 4, PixelRenderer.COL_HP_BK);
        PixelRenderer.DrawRect(1, 37, (W-2)*tf, 4, tc);

        // Nothing to show if no questions loaded
        if (_qs == null || _qs.Count == 0 || _qi >= _qs.Count) {
            PixelRenderer.DrawString(W/2-80, H/2, "Loading questions...", 13, DK);
            return;
        }

        var q = _qs[_qi];

        // ── Question box ──
        PixelRenderer.DrawRect(4, 45, W-8, 40, DK);
        PixelRenderer.DrawRect(5, 46, W-10, 38, BOX);
        PixelRenderer.DrawBorder(5, 46, W-10, 38, DK, 1.5f);
        // Question number badge
        PixelRenderer.DrawRect(W-68, 47, 36, 14, new Color(0.2f,0.2f,0.3f,0.8f));
        PixelRenderer.DrawString(W-66, 58, "Q "+(_qi+1)+"/"+_qs.Count, 10, new Color(0.9f,0.9f,1f));
        // Question text — wrap at 440px
        DrawWrapped(12, 60, q.q, 12, DK, W-24);

        // ── Answer grid (2 x 2) ──
        const int AY=88, STEP=34;
        for (int i=0; i<Mathf.Min(q.opts.Length,4); i++) {
            int col=i%2, row=i/2;
            float cx=col==0?4f:242f, ry=AY+row*STEP;
            bool sel2 = (!_locked && i==_sel);

            // Box
            PixelRenderer.DrawRect(cx,   ry,   232, 32, DK);
            PixelRenderer.DrawRect(cx+1, ry+1, 230, 30, BOX);
            if (sel2) PixelRenderer.DrawRect(cx+1, ry+1, 230, 30, SEL);

            // Selection cursor
            if (sel2) {
                PixelRenderer.DrawRect(cx+4, ry+10, 8, 12, DK);
                PixelRenderer.DrawRect(cx+5, ry+11, 6, 10, BOX);
            }

            string letter = new[]{"A","B","C","D"}[i];
            string optText = letter + ".  " + q.opts[i];
            Color textCol = sel2 ? new Color(0.05f,0.1f,0.4f) : DK;
            PixelRenderer.DrawString(cx+16, ry+19, optText, 11, textCol, sel2, 210);
        }

        // ── Bottom stats strip ──
        PixelRenderer.DrawRect(4, H-16, W-8, 12, new Color(0,0,0,0.65f));
        PixelRenderer.DrawRect(5, H-15, W-10, 10, new Color(0.06f,0.06f,0.12f));
        var weak = AdaptiveAI.Instance?.GetWeakTopics(_world) ?? new List<string>();
        string statsStr = "Wins: " + GameManager.Instance.DuelWins;
        if (weak.Count > 0) statsStr += "   Weak topic: " + weak[0];
        PixelRenderer.DrawString(9, H-6, statsStr, 9, new Color(0.7f,0.8f,1f));

        // ── Flash overlay + result ──
        if (_locked && !_over && _flashT > 0f) {
            PixelRenderer.DrawRect(0, 0, W, H/2,
                new Color(_flashCol.r, _flashCol.g, _flashCol.b, _flashCol.a * Mathf.Max(0f, 1f - _flashT*0.4f)));
            if (_flashT > 0.35f && !string.IsNullOrEmpty(_result)) {
                float rw = _result.Length * 7.5f + 32f;
                float rx = (W - rw) * 0.5f;
                PixelRenderer.DrawRect(rx-2,   H/2-26, rw+4, 28, DK);
                PixelRenderer.DrawRect(rx,     H/2-24, rw,   24, BOX);
                PixelRenderer.DrawBorder(rx,   H/2-24, rw,   24, DK, 1.5f);
                Color rc = _result.StartsWith("Correct") ? PixelRenderer.COL_HP_G
                         : _result.StartsWith("Both correct") ? new Color(0.3f,0.7f,1f)
                         : PixelRenderer.COL_HP_R;
                PixelRenderer.DrawString(rx+10, H/2-9, _result, 12, rc, true);
            }
        }
    }

    // Word-wrap helper
    static void DrawWrapped(float x, float y, string text, int size, Color col, float maxW)
    {
        if (string.IsNullOrEmpty(text)) return;
        // Simple character-based wrap (approx 7px per char at size 12)
        float charW = size * 0.68f;
        int charsPerLine = Mathf.Max(1, Mathf.FloorToInt(maxW / charW));
        string[] words = text.Split(' ');
        string line = "";
        float lineY = y;
        foreach (string w in words) {
            if (line.Length + w.Length + 1 > charsPerLine && line.Length > 0) {
                PixelRenderer.DrawString(x, lineY, line, size, col, false, (int)maxW);
                lineY += size + 3f;
                line = w + " ";
            } else {
                line += w + " ";
            }
        }
        if (line.Trim().Length > 0)
            PixelRenderer.DrawString(x, lineY, line.TrimEnd(), size, col, false, (int)maxW);
    }
}
