// KaiserScreen.cs  –  Victory celebration screen
using UnityEngine;
public class KaiserScreen : MonoBehaviour
{
    float _t;
    void OnEnable() { _t = 0f; }
    void Update() { _t+=Time.deltaTime; if(_t>4f&&Input.anyKeyDown) GameScreenManager.Instance?.GoTo(GameScreen.SubjectSelect); }
    void OnGUI() {
        if(GameScreenManager.Instance?.Current!=GameScreen.Kaiser) return;
        PixelRenderer.BeginFrame();
        int W=480,H=320;
        float alpha=Mathf.Clamp01(_t/1.2f);
        PixelRenderer.DrawRect(0,0,W,H,new Color(0.02f,0.02f,0.06f));
        // Stars
        for(int i=0;i<40;i++){
            float sx2=(i*53+7)%480f,sy2=(i*37+11)%220f;
            float tw=0.5f+0.5f*Mathf.Sin(_t*1.8f+i*0.7f);
            PixelRenderer.DrawRect(sx2,sy2,2,2,new Color(1,1,1,alpha*tw));
        }
        // Gold burst
        for(int r=0;r<8;r++){
            float angle=r*Mathf.PI/4f+_t*0.5f;
            float rx=W/2f+Mathf.Cos(angle)*50f,ry=H/2f+Mathf.Sin(angle)*30f;
            PixelRenderer.DrawRect(rx-2,ry-2,4,4,new Color(1f,0.84f,0f,alpha*0.8f));
        }
        // KAISER text
        PixelRenderer.DrawRect(80,90,320,90,new Color(0,0,0,alpha*0.6f));
        PixelRenderer.DrawBorder(78,88,324,92,new Color(1f,0.84f,0f,alpha*0.9f),3f);
        PixelRenderer.DrawString(90,102,"★  KAISER  ★",42,new Color(1f,0.88f,0.20f,alpha),true);
        PixelRenderer.DrawString(130,150,GameManager.Instance?.PlayerName?.ToUpper()??"",26,Color.white,true);
        string sub=GameManager.Instance?.ActiveSubject??"";
        if(SubjectDB.Subjects.TryGetValue(sub,out var si))
            PixelRenderer.DrawString(W/2-90,185,"Master of "+si.name,14,new Color(0.75f,0.82f,1f,alpha));
        if(_t>2f) PixelRenderer.DrawString(W/2-100,H-26,"Press any key to continue",13,new Color(0.8f,0.8f,0.8f,Mathf.Sin(_t*3f)*0.5f+0.5f));
        PixelRenderer.EndFrame();
    }
}
