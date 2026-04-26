// HUD.cs — Gen 1/2 Stats Overlay (improved text sizing + contrast)
using UnityEngine;

public class HUD : MonoBehaviour
{
    public static HUD Instance { get; private set; }
    void Awake() {
        if (Instance!=null&&Instance!=this){Destroy(gameObject);return;}
        Instance=this; DontDestroyOnLoad(gameObject);
    }

    string _notif  = "";
    float  _notifT = 0f;
    float  _time   = 0f;
    const float NDUR = 2.8f;

    void Start()
    {
        if (GameManager.Instance != null) {
            GameManager.Instance.OnXPChanged   += (_,_,_) => { };
            GameManager.Instance.OnLevelUp     += lv => ShowNotif("LEVEL UP!  Lv." + lv + "!");
            GameManager.Instance.OnBadgeEarned += b  => ShowNotif(b + " EARNED!");
            GameManager.Instance.OnHPChanged   += (_,_) => { };
        }
    }

    void Update() {
        _time  += Time.deltaTime;
        if (_notifT > 0f) { _notifT -= Time.deltaTime; if (_notifT < 0f) _notifT = 0f; }
    }

    public void ShowXPGain(int amt) => ShowNotif("+" + amt + " EXP!");
    public void ShowNotif(string t) { _notif = t; _notifT = NDUR; }

    void OnGUI()
    {
        if (GameManager.Instance == null || string.IsNullOrEmpty(GameManager.Instance.ActiveSubject)) return;
        if (DialogBox.Instance != null && DialogBox.Instance.IsOpen) return;

        PixelRenderer.BeginFrame();
        var gm = GameManager.Instance;
        Color wcol = SubjectDB.Subjects.TryGetValue(gm.ActiveSubject, out var si)
            ? si.color : new Color(0.38f,0.38f,0.63f);

        const int PW=168, PH=76, PX=480-168-4, PY=4;
        var DK = PixelRenderer.COL_BLACK;
        var WH = PixelRenderer.COL_WHITE;

        // Panel shell
        PixelRenderer.DrawRect(PX,   PY,   PW,   PH,   DK);
        PixelRenderer.DrawRect(PX+2, PY+2, PW-4, PH-4, WH);
        PixelRenderer.DrawBorder(PX+2, PY+2, PW-4, PH-4, DK, 1.5f);
        // Colour accent bar
        PixelRenderer.DrawRect(PX+2, PY+2, PW-4, 15,
            new Color(wcol.r*0.22f, wcol.g*0.22f, wcol.b*0.38f));
        // Corner ornaments
        float[] cxs={PX, PX+PW-9f}; float[] cys={PY, PY+PH-9f};
        foreach (float ccx in cxs) foreach (float ccy in cys) {
            PixelRenderer.DrawRect(ccx,   ccy,   9, 9, DK);
            PixelRenderer.DrawRect(ccx+2, ccy+2, 5, 5, wcol);
        }

        // Name + Level
        PixelRenderer.DrawString(PX+7, PY+14,
            gm.PlayerName.ToUpper() + "  Lv." + gm.Level, 12, DK, true);

        // HP bar + label
        PixelRenderer.DrawString(PX+6, PY+28, "HP", 10, DK, true);
        PixelRenderer.DrawHPBar(PX+24, PY+22, PW-30, 9, (float)gm.HP / Mathf.Max(gm.MaxHP, 1));
        if (gm.HP != gm.MaxHP)
            PixelRenderer.DrawString(PX+PW-56, PY+38, gm.HP+"/"+gm.MaxHP, 9, DK);

        // XP bar + label
        PixelRenderer.DrawString(PX+6, PY+43, "XP", 10, DK, true);
        PixelRenderer.DrawRect(PX+24, PY+37, PW-30, 7, DK);
        PixelRenderer.DrawRect(PX+25, PY+38, PW-32, 5, PixelRenderer.COL_HP_BK);
        float xpFrac = Mathf.Clamp01((float)gm.XP / Mathf.Max(gm.XPMax, 1));
        PixelRenderer.DrawRect(PX+25, PY+38, (PW-32)*xpFrac, 5,
            new Color(Mathf.Min(wcol.r*1.3f,1f), Mathf.Min(wcol.g*1.3f,1f), Mathf.Min(wcol.b*1.3f,1f)));
        PixelRenderer.DrawString(PX+6, PY+56, gm.XP+"/"+gm.XPMax, 9, new Color(0.3f,0.3f,0.4f));

        // Badges row
        int bdg = gm.Badges.Count;
        if (bdg > 0) {
            int bay = PY + PH + 2;
            PixelRenderer.DrawRect(PX,   bay,   PW,   16, DK);
            PixelRenderer.DrawRect(PX+2, bay+2, PW-4, 12, WH);
            string bstr = "";
            for (int i=0; i<Mathf.Min(bdg,8); i++) bstr += "★";
            bstr += "  " + bdg + "/20";
            PixelRenderer.DrawString(PX+5, bay+12, bstr, 10, new Color(0.80f,0.50f,0f));
        }

        // AI difficulty strip
        string bkey = gm.ActiveSubject + ":" + gm.ActiveBranch;
        int diff   = AdaptiveAI.Instance?.GetDiffLevel(bkey) ?? 1;
        int streak = AdaptiveAI.Instance?.GetStreak(bkey)    ?? 0;
        int ay     = PY + PH + (bdg > 0 ? 18 : 2);
        PixelRenderer.DrawRect(PX,   ay,   PW,   14, DK);
        PixelRenderer.DrawRect(PX+2, ay+2, PW-4, 10, new Color(0.06f,0.06f,0.14f));
        string diffStr = "Diff: ";
        for (int d=0; d<diff;  d++) diffStr += "●";
        for (int d=diff; d<4; d++) diffStr += "○";
        PixelRenderer.DrawString(PX+5, ay+11, diffStr, 10, new Color(wcol.r, wcol.g, wcol.b, 1f));
        if (streak > 1)
            PixelRenderer.DrawString(PX+PW-36, ay+11, "x"+streak, 10, PixelRenderer.COL_GOLD);

        // XP gain popup
        if (_notifT > 0f) {
            float alpha = Mathf.Min(_notifT / 0.3f, 1f);
            float ny = 55f - (1f - _notifT/NDUR) * 14f;
            float nw = _notif.Length * 7.5f + 24f;
            PixelRenderer.DrawRect(164f, ny-16f, nw, 22f, new Color(0f,0f,0f,0.72f*alpha));
            PixelRenderer.DrawBorder(165f, ny-15f, nw-2f, 20f, PixelRenderer.COL_GOLD, 1f);
            PixelRenderer.DrawString(172f, ny, _notif.ToUpper(), 13,
                new Color(0.30f, 1f, 0.30f, alpha), true);
        }

        PixelRenderer.EndFrame();
    }
}
