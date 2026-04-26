// PixelRenderer.cs — Gen 1/2 Pixel Art Renderer (Unity OnGUI)
// Improved: better text sizing, spacing, contrast, and readability.
using UnityEngine;

public static class PixelRenderer
{
    public const int W = 480;
    public const int H = 320;

    private static Texture2D _whiteTex;
    static Texture2D WhiteTex {
        get {
            if (_whiteTex == null) {
                _whiteTex = new Texture2D(1,1,TextureFormat.RGBA32,false);
                _whiteTex.filterMode = FilterMode.Point;
                _whiteTex.SetPixel(0,0,Color.white);
                _whiteTex.Apply();
            }
            return _whiteTex;
        }
    }

    static float _sx=1f, _sy=1f, _ox=0f, _oy=0f;

    public static void BeginFrame()
    {
        float sx = Screen.width  / (float)W;
        float sy = Screen.height / (float)H;
        float s  = Mathf.Min(sx, sy);
        _sx = s; _sy = s;
        _ox = (Screen.width  - W*s) * 0.5f;
        _oy = (Screen.height - H*s) * 0.5f;
        GUI.matrix = Matrix4x4.TRS(new Vector3(_ox,_oy,0), Quaternion.identity, new Vector3(s,s,1));
    }

    public static void EndFrame()
    {
        GUI.matrix = Matrix4x4.identity;
        GUI.color  = Color.white;
    }

    // ── Core draw ──────────────────────────────────────────────────────────────
    public static void DrawRect(float x, float y, float w, float h, Color c)
    {
        if (c.a <= 0f) return;
        var prev = GUI.color;
        GUI.color = c;
        GUI.DrawTexture(new Rect(x, y, w, h), WhiteTex);
        GUI.color = prev;
    }

    public static void DrawRect(Rect r, Color c) => DrawRect(r.x, r.y, r.width, r.height, c);

    public static void DrawBorder(float x, float y, float w, float h, Color c, float t=1.5f)
    {
        if (c.a <= 0f) return;
        float th = Mathf.Max(1f, t);
        DrawRect(x,       y,       w,  th, c);
        DrawRect(x,       y+h-th,  w,  th, c);
        DrawRect(x,       y,       th, h,  c);
        DrawRect(x+w-th,  y,       th, h,  c);
    }

    public static void DrawLine(float x1,float y1,float x2,float y2,Color c,float lw=1f)
    {
        if (c.a<=0f) return;
        float dx=x2-x1, dy=y2-y1, len=Mathf.Sqrt(dx*dx+dy*dy);
        if (len<0.5f) return;
        int steps=Mathf.CeilToInt(len);
        for(int i=0;i<steps;i++){
            float tt=(float)i/steps;
            DrawRect(x1+dx*tt-lw/2, y1+dy*tt-lw/2, lw, lw, c);
        }
    }

    // ── Text ───────────────────────────────────────────────────────────────────
    // Refreshed every frame so fontSize changes take effect immediately.
    static GUIStyle _labelStyle;
    static GUIStyle _boldStyle;
    static int      _lastLabelSize = -1;
    static int      _lastBoldSize  = -1;

    static GUIStyle GetLabelStyle(int size, bool bold)
    {
        if (bold) {
            if (_boldStyle == null || _lastBoldSize != size) {
                _boldStyle = new GUIStyle(GUI.skin.label) {
                    fontStyle  = FontStyle.Bold,
                    alignment  = TextAnchor.UpperLeft,
                    wordWrap   = false,
                    clipping   = TextClipping.Overflow,
                    fontSize   = size,
                    richText   = false,
                };
                _lastBoldSize = size;
            }
            return _boldStyle;
        } else {
            if (_labelStyle == null || _lastLabelSize != size) {
                _labelStyle = new GUIStyle(GUI.skin.label) {
                    fontStyle  = FontStyle.Normal,
                    alignment  = TextAnchor.UpperLeft,
                    wordWrap   = false,
                    clipping   = TextClipping.Overflow,
                    fontSize   = size,
                    richText   = false,
                };
                _lastLabelSize = size;
            }
            return _labelStyle;
        }
    }

    /// <summary>
    /// Draw text with a drop-shadow for readability.
    /// x,y  = top-left corner (in logical 480×320 space, y increases downward).
    /// size = font size in logical pixels (e.g. 12 = comfortable reading).
    /// </summary>
    public static void DrawString(float x, float y, string text, int size, Color c,
                                  bool bold=false, int maxWidth=-1)
    {
        if (string.IsNullOrEmpty(text) || c.a <= 0f) return;
        var style = GetLabelStyle(size, bold);
        float fw  = maxWidth > 0 ? maxWidth : W;
        float fh  = size * 2.2f;   // generous height so descenders don't clip

        // Shadow pass (1px offset, semi-transparent black)
        style.normal.textColor = new Color(0f, 0f, 0f, Mathf.Min(0.72f * c.a, 1f));
        GUI.Label(new Rect(x+1.2f, y+1.2f, fw, fh), text, style);

        // Main text
        style.normal.textColor = c;
        GUI.Label(new Rect(x, y, fw, fh), text, style);
    }

    // ── Gen 1/2 UI Colors ──────────────────────────────────────────────────────
    public static readonly Color COL_BLACK = new(0.094f,0.063f,0.063f,1f);
    public static readonly Color COL_WHITE = new(0.972f,0.972f,0.941f,1f);
    public static readonly Color COL_GOLD  = new(1.000f,0.843f,0.000f,1f);
    public static readonly Color COL_HP_G  = new(0.314f,0.820f,0.188f,1f);
    public static readonly Color COL_HP_Y  = new(0.973f,0.784f,0.000f,1f);
    public static readonly Color COL_HP_R  = new(0.910f,0.125f,0.125f,1f);
    public static readonly Color COL_HP_BK = new(0.157f,0.157f,0.157f,1f);
    public static readonly Color COL_BG_LT = new(0.910f,0.910f,0.816f,1f);
    public static readonly Color COL_BG_DK = new(0.847f,0.847f,0.749f,1f);
    public static readonly Color COL_CREAM = new(0.910f,0.910f,0.870f,1f);

    // ── Composite widgets ──────────────────────────────────────────────────────
    public static void DrawDialogBox(float x, float y, float w, float h)
    {
        DrawRect(x,   y,   w,  h,  COL_BLACK);
        DrawRect(x+2, y+2, w-4, h-4, COL_WHITE);
        DrawBorder(x+2, y+2, w-4, h-4, COL_BLACK, 2f);
        DrawRect(x+6, y+6, w-12, h-12, COL_WHITE);
        DrawBorder(x+6, y+6, w-12, h-12, COL_BLACK, 1.5f);
        // Corner ornaments
        float[] cx={x, x+w-10f}; float[] cy={y, y+h-10f};
        foreach(float ccx in cx) foreach(float ccy in cy) {
            DrawRect(ccx, ccy, 10, 10, COL_BLACK);
            DrawRect(ccx+2, ccy+2, 6, 6, COL_HP_R);
        }
    }

    public static void DrawHPBar(float x, float y, float w, float h, float frac)
    {
        Color hcol = frac > 0.5f ? COL_HP_G : frac > 0.25f ? COL_HP_Y : COL_HP_R;
        DrawRect(x,   y,   w,   h,   COL_BLACK);
        DrawRect(x+1, y+1, w-2, h-2, COL_HP_BK);
        DrawRect(x+1, y+1, (w-2)*Mathf.Clamp01(frac), h-2, hcol);
    }

    public static void DrawBattleBackground()
    {
        // Checkerboard top half
        for (int gy=0; gy<H/2; gy+=4)
        for (int gx=0; gx<W;   gx+=4)
            DrawRect(gx, gy, 4, 4,
                ((gx/4+gy/4)%2==0) ? COL_BG_DK : COL_BG_LT);
        // Divider
        DrawRect(0, H/2, W, 4, COL_BLACK);
        // Plain lower half
        DrawRect(0, H/2+4, W, H/2-4, COL_WHITE);
    }

    public static void DrawPlatform(float px, float py, float pw, bool isPlayer)
    {
        Color pc = isPlayer ? new Color(0.69f,0.63f,0.38f) : new Color(0.63f,0.56f,0.38f);
        DrawRect(px-10, py+14, pw+20, 9,  new Color(pc.r-0.2f, pc.g-0.2f, pc.b-0.2f));
        DrawRect(px-14, py+16, pw+28, 7,  pc);
        DrawRect(px-16, py+18, pw+32, 5,  new Color(pc.r+0.1f, pc.g+0.1f, pc.b+0.1f));
    }
}
