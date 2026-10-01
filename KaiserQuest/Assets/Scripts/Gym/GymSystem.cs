using UnityEngine;
using System.Collections.Generic;

/// <summary>
/// GymData — Holds data for each gym in the game.
/// Attach to a Gym building GameObject.
/// </summary>
public class GymData : MonoBehaviour, IInteractable
{
    [Header("Gym Info")]
    public int gymIndex = 0; // 0-19 (1-20 for display)
    public string gymName = "Knowledge Gym";
    public string cityName = "";
    public string gymTopic = "Variables";
    public string gymSubject = "Mathematics";
    public int gymDifficulty = 1;

    [Header("Gym Leader")]
    public NPCController gymLeader;
    public string leaderName = "Gym Leader";
    public Sprite leaderPortrait;

    [Header("Badge")]
    public string badgeName = "Variable Badge";
    public Sprite badgeSprite;

    [Header("Interior")]
    public GameObject gymInterior; // Interior tilemap/objects
    public Transform playerSpawnPoint;
    public Transform leaderPosition;

    [Header("Visual")]
    public SpriteRenderer buildingRenderer;
    public GameObject badgeGlow; // Visual effect when gym is completed
    public ParticleSystem entranceParticles;

    private bool isCompleted = false;

    private void Start()
    {
        // Check if gym already completed
        if (GameManager.Instance != null)
        {
            isCompleted = GameManager.Instance.playerData.earnedBadges.Contains(gymIndex + 1);
            if (badgeGlow != null)
                badgeGlow.SetActive(isCompleted);
        }
    }

    public void Interact(PlayerController player)
    {
        if (isCompleted)
        {
            DialogSystem.Instance.ShowDialog(
                "Sign",
                $"[{gymName}]\n{cityName} City Gym\nLeader: {leaderName}\nStatus: COMPLETED ✓"
            );
            return;
        }

        int requiredLevel = (gymIndex + 1) * 5;
        int playerLevel = GameManager.Instance.playerData.level;

        if (playerLevel < requiredLevel)
        {
            DialogSystem.Instance.ShowDialog(
                "Sign",
                $"[{gymName}]\n{cityName} City Gym\nRequired Level: {requiredLevel}\nYour Level: {playerLevel}\n\nYou need to train more!"
            );
            return;
        }

        // Enter gym
        DialogSystem.Instance.ShowChoice(
            "Sign",
            $"[{gymName}]\nDo you want to enter the gym?",
            new List<string> { "Enter", "Not yet" },
            (choice) =>
            {
                if (choice == 0)
                {
                    EnterGym(player);
                }
            }
        );
    }

    private void EnterGym(PlayerController player)
    {
        // Show gym interior
        if (gymInterior != null)
            gymInterior.SetActive(true);

        // Teleport player to gym spawn
        if (playerSpawnPoint != null)
            player.TeleportTo(playerSpawnPoint.position);

        // Start gym leader dialog
        if (gymLeader != null)
        {
            var introLines = new List<DialogLine>
            {
                new DialogLine(leaderName, $"Welcome to {gymName}!", leaderPortrait),
                new DialogLine(leaderName, $"I am {leaderName}, master of {gymTopic}!", leaderPortrait),
                new DialogLine(leaderName, "Prove your knowledge and earn the badge!", leaderPortrait)
            };

            DialogSystem.Instance.ShowDialog(introLines, () =>
            {
                // Start gym battle
                BattleData battleData = new BattleData
                {
                    opponentName = leaderName,
                    opponentPortrait = leaderPortrait,
                    topic = gymTopic,
                    difficulty = gymDifficulty,
                    xpReward = 100 + (gymIndex * 50),
                    isGymBattle = true,
                    gymIndex = gymIndex,
                    isSilverMountain = false,
                    onBattleComplete = (won) =>
                    {
                        if (won)
                        {
                            isCompleted = true;
                            if (badgeGlow != null)
                                badgeGlow.SetActive(true);

                            var victoryLines = new List<DialogLine>
                            {
                                new DialogLine(leaderName, "Impressive! Your knowledge is remarkable!", leaderPortrait),
                                new DialogLine(leaderName, $"You've earned the {badgeName}!", leaderPortrait),
                                new DialogLine(leaderName, "Continue your journey and challenge the next gym!", leaderPortrait)
                            };
                            DialogSystem.Instance.ShowDialog(victoryLines);
                        }
                        else
                        {
                            var defeatLines = new List<DialogLine>
                            {
                                new DialogLine(leaderName, "You're not ready yet. Study more and come back!", leaderPortrait)
                            };
                            DialogSystem.Instance.ShowDialog(defeatLines);
                        }

                        // Exit gym
                        if (gymInterior != null)
                            gymInterior.SetActive(false);
                    }
                };

                BattleManager.Instance.StartBattle(battleData);
            });
        }
    }
}

/// <summary>
/// GymProgressionData — Defines all 20 gyms for a subject branch.
/// </summary>
[CreateAssetMenu(fileName = "GymProgression", menuName = "KaiserQuest/Gym Progression")]
public class GymProgressionData : ScriptableObject
{
    public string subjectName;
    public string branchName;
    public List<GymInfo> gyms = new List<GymInfo>();
}

[System.Serializable]
public class GymInfo
{
    public int gymNumber; // 1-20
    public string gymName;
    public string cityName;
    public string leaderName;
    public string topic;
    public int difficulty;
    public string badgeName;
    public int requiredLevel; // gymNumber * 5
    [TextArea]
    public string description;
}
