// WorldController.cs  –  Input + smooth movement.  DrawWorld() via WorldManager.
using UnityEngine;

public class WorldController : MonoBehaviour
{
    Vector2Int _gridPos;
    int        _facing  = 0;
    bool       _moving  = false;
    int        _frame   = 0;
    float      _frameAcc= 0f;

    const float STEP_DUR    = 0.12f;  // seconds to cross one tile
    const float FIRST_DELAY = 0.20f;
    const float HOLD_RATE   = 0.10f;

    float      _holdT  = 0f;
    float      _stepT  = 0f;
    Vector2Int _lastDir= Vector2Int.zero;

    bool DialogOpen => DialogBox.Instance != null && DialogBox.Instance.IsOpen;

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    void OnEnable()
    {
        if (WorldManager.Instance == null) return;
        WorldManager.Instance.InitWorld(GameManager.Instance.BranchKey);

        _gridPos = GameManager.Instance.GridPos;
        _facing  = 0; _moving = false;

        WorldManager.Instance.OnGymEntered    -= DoEnterGym;
        WorldManager.Instance.OnDuelTriggered -= DoStartDuel;
        WorldManager.Instance.OnGymEntered    += DoEnterGym;
        WorldManager.Instance.OnDuelTriggered += DoStartDuel;
    }

    void OnDisable()
    {
        if (WorldManager.Instance == null) return;
        WorldManager.Instance.OnGymEntered    -= DoEnterGym;
        WorldManager.Instance.OnDuelTriggered -= DoStartDuel;
    }

    // ── Battle entry points ───────────────────────────────────────────────────
    void DoEnterGym()
    {
        var parts  = GameManager.Instance.BranchKey.Split(':');
        if (parts.Length < 2) return;
        int gymNum = GameManager.Instance.Badges.Count + 1;
        var leader = SubjectDB.GetGymLeader(parts[0], parts[1], gymNum);
        var qs     = SubjectDB.GetGymQuestions(parts[0], parts[1], gymNum, 5 + Mathf.Min(gymNum, 7));
        GameScreenManager.Instance?.GoTo(GameScreen.Battle);
        BattleManager.Instance?.Setup(leader, qs, false);
    }

    void DoStartDuel(GymLeaderData opp, float acc)
    {
        GameScreenManager.Instance?.GoTo(GameScreen.Duel);
        DuelManager.Instance?.Setup(GameManager.Instance.BranchKey, opp, acc);
    }

    // ── Update ────────────────────────────────────────────────────────────────
    void Update()
    {
        if (GameScreenManager.Instance?.Current != GameScreen.World) return;

        if (Input.GetKeyDown(KeyCode.Escape)) {
            GameScreenManager.Instance.GoTo(GameScreen.SubjectSelect); return;
        }
        if (Input.GetKeyDown(KeyCode.F5)) {
            GameManager.Instance?.ResetAll();
            GameScreenManager.Instance.GoTo(GameScreen.Title); return;
        }

        if (DialogOpen || _moving) {
            _holdT = 0f; _stepT = 0f; _lastDir = Vector2Int.zero; return;
        }

        // Directional input
        Vector2Int dir = Vector2Int.zero; int face = -1;
        if      (Input.GetKey(KeyCode.DownArrow)  || Input.GetKey(KeyCode.S)) { dir=new( 0, 1); face=0; }
        else if (Input.GetKey(KeyCode.UpArrow)    || Input.GetKey(KeyCode.W)) { dir=new( 0,-1); face=1; }
        else if (Input.GetKey(KeyCode.LeftArrow)  || Input.GetKey(KeyCode.A)) { dir=new(-1, 0); face=2; }
        else if (Input.GetKey(KeyCode.RightArrow) || Input.GetKey(KeyCode.D)) { dir=new( 1, 0); face=3; }

        // Interact
        if (Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.KeypadEnter)
                                             || Input.GetKeyDown(KeyCode.Space)) {
            if (!DialogOpen) WorldManager.Instance?.TryInteract(_gridPos, _facing);
            return;
        }

        if (face >= 0) _facing = face;

        if (dir == Vector2Int.zero) {
            _holdT=0f; _stepT=0f; _lastDir=Vector2Int.zero; return;
        }
        if (dir != _lastDir) {
            _lastDir=dir; _holdT=0f; _stepT=0f; TryStep(dir); return;
        }
        _holdT += Time.deltaTime;
        if (_holdT < FIRST_DELAY) return;
        _stepT += Time.deltaTime;
        if (_stepT >= HOLD_RATE)  { _stepT=0f; TryStep(dir); }
    }

    void TryStep(Vector2Int dir)
    {
        if (WorldManager.Instance == null) return;
        if (WorldManager.Instance.TryMove(_gridPos, dir, out var dest)) {
            _gridPos = dest;
            _frameAcc += STEP_DUR;
            if (_frameAcc >= STEP_DUR) { _frameAcc=0f; _frame=1-_frame; }
            _moving = true;
            WorldManager.Instance.SetPlayerFacing(_facing);
            WorldManager.Instance.SetPlayerMoving(true, _frame);
            StartCoroutine(SmoothStep(new Vector2(dest.x * WorldManager.TS,
                                                  dest.y * WorldManager.TS)));
        }
    }

    System.Collections.IEnumerator SmoothStep(Vector2 target)
    {
        var start = WorldManager.Instance.PlayerVisualPos;
        float t   = 0f;
        while (t < STEP_DUR) {
            t += Time.deltaTime;
            WorldManager.Instance.SetPlayerVisualPos(
                Vector2.Lerp(start, target, t / STEP_DUR));
            yield return null;
        }
        WorldManager.Instance.SetPlayerVisualPos(target);
        _moving = false;
        WorldManager.Instance.SetPlayerMoving(false, _frame);
        WorldManager.Instance.OnPlayerMoved(_gridPos);
    }

    // ── Draw ──────────────────────────────────────────────────────────────────
    void OnGUI()
    {
        if (GameScreenManager.Instance?.Current != GameScreen.World) return;
        PixelRenderer.BeginFrame();
        WorldManager.Instance?.DrawWorld();
        PixelRenderer.EndFrame();
    }
}
