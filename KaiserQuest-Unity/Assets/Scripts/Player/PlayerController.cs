using UnityEngine;

/// <summary>
/// PlayerController — Grid-based 4-directional movement like Pokemon Gen1/Gen2.
/// The player moves tile-by-tile on a grid, with smooth interpolation.
/// </summary>
public class PlayerController : MonoBehaviour
{
    [Header("Movement")]
    public float moveSpeed = 5f;
    public float gridSize = 1f;
    public LayerMask collisionLayer;
    public LayerMask npcLayer;
    public LayerMask interactableLayer;

    [Header("Animation")]
    public Animator animator;
    public SpriteRenderer spriteRenderer;

    [Header("State")]
    public bool isMoving = false;
    public bool canMove = true;
    public Vector2 facingDirection = Vector2.down;

    private Vector3 targetPosition;
    private Vector2 inputDirection;

    // Animation parameter hashes for performance
    private static readonly int AnimMoveX = Animator.StringToHash("MoveX");
    private static readonly int AnimMoveY = Animator.StringToHash("MoveY");
    private static readonly int AnimIsMoving = Animator.StringToHash("IsMoving");

    private void Start()
    {
        targetPosition = transform.position;

        if (animator == null)
            animator = GetComponent<Animator>();
        if (spriteRenderer == null)
            spriteRenderer = GetComponent<SpriteRenderer>();
    }

    private void Update()
    {
        if (!canMove) return;

        if (isMoving)
        {
            MoveToTarget();
        }
        else
        {
            HandleInput();
        }

        // Handle interaction
        if (Input.GetKeyDown(KeyCode.Z) || Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.Space))
        {
            TryInteract();
        }

        // Handle menu
        if (Input.GetKeyDown(KeyCode.X) || Input.GetKeyDown(KeyCode.Escape))
        {
            OpenPauseMenu();
        }
    }

    private void HandleInput()
    {
        inputDirection = Vector2.zero;

        // Get input (keyboard + mouse click support for mobile later)
        if (Input.GetKey(KeyCode.W) || Input.GetKey(KeyCode.UpArrow))
            inputDirection = Vector2.up;
        else if (Input.GetKey(KeyCode.S) || Input.GetKey(KeyCode.DownArrow))
            inputDirection = Vector2.down;
        else if (Input.GetKey(KeyCode.A) || Input.GetKey(KeyCode.LeftArrow))
            inputDirection = Vector2.left;
        else if (Input.GetKey(KeyCode.D) || Input.GetKey(KeyCode.RightArrow))
            inputDirection = Vector2.right;

        if (inputDirection != Vector2.zero)
        {
            facingDirection = inputDirection;
            UpdateAnimation(inputDirection, true);

            Vector3 nextPos = transform.position + new Vector3(inputDirection.x, inputDirection.y, 0) * gridSize;

            // Check collision before moving
            if (!IsCollision(nextPos))
            {
                targetPosition = nextPos;
                isMoving = true;
            }
        }
        else
        {
            UpdateAnimation(facingDirection, false);
        }
    }

    private void MoveToTarget()
    {
        transform.position = Vector3.MoveTowards(transform.position, targetPosition, moveSpeed * Time.deltaTime);

        if (Vector3.Distance(transform.position, targetPosition) < 0.01f)
        {
            transform.position = targetPosition;
            isMoving = false;

            // Snap to grid
            transform.position = new Vector3(
                Mathf.Round(transform.position.x / gridSize) * gridSize,
                Mathf.Round(transform.position.y / gridSize) * gridSize,
                transform.position.z
            );

            // Check for tile triggers (tall grass, city entrance, etc.)
            CheckTileTriggers();
        }
    }

    private bool IsCollision(Vector3 targetPos)
    {
        // Raycast to check for solid colliders
        Vector2 direction = (targetPos - transform.position).normalized;
        RaycastHit2D hit = Physics2D.Raycast(
            (Vector2)transform.position + direction * 0.5f,
            direction,
            0.1f,
            collisionLayer | npcLayer
        );

        return hit.collider != null;
    }

    private void TryInteract()
    {
        // Cast a ray in the facing direction to find interactable objects
        RaycastHit2D hit = Physics2D.Raycast(
            (Vector2)transform.position,
            facingDirection,
            gridSize,
            npcLayer | interactableLayer
        );

        if (hit.collider != null)
        {
            // Try NPC interaction
            NPCController npc = hit.collider.GetComponent<NPCController>();
            if (npc != null)
            {
                npc.Interact(this);
                return;
            }

            // Try generic interactable
            IInteractable interactable = hit.collider.GetComponent<IInteractable>();
            if (interactable != null)
            {
                interactable.Interact(this);
            }
        }
    }

    private void CheckTileTriggers()
    {
        // Check for triggers at current position
        Collider2D trigger = Physics2D.OverlapPoint(transform.position, interactableLayer);
        if (trigger != null)
        {
            // City entrance
            CityEntrance entrance = trigger.GetComponent<CityEntrance>();
            if (entrance != null)
            {
                entrance.Enter();
                return;
            }

            // Random encounter zone (tall grass)
            EncounterZone encounterZone = trigger.GetComponent<EncounterZone>();
            if (encounterZone != null)
            {
                encounterZone.CheckEncounter();
            }
        }
    }

    private void UpdateAnimation(Vector2 direction, bool moving)
    {
        if (animator == null) return;

        animator.SetFloat(AnimMoveX, direction.x);
        animator.SetFloat(AnimMoveY, direction.y);
        animator.SetBool(AnimIsMoving, moving);
    }

    private void OpenPauseMenu()
    {
        if (GameManager.Instance != null)
        {
            GameManager.Instance.SetGameState(GameState.Paused);
        }

        PauseMenuUI pauseMenu = FindObjectOfType<PauseMenuUI>();
        if (pauseMenu != null)
        {
            pauseMenu.Toggle();
        }
    }

    public void SetCanMove(bool value)
    {
        canMove = value;
        if (!value)
        {
            isMoving = false;
            UpdateAnimation(facingDirection, false);
        }
    }

    public void TeleportTo(Vector3 position)
    {
        transform.position = position;
        targetPosition = position;
        isMoving = false;
    }
}

/// <summary>
/// Interface for interactable objects in the world.
/// </summary>
public interface IInteractable
{
    void Interact(PlayerController player);
}
