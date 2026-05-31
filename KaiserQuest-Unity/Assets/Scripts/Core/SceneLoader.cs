using UnityEngine;
using UnityEngine.SceneManagement;
using System.Collections;

/// <summary>
/// SceneLoader — Handles scene transitions with fade effects.
/// </summary>
public class SceneLoader : MonoBehaviour
{
    public static SceneLoader Instance { get; private set; }

    [Header("Transition")]
    public CanvasGroup fadePanel;
    public float fadeDuration = 0.5f;

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;
        DontDestroyOnLoad(gameObject);
    }

    public void LoadScene(string sceneName)
    {
        StartCoroutine(TransitionToScene(sceneName));
    }

    private IEnumerator TransitionToScene(string sceneName)
    {
        // Fade out
        if (fadePanel != null)
        {
            fadePanel.gameObject.SetActive(true);
            yield return StartCoroutine(Fade(0f, 1f));
        }

        // Load scene
        AsyncOperation asyncLoad = SceneManager.LoadSceneAsync(sceneName);
        while (!asyncLoad.isDone)
        {
            yield return null;
        }

        // Fade in
        if (fadePanel != null)
        {
            yield return StartCoroutine(Fade(1f, 0f));
            fadePanel.gameObject.SetActive(false);
        }
    }

    private IEnumerator Fade(float from, float to)
    {
        float elapsed = 0f;
        while (elapsed < fadeDuration)
        {
            elapsed += Time.unscaledDeltaTime;
            fadePanel.alpha = Mathf.Lerp(from, to, elapsed / fadeDuration);
            yield return null;
        }
        fadePanel.alpha = to;
    }
}
