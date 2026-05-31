using UnityEngine;
using UnityEngine.Networking;
using System.Collections;
using System.Collections.Generic;

/// <summary>
/// AIClient — Communicates with the Python FastAPI backend for adaptive AI features.
/// </summary>
public class AIClient : MonoBehaviour
{
    public static AIClient Instance { get; private set; }

    [Header("Backend Settings")]
    public string backendUrl = "http://localhost:8000";
    public float requestTimeout = 10f;

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;
        DontDestroyOnLoad(gameObject);
    }

    /// <summary>
    /// Get adaptive difficulty recommendation from the backend.
    /// </summary>
    public void GetAdaptiveDifficulty(string playerId, System.Action<int> callback)
    {
        StartCoroutine(GetRequest($"{backendUrl}/adaptive/difficulty/{playerId}", (json) =>
        {
            if (!string.IsNullOrEmpty(json))
            {
                var response = JsonUtility.FromJson<DifficultyResponse>(json);
                callback?.Invoke(response.recommended_difficulty);
            }
            else
            {
                callback?.Invoke(GameManager.Instance.playerData.level / 5 + 1); // fallback
            }
        }));
    }

    /// <summary>
    /// Get questions from the backend.
    /// </summary>
    public void GetQuestionsFromBackend(string subject, string topic, int difficulty, int count, 
        System.Action<List<QuestionData>> callback)
    {
        string url = $"{backendUrl}/questions/{subject}/{topic}?difficulty={difficulty}&count={count}";
        StartCoroutine(GetRequest(url, (json) =>
        {
            if (!string.IsNullOrEmpty(json))
            {
                var response = JsonUtility.FromJson<QuestionFileData>(json);
                callback?.Invoke(response.questions);
            }
            else
            {
                callback?.Invoke(null);
            }
        }));
    }

    /// <summary>
    /// Submit a battle answer to the backend for tracking.
    /// </summary>
    public void SubmitAnswer(string playerId, string subject, string topic, bool correct, float responseTime)
    {
        var data = new AnswerSubmission
        {
            player_id = playerId,
            subject = subject,
            topic = topic,
            correct = correct,
            response_time = responseTime
        };

        string json = JsonUtility.ToJson(data);
        StartCoroutine(PostRequest($"{backendUrl}/answer", json, null));
    }

    /// <summary>
    /// Update player stats on the backend.
    /// </summary>
    public void UpdatePlayerStats(string playerId)
    {
        PlayerData data = GameManager.Instance.playerData;
        var stats = new PlayerStatsUpdate
        {
            player_id = playerId,
            level = data.level,
            accuracy = data.accuracy,
            total_answered = data.totalAnswered,
            total_correct = data.totalCorrect,
            streak = data.streak,
            badges = data.earnedBadges.Count
        };

        string json = JsonUtility.ToJson(stats);
        StartCoroutine(PostRequest($"{backendUrl}/player/{playerId}/update", json, null));
    }

    // ============================================================
    // HTTP HELPERS
    // ============================================================

    private IEnumerator GetRequest(string url, System.Action<string> callback)
    {
        using (UnityWebRequest request = UnityWebRequest.Get(url))
        {
            request.timeout = (int)requestTimeout;
            yield return request.SendWebRequest();

            if (request.result == UnityWebRequest.Result.Success)
            {
                callback?.Invoke(request.downloadHandler.text);
            }
            else
            {
                Debug.LogWarning($"[AIClient] GET {url} failed: {request.error}");
                callback?.Invoke(null);
            }
        }
    }

    private IEnumerator PostRequest(string url, string jsonBody, System.Action<string> callback)
    {
        using (UnityWebRequest request = new UnityWebRequest(url, "POST"))
        {
            byte[] bodyRaw = System.Text.Encoding.UTF8.GetBytes(jsonBody);
            request.uploadHandler = new UploadHandlerRaw(bodyRaw);
            request.downloadHandler = new DownloadHandlerBuffer();
            request.SetRequestHeader("Content-Type", "application/json");
            request.timeout = (int)requestTimeout;

            yield return request.SendWebRequest();

            if (request.result == UnityWebRequest.Result.Success)
            {
                callback?.Invoke(request.downloadHandler.text);
            }
            else
            {
                Debug.LogWarning($"[AIClient] POST {url} failed: {request.error}");
                callback?.Invoke(null);
            }
        }
    }
}

// ============================================================
// API DATA MODELS
// ============================================================

[System.Serializable]
public class DifficultyResponse
{
    public int recommended_difficulty;
    public float confidence;
}

[System.Serializable]
public class AnswerSubmission
{
    public string player_id;
    public string subject;
    public string topic;
    public bool correct;
    public float response_time;
}

[System.Serializable]
public class PlayerStatsUpdate
{
    public string player_id;
    public int level;
    public float accuracy;
    public int total_answered;
    public int total_correct;
    public int streak;
    public int badges;
}
