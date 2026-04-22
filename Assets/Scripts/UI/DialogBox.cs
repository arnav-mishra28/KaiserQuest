// DialogBox.cs — Context-aware Gen 1/2 Dialog Box
// World context = bottom bar (80px)  |  Battle context = top compact (44px)
using UnityEngine;
using System.Collections.Generic;
using System;

public class DialogBox : MonoBehaviour
{
    public static DialogBox Instance { get; private set; }
    void Awake() { if(Instance!=null&&Instance!=this){Destroy(gameObject);return;}Instance=this;DontDestroyOnLoad(gameObject); }

    public enum Context { World, Battle }
    public Context CurrentContext { get; set; } = Context.World;

    enum State { Closed, Typing, Waiting }
    State  _state   = State.Closed;
    string[]  _lines;
    int       _page;
    string    _full, _shown;
    float     _typeT, _blinkT;
    bool      _blink;
    Action    _callback;

    const float CPS = 40f;

    public bool IsOpen => _state != State.Closed;

    // ── Notify player that dialog is open/closed ──────────────────────────────
    public event Action<bool> DialogStateChanged;

    public void ShowLines(string[] lines, Action callback = null, Context ctx = Context.World)
    {
        if (_state != State.Closed) return;
        if (lines == null || lines.Length == 0) { callback?.Invoke(); return; }
        CurrentContext = ctx;
        _lines = lines; _page = 0; _callback = callback;
        _full = _lines[0]; _shown = ""; _typeT = 0f; _blink = true;
        _state = State.Typing;
        DialogStateChanged?.Invoke(true);
    }

    public void Close()
    {
        if (_state == State.Closed) return;
        _state = State.Closed;
        DialogStateChanged?.Invoke(false);
        var cb = _callback; _callback = null; cb?.Invoke();
    }

    void Update()
    {
        if (_state == State.Closed) return;
        if (_state == State.Typing) {
            _typeT += Time.deltaTime;
            int n = (int)(_typeT * CPS);
            if (n >= _full.Length) { _shown = _full; _state = State.Waiting; }
            else _shown = _full.Substring(0, n);
        } else if (_state == State.Waiting) {
            _blinkT += Time.deltaTime;
            if (_blinkT >= 0.5f) { _blinkT = 0f; _blink = !_blink; }
        }

        if (Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.KeypadEnter) ||
            Input.GetKeyDown(KeyCode.Space)  || Input.GetMouseButtonDown(0)) {
            if (_state == State.Typing) { _shown = _full; _state = State.Waiting; }
            else if (_state == State.Waiting) {
                _page++;
                if (_page >= _lines.Length) Close();
                else { _full=_lines[_page]; _shown=""; _typeT=0f; _state=State.Typing; }
            }
        }
    }

    void OnGUI()
    {
        if (_state == State.Closed) return;
        PixelRenderer.BeginFrame();
        int W=PixelRenderer.W, H=PixelRenderer.H;
        if (CurrentContext == Context.Battle) DrawBattle(W, H);
        else DrawWorld(W, H);
        PixelRenderer.EndFrame();
    }

    void DrawWorld(int W, int H)
    {
        const int BH=80;
        int by=H-BH-2;
        // Outer border
        PixelRenderer.DrawRect(2,by,W-4,BH,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(4,by+2,W-8,BH-4,PixelRenderer.COL_WHITE);
        PixelRenderer.DrawBorder(4,by+2,W-8,BH-4,PixelRenderer.COL_BLACK,2f);
        PixelRenderer.DrawRect(8,by+6,W-16,BH-12,PixelRenderer.COL_WHITE);
        PixelRenderer.DrawBorder(8,by+6,W-16,BH-12,PixelRenderer.COL_BLACK,1.5f);
        // Corner ornaments
        float[] cx={2f,W-10f}; float[] cy2={by,by+BH-10f};
        foreach(float cx2 in cx) foreach(float cy in cy2) {
            PixelRenderer.DrawRect(cx2,cy,10,10,PixelRenderer.COL_BLACK);
            PixelRenderer.DrawRect(cx2+2,cy+2,6,6,PixelRenderer.COL_HP_R);
        }
        // Text
        var rows=_shown.Split('\n');
        for(int i=0;i<rows.Length;i++)
            PixelRenderer.DrawString(18,by+18+i*18,rows[i].ToUpper(),13,PixelRenderer.COL_BLACK);
        // Arrow
        if(_state==State.Waiting && _blink)
            DrawArrow(W-20,by+BH-14,W-10,by+BH-14,W-15,by+BH-8);
        // Page counter
        if(_lines.Length>1)
            PixelRenderer.DrawString(W-52,by+8,(_page+1)+"/"+_lines.Length,9,new Color(0.38f,0.38f,0.38f));
    }

    void DrawBattle(int W, int H)
    {
        const int BH=44, BY=2;
        PixelRenderer.DrawRect(2,BY,W-4,BH,PixelRenderer.COL_BLACK);
        PixelRenderer.DrawRect(4,BY+2,W-8,BH-4,new Color(0.94f,0.94f,0.91f,0.97f));
        PixelRenderer.DrawBorder(4,BY+2,W-8,BH-4,PixelRenderer.COL_BLACK,1.5f);
        PixelRenderer.DrawRect(4,BY+2,W-8,10,new Color(0.12f,0.31f,0.63f,0.25f));
        var rows=_shown.Split('\n');
        for(int i=0;i<Mathf.Min(rows.Length,2);i++)
            PixelRenderer.DrawString(14,BY+12+i*16,rows[i].ToUpper(),12,PixelRenderer.COL_BLACK);
        if(_state==State.Waiting&&_blink)
            PixelRenderer.DrawString(W-22,BY+BH-8,"▶",12,PixelRenderer.COL_BLACK);
        if(_lines.Length>1){
            PixelRenderer.DrawRect(W-46,BY+2,42,12,new Color(0f,0f,0f,0.5f));
            PixelRenderer.DrawString(W-44,BY+12,(_page+1)+"/"+_lines.Length,9,Color.white);
        }
    }

    void DrawArrow(float x1,float y1,float x2,float y2,float x3,float y3)
    {
        // Filled triangle for continue arrow
        for(float y=y1;y<=y3;y++){
            float t=(y-y1)/(y3-y1);
            float lx=Mathf.Lerp(x1,x3,t), rx=Mathf.Lerp(x2,x3,t);
            if(rx<lx)(lx,rx)=(rx,lx);
            PixelRenderer.DrawRect(lx,y,rx-lx,1,PixelRenderer.COL_BLACK);
        }
    }
}
