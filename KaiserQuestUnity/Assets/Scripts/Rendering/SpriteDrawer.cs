// SpriteDrawer.cs — Pixel Art Sprite Drawing (Gen 1/2 Pokemon style)
// All characters drawn procedurally - no external sprite files needed
using UnityEngine;

public static class SpriteDrawer
{
    static readonly Color DK  = PixelRenderer.COL_BLACK;
    static readonly Color SKN = new Color(0.941f, 0.784f, 0.533f);
    static readonly Color RED = new Color(0.753f, 0.063f, 0.094f);
    static readonly Color RDL = new Color(0.878f, 0.125f, 0.125f);
    static readonly Color BLU = new Color(0.094f, 0.157f, 0.627f);
    static readonly Color GLD = new Color(1.000f, 0.843f, 0.000f);

    // ── Player sprite (back view, Gen 1 RED style) ────────────────────────────
    public static void DrawPlayerBack(float ox, float oy, int frame, int facing)
    {
        float lo = (frame == 0) ? -3 : 3;
        float ro = (frame == 0) ?  3 : -3;
        float s = 1f;

        void R(float x, float y, float w, float h, Color c) =>
            PixelRenderer.DrawRect(ox + x*s, oy + y*s, w*s, h*s, c);

        // Shadow
        R(4,  44, 24, 5,  new Color(0,0,0,0.22f));
        // Shoes
        R(5+lo, 38,  9, 5, DK); R(6+lo, 39,  7, 4, new Color(0.16f,0.16f,0.16f));
        R(18+ro,38,  9, 5, DK); R(19+ro,39,  7, 4, new Color(0.16f,0.16f,0.16f));
        // Pants
        R(6,  26, 9, 14, BLU); R(6, 26, 9, 14, DK, true);
        R(17, 26, 9, 14, BLU); R(17,26, 9, 14, DK, true);
        R(7,  26,16,  4, new Color(0.14f,0.23f,0.66f));
        // Belt
        R(4,  25,24,  3, new Color(0.31f,0.16f,0.03f));
        R(13, 25, 5,  3, GLD);
        // Shirt (Red's iconic red)
        R(4,  14,24, 10, RED);
        R(4,  14,24,  3, RDL);
        R(4,  19,24,  5, new Color(0.61f,0.05f,0.06f));
        R(4,  14,24, 10, DK, true);
        R(12, 14, 8,  4, new Color(0.91f,0.91f,0.91f));
        // Arms
        for(float ax=0;ax<=27;ax+=27){R(ax,15,5,11,SKN);R(ax,15,5,11,DK,true);}
        // Neck
        R(13, 10, 6, 5, SKN);
        // Head
        R(7,  0, 18,11, SKN); R(7,0,18,11, DK, true);
        R(8,  0, 16, 4, new Color(0.98f,0.85f,0.72f));
        R(7,  6, 18, 5, new Color(0.847f, 0.624f, 0.533f));
        // Cap
        R(5,  3, 22, 3, RED); R(5,3,22,3, DK, true);
        R(6,  0, 20, 5, RED); R(6,0,20,5, DK, true);
        R(7,  0, 16, 2, RDL);
        R(14, 1,  5, 3, GLD);
        // Eyes (facing dependent)
        if (facing == 0) {
            R(10,6,4,3,DK); R(18,6,4,3,DK);
            R(11,6,2,2,new Color(1,1,1,0.7f)); R(19,6,2,2,new Color(1,1,1,0.7f));
        } else if (facing == 2) { R(9,6,4,3,DK); R(10,6,2,2,new Color(1,1,1,0.65f)); }
        else if (facing == 3)   { R(19,6,4,3,DK); R(20,6,2,2,new Color(1,1,1,0.65f)); }
        else { R(10,6,4,3,DK); R(18,6,4,3,DK); }
    }

    static void R(float ox, float oy, float x, float y, float w, float h, Color c, bool border=false)
    {
        if (border) PixelRenderer.DrawBorder(ox+x, oy+y, w, h, c, 1f);
        else PixelRenderer.DrawRect(ox+x, oy+y, w, h, c);
    }

    // ── Player sprite (front, large, for battle) ──────────────────────────────
    public static void DrawPlayerBattle(float ox, float oy)
    {
        // Larger battle back sprite (1.8× scale)
        float s = 1.8f;
        void Rb(float x, float y, float w, float h, Color c) =>
            PixelRenderer.DrawRect(ox + x*s, oy + y*s, w*s, h*s, c);

        Rb(4,44,26,6,new Color(0,0,0,0.22f));
        Rb(5,36,10,8,BLU);Rb(5,36,10,8,DK,true);Rb(20,36,10,8,BLU);Rb(20,36,10,8,DK,true);
        Rb(4,20,26,18,RED);Rb(4,20,26,5,RDL);Rb(4,20,26,18,DK,true);
        for(float ax=0;ax<=29;ax+=29){Rb(ax,21,5,14,SKN);Rb(ax,21,5,14,DK,true);}
        Rb(9,6,16,16,SKN);Rb(9,6,16,16,DK,true);
        Rb(7,6,20,6,RED);Rb(6,9,22,5,RED);Rb(7,6,20,6,DK,true);Rb(14,7,5,4,GLD);
        Rb(11,13,3,3,DK);Rb(18,13,3,3,DK);
        Rb(12,13,1,2,new Color(1,1,1,0.65f));Rb(19,13,1,2,new Color(1,1,1,0.65f));
    }

    // ── NPC sprite (front view) ────────────────────────────────────────────────
    public static void DrawNPC(float ox, float oy, Color shirtColor, bool isTeacher=false, bool isDuel=false)
    {
        void Rn(float x, float y, float w, float h, Color c) =>
            PixelRenderer.DrawRect(ox+x, oy+y, w, h, c);

        Rn(6,27,20,4,new Color(0,0,0,0.22f));
        Rn(7,24,7,5,DK); Rn(18,24,7,5,DK);
        Rn(8,15,7,11,new Color(0.16f,0.28f,0.56f));
        Rn(17,15,7,11,new Color(0.16f,0.28f,0.56f));
        Rn(5,8,22,9,shirtColor);
        Rn(5,8,22,3,new Color(shirtColor.r*1.2f,shirtColor.g*1.2f,shirtColor.b*1.2f,1));
        Rn(5,8,22,9,DK,true);
        for(float ax=1;ax<=26;ax+=25){Rn(ax,9,5,9,SKN);Rn(ax,9,5,9,DK,true);}
        Rn(8,1,16,10,SKN);Rn(8,1,16,10,DK,true);Rn(9,1,14,4,new Color(0.98f,0.85f,0.72f));
        Rn(8,1,16,4,new Color(0.28f,0.16f,0.03f));
        Rn(11,6,4,3,DK);Rn(18,6,4,3,DK);
        Rn(12,6,2,2,new Color(1,1,1,0.7f));Rn(19,6,2,2,new Color(1,1,1,0.7f));
        // Badge
        if (isTeacher) {
            Rn(11,-9,10,9,GLD);Rn(11,-9,10,9,DK,true);
            PixelRenderer.DrawString(ox+14, oy-8, "?", 10, DK);
        } else if (isDuel) {
            Rn(11,-9,10,9,PixelRenderer.COL_HP_R);Rn(11,-9,10,9,DK,true);
            PixelRenderer.DrawString(ox+13, oy-8, "VS", 8, Color.white);
        }
    }

    // ── Enemy/Leader sprite (front view, larger, for battle) ──────────────────
    public static void DrawLeaderBattle(float ox, float oy, Color coat, float time)
    {
        float bob = Mathf.Sin(time * 1.6f) * 2f;
        oy += bob;
        float pulse = 0.5f + 0.5f * Mathf.Sin(time * 2.5f);

        void Rl(float x, float y, float w, float h, Color c) =>
            PixelRenderer.DrawRect(ox+x, oy+y, w, h, c);
        void Rlb(float x, float y, float w, float h, Color c) =>
            PixelRenderer.DrawBorder(ox+x, oy+y, w, h, c, 1f);

        // Aura
        PixelRenderer.DrawRect(ox+2, oy+2, 56, 68, new Color(coat.r,coat.g,coat.b,0.12f*pulse));
        // Shoes
        Rl(5,54,9,5,DK); Rl(22,54,9,5,DK);
        // Legs
        Rl(6,36,8,18,new Color(0.16f,0.16f,0.38f)); Rlb(6,36,8,18,DK);
        Rl(21,36,8,18,new Color(0.16f,0.16f,0.38f)); Rlb(21,36,8,18,DK);
        // Lab coat body
        Rl(4,18,28,20,coat.gamma); Rl(4,18,28,6,new Color(1,1,1,0.25f)); Rlb(4,18,28,20,DK);
        Rl(13,20,10,18,new Color(0.91f,0.91f,0.94f)); Rl(16,22,4,16,coat);
        // Arms
        for(float ax=0;ax<=31;ax+=31){Rl(ax,19,5,14,SKN);Rlb(ax,19,5,14,DK);}
        // Head
        Rl(9,6,18,14,SKN); Rlb(9,6,18,14,DK); Rl(10,6,16,5,new Color(0.98f,0.85f,0.72f));
        Rl(9,6,18,5,new Color(0.56f,0.56f,0.63f));
        // Glasses
        Rlb(10,12,7,5,DK); Rlb(21,12,7,5,DK); Rl(17,14,4,1,DK);
        Rl(12,13,3,3,new Color(0.53f,0.78f,1f)); Rl(23,13,3,3,new Color(0.53f,0.78f,1f));
        // Orbiting orbs
        for (int i=0;i<3;i++) {
            float angle = time*1.5f + i*2.094f;
            float rx = ox+19 + Mathf.Cos(angle)*22;
            float ry = oy+28 + Mathf.Sin(angle)*14;
            PixelRenderer.DrawRect(rx, ry, 5, 5, new Color(coat.r,coat.g,coat.b,0.6f+0.4f*Mathf.Sin(time*2+i)));
        }
    }

    // ── Tile sprites ───────────────────────────────────────────────────────────
    public static void DrawGrassTile(float px, float py, int ts, Color baseCol, bool checker, bool hasFlower, float time)
    {
        Color g1 = baseCol;
        Color g2 = new Color(baseCol.r*0.88f, baseCol.g*0.88f, baseCol.b*0.88f);
        PixelRenderer.DrawRect(px, py, ts, ts, g1);
        for (int dy=0;dy<ts;dy+=4)
        for (int dx=0;dx<ts;dx+=4)
            if (((dx/4+dy/4)%2)==0) PixelRenderer.DrawRect(px+dx,py+dy,4,4,g2);
        if (hasFlower) {
            float glow = 0.6f+0.4f*Mathf.Sin(time*3f);
            PixelRenderer.DrawRect(px+10,py+18,4,4,new Color(0.97f,0.50f,0.63f,glow));
        }
    }

    public static void DrawTreeTile(float px, float py, int ts)
    {
        Color trl1=new Color(0.10f,0.25f,0.06f), trl2=new Color(0.16f,0.41f,0.10f);
        Color trl3=new Color(0.25f,0.63f,0.16f), trl4=new Color(0.44f,0.78f,0.25f);
        Color trk =new Color(0.42f,0.25f,0.06f);
        PixelRenderer.DrawRect(px,   py,   ts, ts, trl1);
        PixelRenderer.DrawRect(px+1, py+14,14, 10, trl1);
        PixelRenderer.DrawRect(px+2, py+10,12, 10, trl2);
        PixelRenderer.DrawRect(px+4, py+6,  8, 10, trl3);
        PixelRenderer.DrawRect(px+5, py+6,  6,  4, trl4);
        PixelRenderer.DrawRect(px+6, py+4,  4,  4, new Color(1,1,1,0.12f));
        PixelRenderer.DrawRect(px+11,py+22, 10,  8, trk);
        PixelRenderer.DrawBorder(px, py, ts, ts, PixelRenderer.COL_BLACK, 1f);
    }

    public static void DrawHouseTile(float px, float py, int ts, Color roofColor)
    {
        Color wall=new Color(0.78f,0.66f,0.51f);
        PixelRenderer.DrawRect(px,   py,    ts, ts, wall);
        PixelRenderer.DrawRect(px,   py,    ts, 10, roofColor.gamma);
        PixelRenderer.DrawRect(px,   py+4,  ts,  7, roofColor);
        PixelRenderer.DrawRect(px+2, py+9,  ts-4,3, new Color(roofColor.r*1.1f,roofColor.g*1.1f,roofColor.b*1.1f));
        PixelRenderer.DrawRect(px+ts-5,py+10,5,ts-10,new Color(wall.r*0.85f,wall.g*0.85f,wall.b*0.85f));
        PixelRenderer.DrawRect(px+6,py+12,20,13,new Color(0.53f,0.80f,1f));
        PixelRenderer.DrawBorder(px+6,py+12,20,13,PixelRenderer.COL_BLACK,1.5f);
        PixelRenderer.DrawRect(px+15,py+12,2,13,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(px+6,py+17,20,2,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(px+22,py,5,10,new Color(roofColor.r*0.85f,roofColor.g*0.85f,roofColor.b*0.85f));
        PixelRenderer.DrawBorder(px,py,ts,ts,PixelRenderer.COL_BLACK,1f);
    }

    public static void DrawGymWall(float px, float py, int ts, Color gymColor, float time)
    {
        PixelRenderer.DrawRect(px,   py,   ts, ts, gymColor.gamma);
        PixelRenderer.DrawRect(px,   py,   ts,  8, new Color(gymColor.r,gymColor.g*1.1f,gymColor.b*1.1f));
        PixelRenderer.DrawRect(px+4, py+8,  2, ts-8, new Color(gymColor.r,gymColor.g,gymColor.b,0.5f));
        PixelRenderer.DrawRect(px+ts-6,py+5,2, ts-5, new Color(gymColor.r,gymColor.g,gymColor.b,0.5f));
        float glow = 0.4f + 0.35f * Mathf.Sin(time*2.5f);
        PixelRenderer.DrawRect(px+4, py+ts-3, ts-8, 2, new Color(gymColor.r,gymColor.g,gymColor.b,glow));
        PixelRenderer.DrawBorder(px, py, ts, ts, PixelRenderer.COL_BLACK, 1f);
    }

    public static void DrawGymDoor(float px, float py, int ts, Color gymColor, float time)
    {
        PixelRenderer.DrawRect(px,   py,   ts, ts, gymColor.gamma);
        PixelRenderer.DrawRect(px+4, py+4, 24, 28, new Color(gymColor.r*1.1f,gymColor.g*1.1f,gymColor.b*1.1f));
        PixelRenderer.DrawBorder(px+4,py+4,24,28, gymColor.gamma, 2f);
        PixelRenderer.DrawRect(px+6, py+5, 6, 20, new Color(1,1,1,0.22f));
        float glow = 0.6f+0.4f*Mathf.Sin(time*3f);
        PixelRenderer.DrawRect(px+8, py+1, 16, 4, new Color(gymColor.r,gymColor.g,gymColor.b,glow));
        PixelRenderer.DrawRect(px+14,py+17,4,4,Color.white);
        PixelRenderer.DrawBorder(px, py, ts, ts, PixelRenderer.COL_BLACK, 1f);
    }

    public static void DrawPathTile(float px, float py, int ts, bool checker)
    {
        Color p1=new Color(0.75f,0.69f,0.48f), p2=new Color(0.78f,0.73f,0.53f);
        PixelRenderer.DrawRect(px,py,ts,ts,checker?p1:p2);
        PixelRenderer.DrawRect(px+1,py+1,14,14,new Color(0,0,0,0.06f));
        PixelRenderer.DrawRect(px+17,py+1,14,14,new Color(0,0,0,0.06f));
        PixelRenderer.DrawRect(px+9,py+17,14,14,new Color(0,0,0,0.06f));
    }

    public static void DrawWaterTile(float px, float py, int ts, float time, int c, int r)
    {
        float wv = 0.4f + 0.6f * Mathf.Sin(time*2f+(c+r)*0.5f);
        PixelRenderer.DrawRect(px,py,ts,ts,new Color(0.08f,0.25f,0.75f));
        int[] rows={5,12,19,26};
        foreach(int wy in rows)
            PixelRenderer.DrawRect(px+2,py+wy,ts-4,2,new Color(0.3f,0.6f,1f,wv*0.45f));
    }

    public static void DrawItemSparkle(float px, float py, Color col, float time)
    {
        float g  = 0.5f+0.5f*Mathf.Sin(time*4f);
        float g2 = 0.5f+0.5f*Mathf.Sin(time*4f+Mathf.PI);
        PixelRenderer.DrawRect(px+9, py+8, 14,15, new Color(col.r,col.g,col.b,g));
        PixelRenderer.DrawRect(px+12,py+11, 8,10, new Color(1,1,1,g*0.6f));
        PixelRenderer.DrawBorder(px+9,py+8,14,15, PixelRenderer.COL_BLACK, 1f);
        PixelRenderer.DrawRect(px+14,py+2,  4, 7, new Color(1,1,1,g));
        PixelRenderer.DrawRect(px+10,py+5, 12, 3, new Color(1,1,1,g2*0.5f));
    }
}
