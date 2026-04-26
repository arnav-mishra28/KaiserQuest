// WorldManager.cs — Gen 1/2 Pokemon-Style Town Map (2.5D logic layer)
// This file owns the game-world data and NPC logic.
// Visual rendering is split: 3D geometry via World3DRenderer, 2D HUD via DrawHUD().
using UnityEngine;
using System.Collections.Generic;

public class WorldManager : MonoBehaviour
{
    public static WorldManager Instance { get; private set; }
    void Awake() { Instance = this; }

    public event System.Action                       OnGymEntered;
    public event System.Action<GymLeaderData,float>  OnDuelTriggered;

    const int COLS=15, ROWS=10;
    readonly int[] WALKABLE={0,4,7,9,12};

    // T_GRASS=0,T_TREE=1,T_HOUSE=2,T_DOOR=12,T_PATH=4,T_GYM=5,T_GDOOR=6,
    // T_ITEM=7,T_FENCE=11,T_WATER=8,T_SAND=9
    public static readonly int[,] MAP3D={
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
    public static readonly Vector2Int ITEM_POS3D=new(11,5);

    struct NPCDef {
        public Vector2Int pos; public Color shirt; public string type;
        public string id, label; public string[] lines; public string[] lesson;
        public int xp; public float duelAccuracy;
    }

    readonly NPCDef[] NPCS_ALGEBRA={
        new(){pos=new(7,2),shirt=new Color(0.12f,0.38f,0.82f),type="teacher",id="t1",label="Prof. Varius",xp=75,
              lesson=new[]{"LESSON: Variables","A variable is a letter that stands for an unknown number.",
                           "x, y, n are variables.  7, 3.14 are constants.",
                           "If x + 2 = 5, then x = 3.   +75 XP"}},
        new(){pos=new(4,8),shirt=new Color(0.06f,0.63f,0.38f),type="teacher",id="t2",label="Scholar Equa",xp=75,
              lesson=new[]{"LESSON: Equations","An equation says two things are equal.",
                           "2x + 1 = 7: solve for x.  Subtract 1: 2x=6,  Divide: x=3.","+ 75 XP"}},
        new(){pos=new(12,3),shirt=new Color(0.91f,0.75f,0.19f),type="npc",id="npc1",xp=50,
              lines=new[]{"Welcome to this city!","Talk to Teachers for XP!","You need Level 5 for Gym 1."}},
        new(){pos=new(12,5),shirt=new Color(0.19f,0.63f,0.19f),type="npc",id="npc2",xp=50,
              lines=new[]{"There are 20 gyms in this branch!","Each gym tests your knowledge.","Get all 20 badges to reach Silver Mountain!"}},
        new(){pos=new(12,6),shirt=new Color(0.88f,0.31f,0.06f),type="duel",id="duel1",duelAccuracy=0.55f,
              lines=new[]{"I challenge you!","Knowledge Duel!  7 questions.","Let's go!"}},
    };

    NPCDef[] _npcs;
    string   _world;
    float    _time;
    bool     _dialogOpen;
    Vector2  _playerVisualPos;
    int      _playerFacing=0;
    bool     _playerMoving=false;
    int      _playerFrame=0;

    public void InitWorld(string worldKey)
    {
        _world = worldKey;
        _npcs  = NPCS_ALGEBRA;
        _dialogOpen = false;
        var gp = GameManager.Instance.GridPos;
        gp.x = Mathf.Clamp(gp.x,0,COLS-1); gp.y = Mathf.Clamp(gp.y,0,ROWS-1);
        if (!IsWalkable(gp)) gp = new Vector2Int(7,8);
        GameManager.Instance.GridPos = gp;
        _playerVisualPos = new Vector2(gp.x*32, gp.y*32);
    }

    // Returns NPC data for the 3D renderer
    public World3DRenderer.NPCInfo[] GetNPCInfosFor3D()
    {
        var result = new World3DRenderer.NPCInfo[_npcs.Length];
        for (int i = 0; i < _npcs.Length; i++)
            result[i] = new World3DRenderer.NPCInfo {
                pos       = _npcs[i].pos,
                shirt     = _npcs[i].shirt,
                isTeacher = _npcs[i].type == "teacher",
                isDuel    = _npcs[i].type == "duel",
            };
        return result;
    }

    public void SetDialogOpen(bool v) { _dialogOpen = v; }
    public void SetPlayerState(Vector2 vp, int facing, bool moving, int frame) {
        _playerVisualPos = vp; _playerFacing = facing; _playerMoving = moving; _playerFrame = frame;
    }

    bool IsWalkable(Vector2Int p) {
        if (p.x<0||p.x>=COLS||p.y<0||p.y>=ROWS) return false;
        int t=MAP3D[p.y,p.x];
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
        if (gp==ITEM_POS3D && !GameManager.Instance.HasItem("branch_scroll")) {
            GameManager.Instance.CollectItem("branch_scroll");
            GameManager.Instance.AddXP(200);
            HUD.Instance?.ShowXPGain(200);
            DialogBox.Instance?.ShowLines(new[]{"You found a Knowledge Scroll!",
                "'The greatest journey begins with a single question.'","+200 XP!"},
                null, DialogBox.Context.World);
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
        var lines=new List<string>(npc.lines);
        if (!GameManager.Instance.HasTalked(npc.id)) {
            GameManager.Instance.MarkTalked(npc.id);
            lines.Add("(+" + npc.xp + " XP!)");
            GameManager.Instance.AddXP(npc.xp);
            HUD.Instance?.ShowXPGain(npc.xp);
        }
        DialogBox.Instance?.ShowLines(lines.ToArray(),null,DialogBox.Context.World);
    }

    void TalkTeacher(NPCDef npc)
    {
        if (GameManager.Instance.HasTalked(npc.id)) {
            DialogBox.Instance?.ShowLines(new[]{"You already learned from "+npc.label+"!",
                "Keep practicing those concepts."},null,DialogBox.Context.World);
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
        var opp = new GymLeaderData { name = npc.id, color = npc.shirt };
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
            DialogBox.Instance?.ShowLines(new[]{"All 20 gyms conquered!","Silver Mountain awaits!"},
                null,DialogBox.Context.World);return;
        }
        var leader=SubjectDB.GetGymLeader(subject,branch,gymNum);
        if(GameManager.Instance.HasBadge(leader.badgeName)){
            DialogBox.Instance?.ShowLines(new[]{"You already hold "+leader.badgeName+"!",
                "The leader bows respectfully."},null,DialogBox.Context.World);return;
        }
        if(!GameManager.Instance.CanChallengeGym(gymNum)){
            DialogBox.Instance?.ShowLines(new[]{"The gym is sealed!",
                "You need Level "+(gymNum*5)+" for Gym "+gymNum+".",
                "Your Level: "+GameManager.Instance.Level+"  Talk to Teachers for XP!"},
                null,DialogBox.Context.World);return;
        }
        bool talkedToTeacher=false;
        foreach(var n in _npcs) if(n.type=="teacher"&&GameManager.Instance.HasTalked(n.id)){talkedToTeacher=true;break;}
        if(!talkedToTeacher){
            DialogBox.Instance?.ShowLines(new[]{"The gym door is locked!","Talk to a Teacher first!"},
                null,DialogBox.Context.World);return;
        }
        DialogBox.Instance?.ShowLines(new[]{"You step up to the gym entrance...","The door opens before you!"},
            ()=>{
                GameScreenManager.Instance?.GoTo(GameScreen.Battle);
                OnGymEntered?.Invoke();
            },DialogBox.Context.World);
    }

    Vector2Int FacingDir(int f){
        switch(f){case 0:return new(0,1);case 1:return new(0,-1);case 2:return new(-1,0);default:return new(1,0);}
    }

    void Update() => _time+=Time.deltaTime;

    // DrawHUD — called from WorldController.OnGUI for the 2D overlay only
    public void DrawHUD()
    {
        var sub=SubjectDB.Subjects.TryGetValue(GameManager.Instance.ActiveSubject,out var si)?si:null;
        Color subCol=sub!=null?sub.color:new Color(0.12f,0.38f,0.82f);

        DrawGymBanner(subCol);
        DrawUIOverlay();
    }

    void DrawGymBanner(Color sc)
    {
        var br=SubjectDB.Subjects.TryGetValue(GameManager.Instance.ActiveSubject,out var si)&&
               si.branches.TryGetValue(GameManager.Instance.ActiveBranch,out var bi)?bi:null;
        int gym=Mathf.Min(GameManager.Instance.Badges.Count+1,20);
        string txt="  "+(br?.name??"")+"  Gym "+gym+"  ";

        // Banner at bottom center
        float bw = txt.Length * 7.5f + 24f;
        float bx = (480f - bw) * 0.5f;
        PixelRenderer.DrawRect(bx,     290, bw,   20, new Color(0,0,0,0.82f));
        PixelRenderer.DrawRect(bx+2,   292, bw-4, 16, new Color(sc.r*0.7f, sc.g*0.7f, sc.b*0.7f));
        PixelRenderer.DrawBorder(bx+2, 292, bw-4, 16, PixelRenderer.COL_BLACK, 1.5f);
        Color txtCol = (sc.r*0.7f < 0.45f && sc.g*0.7f < 0.45f) ? Color.white : PixelRenderer.COL_BLACK;
        PixelRenderer.DrawString(bx+10, 302, "  " + (br?.name ?? "") + "  Gym " + gym, 11, txtCol);
    }

    void DrawUIOverlay()
    {
        var br=SubjectDB.Subjects.TryGetValue(GameManager.Instance.ActiveSubject,out var si)&&
               si.branches.TryGetValue(GameManager.Instance.ActiveBranch,out var bi)?bi:null;
        string town=br?.name??"City";

        // Town name  top-left
        float tlen = town.Length * 7f + 20f;
        PixelRenderer.DrawRect(3, 3, tlen+4, 18, new Color(0,0,0,0.82f));
        PixelRenderer.DrawRect(5, 5, tlen,   14, PixelRenderer.COL_WHITE);
        PixelRenderer.DrawBorder(5, 5, tlen, 14, PixelRenderer.COL_BLACK, 1.5f);
        PixelRenderer.DrawString(10, 16, town.ToUpper(), 11, PixelRenderer.COL_BLACK, true);

        // Controls hint  top-right
        string hint = "ENTER=Talk  ESC=Menu";
        float hw = hint.Length * 6f + 14f;
        PixelRenderer.DrawRect(480-hw-3, 3, hw+4, 18, new Color(0,0,0,0.82f));
        PixelRenderer.DrawRect(480-hw-1, 5, hw,   14, PixelRenderer.COL_WHITE);
        PixelRenderer.DrawBorder(480-hw-1, 5, hw, 14, PixelRenderer.COL_BLACK, 1.5f);
        PixelRenderer.DrawString(480-hw+2, 16, hint, 10, PixelRenderer.COL_BLACK);
    }
}
