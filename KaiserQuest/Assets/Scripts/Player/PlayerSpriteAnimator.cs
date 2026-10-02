using UnityEngine;
using KaiserQuest.Story;

/// <summary>
/// Gives the player a body: the right sprite for the character they created, the
/// right sprite for the direction they are facing, and a step bob while walking.
///
/// The player sprite is drawn in code from the character-creation palette, so the
/// appearance chosen at the start of the campaign is visible on the overworld
/// rather than only living in the save file. The bob is applied to a child body
/// transform so it can never fight the controller's grid snapping, which owns the
/// root position.
/// </summary>
[RequireComponent(typeof(PlayerController))]
public class PlayerSpriteAnimator : MonoBehaviour
{
    [Tooltip("Child transform holding the SpriteRenderer. Bobbed while walking.")]
    public Transform body;

    [Header("Walk bob")]
    public float bobHeight = 0.06f;
    public float stepsPerSecond = 6f;

    private PlayerController _controller;
    private SpriteRenderer _renderer;
    private AppearancePreset _appearance;
    private string _appearanceId;
    private PlayerDirection _drawn = PlayerDirection.Down;
    private bool _drawnAnything;
    private float _stepPhase;

    private void Start()
    {
        _controller = GetComponent<PlayerController>();
        _renderer = _controller.spriteRenderer != null
            ? _controller.spriteRenderer
            : GetComponentInChildren<SpriteRenderer>();

        if (body == null && _renderer != null && _renderer.transform != transform)
            body = _renderer.transform;

        ApplyAppearance();
    }

    /// <summary>
    /// Re-read the appearance from the save. Called after character creation, so
    /// the explorer the player just designed is the one who walks out of it.
    /// </summary>
    public void ApplyAppearance()
    {
        _appearance = null;
        _appearanceId = null;

        StoryModeManager story = StoryModeManager.Instance;
        if (story != null && story.Save != null)
        {
            _appearanceId = story.Save.appearanceId;
            _appearance = CharacterCreation.FindAppearance(_appearanceId);
        }

        _drawnAnything = false; // force a redraw in the new palette
    }

    private void Update()
    {
        if (_controller == null || _renderer == null) return;

        // Character creation finishes after the player exists, so the body watches
        // the save rather than requiring the UI to remember to call back here. One
        // string compare per frame buys a wiring requirement removed.
        StoryModeManager story = StoryModeManager.Instance;
        if (story != null && story.Save != null && story.Save.appearanceId != _appearanceId)
            ApplyAppearance();

        Draw(FacingOf(_controller.facingDirection), _controller.isMoving);
        Bob(_controller.isMoving);
    }

    private void Draw(PlayerDirection facing, bool moving)
    {
        if (_drawnAnything && _drawn == facing) return;

        PixelSpriteGenerator sprites = PixelSpriteGenerator.Instance;
        if (sprites == null) return;

        _renderer.sprite = _appearance != null
            ? sprites.GeneratePlayerSprite(facing, _appearance)
            : sprites.GeneratePlayerSprite(facing);

        _drawn = facing;
        _drawnAnything = true;
    }

    private void Bob(bool moving)
    {
        if (body == null) return;

        if (!moving)
        {
            _stepPhase = 0f;
            body.localPosition = Vector3.zero;
            return;
        }

        _stepPhase += Time.deltaTime * stepsPerSecond;
        // Only ever lifts — a sprite that dipped below its tile would read as
        // falling through the floor rather than walking on it.
        float lift = Mathf.Abs(Mathf.Sin(_stepPhase)) * bobHeight;
        body.localPosition = new Vector3(0f, lift, 0f);
    }

    private static PlayerDirection FacingOf(Vector2 direction)
    {
        if (Mathf.Abs(direction.x) > Mathf.Abs(direction.y))
            return direction.x < 0f ? PlayerDirection.Left : PlayerDirection.Right;

        return direction.y > 0f ? PlayerDirection.Up : PlayerDirection.Down;
    }
}
