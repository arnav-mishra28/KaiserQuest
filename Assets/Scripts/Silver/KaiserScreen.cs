// KaiserScreen.cs — Kaiser Victory Certification Screen
using UnityEngine;
using System.Collections.Generic;

public class KaiserScreen : MonoBehaviour
{
    public static KaiserScreen Instance { get; private set; }
    void Awake() { Instance = this; }

    float _time, _sealR, _ta, _bt;
    bool  _blink=true;
    readonly List<Spark> _sparks=new();
    readonly List<Star>  _stars=new();

    struct Spark{public float x,y,vx,vy,life,maxLife,size;public Color col;}
    struct Star {public float x,y,s,a,sp;}

    void OnEnable()
    {
        _time=0f;_sealR=0f;_ta=0f;_bt=0f;_blink=true;
        _sparks.Clear();_stars.Clear();
        for(int i=0;i<80;i++) _stars.Add(new Star{x=Random.value*480,y=Random.value*320,s=Random.Range(1f,3f),a=Random.value,sp=Random.Range(.5f,2f)});
        for(int i=0;i<60;i++){
            Color[]cols={PixelRenderer.COL_GOLD,new Color(.75f,.78f,1f),Color.white,new Color(1f,.93f,.66f)};
            _sparks.Add(new Spark{x=240+Random.Range(-10,10),y=160+Random.Range(-10,10),
                vx=Random.Range(-4f,4f),vy=Random.Range(-5f,-.5f),life=Random.Range(.5f,2.5f),maxLife=2f,
                size=Random.Range(2f,6f),col=cols[Random.Range(0,cols.Length)]});
        }
    }

    void Update()
    {
        if(GameScreenManager.Instance?.Current!=GameScreen.Kaiser) return;
        _time+=Time.deltaTime;_ta=Mathf.MoveTowards(_ta,1f,Time.deltaTime*.5f);
        _sealR=Mathf.MoveTowards(_sealR,90f,Time.deltaTime*40f);
        _bt+=Time.deltaTime;if(_bt>=.55f){_bt=0f;_blink=!_blink;}
        for(int i=_sparks.Count-1;i>=0;i--){
            var s=_sparks[i];s.x+=s.vx;s.y+=s.vy;s.vy+=.08f;s.life-=Time.deltaTime;
            if(s.life<=0)_sparks.RemoveAt(i);else _sparks[i]=s;
        }
        for(int i=0;i<_stars.Count;i++){var s=_stars[i];s.a=Mathf.Repeat(s.a+Time.deltaTime*s.sp*.3f,1f);_stars[i]=s;}
        if(_ta>=1f&&Input.anyKeyDown) GameScreenManager.Instance?.GoTo(GameScreen.SubjectSelect);
    }

    void OnGUI()
    {
        if(GameScreenManager.Instance?.Current!=GameScreen.Kaiser) return;
        PixelRenderer.BeginFrame();
        const int W=480,H=320;
        // Background
        PixelRenderer.DrawRect(0,0,W,H,new Color(.08f,.06f,.02f));
        for(int y=0;y<H;y+=4)for(int x=0;x<W;x+=4)
            if(((x/4+y/4)%2)==0) PixelRenderer.DrawRect(x,y,4,4,new Color(.10f,.08f,.04f,.6f));
        // Stars
        foreach(var s in _stars) PixelRenderer.DrawRect(s.x,s.y,s.s,s.s,new Color(1,1,.9f,s.a*_ta));
        // Sparks
        foreach(var s in _sparks){float a=Mathf.Clamp01(s.life/s.maxLife);PixelRenderer.DrawRect(s.x,s.y,s.size,s.size,new Color(s.col.r,s.col.g,s.col.b,a));}
        // Gold border
        if(_ta>.1f){PixelRenderer.DrawBorder(8,8,W-16,H-16,new Color(1f,.84f,0f,_ta*.5f),3f);PixelRenderer.DrawBorder(12,12,W-24,H-24,new Color(1f,.84f,0f,_ta*.25f),1.5f);}
        // Seal ring
        float cr=_sealR;
        if(cr>0f){
            DrawCircleOutline(W/2f,H/2f,cr,new Color(1f,.84f,0f,_ta*.9f),3f);
            DrawCircleOutline(W/2f,H/2f,cr-6f,new Color(1f,.84f,0f,_ta*.5f),1.5f);
            DrawCircleOutline(W/2f,H/2f,cr+8f,new Color(.75f,.78f,1f,_ta*.4f),1f);
            for(int i=0;i<8;i++){float angle=i/8f*Mathf.PI*2f+_time*.2f;
                float x1=W/2f+Mathf.Cos(angle)*(cr-12),y1=H/2f+Mathf.Sin(angle)*(cr-12);
                float x2=W/2f+Mathf.Cos(angle)*(cr+12),y2=H/2f+Mathf.Sin(angle)*(cr+12);
                DrawLine(x1,y1,x2,y2,new Color(1f,.84f,0f,_ta*.7f),2f);}
            FillCircle(W/2f,H/2f,cr-10f,new Color(.06f,.04f,.01f,.95f));
            PixelRenderer.DrawString(W/2f-14,H/2f+10,"K",44,new Color(1f,.84f,0f,_ta),true);
        }
        // KAISER OF KNOWLEDGE title
        if(_ta>.3f){float ta2=(_ta-.3f)*1.43f;
            PixelRenderer.DrawString(108,44,"KAISER OF KNOWLEDGE",24,new Color(0,0,0,.6f*ta2),true);
            PixelRenderer.DrawString(106,42,"KAISER OF KNOWLEDGE",24,new Color(1f,.84f,0f,ta2),true);
            PixelRenderer.DrawRect(60,50,360,2,new Color(1f,.84f,0f,ta2*.6f));}
        // Player name
        if(_ta>.5f){float ta3=(_ta-.5f)*2f;
            string name=GameManager.Instance.PlayerName.ToUpper();
            PixelRenderer.DrawString(240-name.Length*7,254,name,18,new Color(.75f,.78f,1f,ta3),true);
            PixelRenderer.DrawString(152,272,"has restored the light of the world",12,new Color(.8f,.8f,.7f,ta3*.8f));}
        // Press ENTER
        if(_ta>=1f&&_blink){PixelRenderer.DrawRect(148,296,184,16,new Color(0,0,0,.5f));PixelRenderer.DrawString(156,308,"Press any key to continue",13,Color.white);}
        PixelRenderer.EndFrame();
    }

    void DrawCircleOutline(float cx,float cy,float r,Color c,float t)
    {
        int segs=64;
        for(int i=0;i<segs;i++){
            float a1=i/(float)segs*Mathf.PI*2f,a2=(i+1)/(float)segs*Mathf.PI*2f;
            float x1=cx+Mathf.Cos(a1)*r,y1=cy+Mathf.Sin(a1)*r;
            float x2=cx+Mathf.Cos(a2)*r,y2=cy+Mathf.Sin(a2)*r;
            DrawLine(x1,y1,x2,y2,c,t);
        }
    }

    void FillCircle(float cx,float cy,float r,Color c)
    {
        for(float y=cy-r;y<=cy+r;y++){float dx=Mathf.Sqrt(Mathf.Max(0,r*r-(y-cy)*(y-cy)));PixelRenderer.DrawRect(cx-dx,y,dx*2,1,c);}
    }

    void DrawLine(float x1,float y1,float x2,float y2,Color c,float w)
    {
        float dx=x2-x1,dy=y2-y1,len=Mathf.Sqrt(dx*dx+dy*dy);
        if(len<1f)return;int steps=Mathf.CeilToInt(len);
        for(int i=0;i<steps;i++){float t=i/(float)steps;PixelRenderer.DrawRect(x1+dx*t-w/2,y1+dy*t-w/2,w,w,c);}
    }
}
