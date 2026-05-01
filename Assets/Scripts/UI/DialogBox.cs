// DialogBox.cs  –  Gen1/2 dialog system
using UnityEngine;
using System;

public class DialogBox : MonoBehaviour
{
    public static DialogBox Instance { get; private set; }
    void Awake() {
        if (Instance != null && Instance != this) { Destroy(gameObject); return; }
        Instance = this; DontDestroyOnLoad(gameObject);
    }

    public enum Context { World, Battle }

    enum State { Closed, Typing, Waiting }
    State    _state  = State.Closed;
    string[] _lines;
    int      _page;
    string   _full, _shown;
    float    _typeT, _blinkT;
    bool     _blink;
    Action   _onDone;
    public Context Ctx { get; private set; } = Context.World;

    const float CPS = 36f;  // chars per second

    public bool IsOpen => _state != State.Closed;

    public void ShowLines(string[] lines, Action onDone = null, Context ctx = Context.World)
    {
        if (_state != State.Closed) return;
        if (lines == null || lines.Length == 0) { onDone?.Invoke(); return; }
        Ctx    = ctx;
        _lines = lines; _page = 0; _onDone = onDone;
        _full  = _lines[0]; _shown = "";
        _typeT = 0f; _blink = true; _state = State.Typing;
    }

    public void ForceClose()
    {
        if (_state == State.Closed) return;
        _state = State.Closed;
        var cb = _onDone; _onDone = null; cb?.Invoke();
    }

    void Update()
    {
        if (_state == State.Closed) return;

        if (_state == State.Typing) {
            _typeT += Time.deltaTime;
            int n = Mathf.Min((int)(_typeT * CPS), _full.Length);
            _shown = _full.Substring(0, n);
            if (n >= _full.Length) _state = State.Waiting;
        } else {
            _blinkT += Time.deltaTime;
            if (_blinkT >= 0.48f) { _blinkT = 0f; _blink = !_blink; }
        }

        bool adv = Input.GetKeyDown(KeyCode.Return)
                || Input.GetKeyDown(KeyCode.KeypadEnter)
                || Input.GetKeyDown(KeyCode.Space)
                || Input.GetMouseButtonDown(0);

        if (!adv) return;
        if (_state == State.Typing)   { _shown = _full; _state = State.Waiting; return; }
        if (_state == State.Waiting) {
            _page++;
            if (_page >= _lines.Length) {
                _state = State.Closed;
                var cb = _onDone; _onDone = null; cb?.Invoke();
            } else {
                _full = _lines[_page]; _shown = ""; _typeT = 0f;
                _state = State.Typing;
            }
        }
    }

    void OnGUI()
    {
        if (_state == State.Closed) return;
        PixelRenderer.BeginFrame();
        int W = PixelRenderer.W, H = PixelRenderer.H;

        if (Ctx == Context.World) DrawWorldBox(W, H);
        else                       DrawBattleBox(W, H);

        PixelRenderer.EndFrame();
    }

    void DrawWorldBox(int W, int H)
    {
        const int BH = 80, MARGIN = 4;
        float by = H - BH - MARGIN;

        // Outer black
        PixelRenderer.DrawRect(MARGIN, by, W-MARGIN*2, BH, PixelRenderer.COL_BLACK);
        // Inner white
        PixelRenderer.DrawRect(MARGIN+2, by+2, W-MARGIN*2-4, BH-4, PixelRenderer.COL_WHITE);
        PixelRenderer.DrawBorder(MARGIN+2, by+2, W-MARGIN*2-4, BH-4, PixelRenderer.COL_BLACK, 2f);
        // Inner inset
        PixelRenderer.DrawRect(MARGIN+6, by+6, W-MARGIN*2-12, BH-12, PixelRenderer.COL_WHITE);
        PixelRenderer.DrawBorder(MARGIN+6, by+6, W-MARGIN*2-12, BH-12, PixelRenderer.COL_BLACK, 1.5f);

        // Corner gems
        float[] ccx = {MARGIN, W-MARGIN-10f};
        float[] ccy = {by, by+BH-10f};
        foreach (float cx in ccx) foreach (float cy in ccy) {
            PixelRenderer.DrawRect(cx, cy, 10, 10, PixelRenderer.COL_BLACK);
            PixelRenderer.DrawRect(cx+2, cy+2, 6, 6, PixelRenderer.COL_HP_R);
            PixelRenderer.DrawRect(cx+3, cy+3, 2, 2, new Color(1f,0.5f,0.5f));
        }

        // Text (wrap at ~450px)
        float textX = MARGIN + 14f, textY = by + 18f;
        string[] rows = _shown.Split('\n');
        for (int i = 0; i < rows.Length && i < 3; i++)
            PixelRenderer.DrawString(textX, textY + i*19, rows[i], 13, PixelRenderer.COL_BLACK);

        // Arrow
        if (_state == State.Waiting && _blink)
            DrawArrow(W - MARGIN - 18, by + BH - 14);

        // Page counter
        if (_lines.Length > 1) {
            string pg = (_page+1)+"/"+_lines.Length;
            PixelRenderer.DrawRect(W-MARGIN-34, by+4, 30, 12, new Color(0,0,0,0.55f));
            PixelRenderer.DrawString(W-MARGIN-32, by+13, pg, 10, Color.white);
        }
    }

    void DrawBattleBox(int W, int H)
    {
        // Compact top bar for battle context
        const int BH = 52;
        PixelRenderer.DrawRect(2, 2, W-4, BH, PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(4, 4, W-8, BH-4, new Color(0.96f, 0.96f, 0.93f, 0.97f));
        PixelRenderer.DrawBorder(4, 4, W-8, BH-4, PixelRenderer.COL_BLACK, 1.5f);
        PixelRenderer.DrawRect(4, 4, W-8, 10, new Color(0.12f, 0.31f, 0.63f, 0.22f));

        string[] rows = _shown.Split('\n');
        for (int i = 0; i < Mathf.Min(rows.Length, 2); i++)
            PixelRenderer.DrawString(12, 20 + i*18, rows[i], 12, PixelRenderer.COL_BLACK);

        if (_state == State.Waiting && _blink)
            PixelRenderer.DrawString(W-22, BH-12, "▶", 12, PixelRenderer.COL_BLACK);

        if (_lines.Length > 1) {
            PixelRenderer.DrawRect(W-48, 4, 42, 12, new Color(0,0,0,0.55f));
            PixelRenderer.DrawString(W-46, 14, (_page+1)+"/"+_lines.Length, 10, Color.white);
        }
    }

    void DrawArrow(float x, float y)
    {
        // Simple downward triangle cursor
        for (int i = 0; i < 6; i++)
            PixelRenderer.DrawRect(x+i, y+i/2, 6-i*2+2, 2, PixelRenderer.COL_BLACK);
    }
}
