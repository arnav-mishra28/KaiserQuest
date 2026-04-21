// AdaptiveAI.cs — Adaptive Learning Engine
using UnityEngine;
using System.Collections.Generic;
using System.IO;

public class AdaptiveAI : MonoBehaviour
{
    public static AdaptiveAI Instance { get; private set; }

    void Awake() {
        if (Instance != null && Instance != this) { Destroy(gameObject); return; }
        Instance = this; DontDestroyOnLoad(gameObject); Load();
    }

    // ── Data ──────────────────────────────────────────────────────────────────
    private Dictionary<string, AIData> _data = new();

    void Ensure(string key) {
        if (!_data.ContainsKey(key))
            _data[key] = new AIData();
    }

    AIData D(string key) { Ensure(key); return _data[key]; }

    // ── Session ───────────────────────────────────────────────────────────────
    private string _sessionKey = "";
    private List<SessionEntry> _session = new();
    private float  _qStart  = 0f;

    public void StartSession(string key) {
        _sessionKey = key; _session.Clear();
        _qStart = Time.realtimeSinceStartup;
    }

    public void RecordAnswer(string topic, bool correct) {
        float ms = (Time.realtimeSinceStartup - _qStart) * 1000f;
        _qStart = Time.realtimeSinceStartup;
        _session.Add(new SessionEntry { topic = topic, correct = correct, ms = ms });
        if (!string.IsNullOrEmpty(_sessionKey)) {
            var d = D(_sessionKey);
            d.streak = correct ? d.streak + 1 : 0;
            d.bestStreak = Mathf.Max(d.bestStreak, d.streak);
        }
    }

    public Dictionary<string, object> EndSession() {
        if (string.IsNullOrEmpty(_sessionKey) || _session.Count == 0)
            return new Dictionary<string, object>();
        var d = D(_sessionKey);
        d.sessions++;
        float totalMs = 0f; int correct = 0;
        foreach (var s in _session) {
            totalMs += s.ms; d.totalQ++;
            if (s.correct) { d.totalCorrect++; correct++; }
            if (!d.topicAcc.ContainsKey(s.topic)) d.topicAcc[s.topic] = new int[]{0,0};
            d.topicAcc[s.topic][1]++;
            if (s.correct) d.topicAcc[s.topic][0]++;
        }
        if (_session.Count > 0) d.avgMs = Mathf.Lerp(d.avgMs, totalMs / _session.Count, 0.25f);
        float acc = (float)correct / Mathf.Max(_session.Count, 1);
        if (acc >= 0.85f && d.diffLevel < 4) d.diffLevel++;
        else if (acc < 0.40f && d.diffLevel > 1) d.diffLevel--;
        float speedBonus = Mathf.Clamp01((5000f - d.avgMs) / 5000f);
        d.xpMult = 1f + speedBonus * 0.75f + acc * 0.75f;
        Save();
        return new Dictionary<string, object> {
            {"correct", correct}, {"total", _session.Count}, {"accuracy", acc},
            {"xpMult", d.xpMult}, {"streak", d.streak}, {"difficulty", d.diffLevel},
            {"weak", GetWeakTopics(_sessionKey)}
        };
    }

    // ── Queries ───────────────────────────────────────────────────────────────
    public List<string> GetWeakTopics(string key) {
        Ensure(key); var weak = new List<string>();
        foreach (var kv in D(key).topicAcc)
            if ((float)kv.Value[0] / Mathf.Max(kv.Value[1], 1) < 0.60f) weak.Add(kv.Key);
        return weak;
    }

    public float GetAccuracy(string key) {
        Ensure(key); var d = D(key);
        return (float)d.totalCorrect / Mathf.Max(d.totalQ, 1);
    }

    public int GetDiffLevel(string key) { Ensure(key); return D(key).diffLevel; }
    public float GetXPMult(string key)  { Ensure(key); return D(key).xpMult; }
    public int GetStreak(string key)    { Ensure(key); return D(key).streak; }

    public string GetExplanationLevel(string key) {
        float acc = GetAccuracy(key);
        if (acc < 0.40f) return "beginner";
        if (acc < 0.70f) return "intermediate";
        return "advanced";
    }

    public static List<QuestionData> AdaptiveSelect(List<QuestionData> questions, string key, int playerLevel, int count)
    {
        if (questions == null || questions.Count == 0) return new List<QuestionData>();
        var weak    = Instance != null ? Instance.GetWeakTopics(key) : new List<string>();
        int maxDiff = Mathf.Clamp(playerLevel / 5 + 2, 1, 4);
        var hi = new List<QuestionData>();
        var lo = new List<QuestionData>();
        foreach (var q in questions) {
            if (q.difficulty > maxDiff) continue;
            if (weak.Contains(q.topic)) hi.Add(q);
            else lo.Add(q);
        }
        // Shuffle
        for (int i = hi.Count-1; i>0; i--){var j=Random.Range(0,i+1);(hi[j],hi[i])=(hi[i],hi[j]);}
        for (int i = lo.Count-1; i>0; i--){var j=Random.Range(0,i+1);(lo[j],lo[i])=(lo[i],lo[j]);}
        var pool = new List<QuestionData>(hi); pool.AddRange(lo);
        if (pool.Count < count) {
            var all = new List<QuestionData>(questions);
            for (int i=all.Count-1;i>0;i--){var j=Random.Range(0,i+1);(all[j],all[i])=(all[i],all[j]);}
            foreach (var q in all) if (!pool.Contains(q)) pool.Add(q);
        }
        return pool.GetRange(0, Mathf.Min(count, pool.Count));
    }

    // ── Predict ───────────────────────────────────────────────────────────────
    public float PredictSuccess(string key, string topic, int difficulty) {
        float acc   = GetAccuracy(key);
        float speed = Mathf.Clamp01((5000f - D(key).avgMs) / 5000f);
        float x     = acc * 0.7f + speed * 0.3f - (difficulty - 1) * 0.22f;
        return 1f / (1f + Mathf.Exp(-8f * (x - 0.5f)));
    }

    // ── Save / Load ───────────────────────────────────────────────────────────
    private string AIPath => Path.Combine(Application.persistentDataPath, "kq_ai.json");

    void Save() {
        var entries = new List<AIEntry>();
        foreach (var kv in _data) entries.Add(new AIEntry{key=kv.Key, data=kv.Value});
        File.WriteAllText(AIPath, JsonUtility.ToJson(new AIFile{entries=entries}, true));
    }

    void Load() {
        if (!File.Exists(AIPath)) return;
        try {
            var file = JsonUtility.FromJson<AIFile>(File.ReadAllText(AIPath));
            if (file?.entries == null) return;
            foreach (var e in file.entries) _data[e.key] = e.data;
        } catch { }
    }

    [System.Serializable] class SessionEntry { public string topic; public bool correct; public float ms; }
    [System.Serializable] class AIEntry      { public string key; public AIData data; }
    [System.Serializable] class AIFile       { public List<AIEntry> entries; }
}

[System.Serializable]
public class AIData
{
    public int   sessions    = 0;
    public int   totalCorrect= 0;
    public int   totalQ      = 0;
    public float avgMs       = 5000f;
    public int   diffLevel   = 1;
    public int   streak      = 0;
    public int   bestStreak  = 0;
    public float xpMult      = 1f;
    public SerializableTopicAcc topicAcc = new();
}

[System.Serializable]
public class SerializableTopicAcc : Dictionary<string, int[]>, ISerializationCallbackReceiver
{
    [SerializeField] private List<string>    _keys   = new();
    [SerializeField] private List<IntPair>   _values = new();
    public void OnBeforeSerialize() {
        _keys.Clear(); _values.Clear();
        foreach (var kv in this) { _keys.Add(kv.Key); _values.Add(new IntPair{a=kv.Value[0],b=kv.Value[1]}); }
    }
    public void OnAfterDeserialize() {
        Clear();
        for (int i=0;i<_keys.Count;i++) this[_keys[i]] = new[]{_values[i].a,_values[i].b};
    }
    [System.Serializable] struct IntPair { public int a, b; }
}
