using UnityEngine;
using UnityEngine.UI;
using TMPro;
using System.Collections.Generic;

/// <summary>
/// MainMenuUI — Handles the main menu screen.
/// </summary>
public class MainMenuUI : MonoBehaviour
{
    [Header("Panels")]
    public GameObject mainMenuPanel;
    public GameObject newGamePanel;
    public GameObject loadGamePanel;

    [Header("Main Menu Buttons")]
    public Button newGameButton;
    public Button continueButton;
    public Button settingsButton;
    public Button quitButton;

    [Header("New Game")]
    public TMP_InputField playerNameInput;
    public Button startButton;
    public Button backButton;

    [Header("Title")]
    public TextMeshProUGUI titleText;
    public TextMeshProUGUI versionText;

    private void Start()
    {
        ShowMainMenu();

        // Check if save exists
        bool hasSave = PlayerPrefs.HasKey("KaiserQuest_SaveData");
        if (continueButton != null)
            continueButton.interactable = hasSave;

        // Button listeners
        newGameButton?.onClick.AddListener(OnNewGame);
        continueButton?.onClick.AddListener(OnContinue);
        settingsButton?.onClick.AddListener(OnSettings);
        quitButton?.onClick.AddListener(OnQuit);
        startButton?.onClick.AddListener(OnStartNewGame);
        backButton?.onClick.AddListener(ShowMainMenu);

        if (titleText != null)
            titleText.text = "KAISERQUEST";
        if (versionText != null)
            versionText.text = "v0.1.0";
    }

    private void ShowMainMenu()
    {
        mainMenuPanel?.SetActive(true);
        newGamePanel?.SetActive(false);
        loadGamePanel?.SetActive(false);
    }

    private void OnNewGame()
    {
        mainMenuPanel?.SetActive(false);
        newGamePanel?.SetActive(true);
        playerNameInput?.SetTextWithoutNotify("Arix");
    }

    private void OnContinue()
    {
        if (GameManager.Instance.LoadGame())
        {
            // Load overworld scene
            SceneLoader.Instance?.LoadScene("SubjectSelect");
        }
    }

    private void OnStartNewGame()
    {
        string name = playerNameInput?.text ?? "Arix";
        if (string.IsNullOrWhiteSpace(name)) name = "Arix";

        GameManager.Instance.NewGame(name);
        SceneLoader.Instance?.LoadScene("SubjectSelect");
    }

    private void OnSettings()
    {
        Debug.Log("Settings not yet implemented");
    }

    private void OnQuit()
    {
#if UNITY_EDITOR
        UnityEditor.EditorApplication.isPlaying = false;
#else
        Application.Quit();
#endif
    }
}

/// <summary>
/// SubjectSelectUI — Lets the player choose a subject and branch.
/// </summary>
public class SubjectSelectUI : MonoBehaviour
{
    [Header("Panels")]
    public GameObject subjectPanel;
    public GameObject branchPanel;

    [Header("Subject Buttons")]
    public Button mathButton;
    public Button languageButton;
    public Button musicButton;
    public Button backButton;

    [Header("Branch Buttons")]
    public List<Button> branchButtons;
    public List<TextMeshProUGUI> branchTexts;
    public Button branchBackButton;

    [Header("Info")]
    public TextMeshProUGUI subjectTitle;
    public TextMeshProUGUI subjectDescription;

    private SubjectType selectedSubject;

    private readonly Dictionary<SubjectType, List<string>> branches = new Dictionary<SubjectType, List<string>>
    {
        { SubjectType.Mathematics, new List<string> { "Algebra", "Geometry", "Calculus" } },
        { SubjectType.Languages, new List<string> { "English", "Spanish", "French" } },
        { SubjectType.Music, new List<string> { "Music Theory", "Composition", "History" } }
    };

    private readonly Dictionary<SubjectType, string> descriptions = new Dictionary<SubjectType, string>
    {
        { SubjectType.Mathematics, "Master the language of the universe! Solve equations, conquer variables, and unlock the power of numbers." },
        { SubjectType.Languages, "Words are your weapons! Master grammar, expand vocabulary, and become a master communicator." },
        { SubjectType.Music, "Feel the rhythm of knowledge! Learn notes, chords, scales, and become a musical scholar." }
    };

    private void Start()
    {
        ShowSubjects();

        mathButton?.onClick.AddListener(() => SelectSubject(SubjectType.Mathematics));
        languageButton?.onClick.AddListener(() => SelectSubject(SubjectType.Languages));
        musicButton?.onClick.AddListener(() => SelectSubject(SubjectType.Music));
        backButton?.onClick.AddListener(() => SceneLoader.Instance?.LoadScene("MainMenu"));
        branchBackButton?.onClick.AddListener(ShowSubjects);
    }

    private void ShowSubjects()
    {
        subjectPanel?.SetActive(true);
        branchPanel?.SetActive(false);
    }

    private void SelectSubject(SubjectType subject)
    {
        selectedSubject = subject;
        subjectPanel?.SetActive(false);
        branchPanel?.SetActive(true);

        if (subjectTitle != null)
            subjectTitle.text = subject.ToString();
        if (subjectDescription != null)
            subjectDescription.text = descriptions[subject];

        // Set up branch buttons
        List<string> subjectBranches = branches[subject];
        for (int i = 0; i < branchButtons.Count; i++)
        {
            if (i < subjectBranches.Count)
            {
                branchButtons[i].gameObject.SetActive(true);
                branchTexts[i].text = subjectBranches[i];

                int index = i;
                branchButtons[i].onClick.RemoveAllListeners();
                branchButtons[i].onClick.AddListener(() => SelectBranch(subjectBranches[index]));
            }
            else
            {
                branchButtons[i].gameObject.SetActive(false);
            }
        }
    }

    private void SelectBranch(string branch)
    {
        GameManager.Instance.SelectSubject(selectedSubject, branch);
        SceneLoader.Instance?.LoadScene("Overworld");
    }
}

/// <summary>
/// HUD — In-game heads-up display showing player stats.
/// </summary>
public class HUD : MonoBehaviour
{
    [Header("Player Info")]
    public TextMeshProUGUI levelText;
    public TextMeshProUGUI expText;
    public Slider expBar;
    public TextMeshProUGUI hpText;
    public Slider hpBar;
    public TextMeshProUGUI cityText;

    [Header("Badge Display")]
    public List<Image> badgeIcons;

    [Header("Quick Info")]
    public TextMeshProUGUI subjectText;
    public TextMeshProUGUI branchText;

    private void Update()
    {
        if (GameManager.Instance == null) return;

        PlayerData data = GameManager.Instance.playerData;

        if (levelText != null)
            levelText.text = $"Lv.{data.level}";

        if (expBar != null)
        {
            expBar.maxValue = data.GetExpForNextLevel();
            expBar.value = data.experience;
        }
        if (expText != null)
            expText.text = $"EXP: {data.experience}/{data.GetExpForNextLevel()}";

        if (hpBar != null)
        {
            hpBar.maxValue = data.maxHp;
            hpBar.value = data.hp;
        }
        if (hpText != null)
            hpText.text = $"HP: {data.hp}/{data.maxHp}";

        if (cityText != null)
            cityText.text = GameManager.Instance.currentCity;

        if (subjectText != null)
            subjectText.text = GameManager.Instance.currentSubject.ToString();
        if (branchText != null)
            branchText.text = GameManager.Instance.currentBranch;

        // Update badge icons
        if (badgeIcons != null)
        {
            for (int i = 0; i < badgeIcons.Count; i++)
            {
                if (data.earnedBadges.Contains(i + 1))
                {
                    badgeIcons[i].color = Color.white;
                }
                else
                {
                    badgeIcons[i].color = new Color(0.2f, 0.2f, 0.2f, 0.5f);
                }
            }
        }
    }
}

/// <summary>
/// PauseMenuUI — In-game pause menu.
/// </summary>
public class PauseMenuUI : MonoBehaviour
{
    [Header("UI")]
    public GameObject pausePanel;
    public Button resumeButton;
    public Button saveButton;
    public Button badgesButton;
    public Button statsButton;
    public Button mainMenuButton;

    [Header("Sub Panels")]
    public GameObject badgePanel;
    public GameObject statsPanel;

    [Header("Stats Display")]
    public TextMeshProUGUI statsText;

    private bool isPaused = false;

    private void Start()
    {
        pausePanel?.SetActive(false);

        resumeButton?.onClick.AddListener(Resume);
        saveButton?.onClick.AddListener(SaveGame);
        badgesButton?.onClick.AddListener(ShowBadges);
        statsButton?.onClick.AddListener(ShowStats);
        mainMenuButton?.onClick.AddListener(ReturnToMainMenu);
    }

    public void Toggle()
    {
        if (isPaused) Resume();
        else Pause();
    }

    private void Pause()
    {
        isPaused = true;
        Time.timeScale = 0f;
        pausePanel?.SetActive(true);
        badgePanel?.SetActive(false);
        statsPanel?.SetActive(false);
    }

    private void Resume()
    {
        isPaused = false;
        Time.timeScale = 1f;
        pausePanel?.SetActive(false);
        GameManager.Instance?.SetGameState(GameState.Overworld);
    }

    private void SaveGame()
    {
        GameManager.Instance?.SaveGame();
        DialogSystem.Instance?.ShowDialog("System", "Game saved successfully!");
    }

    private void ShowBadges()
    {
        badgePanel?.SetActive(true);
        statsPanel?.SetActive(false);
    }

    private void ShowStats()
    {
        statsPanel?.SetActive(true);
        badgePanel?.SetActive(false);

        if (statsText != null && GameManager.Instance != null)
        {
            PlayerData data = GameManager.Instance.playerData;
            statsText.text = $"Player: {data.playerName}\n" +
                           $"Level: {data.level}\n" +
                           $"Total XP: {data.totalExp}\n" +
                           $"Battles Won: {data.battlesWon}\n" +
                           $"Battles Lost: {data.battlesLost}\n" +
                           $"Accuracy: {data.accuracy:P1}\n" +
                           $"Badges: {data.earnedBadges.Count}/20\n" +
                           $"Quests: {data.questsCompleted}\n" +
                           $"Streak: {data.streak}\n" +
                           $"Kaiser: {(data.isKaiser ? "YES" : "Not yet")}";
        }
    }

    private void ReturnToMainMenu()
    {
        Time.timeScale = 1f;
        SceneLoader.Instance?.LoadScene("MainMenu");
    }
}
