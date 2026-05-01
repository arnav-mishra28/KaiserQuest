// SilverMountainManager.cs  –  Final boss
using UnityEngine;
using System.Collections.Generic;

public class SilverMountainManager : MonoBehaviour
{
    public static SilverMountainManager Instance { get; private set; }
    void Awake() { Instance = this; }

    List<QuestionData> _qs = new();
    int   _qi, _sel, _lives=3, _score;
    bool  _locked, _over, _ready;
    float _flashT, _qTimer;
    Color _flashCol = Color.clear;
    string _result="";
    const float Q_LIMIT = 15f;

    static readonly Color BG1 = new(0.55f,0.60f,0.72f);
    static readonly Color BG2 = new(0.48f,0.53f,0.65f);
    static readonly Color BOX = new(0.96f,0.96f,0.94f);

    public void StartChallenge(string worldKey)
    {
        if (!GameManager.Instance.CanChallengeSilver()) {
            DialogBox.Instance?.ShowLines(new[]{
                "The Silver Summit is sealed!","You need Level 100 + all 20 Badges.",
                "Current: Lv."+GameManager.Instance.Level+" / "+GameManager.Instance.Badges.Count+" badges"
            }, ()=>GameScreenManager.Instance?.GoTo(GameScreen.World), DialogBox.Context.World);
            return;
        }
        if (GameManager.Instance.SilverOnCooldown()) {
            long secs = GameManager.Instance.SilverCooldownRemaining();
            DialogBox.Instance?.ShowLines(new[]{
                "The Kaiser still tests your resolve...","Cooldown: "+(secs/3600)+"h "+(secs%3600/60)+"m remaining.",
                "Study. Return when the sun rises again."
            }, ()=>GameScreenManager.Instance?.GoTo(GameScreen.World), DialogBox.Context.World);
            return;
        }
        var parts = worldKey.Split(':');
        var allQ  = SubjectDB.GetQuestions(parts[0], parts.Length>1?parts[1]:"algebra");
        var pool  = new List<QuestionData>(allQ);
        for (int i=pool.Count-1;i>0;i--) { int j=Random.Range(0,i+1); (pool[j],pool[i])=(pool[i],pool[j]); }
        _qs = pool.Count>15 ? pool.GetRange(0,15) : pool;
        _qi=0;_sel=0;_lives=3;_score=0;
        _locked=true;_over=false;_ready=false;
        _flashT=0f;_result="";_flashCol=Color.clear;_qTimer=Q_LIMIT;
        AdaptiveAI.Instance?.StartSession(worldKey);
        DialogBox.Instance?.ShowLines(new[]{
            "The Kaiser awaits at the Silver Mountain...",
            "\"Only those who truly know may pass.\"",
            "15 questions  |  3 lives  |  No turning back.",
            "Press ENTER to begin the final trial."
        }, ()=>{ _locked=false; _ready=true; }, DialogBox.Context.Battle);
    }

    void Update()
    {
        if (GameScreenManager.Instance?.Current != GameScreen.Silver) return;
        if (!_ready||_over) return;
        if (DialogBox.Instance?.IsOpen==true) return;
        if (!_locked) { _qTimer-=Time.deltaTime; if(_qTimer<=0f) Timeout(); }
        if (_locked) { _flashT+=Time.deltaTime; if(_flashT>=2f) Advance(); return; }
        int n=_qs.Count>0&&_qi<_qs.Count?_qs[_qi].opts.Length:4;
        if(Input.GetKeyDown(KeyCode.UpArrow))   _sel=(_sel-1+n)%n;
        if(Input.GetKeyDown(KeyCode.DownArrow)) _sel=(_sel+1)%n;
        if(Input.GetKeyDown(KeyCode.Return)||Input.GetKeyDown(KeyCode.KeypadEnter)) Submit();
    }

    void Submit() {
        if(_qs==null||_qi>=_qs.Count) return;
        _locked=true; _flashT=0f;
        var q=_qs[_qi]; bool ok=(q.ans==_sel);
        AdaptiveAI.Instance?.RecordAnswer(q.topic,ok);
        if(ok){ _score++; _result="Correct! The Kaiser nods."; _flashCol=new Color(0,0.7f,0,0.2f);}
        else  { _lives--; _result="Wrong! The Kaiser shakes his head."; _flashCol=new Color(0.8f,0,0,0.2f);}
    }
    void Timeout() { _locked=true;_flashT=0f;_lives--;_result="Too slow! The Kaiser frowns.";_flashCol=new Color(0.8f,0.4f,0,0.2f);}

    void Advance() {
        _result="";_flashCol=Color.clear;
        if(_lives<=0){Fail();return;}
        _qi++;
        if(_qi>=_qs.Count){if(_score>=10) Win(); else Fail(); return;}
        _sel=0;_locked=false;_qTimer=Q_LIMIT;
    }

    void Win() {
        _over=true; AdaptiveAI.Instance?.EndSession();
        GameManager.Instance.SilverCleared();
        GameManager.Instance.AddXP(2000);
        GameScreenManager.Instance?.GoTo(GameScreen.Kaiser);
    }

    void Fail() {
        _over=true; AdaptiveAI.Instance?.EndSession();
        GameManager.Instance.SilverAttemptFailed();
        bool cooldown = GameManager.Instance.SilverOnCooldown();
        DialogBox.Instance?.ShowLines(cooldown
            ? new[]{"The Kaiser is silent...","You were not ready.","A 24-hour reflection period begins.","Return stronger."}
            : new[]{"The Kaiser shakes his head.","\"Review what you have learned.\"","Try again when you are ready."},
            ()=>GameScreenManager.Instance?.GoTo(GameScreen.World), DialogBox.Context.World);
    }

    int HitAnswer(Vector2 mp) {
        float s=Mathf.Min(Screen.width/480f,Screen.height/320f);
        float ox=(Screen.width-480*s)*0.5f,oy=(Screen.height-320*s)*0.5f;
        float lx=(mp.x-ox)/s,ly=320f-(mp.y-oy)/s;
        const int AY=90,STEP=34;
        for(int i=0;i<4;i++){float cx=i%2==0?4f:242f,ry=AY+i/2*STEP;if(lx>=cx&&lx<=cx+232&&ly>=ry&&ly<=ry+32)return i;}
        return -1;
    }

    void OnGUI() {
        if(GameScreenManager.Instance?.Current!=GameScreen.Silver) return;
        if(!_locked&&!_over&&_ready){
            if(Event.current.type==EventType.MouseDown&&Event.current.button==0){int ai=HitAnswer(Event.current.mousePosition);if(ai>=0){_sel=ai;Submit();}}
            if(Event.current.type==EventType.MouseMove){int ai=HitAnswer(Event.current.mousePosition);if(ai>=0)_sel=ai;}
        }
        PixelRenderer.BeginFrame();
        int W=480,H=320;
        for(int gy=0;gy<H;gy+=4) for(int gx=0;gx<W;gx+=4)
            PixelRenderer.DrawRect(gx,gy,4,4,((gx/4+gy/4)%2)==0?BG2:BG1);
        PixelRenderer.DrawRect(0,0,W,36,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(0,0,W,34,BOX);
        PixelRenderer.DrawString(8,14,"SILVER MOUNTAIN TRIAL",15,new Color(0.4f,0.5f,0.8f),true);
        string lh=""; for(int i=0;i<3;i++) lh+=i<_lives?"♥ ":"♡ ";
        PixelRenderer.DrawString(W-100,14,lh.TrimEnd(),13,_lives>1?PixelRenderer.COL_HP_G:PixelRenderer.COL_HP_R,true);
        float tf=_locked?1f:Mathf.Clamp01(_qTimer/Q_LIMIT);
        Color tc=tf>0.5f?PixelRenderer.COL_HP_G:tf>0.25f?PixelRenderer.COL_HP_Y:PixelRenderer.COL_HP_R;
        PixelRenderer.DrawRect(0,36,W,6,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(1,37,W-2,4,PixelRenderer.COL_HP_BK);
        PixelRenderer.DrawRect(1,37,(W-2)*tf,4,tc);
        if(_qs==null||_qs.Count==0||_qi>=_qs.Count){PixelRenderer.DrawString(W/2-60,H/2,"Loading...",13,PixelRenderer.COL_BLACK);PixelRenderer.EndFrame();return;}
        var q=_qs[_qi];
        PixelRenderer.DrawRect(4,44,W-8,40,PixelRenderer.COL_BLACK);PixelRenderer.DrawRect(5,45,W-10,38,BOX);
        PixelRenderer.DrawBorder(5,45,W-10,38,PixelRenderer.COL_BLACK,1.5f);
        PixelRenderer.DrawRect(W-66,46,34,14,new Color(0.3f,0.3f,0.5f,0.8f));
        PixelRenderer.DrawString(W-64,57,"Q"+(_qi+1)+"/"+_qs.Count,10,Color.white);
        PixelRenderer.DrawString(10,58,q.q,12,PixelRenderer.COL_BLACK,false,W-20);
        const int AY=90,STEP=34;
        for(int i=0;i<Mathf.Min(q.opts.Length,4);i++){
            float cx=i%2==0?4f:242f,ry=AY+i/2*STEP;
            bool sel=!_locked&&i==_sel;
            string letter=new[]{"A","B","C","D"}[i];
            PixelRenderer.DrawRect(cx,ry,232,32,PixelRenderer.COL_BLACK);
            PixelRenderer.DrawRect(cx+1,ry+1,230,30,BOX);
            if(sel)PixelRenderer.DrawRect(cx+1,ry+1,230,30,new Color(0.7f,0.7f,1f,0.5f));
            PixelRenderer.DrawString(cx+15,ry+18,letter+".  "+q.opts[i],11,PixelRenderer.COL_BLACK,sel,210);
        }
        if(_locked&&_flashT>0f&&_flashT<2f){
            float a=_flashCol.a*(1f-_flashT/2f);
            PixelRenderer.DrawRect(0,0,W,H/2,new Color(_flashCol.r,_flashCol.g,_flashCol.b,a));
            if(_flashT>0.3f&&!string.IsNullOrEmpty(_result)){
                float rw=_result.Length*6.8f+24f,rx=(W-rw)*0.5f;
                PixelRenderer.DrawRect(rx-2,H/2-24,rw+4,24,PixelRenderer.COL_BLACK);
                PixelRenderer.DrawRect(rx,H/2-22,rw,20,BOX);
                PixelRenderer.DrawBorder(rx,H/2-22,rw,20,PixelRenderer.COL_BLACK,1.5f);
                Color rc=_result.StartsWith("Correct")?PixelRenderer.COL_HP_G:PixelRenderer.COL_HP_R;
                PixelRenderer.DrawString(rx+6,H/2-10,_result,12,rc,true);
            }
        }
        PixelRenderer.DrawRect(0,H-14,W,14,new Color(0,0,0,0.65f));
        PixelRenderer.DrawString(6,H-6,"Score: "+_score+"/"+_qs.Count+"  Lives: "+_lives,9,new Color(0.8f,0.85f,1f));
        PixelRenderer.EndFrame();
    }
}

// KaiserScreen.cs  –  Victory celebration
