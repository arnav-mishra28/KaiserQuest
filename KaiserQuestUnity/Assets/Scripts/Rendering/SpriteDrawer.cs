// SpriteDrawer.cs — Pixel Art Sprites (Gen 1/2 Pokemon style)
using UnityEngine;

public static class SpriteDrawer
{
    static readonly Color DK  = PixelRenderer.COL_BLACK;
    static readonly Color SKN = new Color(0.941f,0.784f,0.533f);
    static readonly Color RED = new Color(0.753f,0.063f,0.094f);
    static readonly Color RDL = new Color(0.878f,0.125f,0.125f);
    static readonly Color BLU = new Color(0.094f,0.157f,0.627f);
    static readonly Color GLD = new Color(1.000f,0.843f,0.000f);

    // ── Shared: draw rect or border ───────────────────────────────────────────
    static void PR(float x,float y,float w,float h,Color c,bool border=false)
    {
        if(border) PixelRenderer.DrawBorder(x,y,w,h,c,1f);
        else       PixelRenderer.DrawRect(x,y,w,h,c);
    }

    // ── Player back view ──────────────────────────────────────────────────────
    public static void DrawPlayerBack(float ox,float oy,int frame,int facing)
    {
        float lo=(frame==0)?-3f:3f, ro=(frame==0)?3f:-3f;
        // R takes ox/oy offset + 5 required + 1 optional
        void R(float x,float y,float w,float h,Color c,bool b=false)=>PR(ox+x,oy+y,w,h,c,b);

        R(4,44,24,5,new Color(0,0,0,0.22f));
        R(5+lo,38,9,5,DK); R(6+lo,39,7,4,new Color(0.16f,0.16f,0.16f));
        R(18+ro,38,9,5,DK); R(19+ro,39,7,4,new Color(0.16f,0.16f,0.16f));
        R(6, 26,9,14,BLU); R(6, 26,9,14,DK,true);
        R(17,26,9,14,BLU); R(17,26,9,14,DK,true);
        R(7, 26,16,4,new Color(0.14f,0.23f,0.66f));
        R(4, 25,24,3,new Color(0.31f,0.16f,0.03f));
        R(13,25,5,3,GLD);
        R(4, 14,24,10,RED);
        R(4, 14,24,3,RDL);
        R(4, 19,24,5,new Color(0.61f,0.05f,0.06f));
        R(4, 14,24,10,DK,true);
        R(12,14,8,4,new Color(0.91f,0.91f,0.91f));
        for(float ax=0;ax<=27;ax+=27){R(ax,15,5,11,SKN);R(ax,15,5,11,DK,true);}
        R(13,10,6,5,SKN);
        R(7, 0,18,11,SKN); R(7,0,18,11,DK,true);
        R(8, 0,16,4,new Color(0.98f,0.85f,0.72f));
        R(7, 6,18,5,new Color(0.847f,0.624f,0.533f));
        R(5, 3,22,3,RED); R(5,3,22,3,DK,true);
        R(6, 0,20,5,RED); R(6,0,20,5,DK,true);
        R(7, 0,16,2,RDL);
        R(14,1,5,3,GLD);
        switch(facing){
            case 0: R(10,6,4,3,DK);R(18,6,4,3,DK);R(11,6,2,2,new Color(1,1,1,.7f));R(19,6,2,2,new Color(1,1,1,.7f));break;
            case 2: R(9,6,4,3,DK);R(10,6,2,2,new Color(1,1,1,.65f));break;
            case 3: R(19,6,4,3,DK);R(20,6,2,2,new Color(1,1,1,.65f));break;
            default: R(10,6,4,3,DK);R(18,6,4,3,DK);break;
        }
    }

    // ── Player battle (1.8× scale, back view) ─────────────────────────────────
    public static void DrawPlayerBattle(float ox,float oy)
    {
        const float S=1.8f;
        void Rb(float x,float y,float w,float h,Color c,bool b=false)=>PR(ox+x*S,oy+y*S,w*S,h*S,c,b);

        Rb(4,44,26,6,new Color(0,0,0,.22f));
        Rb(5,36,10,8,BLU);Rb(5,36,10,8,DK,true);
        Rb(20,36,10,8,BLU);Rb(20,36,10,8,DK,true);
        Rb(4,20,26,18,RED);Rb(4,20,26,5,RDL);Rb(4,20,26,18,DK,true);
        for(float ax=0;ax<=29;ax+=29){Rb(ax,21,5,14,SKN);Rb(ax,21,5,14,DK,true);}
        Rb(9,6,16,16,SKN);Rb(9,6,16,16,DK,true);
        Rb(7,6,20,6,RED);Rb(6,9,22,5,RED);Rb(7,6,20,6,DK,true);
        Rb(14,7,5,4,GLD);
        Rb(11,13,3,3,DK);Rb(18,13,3,3,DK);
        Rb(12,13,1,2,new Color(1,1,1,.65f));Rb(19,13,1,2,new Color(1,1,1,.65f));
    }

    // ── NPC (world) ───────────────────────────────────────────────────────────
    public static void DrawNPC(float ox,float oy,Color shirt,bool isTeacher=false,bool isDuel=false)
    {
        void Rn(float x,float y,float w,float h,Color c,bool b=false)=>PR(ox+x,oy+y,w,h,c,b);

        Rn(6,27,20,4,new Color(0,0,0,.22f));
        Rn(7,24,7,5,DK);Rn(18,24,7,5,DK);
        Rn(8,15,7,11,new Color(.16f,.28f,.56f));Rn(17,15,7,11,new Color(.16f,.28f,.56f));
        Rn(5,8,22,9,shirt);
        float sr=Mathf.Min(shirt.r*1.2f,1f),sg=Mathf.Min(shirt.g*1.2f,1f),sb=Mathf.Min(shirt.b*1.2f,1f);
        Rn(5,8,22,3,new Color(sr,sg,sb,1f));
        Rn(5,8,22,9,DK,true);
        for(float ax=1;ax<=26;ax+=25){Rn(ax,9,5,9,SKN);Rn(ax,9,5,9,DK,true);}
        Rn(8,1,16,10,SKN);Rn(8,1,16,10,DK,true);Rn(9,1,14,4,new Color(.98f,.85f,.72f));
        Rn(8,1,16,4,new Color(.28f,.16f,.03f));
        Rn(11,6,4,3,DK);Rn(18,6,4,3,DK);
        Rn(12,6,2,2,new Color(1,1,1,.7f));Rn(19,6,2,2,new Color(1,1,1,.7f));
        if(isTeacher){
            Rn(11,-9,10,9,GLD);Rn(11,-9,10,9,DK,true);
            PixelRenderer.DrawString(ox+14,oy-8,"?",10,DK);
        } else if(isDuel){
            Rn(11,-9,10,9,PixelRenderer.COL_HP_R);Rn(11,-9,10,9,DK,true);
            PixelRenderer.DrawString(ox+13,oy-8,"VS",8,Color.white);
        }
    }

    // ── Gym leader (battle front) ─────────────────────────────────────────────
    public static void DrawLeaderBattle(float ox,float oy,Color coat,float time)
    {
        float bob=Mathf.Sin(time*1.6f)*2f; oy+=bob;
        float pulse=0.5f+0.5f*Mathf.Sin(time*2.5f);
        void Rl(float x,float y,float w,float h,Color c,bool b=false)=>PR(ox+x,oy+y,w,h,c,b);

        PixelRenderer.DrawRect(ox+2,oy+2,56,68,new Color(coat.r,coat.g,coat.b,.12f*pulse));
        Rl(5,54,9,5,DK);Rl(22,54,9,5,DK);
        Rl(6,36,8,18,new Color(.16f,.16f,.38f));Rl(6,36,8,18,DK,true);
        Rl(21,36,8,18,new Color(.16f,.16f,.38f));Rl(21,36,8,18,DK,true);
        Rl(4,18,28,20,coat);Rl(4,18,28,6,new Color(1,1,1,.25f));Rl(4,18,28,20,DK,true);
        Rl(13,20,10,18,new Color(.91f,.91f,.94f));Rl(16,22,4,16,coat);
        for(float ax=0;ax<=31;ax+=31){Rl(ax,19,5,14,SKN);Rl(ax,19,5,14,DK,true);}
        Rl(9,6,18,14,SKN);Rl(9,6,18,14,DK,true);Rl(10,6,16,5,new Color(.98f,.85f,.72f));
        Rl(9,6,18,5,new Color(.56f,.56f,.63f));
        Rl(10,12,7,5,DK,true);Rl(21,12,7,5,DK,true);Rl(17,14,4,1,DK);
        Rl(12,13,3,3,new Color(.53f,.78f,1f));Rl(23,13,3,3,new Color(.53f,.78f,1f));
        for(int i=0;i<3;i++){
            float angle=time*1.5f+i*2.094f;
            float rx=ox+19+Mathf.Cos(angle)*22f, ry=oy+28+Mathf.Sin(angle)*14f;
            PixelRenderer.DrawRect(rx,ry,5,5,new Color(coat.r,coat.g,coat.b,.6f+.4f*Mathf.Sin(time*2+i)));
        }
    }

    // ── Tile sprites ──────────────────────────────────────────────────────────
    public static void DrawGrassTile(float px,float py,int ts,Color baseCol,bool checker,bool flower,float time)
    {
        Color g2=new Color(baseCol.r*.88f,baseCol.g*.88f,baseCol.b*.88f);
        PixelRenderer.DrawRect(px,py,ts,ts,baseCol);
        for(int dy=0;dy<ts;dy+=4)
        for(int dx=0;dx<ts;dx+=4)
            if(((dx/4+dy/4)%2)==0) PixelRenderer.DrawRect(px+dx,py+dy,4,4,g2);
        if(flower){float g=.6f+.4f*Mathf.Sin(time*3f);PixelRenderer.DrawRect(px+10,py+18,4,4,new Color(.97f,.50f,.63f,g));}
    }

    public static void DrawTreeTile(float px,float py,int ts)
    {
        Color t1=new Color(.10f,.25f,.06f),t2=new Color(.16f,.41f,.10f),
              t3=new Color(.25f,.63f,.16f),t4=new Color(.44f,.78f,.25f),tk=new Color(.42f,.25f,.06f);
        PixelRenderer.DrawRect(px,py,ts,ts,t1);
        PixelRenderer.DrawRect(px+1,py+14,14,10,t1);PixelRenderer.DrawRect(px+2,py+10,12,10,t2);
        PixelRenderer.DrawRect(px+4,py+6,8,10,t3);PixelRenderer.DrawRect(px+5,py+6,6,4,t4);
        PixelRenderer.DrawRect(px+6,py+4,4,4,new Color(1,1,1,.12f));
        PixelRenderer.DrawRect(px+11,py+22,10,8,tk);
        PixelRenderer.DrawBorder(px,py,ts,ts,PixelRenderer.COL_BLACK,1f);
    }

    public static void DrawHouseTile(float px,float py,int ts,Color roofCol)
    {
        Color wall=new Color(.78f,.66f,.51f);
        PixelRenderer.DrawRect(px,py,ts,ts,wall);
        PixelRenderer.DrawRect(px,py,ts,10,new Color(roofCol.r*0.85f,roofCol.g*0.85f,roofCol.b*0.85f));PixelRenderer.DrawRect(px,py+4,ts,7,roofCol);
        PixelRenderer.DrawRect(px+2,py+9,ts-4,3,new Color(Mathf.Min(roofCol.r*1.1f,1),Mathf.Min(roofCol.g*1.1f,1),Mathf.Min(roofCol.b*1.1f,1)));
        PixelRenderer.DrawRect(px+ts-5,py+10,5,ts-10,new Color(wall.r*.85f,wall.g*.85f,wall.b*.85f));
        PixelRenderer.DrawRect(px+6,py+12,20,13,new Color(.53f,.80f,1f));
        PixelRenderer.DrawBorder(px+6,py+12,20,13,PixelRenderer.COL_BLACK,1.5f);
        PixelRenderer.DrawRect(px+15,py+12,2,13,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(px+6,py+17,20,2,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(px+22,py,5,10,new Color(roofCol.r*.85f,roofCol.g*.85f,roofCol.b*.85f));
        PixelRenderer.DrawBorder(px,py,ts,ts,PixelRenderer.COL_BLACK,1f);
    }

    public static void DrawGymWall(float px,float py,int ts,Color sc,float time)
    {
        PixelRenderer.DrawRect(px,py,ts,ts,new Color(sc.r*0.85f,sc.g*0.85f,sc.b*0.85f));
        PixelRenderer.DrawRect(px,py,ts,8,new Color(sc.r,Mathf.Min(sc.g*1.1f,1),Mathf.Min(sc.b*1.1f,1)));
        PixelRenderer.DrawRect(px+4,py+8,2,ts-8,new Color(sc.r,sc.g,sc.b,.5f));
        PixelRenderer.DrawRect(px+ts-6,py+5,2,ts-5,new Color(sc.r,sc.g,sc.b,.5f));
        float glow=.4f+.35f*Mathf.Sin(time*2.5f);
        PixelRenderer.DrawRect(px+4,py+ts-3,ts-8,2,new Color(sc.r,sc.g,sc.b,glow));
        PixelRenderer.DrawBorder(px,py,ts,ts,PixelRenderer.COL_BLACK,1f);
    }

    public static void DrawGymDoor(float px,float py,int ts,Color sc,float time)
    {
        PixelRenderer.DrawRect(px,py,ts,ts,new Color(sc.r*0.85f,sc.g*0.85f,sc.b*0.85f));
        PixelRenderer.DrawRect(px+4,py+4,24,28,new Color(Mathf.Min(sc.r*1.1f,1),Mathf.Min(sc.g*1.1f,1),Mathf.Min(sc.b*1.1f,1)));
        PixelRenderer.DrawBorder(px+4,py+4,24,28,new Color(sc.r*0.85f,sc.g*0.85f,sc.b*0.85f),2f);
        PixelRenderer.DrawRect(px+6,py+5,6,20,new Color(1,1,1,.22f));
        float glow=.6f+.4f*Mathf.Sin(time*3f);
        PixelRenderer.DrawRect(px+8,py+1,16,4,new Color(sc.r,sc.g,sc.b,glow));
        PixelRenderer.DrawRect(px+14,py+17,4,4,Color.white);
        PixelRenderer.DrawBorder(px,py,ts,ts,PixelRenderer.COL_BLACK,1f);
    }

    public static void DrawPathTile(float px,float py,int ts,bool checker)
    {
        Color p1=new Color(.75f,.69f,.48f),p2=new Color(.78f,.73f,.53f);
        PixelRenderer.DrawRect(px,py,ts,ts,checker?p1:p2);
        PixelRenderer.DrawRect(px+1,py+1,14,14,new Color(0,0,0,.06f));
        PixelRenderer.DrawRect(px+17,py+1,14,14,new Color(0,0,0,.06f));
        PixelRenderer.DrawRect(px+9,py+17,14,14,new Color(0,0,0,.06f));
    }

    public static void DrawWaterTile(float px,float py,int ts,float time,int c,int r)
    {
        float wv=.4f+.6f*Mathf.Sin(time*2f+(c+r)*.5f);
        PixelRenderer.DrawRect(px,py,ts,ts,new Color(.08f,.25f,.75f));
        foreach(int wy in new[]{5,12,19,26})
            PixelRenderer.DrawRect(px+2,py+wy,ts-4,2,new Color(.3f,.6f,1f,wv*.45f));
    }

    public static void DrawItemSparkle(float px,float py,Color col,float time)
    {
        float g=.5f+.5f*Mathf.Sin(time*4f), g2=.5f+.5f*Mathf.Sin(time*4f+Mathf.PI);
        PixelRenderer.DrawRect(px+9,py+8,14,15,new Color(col.r,col.g,col.b,g));
        PixelRenderer.DrawRect(px+12,py+11,8,10,new Color(1,1,1,g*.6f));
        PixelRenderer.DrawBorder(px+9,py+8,14,15,PixelRenderer.COL_BLACK,1f);
        PixelRenderer.DrawRect(px+14,py+2,4,7,new Color(1,1,1,g));
        PixelRenderer.DrawRect(px+10,py+5,12,3,new Color(1,1,1,g2*.5f));
    }
}
