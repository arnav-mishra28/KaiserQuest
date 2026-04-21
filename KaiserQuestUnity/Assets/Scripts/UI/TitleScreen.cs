// TitleScreen.cs — Animated Pokemon-style Title Screen
using UnityEngine;

public class TitleScreen : MonoBehaviour
{
    private float _time     = 0f;
    private float _alpha    = 0f;
    private bool  _ready    = false;
    private float _blinkT   = 0f;
    private bool  _blink    = true;

    static readonly Vector2[] STARS = {
        new(18,12),new(55,8),new(95,22),new(148,6),new(190,18),
        new(235,10),new(280,25),new(330,8),new(375,20),new(415,12),
        new(458,28),new(32,42),new(78,55),new(128,38),new(200,48),
        new(260,35),new(315,52),new(362,40),new(430,50),new(470,36),
        new(10,70),new(60,82),new(110,68),new(175,88),new(240,72),
        new(300,90),new(355,78),new(410,95),new(455,68)
    };

    void Update()
    {
        _time  += Time.deltaTime;
        _alpha  = Mathf.MoveTowards(_alpha, 1f, Time.deltaTime * 0.55f);
        if (_alpha >= 1f) _ready = true;
        _blinkT += Time.deltaTime;
        if (_blinkT >= 0.52f) { _blinkT = 0f; _blink = !_blink; }

        if (_ready && Input.anyKeyDown && GameScreenManager.Instance != null)
        {
            if (string.IsNullOrEmpty(GameManager.Instance.PlayerName) ||
                GameManager.Instance.PlayerName == "Arix")
                GameScreenManager.Instance.GoTo(GameScreen.NameEntry);
            else
                GameScreenManager.Instance.GoTo(GameScreen.SubjectSelect);
        }
    }

    void OnGUI()
    {
        PixelRenderer.BeginFrame();
        int W = PixelRenderer.W; int H = PixelRenderer.H;

        // Sky gradient
        for (int i = 0; i < 8; i++) {
            float t = i / 7f;
            PixelRenderer.DrawRect(0, i*40, W, 42,
                new Color(0.02f+t*0.04f, 0.02f+t*0.06f, 0.10f+t*0.14f, _alpha));
        }

        // Stars
        for (int si = 0; si < STARS.Length; si++) {
            float tw = 0.55f + 0.45f * Mathf.Sin(_time*1.8f + si*0.7f);
            int ss = (si%3==0) ? 2 : 1;
            PixelRenderer.DrawRect(STARS[si].x, STARS[si].y, ss, ss, new Color(1,1,1,_alpha*tw));
        }

        // Moon
        PixelRenderer.DrawRect(400,18,24,24,new Color(1f,0.97f,0.80f,_alpha));
        PixelRenderer.DrawRect(407,20,22,20,new Color(0.04f,0.04f,0.14f,_alpha));

        // Mountains (silhouette)
        Color dm = new Color(0.06f,0.07f,0.18f,_alpha);
        DrawTriFill(0,200,60,140,130,200,dm);
        DrawTriFill(100,200,200,118,310,200,dm);
        DrawTriFill(270,200,380,108,480,200,dm);
        // Silver peak
        DrawTriFill(360,126,380,108,400,126,new Color(0.78f,0.84f,1f,_alpha));

        // Ground
        PixelRenderer.DrawRect(0,200,W,H-200,new Color(0.05f,0.10f,0.05f,_alpha));
        for (int gx=0;gx<480;gx+=8)
            PixelRenderer.DrawRect(gx,197,4,3+(gx%5),new Color(0.10f,0.22f,0.08f,_alpha*0.7f));

        // Title plate
        if (_alpha > 0.1f) {
            PixelRenderer.DrawRect(60,62,362,114,new Color(0,0,0,_alpha*0.55f));
            PixelRenderer.DrawBorder(58,60,364,116,new Color(1f,0.84f,0f,_alpha*0.88f),3f);
            PixelRenderer.DrawBorder(62,64,356,108,new Color(0.6f,0.45f,0f,_alpha*0.55f),1.5f);
            // KAISER text with shadow
            PixelRenderer.DrawString(86,92,"KAISER",52,new Color(0,0,0,_alpha*0.6f),true);
            PixelRenderer.DrawString(84,90,"KAISER",52,new Color(1f,0.88f,0.20f,_alpha),true);
            PixelRenderer.DrawString(222,132,"QUEST",52,new Color(0,0,0,_alpha*0.6f),true);
            PixelRenderer.DrawString(220,130,"QUEST",52,new Color(1f,1f,1f,_alpha),true);
            PixelRenderer.DrawRect(68,138,346,2,new Color(1f,0.84f,0f,_alpha*0.7f));
        }

        if (_alpha > 0.5f)
            PixelRenderer.DrawString(90,158,"Learn  ·  Level Up  ·  Become Kaiser",14,new Color(0.75f,0.82f,1f,_alpha));

        // Subject icons
        if (_alpha > 0.7f) {
            DrawSubjectIcon(90,  "∑","MATH",    new Color(0.27f,0.67f,1f,_alpha));
            DrawSubjectIcon(196, "A","LANGUAGES",new Color(1f,0.80f,0.27f,_alpha));
            DrawSubjectIcon(334, "♪","MUSIC",   new Color(0.80f,0.27f,1f,_alpha));
        }

        if (_ready && _blink) {
            PixelRenderer.DrawRect(138,248,204,22,new Color(0,0,0,0.55f));
            PixelRenderer.DrawString(152,250,"Press  ENTER  to  Start",16,Color.white);
        }

        PixelRenderer.DrawString(396,306,"v1.0",11,new Color(0.3f,0.3f,0.5f,_alpha));
        PixelRenderer.EndFrame();
    }

    void DrawTriFill(float x1,float y1,float x2,float y2,float x3,float y3,Color c)
    {
        // Approximate triangle fill with horizontal rectangles
        float minY=Mathf.Min(y1,Mathf.Min(y2,y3));
        float maxY=Mathf.Max(y1,Mathf.Max(y2,y3));
        for(float y=minY;y<=maxY;y++) {
            float lx=W,rx=0;
            float[] xs={x1,x2,x3}; float[] ys={y1,y2,y3};
            for(int i=0;i<3;i++){
                int j=(i+1)%3;
                if((ys[i]<=y&&y<ys[j])||(ys[j]<=y&&y<ys[i])){
                    float t=(y-ys[i])/(ys[j]-ys[i]);
                    float xi=xs[i]+t*(xs[j]-xs[i]);
                    if(xi<lx)lx=xi; if(xi>rx)rx=xi;
                }
            }
            if(rx>=lx)PixelRenderer.DrawRect(lx,y,rx-lx,1,c);
        }
    }

    void DrawSubjectIcon(float x, string icon, string label, Color col)
    {
        PixelRenderer.DrawRect(x-2,198,82,38,new Color(0,0,0,0.45f));
        PixelRenderer.DrawBorder(x-2,198,82,38,new Color(col.r,col.g,col.b,0.45f),1.5f);
        PixelRenderer.DrawString(x+6,206,icon,20,col,true);
        PixelRenderer.DrawString(x+30,214,label,9,new Color(0.9f,0.9f,0.9f,col.a));
    }
}
