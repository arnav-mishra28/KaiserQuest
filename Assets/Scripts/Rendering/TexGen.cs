// TexGen.cs — Pixel-Art Texture Generator for 2.5D World
// Generates Texture2D objects for 3D tile quads and billboard sprites.
using UnityEngine;

public static class TexGen
{
    // ── Colours (shared with PixelRenderer palette) ───────────────────────────
    static readonly Color DK   = new(0.094f,0.063f,0.063f,1f);
    static readonly Color SKN  = new(0.941f,0.784f,0.533f,1f);
    static readonly Color RED  = new(0.753f,0.063f,0.094f,1f);
    static readonly Color RDL  = new(0.878f,0.125f,0.125f,1f);
    static readonly Color BLU  = new(0.094f,0.157f,0.627f,1f);
    static readonly Color GLD  = new(1.000f,0.843f,0.000f,1f);
    static readonly Color CLEAR = new(0,0,0,0);

    // ── Helpers ───────────────────────────────────────────────────────────────
    static Texture2D Make(int w, int h, bool alpha=true)
    {
        var t = new Texture2D(w, h, alpha ? TextureFormat.RGBA32 : TextureFormat.RGB24, false);
        t.filterMode = FilterMode.Point;
        t.wrapMode   = TextureWrapMode.Clamp;
        return t;
    }

    // Draw rect. y=0 is TOP of image (flipped for Texture2D internally).
    static void R(Color[] px, int W, int H, int x, int y, int w, int h, Color c)
    {
        for (int dy = 0; dy < h; dy++)
        for (int dx = 0; dx < w; dx++) {
            int px2 = x+dx, py2 = H-1-(y+dy);   // flip Y so y=0 == top
            if (px2 >= 0 && px2 < W && py2 >= 0 && py2 < H)
                px[py2*W + px2] = Color.Lerp(px[py2*W+px2], c, c.a > 0.999f ? 1f : c.a);
        }
    }

    static Color Dk(Color c, float f=0.85f) => new(c.r*f, c.g*f, c.b*f, c.a);
    static Color Lt(Color c, float f=1.15f) =>
        new(Mathf.Min(c.r*f,1f), Mathf.Min(c.g*f,1f), Mathf.Min(c.b*f,1f), c.a);

    // ── Ground Tilemap ────────────────────────────────────────────────────────
    /// <summary>Generates a single 480×320 texture for the entire ground plane.</summary>
    public static Texture2D BuildTilemap(int[,] map, Color subjectColor)
    {
        int ROWS = map.GetLength(0), COLS = map.GetLength(1);
        int W = COLS*32, H = ROWS*32;
        var t = Make(W, H, false);
        var px = new Color[W*H];

        Color grassBase = Color.Lerp(subjectColor, new Color(0.14f,0.32f,0.12f), 0.6f);

        for (int r = 0; r < ROWS; r++)
        for (int c = 0; c < COLS; c++) {
            int tile = map[r,c];
            int bx = c*32, by = r*32;
            DrawGroundTile(px, W, H, bx, by, tile, c, r, subjectColor, grassBase);
        }

        t.SetPixels(px); t.Apply();
        return t;
    }

    static void DrawGroundTile(Color[] px, int W, int H,
        int bx, int by, int tile, int c, int r, Color sc, Color grassBase)
    {
        bool chk = ((c+r)%2)==0;
        switch (tile) {
            case 4:  DrawPath (px,W,H,bx,by,chk); return;
            case 8:  DrawWater(px,W,H,bx,by);     return;
            case 9:  DrawSand (px,W,H,bx,by,chk); return;
            default: DrawGrass(px,W,H,bx,by,grassBase,chk,(c*11+r*7)%14==0); return;
        }
    }

    static void DrawGrass(Color[] px, int W, int H, int bx, int by, Color col, bool chk, bool flower)
    {
        Color c2 = Dk(col, 0.88f);
        R(px,W,H,bx,by,32,32,col);
        for (int dy=0; dy<32; dy+=4)
        for (int dx=0; dx<32; dx+=4)
            if (((dx/4+dy/4)%2)==0) R(px,W,H,bx+dx,by+dy,4,4,c2);
        if (flower) R(px,W,H,bx+10,by+18,4,4,new Color(0.97f,0.50f,0.63f));
    }

    static void DrawPath(Color[] px, int W, int H, int bx, int by, bool chk)
    {
        Color p1=new(0.75f,0.69f,0.48f), p2=new(0.78f,0.73f,0.53f);
        R(px,W,H,bx,by,32,32,chk?p1:p2);
        R(px,W,H,bx+1, by+1, 14,14,new Color(0,0,0,0.06f));
        R(px,W,H,bx+17,by+1, 14,14,new Color(0,0,0,0.06f));
        R(px,W,H,bx+9, by+17,14,14,new Color(0,0,0,0.06f));
    }

    static void DrawWater(Color[] px, int W, int H, int bx, int by)
    {
        R(px,W,H,bx,by,32,32,new Color(0.08f,0.25f,0.75f));
        foreach (int wy in new[]{5,12,19,26})
            R(px,W,H,bx+2,by+wy,28,2,new Color(0.30f,0.60f,1f,0.45f));
    }

    static void DrawSand(Color[] px, int W, int H, int bx, int by, bool chk)
    {
        R(px,W,H,bx,by,32,32,chk?new Color(0.83f,0.72f,0.44f):new Color(0.77f,0.66f,0.38f));
    }

    // ── Vertical Sprite Textures ──────────────────────────────────────────────

    public static Texture2D MakeTree()
    {
        int W=32, H=64;
        var t = Make(W,H); var px=InitAlpha(W,H);
        Color tk=new(0.42f,0.25f,0.06f);
        Color t1=new(0.10f,0.25f,0.06f),t2=new(0.16f,0.41f,0.10f),
              t3=new(0.25f,0.63f,0.16f),t4=new(0.44f,0.78f,0.25f);
        // Trunk
        R(px,W,H,12,42,8,22,tk);
        R(px,W,H,13,42,6,22,Dk(tk,0.85f));
        // Foliage rings
        R(px,W,H, 0,24,32,20,t1);
        R(px,W,H, 2,16,28,24,t2);
        R(px,W,H, 5, 8,22,24,t3);
        R(px,W,H, 9, 2,14,20,t4);
        // Highlight
        R(px,W,H,11, 2, 8, 8,new Color(1,1,1,0.18f));
        // Outline on edges
        AddEdgeOutline(px,W,H,DK);
        t.SetPixels(px); t.Apply(); return t;
    }

    public static Texture2D MakeHouse(Color roofCol)
    {
        int W=64, H=64;
        var t = Make(W,H); var px=InitAlpha(W,H);
        Color wall=new(0.78f,0.66f,0.51f);
        R(px,W,H, 0,32,64,32,wall);                      // wall base
        R(px,W,H, 0, 0,64,36,Dk(roofCol));               // roof area dark
        R(px,W,H, 2, 8,60,28,roofCol);                   // roof main
        R(px,W,H, 2,20,60,10,Lt(roofCol,1.12f));         // roof highlight
        R(px,W,H, 6,36,22,22,new Color(0.53f,0.80f,1f)); // window L
        R(px,W,H,36,36,22,22,new Color(0.53f,0.80f,1f)); // window R
        // Window frames
        R(px,W,H,16,36, 2,22,DK); R(px,W,H,6,47,22,2,DK);
        R(px,W,H,46,36, 2,22,DK); R(px,W,H,36,47,22,2,DK);
        // Chimney
        R(px,W,H,48, 0, 8,12,Dk(roofCol,0.7f));
        R(px,W,H,49, 0, 6, 2,new Color(0.2f,0.2f,0.2f));
        AddEdgeOutline(px,W,H,DK);
        t.SetPixels(px); t.Apply(); return t;
    }

    public static Texture2D MakeGymSprite(Color sc, bool isDoor)
    {
        int W=64, H=96;
        var t = Make(W,H); var px=InitAlpha(W,H);
        Color scDk=Dk(sc,0.82f), scLt=Lt(sc,1.1f);
        // Main body
        R(px,W,H, 0,20,64,76,scDk);
        R(px,W,H, 0,20,64,18,sc);
        R(px,W,H, 0,20,64, 6,scLt);
        // Stripe detail
        R(px,W,H, 4,52, 2,44,new Color(sc.r,sc.g,sc.b,0.5f));
        R(px,W,H,58,50, 2,46,new Color(sc.r,sc.g,sc.b,0.5f));
        if (isDoor) {
            // Door frame + opening
            R(px,W,H,14,38,36,58,Lt(scDk,1.15f));
            R(px,W,H,16,56,32,40,new Color(0.45f,0.8f,1f,0.7f));
            // Door handle
            R(px,W,H,42,76, 4, 4,new Color(1,0.85f,0,0.9f));
        } else {
            // Window slit
            R(px,W,H, 8,46,48,12,new Color(0,0,0,0.4f));
            R(px,W,H,10,48,44, 8,new Color(sc.r,sc.g,sc.b,0.5f));
        }
        // Glow strip at top
        R(px,W,H, 4,18,56, 4,new Color(sc.r,sc.g,sc.b,0.85f));
        AddEdgeOutline(px,W,H,DK);
        t.SetPixels(px); t.Apply(); return t;
    }

    public static Texture2D MakeFencePost()
    {
        int W=32, H=32;
        var t = Make(W,H); var px=InitAlpha(W,H);
        Color wood=new(0.55f,0.31f,0.12f), woodLt=Lt(wood,1.2f);
        R(px,W,H, 3, 6, 4,26,wood);
        R(px,W,H, 4, 6, 2,26,woodLt);
        R(px,W,H,25, 6, 4,26,wood);
        R(px,W,H,26, 6, 2,26,woodLt);
        R(px,W,H, 3, 8,26, 4,woodLt);
        R(px,W,H, 3,20,26, 4,wood);
        AddEdgeOutline(px,W,H,DK);
        t.SetPixels(px); t.Apply(); return t;
    }

    public static Texture2D MakeDoorSprite()
    {
        int W=32, H=48;
        var t = Make(W,H); var px=InitAlpha(W,H);
        Color wood=new(0.35f,0.19f,0.06f), woodLt=Lt(wood,1.25f);
        R(px,W,H, 8, 5,16,43,wood);
        R(px,W,H, 9, 5,14,43,woodLt);
        R(px,W,H,18, 5, 4,43,Dk(wood));
        // Knob
        R(px,W,H,20,28, 3, 3,GLD);
        AddEdgeOutline(px,W,H,DK);
        t.SetPixels(px); t.Apply(); return t;
    }

    // ── Character Sprites ─────────────────────────────────────────────────────

    public static Texture2D MakePlayerBack()
    {
        int W=32, H=48;
        var t = Make(W,H); var px=InitAlpha(W,H);

        // Shadow ellipse
        R(px,W,H, 4,44,24, 4,new Color(0,0,0,0.22f));
        // Legs / shoes
        R(px,W,H, 6,38, 9, 6,DK); R(px,W,H, 7,39, 7, 5,new Color(0.16f,0.16f,0.16f));
        R(px,W,H,17,38, 9, 6,DK); R(px,W,H,18,39, 7, 5,new Color(0.16f,0.16f,0.16f));
        // Pants (lower body)
        R(px,W,H, 6,28, 9,10,BLU); R(px,W,H,17,28, 9,10,BLU);
        R(px,W,H, 7,28,18, 4,new Color(0.14f,0.23f,0.66f));
        // Belt
        R(px,W,H, 4,26,24, 3,new Color(0.31f,0.16f,0.03f));
        R(px,W,H,13,26, 6, 3,GLD);
        // Jacket / shirt
        R(px,W,H, 4,14,24,12,RED);
        R(px,W,H, 4,14,24, 4,RDL);
        R(px,W,H, 4,20,24, 6,Dk(RED,0.82f));
        // Backpack detail
        R(px,W,H,12,14, 8, 6,new Color(0.91f,0.91f,0.91f));
        // Arms
        R(px,W,H, 0,15, 5,11,SKN); R(px,W,H,27,15, 5,11,SKN);
        // Neck
        R(px,W,H,13, 9, 6, 6,SKN);
        // Head
        R(px,W,H, 7, 0,18,10,SKN);
        R(px,W,H, 8, 0,16, 4,new Color(0.98f,0.85f,0.72f));
        R(px,W,H, 7, 6,18, 4,new Color(0.847f,0.624f,0.533f));
        // Hat brim
        R(px,W,H, 5, 2,22, 3,RED);
        R(px,W,H, 6, 0,20, 4,RED);
        R(px,W,H, 7, 0,16, 2,RDL);
        R(px,W,H,14, 1, 5, 3,GLD);
        // Eyes (back view: side glance)
        R(px,W,H,10, 6, 4, 3,DK); R(px,W,H,18, 6, 4, 3,DK);
        R(px,W,H,11, 6, 2, 2,new Color(1,1,1,0.7f));
        R(px,W,H,19, 6, 2, 2,new Color(1,1,1,0.7f));

        t.SetPixels(px); t.Apply(); return t;
    }

    public static Texture2D MakeNPC(Color shirt, bool isTeacher, bool isDuel)
    {
        int W=32, H=48;
        var t = Make(W,H); var px=InitAlpha(W,H);
        Color pants=new(0.16f,0.28f,0.56f);

        R(px,W,H, 6,44,20, 4,new Color(0,0,0,0.22f));   // shadow
        R(px,W,H, 7,36, 7, 8,DK); R(px,W,H,18,36, 7, 8,DK); // shoes
        R(px,W,H, 8,26, 7,10,pants); R(px,W,H,17,26, 7,10,pants); // pants
        R(px,W,H, 5,16,22, 9,shirt);
        R(px,W,H, 5,16,22, 3,Lt(shirt,1.15f));           // shirt highlight
        // Arms
        R(px,W,H, 1,17, 5, 9,SKN); R(px,W,H,26,17, 5, 9,SKN);
        // Head
        R(px,W,H, 8, 6,16,10,SKN);
        R(px,W,H, 9, 6,14, 4,new Color(0.98f,0.85f,0.72f));
        R(px,W,H, 8, 3,16, 5,new Color(0.28f,0.16f,0.03f)); // hair
        // Eyes
        R(px,W,H,11,11, 4, 3,DK); R(px,W,H,18,11, 4, 3,DK);
        R(px,W,H,12,11, 2, 2,new Color(1,1,1,0.7f)); R(px,W,H,19,11, 2, 2,new Color(1,1,1,0.7f));
        // Badge above head (teacher=gold "?", duel=red "VS")
        if (isTeacher) {
            R(px,W,H,11,-2,10, 8,GLD);
            R(px,W,H,12,-1, 8, 6,Lt(GLD,1.1f));
        } else if (isDuel) {
            R(px,W,H,11,-2,10, 8,RED);
            R(px,W,H,12,-1, 8, 6,RDL);
        }
        t.SetPixels(px); t.Apply(); return t;
    }

    public static Texture2D MakeItemSparkle(Color col)
    {
        int W=32, H=32;
        var t = Make(W,H); var px=InitAlpha(W,H);
        R(px,W,H, 9, 8,14,15,new Color(col.r,col.g,col.b,0.9f));
        R(px,W,H,12,11, 8,10,new Color(1,1,1,0.65f));
        R(px,W,H,14, 2, 4, 7,new Color(1,1,1,0.9f));  // vertical sparkle
        R(px,W,H,10, 5,12, 3,new Color(1,1,1,0.55f));  // horizontal sparkle
        t.SetPixels(px); t.Apply(); return t;
    }

    // ── Utility ───────────────────────────────────────────────────────────────
    static Color[] InitAlpha(int W, int H)
    {
        var px = new Color[W*H];
        for (int i=0;i<px.Length;i++) px[i]=CLEAR;
        return px;
    }

    static void AddEdgeOutline(Color[] px, int W, int H, Color outlineCol)
    {
        var copy = (Color[])px.Clone();
        for (int y=0;y<H;y++)
        for (int x=0;x<W;x++) {
            if (copy[y*W+x].a < 0.05f) continue;
            bool edgePixel = false;
            foreach (var (dx,dy) in new[]{(-1,0),(1,0),(0,-1),(0,1)}) {
                int nx=x+dx, ny=y+dy;
                if (nx<0||nx>=W||ny<0||ny>=H||copy[ny*W+nx].a<0.05f) { edgePixel=true; break; }
            }
            if (edgePixel) px[y*W+x] = Color.Lerp(px[y*W+x], outlineCol, 0.7f);
        }
    }
}
