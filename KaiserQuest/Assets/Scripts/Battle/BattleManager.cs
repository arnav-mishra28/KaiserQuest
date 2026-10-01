using UnityEngine;
using UnityEngine.UI;
using TMPro;
using System.Collections;
using System.Collections.Generic;

/// <summary>
/// BattleManager — Pokemon-style knowledge battle system.
/// Handles battle flow, question display, HP bars, animations, and results.
/// Supports click-to-answer (not arrow-key selection).
/// </summary>
public class BattleManager : MonoBehaviour
{
    public static BattleManager Instance { get; private set; }

    [Header("Battle UI")]
    public GameObject battleCanvas;
    public GameObject battlePanel;

    [Header("Player Side")]
    public Image playerAvatar;
    public TextMeshProUGUI playerNameText;
    public Slider playerHPBar;
    public TextMeshProUGUI playerHPText;
    public TextMeshProUGUI playerLevelText;

    [Header("Opponent Side")]
    public Image opponentAvatar;
    public TextMeshProUGUI opponentNameText;
    public Slider opponentHPBar;
    public TextMeshProUGUI opponentHPText;
    public TextMeshProUGUI opponentLevelText;

    [Header("Question Area")]
    public TextMeshProUGUI questionText;
    public TextMeshProUGUI topicText;
    public TextMeshProUGUI questionCountText;

    [Header("Answer Buttons (Click to Answer)")]
    public List<Button> answerButtons;
    public List<TextMeshProUGUI> answerTexts;
    public List<Image> answerButtonImages;

    [Header("Feedback")]
    public GameObject feedbackPanel;
    public TextMeshProUGUI feedbackText;
    public Image feedbackIcon;
    public Sprite correctIcon;
    public Sprite wrongIcon;

    [Header("Battle Info")]
    public TextMeshProUGUI battleInfoText;
    public GameObject xpGainPanel;
    public TextMeshProUGUI xpGainText;

    [Header("Colors")]
    public Color correctColor = new Color(0.2f, 0.8f, 0.2f);
    public Color wrongColor = new Color(0.8f, 0.2f, 0.2f);
    public Color normalColor = new Color(0.3f, 0.3f, 0.5f);
    public Color hoverColor = new Color(0.4f, 0.4f, 0.6f);

    [Header("Battle Settings")]
    public int questionsPerBattle = 5;
    public int questionsPerGymBattle = 10;
    public int questionsPerSilverMountain = 20;
    public float feedbackDuration = 1.5f;
    public int damagePerWrongAnswer = 20;
    public int damagePerCorrectAnswer = 25;

    [Header("Animation")]
    public Animator playerBattleAnimator;
    public Animator opponentBattleAnimator;
    public GameObject damageEffectPrefab;
    public GameObject healEffectPrefab;

    [Header("Audio")]
    public AudioClip battleStartSound;
    public AudioClip correctAnswerSound;
    public AudioClip wrongAnswerSound;
    public AudioClip victorySound;
    public AudioClip defeatSound;
    public AudioClip battleMusic;
    private AudioSource audioSource;

    // Battle State
    private BattleData currentBattle;
    private List<QuestionData> questions;
    private int currentQuestionIndex = 0;
    private int playerHP;
    private int playerMaxHP;
    private int opponentHP;
    private int opponentMaxHP;
    private int correctAnswers = 0;
    private int totalQuestions = 0;
    private bool isBattleActive = false;
    private float battleStartTime;
    private bool waitingForAnswer = false;

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;

        audioSource = GetComponent<AudioSource>();
        if (audioSource == null)
            audioSource = gameObject.AddComponent<AudioSource>();

        HideBattle();
    }

    /// <summary>
    /// Start a knowledge battle.
    /// </summary>
    public void StartBattle(BattleData data)
    {
        currentBattle = data;
        currentQuestionIndex = 0;
        correctAnswers = 0;
        isBattleActive = true;
        battleStartTime = Time.time;

        // Determine question count
        if (data.isSilverMountain)
            totalQuestions = questionsPerSilverMountain;
        else if (data.isGymBattle)
            totalQuestions = questionsPerGymBattle;
        else
            totalQuestions = questionsPerBattle;

        // Set HP
        playerMaxHP = GameManager.Instance.playerData.maxHp;
        playerHP = playerMaxHP;
        opponentMaxHP = 100 + (data.difficulty * 10);
        opponentHP = opponentMaxHP;

        // Load questions
        questions = QuestionBank.Instance.GetQuestions(
            GameManager.Instance.currentSubject.ToString(),
            data.topic,
            data.difficulty,
            totalQuestions
        );

        if (questions == null || questions.Count == 0)
        {
            Debug.LogError("[BattleManager] No questions loaded! Using fallback.");
            questions = QuestionBank.Instance.GetFallbackQuestions(totalQuestions);
        }

        // Disable player movement
        PlayerController player = FindObjectOfType<PlayerController>();
        if (player != null) player.SetCanMove(false);

        // Set game state
        if (data.isGymBattle)
            GameManager.Instance.SetGameState(GameState.GymBattle);
        else if (data.isSilverMountain)
            GameManager.Instance.SetGameState(GameState.SilverMountain);
        else
            GameManager.Instance.SetGameState(GameState.Battle);

        // Show battle UI
        StartCoroutine(BattleIntro());
    }

    private IEnumerator BattleIntro()
    {
        battleCanvas.SetActive(true);
        battlePanel.SetActive(true);

        // Set up player info
        playerNameText.text = GameManager.Instance.playerData.playerName;
        playerLevelText.text = $"Lv.{GameManager.Instance.playerData.level}";
        UpdateHPBar(playerHPBar, playerHPText, playerHP, playerMaxHP);

        // Set up opponent info
        opponentNameText.text = currentBattle.opponentName;
        opponentLevelText.text = $"Lv.{currentBattle.difficulty}";
        if (currentBattle.opponentPortrait != null)
            opponentAvatar.sprite = currentBattle.opponentPortrait;
        UpdateHPBar(opponentHPBar, opponentHPText, opponentHP, opponentMaxHP);

        // Battle start announcement
        if (battleStartSound != null)
            audioSource.PlayOneShot(battleStartSound);

        battleInfoText.text = $"A Knowledge Battle with {currentBattle.opponentName} begins!";
        battleInfoText.gameObject.SetActive(true);

        // Hide question area initially
        HideAnswers();
        questionText.text = "";

        yield return new WaitForSeconds(2f);

        battleInfoText.gameObject.SetActive(false);

        // Show first question
        ShowNextQuestion();
    }

    private void ShowNextQuestion()
    {
        if (currentQuestionIndex >= questions.Count || currentQuestionIndex >= totalQuestions)
        {
            EndBattle();
            return;
        }

        // Check if either side is defeated
        if (playerHP <= 0)
        {
            EndBattle();
            return;
        }
        if (opponentHP <= 0)
        {
            EndBattle();
            return;
        }

        QuestionData q = questions[currentQuestionIndex];

        // Update question counter
        questionCountText.text = $"Q{currentQuestionIndex + 1}/{totalQuestions}";
        topicText.text = q.topic;

        // Show question
        questionText.text = q.question;

        // Show answer buttons (CLICK TO ANSWER)
        List<string> shuffledAnswers = new List<string>(q.answers);
        int correctIndex = 0;

        // Shuffle answers
        for (int i = shuffledAnswers.Count - 1; i > 0; i--)
        {
            int j = Random.Range(0, i + 1);
            string temp = shuffledAnswers[i];
            shuffledAnswers[i] = shuffledAnswers[j];
            shuffledAnswers[j] = temp;
        }

        // Find correct answer index after shuffle
        correctIndex = shuffledAnswers.IndexOf(q.correctAnswer);

        for (int i = 0; i < answerButtons.Count; i++)
        {
            if (i < shuffledAnswers.Count)
            {
                answerButtons[i].gameObject.SetActive(true);
                answerTexts[i].text = shuffledAnswers[i];
                answerButtonImages[i].color = normalColor;

                int buttonIndex = i;
                bool isCorrect = (i == correctIndex);
                string answer = shuffledAnswers[i];

                answerButtons[i].onClick.RemoveAllListeners();
                answerButtons[i].onClick.AddListener(() => OnAnswerClicked(buttonIndex, isCorrect, answer, q));

                // Hover effects
                var eventTrigger = answerButtons[i].GetComponent<UnityEngine.EventSystems.EventTrigger>();
                if (eventTrigger == null)
                    eventTrigger = answerButtons[i].gameObject.AddComponent<UnityEngine.EventSystems.EventTrigger>();
            }
            else
            {
                answerButtons[i].gameObject.SetActive(false);
            }
        }

        waitingForAnswer = true;
        feedbackPanel.SetActive(false);
    }

    private void OnAnswerClicked(int buttonIndex, bool isCorrect, string answer, QuestionData question)
    {
        if (!waitingForAnswer) return;
        waitingForAnswer = false;

        // Disable all buttons
        foreach (var btn in answerButtons)
            btn.interactable = false;

        // Record answer
        GameManager.Instance.playerData.RecordAnswer(isCorrect, question.topic);

        StartCoroutine(ShowAnswerFeedback(buttonIndex, isCorrect, question));
    }

    private IEnumerator ShowAnswerFeedback(int selectedIndex, bool isCorrect, QuestionData question)
    {
        // Highlight correct/wrong
        for (int i = 0; i < answerButtons.Count; i++)
        {
            if (i < question.answers.Count)
            {
                if (answerTexts[i].text == question.correctAnswer)
                    answerButtonImages[i].color = correctColor;
                else if (i == selectedIndex && !isCorrect)
                    answerButtonImages[i].color = wrongColor;
            }
        }

        if (isCorrect)
        {
            correctAnswers++;

            // Damage opponent
            int damage = damagePerCorrectAnswer + (GameManager.Instance.playerData.streak * 2);
            opponentHP = Mathf.Max(0, opponentHP - damage);
            UpdateHPBar(opponentHPBar, opponentHPText, opponentHP, opponentMaxHP);

            // Feedback
            feedbackPanel.SetActive(true);
            feedbackText.text = $"Correct! -{damage} HP";
            feedbackText.color = correctColor;
            if (feedbackIcon != null && correctIcon != null)
                feedbackIcon.sprite = correctIcon;

            if (correctAnswerSound != null)
                audioSource.PlayOneShot(correctAnswerSound);

            // Play attack animation
            if (playerBattleAnimator != null)
                playerBattleAnimator.SetTrigger("Attack");
            if (opponentBattleAnimator != null)
                opponentBattleAnimator.SetTrigger("TakeDamage");
        }
        else
        {
            // Player takes damage
            int damage = damagePerWrongAnswer;
            playerHP = Mathf.Max(0, playerHP - damage);
            UpdateHPBar(playerHPBar, playerHPText, playerHP, playerMaxHP);

            // Feedback
            feedbackPanel.SetActive(true);
            feedbackText.text = $"Wrong! The answer was: {question.correctAnswer}\n-{damage} HP";
            feedbackText.color = wrongColor;
            if (feedbackIcon != null && wrongIcon != null)
                feedbackIcon.sprite = wrongIcon;

            if (wrongAnswerSound != null)
                audioSource.PlayOneShot(wrongAnswerSound);

            // Play damage animation
            if (opponentBattleAnimator != null)
                opponentBattleAnimator.SetTrigger("Attack");
            if (playerBattleAnimator != null)
                playerBattleAnimator.SetTrigger("TakeDamage");
        }

        yield return new WaitForSeconds(feedbackDuration);

        feedbackPanel.SetActive(false);

        // Re-enable buttons
        foreach (var btn in answerButtons)
            btn.interactable = true;

        currentQuestionIndex++;
        ShowNextQuestion();
    }

    private void EndBattle()
    {
        isBattleActive = false;
        bool playerWon = opponentHP <= 0 || (playerHP > 0 && correctAnswers >= totalQuestions / 2);

        StartCoroutine(BattleResult(playerWon));
    }

    private IEnumerator BattleResult(bool playerWon)
    {
        HideAnswers();
        questionText.text = "";

        if (playerWon)
        {
            // Victory!
            if (victorySound != null)
                audioSource.PlayOneShot(victorySound);

            battleInfoText.text = $"You defeated {currentBattle.opponentName}!";
            battleInfoText.gameObject.SetActive(true);

            yield return new WaitForSeconds(2f);

            // XP gain
            int xpGain = currentBattle.xpReward;
            float accuracy = (float)correctAnswers / totalQuestions;
            xpGain = Mathf.RoundToInt(xpGain * (1f + accuracy)); // Bonus for high accuracy

            GameManager.Instance.AddExperience(xpGain);
            GameManager.Instance.playerData.battlesWon++;

            xpGainPanel.SetActive(true);
            xpGainText.text = $"+{xpGain} XP";

            yield return new WaitForSeconds(2f);
            xpGainPanel.SetActive(false);

            // Badge for gym battles
            if (currentBattle.isGymBattle)
            {
                GameManager.Instance.EarnBadge(currentBattle.gymIndex + 1, currentBattle.opponentName);
                battleInfoText.text = $"You earned the {currentBattle.opponentName} Badge!";
                yield return new WaitForSeconds(2f);
            }

            // Kaiser title for Silver Mountain
            if (currentBattle.isSilverMountain)
            {
                GameManager.Instance.playerData.isKaiser = true;
                battleInfoText.text = "You have become a KAISER!\nMaster of Knowledge!";
                yield return new WaitForSeconds(3f);
            }
        }
        else
        {
            // Defeat
            if (defeatSound != null)
                audioSource.PlayOneShot(defeatSound);

            battleInfoText.text = "You were defeated...";
            battleInfoText.gameObject.SetActive(true);
            GameManager.Instance.playerData.battlesLost++;

            yield return new WaitForSeconds(2f);

            if (currentBattle.isSilverMountain)
            {
                int attemptsLeft = 3 - GameManager.Instance.playerData.silverMountainAttempts;
                if (attemptsLeft > 0)
                {
                    battleInfoText.text = $"You have {attemptsLeft} attempts remaining.";
                }
                else
                {
                    battleInfoText.text = "You must wait 24 hours before trying again.\nReview what you've learned!";
                }
                yield return new WaitForSeconds(3f);
            }
        }

        // Invoke callback
        currentBattle.onBattleComplete?.Invoke(playerWon);

        // Clean up
        HideBattle();

        // Re-enable player movement
        PlayerController player = FindObjectOfType<PlayerController>();
        if (player != null) player.SetCanMove(true);

        GameManager.Instance.SetGameState(GameState.Overworld);
    }

    private void UpdateHPBar(Slider hpBar, TextMeshProUGUI hpText, int current, int max)
    {
        if (hpBar != null)
        {
            hpBar.maxValue = max;
            hpBar.value = current;
        }
        if (hpText != null)
        {
            hpText.text = $"{current}/{max}";
        }
    }

    private void HideAnswers()
    {
        foreach (var btn in answerButtons)
            btn.gameObject.SetActive(false);
    }

    private void HideBattle()
    {
        if (battleCanvas != null)
            battleCanvas.SetActive(false);
        if (battlePanel != null)
            battlePanel.SetActive(false);
    }
}

// ============================================================
// BATTLE DATA
// ============================================================

[System.Serializable]
public class BattleData
{
    public string opponentName;
    public Sprite opponentPortrait;
    public string topic;
    public int difficulty;
    public int xpReward;
    public bool isGymBattle;
    public int gymIndex;
    public bool isSilverMountain;
    public System.Action<bool> onBattleComplete;
}
