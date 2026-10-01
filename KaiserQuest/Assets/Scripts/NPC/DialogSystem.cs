using UnityEngine;
using UnityEngine.UI;
using TMPro;
using System.Collections;
using System.Collections.Generic;

/// <summary>
/// DialogSystem — Pokemon-style dialog boxes with typewriter effect.
/// Supports multi-line text, choice prompts, and NPC portraits.
/// </summary>
public class DialogSystem : MonoBehaviour
{
    public static DialogSystem Instance { get; private set; }

    [Header("UI References")]
    public GameObject dialogPanel;
    public TextMeshProUGUI dialogText;
    public TextMeshProUGUI speakerNameText;
    public Image speakerPortrait;
    public GameObject continueIndicator; // Little arrow that bounces
    public GameObject choicePanel;
    public List<Button> choiceButtons;
    public List<TextMeshProUGUI> choiceTexts;

    [Header("Settings")]
    public float typewriterSpeed = 0.03f;
    public AudioClip typewriterSound;
    public AudioClip advanceSound;

    private Queue<DialogLine> dialogQueue = new Queue<DialogLine>();
    private bool isTyping = false;
    private bool isDialogActive = false;
    private string currentFullText = "";
    private Coroutine typingCoroutine;
    private System.Action onDialogComplete;
    private System.Action<int> onChoiceMade;
    private AudioSource audioSource;

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

        HideDialog();
    }

    /// <summary>
    /// Show a sequence of dialog lines.
    /// </summary>
    public void ShowDialog(List<DialogLine> lines, System.Action onComplete = null)
    {
        if (isDialogActive) return;

        dialogQueue.Clear();
        foreach (var line in lines)
        {
            dialogQueue.Enqueue(line);
        }

        onDialogComplete = onComplete;
        isDialogActive = true;

        // Disable player movement
        PlayerController player = FindObjectOfType<PlayerController>();
        if (player != null) player.SetCanMove(false);

        if (GameManager.Instance != null)
            GameManager.Instance.SetGameState(GameState.Dialog);

        dialogPanel.SetActive(true);
        ShowNextLine();
    }

    /// <summary>
    /// Show a single dialog line.
    /// </summary>
    public void ShowDialog(string speaker, string text, Sprite portrait = null, System.Action onComplete = null)
    {
        var lines = new List<DialogLine>
        {
            new DialogLine(speaker, text, portrait)
        };
        ShowDialog(lines, onComplete);
    }

    /// <summary>
    /// Show a choice dialog (e.g., "Do you want to challenge the gym?")
    /// </summary>
    public void ShowChoice(string speaker, string question, List<string> choices, System.Action<int> onChoice, Sprite portrait = null)
    {
        onChoiceMade = onChoice;

        var lines = new List<DialogLine>
        {
            new DialogLine(speaker, question, portrait, true, choices)
        };
        ShowDialog(lines);
    }

    private void ShowNextLine()
    {
        if (dialogQueue.Count == 0)
        {
            EndDialog();
            return;
        }

        DialogLine line = dialogQueue.Dequeue();

        // Set speaker name
        if (speakerNameText != null)
        {
            speakerNameText.text = line.speakerName;
            speakerNameText.gameObject.SetActive(!string.IsNullOrEmpty(line.speakerName));
        }

        // Set portrait
        if (speakerPortrait != null)
        {
            if (line.portrait != null)
            {
                speakerPortrait.sprite = line.portrait;
                speakerPortrait.gameObject.SetActive(true);
            }
            else
            {
                speakerPortrait.gameObject.SetActive(false);
            }
        }

        // Hide continue indicator and choices
        if (continueIndicator != null)
            continueIndicator.SetActive(false);
        if (choicePanel != null)
            choicePanel.SetActive(false);

        // Start typewriter effect
        currentFullText = line.text;
        if (typingCoroutine != null)
            StopCoroutine(typingCoroutine);
        typingCoroutine = StartCoroutine(TypeText(line));
    }

    private IEnumerator TypeText(DialogLine line)
    {
        isTyping = true;
        dialogText.text = "";

        foreach (char c in currentFullText)
        {
            dialogText.text += c;

            // Play typewriter sound every few characters
            if (typewriterSound != null && c != ' ' && audioSource != null)
            {
                audioSource.PlayOneShot(typewriterSound, 0.3f);
            }

            yield return new WaitForSeconds(typewriterSpeed);
        }

        isTyping = false;

        // Show choices or continue indicator
        if (line.hasChoices && line.choices != null)
        {
            ShowChoices(line.choices);
        }
        else
        {
            if (continueIndicator != null)
                continueIndicator.SetActive(true);
        }
    }

    private void ShowChoices(List<string> choices)
    {
        if (choicePanel == null) return;

        choicePanel.SetActive(true);

        for (int i = 0; i < choiceButtons.Count; i++)
        {
            if (i < choices.Count)
            {
                choiceButtons[i].gameObject.SetActive(true);
                choiceTexts[i].text = choices[i];

                int index = i; // Capture for lambda
                choiceButtons[i].onClick.RemoveAllListeners();
                choiceButtons[i].onClick.AddListener(() => OnChoiceSelected(index));
            }
            else
            {
                choiceButtons[i].gameObject.SetActive(false);
            }
        }
    }

    private void OnChoiceSelected(int index)
    {
        if (choicePanel != null)
            choicePanel.SetActive(false);

        onChoiceMade?.Invoke(index);
        ShowNextLine();
    }

    private void Update()
    {
        if (!isDialogActive) return;

        // Advance dialog with Z, Enter, Space, or mouse click
        if (Input.GetKeyDown(KeyCode.Z) || Input.GetKeyDown(KeyCode.Return) || 
            Input.GetKeyDown(KeyCode.Space) || Input.GetMouseButtonDown(0))
        {
            if (isTyping)
            {
                // Skip typewriter — show full text immediately
                StopCoroutine(typingCoroutine);
                dialogText.text = currentFullText;
                isTyping = false;

                if (continueIndicator != null)
                    continueIndicator.SetActive(true);
            }
            else if (choicePanel != null && choicePanel.activeSelf)
            {
                // Choices are showing — wait for click on choice button
                return;
            }
            else
            {
                // Advance to next line
                if (advanceSound != null && audioSource != null)
                    audioSource.PlayOneShot(advanceSound);
                ShowNextLine();
            }
        }
    }

    private void EndDialog()
    {
        isDialogActive = false;
        HideDialog();

        // Re-enable player movement
        PlayerController player = FindObjectOfType<PlayerController>();
        if (player != null) player.SetCanMove(true);

        if (GameManager.Instance != null)
            GameManager.Instance.SetGameState(GameState.Overworld);

        onDialogComplete?.Invoke();
        onDialogComplete = null;
    }

    private void HideDialog()
    {
        if (dialogPanel != null)
            dialogPanel.SetActive(false);
        if (choicePanel != null)
            choicePanel.SetActive(false);
    }

    public bool IsActive() => isDialogActive;
}

// ============================================================
// DIALOG LINE DATA
// ============================================================

[System.Serializable]
public class DialogLine
{
    public string speakerName;
    public string text;
    public Sprite portrait;
    public bool hasChoices;
    public List<string> choices;

    public DialogLine(string speaker, string text, Sprite portrait = null, bool hasChoices = false, List<string> choices = null)
    {
        this.speakerName = speaker;
        this.text = text;
        this.portrait = portrait;
        this.hasChoices = hasChoices;
        this.choices = choices ?? new List<string>();
    }
}
