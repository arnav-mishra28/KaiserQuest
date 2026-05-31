using UnityEngine;
using System;
using System.Collections.Generic;

/// <summary>
/// GameManager — Singleton that persists across scenes.
/// Manages global game state: current subject, branch, player data, badges, etc.
/// </summary>
public class GameManager : MonoBehaviour
{
    public static GameManager Instance { get; private set; }

    [Header("Player Data")]
    public PlayerData playerData;

    [Header("Game State")]
    public GameState currentState = GameState.MainMenu;
    public SubjectType currentSubject = SubjectType.None;
    public string currentBranch = "";
    public string currentCity = "";
    public int currentGymIndex = 0;

    [Header("Settings")]
    public float textSpeed = 0.03f;
    public float musicVolume = 0.7f;
    public float sfxVolume = 0.8f;

    // Events
    public event Action<GameState> OnGameStateChanged;
    public event Action<int> OnLevelUp;
    public event Action<int> OnBadgeEarned;
    public event Action OnGameSaved;

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }

        Instance = this;
        DontDestroyOnLoad(gameObject);

        if (playerData == null)
        {
            playerData = new PlayerData();
            playerData.Initialize();
        }
    }

    public void SetGameState(GameState newState)
    {
        currentState = newState;
        OnGameStateChanged?.Invoke(newState);
    }

    public void SelectSubject(SubjectType subject, string branch)
    {
        currentSubject = subject;
        currentBranch = branch;
        Debug.Log($"[GameManager] Subject: {subject}, Branch: {branch}");
    }

    public void AddExperience(int amount)
    {
        int oldLevel = playerData.level;
        playerData.AddExperience(amount);

        if (playerData.level > oldLevel)
        {
            OnLevelUp?.Invoke(playerData.level);
            Debug.Log($"[GameManager] Level Up! Now level {playerData.level}");
        }
    }

    public void EarnBadge(int gymIndex, string gymName)
    {
        if (!playerData.earnedBadges.Contains(gymIndex))
        {
            playerData.earnedBadges.Add(gymIndex);
            OnBadgeEarned?.Invoke(gymIndex);
            Debug.Log($"[GameManager] Badge earned: {gymName} (Gym {gymIndex})");
        }
    }

    public bool CanChallengeGym(int gymIndex)
    {
        int requiredLevel = gymIndex * 5;
        return playerData.level >= requiredLevel;
    }

    public bool CanChallengeSilverMountain()
    {
        return playerData.level >= 100 && playerData.earnedBadges.Count >= 20;
    }

    public void SaveGame()
    {
        string json = JsonUtility.ToJson(playerData, true);
        PlayerPrefs.SetString("KaiserQuest_SaveData", json);
        PlayerPrefs.SetString("KaiserQuest_Subject", currentSubject.ToString());
        PlayerPrefs.SetString("KaiserQuest_Branch", currentBranch);
        PlayerPrefs.Save();
        OnGameSaved?.Invoke();
        Debug.Log("[GameManager] Game saved!");
    }

    public bool LoadGame()
    {
        if (PlayerPrefs.HasKey("KaiserQuest_SaveData"))
        {
            string json = PlayerPrefs.GetString("KaiserQuest_SaveData");
            playerData = JsonUtility.FromJson<PlayerData>(json);
            currentSubject = (SubjectType)Enum.Parse(typeof(SubjectType), 
                PlayerPrefs.GetString("KaiserQuest_Subject", "None"));
            currentBranch = PlayerPrefs.GetString("KaiserQuest_Branch", "");
            Debug.Log("[GameManager] Game loaded!");
            return true;
        }
        return false;
    }

    public void NewGame(string playerName)
    {
        playerData = new PlayerData();
        playerData.Initialize();
        playerData.playerName = playerName;
        currentSubject = SubjectType.None;
        currentBranch = "";
        SetGameState(GameState.SubjectSelect);
    }
}

// ============================================================
// ENUMS
// ============================================================

public enum GameState
{
    MainMenu,
    SubjectSelect,
    BranchSelect,
    Overworld,
    Dialog,
    Battle,
    GymBattle,
    SilverMountain,
    PvP,
    Paused,
    SideQuest,
    Cutscene
}

public enum SubjectType
{
    None,
    Mathematics,
    Languages,
    Music
}

// ============================================================
// PLAYER DATA
// ============================================================

[Serializable]
public class PlayerData
{
    public string playerName = "Arix";
    public int level = 1;
    public int experience = 0;
    public int totalExp = 0;
    public int hp = 100;
    public int maxHp = 100;
    public int questsCompleted = 0;
    public int battlesWon = 0;
    public int battlesLost = 0;
    public int streak = 0;
    public float accuracy = 0f;
    public int totalAnswered = 0;
    public int totalCorrect = 0;
    public int silverMountainAttempts = 0;
    public string lastSilverMountainAttempt = "";
    public List<int> earnedBadges = new List<int>();
    public List<string> completedQuests = new List<string>();
    public List<string> weakTopics = new List<string>();
    public string lastSaveCity = "OriginVillage";
    public float lastPosX = 0f;
    public float lastPosY = 0f;
    public bool isKaiser = false;

    public void Initialize()
    {
        level = 1;
        experience = 0;
        totalExp = 0;
        hp = 100;
        maxHp = 100;
        earnedBadges = new List<int>();
        completedQuests = new List<string>();
        weakTopics = new List<string>();
    }

    public int GetExpForNextLevel()
    {
        // Pokemon-style exp curve: level^3
        return level * level * level;
    }

    public void AddExperience(int amount)
    {
        experience += amount;
        totalExp += amount;

        while (experience >= GetExpForNextLevel() && level < 100)
        {
            experience -= GetExpForNextLevel();
            level++;
            maxHp = 100 + (level * 5);
            hp = maxHp;
        }
    }

    public void RecordAnswer(bool correct, string topic)
    {
        totalAnswered++;
        if (correct)
        {
            totalCorrect++;
            streak++;
        }
        else
        {
            streak = 0;
            if (!weakTopics.Contains(topic))
                weakTopics.Add(topic);
        }
        accuracy = totalAnswered > 0 ? (float)totalCorrect / totalAnswered : 0f;
    }
}
