// HUD.cs — Gen 1/2 Stats Overlay
using UnityEngine;

public class HUD : MonoBehaviour
{
    public static HUD Instance { get; private set; }
    void Awake() { if(Instance!=null&&Instance!=this){Destroy(gameObject);return;}Instance=this;DontDestroyOnLoad(gameObject); }

    private string _notif    = "";
    private float  _notifT   = 0f;
    private float  _time     = 0f;
    const float NDUR = 2.5f;

    void Start()
    {
        if (GameManager.Instance != null) {
            GameManager.Instance.OnXPChanged  += (_,_,_) => Repaint();
            GameManager.Instance.OnLevelUp    += lv      => ShowNotif("LEVEL UP! Lv."+lv+"!");
            GameManager.Instance.OnBadgeEarned+= b       => ShowNotif(b+" EARNED!");
            GameManager.Instance.OnHPChanged  += (_,_)   => Repaint();
        }
    }

    void Update() {
        _time += Time.deltaTime;
        if (_notifT > 0f) { _notifT -= Time.deltaTime; if(_notifT<0f)_notifT=0f; }
    }

    public void ShowXPGain(int amt) => ShowNotif("+" + amt + " EXP!");
    public void ShowNotif(string t)  { _notif = t; _notifT = NDUR; }
    void Repaint() { /* triggers OnGUI via dirty */ }

    void OnGUI()
    {
        if (GameManager.Instance == null || string.IsNullOrEmpty(GameManager.Instance.ActiveSubject)) return;
        if (DialogBox.Instance != null && DialogBox.Instance.IsOpen) return;  // Dialog covers HUD

        PixelRenderer.BeginFrame();
        var gm=GameManager.Instance;
        var wcol=SubjectDB.Subjects.TryGetValue(gm.ActiveSubject,out var si)?si.color:new Color(0.38f,0.38f,0.63f);

        const int PW=160,PH=72,PX=480-160-3,PY=3;
        var DK=PixelRenderer.COL_BLACK; var WH=PixelRenderer.COL_WHITE;

        // Panel background (Gen 1 double border)
        PixelRenderer.DrawRect(PX,PY,PW,PH,DK);
        PixelRenderer.DrawRect(PX+2,PY+2,PW-4,PH-4,WH);
        PixelRenderer.DrawBorder(PX+2,PY+2,PW-4,PH-4,DK,1.5f);
        PixelRenderer.DrawRect(PX+2,PY+2,PW-4,14,new Color(wcol.r*0.25f,wcol.g*0.25f,wcol.b*0.4f));
        // Corner ornaments
        float[] corners_x={PX,PX+PW-8f}; float[] corners_y={PY,PY+PH-8f};
        foreach(float cx in corners_x) foreach(float cy in corners_y){
            PixelRenderer.DrawRect(cx,cy,8,8,DK); PixelRenderer.DrawRect(cx+2,cy+2,4,4,wcol);
        }

        // Name + Level
        PixelRenderer.DrawString(PX+7,PY+13,gm.PlayerName.ToUpper()+":Lv"+gm.Level,12,DK,true);

        // HP bar
        PixelRenderer.DrawString(PX+6,PY+26,"HP",10,DK);
        PixelRenderer.DrawHPBar(PX+22,PY+20,PW-28,8,(float)gm.HP/Mathf.Max(gm.MaxHP,1));
        if (gm.HP != gm.MaxHP)
            PixelRenderer.DrawString(PX+PW-54,PY+37,gm.HP+"/"+gm.MaxHP,9,DK);

        // XP bar
        PixelRenderer.DrawString(PX+6,PY+40,"XP",10,DK);
        PixelRenderer.DrawRect(PX+22,PY+34,PW-28,6,DK);
        PixelRenderer.DrawRect(PX+23,PY+35,PW-30,4,PixelRenderer.COL_HP_BK);
        float xpFrac=Mathf.Clamp01((float)gm.XP/Mathf.Max(gm.XPMax,1));
        PixelRenderer.DrawRect(PX+23,PY+35,(PW-30)*xpFrac,4,new Color(wcol.r*1.2f,wcol.g*1.2f,wcol.b*1.2f,1));
        PixelRenderer.DrawString(PX+6,PY+52,gm.XP+"/"+gm.XPMax,9,DK);

        // Badges
        int bdg=gm.Badges.Count;
        if(bdg>0){
            PixelRenderer.DrawRect(PX,PY+PH+2,PW,14,DK);
            PixelRenderer.DrawRect(PX+2,PY+PH+4,PW-4,10,WH);
            string bstr=""; for(int i=0;i<Mathf.Min(bdg,6);i++) bstr+="★";
            bstr+=" "+bdg+"/20";
            PixelRenderer.DrawString(PX+5,PY+PH+12,bstr,10,new Color(0.75f,0.44f,0f));
        }

        // AI diff indicator
        string bkey=gm.ActiveSubject+":"+gm.ActiveBranch;
        var summ=AdaptiveAI.Instance?.GetDiffLevel(bkey)??1;
        int streak=AdaptiveAI.Instance?.GetStreak(bkey)??0;
        int ay=PY+PH+(bdg>0?16:2);
        PixelRenderer.DrawRect(PX,ay,PW,13,DK);
        PixelRenderer.DrawRect(PX+2,ay+2,PW-4,9,new Color(0.08f,0.08f,0.16f));
        string diffStr="Diff:";
        for(int d=0;d<summ;d++) diffStr+="●";
        for(int d=summ;d<4;d++) diffStr+="○";
        PixelRenderer.DrawString(PX+5,ay+10,diffStr,9,new Color(wcol.r,wcol.g,wcol.b,1));
        if(streak>1) PixelRenderer.DrawString(PX+PW-34,ay+10,"x"+streak,9,new Color(0.97f,0.75f,0f));

        // XP notification popup
        if(_notifT>0f){
            float a=Mathf.Min(_notifT/0.3f,1f);
            float ny=60f-(1f-_notifT/NDUR)*12f;
            PixelRenderer.DrawRect(156,ny-15,168,20,new Color(0,0,0,0.65f*a));
            PixelRenderer.DrawString(164,ny,_notif.ToUpper(),13,new Color(0.35f,1f,0.35f,a),true);
        }

        PixelRenderer.EndFrame();
    }
}
