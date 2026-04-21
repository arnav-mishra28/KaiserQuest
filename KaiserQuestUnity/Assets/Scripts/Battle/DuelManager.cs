// DuelManager.cs — Knowledge Duel (Player vs AI Opponent)
using UnityEngine;
using System.Collections.Generic;

public class DuelManager : MonoBehaviour
{
    public static DuelManager Instance { get; private set; }
    void Awake() { Instance = this; }

    string    _world;
    GymLeaderData _opp;
    float     _oppAccuracy;
    List<QuestionData> _qs;
    int  _qi, _sel, _pLives=3, _aLives=3;
    bool _locked, _over;
    float _time, _qTime, _flashT;
    Color _flashCol=Color.clear;
    string _result="";
    const float Q_LIMIT=12f;

    static readonly Color BG1=new(.596f,.627f,.376f), BG2=new(.533f,.565f,.298f);
    static readonly Color BOX=new(.941f,.941f,.878f), DK=PixelRenderer.COL_BLACK;
    static readonly Color SEL=new(.659f,.847f,.973f);

    public void Setup(string world, GymLeaderData opp, float accuracy)
    {
        _world=world; _opp=opp; _oppAccuracy=accuracy;
        var parts=world.Split(':');
        string sub=parts.Length>0?parts[0]:"math", br=parts.Length>1?parts[1]:"algebra";
        _qs=SubjectDB.GetGymQuestions(sub,br,GameManager.Instance.Badges.Count+1,7);
        if(_qs.Count==0){var all=SubjectDB.GetQuestions(sub,br);all=new List<QuestionData>(all);Shuffle(all);_qs=all.Count>7?all.GetRange(0,7):all;}
        _qi=0;_sel=0;_pLives=3;_aLives=3;_locked=true;_over=false;_flashT=0f;_qTime=Q_LIMIT;
        AdaptiveAI.Instance?.StartSession(world);
        DialogBox.Instance?.ShowLines(new[]{
            (opp.name??Opponent)+" challenges you\nto a Knowledge Duel!",
            "7 questions · 3 lives each",
            "Correct = you score · Wrong = they score",
            "Press ENTER to begin!"
        },()=>{_locked=false;}, DialogBox.Context.Battle);
    }
    string Opponent => "Rival";

    void Shuffle<T>(List<T> l){for(int i=l.Count-1;i>0;i--){int j=Random.Range(0,i+1);(l[j],l[i])=(l[i],l[j]);}}

    void Update()
    {
        if(GameScreenManager.Instance?.Current!=GameScreen.Duel) return;
        _time+=Time.deltaTime;
        if(!_locked&&!_over){_qTime-=Time.deltaTime;if(_qTime<=0f)Timeout();}
        if(_locked&&!_over){_flashT+=Time.deltaTime;if(_flashT>=1.6f)Advance();}
        if(_phase!=Phase.Active||DialogBox.Instance?.IsOpen==true||_locked) return;
        HandleInput();
    }
    enum Phase{Active}
    Phase _phase=Phase.Active;

    void HandleInput()
    {
        int n=_qs.Count>_qi?_qs[_qi].opts.Length:4;
        if(Input.GetKeyDown(KeyCode.UpArrow))   _sel=(_sel-1+n)%n;
        if(Input.GetKeyDown(KeyCode.DownArrow))  _sel=(_sel+1)%n;
        if(Input.GetKeyDown(KeyCode.Return)||Input.GetKeyDown(KeyCode.KeypadEnter)) Submit();
    }

    int HitIdx(Vector2 mp)
    {
        float sx=Screen.width/480f,sy=Screen.height/320f,s=Mathf.Min(sx,sy);
        float offX=(Screen.width-480*s)/2f,offY=(Screen.height-320*s)/2f;
        float lx=(mp.x-offX)/s,ly=320f-(mp.y-offY)/s;
        const int AY=86,STEP=34;
        for(int i=0;i<4;i++){
            int col=i%2,row=i/2;
            float cx=col==0?4f:242f,ry=AY+row*STEP;
            if(lx>=cx&&lx<=cx+232&&ly>=ry&&ly<=ry+32) return i;
        }
        return -1;
    }

    void Submit()
    {
        _locked=true;
        var q=_qs[_qi]; bool ok=(q.ans==_sel);
        AdaptiveAI.Instance?.RecordAnswer(q.topic,ok);
        bool aiOk=Random.value<_oppAccuracy;
        if(ok&&!aiOk)     {_aLives--;_result="✓ You score!";}
        else if(!ok&&aiOk){_pLives--;_result="✗ Opponent scores!";}
        else if(ok)        _result="Both correct!";
        else               _result="Both wrong!";
        _flashCol=ok?new Color(0,.8f,0,.2f):new Color(.8f,0,0,.2f);
        _flashT=0f;
    }

    void Timeout(){_locked=true;_pLives--;_result="⏱ Time's up!";_flashCol=new Color(.8f,.4f,0,.2f);}

    void Advance()
    {
        _result="";_flashCol=Color.clear;
        if(_pLives<=0){EndDuel(false);return;}
        if(_aLives<=0){EndDuel(true);return;}
        _qi++;
        if(_qi>=_qs.Count){EndDuel(_pLives>_aLives);return;}
        _sel=0;_locked=false;_qTime=Q_LIMIT;
    }

    void EndDuel(bool won)
    {
        _over=true;_locked=true;
        AdaptiveAI.Instance?.EndSession();
        int xp=won?(_opp!=null?150:100):25;
        if(won){GameManager.Instance.AddXP(xp);GameManager.Instance.AddDuelWin();HUD.Instance?.ShowXPGain(xp);}
        else GameManager.Instance.AddXP(xp);
        DialogBox.Instance?.ShowLines(won
            ?new[]{"Duel Victory! ★",GameManager.Instance.PlayerName+" wins!","+"+xp+" XP!","Duel Wins: "+GameManager.Instance.DuelWins}
            :new[]{"Duel lost...","Keep practicing!","You earned +"+xp+" XP."},
            ()=>GameScreenManager.Instance?.GoTo(GameScreen.World),DialogBox.Context.World);
    }

    void OnGUI()
    {
        if(GameScreenManager.Instance?.Current!=GameScreen.Duel) return;
        if(_qs==null||_qs.Count==0) return;
        if(Event.current.type==EventType.MouseDown&&Event.current.button==0&&!_locked&&!_over){
            int ai=HitIdx(Event.current.mousePosition);if(ai>=0){_sel=ai;Submit();}
        }
        if(Event.current.type==EventType.MouseMove&&!_locked&&!_over){
            int ai=HitIdx(Event.current.mousePosition);if(ai>=0&&ai!=_sel)_sel=ai;
        }
        PixelRenderer.BeginFrame();
        Draw();
        PixelRenderer.EndFrame();
    }

    void Draw()
    {
        const int W=480,H=320;
        var q=_qi<_qs.Count?_qs[_qi]:null;
        // Background
        for(int gy=0;gy<H/2;gy+=4)for(int gx=0;gx<W;gx+=4)
            PixelRenderer.DrawRect(gx,gy,4,4,((gx/4+gy/4)%2)==0?BG2:BG1);
        for(int gy=H/2;gy<H;gy+=4)for(int gx=0;gx<W;gx+=4)
            PixelRenderer.DrawRect(gx,gy,4,4,((gx/4+gy/4)%2)==0?new Color(.66f,.72f,.47f):new Color(.6f,.66f,.41f));
        // VS Header
        PixelRenderer.DrawRect(0,0,W,32,DK);PixelRenderer.DrawRect(0,0,W,30,BOX);
        PixelRenderer.DrawRect(2,2,146,26,new Color(.25f,.35f,.65f,.3f));
        PixelRenderer.DrawString(8,12,GameManager.Instance.PlayerName,12,Color.white,true);
        string ph=""; for(int i=0;i<3;i++) ph+=i<_pLives?"♥":"♡";
        PixelRenderer.DrawString(8,24,ph,14,_pLives>1?PixelRenderer.COL_HP_G:PixelRenderer.COL_HP_R,true);
        PixelRenderer.DrawString(W/2-12,18,"VS",16,PixelRenderer.COL_GOLD,true);
        PixelRenderer.DrawRect(W-148,2,146,26,new Color(.5f,.12f,.12f));
        PixelRenderer.DrawString(W-142,12,_opp?.name??"Rival",12,new Color(1f,.53f,.53f),true);
        string ah=""; for(int i=0;i<3;i++) ah+=i<_aLives?"♥":"♡";
        PixelRenderer.DrawString(W-142,24,ah,14,_aLives>1?PixelRenderer.COL_HP_G:PixelRenderer.COL_HP_R,true);
        // Timer bar
        float tf=Mathf.Clamp01(_locked?1f:_qTime/Q_LIMIT);
        Color tc=tf>.5f?PixelRenderer.COL_HP_G:tf>.25f?PixelRenderer.COL_HP_Y:PixelRenderer.COL_HP_R;
        PixelRenderer.DrawRect(0,32,W,5,DK);PixelRenderer.DrawRect(1,33,W-2,3,PixelRenderer.COL_HP_BK);
        PixelRenderer.DrawRect(1,33,(W-2)*tf,3,tc);
        // Question
        PixelRenderer.DrawRect(4,40,W-8,42,DK);PixelRenderer.DrawRect(5,41,W-10,40,BOX);
        if(q!=null){
            PixelRenderer.DrawString(12,54,q.q,13,DK,false,W-24);
            PixelRenderer.DrawString(W-60,76,"Q "+(_qi+1)+"/"+_qs.Count,9,new Color(.4f,.4f,.5f));
        }
        // Options 2×2
        if(q!=null){
            const int AY=86,STEP=34;
            for(int i=0;i<q.opts.Length;i++){
                int col=i%2,row=i/2;
                float cx=col==0?4f:242f,ry=AY+row*STEP;
                bool sel2=(!_locked&&i==_sel);
                PixelRenderer.DrawRect(cx,ry,232,32,DK);PixelRenderer.DrawRect(cx+1,ry+1,230,30,BOX);
                if(sel2) PixelRenderer.DrawRect(cx+1,ry+1,230,30,SEL);
                PixelRenderer.DrawString(cx+5,ry+18,(sel2?"► ":"  ")+new[]{"A","B","C","D"}[i]+". "+q.opts[i],12,DK,sel2,220);
            }
        }
        // Stats bar
        PixelRenderer.DrawRect(4,H-14,W-8,10,DK);PixelRenderer.DrawRect(5,H-13,W-10,8,BOX);
        var weak=AdaptiveAI.Instance?.GetWeakTopics(_world)??new List<string>();
        PixelRenderer.DrawString(8,H-5,"Wins:"+GameManager.Instance.DuelWins+(weak.Count>0?" Weak:"+weak[0]:""),9,DK);
        // Flash + result
        if(_locked&&!_over&&_flashT>0f){
            PixelRenderer.DrawRect(0,0,W,H/2,new Color(_flashCol.r,_flashCol.g,_flashCol.b,_flashCol.a));
            if(_flashT>.3f&&!string.IsNullOrEmpty(_result)){
                PixelRenderer.DrawRect(W/2-120,H/2-28,240,24,DK);
                PixelRenderer.DrawRect(W/2-119,H/2-27,238,22,BOX);
                PixelRenderer.DrawString(W/2-100,H/2-14,_result,13,DK,true);
            }
        }
    }
}
