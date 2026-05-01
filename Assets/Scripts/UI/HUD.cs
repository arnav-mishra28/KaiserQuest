// HUD.cs  –  Player stats overlay (top-right corner)
using UnityEngine;

public class HUD : MonoBehaviour
{
    public static HUD Instance { get; private set; }
    void Awake() {
        if (Instance != null && Instance != this) { Destroy(gameObject); return; }
        Instance = this; DontDestroyOnLoad(gameObject);
    }

    string _notif  = "";
    float  _notifT = 0f;
    const float NOTIF_DUR = 2.8f;

    void Start()
    {
        if (GameManager.Instance != null) {
            GameManager.Instance.OnLevelUp     += lv => ShowNotif("LEVEL UP!  Lv." + lv + "!");
            GameManager.Instance.OnBadgeEarned += b  => ShowNotif(b + " BADGE!");
        }
    }

    public void ShowXPGain(int amt) => ShowNotif("+" + amt + " EXP!");
    public void ShowNotif(string t) { _notif = t; _notifT = NOTIF_DUR; }

    void Update()
    {
        if (_notifT > 0f) _notifT = Mathf.Max(0f, _notifT - Time.deltaTime);
    }

    void OnGUI()
    {
        var gm = GameManager.Instance;
        if (gm == null || string.IsNullOrEmpty(gm.ActiveSubject)) return;
        if (DialogBox.Instance?.IsOpen == true &&
            DialogBox.Instance.Ctx == DialogBox.Context.Battle) return;

        PixelRenderer.BeginFrame();
        int W = PixelRenderer.W;

        Color wc = SubjectDB.Subjects.TryGetValue(gm.ActiveSubject, out var si)
                   ? si.color : new Color(0.38f, 0.38f, 0.63f);

        const int PX = 480-164, PY = 3, PW = 161, PH = 72;

        // Panel
        PixelRenderer.DrawRect(PX,   PY,   PW,   PH,   PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(PX+2, PY+2, PW-4, PH-4, PixelRenderer.COL_WHITE);
        PixelRenderer.DrawBorder(PX+2, PY+2, PW-4, PH-4, PixelRenderer.COL_BLACK, 1.5f);
        // Colour bar
        PixelRenderer.DrawRect(PX+2, PY+2, PW-4, 14,
            new Color(wc.r*0.22f, wc.g*0.22f, wc.b*0.40f));

        PixelRenderer.DrawString(PX+6, PY+13,
            gm.PlayerName.ToUpper() + "  Lv." + gm.Level, 12, PixelRenderer.COL_BLACK, true);

        // HP
        PixelRenderer.DrawString(PX+5, PY+28, "HP", 10, PixelRenderer.COL_BLACK, true);
        PixelRenderer.DrawHPBar(PX+22, PY+22, PW-28, 8, (float)gm.HP / Mathf.Max(gm.MaxHP, 1));
        PixelRenderer.DrawString(PX+PW-58, PY+37, gm.HP+"/"+gm.MaxHP, 9, PixelRenderer.COL_BLACK);

        // XP bar
        PixelRenderer.DrawString(PX+5, PY+43, "XP", 10, PixelRenderer.COL_BLACK, true);
        PixelRenderer.DrawRect(PX+22, PY+37, PW-28, 6, PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(PX+23, PY+38, PW-30, 4, PixelRenderer.COL_HP_BK);
        float xpF = Mathf.Clamp01((float)gm.XP / Mathf.Max(gm.XPMax, 1));
        PixelRenderer.DrawRect(PX+23, PY+38, (PW-30)*xpF, 4,
            new Color(Mathf.Min(wc.r*1.3f,1f), Mathf.Min(wc.g*1.3f,1f), Mathf.Min(wc.b*1.3f,1f)));
        PixelRenderer.DrawString(PX+5, PY+55, gm.XP+"/"+gm.XPMax+" XP", 9,
            new Color(0.3f,0.3f,0.4f));

        // Badges
        int bdg = gm.Badges.Count;
        if (bdg > 0) {
            int by2 = PY + PH + 1;
            PixelRenderer.DrawRect(PX,   by2,   PW,   14, PixelRenderer.COL_BLACK);
            PixelRenderer.DrawRect(PX+2, by2+2, PW-4, 10, PixelRenderer.COL_WHITE);
            string bs = "";
            for (int i=0; i<Mathf.Min(bdg,8); i++) bs += "★";
            bs += "  " + bdg + "/20";
            PixelRenderer.DrawString(PX+5, by2+11, bs, 10, new Color(0.80f,0.50f,0f));
        }

        // XP popup
        if (_notifT > 0f) {
            float alpha = Mathf.Min(_notifT/0.35f, 1f);
            float ny = 58f - (1f-_notifT/NOTIF_DUR)*12f;
            float nw = _notif.Length * 7f + 20f;
            PixelRenderer.DrawRect(PX-nw-8, ny-14, nw+4, 20, new Color(0,0,0,0.7f*alpha));
            PixelRenderer.DrawBorder(PX-nw-7, ny-13, nw+2, 18, PixelRenderer.COL_GOLD, 1f);
            PixelRenderer.DrawString(PX-nw-4, ny, _notif, 13,
                new Color(0.35f, 1f, 0.35f, alpha), true);
        }

        PixelRenderer.EndFrame();
    }
}
