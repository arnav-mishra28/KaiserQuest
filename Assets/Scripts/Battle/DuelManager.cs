// DuelManager.cs  –  Knowledge Duel (fixed blank-screen bug)
// Root cause was: Setup() called before GoTo(Duel) so _setupDone was never set.
// Fix: _setupDone flag + all draw paths null-guarded.
using UnityEngine;
using System.Collections.Generic;

public class DuelManager : MonoBehaviour
{
    public static DuelManager Instance { get; private set; }
    void Awake() { Instance = this; }

    string            _world;
    GymLeaderData     _opp;
    float             _oppAcc;
    List<QuestionData> _qs = new();

    int   _qi, _sel, _pLives=3, _aLives=3;
    bool  _locked, _over, _ready;
    float _flashT;
    Color _flashCol = Color.clear;
    string _result = "";
    float _qTimer;
    const float Q_LIMIT = 12f;

    // Colours
    static readonly Color BG1 = new(0.25f,0.43f,0.17f);
    static readonly Color BG2 = new(0.22f,0.38f,0.13f);
    static readonly Color BOX = new(0.96f,0.96f,0.91f);
    static readonly Color SEL = new(0.50f,0.80f,1.00f);

    // ── Setup ─────────────────────────────────────────────────────────────────
    public void Setup(string world, GymLeaderData opp, float accuracy)
    {
        _world   = world; _opp = opp; _oppAcc = accuracy;
        _qi=0; _sel=0; _pLives=3; _aLives=3;
        _locked=true; _over=false; _ready=false;
        _flashT=0f; _result=""; _flashCol=Color.clear; _qTimer=Q_LIMIT;

        // Load questions
        var parts = world.Split(':');
        string sub = parts.Length>0 ? parts[0] : "math";
        string br  = parts.Length>1 ? parts[1] : "algebra";
        _qs = SubjectDB.GetGymQuestions(sub, br, GameManager.Instance.Badges.Count+1, 7);
        if (_qs.Count == 0) {
            var all = new List<QuestionData>(SubjectDB.GetQuestions(sub, br));
            Shuffle(all);
            _qs = all.Count > 7 ? all.GetRange(0, 7) : all;
        }

        AdaptiveAI.Instance?.StartSession(world);

        DialogBox.Instance?.ShowLines(new[]{
            (_opp?.name ?? "Rival") + " challenges you to a Knowledge Duel!",
            "7 questions  |  3 lives each",
            "Correct answer = opponent loses a life.",
            "Wrong = YOU lose a life.  Press ENTER to begin!"
        }, ()=>{ _locked=false; _ready=true; }, DialogBox.Context.Battle);
    }

    static void Shuffle<T>(List<T> l)
    { for (int i=l.Count-1;i>0;i--){int j=Random.Range(0,i+1);(l[j],l[i])=(l[i],l[j]);} }

    // ── Update ────────────────────────────────────────────────────────────────
    void Update()
    {
        if (GameScreenManager.Instance?.Current != GameScreen.Duel) return;
        if (!_ready) return;
        if (_over)   return;
        if (DialogBox.Instance?.IsOpen == true) return;

        if (!_locked) {
            _qTimer -= Time.deltaTime;
            if (_qTimer <= 0f) Timeout();
        }

        if (_locked) {
            _flashT += Time.deltaTime;
            if (_flashT >= 1.9f) Advance();
            return;
        }

        HandleInput();
    }

    void HandleInput()
    {
        if (_qs == null || _qi >= _qs.Count) return;
        int n = _qs[_qi].opts.Length;
        if (Input.GetKeyDown(KeyCode.UpArrow))   _sel = (_sel-1+n)%n;
        if (Input.GetKeyDown(KeyCode.DownArrow)) _sel = (_sel+1)%n;
        if (Input.GetKeyDown(KeyCode.Return)||Input.GetKeyDown(KeyCode.KeypadEnter)) Submit();
    }

    void Submit()
    {
        if (_qs==null||_qi>=_qs.Count) return;
        _locked = true; _flashT = 0f;
        var q = _qs[_qi]; bool ok = (q.ans == _sel);
        AdaptiveAI.Instance?.RecordAnswer(q.topic, ok);
        bool aiOk = Random.value < _oppAcc;
        if      ( ok && !aiOk) { _aLives--;  _result="Correct!  Opponent loses a life!"; _flashCol=new Color(0,0.75f,0,0.2f); }
        else if (!ok &&  aiOk) { _pLives--;  _result="Wrong!  You lose a life.";         _flashCol=new Color(0.8f,0,0,0.2f); }
        else if ( ok)           { _result="Both answered correctly!";                     _flashCol=new Color(0,0.5f,1f,0.15f); }
        else                    { _result="Both got it wrong...";                         _flashCol=new Color(0.5f,0.5f,0,0.12f); }
    }

    void Timeout() { _locked=true; _flashT=0f; _pLives--; _result="Time's up!  You lose a life."; _flashCol=new Color(0.8f,0.4f,0,0.2f); }

    void Advance()
    {
        _result=""; _flashCol=Color.clear;
        if (_pLives<=0) { EndDuel(false); return; }
        if (_aLives<=0) { EndDuel(true);  return; }
        _qi++;
        if (_qi>=_qs.Count) { EndDuel(_pLives>_aLives); return; }
        _sel=0; _locked=false; _qTimer=Q_LIMIT;
    }

    void EndDuel(bool won)
    {
        _over=true; _ready=false;
        AdaptiveAI.Instance?.EndSession();
        int xp = won ? 150 : 25;
        GameManager.Instance.AddXP(xp);
        if (won) { GameManager.Instance.AddDuelWin(); HUD.Instance?.ShowXPGain(xp); }
        DialogBox.Instance?.ShowLines(
            won ? new[]{"Duel Victory!","You won "+(_opp?.name??"the rival")+"!","+"+xp+" XP!","Duel Wins: "+GameManager.Instance.DuelWins}
                : new[]{"Duel lost...","Keep practicing!","+"+xp+" XP for trying."},
            ()=> GameScreenManager.Instance?.GoTo(GameScreen.World),
            DialogBox.Context.World);
    }

    // ── Mouse input in OnGUI ──────────────────────────────────────────────────
    int HitAnswer(Vector2 mp)
    {
        float s=Mathf.Min(Screen.width/480f,Screen.height/320f);
        float ox=(Screen.width-480*s)*0.5f, oy=(Screen.height-320*s)*0.5f;
        float lx=(mp.x-ox)/s, ly=320f-(mp.y-oy)/s;
        const int AY=90, STEP=34;
        for (int i=0;i<4;i++){
            float cx=i%2==0?4f:242f, ry=AY+i/2*STEP;
            if (lx>=cx&&lx<=cx+232&&ly>=ry&&ly<=ry+32) return i;
        }
        return -1;
    }

    // ── OnGUI ─────────────────────────────────────────────────────────────────
    void OnGUI()
    {
        if (GameScreenManager.Instance?.Current != GameScreen.Duel) return;

        if (!_locked && !_over && _ready) {
            if (Event.current.type == EventType.MouseDown && Event.current.button==0) {
                int ai = HitAnswer(Event.current.mousePosition);
                if (ai >= 0) { _sel=ai; Submit(); }
            }
            if (Event.current.type == EventType.MouseMove) {
                int ai = HitAnswer(Event.current.mousePosition);
                if (ai >= 0) _sel = ai;
            }
        }

        PixelRenderer.BeginFrame();
        DrawDuel();
        PixelRenderer.EndFrame();
    }

    void DrawDuel()
    {
        int W=480, H=320;

        // Checkerboard BG
        for (int gy=0;gy<H;gy+=4) for (int gx=0;gx<W;gx+=4)
            PixelRenderer.DrawRect(gx,gy,4,4,((gx/4+gy/4)%2)==0?BG2:BG1);

        // ── Header bar ──
        PixelRenderer.DrawRect(0,0,W,36,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(0,0,W,34,BOX);

        // Player side
        PixelRenderer.DrawRect(2,2,150,30,new Color(0.12f,0.25f,0.60f,0.35f));
        PixelRenderer.DrawString(8,14,GameManager.Instance.PlayerName.ToUpper(),13,PixelRenderer.COL_BLACK,true);
        string ph=""; for(int i=0;i<3;i++) ph+=i<_pLives?"♥ ":"♡ ";
        PixelRenderer.DrawString(8,28,ph.TrimEnd(),13,_pLives>1?PixelRenderer.COL_HP_G:PixelRenderer.COL_HP_R,true);

        // VS
        PixelRenderer.DrawStringC(W/2f,12,"VS",18,PixelRenderer.COL_GOLD,true);

        // Opponent side
        string oppName = _opp?.name ?? "Rival";
        PixelRenderer.DrawRect(W-152,2,150,30,new Color(0.55f,0.10f,0.10f,0.50f));
        PixelRenderer.DrawString(W-148,14,oppName.ToUpper(),13,new Color(1f,0.6f,0.6f),true);
        string ah=""; for(int i=0;i<3;i++) ah+=i<_aLives?"♥ ":"♡ ";
        PixelRenderer.DrawString(W-148,28,ah.TrimEnd(),13,_aLives>1?PixelRenderer.COL_HP_G:PixelRenderer.COL_HP_R,true);

        // ── Timer bar ──
        float tf = _locked ? 1f : Mathf.Clamp01(_qTimer/Q_LIMIT);
        Color tc = tf>0.5f?PixelRenderer.COL_HP_G:tf>0.25f?PixelRenderer.COL_HP_Y:PixelRenderer.COL_HP_R;
        PixelRenderer.DrawRect(0,36,W,6,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(1,37,W-2,4,PixelRenderer.COL_HP_BK);
        PixelRenderer.DrawRect(1,37,(W-2)*tf,4,tc);

        if (_qs==null||_qs.Count==0||_qi>=_qs.Count) {
            PixelRenderer.DrawString(W/2-80,H/2,"Loading...",13,PixelRenderer.COL_BLACK);
            return;
        }

        var q = _qs[_qi];

        // ── Question ──
        PixelRenderer.DrawRect(4,44,W-8,40,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(5,45,W-10,38,BOX);
        PixelRenderer.DrawBorder(5,45,W-10,38,PixelRenderer.COL_BLACK,1.5f);
        // Q number badge
        PixelRenderer.DrawRect(W-66,46,34,14,new Color(0.2f,0.2f,0.3f,0.8f));
        PixelRenderer.DrawString(W-64,57,"Q "+(_qi+1)+"/"+_qs.Count,10,new Color(0.9f,0.9f,1f));
        // Question text
        DrawWrapped(10,58,q.q,12,PixelRenderer.COL_BLACK,W-20);

        // ── Answer grid 2×2 ──
        const int AY=90, STEP=34;
        for (int i=0;i<Mathf.Min(q.opts.Length,4);i++) {
            int col2=i%2, row2=i/2;
            float cx=col2==0?4f:242f, ry=AY+row2*STEP;
            bool sel2 = !_locked && i==_sel;
            string letter = new[]{"A","B","C","D"}[i];

            PixelRenderer.DrawRect(cx,   ry,   232,32,PixelRenderer.COL_BLACK);
            PixelRenderer.DrawRect(cx+1, ry+1, 230,30,BOX);
            if (sel2) PixelRenderer.DrawRect(cx+1,ry+1,230,30,SEL);
            if (sel2) {
                PixelRenderer.DrawRect(cx+4,ry+10,7,12,PixelRenderer.COL_BLACK);
                PixelRenderer.DrawRect(cx+5,ry+11,5,10,BOX);
            }
            Color tc2 = sel2 ? new Color(0.05f,0.10f,0.40f) : PixelRenderer.COL_BLACK;
            PixelRenderer.DrawString(cx+15,ry+18,letter+".  "+q.opts[i],11,tc2,sel2,210);
        }

        // ── Result flash ──
        if (_locked && _flashT>0f && _flashT<1.9f) {
            float a = _flashCol.a*(1f-_flashT/1.9f);
            PixelRenderer.DrawRect(0,0,W,H/2,new Color(_flashCol.r,_flashCol.g,_flashCol.b,a));
            if (_flashT>0.3f && !string.IsNullOrEmpty(_result)) {
                float rw=_result.Length*7f+28f;
                float rx=(W-rw)*0.5f;
                PixelRenderer.DrawRect(rx-2,H/2-26,rw+4,26,PixelRenderer.COL_BLACK);
                PixelRenderer.DrawRect(rx,  H/2-24,rw,  22,BOX);
                PixelRenderer.DrawBorder(rx,H/2-24,rw,22,PixelRenderer.COL_BLACK,1.5f);
                Color rc=_result.StartsWith("Correct")?PixelRenderer.COL_HP_G:PixelRenderer.COL_HP_R;
                PixelRenderer.DrawString(rx+8,H/2-11,_result,12,rc,true);
            }
        }

        // ── Bottom stat strip ──
        var weak = AdaptiveAI.Instance?.GetWeakTopics(_world) ?? new List<string>();
        PixelRenderer.DrawRect(0,H-16,W,16,new Color(0,0,0,0.65f));
        string stat="Wins: "+GameManager.Instance.DuelWins;
        if (weak.Count>0) stat+="   Weak: "+weak[0];
        PixelRenderer.DrawString(6,H-7,stat,9,new Color(0.7f,0.85f,1f));
    }

    static void DrawWrapped(float x, float y, string text, int size, Color col, float maxW)
    {
        if (string.IsNullOrEmpty(text)) return;
        float charW = size*0.65f;
        int cpl = Mathf.Max(1, Mathf.FloorToInt(maxW/charW));
        string[] words = text.Split(' ');
        string line=""; float ly=y;
        foreach (string w in words) {
            if (line.Length+w.Length+1>cpl&&line.Length>0) {
                PixelRenderer.DrawString(x,ly,line,size,col,false,(int)maxW);
                ly+=size+3; line=w+" ";
            } else line+=w+" ";
        }
        if (line.Trim().Length>0)
            PixelRenderer.DrawString(x,ly,line.TrimEnd(),size,col,false,(int)maxW);
    }
}
