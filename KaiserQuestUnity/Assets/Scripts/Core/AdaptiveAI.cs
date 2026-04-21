// AdaptiveAI.cs — Adaptive Learning Engine (Singleton)
using UnityEngine;
using System.Collections.Generic;
using System.IO;

public class AdaptiveAI : MonoBehaviour
{
    public static AdaptiveAI Instance { get; private set; }
    void Awake() {
        if(Instance!=null&&Instance!=this){Destroy(gameObject);return;}
        Instance=this; DontDestroyOnLoad(gameObject); Load();
    }

    // ── Data store (Dictionary<key, AIData>) ──────────────────────────────────
    private Dictionary<string,AIData> _data = new();

    void Ensure(string key){if(!_data.ContainsKey(key))_data[key]=new AIData();}
    AIData D(string key){Ensure(key);return _data[key];}

    // ── Session ───────────────────────────────────────────────────────────────
    private string _sessionKey="";
    private List<SEntry> _session=new();
    private float _qStart=0f;
    private struct SEntry{public string topic;public bool correct;public float ms;}

    public void StartSession(string key){
        _sessionKey=key;_session.Clear();_qStart=Time.realtimeSinceStartup;
    }

    public void RecordAnswer(string topic,bool correct){
        float ms=(Time.realtimeSinceStartup-_qStart)*1000f;
        _qStart=Time.realtimeSinceStartup;
        _session.Add(new SEntry{topic=topic,correct=correct,ms=ms});
        if(!string.IsNullOrEmpty(_sessionKey)){
            var d=D(_sessionKey);
            d.streak=correct?d.streak+1:0;
            d.bestStreak=Mathf.Max(d.bestStreak,d.streak);
        }
    }

    public Dictionary<string,object> EndSession(){
        if(string.IsNullOrEmpty(_sessionKey)||_session.Count==0)
            return new Dictionary<string,object>();
        var d=D(_sessionKey);d.sessions++;
        float totalMs=0f;int correct=0;
        foreach(var s in _session){
            totalMs+=s.ms;d.totalQ++;
            if(s.correct){d.totalCorrect++;correct++;}
            if(!d.topicCorrect.ContainsKey(s.topic)){d.topicCorrect[s.topic]=0;d.topicTotal[s.topic]=0;}
            d.topicTotal[s.topic]++;
            if(s.correct)d.topicCorrect[s.topic]++;
        }
        if(_session.Count>0)d.avgMs=Mathf.Lerp(d.avgMs,totalMs/_session.Count,0.25f);
        float acc=(float)correct/Mathf.Max(_session.Count,1);
        if(acc>=0.85f&&d.diffLevel<4)d.diffLevel++;
        else if(acc<0.40f&&d.diffLevel>1)d.diffLevel--;
        float spd=Mathf.Clamp01((5000f-d.avgMs)/5000f);
        d.xpMult=1f+spd*0.75f+acc*0.75f;
        Save();
        var weak=GetWeakTopics(_sessionKey);
        return new Dictionary<string,object>{{"correct",correct},{"total",_session.Count},
            {"accuracy",acc},{"xpMult",d.xpMult},{"streak",d.streak},{"difficulty",d.diffLevel},{"weak",weak}};
    }

    // ── Queries ───────────────────────────────────────────────────────────────
    public List<string> GetWeakTopics(string key){
        Ensure(key);var weak=new List<string>();
        var d=D(key);
        foreach(var kv in d.topicTotal)
            if((float)d.topicCorrect.GetValueOrDefault(kv.Key,0)/Mathf.Max(kv.Value,1)<0.60f)
                weak.Add(kv.Key);
        return weak;
    }

    public float GetAccuracy(string key){
        Ensure(key);var d=D(key);
        return(float)d.totalCorrect/Mathf.Max(d.totalQ,1);
    }

    public int   GetDiffLevel(string key){Ensure(key);return D(key).diffLevel;}
    public float GetXPMult(string key)  {Ensure(key);return D(key).xpMult;}
    public int   GetStreak(string key)  {Ensure(key);return D(key).streak;}

    public string GetExplanationLevel(string key){
        float acc=GetAccuracy(key);
        if(acc<0.40f)return"beginner";if(acc<0.70f)return"intermediate";return"advanced";
    }

    // ── Adaptive question selection ────────────────────────────────────────────
    public static List<QuestionData> AdaptiveSelect(List<QuestionData> questions,string key,int playerLevel,int count)
    {
        if(questions==null||questions.Count==0)return new List<QuestionData>();
        var weak=Instance!=null?Instance.GetWeakTopics(key):new List<string>();
        int maxDiff=Mathf.Clamp(playerLevel/5+2,1,4);
        var hi=new List<QuestionData>();var lo=new List<QuestionData>();
        foreach(var q in questions){
            if(q.difficulty>maxDiff)continue;
            if(weak.Contains(q.topic))hi.Add(q);else lo.Add(q);
        }
        Shuffle(hi);Shuffle(lo);
        var pool=new List<QuestionData>(hi);pool.AddRange(lo);
        if(pool.Count<count){
            var all=new List<QuestionData>(questions);Shuffle(all);
            foreach(var q in all)if(!pool.Contains(q))pool.Add(q);
        }
        return pool.GetRange(0,Mathf.Min(count,pool.Count));
    }

    static void Shuffle<T>(List<T> l){for(int i=l.Count-1;i>0;i--){int j=Random.Range(0,i+1);(l[j],l[i])=(l[i],l[j]);}}

    public float PredictSuccess(string key,string topic,int difficulty){
        float acc=GetAccuracy(key);var d=D(key);
        float spd=Mathf.Clamp01((5000f-d.avgMs)/5000f);
        float x=acc*0.7f+spd*0.3f-(difficulty-1)*0.22f;
        return 1f/(1f+Mathf.Exp(-8f*(x-0.5f)));
    }

    // ── Save / Load (uses simple JSON with flat arrays) ────────────────────────
    string AIPath=>Path.Combine(Application.persistentDataPath,"kq_ai.json");

    void Save(){
        var wrapper=new SaveWrapper();
        foreach(var kv in _data){
            wrapper.keys.Add(kv.Key);
            wrapper.vals.Add(kv.Value.Serialize());
        }
        File.WriteAllText(AIPath,JsonUtility.ToJson(wrapper,true));
    }

    void Load(){
        if(!File.Exists(AIPath))return;
        try{
            var wrapper=JsonUtility.FromJson<SaveWrapper>(File.ReadAllText(AIPath));
            if(wrapper?.keys==null)return;
            for(int i=0;i<wrapper.keys.Count&&i<wrapper.vals.Count;i++){
                var d=new AIData();d.Deserialize(wrapper.vals[i]);_data[wrapper.keys[i]]=d;
            }
        }catch(System.Exception e){Debug.LogWarning("AI load: "+e.Message);}
    }

    [System.Serializable] class SaveWrapper{public List<string> keys=new();public List<AIDataFlat> vals=new();}
}

// ── AIData (no Dictionary — uses parallel lists for serialization) ─────────────
public class AIData
{
    public int   sessions=0,totalCorrect=0,totalQ=0;
    public float avgMs=5000f;
    public int   diffLevel=1,streak=0,bestStreak=0;
    public float xpMult=1f;
    // Topic accuracy stored as parallel lists
    public Dictionary<string,int> topicCorrect=new();
    public Dictionary<string,int> topicTotal=new();

    public AIDataFlat Serialize(){
        var f=new AIDataFlat{sessions=sessions,totalCorrect=totalCorrect,totalQ=totalQ,
            avgMs=avgMs,diffLevel=diffLevel,streak=streak,bestStreak=bestStreak,xpMult=xpMult};
        foreach(var kv in topicCorrect){f.topicKeys.Add(kv.Key);f.topicCorrects.Add(kv.Value);f.topicTotals.Add(topicTotal.GetValueOrDefault(kv.Key,0));}
        return f;
    }

    public void Deserialize(AIDataFlat f){
        sessions=f.sessions;totalCorrect=f.totalCorrect;totalQ=f.totalQ;
        avgMs=f.avgMs;diffLevel=f.diffLevel;streak=f.streak;bestStreak=f.bestStreak;xpMult=f.xpMult;
        for(int i=0;i<f.topicKeys.Count;i++){
            topicCorrect[f.topicKeys[i]]=f.topicCorrects.Count>i?f.topicCorrects[i]:0;
            topicTotal[f.topicKeys[i]]=f.topicTotals.Count>i?f.topicTotals[i]:0;
        }
    }
}

[System.Serializable]
public class AIDataFlat{
    public int sessions,totalCorrect,totalQ,diffLevel,streak,bestStreak;
    public float avgMs,xpMult;
    public List<string> topicKeys=new();
    public List<int>    topicCorrects=new();
    public List<int>    topicTotals=new();
}
