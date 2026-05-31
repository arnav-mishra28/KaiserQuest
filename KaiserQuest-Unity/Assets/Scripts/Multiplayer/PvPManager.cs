using UnityEngine;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Text;

/// <summary>
/// PvPManager — Handles player-vs-player knowledge battles via WebSocket.
/// Connects to the Python backend WebSocket for real-time PvP.
/// </summary>
public class PvPManager : MonoBehaviour
{
    public static PvPManager Instance { get; private set; }

    [Header("Settings")]
    public string serverUrl = "ws://localhost:8000/pvp/battle";

    [Header("State")]
    public bool isConnected = false;
    public bool inMatch = false;
    public string matchId = "";
    public string opponentName = "";

    // Events
    public event Action<string> OnMatchFound;
    public event Action<PvPQuestionData> OnQuestionReceived;
    public event Action<PvPResultData> OnMatchResult;
    public event Action<string> OnOpponentAnswered;
    public event Action OnDisconnected;

    // WebSocket (Unity doesn't have built-in WebSocket, so we use a simple TCP approach
    // or the user can use a WebSocket library)
    private bool useSimulatedPvP = true; // Fallback when server not available

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;
    }

    /// <summary>
    /// Start looking for a PvP match.
    /// </summary>
    public void FindMatch(string playerName)
    {
        if (useSimulatedPvP)
        {
            StartCoroutine(SimulatedMatchmaking(playerName));
        }
        else
        {
            // Real WebSocket connection would go here
            Debug.Log("[PvP] Connecting to server...");
        }
    }

    /// <summary>
    /// Submit answer in PvP battle.
    /// </summary>
    public void SubmitPvPAnswer(int questionIndex, string answer, float responseTime)
    {
        if (useSimulatedPvP)
        {
            SimulateOpponentAnswer(questionIndex, responseTime);
        }
    }

    /// <summary>
    /// Leave current match.
    /// </summary>
    public void LeaveMatch()
    {
        inMatch = false;
        matchId = "";
        opponentName = "";
        OnDisconnected?.Invoke();
    }

    // ============================================================
    // SIMULATED PVP (Offline mode)
    // ============================================================

    private IEnumerator SimulatedMatchmaking(string playerName)
    {
        DialogSystem.Instance?.ShowDialog("PvP", "Searching for an opponent...");

        yield return new WaitForSeconds(2f);

        // Simulate finding an opponent
        string[] aiNames = { "Scholar Alex", "Professor Byte", "Sage Luna", "Master Chen", "Student Max" };
        opponentName = aiNames[UnityEngine.Random.Range(0, aiNames.Length)];
        matchId = Guid.NewGuid().ToString().Substring(0, 8);
        inMatch = true;

        DialogSystem.Instance?.ShowDialog("PvP", $"Match found! vs {opponentName}");

        yield return new WaitForSeconds(1.5f);

        // Start PvP battle
        OnMatchFound?.Invoke(opponentName);
        StartPvPBattle();
    }

    private void StartPvPBattle()
    {
        BattleData data = new BattleData
        {
            opponentName = opponentName,
            topic = "",
            difficulty = GameManager.Instance.playerData.level / 5 + 1,
            xpReward = 100,
            isGymBattle = false,
            isSilverMountain = false,
            onBattleComplete = (won) =>
            {
                var result = new PvPResultData
                {
                    won = won,
                    opponentName = opponentName,
                    xpEarned = won ? 100 : 25
                };
                OnMatchResult?.Invoke(result);
                inMatch = false;

                if (won)
                {
                    DialogSystem.Instance?.ShowDialog("PvP", 
                        $"You defeated {opponentName} in a Knowledge Duel!\n+100 XP");
                }
                else
                {
                    DialogSystem.Instance?.ShowDialog("PvP", 
                        $"{opponentName} won the Knowledge Duel.\n+25 XP for trying!");
                }
            }
        };

        GameManager.Instance.SetGameState(GameState.PvP);
        BattleManager.Instance?.StartBattle(data);
    }

    private void SimulateOpponentAnswer(int questionIndex, float playerTime)
    {
        // AI opponent responds with slightly variable speed
        float aiTime = playerTime + UnityEngine.Random.Range(-2f, 3f);
        bool aiCorrect = UnityEngine.Random.value > 0.4f; // 60% chance AI is correct

        OnOpponentAnswered?.Invoke(aiCorrect ? "correct" : "wrong");
    }
}

// ============================================================
// PVP DATA
// ============================================================

[System.Serializable]
public class PvPQuestionData
{
    public int questionIndex;
    public QuestionData question;
    public float timeLimit;
}

[System.Serializable]
public class PvPResultData
{
    public bool won;
    public string opponentName;
    public int xpEarned;
    public int playerScore;
    public int opponentScore;
}
