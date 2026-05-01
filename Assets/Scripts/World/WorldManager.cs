// WorldManager.cs  –  Tile world, NPC logic, OnGUI world renderer
// Pure 2D with tile-based movement. Camera follows player.
// Sprites drawn with SpriteDrawer pixel art.
using UnityEngine;
using System.Collections.Generic;

public class WorldManager : MonoBehaviour
{
    public static WorldManager Instance { get; private set; }
    void Awake() { Instance = this; }

    // ── Events ────────────────────────────────────────────────────────────────
    public event System.Action                       OnGymEntered;
    public event System.Action<GymLeaderData,float>  OnDuelTriggered;

    // ── Map constants ─────────────────────────────────────────────────────────
    public const int COLS = 20, ROWS = 15, TS = 16;

    /*  Tile IDs:
        0=grass  1=tree  2=path  3=water  4=sand  5=gym_wall  6=gym_door
        7=house  8=fence 9=sign  10=tall_grass  11=item_spot  12=flower  */
    public static readonly int[,] MAP = {
        {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
        {1,0,0,0,0,0,0,12,0,0,0,0,0,0,0,0,0,12,0,1},
        {1,0,7,7,0,0,0,0,0,0,0,7,7,0,5,5,5,0,0,1},
        {1,0,7,7,0,12,0,0,10,10,0,7,7,0,5,6,5,0,0,1},
        {1,0,0,0,8,8,8,8,0,0,8,8,8,8,0,0,0,0,0,1},
        {1,0,0,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0,0,1},
        {1,12,0,2,0,0,0,0,0,0,0,0,0,0,0,2,0,12,0,1},
        {1,0,0,2,0,9,0,0,11,0,0,9,0,0,0,2,0,0,0,1},
        {1,0,0,2,0,0,10,10,10,10,0,0,0,0,0,2,0,0,0,1},
        {1,1,0,2,2,2,2,2,2,2,2,2,2,2,2,2,0,0,1,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,0,12,0,3,3,3,3,3,3,3,0,0,0,0,0,12,0,0,1},
        {1,0,0,0,3,3,3,3,3,3,3,0,0,0,0,0,0,0,0,1},
        {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
        {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
    };

    static readonly Vector2Int GYM_DOOR_POS = new(15, 3);
    static readonly Vector2Int ITEM_POS     = new(8,  7);

    // ── NPC definitions ───────────────────────────────────────────────────────
    struct NPCDef {
        public Vector2Int pos;
        public Color shirt;
        public string type;   // "teacher" | "duel" | "npc"
        public string id;
        public string label;
        public int xp;
        public float duelAcc;
        public string[] lines;
        public string[] lesson;
    }

    static readonly NPCDef[] NPCS_MATH_ALGEBRA = {
        new(){pos=new(11,2),shirt=new Color(0.12f,0.38f,0.82f),type="teacher",id="t1",label="Prof. Varius",xp=75,
              lesson=new[]{"LESSON: Variables","A variable is a letter standing for an unknown.","x+2=5  →  x=3.  So x=3!","+75 XP!"}},
        new(){pos=new(3,8),shirt=new Color(0.06f,0.63f,0.38f),type="teacher",id="t2",label="Scholar Equa",xp=75,
              lesson=new[]{"LESSON: Equations","An equation says two things are equal.","2x+1=7: solve step by step.","Subtract 1 → 2x=6 → x=3.  +75 XP!"}},
        new(){pos=new(16,6),shirt=new Color(0.91f,0.75f,0.19f),type="npc",id="npc1",xp=40,
              lines=new[]{"Welcome to Algebropolis!","The gym is to the north-east.","You need Level 5 to enter!"}},
        new(){pos=new(11,7),shirt=new Color(0.19f,0.63f,0.19f),type="npc",id="npc2",xp=40,
              lines=new[]{"Explore the tall grass for XP!","Talk to teachers first.","Side quests help you level up."}},
        new(){pos=new(6,5),shirt=new Color(0.88f,0.31f,0.06f),type="duel",id="duel1",duelAcc=0.55f,
              lines=new[]{"Hey! Knowledge Duel!","7 questions, 3 lives each.","Are you ready? Face me!"}},
    };

    static readonly NPCDef[] NPCS_LANG_ENGLISH = {
        new(){pos=new(11,2),shirt=new Color(0.75f,0.44f,0.06f),type="teacher",id="le_t1",label="Maestra Nora",xp=75,
              lesson=new[]{"LESSON: Nouns","A noun names a person, place, thing or idea.","'Knight', 'London', 'Freedom' are nouns.","+75 XP!"}},
        new(){pos=new(3,8),shirt=new Color(0.75f,0.25f,0.25f),type="teacher",id="le_t2",label="Scholar Verb",xp=75,
              lesson=new[]{"LESSON: Verbs","A verb expresses an action or a state.","'eat→ate', 'will run' = future tense.","+75 XP!"}},
        new(){pos=new(16,6),shirt=new Color(0.44f,0.69f,0.19f),type="npc",id="le_npc1",xp=40,
              lines=new[]{"Welcome to Linguopolis!","The English gym awaits you!","Level 5 is the entry requirement."}},
        new(){pos=new(6,5),shirt=new Color(0.63f,0.19f,0.75f),type="duel",id="le_duel1",duelAcc=0.52f,
              lines=new[]{"Grammar duel – let's go!","3 lives, 7 questions.","Begin!"}},
    };

    static readonly NPCDef[] NPCS_MUSIC_THEORY = {
        new(){pos=new(11,2),shirt=new Color(0.50f,0.12f,0.75f),type="teacher",id="mt_t1",label="Maestro Clef",xp=75,
              lesson=new[]{"LESSON: Staff & Notes","A staff has 5 lines. Treble clef = higher notes.","Whole=4 beats  Half=2  Quarter=1","+75 XP!"}},
        new(){pos=new(3,8),shirt=new Color(0.75f,0.25f,0.56f),type="teacher",id="mt_t2",label="Scholar Chord",xp=75,
              lesson=new[]{"LESSON: Chords","Major chord = bright/happy sound.","C-E-G = C major triad.","+75 XP!"}},
        new(){pos=new(16,6),shirt=new Color(0.25f,0.56f,0.75f),type="npc",id="mt_npc1",xp=40,
              lines=new[]{"Welcome to Harmonica!","The Music gym is north-east.","Listen for the rhythm!"}},
        new(){pos=new(6,5),shirt=new Color(0.19f,0.44f,0.75f),type="duel",id="mt_duel1",duelAcc=0.58f,
              lines=new[]{"Rhythm duel! 7 questions!","Match my note speed!","Go!"}},
    };

    // ── State ─────────────────────────────────────────────────────────────────
    NPCDef[] _npcs;
    Color    _subjectColor = new(0.12f, 0.38f, 0.82f);
    float    _time;

    // Player visual (smooth sub-tile position in pixels)
    public Vector2 PlayerVisualPos  { get; private set; }
    public int     PlayerFacing     { get; private set; } = 0;
    public bool    PlayerMoving     { get; private set; } = false;
    public int     PlayerFrame      { get; private set; } = 0;

    // Camera offset (top-left world pixel visible)
    Vector2 _camOffset;

    // ── Init ──────────────────────────────────────────────────────────────────
    public void InitWorld(string worldKey)
    {
        var parts = worldKey.Split(':');
        string sub = parts.Length > 0 ? parts[0] : "math";
        string br  = parts.Length > 1 ? parts[1] : "algebra";

        _npcs = (sub, br) switch {
            ("languages","english") => NPCS_LANG_ENGLISH,
            ("music","theory")      => NPCS_MUSIC_THEORY,
            _                       => NPCS_MATH_ALGEBRA,
        };

        _subjectColor = SubjectDB.Subjects.TryGetValue(sub, out var si)
            ? si.color : new Color(0.12f, 0.38f, 0.82f);

        // Clamp player to walkable start pos
        var gp = GameManager.Instance.GridPos;
        gp.x = Mathf.Clamp(gp.x, 1, COLS-2);
        gp.y = Mathf.Clamp(gp.y, 1, ROWS-2);
        if (!IsWalkable(gp)) { gp = new Vector2Int(7, 9); }
        GameManager.Instance.GridPos = gp;
        PlayerVisualPos = new Vector2(gp.x * TS, gp.y * TS);
        UpdateCamera();
    }

    // ── Camera ────────────────────────────────────────────────────────────────
    void UpdateCamera()
    {
        float worldW = COLS * TS, worldH = ROWS * TS;
        float viewW  = PixelRenderer.W, viewH = PixelRenderer.H;
        float cx = PlayerVisualPos.x + TS*0.5f - viewW*0.5f;
        float cy = PlayerVisualPos.y + TS*0.5f - viewH*0.5f;
        cx = Mathf.Clamp(cx, 0, Mathf.Max(0, worldW - viewW));
        cy = Mathf.Clamp(cy, 0, Mathf.Max(0, worldH - viewH));
        _camOffset = new Vector2(cx, cy);
    }

    // ── Movement ──────────────────────────────────────────────────────────────
    static readonly int[] WALKABLE = {0, 2, 4, 10, 11, 12};

    public bool IsWalkable(Vector2Int p)
    {
        if (p.x<1||p.x>=COLS-1||p.y<1||p.y>=ROWS-1) return false;
        int t = MAP[p.y, p.x];
        foreach (int w in WALKABLE) if (t == w) return true;
        return false;
    }

    public bool TryMove(Vector2Int from, Vector2Int dir, out Vector2Int dest)
    {
        dest = from + dir;
        return IsWalkable(dest);
    }

    public void SetPlayerVisualPos(Vector2 vp)
    {
        PlayerVisualPos = vp;
        UpdateCamera();
    }
    public void SetPlayerFacing(int f) => PlayerFacing = f;
    public void SetPlayerMoving(bool m, int frame) { PlayerMoving = m; PlayerFrame = frame; }

    // ── Interaction ───────────────────────────────────────────────────────────
    public void TryInteract(Vector2Int gridPos, int facing)
    {
        var front = gridPos + FacingDir(facing);

        if (front == GYM_DOOR_POS) { TryEnterGym(); return; }

        int tile = (front.x>=0&&front.x<COLS&&front.y>=0&&front.y<ROWS)
                   ? MAP[front.y, front.x] : -1;
        if (tile == 9) { // sign
            DialogBox.Instance?.ShowLines(
                new[]{"[Sign]","The Gym lies to the north.","Talk to Teachers first!"},
                null, DialogBox.Context.World);
            return;
        }

        foreach (var npc in _npcs) {
            if (npc.pos == front) { TalkNPC(npc); return; }
        }
    }

    public void OnPlayerMoved(Vector2Int gp)
    {
        GameManager.Instance.GridPos = gp;

        // Item pickup
        if (gp == ITEM_POS && !GameManager.Instance.HasItem("scroll")) {
            GameManager.Instance.CollectItem("scroll");
            GameManager.Instance.AddXP(200);
            HUD.Instance?.ShowXPGain(200);
            DialogBox.Instance?.ShowLines(
                new[]{"You found a Knowledge Scroll!","'The greatest journey begins with a single question.'","+200 XP!"},
                null, DialogBox.Context.World);
            return;
        }

        // Tall grass XP
        if (MAP[gp.y, gp.x] == 10 && Random.value < 0.35f) {
            int xpGain = Random.Range(8, 18);
            GameManager.Instance.AddXP(xpGain);
            HUD.Instance?.ShowXPGain(xpGain);
        }
    }

    // ── NPC conversation ──────────────────────────────────────────────────────
    void TalkNPC(NPCDef npc)
    {
        if (npc.type == "teacher")      TalkTeacher(npc);
        else if (npc.type == "duel")    TalkDuel(npc);
        else                            TalkNormal(npc);
    }

    void TalkNormal(NPCDef npc)
    {
        var lines = new List<string>(npc.lines);
        if (!GameManager.Instance.HasTalked(npc.id)) {
            GameManager.Instance.MarkTalked(npc.id);
            lines.Add("(+" + npc.xp + " XP!)");
            GameManager.Instance.AddXP(npc.xp);
            HUD.Instance?.ShowXPGain(npc.xp);
        }
        DialogBox.Instance?.ShowLines(lines.ToArray(), null, DialogBox.Context.World);
    }

    void TalkTeacher(NPCDef npc)
    {
        if (GameManager.Instance.HasTalked(npc.id)) {
            DialogBox.Instance?.ShowLines(
                new[]{"You already learned from "+npc.label+"!","Practice those concepts more!"},
                null, DialogBox.Context.World);
            return;
        }
        GameManager.Instance.MarkTalked(npc.id);
        DialogBox.Instance?.ShowLines(npc.lesson, () => {
            GameManager.Instance.AddXP(npc.xp);
            HUD.Instance?.ShowXPGain(npc.xp);
        }, DialogBox.Context.World);
    }

    void TalkDuel(NPCDef npc)
    {
        var opp = new GymLeaderData { name = npc.label ?? npc.id, color = npc.shirt };
        float acc = npc.duelAcc;
        DialogBox.Instance?.ShowLines(npc.lines, () => {
            OnDuelTriggered?.Invoke(opp, acc);
        }, DialogBox.Context.World);
    }

    void TryEnterGym()
    {
        var parts = GameManager.Instance.BranchKey.Split(':');
        if (parts.Length < 2) return;
        string sub = parts[0], br = parts[1];
        int gymNum = GameManager.Instance.Badges.Count + 1;
        if (gymNum > 20) {
            DialogBox.Instance?.ShowLines(new[]{"All 20 gyms cleared!","Silver Mountain awaits!"}, null, DialogBox.Context.World);
            return;
        }
        var leader = SubjectDB.GetGymLeader(sub, br, gymNum);
        if (GameManager.Instance.HasBadge(leader.badgeName)) {
            DialogBox.Instance?.ShowLines(new[]{"You already have "+leader.badgeName+"!","The leader bows."}, null, DialogBox.Context.World);
            return;
        }
        if (!GameManager.Instance.CanChallengeGym(gymNum)) {
            DialogBox.Instance?.ShowLines(new[]{"Gym "+gymNum+" is sealed!","You need Level "+(gymNum*5)+".","Current level: "+GameManager.Instance.Level+".","Talk to Teachers for XP!"}, null, DialogBox.Context.World);
            return;
        }
        bool taughtBy = false;
        foreach (var n in _npcs) if (n.type=="teacher" && GameManager.Instance.HasTalked(n.id)) { taughtBy=true; break; }
        if (!taughtBy) {
            DialogBox.Instance?.ShowLines(new[]{"The gym door is locked!","Talk to a Teacher first!"}, null, DialogBox.Context.World);
            return;
        }
        DialogBox.Instance?.ShowLines(
            new[]{"The gym doors slide open...","You step inside the arena!"},
            () => { OnGymEntered?.Invoke(); }, DialogBox.Context.World);
    }

    // ── World OnGUI ───────────────────────────────────────────────────────────
    public void DrawWorld()
    {
        _time += Time.deltaTime;
        float camX = _camOffset.x, camY = _camOffset.y;

        // ── Tiles ──
        int tileXStart = Mathf.Max(0, Mathf.FloorToInt(camX / TS));
        int tileYStart = Mathf.Max(0, Mathf.FloorToInt(camY / TS));
        int tileXEnd   = Mathf.Min(COLS, tileXStart + PixelRenderer.W/TS + 2);
        int tileYEnd   = Mathf.Min(ROWS, tileYStart + PixelRenderer.H/TS + 2);

        for (int ty = tileYStart; ty < tileYEnd; ty++)
        for (int tx = tileXStart; tx < tileXEnd; tx++) {
            float sx = tx*TS - camX, sy = ty*TS - camY;
            DrawTile(tx, ty, sx, sy);
        }

        // ── NPCs ──
        foreach (var npc in _npcs) {
            float nx = npc.pos.x*TS - camX;
            float ny = npc.pos.y*TS - camY;
            if (nx > -TS && nx < PixelRenderer.W+TS && ny > -TS && ny < PixelRenderer.H+TS) {
                int fr = (int)(_time * 4f) % 2;
                SpriteDrawer.DrawNPCSmall(nx, ny, npc.shirt, fr);
                // "!" bubble for teacher / duel
                if (npc.type == "teacher" || npc.type == "duel") {
                    Color bc = npc.type=="teacher" ? PixelRenderer.COL_GOLD : PixelRenderer.COL_HP_R;
                    PixelRenderer.DrawRect(nx+5, ny-8, 6, 7, PixelRenderer.COL_BLACK);
                    PixelRenderer.DrawRect(nx+6, ny-7, 4, 5, bc);
                    PixelRenderer.DrawRect(nx+7, ny-4, 2, 2, PixelRenderer.COL_WHITE);
                }
            }
        }

        // ── Item sparkle ──
        if (!GameManager.Instance.HasItem("scroll")) {
            float ix = ITEM_POS.x*TS - camX + 4;
            float iy = ITEM_POS.y*TS - camY + 4;
            float pulse = 0.6f + 0.4f*Mathf.Sin(_time*5f);
            PixelRenderer.DrawRect(ix, iy, 8, 8,
                new Color(_subjectColor.r, _subjectColor.g, _subjectColor.b, pulse));
            PixelRenderer.DrawRect(ix+2, iy+2, 4, 4,
                new Color(1,1,1,pulse*0.8f));
        }

        // ── Player ──
        float px = PlayerVisualPos.x - camX;
        float py = PlayerVisualPos.y - camY;
        SpriteDrawer.DrawPlayerSmall(px, py, PlayerFacing, PlayerFrame);

        // ── HUD overlays ──
        DrawWorldHUD();
    }

    void DrawTile(int tx, int ty, float sx, float sy)
    {
        int t = MAP[ty, tx];
        bool even = ((tx + ty) % 2 == 0);
        switch (t) {
            case 0:  // grass
                PixelRenderer.DrawRect(sx,sy,TS,TS, even?new Color(0.31f,0.58f,0.16f):new Color(0.27f,0.52f,0.14f));
                if ((tx*7+ty*11)%13==0) {
                    PixelRenderer.DrawRect(sx+3,sy+10,2,3,new Color(0.22f,0.47f,0.10f));
                    PixelRenderer.DrawRect(sx+8,sy+8, 2,4,new Color(0.22f,0.47f,0.10f));
                }
                break;
            case 1:  // tree
                PixelRenderer.DrawRect(sx,sy,TS,TS, new Color(0.14f,0.31f,0.08f));
                // foliage
                PixelRenderer.DrawRect(sx+2,sy+1,12,10,new Color(0.22f,0.47f,0.12f));
                PixelRenderer.DrawRect(sx+4,sy,  8, 6,new Color(0.33f,0.61f,0.18f));
                // trunk
                PixelRenderer.DrawRect(sx+5,sy+10,6,6,new Color(0.42f,0.25f,0.06f));
                // outline
                PixelRenderer.DrawBorder(sx+2,sy+1,12,10,PixelRenderer.COL_BLACK,1f);
                break;
            case 2:  // path
                PixelRenderer.DrawRect(sx,sy,TS,TS, even?new Color(0.77f,0.69f,0.47f):new Color(0.73f,0.65f,0.43f));
                PixelRenderer.DrawRect(sx,sy,TS,1,new Color(0.85f,0.78f,0.55f,0.4f));
                PixelRenderer.DrawRect(sx,sy,1,TS,new Color(0.85f,0.78f,0.55f,0.4f));
                break;
            case 3:  // water
                float wt = _time;
                PixelRenderer.DrawRect(sx,sy,TS,TS,new Color(0.08f,0.27f,0.75f));
                PixelRenderer.DrawRect(sx+2,sy+3,12,2,new Color(0.31f,0.63f,1f,0.55f+0.15f*Mathf.Sin(wt*2+tx)));
                PixelRenderer.DrawRect(sx,sy+10,16,2,new Color(0.31f,0.63f,1f,0.45f+0.10f*Mathf.Sin(wt*1.5f+ty)));
                break;
            case 4:  // sand
                PixelRenderer.DrawRect(sx,sy,TS,TS, even?new Color(0.82f,0.72f,0.43f):new Color(0.77f,0.67f,0.38f));
                break;
            case 5:  // gym wall
                PixelRenderer.DrawRect(sx,sy,TS,TS, new Color(_subjectColor.r*0.55f,_subjectColor.g*0.55f,_subjectColor.b*0.70f));
                PixelRenderer.DrawBorder(sx,sy,TS,TS,PixelRenderer.COL_BLACK,1f);
                PixelRenderer.DrawRect(sx+3,sy+3,TS-6,TS-6,new Color(_subjectColor.r*0.75f,_subjectColor.g*0.75f,_subjectColor.b*0.90f));
                break;
            case 6:  // gym door
                PixelRenderer.DrawRect(sx,sy,TS,TS, new Color(0.06f,0.06f,0.18f));
                PixelRenderer.DrawRect(sx+2,sy+2,TS-4,TS-4,new Color(_subjectColor.r,_subjectColor.g,_subjectColor.b,0.7f));
                PixelRenderer.DrawBorder(sx,sy,TS,TS,PixelRenderer.COL_BLACK,1f);
                // Doorframe glow
                float dg = 0.4f+0.3f*Mathf.Sin(_time*3f);
                PixelRenderer.DrawBorder(sx+1,sy+1,TS-2,TS-2,
                    new Color(_subjectColor.r,_subjectColor.g,_subjectColor.b,dg),1.5f);
                break;
            case 7:  // house
                PixelRenderer.DrawRect(sx,sy,TS,TS, new Color(0.78f,0.66f,0.50f));
                PixelRenderer.DrawRect(sx,sy,TS, 7, new Color(_subjectColor.r*0.55f,_subjectColor.g*0.55f,_subjectColor.b*0.70f));
                PixelRenderer.DrawBorder(sx,sy,TS,TS,PixelRenderer.COL_BLACK,1f);
                PixelRenderer.DrawRect(sx+3,sy+9,4,4,new Color(0.53f,0.80f,1f)); // window
                PixelRenderer.DrawRect(sx+9,sy+9,4,4,new Color(0.53f,0.80f,1f));
                break;
            case 8:  // fence
                PixelRenderer.DrawRect(sx,sy,TS,TS, new Color(0.31f,0.58f,0.16f));
                PixelRenderer.DrawRect(sx+1,sy+6,TS-2,2,new Color(0.78f,0.58f,0.25f));
                PixelRenderer.DrawRect(sx+2,sy+3,2,TS-3,new Color(0.78f,0.58f,0.25f));
                PixelRenderer.DrawRect(sx+TS-4,sy+3,2,TS-3,new Color(0.78f,0.58f,0.25f));
                PixelRenderer.DrawBorder(sx+2,sy+3,TS-4,TS-6,PixelRenderer.COL_BLACK,1f);
                break;
            case 9:  // sign
                PixelRenderer.DrawRect(sx,sy,TS,TS, even?new Color(0.31f,0.58f,0.16f):new Color(0.27f,0.52f,0.14f));
                PixelRenderer.DrawRect(sx+4,sy+3,8,6,new Color(0.91f,0.85f,0.58f));
                PixelRenderer.DrawBorder(sx+4,sy+3,8,6,PixelRenderer.COL_BLACK,1f);
                PixelRenderer.DrawRect(sx+7,sy+9,2,5,new Color(0.55f,0.31f,0.08f));
                break;
            case 10: // tall grass
                PixelRenderer.DrawRect(sx,sy,TS,TS, even?new Color(0.20f,0.50f,0.10f):new Color(0.16f,0.44f,0.08f));
                PixelRenderer.DrawRect(sx+2,sy+2,2,10,new Color(0.10f,0.36f,0.06f));
                PixelRenderer.DrawRect(sx+7,sy,  2,12,new Color(0.10f,0.36f,0.06f));
                PixelRenderer.DrawRect(sx+12,sy+3,2, 9,new Color(0.10f,0.36f,0.06f));
                break;
            case 11: // item spot
                PixelRenderer.DrawRect(sx,sy,TS,TS, even?new Color(0.31f,0.58f,0.16f):new Color(0.27f,0.52f,0.14f));
                if (!GameManager.Instance.HasItem("scroll"))
                    PixelRenderer.DrawRect(sx+4,sy+4,8,8,new Color(_subjectColor.r,_subjectColor.g,_subjectColor.b,0.5f));
                break;
            case 12: // flower
                PixelRenderer.DrawRect(sx,sy,TS,TS, even?new Color(0.31f,0.58f,0.16f):new Color(0.27f,0.52f,0.14f));
                PixelRenderer.DrawRect(sx+5,sy+7,6,5,new Color(0.97f,0.38f,0.56f));
                PixelRenderer.DrawRect(sx+6,sy+8,4,3,new Color(1f,0.80f,0f));
                break;
        }
    }

    void DrawWorldHUD()
    {
        int W = PixelRenderer.W, H = PixelRenderer.H;
        // Town name box (top-left)
        var br = SubjectDB.Subjects.TryGetValue(GameManager.Instance.ActiveSubject, out var si)
                 && si.branches.TryGetValue(GameManager.Instance.ActiveBranch, out var bi) ? bi : null;
        string town = br?.name ?? "Region";
        float tLen = town.Length * 7f + 20f;
        PixelRenderer.DrawRect(2, 2, tLen+4, 18, new Color(0,0,0,0.78f));
        PixelRenderer.DrawRect(4, 4, tLen,   14, PixelRenderer.COL_WHITE);
        PixelRenderer.DrawBorder(4,4,tLen,14,PixelRenderer.COL_BLACK,1.5f);
        PixelRenderer.DrawString(8, 15, town.ToUpper(), 11, PixelRenderer.COL_BLACK, true);

        // Controls (bottom-right)
        string hint = "Arrows:Move  Enter:Talk  Esc:Menu";
        float hLen = hint.Length * 5.8f + 8f;
        PixelRenderer.DrawRect(W-hLen-4, H-18, hLen+4, 16, new Color(0,0,0,0.72f));
        PixelRenderer.DrawString(W-hLen, H-9, hint, 9, new Color(0.85f,0.85f,0.85f));
    }

    static Vector2Int FacingDir(int f) => f switch {
        0 => new( 0, 1), 1 => new( 0,-1), 2 => new(-1, 0), _ => new( 1, 0)
    };

    void Update() {} // time updated in DrawWorld() called from OnGUI
}
