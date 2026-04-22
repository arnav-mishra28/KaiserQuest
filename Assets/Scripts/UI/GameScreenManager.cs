// GameScreenManager.cs — Central Screen/State Machine
using UnityEngine;

public enum GameScreen { Title, NameEntry, SubjectSelect, World, Battle, Duel, Silver, Kaiser }

public class GameScreenManager : MonoBehaviour
{
    public static GameScreenManager Instance { get; private set; }
    public GameScreen Current { get; private set; } = GameScreen.Title;

    void Awake() {
        if (Instance != null && Instance != this) { Destroy(gameObject); return; }
        Instance = this; DontDestroyOnLoad(gameObject);
    }

    public event System.Action<GameScreen, GameScreen> OnScreenChanged;

    public void GoTo(GameScreen screen) {
        var prev = Current; Current = screen;
        OnScreenChanged?.Invoke(prev, screen);
    }
}
