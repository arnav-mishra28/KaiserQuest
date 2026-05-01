// PixelRenderer.cs  –  Gen1/2 OnGUI pixel-art renderer
// Virtual canvas: 480 × 320.  Call BeginFrame()/EndFrame() around all draws.
using UnityEngine;

public static class PixelRenderer
{
    public const int W = 480;
    public const int H = 320;

    // ── Palette ───────────────────────────────────────────────────────────────
    public static readonly Color COL_BLACK = new(0.094f, 0.063f, 0.063f, 1f);
    public static readonly Color COL_WHITE = new(0.972f, 0.957f, 0.925f, 1f);
    public static readonly Color COL_GOLD  = new(1.000f, 0.843f, 0.000f, 1f);
    public static readonly Color COL_HP_G  = new(0.314f, 0.820f, 0.188f, 1f);
    public static readonly Color COL_HP_Y  = new(0.973f, 0.784f, 0.000f, 1f);
    public static readonly Color COL_HP_R  = new(0.910f, 0.125f, 0.125f, 1f);
    public static readonly Color COL_HP_BK = new(0.157f, 0.157f, 0.157f, 1f);
    public static readonly Color COL_BG_LT = new(0.910f, 0.910f, 0.816f, 1f);
    public static readonly Color COL_BG_DK = new(0.847f, 0.847f, 0.749f, 1f);
    public static readonly Color COL_CREAM = new(0.910f, 0.910f, 0.870f, 1f);

    // ── White texture (1×1) ───────────────────────────────────────────────────
    static Texture2D _white;
    static Texture2D White {
        get {
            if (_white != null) return _white;
            _white = new Texture2D(1, 1, TextureFormat.RGBA32, false)
                { filterMode = FilterMode.Point };
            _white.SetPixel(0, 0, Color.white);
            _white.Apply();
            return _white;
        }
    }

    // ── Frame state ───────────────────────────────────────────────────────────
    static float _sx = 1f, _sy = 1f, _ox = 0f, _oy = 0f;

    public static void BeginFrame()
    {
        float s  = Mathf.Min(Screen.width / (float)W, Screen.height / (float)H);
        _sx = s; _sy = s;
        _ox = (Screen.width  - W * s) * 0.5f;
        _oy = (Screen.height - H * s) * 0.5f;
        GUI.matrix = Matrix4x4.TRS(new Vector3(_ox, _oy, 0),
                                   Quaternion.identity, new Vector3(s, s, 1));
    }

    public static void EndFrame()
    {
        GUI.matrix = Matrix4x4.identity;
        GUI.color  = Color.white;
    }

    // ── Core rectangle ────────────────────────────────────────────────────────
    public static void DrawRect(float x, float y, float w, float h, Color c)
    {
        if (c.a <= 0f || w <= 0 || h <= 0) return;
        var prev = GUI.color;
        GUI.color = c;
        GUI.DrawTexture(new Rect(x, y, w, h), White);
        GUI.color = prev;
    }
    public static void DrawRect(Rect r, Color c) => DrawRect(r.x, r.y, r.width, r.height, c);

    // ── Border ────────────────────────────────────────────────────────────────
    public static void DrawBorder(float x, float y, float w, float h, Color c, float t = 1.5f)
    {
        if (c.a <= 0f) return;
        float th = Mathf.Max(1f, t);
        DrawRect(x,       y,       w,  th, c);
        DrawRect(x,       y+h-th,  w,  th, c);
        DrawRect(x,       y,       th, h,  c);
        DrawRect(x+w-th,  y,       th, h,  c);
    }

    // ── Text (with drop-shadow) ───────────────────────────────────────────────
    static GUIStyle _style;
    static int      _lastSize = -1;
    static bool     _lastBold = false;

    static GUIStyle Style(int size, bool bold)
    {
        if (_style == null || _lastSize != size || _lastBold != bold) {
            _style = new GUIStyle(GUI.skin.label) {
                fontStyle = bold ? FontStyle.Bold : FontStyle.Normal,
                alignment = TextAnchor.UpperLeft,
                wordWrap  = false,
                clipping  = TextClipping.Overflow,
                fontSize  = size,
                richText  = false,
            };
            _lastSize = size; _lastBold = bold;
        }
        return _style;
    }

    public static void DrawString(float x, float y, string text, int size,
                                  Color c, bool bold = false, int maxW = -1)
    {
        if (string.IsNullOrEmpty(text) || c.a <= 0f) return;
        var st = Style(size, bold);
        float fw = maxW > 0 ? maxW : W;
        float fh = size * 2.4f;

        // Shadow
        st.normal.textColor = new Color(0f, 0f, 0f, Mathf.Min(c.a * 0.65f, 1f));
        GUI.Label(new Rect(x + 1f, y + 1.2f, fw, fh), text, st);

        // Main
        st.normal.textColor = c;
        GUI.Label(new Rect(x, y, fw, fh), text, st);
    }

    // Centred string
    public static void DrawStringC(float cx, float y, string text, int size,
                                   Color c, bool bold = false)
    {
        float fw = text.Length * size * 0.62f;
        DrawString(cx - fw * 0.5f, y, text, size, c, bold);
    }

    // ── Composites ────────────────────────────────────────────────────────────
    public static void DrawHPBar(float x, float y, float w, float h, float frac)
    {
        Color hc = frac > 0.5f ? COL_HP_G : frac > 0.25f ? COL_HP_Y : COL_HP_R;
        DrawRect(x,   y,   w,   h,   COL_BLACK);
        DrawRect(x+1, y+1, w-2, h-2, COL_HP_BK);
        DrawRect(x+1, y+1, (w-2)*Mathf.Clamp01(frac), h-2, hc);
    }

    public static void DrawDialogBox(float x, float y, float w, float h)
    {
        DrawRect(x,   y,   w,  h,  COL_BLACK);
        DrawRect(x+2, y+2, w-4, h-4, COL_WHITE);
        DrawBorder(x+2, y+2, w-4, h-4, COL_BLACK, 2f);
        DrawRect(x+6, y+6, w-12, h-12, COL_WHITE);
        DrawBorder(x+6, y+6, w-12, h-12, COL_BLACK, 1.5f);
    }

    public static void DrawBattleBackground()
    {
        for (int gy = 0; gy < H/2; gy += 4)
        for (int gx = 0; gx < W;   gx += 4)
            DrawRect(gx, gy, 4, 4, ((gx/4+gy/4)%2==0) ? COL_BG_DK : COL_BG_LT);
        DrawRect(0, H/2, W, 4,    COL_BLACK);
        DrawRect(0, H/2+4, W, H/2-4, COL_WHITE);
    }

    public static void DrawPlatform(float px, float py, float pw, bool isPlayer)
    {
        Color pc = isPlayer
            ? new Color(0.69f, 0.63f, 0.38f)
            : new Color(0.63f, 0.56f, 0.38f);
        DrawRect(px-10, py+14, pw+20, 9,  new Color(pc.r-0.2f, pc.g-0.2f, pc.b-0.2f));
        DrawRect(px-14, py+16, pw+28, 7,  pc);
        DrawRect(px-16, py+18, pw+32, 5,  new Color(pc.r+0.1f, pc.g+0.1f, pc.b+0.1f));
    }
}
