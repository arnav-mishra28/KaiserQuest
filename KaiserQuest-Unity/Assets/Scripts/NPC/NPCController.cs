using UnityEngine;
using System.Collections.Generic;

/// <summary>
/// NPCController — Handles NPC behavior, dialog triggers, and interaction.
/// NPCs can be teachers, gym leaders, side quest givers, or random trainers.
/// </summary>
public class NPCController : MonoBehaviour, IInteractable
{
    [Header("NPC Info")]
    public string npcName = "NPC";
    public NPCType npcType = NPCType.Villager;
    public Sprite portrait;

    [Header("Dialog")]
    [TextArea(3, 10)]
    public List<string> dialogLines = new List<string>();

    [Header("Teaching")]
    public string teachingSubject = "";
    public string teachingTopic = "";
    [TextArea(3, 10)]
    public List<string> teachingLines = new List<string>();

    [Header("Battle")]
    public bool canBattle = false;
    public int battleLevel = 1;
    public string battleTopic = "";
    public int xpReward = 50;
    public bool hasBeenDefeated = false;

    [Header("Quest")]
    public string questId = "";
    public string questDescription = "";
    public int questXpReward = 100;

    [Header("Movement")]
    public bool wanders = false;
    public float wanderRadius = 3f;
    public float wanderInterval = 3f;

    [Header("Visual")]
    public Animator animator;
    public SpriteRenderer spriteRenderer;
    public GameObject exclamationMark; // "!" indicator above head

    private Vector3 startPosition;
    private float wanderTimer;
    private bool isInteracting = false;

    private void Start()
    {
        startPosition = transform.position;
        wanderTimer = wanderInterval;

        if (animator == null) animator = GetComponent<Animator>();
        if (spriteRenderer == null) spriteRenderer = GetComponent<SpriteRenderer>();

        if (exclamationMark != null)
            exclamationMark.SetActive(false);
    }

    private void Update()
    {
        if (wanders && !isInteracting)
        {
            wanderTimer -= Time.deltaTime;
            if (wanderTimer <= 0f)
            {
                Wander();
                wanderTimer = wanderInterval + Random.Range(-1f, 1f);
            }
        }
    }

    public void Interact(PlayerController player)
    {
        if (isInteracting) return;
        isInteracting = true;

        // Face the player
        FacePlayer(player.transform.position);

        // Show exclamation mark briefly
        if (exclamationMark != null)
        {
            exclamationMark.SetActive(true);
            Invoke(nameof(HideExclamation), 0.5f);
        }

        switch (npcType)
        {
            case NPCType.Teacher:
                HandleTeacherInteraction(player);
                break;
            case NPCType.GymLeader:
                HandleGymLeaderInteraction(player);
                break;
            case NPCType.Trainer:
                HandleTrainerInteraction(player);
                break;
            case NPCType.QuestGiver:
                HandleQuestInteraction(player);
                break;
            case NPCType.Mentor:
                HandleMentorInteraction(player);
                break;
            case NPCType.SilverMountainBoss:
                HandleSilverMountainInteraction(player);
                break;
            default:
                HandleVillagerInteraction(player);
                break;
        }
    }

    private void HandleVillagerInteraction(PlayerController player)
    {
        var lines = new List<DialogLine>();
        foreach (string line in dialogLines)
        {
            lines.Add(new DialogLine(npcName, line, portrait));
        }

        DialogSystem.Instance.ShowDialog(lines, () => { isInteracting = false; });
    }

    private void HandleTeacherInteraction(PlayerController player)
    {
        var lines = new List<DialogLine>();

        // Teaching lines
        foreach (string line in teachingLines)
        {
            lines.Add(new DialogLine(npcName, line, portrait));
        }

        // After teaching, offer a practice quiz
        DialogSystem.Instance.ShowDialog(lines, () =>
        {
            DialogSystem.Instance.ShowChoice(
                npcName,
                "Want to test what you've learned?",
                new List<string> { "Yes, let's go!", "Not right now" },
                (choice) =>
                {
                    if (choice == 0)
                    {
                        // Start a practice battle
                        StartBattle(player, false);
                    }
                    isInteracting = false;
                },
                portrait
            );
        });
    }

    private void HandleGymLeaderInteraction(PlayerController player)
    {
        int requiredLevel = (currentGymIndex() + 1) * 5;
        bool canChallenge = GameManager.Instance.CanChallengeGym(currentGymIndex() + 1);

        if (hasBeenDefeated)
        {
            var lines = new List<DialogLine>
            {
                new DialogLine(npcName, "You've already earned this badge! Keep pushing forward, champion!", portrait)
            };
            DialogSystem.Instance.ShowDialog(lines, () => { isInteracting = false; });
            return;
        }

        if (!canChallenge)
        {
            var lines = new List<DialogLine>
            {
                new DialogLine(npcName, $"You need to be at least Level {requiredLevel} to challenge me!", portrait),
                new DialogLine(npcName, "Go train more and come back when you're ready.", portrait)
            };
            DialogSystem.Instance.ShowDialog(lines, () => { isInteracting = false; });
            return;
        }

        var introLines = new List<DialogLine>
        {
            new DialogLine(npcName, $"I am {npcName}, the Gym Leader of this city!", portrait),
            new DialogLine(npcName, "Let's see if your knowledge is worthy of a badge!", portrait)
        };

        DialogSystem.Instance.ShowDialog(introLines, () =>
        {
            DialogSystem.Instance.ShowChoice(
                npcName,
                "Are you ready to challenge me?",
                new List<string> { "Bring it on!", "I need more preparation" },
                (choice) =>
                {
                    if (choice == 0)
                    {
                        StartBattle(player, true);
                    }
                    isInteracting = false;
                },
                portrait
            );
        });
    }

    private void HandleTrainerInteraction(PlayerController player)
    {
        if (hasBeenDefeated)
        {
            var lines = new List<DialogLine>
            {
                new DialogLine(npcName, "You beat me fair and square! Good luck on your journey!", portrait)
            };
            DialogSystem.Instance.ShowDialog(lines, () => { isInteracting = false; });
            return;
        }

        var challengeLines = new List<DialogLine>
        {
            new DialogLine(npcName, "Hey! Our eyes met! Let's have a Knowledge Duel!", portrait)
        };

        DialogSystem.Instance.ShowDialog(challengeLines, () =>
        {
            StartBattle(player, false);
            isInteracting = false;
        });
    }

    private void HandleQuestInteraction(PlayerController player)
    {
        bool questCompleted = GameManager.Instance.playerData.completedQuests.Contains(questId);

        if (questCompleted)
        {
            var lines = new List<DialogLine>
            {
                new DialogLine(npcName, "Thanks for your help earlier! You're a true scholar!", portrait)
            };
            DialogSystem.Instance.ShowDialog(lines, () => { isInteracting = false; });
            return;
        }

        var questLines = new List<DialogLine>
        {
            new DialogLine(npcName, questDescription, portrait)
        };

        DialogSystem.Instance.ShowDialog(questLines, () =>
        {
            DialogSystem.Instance.ShowChoice(
                npcName,
                "Will you help me?",
                new List<string> { "Of course!", "Maybe later" },
                (choice) =>
                {
                    if (choice == 0)
                    {
                        // Start side quest battle
                        StartBattle(player, false);
                    }
                    isInteracting = false;
                },
                portrait
            );
        });
    }

    private void HandleMentorInteraction(PlayerController player)
    {
        int playerLevel = GameManager.Instance.playerData.level;
        var lines = new List<DialogLine>
        {
            new DialogLine(npcName, "Welcome, young scholar! The world's knowledge is fading...", portrait),
            new DialogLine(npcName, "You are the last hope to restore it. Learn well!", portrait),
            new DialogLine(npcName, $"You are currently Level {playerLevel}. Keep growing!", portrait)
        };

        DialogSystem.Instance.ShowDialog(lines, () => { isInteracting = false; });
    }

    private void HandleSilverMountainInteraction(PlayerController player)
    {
        if (!GameManager.Instance.CanChallengeSilverMountain())
        {
            int badges = GameManager.Instance.playerData.earnedBadges.Count;
            int level = GameManager.Instance.playerData.level;
            var lines = new List<DialogLine>
            {
                new DialogLine(npcName, "...", portrait),
                new DialogLine(npcName, $"You have {badges}/20 badges and are Level {level}.", portrait),
                new DialogLine(npcName, "You are not ready. Come back with all 20 badges and Level 100.", portrait)
            };
            DialogSystem.Instance.ShowDialog(lines, () => { isInteracting = false; });
            return;
        }

        // Check 24-hour cooldown
        int attempts = GameManager.Instance.playerData.silverMountainAttempts;
        if (attempts >= 3)
        {
            string lastAttempt = GameManager.Instance.playerData.lastSilverMountainAttempt;
            if (!string.IsNullOrEmpty(lastAttempt))
            {
                System.DateTime lastTime = System.DateTime.Parse(lastAttempt);
                System.TimeSpan elapsed = System.DateTime.Now - lastTime;
                if (elapsed.TotalHours < 24)
                {
                    double hoursLeft = 24 - elapsed.TotalHours;
                    var lines = new List<DialogLine>
                    {
                        new DialogLine(npcName, $"You must wait {hoursLeft:F1} more hours before challenging again.", portrait),
                        new DialogLine(npcName, "Use this time to review everything you've learned.", portrait)
                    };
                    DialogSystem.Instance.ShowDialog(lines, () => { isInteracting = false; });
                    return;
                }
                else
                {
                    // Reset attempts after 24 hours
                    GameManager.Instance.playerData.silverMountainAttempts = 0;
                }
            }
        }

        var introLines = new List<DialogLine>
        {
            new DialogLine(npcName, "So... you've made it to the summit.", portrait),
            new DialogLine(npcName, "I am the Guardian of Silver Mountain.", portrait),
            new DialogLine(npcName, "To earn the title of KAISER, you must prove your mastery of ALL knowledge.", portrait),
            new DialogLine(npcName, $"This is attempt {attempts + 1} of 3.", portrait)
        };

        DialogSystem.Instance.ShowDialog(introLines, () =>
        {
            DialogSystem.Instance.ShowChoice(
                npcName,
                "Are you ready for the ultimate challenge?",
                new List<string> { "I was born ready!", "Let me prepare first" },
                (choice) =>
                {
                    if (choice == 0)
                    {
                        GameManager.Instance.playerData.silverMountainAttempts++;
                        GameManager.Instance.playerData.lastSilverMountainAttempt = System.DateTime.Now.ToString();
                        StartBattle(player, true);
                    }
                    isInteracting = false;
                },
                portrait
            );
        });
    }

    private void StartBattle(PlayerController player, bool isGymBattle)
    {
        BattleManager battleManager = FindObjectOfType<BattleManager>();
        if (battleManager != null)
        {
            BattleData data = new BattleData
            {
                opponentName = npcName,
                opponentPortrait = portrait,
                topic = battleTopic,
                difficulty = battleLevel,
                xpReward = xpReward,
                isGymBattle = isGymBattle,
                gymIndex = currentGymIndex(),
                isSilverMountain = (npcType == NPCType.SilverMountainBoss),
                onBattleComplete = (won) =>
                {
                    if (won)
                    {
                        hasBeenDefeated = true;
                        if (isGymBattle)
                        {
                            GameManager.Instance.EarnBadge(currentGymIndex() + 1, npcName);
                        }
                    }
                }
            };

            battleManager.StartBattle(data);
        }
    }

    private int currentGymIndex()
    {
        // Find which gym this NPC belongs to
        GymData gym = GetComponentInParent<GymData>();
        return gym != null ? gym.gymIndex : 0;
    }

    private void FacePlayer(Vector3 playerPos)
    {
        Vector2 dir = (playerPos - transform.position).normalized;

        if (animator != null)
        {
            animator.SetFloat("MoveX", dir.x);
            animator.SetFloat("MoveY", dir.y);
        }
    }

    private void Wander()
    {
        Vector2 randomDir = Random.insideUnitCircle.normalized;
        Vector3 wanderTarget = startPosition + new Vector3(randomDir.x, randomDir.y, 0) * Random.Range(0.5f, wanderRadius);

        if (Vector3.Distance(wanderTarget, startPosition) <= wanderRadius)
        {
            // Simple move (not grid-based for NPCs)
            transform.position = Vector3.MoveTowards(transform.position, wanderTarget, 2f * Time.deltaTime);
        }
    }

    private void HideExclamation()
    {
        if (exclamationMark != null)
            exclamationMark.SetActive(false);
    }
}

public enum NPCType
{
    Villager,
    Teacher,
    GymLeader,
    Trainer,
    QuestGiver,
    Mentor,
    SilverMountainBoss,
    Shopkeeper
}
