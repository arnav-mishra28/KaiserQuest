// SilverMountainManager.cs — Oracle Final Boss Zone
using UnityEngine;
using System.Collections.Generic;

public class SilverMountainManager : MonoBehaviour
{
    public static SilverMountainManager Instance { get; private set; }
    void Awake() { Instance = this; }

    float _time, _rise;
    int   _attempt;
    readonly List<Particle> _pts=new();

    struct Particle{public float x,y,vx,vy,alpha,size;public Color col;}

    void OnEnable()
    {
        _time=0f;_rise=0f;_pts.Clear();
        for(int i=0;i<40;i++){
            Color[] cols={new Color(.75f,.78f,1f),new Color(1f,.84f,0f),Color.white,new Color(.53f,.6f,1f)};
            _pts.Add(new Particle{x=Random.value*480,y=Random.value*320,vx=Random.Range(-.3f,.3f),
                vy=Random.Range(-.6f,-.1f),alpha=Random.value,size=Random.Range(1.5f,4f),col=cols[Random.Range(0,cols.Length)]});
        }
        Check();
    }

    void Check()
    {
        if(GameManager.Instance.SilverOnCooldown()){
            long s=GameManager.Instance.SilverCooldownRemaining();
            long hrs=s/3600,mins=(s%3600)/60;
            DialogBox.Instance?.ShowLines(new[]{
                "Silver Mountain is sealed...",
                "Cooldown: "+hrs+"h "+mins+"m remaining.",
                "Study your weak topics!","Return when the gate reopens."},
                ()=>GameScreenManager.Instance?.GoTo(GameScreen.World),DialogBox.Context.World);
            return;
        }
        if(!GameManager.Instance.CanChallengeSilver()){
            int lv=GameManager.Instance.Level,bdg=GameManager.Instance.Badges.Count;
            DialogBox.Instance?.ShowLines(new[]{
                "The Oracle senses you...",
                "But you are not ready.",
                "Need: Level 100 (you: "+lv+"),\n20 badges (you: "+bdg+"/20)."},
                ()=>GameScreenManager.Instance?.GoTo(GameScreen.World),DialogBox.Context.World);
            return;
        }
        ShowStory();
    }

    void ShowStory()
    {
        DialogBox.Instance?.ShowLines(new[]{
            "Long ago, the world was bright\nwith knowledge and light.",
            "Then the Fog of Forgetting came...",
            "Cities fell silent. Books gathered dust.\nNotes faded from the staff.",
            "One scholar built Silver Mountain\nas a fortress of all knowledge.",
            "At its peak: THE ORACLE —\nguardian of everything ever known.",
            "Three chances. All 20 badges.\nLevel 100.",
            "You are ready, "+GameManager.Instance.PlayerName+".",
            "Enter Silver Mountain.\n\n  — Press ENTER —"},
            BeginBattle,DialogBox.Context.World);
    }

    void BeginBattle()
    {
        _attempt++;
        // Mix questions from all banks
        var all=new List<QuestionData>();
        foreach(var sub in SubjectDB.Subjects.Keys)
            foreach(var br in SubjectDB.Subjects[sub].branches.Keys)
                all.AddRange(SubjectDB.GetQuestions(sub,br));
        for(int i=all.Count-1;i>0;i--){var j=Random.Range(0,i+1);(all[j],all[i])=(all[i],all[j]);}
        var pool=all.Count>15?all.GetRange(0,15):all;
        var boss=new GymLeaderData{
            name="The Oracle",title="Ancient Guardian of All Knowledge",
            color=new Color(.75f,.78f,1f),xpReward=5000,badgeName="Kaiser Badge",
            intro=new[]{"The Oracle has watched you from the beginning.","15 mixed questions from all subjects.","3 lives. Your final test.\n\nAttempt "+_attempt+"/3. Begin!"},
            win=new[]{"...","It is done.","You have answered the call\nof all knowledge.","★ KAISER ★"},
            lose=_attempt>=3?new[]{"Three failures...","The Oracle seals the gate for 24 hours."}
                            :new[]{"Not yet...","Return stronger. Attempts left: "+(3-_attempt)}
        };
        pool.ForEach(q=>q.difficulty=Mathf.Clamp(1+_attempt,1,4)); // Scale difficulty with attempts
        BattleManager.Instance?.Setup(boss,pool,true);
        // Listen for result via GameManager events (badge earned = won)
        GameManager.Instance.OnBadgeEarned+=OnBadgeResult;
    }

    void OnBadgeResult(string badge)
    {
        GameManager.Instance.OnBadgeEarned-=OnBadgeResult;
        if(badge=="Kaiser Badge"){
            GameManager.Instance.SilverCleared();
            GameScreenManager.Instance?.GoTo(GameScreen.Kaiser);
        } else {
            GameManager.Instance.SilverAttemptFailed();
            if(GameManager.Instance.SilverOnCooldown()){
                DialogBox.Instance?.ShowLines(new[]{"Three failed attempts...","The Oracle seals the gate for 24 hours.","Return tomorrow. Stronger."},
                    ()=>GameScreenManager.Instance?.GoTo(GameScreen.World),DialogBox.Context.World);
            } else {
                DialogBox.Instance?.ShowLines(new[]{"Defeated...","Attempts remaining: "+(3-_attempt),"Study and return!"},
                    ()=>{ if(_attempt<3) BeginBattle(); else GameScreenManager.Instance?.GoTo(GameScreen.World); },
                    DialogBox.Context.World);
            }
        }
    }

    void Update() {
        if(GameScreenManager.Instance?.Current!=GameScreen.Silver) return;
        _time+=Time.deltaTime;
        _rise=Mathf.MoveTowards(_rise,1f,Time.deltaTime*.4f);
        for(int i=0;i<_pts.Count;i++){
            var p=_pts[i];p.x+=p.vx;p.y+=p.vy;p.alpha=Mathf.Repeat(p.alpha+Time.deltaTime*.3f,1f);
            if(p.y<-10){p.y=330;p.x=Random.value*480;}_pts[i]=p;
        }
    }

    void OnGUI()
    {
        if(GameScreenManager.Instance?.Current!=GameScreen.Silver) return;
        PixelRenderer.BeginFrame();
        int W=PixelRenderer.W,H=PixelRenderer.H;
        float ease=_rise*_rise*(3f-2f*_rise);
        // Sky
        for(int sy=0;sy<H;sy+=4){float t=sy/(float)H;PixelRenderer.DrawRect(0,sy,W,4,new Color(.02f+t*.04f,.01f+t*.04f,.08f+t*.12f,ease));}
        // Stars
        for(int si=0;si<60;si++){
            float sx=(si*71+13)%480f,sy=(si*47+7)%200f;
            PixelRenderer.DrawRect(sx,sy,si%4==0?2:1,si%4==0?2:1,new Color(1,1,1,(.3f+.7f*Mathf.Sin(_time*1.2f+si*.6f))*ease));
        }
        // Mountain silhouettes
        float my=H-(H-60)*ease;
        Color m1=new Color(.10f,.08f,.20f,ease);
        DrawTri(0,H,80,my+60,180,H,m1);DrawTri(120,H,240,my-20,380,H,m1.gamma);DrawTri(280,H,400,my+40,480,H,m1);
        // Silver peak
        DrawTri(200,H,240,my,280,H,new Color(.55f,.6f,.9f,ease));
        DrawTri(228,my+20,240,my,252,my+20,new Color(.92f,.95f,1f,ease));
        float ga=.4f+.3f*Mathf.Sin(_time*2f);PixelRenderer.DrawRect(234,my-6,12,6,new Color(.8f,.85f,1f,ga*ease));
        // Particles
        foreach(var p in _pts) PixelRenderer.DrawRect(p.x,p.y,p.size,p.size,new Color(p.col.r,p.col.g,p.col.b,p.alpha*ease*.7f));
        if(ease>.5f){float ta=(ease-.5f)*2f;
            PixelRenderer.DrawString(154,40,"SILVER MOUNTAIN",18,new Color(.75f,.78f,1f,ta),true);
            PixelRenderer.DrawString(134,60,"The Oracle Awaits",14,new Color(1f,.84f,0f,ta*.8f));
            if(_attempt>0){string dots="";for(int i=0;i<3;i++)dots+=i<_attempt?"●":"○";
                PixelRenderer.DrawRect(4,4,120,16,new Color(0,0,0,.6f));
                PixelRenderer.DrawString(8,14,"Attempts: "+dots,11,new Color(.75f,.78f,1f,ta));}
        }
        PixelRenderer.EndFrame();
    }

    void DrawTri(float x1,float y1,float x2,float y2,float x3,float y3,Color c)
    {
        float minY=Mathf.Min(y1,Mathf.Min(y2,y3)),maxY=Mathf.Max(y1,Mathf.Max(y2,y3));
        float[] xs={x1,x2,x3},ys={y1,y2,y3};
        for(float y=minY;y<=maxY;y++){
            float lx=480,rx=0;
            for(int i=0;i<3;i++){int j=(i+1)%3;
                if((ys[i]<=y&&y<ys[j])||(ys[j]<=y&&y<ys[i])){
                    float t=(y-ys[i])/(ys[j]-ys[i]);float xi=xs[i]+t*(xs[j]-xs[i]);
                    if(xi<lx)lx=xi;if(xi>rx)rx=xi;}}
            if(rx>=lx)PixelRenderer.DrawRect(lx,y,rx-lx,1,c);
        }
    }
}
