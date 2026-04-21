// GameManager.cs — Singleton Global State
using UnityEngine;
using System.Collections.Generic;

public class GameManager : MonoBehaviour
{
    // ── Singleton ─────────────────────────────────────────────────────────────
    public static GameManager Instance { get; private set; }

    void Awake()
    {
        if (Instance != null && Instance != this) { Destroy(gameObject); return; }
        Instance = this;
        DontDestroyOnLoad(gameObject);
        SaveSystem.Load();
    }

    // ── Player Info ───────────────────────────────────────────────────────────
    public string PlayerName   { get; set; } = "Arix";
    public string ActiveSubject{ get; set; } = "";
    public string ActiveBranch { get; set; } = "";
    public string BranchKey    => ActiveSubject + ":" + ActiveBranch;

    // ── Per-branch state ──────────────────────────────────────────────────────
    private Dictionary<string, BranchData> _branchState = new();

    public BranchData GetBranch(string key = null)
    {
        string k = key ?? BranchKey;
        if (!_branchState.ContainsKey(k))
            _branchState[k] = new BranchData();
        return _branchState[k];
    }

    public Dictionary<string, BranchData> AllBranches => _branchState;
    public void SetAllBranches(Dictionary<string, BranchData> data) => _branchState = data;

    // ── Accessors ─────────────────────────────────────────────────────────────
    public int   Level      => GetBranch().Level;
    public int   XP         => GetBranch().XP;
    public int   XPMax      => GetBranch().Level * 100;
    public int   HP         => GetBranch().HP;
    public int   MaxHP      => 30 + (GetBranch().Level - 1) * 3;
    public int   Gold       => GetBranch().Gold;
    public int   DuelWins   => GetBranch().DuelWins;
    public bool  IsKaiser   => GetBranch().Kaiser;
    public List<string> Badges => GetBranch().Badges;

    public bool HasBadge(string b) => GetBranch().Badges.Contains(b);
    public bool HasItem(string id)  => GetBranch().ItemsCollected.Contains(id);
    public bool HasTalked(string id)=> GetBranch().NPCsTalked.Contains(id);
    public bool QuestDone(string id)=> GetBranch().QuestsDone.Contains(id);

    public void MarkTalked(string id) {
        if (!HasTalked(id)) GetBranch().NPCsTalked.Add(id);
    }
    public void CollectItem(string id) {
        if (!HasItem(id)) GetBranch().ItemsCollected.Add(id);
    }
    public void CompleteQuest(string id) {
        if (!QuestDone(id)) { GetBranch().QuestsDone.Add(id); SaveSystem.Save(); }
    }
    public void AddDuelWin() { GetBranch().DuelWins++; SaveSystem.Save(); }

    // ── XP / Level ────────────────────────────────────────────────────────────
    public event System.Action<int, int, int> OnXPChanged;
    public event System.Action<int>           OnLevelUp;
    public event System.Action<string>        OnBadgeEarned;
    public event System.Action<int, int>      OnHPChanged;

    public void AddXP(int amount)
    {
        var b = GetBranch();
        b.XP += amount;
        int cap = b.Level * 100;
        while (b.XP >= cap) {
            b.XP -= cap; b.Level++;
            cap = b.Level * 100;
            OnLevelUp?.Invoke(b.Level);
        }
        OnXPChanged?.Invoke(b.XP, b.Level * 100, b.Level);
        SaveSystem.Save();
    }

    // ── HP ────────────────────────────────────────────────────────────────────
    public void RestoreHP() {
        GetBranch().HP = MaxHP;
        OnHPChanged?.Invoke(HP, MaxHP);
    }
    public void TakeDamage(int d) {
        GetBranch().HP = Mathf.Max(0, HP - d);
        OnHPChanged?.Invoke(HP, MaxHP);
        SaveSystem.Save();
    }

    // ── Gym / Badge ───────────────────────────────────────────────────────────
    public bool CanChallengeGym(int gymNum) => Level >= gymNum * 5;

    public void EarnBadge(string b) {
        if (!HasBadge(b)) {
            GetBranch().Badges.Add(b);
            OnBadgeEarned?.Invoke(b);
            SaveSystem.Save();
        }
    }

    public void SetBestScore(string gymId, int score) {
        var b = GetBranch();
        if (!b.BestScores.ContainsKey(gymId) || score > b.BestScores[gymId])
            b.BestScores[gymId] = score;
        SaveSystem.Save();
    }

    // ── Silver Mountain ───────────────────────────────────────────────────────
    public bool CanChallengeSilver() => Level >= 100 && Badges.Count >= 20;

    public bool SilverOnCooldown() {
        long now = System.DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        return GetBranch().SilverCooldown > now;
    }

    public long SilverCooldownRemaining() {
        long now = System.DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        return Mathf.Max(0, (int)(GetBranch().SilverCooldown - now));
    }

    public void SilverAttemptFailed() {
        var b = GetBranch();
        b.SilverAttempts++;
        if (b.SilverAttempts >= 3) {
            b.SilverCooldown = System.DateTimeOffset.UtcNow.ToUnixTimeSeconds() + 86400;
            b.SilverAttempts = 0;
        }
        SaveSystem.Save();
    }

    public void SilverCleared() {
        GetBranch().Kaiser = true;
        SaveSystem.Save();
    }

    // ── Grid Position ─────────────────────────────────────────────────────────
    public Vector2Int GridPos {
        get => new Vector2Int(GetBranch().GridX, GetBranch().GridY);
        set { GetBranch().GridX = value.x; GetBranch().GridY = value.y; }
    }

    public void ResetAll() {
        _branchState.Clear();
        SaveSystem.Delete();
    }
}

// ── Branch Data (serializable) ────────────────────────────────────────────────
[System.Serializable]
public class BranchData
{
    public int    Level        = 1;
    public int    XP           = 0;
    public int    HP           = 30;
    public int    Gold         = 0;
    public int    DuelWins     = 0;
    public int    SilverAttempts = 0;
    public long   SilverCooldown = 0;
    public bool   Kaiser       = false;
    public int    GridX        = 7;
    public int    GridY        = 8;
    public List<string>             Badges         = new();
    public List<string>             NPCsTalked     = new();
    public List<string>             ItemsCollected = new();
    public List<string>             QuestsDone     = new();
    public Dictionary<string, int>  BestScores     = new();
}
