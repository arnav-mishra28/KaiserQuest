using UnityEngine;
using System.Collections.Generic;

/// <summary>
/// SideQuestManager — Manages side quests for leveling up.
/// </summary>
public class SideQuestManager : MonoBehaviour
{
    public static SideQuestManager Instance { get; private set; }

    [Header("Available Quests")]
    public List<SideQuestData> availableQuests = new List<SideQuestData>();

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;

        InitializeQuests();
    }

    private void InitializeQuests()
    {
        // Math quests
        availableQuests.Add(new SideQuestData
        {
            questId = "math_speed_drill",
            questName = "Speed Drill: Variables",
            description = "Answer 5 variable questions as fast as you can!",
            subject = "Mathematics",
            topic = "Variables",
            difficulty = 2,
            questionCount = 5,
            xpReward = 75,
            timeLimit = 60f,
            repeatable = true
        });

        availableQuests.Add(new SideQuestData
        {
            questId = "math_equation_mastery",
            questName = "Equation Master",
            description = "Solve 10 linear equations without mistakes!",
            subject = "Mathematics",
            topic = "Linear Equations",
            difficulty = 4,
            questionCount = 10,
            xpReward = 150,
            perfectBonusXp = 50,
            repeatable = true
        });

        availableQuests.Add(new SideQuestData
        {
            questId = "math_quadratic_challenge",
            questName = "Quadratic Challenge",
            description = "Face the quadratic equations head-on!",
            subject = "Mathematics",
            topic = "Quadratics",
            difficulty = 7,
            questionCount = 8,
            xpReward = 200,
            repeatable = true
        });

        // English quests
        availableQuests.Add(new SideQuestData
        {
            questId = "eng_grammar_patrol",
            questName = "Grammar Patrol",
            description = "Help fix grammar mistakes around town!",
            subject = "Languages",
            topic = "Grammar",
            difficulty = 3,
            questionCount = 6,
            xpReward = 100,
            repeatable = true
        });

        availableQuests.Add(new SideQuestData
        {
            questId = "eng_vocab_treasure",
            questName = "Vocabulary Treasure Hunt",
            description = "Find the meanings of rare words!",
            subject = "Languages",
            topic = "Vocabulary",
            difficulty = 4,
            questionCount = 8,
            xpReward = 120,
            repeatable = true
        });

        // Music quests
        availableQuests.Add(new SideQuestData
        {
            questId = "music_note_reading",
            questName = "Note Reading Race",
            description = "Identify notes before time runs out!",
            subject = "Music",
            topic = "Notes",
            difficulty = 2,
            questionCount = 5,
            xpReward = 80,
            timeLimit = 45f,
            repeatable = true
        });

        availableQuests.Add(new SideQuestData
        {
            questId = "music_chord_builder",
            questName = "Chord Builder",
            description = "Build chords from scratch!",
            subject = "Music",
            topic = "Chords",
            difficulty = 5,
            questionCount = 6,
            xpReward = 130,
            repeatable = true
        });
    }

    public void StartQuest(string questId)
    {
        SideQuestData quest = availableQuests.Find(q => q.questId == questId);
        if (quest == null)
        {
            Debug.LogError($"[SideQuestManager] Quest not found: {questId}");
            return;
        }

        // Check if already completed (non-repeatable)
        if (!quest.repeatable && GameManager.Instance.playerData.completedQuests.Contains(questId))
        {
            DialogSystem.Instance?.ShowDialog("System", "You've already completed this quest!");
            return;
        }

        var introLines = new List<DialogLine>
        {
            new DialogLine("Quest", $"Side Quest: {quest.questName}"),
            new DialogLine("Quest", quest.description)
        };

        DialogSystem.Instance?.ShowDialog(introLines, () =>
        {
            GameManager.Instance.SetGameState(GameState.SideQuest);

            BattleData data = new BattleData
            {
                opponentName = quest.questName,
                topic = quest.topic,
                difficulty = quest.difficulty,
                xpReward = quest.xpReward,
                isGymBattle = false,
                isSilverMountain = false,
                onBattleComplete = (won) =>
                {
                    if (won)
                    {
                        GameManager.Instance.playerData.questsCompleted++;
                        if (!quest.repeatable)
                            GameManager.Instance.playerData.completedQuests.Add(questId);

                        DialogSystem.Instance?.ShowDialog("Quest", $"Quest Complete! +{quest.xpReward} XP");
                    }
                }
            };

            BattleManager.Instance?.StartBattle(data);
        });
    }
}

[System.Serializable]
public class SideQuestData
{
    public string questId;
    public string questName;
    public string description;
    public string subject;
    public string topic;
    public int difficulty;
    public int questionCount;
    public int xpReward;
    public int perfectBonusXp;
    public float timeLimit; // 0 = no time limit
    public bool repeatable;
}
