// SpriteDrawer.cs  –  Gen1/2 pixel-art characters drawn with GUI rects
using UnityEngine;

public static class SpriteDrawer
{
    // ── Colour palette helpers ────────────────────────────────────────────────
    static readonly Color SK  = new(0.941f,0.784f,0.533f,1f); // skin
    static readonly Color DK  = PixelRenderer.COL_BLACK;
    static readonly Color RED = new(0.753f,0.063f,0.094f,1f);
    static readonly Color RDL = new(0.878f,0.125f,0.125f,1f);
    static readonly Color BLU = new(0.094f,0.157f,0.627f,1f);
    static readonly Color GLD = PixelRenderer.COL_GOLD;
    static readonly Color WH  = PixelRenderer.COL_WHITE;

    static void R(float x,float y,float w,float h,Color c)
        => PixelRenderer.DrawRect(x,y,w,h,c);

    // ── Player (back view, 32×56) ─────────────────────────────────────────────
    public static void DrawPlayerBattle(float ox, float oy)
    {
        // Shadow
        R(ox+2,  oy+52, 24, 4, new Color(0,0,0,0.22f));
        // Shoes
        R(ox+5,  oy+42,  9, 8, DK);   R(ox+6,  oy+43,  7, 7, new Color(0.16f,0.16f,0.16f));
        R(ox+16, oy+42,  9, 8, DK);   R(ox+17, oy+43,  7, 7, new Color(0.16f,0.16f,0.16f));
        // Pants
        R(ox+5,  oy+30, 10,13, BLU);  R(ox+15, oy+30, 10,13, BLU);
        R(ox+6,  oy+30, 18, 4, new Color(0.14f,0.23f,0.66f));
        // Belt
        R(ox+3,  oy+28, 24, 3, new Color(0.31f,0.16f,0.03f));
        R(ox+12, oy+28,  6, 3, GLD);
        // Jacket
        R(ox+3,  oy+14, 24,14, RED);
        R(ox+3,  oy+14, 24, 5, RDL);
        R(ox+3,  oy+20, 24, 8, new Color(0.64f,0.05f,0.08f));
        // Backpack
        R(ox+11, oy+14,  8, 7, WH);
        // Arms
        R(ox,    oy+16,  5,10, SK);   R(ox+25, oy+16,  5,10, SK);
        // Neck
        R(ox+12, oy+10,  6, 5, SK);
        // Head
        R(ox+6,  oy,    18,11, SK);
        R(ox+7,  oy,    16, 4, new Color(0.98f,0.86f,0.73f));
        R(ox+6,  oy+7,  18, 4, new Color(0.847f,0.624f,0.533f));
        // Hat
        R(ox+4,  oy+2,  22, 4, RED);
        R(ox+5,  oy,    20, 4, RDL);
        R(ox+6,  oy,    16, 2, new Color(1f,0.22f,0.22f));
        R(ox+13, oy+1,   5, 4, GLD);
    }

    // ── Gym leader (front view, 32×56) ────────────────────────────────────────
    public static void DrawLeaderBattle(float ox, float oy, Color shirtCol, float t)
    {
        // Idle bob
        float bob = Mathf.Sin(t * 1.4f) * 1.5f;
        oy += bob;

        Color shirt2 = new(shirtCol.r*0.82f, shirtCol.g*0.82f, shirtCol.b*0.82f);
        Color pants  = new(0.16f, 0.28f, 0.56f);

        R(ox+4,  oy+52, 22, 4, new Color(0,0,0,0.22f));
        // Shoes
        R(ox+5,  oy+42,  9, 8, DK);   R(ox+16, oy+42,  9, 8, DK);
        // Pants
        R(ox+5,  oy+28, 10,14, pants); R(ox+15, oy+28, 10,14, pants);
        R(ox+5,  oy+28, 20, 4, new Color(0.12f,0.22f,0.50f));
        // Shirt
        R(ox+3,  oy+14, 24,14, shirtCol);
        R(ox+3,  oy+14, 24, 4, new Color(Mathf.Min(shirtCol.r*1.2f,1f),Mathf.Min(shirtCol.g*1.2f,1f),Mathf.Min(shirtCol.b*1.2f,1f)));
        R(ox+3,  oy+22, 24, 6, shirt2);
        // Arms
        R(ox,    oy+15,  4,12, SK);   R(ox+26, oy+15,  4,12, SK);
        // Neck
        R(ox+12, oy+10,  6, 5, SK);
        // Head
        R(ox+6,  oy+1,  18,10, SK);
        R(ox+7,  oy+1,  16, 3, new Color(0.98f,0.86f,0.73f));
        R(ox+6,  oy+8,  18, 4, new Color(0.847f,0.624f,0.533f));
        // Hair
        R(ox+5,  oy+1,  20, 6, new Color(0.28f,0.16f,0.04f));
        R(ox+5,  oy+1,  20, 2, new Color(0.45f,0.25f,0.06f));
        // Eyes
        R(ox+10, oy+6,   4, 3, DK);   R(ox+17, oy+6,   4, 3, DK);
        R(ox+11, oy+6,   2, 2, WH);   R(ox+18, oy+6,   2, 2, WH);
        R(ox+11, oy+7,   2, 1, shirtCol); R(ox+18, oy+7,   2, 1, shirtCol);
        // Mouth
        R(ox+12, oy+10,  6, 2, new Color(0.75f,0.38f,0.25f));
        // Level badge
        R(ox+9,  oy-8,  12,10, new Color(0,0,0,0.55f));
        R(ox+10, oy-7,  10, 8, shirtCol);
        R(ox+11, oy-6,   8, 6, new Color(Mathf.Min(shirtCol.r*1.3f,1f), Mathf.Min(shirtCol.g*1.3f,1f), Mathf.Min(shirtCol.b*1.3f,1f)));
    }

    // ── Small overworld NPC sprite (16×24) ────────────────────────────────────
    public static void DrawNPCSmall(float ox, float oy, Color shirt, int frame)
    {
        float legOff = frame==0 ? 0 : 2;
        // Shadow
        R(ox+2, oy+20, 12, 3, new Color(0,0,0,0.22f));
        // Legs
        R(ox+3,  oy+14+legOff, 4, 6, new Color(0.2f,0.3f,0.6f));
        R(ox+9,  oy+14-legOff, 4, 6, new Color(0.2f,0.3f,0.6f));
        // Body
        R(ox+2,  oy+7,  12, 8, shirt);
        // Head
        R(ox+4,  oy+1,   8, 7, SK);
        R(ox+5,  oy+5,   2, 2, DK); R(ox+9, oy+5, 2, 2, DK);
    }

    // ── Small player sprite (16×24) ───────────────────────────────────────────
    public static void DrawPlayerSmall(float ox, float oy, int facing, int frame)
    {
        float legOff = frame==0 ? 0 : 2;
        R(ox+2, oy+20, 12, 3, new Color(0,0,0,0.22f));
        // Legs
        R(ox+3,  oy+14+legOff, 4, 6, BLU);
        R(ox+9,  oy+14-legOff, 4, 6, BLU);
        // Body
        R(ox+2,  oy+7,  12, 8, RED);
        // Arms
        R(ox,    oy+8,   3, 6, SK); R(ox+13, oy+8, 3, 6, SK);
        // Head
        R(ox+4,  oy+1,   8, 7, SK);
        // Hat
        R(ox+3,  oy+1,  10, 3, RED);
        R(ox+4,  oy,     8, 2, RDL);
        // Eyes (direction-based)
        if (facing == 0) { // down
            R(ox+5, oy+4, 2, 2, DK); R(ox+9, oy+4, 2, 2, DK);
        } else if (facing == 1) { // up
            R(ox+5, oy+3, 2, 1, DK); R(ox+9, oy+3, 2, 1, DK);
        } else { // side
            int ex = facing == 2 ? 4 : 10;
            R(ox+ex, oy+4, 2, 2, DK);
        }
    }
}
