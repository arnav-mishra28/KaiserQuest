using UnityEngine;
using System;
using System.Collections.Generic;
using KaiserQuest.Knowledge;
using KaiserQuest.Story;

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

    /// <summary>
    /// The story layer, which owns everything about mastery and progress.
    ///
    /// GameManager keeps the world — position, scene, settings, the legacy player
    /// record. It deliberately owns no knowledge state at all: what the player
    /// understands lives in the Knowledge Engine and is played through Story Mode.
    /// </summary>
    public StoryModeManager Story { get { return StoryModeManager.Instance; } }

    public void SelectSubject(SubjectType subject, string branch)
    {
        currentSubject = subject;
        currentBranch = branch;

        // Selecting a subject in the old branch menu is now the same act as choosing
        // which realm's story mode to enter.
        if (Story != null && Story.Ready) Story.ActiveRealmDraft = RealmFor(subject);
        Debug.Log($"[GameManager] Subject: {subject}, Realm: {RealmFor(subject)}, Branch: {branch}");
    }

    /// <summary>Which realm a legacy subject maps onto.</summary>
    public string RealmFor(SubjectType subject)
    {
        switch (subject)
        {
            case SubjectType.Mathematics: return "algebra";
            case SubjectType.Languages: return "english";
            case SubjectType.Music: return "music";
        }
        return Story != null ? Story.ActiveRealmId : "algebra";
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

    /// <summary>
    /// Whether a milestone may be challenged. `gymIndex` is a 1-based milestone
    /// index; 0 means "whatever is next".
    ///
    /// The old implementation was `playerData.level >= gymIndex * 5`. That is the
    /// design the vision rejects, and it is replaced rather than adjusted: a level
    /// gate is satisfied by grinding, a mastery gate cannot be. The real answer comes
    /// from the knowledge trace, through the same entry check the keepers in the world
    /// speak from — including the reason, so the game can say "Proportions is not
    /// solid enough yet" instead of showing a padlock.
    /// </summary>
    public bool CanChallengeGym(int gymIndex)
    {
        EntryCheck entry;
        return TryEnterMilestone(gymIndex, out entry);
    }

    /// <summary>Attempt admission to a milestone, with the keeper's reason attached.</summary>
    public bool TryEnterMilestone(int gymIndex, out EntryCheck entry)
    {
        entry = null;
        StoryModeManager story = StoryModeManager.Instance;
        if (story == null || !story.Ready) return false;

        string realm = RealmFor(currentSubject);
        List<Milestone> milestones = story.Campaign(realm);
        if (milestones.Count == 0) return false;

        int index = gymIndex > 0 ? gymIndex : 0;
        Milestone milestone = story.Progression.FirstUnpassed(milestones, story.Progress(realm));
        if (index > 0)
        {
            milestone = null;
            for (int i = 0; i < milestones.Count; i++)
            {
                if (milestones[i].Index == index) { milestone = milestones[i]; break; }
            }
        }
        if (milestone == null) return false;

        entry = story.Progression.EntryCheck(milestones, milestone, story.Progress(realm));
        return entry.Allowed;
    }

    /// <summary>The summit opens on cleared milestones, never on a level.</summary>
    public bool CanChallengeSilverMountain()
    {
        StoryModeManager story = StoryModeManager.Instance;
        if (story == null || !story.Ready) return false;
        return story.SilverStatus(RealmFor(currentSubject)).CanChallenge;
    }

    /// <summary>
    /// Save the world state.
    ///
    /// The legacy PlayerPrefs blob is kept in sync for the older screens, but the save
    /// that matters is the versioned story save: it carries per-realm progress, the
    /// save point Silver Mountain returns the player to, and the knowledge trace the
    /// 24-hour cooldown depends on.
    /// </summary>
    public void SaveGame()
    {
        StoryModeManager story = StoryModeManager.Instance;
        if (story != null) story.SaveNow();

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
