// BackendClient.cs — Python Backend Integration (WebSocket PvP + Voice AI + REST)
using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;

#if !UNITY_WEBGL || UNITY_EDITOR
using System.Net.WebSockets;
using System.Threading;
using System.Threading.Tasks;
#endif

public class BackendClient : MonoBehaviour
{
    public static BackendClient Instance { get; private set; }
    void Awake() { if(Instance!=null&&Instance!=this){Destroy(gameObject);return;}Instance=this;DontDestroyOnLoad(gameObject); }

    [Header("Backend Settings")]
    public string ServerURL = "http://localhost:8000";
    public string WsURL     = "ws://localhost:8000";
    public bool   Connected  = false;

    // ── Events ────────────────────────────────────────────────────────────────
    public event Action<string>           OnMatchFound;
    public event Action<QuestionPayload>  OnQuestionReceived;
    public event Action<AnswerResult>     OnAnswerResult;
    public event Action<GameOverPayload>  OnGameOver;
    public event Action<string>           OnOpponentLeft;
    public event Action<string>           OnError;

#if !UNITY_WEBGL || UNITY_EDITOR
    ClientWebSocket _ws;
    CancellationTokenSource _cts;
    readonly Queue<string> _sendQueue  = new();
    readonly Queue<string> _recvQueue  = new();
#endif

    // ── REST helpers ──────────────────────────────────────────────────────────
    public IEnumerator CheckHealth(Action<bool> callback)
    {
        using var req=new UnityEngine.Networking.UnityWebRequest(ServerURL+"/health","GET");
        req.downloadHandler=new UnityEngine.Networking.DownloadHandlerBuffer();
        yield return req.SendWebRequest();
        bool ok=req.result==UnityEngine.Networking.UnityWebRequest.Result.Success;
        Connected=ok; callback?.Invoke(ok);
    }

    public IEnumerator GetLeaderboard(Action<string> callback)
    {
        using var req=UnityEngine.Networking.UnityWebRequest.Get(ServerURL+"/leaderboard");
        yield return req.SendWebRequest();
        if(req.result==UnityEngine.Networking.UnityWebRequest.Result.Success)
            callback?.Invoke(req.downloadHandler.text);
    }

    public IEnumerator SubmitScore(string playerName,int score,string subject,string branch,int badges)
    {
        string json=$"{{\"name\":\"{playerName}\",\"score\":{score},\"subject\":\"{subject}\",\"branch\":\"{branch}\",\"badges\":{badges}}}";
        var bytes=Encoding.UTF8.GetBytes(json);
        using var req=new UnityEngine.Networking.UnityWebRequest(ServerURL+"/leaderboard/submit","POST");
        req.uploadHandler=new UnityEngine.Networking.UploadHandlerRaw(bytes);
        req.downloadHandler=new UnityEngine.Networking.DownloadHandlerBuffer();
        req.SetRequestHeader("Content-Type","application/json");
        yield return req.SendWebRequest();
    }

    public IEnumerator GetNPCResponse(string npcName,string role,string message,int level,List<string> weakTopics,Action<string> callback)
    {
        string weakJson="["+string.Join(",",weakTopics.ConvertAll(t=>"\""+t+"\""))+"]";
        string json=$"{{\"npc_name\":\"{npcName}\",\"npc_role\":\"{role}\",\"message\":\"{message}\",\"player_level\":{level},\"weak_topics\":{weakJson}}}";
        var bytes=Encoding.UTF8.GetBytes(json);
        using var req=new UnityEngine.Networking.UnityWebRequest(ServerURL+"/npc/respond","POST");
        req.uploadHandler=new UnityEngine.Networking.UploadHandlerRaw(bytes);
        req.downloadHandler=new UnityEngine.Networking.DownloadHandlerBuffer();
        req.SetRequestHeader("Content-Type","application/json");
        yield return req.SendWebRequest();
        if(req.result==UnityEngine.Networking.UnityWebRequest.Result.Success){
            var resp=JsonUtility.FromJson<NPCResponse>(req.downloadHandler.text);
            callback?.Invoke(resp?.response??"...");
        }
    }

    public IEnumerator TextToSpeech(string text,Action<AudioClip> callback)
    {
        string json=$"{{\"text\":\"{text}\",\"lang\":\"en\"}}";
        var bytes=Encoding.UTF8.GetBytes(json);
        using var req=new UnityEngine.Networking.UnityWebRequest(ServerURL+"/voice/speak","POST");
        req.uploadHandler=new UnityEngine.Networking.UploadHandlerRaw(bytes);
        req.downloadHandler=new UnityEngine.Networking.DownloadHandlerAudioClip(ServerURL+"/voice/speak",AudioType.MPEG);
        req.SetRequestHeader("Content-Type","application/json");
        yield return req.SendWebRequest();
        if(req.result==UnityEngine.Networking.UnityWebRequest.Result.Success)
            callback?.Invoke(((UnityEngine.Networking.DownloadHandlerAudioClip)req.downloadHandler).audioClip);
    }

    public IEnumerator GenerateWorld(int width,int height,int seed,string subject,string branch,Action<string> callback)
    {
        string url=$"{ServerURL}/world/generate?width={width}&height={height}&seed={seed}&subject={subject}&branch={branch}";
        using var req=UnityEngine.Networking.UnityWebRequest.Get(url);
        yield return req.SendWebRequest();
        if(req.result==UnityEngine.Networking.UnityWebRequest.Result.Success)
            callback?.Invoke(req.downloadHandler.text);
    }

    // ── WebSocket PvP ─────────────────────────────────────────────────────────
    public void ConnectPvP(string playerName, string world)
    {
#if !UNITY_WEBGL || UNITY_EDITOR
        _ = ConnectAsync(playerName, world);
#else
        Debug.LogWarning("WebSockets not supported on WebGL.");
#endif
    }

#if !UNITY_WEBGL || UNITY_EDITOR
    async Task ConnectAsync(string playerName, string world)
    {
        try {
            _cts = new CancellationTokenSource();
            _ws  = new ClientWebSocket();
            var uri = new Uri($"{WsURL}/pvp/{Uri.EscapeDataString(playerName)}?world={Uri.EscapeDataString(world)}");
            await _ws.ConnectAsync(uri, _cts.Token);
            _ = ReceiveLoop();
        } catch(Exception e) { OnError?.Invoke("Connection failed: "+e.Message); }
    }

    async Task ReceiveLoop()
    {
        var buf=new byte[4096];
        while(_ws.State==WebSocketState.Open){
            try {
                var seg=new ArraySegment<byte>(buf);
                var result=await _ws.ReceiveAsync(seg,_cts.Token);
                if(result.MessageType==WebSocketMessageType.Close){_ws.CloseAsync(WebSocketCloseStatus.NormalClosure,"",CancellationToken.None);break;}
                string msg=Encoding.UTF8.GetString(buf,0,result.Count);
                lock(_recvQueue) _recvQueue.Enqueue(msg);
            } catch { break; }
        }
    }
#endif

    void Update()
    {
#if !UNITY_WEBGL || UNITY_EDITOR
        // Process messages on main thread
        while(true){
            string msg=null;
            lock(_recvQueue){if(_recvQueue.Count>0)msg=_recvQueue.Dequeue();}
            if(msg==null) break;
            ProcessMessage(msg);
        }
        // Send queued messages
        if(_ws!=null&&_ws.State==WebSocketState.Open){
            while(true){
                string msg=null;
                lock(_sendQueue){if(_sendQueue.Count>0)msg=_sendQueue.Dequeue();}
                if(msg==null)break;
                _ = SendAsync(msg);
            }
        }
#endif
    }

    void ProcessMessage(string json)
    {
        try {
            var base_msg=JsonUtility.FromJson<BaseMsg>(json);
            switch(base_msg?.type){
                case "match_found":   OnMatchFound?.Invoke(json); break;
                case "waiting":       Debug.Log("PvP: Waiting for opponent..."); break;
                case "question":      OnQuestionReceived?.Invoke(JsonUtility.FromJson<QuestionPayload>(json)); break;
                case "answer_result": OnAnswerResult?.Invoke(JsonUtility.FromJson<AnswerResult>(json)); break;
                case "game_over":     OnGameOver?.Invoke(JsonUtility.FromJson<GameOverPayload>(json)); break;
                case "opponent_left": OnOpponentLeft?.Invoke(base_msg.player??"opponent"); break;
            }
        } catch(Exception e) { Debug.LogWarning("PvP parse error: "+e.Message); }
    }

    public void SendAnswer(int answerIdx)
    {
#if !UNITY_WEBGL || UNITY_EDITOR
        lock(_sendQueue) _sendQueue.Enqueue($"{{\"type\":\"answer\",\"idx\":{answerIdx}}}");
#endif
    }

#if !UNITY_WEBGL || UNITY_EDITOR
    async Task SendAsync(string msg)
    {
        try {
            var bytes=Encoding.UTF8.GetBytes(msg);
            await _ws.SendAsync(new ArraySegment<byte>(bytes),WebSocketMessageType.Text,true,_cts?.Token??CancellationToken.None);
        } catch { }
    }
#endif

    public void Disconnect()
    {
#if !UNITY_WEBGL || UNITY_EDITOR
        _cts?.Cancel();
        _ws?.CloseAsync(WebSocketCloseStatus.NormalClosure,"",CancellationToken.None);
#endif
    }

    void OnDestroy() => Disconnect();

    // ── Payload types ─────────────────────────────────────────────────────────
    [Serializable] public class BaseMsg       { public string type; public string player; }
    [Serializable] public class NPCResponse   { public string response; public string npc; }
    [Serializable] public class QuestionPayload { public string type; public int idx; public int total; public string q; public string[] opts; public string topic; }
    [Serializable] public class AnswerResult  { public string type; public string player; public bool correct; public int damage; public int combo; }
    [Serializable] public class GameOverPayload{ public string type; public string winner; public string loser; }
}
