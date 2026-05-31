using UnityEngine;

/// <summary>
/// CameraFollow — Smooth camera that follows the player.
/// The world stays static while the camera moves with the player.
/// Includes bounds clamping and pixel-perfect snapping.
/// </summary>
public class CameraFollow : MonoBehaviour
{
    [Header("Target")]
    public Transform target;

    [Header("Follow Settings")]
    public float smoothSpeed = 8f;
    public Vector3 offset = new Vector3(0, 0, -10);

    [Header("Bounds")]
    public bool useBounds = true;
    public float minX = -50f;
    public float maxX = 50f;
    public float minY = -50f;
    public float maxY = 50f;

    [Header("Pixel Perfect")]
    public bool pixelPerfect = true;
    public float pixelsPerUnit = 16f;

    private Camera cam;

    private void Start()
    {
        cam = GetComponent<Camera>();

        if (target == null)
        {
            // Try to find the player
            PlayerController player = FindObjectOfType<PlayerController>();
            if (player != null)
                target = player.transform;
        }

        // Set camera for pixel art
        if (cam != null)
        {
            cam.orthographic = true;
            cam.orthographicSize = 5f; // Adjust for desired zoom
        }
    }

    private void LateUpdate()
    {
        if (target == null) return;

        Vector3 desiredPosition = target.position + offset;

        // Smooth follow
        Vector3 smoothedPosition = Vector3.Lerp(transform.position, desiredPosition, smoothSpeed * Time.deltaTime);

        // Clamp to bounds
        if (useBounds)
        {
            float camHalfHeight = cam.orthographicSize;
            float camHalfWidth = camHalfHeight * cam.aspect;

            smoothedPosition.x = Mathf.Clamp(smoothedPosition.x, minX + camHalfWidth, maxX - camHalfWidth);
            smoothedPosition.y = Mathf.Clamp(smoothedPosition.y, minY + camHalfHeight, maxY - camHalfHeight);
        }

        // Pixel-perfect snapping
        if (pixelPerfect)
        {
            smoothedPosition.x = Mathf.Round(smoothedPosition.x * pixelsPerUnit) / pixelsPerUnit;
            smoothedPosition.y = Mathf.Round(smoothedPosition.y * pixelsPerUnit) / pixelsPerUnit;
        }

        smoothedPosition.z = offset.z;
        transform.position = smoothedPosition;
    }

    public void SetTarget(Transform newTarget)
    {
        target = newTarget;
    }

    public void SetBounds(float newMinX, float newMaxX, float newMinY, float newMaxY)
    {
        minX = newMinX;
        maxX = newMaxX;
        minY = newMinY;
        maxY = newMaxY;
    }

    /// <summary>
    /// Instantly snap camera to target (no smoothing) — used for scene transitions.
    /// </summary>
    public void SnapToTarget()
    {
        if (target == null) return;
        Vector3 pos = target.position + offset;
        if (useBounds)
        {
            float camHalfHeight = cam.orthographicSize;
            float camHalfWidth = camHalfHeight * cam.aspect;
            pos.x = Mathf.Clamp(pos.x, minX + camHalfWidth, maxX - camHalfWidth);
            pos.y = Mathf.Clamp(pos.y, minY + camHalfHeight, maxY - camHalfHeight);
        }
        pos.z = offset.z;
        transform.position = pos;
    }
}
