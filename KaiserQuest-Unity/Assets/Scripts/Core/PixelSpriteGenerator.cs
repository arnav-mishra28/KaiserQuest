using UnityEngine;
using System.Collections.Generic;

/// <summary>
/// PixelSpriteGenerator — Generates pixel art sprites programmatically at runtime.
/// Creates player, NPC, building, and tile sprites in a Pokemon Gen1/Gen2 style.
/// This serves as a fallback when external sprite assets aren't available.
/// </summary>
public class PixelSpriteGenerator : MonoBehaviour
{
    public static PixelSpriteGenerator Instance { get; private set; }

    [Header("Sprite Settings")]
    public int pixelsPerUnit = 16;
    public FilterMode filterMode = FilterMode.Point;

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

    /// <summary>
    /// Generate player character sprite (16x24 pixels, 4 directions).
    /// </summary>
    public Sprite GeneratePlayerSprite(PlayerDirection direction = PlayerDirection.Down)
    {
        Texture2D tex = new Texture2D(16, 24, TextureFormat.RGBA32, false);
        tex.filterMode = filterMode;

        // Clear
        Color clear = Color.clear;
        Color skin = new Color(0.96f, 0.82f, 0.68f); // skin tone
        Color hair = new Color(0.2f, 0.15f, 0.1f); // dark brown hair
        Color shirt = new Color(0.85f, 0.2f, 0.2f); // red shirt (like Red from Pokemon)
        Color pants = new Color(0.2f, 0.3f, 0.6f); // blue pants
        Color shoes = new Color(0.3f, 0.25f, 0.2f); // brown shoes
        Color hat = new Color(0.85f, 0.2f, 0.2f); // red hat
        Color hatBrim = Color.white;
        Color eyes = new Color(0.1f, 0.1f, 0.15f);
        Color outline = new Color(0.15f, 0.12f, 0.1f);

        FillTexture(tex, clear);

        // Draw based on direction
        switch (direction)
        {
            case PlayerDirection.Down:
                DrawPlayerFront(tex, skin, hair, shirt, pants, shoes, hat, hatBrim, eyes, outline);
                break;
            case PlayerDirection.Up:
                DrawPlayerBack(tex, skin, hair, shirt, pants, shoes, hat, outline);
                break;
            case PlayerDirection.Left:
                DrawPlayerSide(tex, skin, hair, shirt, pants, shoes, hat, eyes, outline, false);
                break;
            case PlayerDirection.Right:
                DrawPlayerSide(tex, skin, hair, shirt, pants, shoes, hat, eyes, outline, true);
                break;
        }

        tex.Apply();
        return Sprite.Create(tex, new Rect(0, 0, 16, 24), new Vector2(0.5f, 0.25f), pixelsPerUnit);
    }

    private void DrawPlayerFront(Texture2D tex, Color skin, Color hair, Color shirt, Color pants, Color shoes, Color hat, Color hatBrim, Color eyes, Color outline)
    {
        // Shoes (rows 0-3)
        DrawRect(tex, 4, 0, 4, 3, shoes);
        DrawRect(tex, 9, 0, 4, 3, shoes);

        // Pants (rows 3-9)
        DrawRect(tex, 4, 3, 9, 6, pants);
        tex.SetPixel(8, 3, outline); tex.SetPixel(8, 4, outline); tex.SetPixel(8, 5, outline);

        // Shirt (rows 9-15)
        DrawRect(tex, 3, 9, 11, 6, shirt);
        // Arms
        DrawRect(tex, 1, 9, 2, 5, shirt);
        DrawRect(tex, 14, 9, 2, 5, shirt);
        // Hands
        DrawRect(tex, 1, 9, 2, 1, skin);
        DrawRect(tex, 14, 9, 2, 1, skin);

        // Neck
        DrawRect(tex, 6, 15, 4, 1, skin);

        // Head (rows 16-22)
        DrawRect(tex, 4, 16, 8, 6, skin);
        // Eyes
        tex.SetPixel(5, 18, eyes);
        tex.SetPixel(6, 18, eyes);
        tex.SetPixel(9, 18, eyes);
        tex.SetPixel(10, 18, eyes);
        // Mouth
        tex.SetPixel(7, 17, new Color(0.8f, 0.4f, 0.4f));
        tex.SetPixel(8, 17, new Color(0.8f, 0.4f, 0.4f));

        // Hair
        DrawRect(tex, 3, 20, 10, 3, hair);
        DrawRect(tex, 3, 19, 2, 2, hair);
        DrawRect(tex, 11, 19, 2, 2, hair);

        // Hat
        DrawRect(tex, 3, 22, 10, 2, hat);
        DrawRect(tex, 2, 22, 1, 1, hatBrim);
        DrawRect(tex, 13, 22, 1, 1, hatBrim);
    }

    private void DrawPlayerBack(Texture2D tex, Color skin, Color hair, Color shirt, Color pants, Color shoes, Color hat, Color outline)
    {
        // Same structure but back view (no face details)
        DrawRect(tex, 4, 0, 4, 3, shoes);
        DrawRect(tex, 9, 0, 4, 3, shoes);
        DrawRect(tex, 4, 3, 9, 6, pants);
        DrawRect(tex, 3, 9, 11, 6, shirt);
        DrawRect(tex, 1, 9, 2, 5, shirt);
        DrawRect(tex, 14, 9, 2, 5, shirt);
        DrawRect(tex, 6, 15, 4, 1, skin);
        DrawRect(tex, 4, 16, 8, 7, hair);
        DrawRect(tex, 3, 22, 10, 2, hat);
    }

    private void DrawPlayerSide(Texture2D tex, Color skin, Color hair, Color shirt, Color pants, Color shoes, Color hat, Color eyes, Color outline, bool flipX)
    {
        int offset = flipX ? 1 : 0;

        DrawRect(tex, 5 + offset, 0, 4, 3, shoes);
        DrawRect(tex, 5 + offset, 3, 6, 6, pants);
        DrawRect(tex, 4 + offset, 9, 8, 6, shirt);
        DrawRect(tex, flipX ? 12 : 2, 10, 2, 4, shirt);
        DrawRect(tex, flipX ? 12 : 2, 10, 2, 1, skin);
        DrawRect(tex, 6 + offset, 15, 4, 1, skin);
        DrawRect(tex, 5 + offset, 16, 7, 6, skin);
        DrawRect(tex, 5 + offset, 20, 7, 3, hair);
        tex.SetPixel(flipX ? 6 : 9, 18, eyes);
        DrawRect(tex, 4 + offset, 22, 9, 2, hat);
    }

    /// <summary>
    /// Generate NPC sprite with customizable colors.
    /// </summary>
    public Sprite GenerateNPCSprite(Color shirtColor, Color hairColor, bool isFemale = false)
    {
        Texture2D tex = new Texture2D(16, 24, TextureFormat.RGBA32, false);
        tex.filterMode = filterMode;

        Color clear = Color.clear;
        Color skin = new Color(0.93f, 0.78f, 0.65f);
        Color eyes = new Color(0.1f, 0.1f, 0.15f);
        Color outline = new Color(0.15f, 0.12f, 0.1f);
        Color pants = new Color(0.3f, 0.3f, 0.35f);
        Color shoes = new Color(0.25f, 0.2f, 0.15f);

        FillTexture(tex, clear);

        // Similar to player but different proportions for variety
        DrawRect(tex, 4, 0, 4, 3, shoes);
        DrawRect(tex, 9, 0, 4, 3, shoes);

        if (isFemale)
        {
            // Skirt instead of pants
            DrawRect(tex, 3, 3, 11, 6, shirtColor);
        }
        else
        {
            DrawRect(tex, 4, 3, 9, 6, pants);
        }

        DrawRect(tex, 3, 9, 11, 6, shirtColor);
        DrawRect(tex, 1, 10, 2, 4, shirtColor);
        DrawRect(tex, 14, 10, 2, 4, shirtColor);
        DrawRect(tex, 1, 10, 2, 1, skin);
        DrawRect(tex, 14, 10, 2, 1, skin);
        DrawRect(tex, 6, 15, 4, 1, skin);
        DrawRect(tex, 4, 16, 8, 6, skin);
        tex.SetPixel(5, 18, eyes); tex.SetPixel(6, 18, eyes);
        tex.SetPixel(9, 18, eyes); tex.SetPixel(10, 18, eyes);
        DrawRect(tex, 3, 20, 10, 4, hairColor);
        DrawRect(tex, 3, 19, 2, 2, hairColor);
        DrawRect(tex, 11, 19, 2, 2, hairColor);

        if (isFemale)
        {
            // Longer hair
            DrawRect(tex, 2, 16, 2, 5, hairColor);
            DrawRect(tex, 12, 16, 2, 5, hairColor);
        }

        tex.Apply();
        return Sprite.Create(tex, new Rect(0, 0, 16, 24), new Vector2(0.5f, 0.25f), pixelsPerUnit);
    }

    /// <summary>
    /// Generate a Gym Leader sprite (more elaborate).
    /// </summary>
    public Sprite GenerateGymLeaderSprite(Color primaryColor, Color secondaryColor)
    {
        Texture2D tex = new Texture2D(16, 24, TextureFormat.RGBA32, false);
        tex.filterMode = filterMode;

        Color skin = new Color(0.9f, 0.75f, 0.6f);
        Color eyes = new Color(0.1f, 0.1f, 0.15f);
        Color cape = secondaryColor;

        FillTexture(tex, Color.clear);

        // Shoes
        DrawRect(tex, 4, 0, 4, 3, Color.black);
        DrawRect(tex, 9, 0, 4, 3, Color.black);
        // Pants
        DrawRect(tex, 4, 3, 9, 6, new Color(0.15f, 0.15f, 0.2f));
        // Shirt/armor
        DrawRect(tex, 3, 9, 11, 6, primaryColor);
        // Cape
        DrawRect(tex, 1, 9, 2, 7, cape);
        DrawRect(tex, 14, 9, 2, 7, cape);
        // Belt
        DrawRect(tex, 3, 9, 11, 1, secondaryColor);
        // Head
        DrawRect(tex, 6, 15, 4, 1, skin);
        DrawRect(tex, 4, 16, 8, 6, skin);
        tex.SetPixel(5, 18, eyes); tex.SetPixel(6, 18, eyes);
        tex.SetPixel(9, 18, eyes); tex.SetPixel(10, 18, eyes);
        // Dramatic hair
        DrawRect(tex, 3, 20, 10, 4, secondaryColor);
        DrawRect(tex, 2, 21, 1, 3, secondaryColor);
        DrawRect(tex, 13, 21, 1, 3, secondaryColor);

        tex.Apply();
        return Sprite.Create(tex, new Rect(0, 0, 16, 24), new Vector2(0.5f, 0.25f), pixelsPerUnit);
    }

    /// <summary>
    /// Generate a grass tile.
    /// </summary>
    public Sprite GenerateGrassTile()
    {
        Texture2D tex = new Texture2D(16, 16, TextureFormat.RGBA32, false);
        tex.filterMode = filterMode;

        Color grassBase = new Color(0.35f, 0.7f, 0.28f);
        Color grassLight = new Color(0.42f, 0.78f, 0.35f);
        Color grassDark = new Color(0.28f, 0.58f, 0.22f);

        FillTexture(tex, grassBase);

        // Random grass details
        System.Random rng = new System.Random(42);
        for (int x = 0; x < 16; x++)
        {
            for (int y = 0; y < 16; y++)
            {
                float noise = rng.Next(100) / 100f;
                if (noise > 0.8f)
                    tex.SetPixel(x, y, grassLight);
                else if (noise < 0.15f)
                    tex.SetPixel(x, y, grassDark);
            }
        }

        // Grass tufts
        tex.SetPixel(3, 14, grassDark); tex.SetPixel(4, 15, grassDark);
        tex.SetPixel(10, 6, grassDark); tex.SetPixel(11, 7, grassDark);
        tex.SetPixel(7, 10, grassDark); tex.SetPixel(8, 11, grassDark);

        tex.Apply();
        return Sprite.Create(tex, new Rect(0, 0, 16, 16), new Vector2(0.5f, 0.5f), pixelsPerUnit);
    }

    /// <summary>
    /// Generate a path tile.
    /// </summary>
    public Sprite GeneratePathTile()
    {
        Texture2D tex = new Texture2D(16, 16, TextureFormat.RGBA32, false);
        tex.filterMode = filterMode;

        Color pathBase = new Color(0.82f, 0.72f, 0.55f);
        Color pathLight = new Color(0.88f, 0.78f, 0.6f);
        Color pathDark = new Color(0.72f, 0.62f, 0.48f);

        FillTexture(tex, pathBase);

        System.Random rng = new System.Random(123);
        for (int x = 0; x < 16; x++)
        {
            for (int y = 0; y < 16; y++)
            {
                float noise = rng.Next(100) / 100f;
                if (noise > 0.85f) tex.SetPixel(x, y, pathLight);
                else if (noise < 0.1f) tex.SetPixel(x, y, pathDark);
            }
        }

        tex.Apply();
        return Sprite.Create(tex, new Rect(0, 0, 16, 16), new Vector2(0.5f, 0.5f), pixelsPerUnit);
    }

    /// <summary>
    /// Generate a water tile.
    /// </summary>
    public Sprite GenerateWaterTile()
    {
        Texture2D tex = new Texture2D(16, 16, TextureFormat.RGBA32, false);
        tex.filterMode = filterMode;

        Color waterBase = new Color(0.25f, 0.5f, 0.85f);
        Color waterLight = new Color(0.35f, 0.6f, 0.92f);
        Color waterDark = new Color(0.18f, 0.4f, 0.72f);

        FillTexture(tex, waterBase);

        // Water wave pattern
        for (int x = 0; x < 16; x++)
        {
            int waveY = 8 + (int)(Mathf.Sin(x * 0.8f) * 2);
            if (waveY >= 0 && waveY < 16)
                tex.SetPixel(x, waveY, waterLight);
            int wave2Y = 4 + (int)(Mathf.Cos(x * 0.6f) * 1.5f);
            if (wave2Y >= 0 && wave2Y < 16)
                tex.SetPixel(x, wave2Y, waterLight);
        }

        tex.Apply();
        return Sprite.Create(tex, new Rect(0, 0, 16, 16), new Vector2(0.5f, 0.5f), pixelsPerUnit);
    }

    /// <summary>
    /// Generate a tree sprite (for decoration).
    /// </summary>
    public Sprite GenerateTreeSprite()
    {
        Texture2D tex = new Texture2D(16, 24, TextureFormat.RGBA32, false);
        tex.filterMode = filterMode;

        Color trunk = new Color(0.45f, 0.3f, 0.18f);
        Color leaves = new Color(0.2f, 0.55f, 0.2f);
        Color leavesLight = new Color(0.3f, 0.65f, 0.25f);
        Color leavesDark = new Color(0.15f, 0.42f, 0.15f);

        FillTexture(tex, Color.clear);

        // Trunk
        DrawRect(tex, 6, 0, 4, 10, trunk);
        DrawRect(tex, 7, 0, 2, 10, new Color(0.5f, 0.35f, 0.2f));

        // Canopy (rounded)
        DrawRect(tex, 3, 10, 10, 10, leaves);
        DrawRect(tex, 2, 12, 12, 8, leaves);
        DrawRect(tex, 1, 14, 14, 4, leaves);

        // Highlights
        DrawRect(tex, 4, 18, 3, 3, leavesLight);
        DrawRect(tex, 8, 15, 4, 3, leavesLight);

        // Shadows
        DrawRect(tex, 3, 11, 4, 3, leavesDark);
        DrawRect(tex, 9, 13, 3, 2, leavesDark);

        tex.Apply();
        return Sprite.Create(tex, new Rect(0, 0, 16, 24), new Vector2(0.5f, 0.25f), pixelsPerUnit);
    }

    /// <summary>
    /// Generate a building sprite (for gym, house, etc).
    /// </summary>
    public Sprite GenerateBuildingSprite(Color wallColor, Color roofColor, bool isGym = false)
    {
        Texture2D tex = new Texture2D(32, 32, TextureFormat.RGBA32, false);
        tex.filterMode = filterMode;

        Color door = new Color(0.45f, 0.3f, 0.18f);
        Color window = new Color(0.6f, 0.8f, 0.95f);
        Color windowFrame = new Color(0.85f, 0.85f, 0.85f);

        FillTexture(tex, Color.clear);

        // Building base
        DrawRect(tex, 2, 0, 28, 18, wallColor);

        // Roof
        for (int y = 0; y < 10; y++)
        {
            int inset = y;
            DrawRect(tex, inset, 18 + y, 32 - inset * 2, 1, roofColor);
        }

        // Door
        DrawRect(tex, 13, 0, 6, 8, door);
        DrawRect(tex, 14, 0, 4, 7, new Color(0.5f, 0.35f, 0.2f));
        tex.SetPixel(17, 4, Color.yellow); // doorknob

        // Windows
        DrawRect(tex, 4, 8, 6, 5, windowFrame);
        DrawRect(tex, 5, 9, 4, 3, window);
        DrawRect(tex, 22, 8, 6, 5, windowFrame);
        DrawRect(tex, 23, 9, 4, 3, window);

        if (isGym)
        {
            // Gym badge symbol on front
            Color gymSymbol = new Color(1f, 0.85f, 0.2f); // gold
            DrawRect(tex, 14, 10, 4, 4, gymSymbol);
            tex.SetPixel(15, 12, Color.white);
            tex.SetPixel(16, 12, Color.white);

            // Gym pillars
            DrawRect(tex, 3, 0, 3, 18, new Color(0.75f, 0.75f, 0.8f));
            DrawRect(tex, 26, 0, 3, 18, new Color(0.75f, 0.75f, 0.8f));
        }

        tex.Apply();
        return Sprite.Create(tex, new Rect(0, 0, 32, 32), new Vector2(0.5f, 0.25f), pixelsPerUnit);
    }

    // ============================================================
    // UTILITY
    // ============================================================

    private void FillTexture(Texture2D tex, Color color)
    {
        Color[] pixels = new Color[tex.width * tex.height];
        for (int i = 0; i < pixels.Length; i++)
            pixels[i] = color;
        tex.SetPixels(pixels);
    }

    private void DrawRect(Texture2D tex, int x, int y, int width, int height, Color color)
    {
        for (int px = x; px < x + width && px < tex.width; px++)
        {
            for (int py = y; py < y + height && py < tex.height; py++)
            {
                if (px >= 0 && py >= 0)
                    tex.SetPixel(px, py, color);
            }
        }
    }
}

public enum PlayerDirection
{
    Down,
    Up,
    Left,
    Right
}
