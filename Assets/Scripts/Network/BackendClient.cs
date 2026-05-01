// BackendClient.cs  –  Optional Python backend bridge (WebSocket)
// Works without server — all local fallback.
using UnityEngine;
using System.Collections;

public class BackendClient : MonoBehaviour
{
    public static BackendClient Instance { get; private set; }
    void Awake() {
        if (Instance != null && Instance != this) { Destroy(gameObject); return; }
        Instance = this; DontDestroyOnLoad(gameObject);
    }

    public bool IsConnected { get; private set; } = false;
    const string SERVER_URL = "ws://localhost:8765";

    void Start() => StartCoroutine(TryConnect());

    IEnumerator TryConnect()
    {
        yield return new WaitForSeconds(1.5f);
        // In a real build, instantiate NativeWebSocket or BestHTTP here.
        // For now, offline mode — all AI is handled locally by AdaptiveAI.cs.
        Debug.Log("[BackendClient] Running in offline mode (no server required).");
        IsConnected = false;
    }

    public void SendSessionData(string worldKey, float accuracy, int level)
    {
        if (!IsConnected) return;
        // Would send JSON payload to Python FastAPI server
    }
}
