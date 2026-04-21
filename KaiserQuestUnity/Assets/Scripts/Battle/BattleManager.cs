// BattleManager.cs — Gen 1/2 Knowledge Battle
using UnityEngine;
using System.Collections.Generic;

public class BattleManager : MonoBehaviour
{
    public static BattleManager Instance { get; private set; }
    void Awake() { Instance = this; }

    // ── State ─────────────────────────────────────────────────────────────────
    enum Phase { Idle, Intro, Menu, Answering, Result, Win, Lose }
    Phase _phase=Phase.Idle;

    GymLeaderData    _gym;
    List<QuestionData> _qs;
    int   _qi,_sel,_menuSel,_score,_combo;
    bool  _inAnswer,_hintUsed,_showHint;
    string _hintText="",_result="",_explain="";
    int[]  _acols; // 0=normal,1=green,2=red

    int   _pHP,_pMax,_eHP,_eMax;
    float _pHPd,_eHPd;
    float _glowT,_shakeT,_flashT;
    Color _flashCol=Color.clear;
    bool  _pvictory;

    // Avatar animation timers
    float _pAttT,_eHurtT,_pHurtT;
    float _time;

    // ── Setup ─────────────────────────────────────────────────────────────────
    public void Setup(GymLeaderData gym, List<QuestionData> qs, bool isSilver)
    {
        _gym=gym; _qs=qs;
        _qi=0; _sel=0; _menuSel=0; _score=0; _combo=0;
        _inAnswer=false; _hintUsed=false; _showHint=false;
        _result=""; _explain=""; _acols=new[]{0,0,0,0};
        _pHP=GameManager.Instance.HP; _pMax=GameManager.Instance.MaxHP;
        _pHPd=_pHP; _eMax=18+GameManager.Instance.Level*2; _eHP=_eMax; _eHPd=_eMax;
        _glowT=0f; _shakeT=0f; _flashT=0f; _pvictory=false;
        _phase=Phase.Intro;

        AdaptiveAI.Instance?.StartSession(GameManager.Instance.BranchKey);

        string[] intro=gym?.intro??new[]{"Battle start!"};
        DialogBox.Instance?.ShowLines(intro,()=>{_phase=Phase.Menu;},DialogBox.Context.Battle);
    }

    // ── Update ────────────────────────────────────────────────────────────────
    void Update()
    {
        if(GameScreenManager.Instance?.Current!=GameScreen.Battle) return;
        _time+=Time.deltaTime;
        _pHPd=Mathf.Lerp(_pHPd,_pHP,Time.deltaTime*4f);
        _eHPd=Mathf.Lerp(_eHPd,_eHP,Time.deltaTime*4f);
        _glowT=Mathf.Max(0f,_glowT-Time.deltaTime*1.5f);
        _shakeT=Mathf.Max(0f,_shakeT-Time.deltaTime);
        _pAttT=Mathf.Max(0f,_pAttT-Time.deltaTime);
        _eHurtT=Mathf.Max(0f,_eHurtT-Time.deltaTime);
        _pHurtT=Mathf.Max(0f,_pHurtT-Time.deltaTime);

        if(_phase==Phase.Answering){
            _flashT+=Time.deltaTime;
            if(_flashT>=2.2f) AfterResult();
        }

        if(_phase!=Phase.Menu||DialogBox.Instance?.IsOpen==true) return;
        HandleInput();
    }

    void HandleInput()
    {
        if(!_inAnswer){
            // FIGHT/HINT/SKIP
            if(Input.GetKeyDown(KeyCode.UpArrow)||Input.GetKeyDown(KeyCode.LeftArrow))
                _menuSel=Mathf.Max(0,_menuSel-1);
            if(Input.GetKeyDown(KeyCode.DownArrow)||Input.GetKeyDown(KeyCode.RightArrow))
                _menuSel=Mathf.Min(2,_menuSel+1);
            if(Input.GetKeyDown(KeyCode.Return)||Input.GetKeyDown(KeyCode.KeypadEnter)){
                if(_menuSel==0){_inAnswer=true;_sel=0;}
                else if(_menuSel==1) UseHint();
                else Skip();
            }
        } else {
            // Answer options (keyboard)
            int n=_qs[_qi].opts.Length;
            if(Input.GetKeyDown(KeyCode.UpArrow))   _sel=(_sel-1+n)%n;
            if(Input.GetKeyDown(KeyCode.DownArrow))  _sel=(_sel+1)%n;
            if(Input.GetKeyDown(KeyCode.Return)||Input.GetKeyDown(KeyCode.KeypadEnter)) Submit();
            if(Input.GetKeyDown(KeyCode.Escape)){_inAnswer=false;}
        }
    }

    void UseHint(){
        if(_hintUsed){_hintText="Hint already used!";}
        else{
            _hintUsed=true;
            var q=_qs[_qi];
            _hintText="Hint: Answer starts with\n'"+(q.opts[q.ans].Length>=4?q.opts[q.ans].Substring(0,4):"?")+"...'";
        }
        _showHint=true;
    }

    void Skip(){
        _hintUsed=false;_showHint=false;_combo=0;
        System.Array.Fill(_acols,0);
        _qi++;
        if(_qi>=_qs.Count) EndBattle(_eHP<_pHP);
        else{_sel=0;_menuSel=0;_inAnswer=false;}
    }

    void Submit(){
        _phase=Phase.Answering;
        var q=_qs[_qi]; bool ok=(q.ans==_sel);
        _explain=q.explain; _hintUsed=false; _showHint=false;
        System.Array.Fill(_acols,0);
        AdaptiveAI.Instance?.RecordAnswer(q.topic,ok);
        if(ok){
            _acols[_sel]=1;_combo++;
            _result="Super effective!"+((_combo>1)?" Combo x"+_combo+"!":"");
            _eHP=Mathf.Max(0,_eHP-5*(1+Mathf.Min(_combo-1,2)));
            _glowT=0.8f;_score=Mathf.Min(_score+(int)(100f/_qs.Count),100);
            _flashCol=new Color(0.97f,0.88f,0f,0.3f);
            _pAttT=0.5f;_eHurtT=0.4f;
        }else{
            _acols[_sel]=2;_acols[q.ans]=1;_combo=0;
            _result="Not very effective...";_pHP=Mathf.Max(0,_pHP-6);
            GameManager.Instance.TakeDamage(6);
            _shakeT=0.5f;_flashCol=new Color(0.91f,0.12f,0.12f,0.22f);
            _pHurtT=0.4f;
        }
        _flashT=0f;
    }

    void AfterResult(){
        _result="";_explain="";_flashCol=Color.clear;System.Array.Fill(_acols,0);_flashT=0f;
        if(_eHP<=0){EndBattle(true);return;}
        if(_pHP<=0){EndBattle(false);return;}
        _qi++;
        if(_qi>=_qs.Count){EndBattle(_eHP<_pHP);return;}
        _sel=0;_inAnswer=false;_menuSel=0;_hintUsed=false;_showHint=false;
        _phase=Phase.Menu;
    }

    void EndBattle(bool won){
        _phase=won?Phase.Win:Phase.Lose;
        if(won)_pvictory=true;
        AdaptiveAI.Instance?.EndSession();
        GameManager.Instance.SetBestScore(_gym?.badgeName??"gym",_score);
        string[] resultLines;
        if(won){
            string badge=_gym?.badgeName??"Badge";
            int xp=_gym?.xpReward??200;
            GameManager.Instance.AddXP(xp);
            GameManager.Instance.EarnBadge(badge);
            HUD.Instance?.ShowXPGain(xp);
            int bdg=GameManager.Instance.Badges.Count;
            var lines=new System.Collections.Generic.List<string>(_gym?.win??new[]{"You won!"});
            lines.Add("★ "+badge+" earned! ★");
            lines.Add("Badges: "+bdg+"/20   +"+xp+" XP!");
            if(bdg==5)  lines.Add("ACT 1 COMPLETE!\nRising challenges await...");
            else if(bdg==12) lines.Add("ACT 2 COMPLETE!\nFinal gyms await!");
            else if(bdg==20) lines.Add("ALL 20 BADGES!\nSilver Mountain awaits!");
            resultLines=lines.ToArray();
        } else {
            var lines=new System.Collections.Generic.List<string>(_gym?.lose??new[]{"Defeated!"});
            lines.Add("Study with the Teachers\nand return stronger!");
            resultLines=lines.ToArray();
        }
        DialogBox.Instance?.ShowLines(resultLines,()=>{
            GameScreenManager.Instance?.GoTo(GameScreen.World);
        },DialogBox.Context.World);
    }

    // ── Mouse click on answer boxes ────────────────────────────────────────────
    int GetAnswerHitIdx(Vector2 mousePos)
    {
        // Convert screen mouse to logical 480×320 coordinates
        float sx=Screen.width/480f,sy=Screen.height/320f,s=Mathf.Min(sx,sy);
        float offX=(Screen.width-480*s)/2f,offY=(Screen.height-320*s)/2f;
        float lx=(mousePos.x-offX)/s, ly=(mousePos.y-offY)/s;
        ly=320f-ly; // Flip Y (GUI coords vs Input coords)
        const int W=480,H=320,MY=166;
        int rw=W/2-2;
        for(int i=0;i<4;i++){
            int row=i/2,col=i%2;
            float ox2=W/2+8+col*(rw/2-4f);
            float oy2=MY+14+row*((H-MY-8)/2f);
            float bw=rw/2-8f,bh=(H-MY-10)/2f-4f;
            if(lx>=ox2&&lx<=ox2+bw&&ly>=oy2&&ly<=oy2+bh) return i;
        }
        return -1;
    }

    int GetMenuHitIdx(Vector2 mousePos)
    {
        float sx=Screen.width/480f,sy=Screen.height/320f,s=Mathf.Min(sx,sy);
        float offX=(Screen.width-480*s)/2f,offY=(Screen.height-320*s)/2f;
        float lx=(mousePos.x-offX)/s,ly=(mousePos.y-offY)/s;
        ly=320f-ly;
        const int W=480,MY=166;
        for(int mi=0;mi<3;mi++){
            float iy=MY+8+mi*22f;
            if(lx>=W/2+8&&lx<=W-8&&ly>=iy&&ly<=iy+22) return mi;
        }
        return -1;
    }

    // ── OnGUI ─────────────────────────────────────────────────────────────────
    void OnGUI()
    {
        if(GameScreenManager.Instance?.Current!=GameScreen.Battle) return;
        if(_qs==null||_qs.Count==0) return;

        // Handle mouse click
        if(Event.current.type==EventType.MouseDown&&Event.current.button==0&&_phase==Phase.Menu){
            Vector2 mp=Event.current.mousePosition;
            if(!_inAnswer){
                int mi=GetMenuHitIdx(mp);
                if(mi>=0){
                    _menuSel=mi;
                    if(mi==0){_inAnswer=true;_sel=0;}
                    else if(mi==1) UseHint();
                    else Skip();
                }
            } else {
                int ai=GetAnswerHitIdx(mp);
                if(ai>=0){_sel=ai;Submit();}
            }
        }
        // Mouse hover
        if(Event.current.type==EventType.MouseMove&&_phase==Phase.Menu){
            if(_inAnswer){int ai=GetAnswerHitIdx(Event.current.mousePosition);if(ai>=0)_sel=ai;}
            else{int mi=GetMenuHitIdx(Event.current.mousePosition);if(mi>=0)_menuSel=mi;}
        }

        PixelRenderer.BeginFrame();
        DrawBattle();
        PixelRenderer.EndFrame();
    }

    void DrawBattle()
    {
        int W=PixelRenderer.W, H=PixelRenderer.H;
        Color wcol=_gym?.color??new Color(0.12f,0.38f,0.82f);
        float shX=_shakeT>0f?Random.Range(-4f,4f)*_shakeT:0f;
        float shY=_shakeT>0f?Random.Range(-2f,2f)*_shakeT:0f;

        // Gen 1/2 battle background
        PixelRenderer.DrawBattleBackground();

        // Platforms
        PixelRenderer.DrawPlatform(W-222+shX,57,120,false);
        PixelRenderer.DrawPlatform(12+shX,102,110,true);

        // Enemy avatar (front view, top-right)
        float eox=(int)(W-185+shX), eoy=(int)(8+shY+Mathf.Sin(_time*1.6f)*2f);
        if(_eHurtT>0f) eox+=Mathf.Sin(_eHurtT*22f)*6f;
        SpriteDrawer.DrawLeaderBattle(eox,eoy,wcol,_time);

        // Player avatar (back view, bottom-left)
        float pox=(int)(40+shX), poy=(int)(62+Mathf.Sin(_time*2f)*2f);
        if(_pHurtT>0f){pox+=Mathf.Sin(_pHurtT*20f)*5f;}
        SpriteDrawer.DrawPlayerBattle(pox,poy);

        // HP Boxes
        DrawHPBox(6,6,230,_gym?.name??"???",_gym?.title??"",Mathf.RoundToInt(_eHPd),_eMax,GameManager.Instance.Level+2,wcol,true);
        DrawHPBox(W-240,H/2-62,234,GameManager.Instance.PlayerName,"",Mathf.RoundToInt(_pHPd),_pMax,GameManager.Instance.Level,wcol,false);

        // Battle menu
        if(_phase==Phase.Menu||_phase==Phase.Answering)
            DrawBattleMenu(H/2+6,W,H,wcol);

        // Score strip
        PixelRenderer.DrawRect(0,H-4,W,4,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(1,H-3,W-2,2,PixelRenderer.COL_HP_BK);
        PixelRenderer.DrawRect(1,H-3,(W-2)*(_score/100f),2,wcol);

        // Glow
        if(_glowT>0f){
            float ga=_glowT*0.5f;
            PixelRenderer.DrawRect(0,0,W,H/2,new Color(0.97f,0.88f,0f,ga*0.3f));
        }
        // Flash
        if(_flashT>0f&&_flashCol.a>0.01f){
            float fa=Mathf.Max(0f,_flashCol.a-_flashT*0.12f);
            PixelRenderer.DrawRect(0,0,W,H,new Color(_flashCol.r,_flashCol.g,_flashCol.b,fa));
        }
    }

    void DrawHPBox(float bx,float by,float bw,string name,string title,int hp,int maxHp,int lv,Color wcol,bool isEnemy)
    {
        float bh=52f;
        PixelRenderer.DrawRect(bx,by,bw,bh,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(bx+2,by+2,bw-4,bh-4,PixelRenderer.COL_WHITE);
        PixelRenderer.DrawBorder(bx+2,by+2,bw-4,bh-4,PixelRenderer.COL_BLACK,1.5f);
        PixelRenderer.DrawRect(bx+2,by+2,bw-4,14,new Color(wcol.r*0.25f,wcol.g*0.25f,wcol.b*0.4f));
        PixelRenderer.DrawString(bx+7,by+12,name.ToUpper(),12,PixelRenderer.COL_BLACK,true);
        PixelRenderer.DrawString(bx+bw-50,by+12,":Lv"+lv,11,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawString(bx+7,by+27,"HP",10,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawHPBar(bx+22,by+21,bw-28,8,(float)hp/Mathf.Max(maxHp,1));
        if(!isEnemy){
            PixelRenderer.DrawString(bx+bw-78,by+42,hp+"/"+maxHp,11,PixelRenderer.COL_BLACK);
            float xpF=Mathf.Clamp01((float)GameManager.Instance.XP/Mathf.Max(GameManager.Instance.XPMax,1));
            PixelRenderer.DrawRect(bx+2,by+bh-6,bw-4,4,PixelRenderer.COL_BLACK);
            PixelRenderer.DrawRect(bx+3,by+bh-5,bw-6,2,PixelRenderer.COL_HP_BK);
            PixelRenderer.DrawRect(bx+3,by+bh-5,(bw-6)*xpF,2,new Color(0.41f,0.53f,0.94f));
        }
        if(isEnemy&&!string.IsNullOrEmpty(title))
            PixelRenderer.DrawString(bx+7,by+42,title,9,new Color(0.38f,0.38f,0.5f),false,Mathf.RoundToInt(bw-14));
    }

    void DrawBattleMenu(float my,int W,int H,Color wcol)
    {
        if(_qs==null||_qi>=_qs.Count) return;
        var q=_qs[_qi];
        float lw=W/2-2f, rw=W/2-2f;

        // Left panel (question / result / hint)
        PixelRenderer.DrawRect(2,my,lw,H-my-4,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(4,my+2,lw-4,H-my-8,PixelRenderer.COL_WHITE);
        PixelRenderer.DrawBorder(4,my+2,lw-4,H-my-8,PixelRenderer.COL_BLACK,1.5f);
        if(!string.IsNullOrEmpty(_result)){
            Color rc=_result.StartsWith("Super")?PixelRenderer.COL_HP_G:PixelRenderer.COL_HP_R;
            PixelRenderer.DrawString(10,my+17,_result.ToUpper(),12,rc,true);
            if(!string.IsNullOrEmpty(_explain)){
                var el=_explain.Split('\n');
                for(int ei=0;ei<el.Length;ei++)
                    PixelRenderer.DrawString(10,my+34+ei*16,el[ei],11,PixelRenderer.COL_BLACK,false,Mathf.RoundToInt(lw-16));
            }
        } else if(_showHint){
            var hl=_hintText.Split('\n');
            for(int hi=0;hi<hl.Length;hi++)
                PixelRenderer.DrawString(10,my+17+hi*16,hl[hi].ToUpper(),12,PixelRenderer.COL_BLACK);
        } else {
            var ql=q.q.Split('\n');
            for(int li=0;li<ql.Length;li++)
                PixelRenderer.DrawString(10,my+14+li*16,ql[li].ToUpper(),12,PixelRenderer.COL_BLACK,false,Mathf.RoundToInt(lw-16));
        }

        // Right panel (FIGHT/HINT/SKIP or answers)
        PixelRenderer.DrawRect(W/2+2,my,rw-4,H-my-4,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(W/2+4,my+2,rw-8,H-my-8,PixelRenderer.COL_WHITE);
        PixelRenderer.DrawBorder(W/2+4,my+2,rw-8,H-my-8,PixelRenderer.COL_BLACK,1.5f);

        if(!_inAnswer){
            string[] items={"FIGHT","HINT","SKIP"};
            for(int mi=0;mi<items.Length;mi++){
                float iy=my+17+mi*22f;
                bool sel=(_menuSel==mi&&_phase==Phase.Menu);
                if(sel){
                    // Black cursor triangle (Gen 1 style)
                    float cx=W/2+12f; float cy=iy-8f;
                    PixelRenderer.DrawRect(cx,cy,6,12,PixelRenderer.COL_BLACK); // simplified arrow
                }
                PixelRenderer.DrawString(W/2+24,iy+4,items[mi],14,PixelRenderer.COL_BLACK,sel);
            }
            PixelRenderer.DrawString(W/2+10,H-my-18,"SCORE:"+_score+"%",10,new Color(0.38f,0.38f,0.5f));
        } else {
            var opts=q.opts;
            for(int i=0;i<opts.Length;i++){
                int row=i/2,col=i%2;
                float ox2=W/2+8+col*(rw/2-4f);
                float oy2=my+14+row*((H-my-8)/2f);
                float bw2=rw/2-8f,bh2=(H-my-10)/2f-4f;
                bool sel2=(i==_sel&&_phase==Phase.Menu);
                Color bgCol=_acols[i]==1?PixelRenderer.COL_HP_G:_acols[i]==2?PixelRenderer.COL_HP_R:PixelRenderer.COL_WHITE;
                PixelRenderer.DrawRect(ox2,oy2,bw2,bh2,PixelRenderer.COL_BLACK);
                PixelRenderer.DrawRect(ox2+2,oy2+2,bw2-4,bh2-4,bgCol);
                if(sel2) PixelRenderer.DrawRect(ox2+2,oy2+2,bw2-4,bh2-4,new Color(wcol.r,wcol.g,wcol.b,0.25f));
                if(sel2){
                    // Small triangle cursor
                    PixelRenderer.DrawRect(ox2+4,oy2+8,6,10,PixelRenderer.COL_BLACK);
                }
                string letter=new string[]{"A","B","C","D"}[i];
                PixelRenderer.DrawString(ox2+14,oy2+14,letter+". "+opts[i],11,PixelRenderer.COL_BLACK,sel2,Mathf.RoundToInt(bw2-20));
            }
        }
    }
}
