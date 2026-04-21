// PixelRenderer.cs — Core 2.5D Pixel Art Rendering Engine
// Provides a cached Texture2D drawing system for authentic Gen 1/2 Pokemon-style visuals
// Usage: Call DrawRect, DrawString, DrawPoly inside any OnGUI() method
using UnityEngine;
using System.Collections.Generic;

public static class PixelRenderer
{
    // ── Logical canvas (480×320 = classic Pokemon resolution) ─────────────────
    public const  int  W = 480;
    public const  int  H = 320;
    private static float _scaleX = 1f;
    private static float _scaleY = 1f;
    private static float _offsetX = 0f;
    private static float _offsetY = 0f;

    // ── Texture cache (avoids GC allocation every frame) ──────────────────────
    private static readonly Dictionary<Color, Texture2D> _texCache = new();
    private static Texture2D GetTex(Color c)
    {
        c.a = Mathf.Clamp01(c.a);
        if (!_texCache.TryGetValue(c, out var tex) || tex == null) {
            tex = new Texture2D(1, 1, TextureFormat.RGBA32, false);
            tex.filterMode = FilterMode.Point;
            tex.SetPixel(0, 0, c);
            tex.Apply();
            _texCache[c] = tex;
        }
        return tex;
    }

    // ── Setup matrix (call once per OnGUI frame) ──────────────────────────────
    public static void BeginFrame()
    {
        float sx = Screen.width  / (float)W;
        float sy = Screen.height / (float)H;
        float s  = Mathf.Min(sx, sy);
        _scaleX  = s; _scaleY = s;
        _offsetX = (Screen.width  - W * s) * 0.5f;
        _offsetY = (Screen.height - H * s) * 0.5f;
        GUI.matrix = Matrix4x4.TRS(new Vector3(_offsetX, _offsetY, 0),
                                   Quaternion.identity,
                                   new Vector3(s, s, 1));
    }

    public static void EndFrame()
    {
        GUI.matrix = Matrix4x4.identity;
    }

    // ── Core draw functions ───────────────────────────────────────────────────
    public static void DrawRect(float x, float y, float w, float h, Color c)
    {
        if (c.a <= 0) return;
        GUI.DrawTexture(new Rect(x, y, w, h), GetTex(c));
    }

    public static void DrawRect(Rect r, Color c) => DrawRect(r.x, r.y, r.width, r.height, c);

    public static void DrawBorder(float x, float y, float w, float h, Color c, float thickness = 1.5f)
    {
        if (c.a <= 0) return;
        var t  = GetTex(c);
        float th = Mathf.Max(1, thickness);
        GUI.DrawTexture(new Rect(x,      y,      w,  th), t);  // top
        GUI.DrawTexture(new Rect(x,      y+h-th, w,  th), t);  // bottom
        GUI.DrawTexture(new Rect(x,      y,      th, h),  t);  // left
        GUI.DrawTexture(new Rect(x+w-th, y,      th, h),  t);  // right
    }

    public static void DrawLine(float x1, float y1, float x2, float y2, Color c, float width = 1f)
    {
        if (c.a <= 0) return;
        var matrix = GUI.matrix;
        float dx = x2 - x1; float dy = y2 - y1;
        float dist = Mathf.Sqrt(dx*dx + dy*dy);
        float angle = Mathf.Atan2(dy, dx) * Mathf.Rad2Deg;
        var pivot = new Vector2(x1, y1);
        GUI.matrix = Matrix4x4.TRS(new Vector3(_offsetX + x1*_scaleX, _offsetY + y1*_scaleY, 0),
            Quaternion.Euler(0,0,angle), new Vector3(_scaleX, _scaleY, 1)) * matrix;
        GUI.DrawTexture(new Rect(0, -width*0.5f, dist, width), GetTex(c));
        GUI.matrix = matrix;
    }

    // ── Text rendering (pixel-perfect) ────────────────────────────────────────
    private static GUIStyle _textStyle;
    private static GUIStyle _textStyleBold;

    static void EnsureStyles()
    {
        if (_textStyle == null) {
            _textStyle = new GUIStyle(GUI.skin.label) {
                fontStyle = FontStyle.Normal,
                alignment = TextAnchor.UpperLeft,
                wordWrap  = false,
                clipping  = TextClipping.Overflow
            };
        }
        if (_textStyleBold == null) {
            _textStyleBold = new GUIStyle(GUI.skin.label) {
                fontStyle = FontStyle.Bold,
                alignment = TextAnchor.UpperLeft,
                wordWrap  = false,
                clipping  = TextClipping.Overflow
            };
        }
    }

    public static void DrawString(float x, float y, string text, int size, Color c, bool bold = false, int maxWidth = -1)
    {
        if (string.IsNullOrEmpty(text) || c.a <= 0) return;
        EnsureStyles();
        var style = bold ? _textStyleBold : _textStyle;
        style.fontSize = size;
        style.normal.textColor = c;
        float w = maxWidth > 0 ? maxWidth : 400f;
        // Shadow for readability
        var shadowStyle = new GUIStyle(style);
        shadowStyle.normal.textColor = new Color(0,0,0,0.5f*c.a);
        GUI.Label(new Rect(x+1, y+1, w, size*1.8f), text, shadowStyle);
        GUI.Label(new Rect(x,   y,   w, size*1.8f), text, style);
    }

    // ── Gen 1/2 UI Primitives ─────────────────────────────────────────────────
    public static readonly Color COL_BLACK  = new Color(0.094f, 0.063f, 0.063f);
    public static readonly Color COL_WHITE  = new Color(0.972f, 0.972f, 0.941f);
    public static readonly Color COL_CREAM  = new Color(0.910f, 0.910f, 0.870f);
    public static readonly Color COL_GOLD   = new Color(1.000f, 0.843f, 0.000f);
    public static readonly Color COL_HP_G   = new Color(0.314f, 0.820f, 0.188f);
    public static readonly Color COL_HP_Y   = new Color(0.973f, 0.784f, 0.000f);
    public static readonly Color COL_HP_R   = new Color(0.910f, 0.125f, 0.125f);
    public static readonly Color COL_HP_BK  = new Color(0.157f, 0.157f, 0.157f);
    public static readonly Color COL_BG_LT  = new Color(0.910f, 0.910f, 0.816f);
    public static readonly Color COL_BG_DK  = new Color(0.847f, 0.847f, 0.749f);

    // Gen 1/2 dialog box (double-border white box)
    public static void DrawDialogBox(float x, float y, float w, float h)
    {
        DrawRect(x,   y,   w,   h,   COL_BLACK);
        DrawRect(x+2, y+2, w-4, h-4, COL_WHITE);
        DrawBorder(x+2, y+2, w-4, h-4, COL_BLACK, 2f);
        DrawRect(x+6, y+6, w-12, h-12, COL_WHITE);
        DrawBorder(x+6, y+6, w-12, h-12, COL_BLACK, 1.5f);
        // Corner ornaments
        float[] cx2 = { x, x+w-10 };
        float[] cy2 = { y, y+h-10 };
        foreach (float cx in cx2) foreach (float cy in cy2) {
            DrawRect(cx, cy, 10, 10, COL_BLACK);
            DrawRect(cx+2, cy+2, 6, 6, COL_HP_R);
        }
    }

    // Gen 1/2 HP bar
    public static void DrawHPBar(float x, float y, float w, float h, float fraction)
    {
        Color hcol = fraction > 0.5f ? COL_HP_G : fraction > 0.25f ? COL_HP_Y : COL_HP_R;
        DrawRect(x,   y,   w,   h,   COL_BLACK);
        DrawRect(x+1, y+1, w-2, h-2, COL_HP_BK);
        DrawRect(x+1, y+1, (w-2) * Mathf.Clamp01(fraction), h-2, hcol);
    }

    // Pokemon-style battle background (checkered)
    public static void DrawBattleBackground()
    {
        for (int gy = 0; gy < H/2; gy += 4)
        for (int gx = 0; gx < W;   gx += 4)
            DrawRect(gx, gy, 4, 4, ((gx/4 + gy/4) % 2 == 0) ? COL_BG_DK : COL_BG_LT);
        DrawRect(0, H/2, W, 4, COL_BLACK);
        DrawRect(0, H/2+4, W, H/2-4, COL_WHITE);
    }

    // Battle platform (Gen 1/2 oval style)
    public static void DrawPlatform(float px, float py, float pw, bool isPlayer)
    {
        var pc = isPlayer ? new Color(0.69f, 0.63f, 0.38f) : new Color(0.63f, 0.56f, 0.38f);
        DrawRect(px-10, py+14, pw+20, 9,  new Color(pc.r-0.2f, pc.g-0.2f, pc.b-0.2f));
        DrawRect(px-14, py+16, pw+28, 7,  pc);
        DrawRect(px-16, py+18, pw+32, 5,  new Color(pc.r+0.1f, pc.g+0.1f, pc.b+0.1f));
    }
}
