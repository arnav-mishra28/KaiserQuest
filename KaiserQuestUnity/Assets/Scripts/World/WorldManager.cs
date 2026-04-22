// WorldManager.cs — Gen 1/2 Pokemon-Style Town Map (15×10 static viewport)
using UnityEngine;
using System.Collections.Generic;

public class WorldManager : MonoBehaviour
{
    public static WorldManager Instance { get; private set; }
    void Awake() { Instance = this; }

    // Events for screen transitions (listened to by WorldController)
    public event System.Action                       OnGymEntered;
    public event System.Action<GymLeaderData,float>  OnDuelTriggered;

    const int TS=32, COLS=15, ROWS=10;
    readonly int[] WALKABLE={0,4,7,9,12};

    // T_GRASS=0,T_TREE=1,T_HOUSE=2,T_DOOR=12,T_PATH=4,T_GYM=5,T_GDOOR=6,T_ITEM=7,T_FENCE=11,T_WATER=8,T_SAND=9
    static readonly int[,] MAP={
        {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
        {1,0,0,0,5,5,0,0,0,0,0,0,0,0,1},
        {1,0,2,2,5,5,0,2,2,0,0,0,0,0,1},
        {1,0,2,2,5,0,0,2,2,0,11,11,0,0,1},
        {1,0,12,0,0,0,0,12,0,0,11,0,0,0,1},
        {1,0,0,0,4,4,4,4,4,4,0,7,0,0,1},
        {1,0,0,4,0,0,0,0,0,0,4,0,0,0,1},
        {1,0,4,5,5,6,5,5,5,5,4,0,0,0,1},
        {1,0,0,4,4,4,4,4,4,4,0,0,0,0,1},
        {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
    };
    static readonly Vector2Int GYM_DOOR=new(5,7);
    static readonly Vector2Int ITEM_POS=new(11,5);

    // ── NPC data ──────────────────────────────────────────────────────────────
    struct NPCDef {
        public Vector2Int pos; public Color shirt; public string type;
        public string id, label; public string[] lines; public string[] lesson;
        public int xp; public float duelAccuracy;
    }

    readonly NPCDef[] NPCS_ALGEBRA={
        new(){pos=new(7,2),shirt=new Color(0.12f,0.38f,0.82f),type="teacher",id="t1",label="Prof. Varius",xp=75,
              lesson=new[]{"📖 LESSON: Variables","A variable is a letter that stands\nfor an unknown number.","x, y, n are variables.\n7, 3.14 are constants.","If x+2=5, then x=3.\n✓ +75 XP"}},
        new(){pos=new(4,8),shirt=new Color(0.06f,0.63f,0.38f),type="teacher",id="t2",label="Scholar Equa",xp=75,
              lesson=new[]{"📖 LESSON: Equations","An equation says two things are equal.","2x+1=7: solve for x.\nSubtract 1: 2x=6, Divide: x=3.","✓ +75 XP"}},
        new(){pos=new(12,3),shirt=new Color(0.91f,0.75f,0.19f),type="npc",id="npc1",xp=50,
              lines=new[]{"Welcome to this city!","Talk to ? Teachers for XP!","You need Level 5 for Gym 1."}},
        new(){pos=new(12,5),shirt=new Color(0.19f,0.63f,0.19f),type="npc",id="npc2",xp=50,
              lines=new[]{"There are 20 gyms in this branch!","Each gym tests your knowledge.","Get all 20 badges to reach\nSilver Mountain!"}},
        new(){pos=new(12,6),shirt=new Color(0.88f,0.31f,0.06f),type="duel",id="duel1",duelAccuracy=0.55f,
              lines=new[]{"I challenge you!","Knowledge Duel! 7 questions.","Let's go!"}},
    };

    NPCDef[] _npcs;
    string   _world;
    float    _time;
    bool     _dialogOpen;
    Vector2  _playerVisualPos;
    int      _playerFacing=0;
    bool     _playerMoving=false;
    int      _playerFrame=0;

    // ── Init ──────────────────────────────────────────────────────────────────
    public void InitWorld(string worldKey)
    {
        _world = worldKey;
        _npcs  = NPCS_ALGEBRA;  // For now same layout, extend per branch
        _dialogOpen = false;
        var gp = GameManager.Instance.GridPos;
        gp.x = Mathf.Clamp(gp.x,0,COLS-1); gp.y = Mathf.Clamp(gp.y,0,ROWS-1);
        if (!IsWalkable(gp)) gp = new Vector2Int(7,8);
        GameManager.Instance.GridPos = gp;
        _playerVisualPos = new Vector2(gp.x*TS, gp.y*TS);
    }

    public void SetDialogOpen(bool v) { _dialogOpen = v; }
    public void SetPlayerState(Vector2 visualPos, int facing, bool moving, int frame) {
        _playerVisualPos = visualPos; _playerFacing = facing; _playerMoving = moving; _playerFrame = frame;
    }

    bool IsWalkable(Vector2Int p) {
        if (p.x<0||p.x>=COLS||p.y<0||p.y>=ROWS) return false;
        int t=MAP[p.y,p.x];
        foreach(var w in WALKABLE) if(t==w) return true;
        return false;
    }

    public bool TryMove(Vector2Int from, Vector2Int dir, out Vector2Int dest) {
        dest=from+dir; return IsWalkable(dest);
    }

    public void TryInteract(Vector2Int gridPos, int facing)
    {
        Vector2Int front=gridPos+FacingDir(facing);
        if (front==GYM_DOOR) { TryEnterGym(); return; }
        foreach(var npc in _npcs) {
            if (npc.pos==front) { TalkNPC(npc); return; }
        }
    }

    public void OnPlayerMoved(Vector2Int gp)
    {
        GameManager.Instance.GridPos = gp;
        if (gp==ITEM_POS && !GameManager.Instance.HasItem("branch_scroll")) {
            GameManager.Instance.CollectItem("branch_scroll");
            GameManager.Instance.AddXP(200);
            HUD.Instance?.ShowXPGain(200);
            DialogBox.Instance?.ShowLines(new[]{"You found a Knowledge Scroll!","'The greatest journey begins\nwith a single question.'","+200 XP!"}, null, DialogBox.Context.World);
        }
    }

    void TalkNPC(NPCDef npc)
    {
        if (npc.type=="teacher") TalkTeacher(npc);
        else if (npc.type=="duel") TalkDuel(npc);
        else TalkNormal(npc);
    }

    void TalkNormal(NPCDef npc)
    {
        var lines=new System.Collections.Generic.List<string>(npc.lines);
        if (!GameManager.Instance.HasTalked(npc.id)) {
            GameManager.Instance.MarkTalked(npc.id);
            lines.Add("(+"+npc.xp+" XP!)");
            GameManager.Instance.AddXP(npc.xp);
            HUD.Instance?.ShowXPGain(npc.xp);
        }
        DialogBox.Instance?.ShowLines(lines.ToArray(),null,DialogBox.Context.World);
    }

    void TalkTeacher(NPCDef npc)
    {
        if (GameManager.Instance.HasTalked(npc.id)) {
            DialogBox.Instance?.ShowLines(new[]{"You already learned from "+npc.label+"!","Keep practicing those concepts."},null,DialogBox.Context.World);
            return;
        }
        GameManager.Instance.MarkTalked(npc.id);
        DialogBox.Instance?.ShowLines(npc.lesson, ()=>{
            GameManager.Instance.AddXP(npc.xp);
            HUD.Instance?.ShowXPGain(npc.xp);
        }, DialogBox.Context.World);
    }

    void TalkDuel(NPCDef npc)
    {
        var opp = new GymLeaderData { name = npc.label, color = npc.shirt };
        float acc = npc.duelAccuracy;
        DialogBox.Instance?.ShowLines(npc.lines, ()=>{
            GameScreenManager.Instance?.GoTo(GameScreen.Duel);
            OnDuelTriggered?.Invoke(opp, acc);
        }, DialogBox.Context.World);
    }

    void TryEnterGym()
    {
        var parts=_world.Split(':');
        if(parts.Length<2) return;
        string subject=parts[0], branch=parts[1];
        int gymNum=GameManager.Instance.Badges.Count+1;
        if(gymNum>20){
            DialogBox.Instance?.ShowLines(new[]{"All 20 gyms conquered!","Silver Mountain awaits!"},null,DialogBox.Context.World);return;
        }
        var leader=SubjectDB.GetGymLeader(subject,branch,gymNum);
        if(GameManager.Instance.HasBadge(leader.badgeName)){
            DialogBox.Instance?.ShowLines(new[]{"You already hold "+leader.badgeName+"!","The leader bows respectfully."},null,DialogBox.Context.World);return;
        }
        if(!GameManager.Instance.CanChallengeGym(gymNum)){
            DialogBox.Instance?.ShowLines(new[]{"The gym is sealed!","You need Level "+(gymNum*5)+" for Gym "+gymNum+".","Your Level: "+GameManager.Instance.Level+"\nTalk to Teachers for XP!"},null,DialogBox.Context.World);return;
        }
        bool talkedToTeacher=false;
        foreach(var n in _npcs) if(n.type=="teacher"&&GameManager.Instance.HasTalked(n.id)){talkedToTeacher=true;break;}
        if(!talkedToTeacher){
            DialogBox.Instance?.ShowLines(new[]{"The gym door is locked!","Talk to a ? Teacher first!"},null,DialogBox.Context.World);return;
        }
        DialogBox.Instance?.ShowLines(new[]{"You step up to the gym entrance...","The door opens before you!"},()=>{
            GameScreenManager.Instance?.GoTo(GameScreen.Battle);
            OnGymEntered?.Invoke();
        },DialogBox.Context.World);
    }

    Vector2Int FacingDir(int f){
        switch(f){case 0:return new(0,1);case 1:return new(0,-1);case 2:return new(-1,0);default:return new(1,0);}
    }

    // ── Drawing ───────────────────────────────────────────────────────────────
    void Update() => _time+=Time.deltaTime;

    public void DrawWorld()
    {
        var sub=SubjectDB.Subjects.TryGetValue(GameManager.Instance.ActiveSubject,out var si)?si:null;
        Color subCol=sub!=null?sub.color:new Color(0.12f,0.38f,0.82f);
        Color grassBase=Color.Lerp(subCol,new Color(0.14f,0.32f,0.12f),0.6f);

        for(int r=0;r<ROWS;r++){
            for(int c=0;c<COLS;c++){
                int t=MAP[r,c]; float px=c*TS, py=r*TS;
                DrawTile(t,px,py,c,r,subCol,grassBase);
            }
        }

        // Item sparkle
        if(!GameManager.Instance.HasItem("branch_scroll"))
            SpriteDrawer.DrawItemSparkle(ITEM_POS.x*TS,ITEM_POS.y*TS,subCol,_time);

        // NPCs (drawn behind player at lower rows, above at higher)
        foreach(var npc in _npcs) {
            float nx=npc.pos.x*TS, ny=npc.pos.y*TS;
            SpriteDrawer.DrawNPC(nx,ny,npc.shirt,npc.type=="teacher",npc.type=="duel");
        }

        // Player
        float plx=_playerVisualPos.x, ply=_playerVisualPos.y;
        SpriteDrawer.DrawPlayerBack(plx,ply,_playerFrame,_playerFacing);

        // Gym banner
        DrawGymBanner(subCol);
        DrawUI();
    }

    void DrawTile(int t,float px,float py,int c,int r,Color sc,Color grassBase)
    {
        bool chk=((c+r)%2)==0;
        switch(t){
            case 0: SpriteDrawer.DrawGrassTile(px,py,TS,grassBase,chk,(c*11+r*7)%14==0,_time); break;
            case 1: SpriteDrawer.DrawTreeTile(px,py,TS); break;
            case 2: SpriteDrawer.DrawHouseTile(px,py,TS,sc); break;
            case 4: SpriteDrawer.DrawPathTile(px,py,TS,chk); break;
            case 5: SpriteDrawer.DrawGymWall(px,py,TS,sc,_time); break;
            case 6: SpriteDrawer.DrawGymDoor(px,py,TS,sc,_time); break;
            case 7: SpriteDrawer.DrawGrassTile(px,py,TS,grassBase,chk,false,_time); break;
            case 8: SpriteDrawer.DrawWaterTile(px,py,TS,_time,c,r); break;
            case 9:
                PixelRenderer.DrawRect(px,py,TS,TS,chk?new Color(0.83f,0.72f,0.44f):new Color(0.77f,0.66f,0.38f));
                break;
            case 11:
                SpriteDrawer.DrawGrassTile(px,py,TS,grassBase,chk,false,_time);
                PixelRenderer.DrawRect(px+3,py+6,4,22,new Color(0.55f,0.31f,0.12f));
                PixelRenderer.DrawRect(px+25,py+6,4,22,new Color(0.55f,0.31f,0.12f));
                PixelRenderer.DrawRect(px+3,py+8,TS-6,4,new Color(0.66f,0.41f,0.19f));
                PixelRenderer.DrawRect(px+3,py+18,TS-6,4,new Color(0.66f,0.41f,0.19f));
                break;
            case 12:
                SpriteDrawer.DrawGrassTile(px,py,TS,grassBase,chk,false,_time);
                PixelRenderer.DrawRect(px+8,py+5,16,25,new Color(0.35f,0.19f,0.06f));
                PixelRenderer.DrawBorder(px+8,py+5,16,25,PixelRenderer.COL_BLACK,1f);
                PixelRenderer.DrawRect(px+20,py+16,3,3,PixelRenderer.COL_GOLD);
                break;
            default:
                PixelRenderer.DrawRect(px,py,TS,TS,new Color(0.14f,0.32f,0.12f));
                break;
        }
    }

    void DrawGymBanner(Color sc)
    {
        var br=SubjectDB.Subjects.TryGetValue(GameManager.Instance.ActiveSubject,out var si)&&
               si.branches.TryGetValue(GameManager.Instance.ActiveBranch,out var bi)?bi:null;
        int gym=Mathf.Min(GameManager.Instance.Badges.Count+1,20);
        string txt="★ "+(br?.name??"")+" Gym "+gym+" ★";
        PixelRenderer.DrawRect(128,208,224,18,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(129,209,222,16,new Color(sc.r*0.85f,sc.g*0.85f,sc.b*0.85f));
        PixelRenderer.DrawString(136,220,txt,12,sc.r*0.85f<0.4f&&sc.g*0.85f<0.4f&&sc.b*0.85f<0.4f?Color.white:PixelRenderer.COL_BLACK);
    }

    void DrawUI()
    {
        var br=SubjectDB.Subjects.TryGetValue(GameManager.Instance.ActiveSubject,out var si)&&
               si.branches.TryGetValue(GameManager.Instance.ActiveBranch,out var bi)?bi:null;
        string town=br?.name??"City";
        PixelRenderer.DrawRect(3,3,130,16,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(5,5,126,12,PixelRenderer.COL_WHITE);
        PixelRenderer.DrawBorder(5,5,126,12,PixelRenderer.COL_BLACK,1.5f);
        PixelRenderer.DrawString(9,13,town.ToUpper(),11,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(338,3,138,16,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(340,5,134,12,PixelRenderer.COL_WHITE);
        PixelRenderer.DrawBorder(340,5,134,12,PixelRenderer.COL_BLACK,1.5f);
        PixelRenderer.DrawString(344,13,"ESC = Subject Menu",10,PixelRenderer.COL_BLACK);
    }
}
