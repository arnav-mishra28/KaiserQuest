// SubjectSelectScreen.cs — Choose Subject → Branch
using UnityEngine;
using System.Collections.Generic;

public class SubjectSelectScreen : MonoBehaviour
{
    private int    _stage     = 0;   // 0=subject, 1=branch
    private int    _selSub    = 0;
    private int    _selBr     = 0;
    private string _chosenSub = "";
    private float  _time      = 0f;
    private float  _alpha     = 0f;
    private List<string> _subjects = new();
    private List<string> _branches = new();

    void OnEnable() {
        _stage = 0; _selSub = 0; _selBr = 0; _alpha = 0f;
        _subjects = new List<string>(SubjectDB.Subjects.Keys);
    }

    void Update()
    {
        _time  += Time.deltaTime;
        _alpha  = Mathf.MoveTowards(_alpha, 1f, Time.deltaTime * 1.5f);

        if (_stage == 0) {
            if (Input.GetKeyDown(KeyCode.LeftArrow))  _selSub = (_selSub - 1 + _subjects.Count) % _subjects.Count;
            if (Input.GetKeyDown(KeyCode.RightArrow)) _selSub = (_selSub + 1) % _subjects.Count;
            if (Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.KeypadEnter)) {
                _chosenSub = _subjects[_selSub];
                _branches  = new List<string>(SubjectDB.Subjects[_chosenSub].branches.Keys);
                _selBr = 0; _stage = 1;
            }
        } else {
            if (Input.GetKeyDown(KeyCode.LeftArrow))  _selBr = (_selBr - 1 + _branches.Count) % _branches.Count;
            if (Input.GetKeyDown(KeyCode.RightArrow)) _selBr = (_selBr + 1) % _branches.Count;
            if (Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.KeypadEnter)) {
                string br = _branches[_selBr];
                GameManager.Instance.ActiveSubject = _chosenSub;
                GameManager.Instance.ActiveBranch  = br;
                GameManager.Instance.RestoreHP();
                GameScreenManager.Instance.GoTo(GameScreen.World);
            }
            if (Input.GetKeyDown(KeyCode.Escape)) _stage = 0;
        }
    }

    void OnGUI()
    {
        PixelRenderer.BeginFrame();
        int W = PixelRenderer.W; int H = PixelRenderer.H;

        // Background
        PixelRenderer.DrawRect(0,0,W,H,new Color(0.02f,0.02f,0.08f));
        for (int i=0;i<24;i++) {
            float sx=(i*53+7)%480f; float sy=(i*37+11)%200f;
            PixelRenderer.DrawRect(sx,sy,2,2,new Color(1,1,1,(0.3f+0.5f*Mathf.Sin(_time*1.5f+i))*_alpha*0.6f));
        }

        if (_stage == 0) DrawSubjectStage(W, H);
        else             DrawBranchStage(W, H);

        PixelRenderer.EndFrame();
    }

    void DrawSubjectStage(int W, int H)
    {
        PixelRenderer.DrawRect(0,0,W,38,new Color(0,0,0,0.65f));
        PixelRenderer.DrawString(14,10,"CHOOSE YOUR SUBJECT",18,new Color(1f,0.84f,0f,_alpha),true);
        PixelRenderer.DrawString(280,18,"← → Navigate   ENTER Select",11,new Color(0.55f,0.55f,0.75f,_alpha));

        const float CW=142f,CH=240f,GAP=7f;
        float totalW=CW*3+GAP*2, sx=(W-totalW)/2f;

        for (int i=0;i<_subjects.Count;i++) {
            if (!SubjectDB.Subjects.TryGetValue(_subjects[i], out var sub)) continue;
            float cx=sx+i*(CW+GAP), cy=44f;
            bool sel=(i==_selSub);
            float pulse=sel?(0.7f+0.3f*Mathf.Sin(_time*3f)):0f;

            PixelRenderer.DrawRect(cx,cy,CW,CH,new Color(sub.color.r*0.35f,sub.color.g*0.35f,sub.color.b*0.65f));
            if (sel) PixelRenderer.DrawBorder(cx-2,cy-2,CW+4,CH+4,new Color(sub.color.r,sub.color.g,sub.color.b,0.5f+pulse*0.4f),3f);
            PixelRenderer.DrawBorder(cx,cy,CW,CH,new Color(sub.color.r,sub.color.g,sub.color.b,0.6f+pulse*0.3f),2f);

            // Icon area
            PixelRenderer.DrawRect(cx+4,cy+4,CW-8,100,new Color(0,0,0,0.4f));
            DrawSubjectScene(i,cx+4,cy+4,CW-8,100,sub.color);

            PixelRenderer.DrawString(cx+8,cy+110,sub.icon,32,new Color(sub.color.r,sub.color.g,sub.color.b,_alpha),true);
            PixelRenderer.DrawString(cx+4,cy+148,sub.name.ToUpper(),12,Color.white,true,Mathf.RoundToInt(CW-8));
            var dl=sub.desc.Split('\n');
            for(int di=0;di<dl.Length;di++)
                PixelRenderer.DrawString(cx+4,cy+162+di*14,dl[di],11,new Color(0.75f,0.80f,0.75f),false,Mathf.RoundToInt(CW-8));

            if (sel) PixelRenderer.DrawRect(cx,cy,CW,CH,new Color(sub.color.r,sub.color.g,sub.color.b,0.08f));
        }

        PixelRenderer.DrawRect(0,H-26,W,26,new Color(0,0,0,0.6f));
        PixelRenderer.DrawString(W/2-124,H-18,"Press ENTER to select "+_subjects[_selSub].ToUpper(),14,Color.white);
    }

    void DrawSubjectScene(int idx,float ox,float oy,float w,float h,Color col)
    {
        switch(idx){
            case 0:
                PixelRenderer.DrawRect(ox,oy,w,h,new Color(0.04f,0.10f,0.23f));
                for(int gx=0;gx<(int)w;gx+=14) PixelRenderer.DrawRect(ox+gx,oy,1,h,new Color(0.2f,0.4f,0.8f,0.28f));
                for(int gy=0;gy<(int)h;gy+=14) PixelRenderer.DrawRect(ox,oy+gy,w,1,new Color(0.2f,0.4f,0.8f,0.28f));
                PixelRenderer.DrawString(ox+6,oy+22,"x + 3 = ?",13,new Color(0.27f,0.67f,1f));
                PixelRenderer.DrawString(ox+6,oy+42,"y = 2x",13,new Color(0.53f,0.80f,1f));
                break;
            case 1:
                PixelRenderer.DrawRect(ox,oy,w,h,new Color(0.17f,0.10f,0.03f));
                for(int bx=0;bx<(int)w-12;bx+=10)
                    PixelRenderer.DrawRect(ox+bx+1,oy+h-30,8,24,new Color(0.5f+bx*0.003f,0.2f,0.1f));
                PixelRenderer.DrawString(ox+8,oy+22,"English",13,new Color(1f,0.80f,0.27f));
                PixelRenderer.DrawString(ox+8,oy+38,"Español",13,new Color(1f,0.53f,0.27f));
                PixelRenderer.DrawString(ox+8,oy+54,"Français",13,new Color(0.27f,0.53f,1f));
                break;
            case 2:
                PixelRenderer.DrawRect(ox,oy,w,h,new Color(0.09f,0.03f,0.16f));
                for(int sl=0;sl<5;sl++) PixelRenderer.DrawRect(ox+4,oy+18+sl*10,w-8,1,new Color(0.7f,0.5f,1f,0.55f));
                for(int np=0;np<4;np++){
                    float nx=np*18+8; float ny=np%2==0?16:26;
                    PixelRenderer.DrawRect(ox+nx,oy+ny+12,10,8,new Color(0.8f,0.27f,1f));
                    PixelRenderer.DrawRect(ox+nx+8,oy+ny,2,13,new Color(0.8f,0.27f,1f));
                }
                break;
        }
    }

    void DrawBranchStage(int W, int H)
    {
        var sub=SubjectDB.Subjects[_chosenSub];
        PixelRenderer.DrawRect(0,0,W,38,new Color(0,0,0,0.65f));
        PixelRenderer.DrawString(14,10,sub.name.ToUpper()+" — CHOOSE BRANCH",16,sub.color,true);
        PixelRenderer.DrawString(330,10,"← → Nav  ENTER Select",11,new Color(0.55f,0.55f,0.75f));
        PixelRenderer.DrawString(330,22,"ESC = Back",11,new Color(0.55f,0.55f,0.75f));

        int n=_branches.Count;
        const float CW=142f, CH=222f, GAP=10f;
        float totalW=CW*n+GAP*(n-1), sx=(W-totalW)/2f;

        for(int i=0;i<n;i++){
            if(!sub.branches.TryGetValue(_branches[i],out var br)) continue;
            float cx=sx+i*(CW+GAP), cy=50f;
            bool sel=(i==_selBr);
            float pulse=sel?(0.7f+0.3f*Mathf.Sin(_time*3f)):0f;

            PixelRenderer.DrawRect(cx,cy,CW,CH,new Color(br.color.r*0.35f,br.color.g*0.35f,br.color.b*0.65f));
            if(sel) PixelRenderer.DrawBorder(cx-2,cy-2,CW+4,CH+4,new Color(br.color.r,br.color.g,br.color.b,0.5f+pulse*0.4f),3f);
            PixelRenderer.DrawBorder(cx,cy,CW,CH,new Color(br.color.r,br.color.g,br.color.b,0.6f+pulse*0.3f),2f);

            PixelRenderer.DrawString(cx+8,cy+22,br.icon,28,new Color(br.color.r,br.color.g,br.color.b,_alpha),true);
            PixelRenderer.DrawString(cx+4,cy+66,br.name.ToUpper(),12,Color.white,true,Mathf.RoundToInt(CW-8));
            PixelRenderer.DrawString(cx+4,cy+82,br.desc,11,new Color(0.75f,0.80f,0.75f),false,Mathf.RoundToInt(CW-8));

            var bs=GameManager.Instance.GetBranch(_chosenSub+":"+_branches[i]);
            int lv=bs.Level, bdg=bs.Badges.Count;
            PixelRenderer.DrawString(cx+4,cy+104,"Lv."+lv+"  ★"+bdg+"/20",11,new Color(0.67f,0.84f,1f));
            PixelRenderer.DrawRect(cx+4,cy+120,CW-8,8,PixelRenderer.COL_BLACK);
            PixelRenderer.DrawRect(cx+5,cy+121,(CW-10)*(bdg/20f),6,br.color);
            PixelRenderer.DrawString(cx+4,cy+136,"Gyms: "+bdg+"/20",10,new Color(0.7f,0.7f,0.9f));

            if(bs.Kaiser) PixelRenderer.DrawString(cx+4,cy+CH-20,"★ KAISER ★",11,PixelRenderer.COL_GOLD,true);
            if(sel) PixelRenderer.DrawRect(cx,cy,CW,CH,new Color(br.color.r,br.color.g,br.color.b,0.08f));
        }

        PixelRenderer.DrawRect(0,H-26,W,26,new Color(0,0,0,0.6f));
        if(_branches.Count>0&&SubjectDB.Subjects[_chosenSub].branches.TryGetValue(_branches[_selBr],out var selBr))
            PixelRenderer.DrawString(W/2-138,H-18,"ENTER to enter "+selBr.name,14,Color.white);
    }
}
