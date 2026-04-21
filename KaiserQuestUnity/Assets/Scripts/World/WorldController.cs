// WorldController.cs — World Input + Movement Controller
using UnityEngine;

public class WorldController : MonoBehaviour
{
    Vector2Int _gridPos;
    Vector2    _visualPos;
    int        _facing  = 0;
    bool       _moving  = false;
    int        _frame   = 0;
    float      _frameT  = 0f;

    const int   TS           = 32;
    float       _holdT       = 0f;
    float       _stepT       = 0f;
    Vector2Int  _lastDir     = Vector2Int.zero;
    const float FIRST_DELAY  = 0.20f;
    const float HOLD_RATE    = 0.09f;

    bool DialogOpen => DialogBox.Instance != null && DialogBox.Instance.IsOpen;

    void OnEnable()
    {
        if (WorldManager.Instance != null)
            WorldManager.Instance.InitWorld(GameManager.Instance.BranchKey);
        _gridPos   = GameManager.Instance.GridPos;
        _visualPos = new Vector2(_gridPos.x * TS, _gridPos.y * TS);
        _facing = 0; _moving = false;

        // Subscribe to screen transitions from WorldManager
        if (WorldManager.Instance != null) {
            WorldManager.Instance.OnGymEntered   -= DoStartBattle;
            WorldManager.Instance.OnDuelTriggered -= DoStartDuel;
            WorldManager.Instance.OnGymEntered   += DoStartBattle;
            WorldManager.Instance.OnDuelTriggered += DoStartDuel;
        }
    }

    void OnDisable()
    {
        if (WorldManager.Instance != null) {
            WorldManager.Instance.OnGymEntered   -= DoStartBattle;
            WorldManager.Instance.OnDuelTriggered -= DoStartDuel;
        }
    }

    void DoStartBattle()
    {
        var parts = GameManager.Instance.BranchKey.Split(':');
        if (parts.Length < 2) return;
        int gymNum = GameManager.Instance.Badges.Count + 1;
        var leader = SubjectDB.GetGymLeader(parts[0], parts[1], gymNum);
        var qs     = SubjectDB.GetGymQuestions(parts[0], parts[1], gymNum, 5 + Mathf.Min(gymNum, 7));
        BattleManager.Instance?.Setup(leader, qs, false);
    }

    void DoStartDuel(GymLeaderData opp, float acc)
    {
        DuelManager.Instance?.Setup(GameManager.Instance.BranchKey, opp, acc);
    }

    void Update()
    {
        if (Input.GetKeyDown(KeyCode.Escape)) {
            GameScreenManager.Instance?.GoTo(GameScreen.SubjectSelect); return;
        }
        if (Input.GetKeyDown(KeyCode.F5)) {
            GameManager.Instance?.ResetAll();
            GameScreenManager.Instance?.GoTo(GameScreen.Title); return;
        }
        if (DialogOpen || _moving) {
            _holdT = 0f; _stepT = 0f; _lastDir = Vector2Int.zero; return;
        }

        Vector2Int dir = Vector2Int.zero; int face = -1;
        if      (Input.GetKey(KeyCode.DownArrow) ||Input.GetKey(KeyCode.S))  { dir=new(0, 1);  face=0; }
        else if (Input.GetKey(KeyCode.UpArrow)   ||Input.GetKey(KeyCode.W))  { dir=new(0,-1);  face=1; }
        else if (Input.GetKey(KeyCode.LeftArrow) ||Input.GetKey(KeyCode.A))  { dir=new(-1, 0); face=2; }
        else if (Input.GetKey(KeyCode.RightArrow)||Input.GetKey(KeyCode.D))  { dir=new( 1, 0); face=3; }

        if (Input.GetKeyDown(KeyCode.Return)||Input.GetKeyDown(KeyCode.Space)||Input.GetKeyDown(KeyCode.KeypadEnter)) {
            if (!DialogOpen) WorldManager.Instance?.TryInteract(_gridPos, _facing);
            return;
        }

        if (face >= 0) _facing = face;
        if (dir == Vector2Int.zero) { _holdT=0f; _stepT=0f; _lastDir=Vector2Int.zero; return; }
        if (dir != _lastDir)        { _lastDir=dir; _holdT=0f; _stepT=0f; TryStep(dir); return; }

        _holdT += Time.deltaTime;
        if (_holdT < FIRST_DELAY) return;
        _stepT += Time.deltaTime;
        if (_stepT >= HOLD_RATE)  { _stepT=0f; TryStep(dir); }
    }

    void TryStep(Vector2Int dir)
    {
        if (WorldManager.Instance == null) return;
        if (WorldManager.Instance.TryMove(_gridPos, dir, out var dest)) {
            _gridPos = dest; _moving = true;
            _frameT += 0.10f;
            if (_frameT >= 0.10f) { _frameT = 0f; _frame = 1 - _frame; }
            StartCoroutine(SmoothMove(new Vector2(dest.x * TS, dest.y * TS)));
        }
    }

    System.Collections.IEnumerator SmoothMove(Vector2 target)
    {
        Vector2 start = _visualPos;
        float   t     = 0f;
        while (t < 0.10f) {
            t += Time.deltaTime;
            _visualPos = Vector2.Lerp(start, target, t / 0.10f);
            yield return null;
        }
        _visualPos = target;
        _moving    = false;
        WorldManager.Instance?.OnPlayerMoved(_gridPos);
        WorldManager.Instance?.SetPlayerState(_visualPos, _facing, _moving, _frame);
    }

    void OnGUI()
    {
        if (GameScreenManager.Instance?.Current != GameScreen.World) return;
        PixelRenderer.BeginFrame();
        WorldManager.Instance?.SetPlayerState(_visualPos, _facing, _moving, _frame);
        WorldManager.Instance?.DrawWorld();
        PixelRenderer.EndFrame();
    }
}
