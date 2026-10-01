using UnityEngine;
using System.IO;
using System.Collections.Generic;
#if UNITY_EDITOR
using UnityEditor;
#endif

/// <summary>
/// TilesetGenerator — Creates pixel art tileset PNG files in the Kenney.nl style.
/// Run from menu: KaiserQuest > Generate Tilesets
/// Generates complete tilesets for grass, path, water, buildings, trees, gym buildings.
/// All assets are 16x16 or 32x32 at 16 PPU with Point filtering for crisp pixel art.
/// </summary>
public class TilesetGenerator : MonoBehaviour
{
    public static string SpritePath = "Assets/Sprites";
    public static string TilesetPath = "Assets/Sprites/Tilesets";
    public static string CharacterPath = "Assets/Sprites/Characters";
    public static string UIPath = "Assets/Sprites/UI";
    public static string BattlePath = "Assets/Sprites/Battle";

    // ================================================================
    // KENNEY-STYLE COLOR PALETTES
    // ================================================================

    // Grass palette (rich greens like Pokemon Gen2)
    static readonly Color grassDark =  new Color32(56, 118, 29, 255);
    static readonly Color grassMid =   new Color32(80, 148, 40, 255);
    static readonly Color grassLight = new Color32(108, 172, 56, 255);
    static readonly Color grassPale =  new Color32(140, 196, 88, 255);

    // Path/dirt palette
    static readonly Color pathDark =   new Color32(152, 120, 72, 255);
    static readonly Color pathMid =    new Color32(184, 152, 96, 255);
    static readonly Color pathLight =  new Color32(208, 176, 128, 255);
    static readonly Color pathPale =   new Color32(224, 200, 160, 255);

    // Water palette (deep blue like Pokemon)
    static readonly Color waterDeep =  new Color32(32, 72, 152, 255);
    static readonly Color waterMid =   new Color32(48, 104, 192, 255);
    static readonly Color waterLight = new Color32(80, 144, 216, 255);
    static readonly Color waterFoam =  new Color32(160, 208, 240, 255);

    // Building palette
    static readonly Color wallLight =  new Color32(224, 216, 200, 255);
    static readonly Color wallMid =    new Color32(192, 184, 168, 255);
    static readonly Color wallDark =   new Color32(152, 144, 128, 255);
    static readonly Color roofRed =    new Color32(176, 48, 48, 255);
    static readonly Color roofBlue =   new Color32(48, 80, 176, 255);
    static readonly Color roofGreen =  new Color32(48, 128, 64, 255);
    static readonly Color woodDark =   new Color32(96, 64, 32, 255);
    static readonly Color woodLight =  new Color32(144, 104, 56, 255);

    // Character skin tones
    static readonly Color skinLight =  new Color32(248, 216, 176, 255);
    static readonly Color skinMid =    new Color32(232, 192, 144, 255);

    // UI colors
    static readonly Color uiBg =       new Color32(24, 32, 56, 240);
    static readonly Color uiBorder =   new Color32(200, 200, 216, 255);
    static readonly Color uiText =     new Color32(248, 248, 248, 255);

#if UNITY_EDITOR
    [MenuItem("KaiserQuest/Generate All Assets")]
    public static void GenerateAll()
    {
        EnsureDirectories();
        GenerateAllTilesets();
        GenerateAllCharacters();
        GenerateUISprites();
        GenerateBattleAssets();
        AssetDatabase.Refresh();
        Debug.Log("[TilesetGenerator] All assets generated!");
    }

    [MenuItem("KaiserQuest/Generate Tilesets Only")]
    public static void GenerateAllTilesets()
    {
        EnsureDirectories();
        GenerateGrassTileset();
        GeneratePathTileset();
        GenerateWaterTileset();
        GenerateTreeSprites();
        GenerateFlowerSprites();
        GenerateRockSprites();
        GenerateFenceTileset();
        GenerateBuildingSprites();
        GenerateGymBuildingSprites();
        AssetDatabase.Refresh();
        Debug.Log("[TilesetGenerator] Tilesets generated!");
    }

    [MenuItem("KaiserQuest/Generate Characters")]
    public static void GenerateAllCharacters()
    {
        EnsureDirectories();
        GeneratePlayerSpriteSheet();
        GenerateNPCSpriteSheets();
        GenerateGymLeaderSprites();
        AssetDatabase.Refresh();
        Debug.Log("[TilesetGenerator] Characters generated!");
    }
#endif

    static void EnsureDirectories()
    {
        string[] dirs = { SpritePath, TilesetPath, CharacterPath, UIPath, BattlePath,
            TilesetPath + "/Grass", TilesetPath + "/Path", TilesetPath + "/Water",
            TilesetPath + "/Trees", TilesetPath + "/Buildings", TilesetPath + "/Decorations",
            CharacterPath + "/Player", CharacterPath + "/NPCs", CharacterPath + "/GymLeaders",
            BattlePath + "/Backgrounds", BattlePath + "/Effects" };

        foreach (string dir in dirs)
        {
            string fullPath = Path.Combine(Application.dataPath.Replace("Assets", ""), dir);
            if (!Directory.Exists(fullPath))
                Directory.CreateDirectory(fullPath);
        }
    }

    // ================================================================
    // GRASS TILESET (9 variants — center, edges, corners)
    // ================================================================
    static void GenerateGrassTileset()
    {
        // Main grass tile
        Texture2D grass = CreateTex(16, 16);
        FillRect(grass, 0, 0, 16, 16, grassMid);
        // Add texture detail
        System.Random rng = new System.Random(42);
        for (int x = 0; x < 16; x++)
            for (int y = 0; y < 16; y++)
            {
                int r = rng.Next(100);
                if (r < 10) grass.SetPixel(x, y, grassDark);
                else if (r > 85) grass.SetPixel(x, y, grassLight);
            }
        // Grass tufts
        SetPixels(grass, new int[,]{{3,12},{4,13},{4,12},{10,5},{11,6},{11,5},{7,9},{8,10}}, grassDark);
        SetPixels(grass, new int[,]{{3,13},{10,6},{7,10}}, grassPale);
        SavePNG(grass, TilesetPath + "/Grass/grass_main.png");

        // Tall grass (encounter zone) — darker with visible blades
        Texture2D tallGrass = CreateTex(16, 16);
        FillRect(tallGrass, 0, 0, 16, 16, grassDark);
        for (int x = 1; x < 15; x += 3)
        {
            tallGrass.SetPixel(x, 12, grassPale); tallGrass.SetPixel(x, 13, grassLight);
            tallGrass.SetPixel(x, 14, grassMid); tallGrass.SetPixel(x, 15, grassDark);
            tallGrass.SetPixel(x+1, 11, grassPale); tallGrass.SetPixel(x+1, 12, grassLight);
            tallGrass.SetPixel(x+1, 13, grassMid);
        }
        SavePNG(tallGrass, TilesetPath + "/Grass/grass_tall.png");

        // Grass-path edge (top)
        Texture2D grassEdgeTop = CreateTex(16, 16);
        FillRect(grassEdgeTop, 0, 0, 16, 12, pathMid);
        FillRect(grassEdgeTop, 0, 12, 16, 4, grassMid);
        FillRect(grassEdgeTop, 0, 11, 16, 2, grassDark);
        SavePNG(grassEdgeTop, TilesetPath + "/Grass/grass_edge_top.png");

        Debug.Log("[Tileset] Grass tiles generated.");
    }

    // ================================================================
    // PATH TILESET
    // ================================================================
    static void GeneratePathTileset()
    {
        // Main path
        Texture2D path = CreateTex(16, 16);
        FillRect(path, 0, 0, 16, 16, pathMid);
        System.Random rng = new System.Random(99);
        for (int x = 0; x < 16; x++)
            for (int y = 0; y < 16; y++)
            {
                int r = rng.Next(100);
                if (r < 8) path.SetPixel(x, y, pathDark);
                else if (r > 90) path.SetPixel(x, y, pathLight);
            }
        SavePNG(path, TilesetPath + "/Path/path_main.png");

        // Path with stone detail
        Texture2D pathStone = CreateTex(16, 16);
        FillRect(pathStone, 0, 0, 16, 16, pathMid);
        FillRect(pathStone, 3, 3, 4, 3, pathDark);
        FillRect(pathStone, 9, 8, 5, 4, pathDark);
        FillRect(pathStone, 4, 4, 2, 1, pathLight);
        FillRect(pathStone, 10, 9, 3, 2, pathLight);
        SavePNG(pathStone, TilesetPath + "/Path/path_stone.png");

        Debug.Log("[Tileset] Path tiles generated.");
    }

    // ================================================================
    // WATER TILESET
    // ================================================================
    static void GenerateWaterTileset()
    {
        // Water frame 1
        Texture2D water1 = CreateTex(16, 16);
        FillRect(water1, 0, 0, 16, 16, waterMid);
        for (int x = 0; x < 16; x++)
        {
            int wy = 4 + (int)(Mathf.Sin(x * 0.5f) * 2);
            if (wy >= 0 && wy < 16) water1.SetPixel(x, wy, waterLight);
            int wy2 = 10 + (int)(Mathf.Cos(x * 0.7f) * 1.5f);
            if (wy2 >= 0 && wy2 < 16) water1.SetPixel(x, wy2, waterLight);
        }
        // Sparkle
        water1.SetPixel(5, 7, waterFoam);
        water1.SetPixel(11, 3, waterFoam);
        SavePNG(water1, TilesetPath + "/Water/water_1.png");

        // Water frame 2 (for animation)
        Texture2D water2 = CreateTex(16, 16);
        FillRect(water2, 0, 0, 16, 16, waterMid);
        for (int x = 0; x < 16; x++)
        {
            int wy = 5 + (int)(Mathf.Sin(x * 0.5f + 1.5f) * 2);
            if (wy >= 0 && wy < 16) water2.SetPixel(x, wy, waterLight);
            int wy2 = 11 + (int)(Mathf.Cos(x * 0.7f + 1f) * 1.5f);
            if (wy2 >= 0 && wy2 < 16) water2.SetPixel(x, wy2, waterLight);
        }
        water2.SetPixel(8, 6, waterFoam);
        water2.SetPixel(3, 12, waterFoam);
        SavePNG(water2, TilesetPath + "/Water/water_2.png");

        // Shore tile (water-grass edge)
        Texture2D shore = CreateTex(16, 16);
        FillRect(shore, 0, 0, 16, 8, waterMid);
        FillRect(shore, 0, 8, 16, 8, grassMid);
        FillRect(shore, 0, 7, 16, 3, waterFoam);
        FillRect(shore, 2, 8, 3, 1, new Color32(200, 180, 140, 255)); // sand
        FillRect(shore, 9, 8, 4, 1, new Color32(200, 180, 140, 255));
        SavePNG(shore, TilesetPath + "/Water/shore.png");

        Debug.Log("[Tileset] Water tiles generated.");
    }

    // ================================================================
    // TREE SPRITES
    // ================================================================
    static void GenerateTreeSprites()
    {
        // Pine tree (32x32)
        Texture2D pine = CreateTex(32, 32);
        // Trunk
        FillRect(pine, 13, 0, 6, 12, woodDark);
        FillRect(pine, 14, 0, 4, 12, woodLight);
        // Canopy layers
        Color treeDark = new Color32(24, 88, 32, 255);
        Color treeMid = new Color32(40, 120, 48, 255);
        Color treeLight = new Color32(64, 152, 56, 255);
        // Bottom layer
        FillRect(pine, 4, 10, 24, 6, treeMid);
        FillRect(pine, 6, 10, 20, 5, treeDark);
        FillRect(pine, 8, 11, 6, 3, treeLight);
        // Middle layer
        FillRect(pine, 6, 16, 20, 6, treeMid);
        FillRect(pine, 8, 16, 16, 5, treeDark);
        FillRect(pine, 10, 17, 5, 3, treeLight);
        // Top layer
        FillRect(pine, 8, 22, 16, 5, treeMid);
        FillRect(pine, 10, 22, 12, 4, treeDark);
        FillRect(pine, 12, 23, 4, 2, treeLight);
        // Peak
        FillRect(pine, 12, 27, 8, 4, treeMid);
        FillRect(pine, 14, 29, 4, 3, treeDark);
        SavePNG(pine, TilesetPath + "/Trees/tree_pine.png");

        // Oak tree (32x32) — round canopy
        Texture2D oak = CreateTex(32, 32);
        FillRect(oak, 13, 0, 6, 10, woodDark);
        FillRect(oak, 14, 0, 4, 10, woodLight);
        // Round canopy
        FillRect(oak, 4, 10, 24, 16, treeMid);
        FillRect(oak, 2, 14, 28, 10, treeMid);
        FillRect(oak, 6, 12, 20, 14, treeDark);
        FillRect(oak, 8, 18, 8, 6, treeLight);
        FillRect(oak, 18, 14, 6, 5, treeLight);
        // Top curve
        FillRect(oak, 6, 26, 20, 4, treeMid);
        FillRect(oak, 10, 28, 12, 3, treeDark);
        SavePNG(oak, TilesetPath + "/Trees/tree_oak.png");

        Debug.Log("[Tileset] Tree sprites generated.");
    }

    // ================================================================
    // FLOWERS AND DECORATIONS
    // ================================================================
    static void GenerateFlowerSprites()
    {
        Color[] flowerColors = {
            new Color32(232, 64, 64, 255),   // Red
            new Color32(64, 96, 232, 255),   // Blue
            new Color32(232, 200, 48, 255),  // Yellow
            new Color32(200, 64, 200, 255),  // Pink
        };
        string[] names = { "red", "blue", "yellow", "pink" };

        for (int i = 0; i < flowerColors.Length; i++)
        {
            Texture2D flower = CreateTex(16, 16);
            // Stem
            flower.SetPixel(7, 2, grassDark); flower.SetPixel(7, 3, grassDark);
            flower.SetPixel(7, 4, grassMid); flower.SetPixel(8, 3, grassDark);
            // Petals
            flower.SetPixel(6, 5, flowerColors[i]); flower.SetPixel(7, 6, flowerColors[i]);
            flower.SetPixel(8, 5, flowerColors[i]); flower.SetPixel(7, 4, flowerColors[i]);
            flower.SetPixel(7, 5, new Color32(255, 220, 64, 255)); // center
            // Leaves
            flower.SetPixel(5, 2, grassMid); flower.SetPixel(9, 3, grassMid);
            SavePNG(flower, TilesetPath + "/Decorations/flower_" + names[i] + ".png");
        }
        Debug.Log("[Tileset] Flower sprites generated.");
    }

    static void GenerateRockSprites()
    {
        Texture2D rock = CreateTex(16, 16);
        Color rockDark = new Color32(120, 112, 104, 255);
        Color rockMid = new Color32(152, 144, 136, 255);
        Color rockLight = new Color32(184, 176, 168, 255);
        FillRect(rock, 3, 1, 10, 8, rockMid);
        FillRect(rock, 2, 3, 12, 5, rockDark);
        FillRect(rock, 4, 5, 4, 3, rockLight);
        FillRect(rock, 9, 4, 3, 2, rockLight);
        SavePNG(rock, TilesetPath + "/Decorations/rock.png");

        // Sign post
        Texture2D sign = CreateTex(16, 16);
        FillRect(sign, 7, 0, 2, 6, woodDark);
        FillRect(sign, 3, 6, 10, 7, woodLight);
        FillRect(sign, 4, 7, 8, 5, woodDark);
        FillRect(sign, 5, 8, 6, 3, new Color32(240, 232, 200, 255)); // sign face
        SavePNG(sign, TilesetPath + "/Decorations/signpost.png");

        Debug.Log("[Tileset] Rock & sign sprites generated.");
    }

    static void GenerateFenceTileset()
    {
        Texture2D fence = CreateTex(16, 16);
        FillRect(fence, 0, 4, 16, 2, woodDark);
        FillRect(fence, 0, 8, 16, 2, woodDark);
        FillRect(fence, 1, 0, 3, 12, woodLight);
        FillRect(fence, 12, 0, 3, 12, woodLight);
        FillRect(fence, 2, 11, 1, 2, woodDark); // post top
        FillRect(fence, 13, 11, 1, 2, woodDark);
        SavePNG(fence, TilesetPath + "/Decorations/fence.png");
        Debug.Log("[Tileset] Fence generated.");
    }

    // ================================================================
    // BUILDINGS
    // ================================================================
    static void GenerateBuildingSprites()
    {
        // House (32x32)
        Texture2D house = CreateTex(32, 32);
        // Walls
        FillRect(house, 2, 0, 28, 18, wallLight);
        FillRect(house, 2, 0, 28, 1, wallDark); // base shadow
        // Roof
        for (int row = 0; row < 10; row++)
        {
            int inset = row;
            FillRect(house, 1 + inset, 18 + row, 30 - inset * 2, 1, roofRed);
        }
        FillRect(house, 2, 18, 28, 1, new Color32(128, 32, 32, 255)); // roof edge
        // Door
        FillRect(house, 12, 0, 8, 10, woodDark);
        FillRect(house, 13, 0, 6, 9, woodLight);
        house.SetPixel(17, 5, new Color32(255, 216, 64, 255)); // doorknob
        // Windows
        Color windowBlue = new Color32(120, 180, 232, 255);
        Color windowFrame = new Color32(200, 200, 208, 255);
        FillRect(house, 4, 8, 6, 6, windowFrame);
        FillRect(house, 5, 9, 4, 4, windowBlue);
        house.SetPixel(7, 9, wallDark); house.SetPixel(7, 10, wallDark); // pane divider
        FillRect(house, 22, 8, 6, 6, windowFrame);
        FillRect(house, 23, 9, 4, 4, windowBlue);
        house.SetPixel(25, 9, wallDark); house.SetPixel(25, 10, wallDark);
        SavePNG(house, TilesetPath + "/Buildings/house.png");

        // Pokemart-style shop
        Texture2D shop = CreateTex(32, 32);
        FillRect(shop, 2, 0, 28, 20, wallLight);
        FillRect(shop, 2, 20, 28, 12, roofBlue);
        FillRect(shop, 12, 0, 8, 12, woodDark);
        FillRect(shop, 13, 0, 6, 11, woodLight);
        // "SHOP" sign
        FillRect(shop, 8, 14, 16, 4, new Color32(248, 248, 200, 255));
        FillRect(shop, 4, 8, 6, 6, new Color32(200, 200, 208, 255));
        FillRect(shop, 5, 9, 4, 4, windowBlue);
        FillRect(shop, 22, 8, 6, 6, new Color32(200, 200, 208, 255));
        FillRect(shop, 23, 9, 4, 4, windowBlue);
        SavePNG(shop, TilesetPath + "/Buildings/shop.png");

        Debug.Log("[Tileset] Building sprites generated.");
    }

    // ================================================================
    // GYM BUILDINGS — Flashy and themed!
    // ================================================================
    static void GenerateGymBuildingSprites()
    {
        // Math Gym (blue/gold theme)
        GenerateGymBuilding("gym_math", new Color32(48, 80, 176, 255), new Color32(200, 168, 48, 255),
            new Color32(64, 96, 200, 255));

        // Language Gym (green/cream theme)
        GenerateGymBuilding("gym_language", new Color32(48, 128, 64, 255), new Color32(200, 192, 160, 255),
            new Color32(64, 152, 80, 255));

        // Music Gym (purple/gold theme)
        GenerateGymBuilding("gym_music", new Color32(128, 48, 160, 255), new Color32(200, 168, 48, 255),
            new Color32(152, 64, 192, 255));

        // Silver Mountain (dark/silver)
        GenerateGymBuilding("silver_mountain", new Color32(80, 80, 96, 255), new Color32(192, 192, 208, 255),
            new Color32(96, 96, 112, 255));

        Debug.Log("[Tileset] Gym buildings generated.");
    }

    static void GenerateGymBuilding(string name, Color32 primary, Color32 accent, Color32 secondary)
    {
        Texture2D gym = CreateTex(48, 48);

        // Grand pillars
        FillRect(gym, 2, 0, 6, 32, new Color32(192, 192, 200, 255));
        FillRect(gym, 3, 0, 4, 32, new Color32(208, 208, 216, 255));
        FillRect(gym, 40, 0, 6, 32, new Color32(192, 192, 200, 255));
        FillRect(gym, 41, 0, 4, 32, new Color32(208, 208, 216, 255));

        // Main wall
        FillRect(gym, 8, 0, 32, 30, primary);
        FillRect(gym, 8, 0, 32, 1, new Color32(40, 40, 48, 255)); // base

        // Grand roof
        FillRect(gym, 0, 30, 48, 4, secondary);
        FillRect(gym, 2, 34, 44, 3, primary);
        FillRect(gym, 4, 37, 40, 3, secondary);
        FillRect(gym, 8, 40, 32, 3, primary);
        FillRect(gym, 12, 43, 24, 3, secondary);
        FillRect(gym, 16, 46, 16, 2, accent);

        // Double doors
        FillRect(gym, 16, 0, 16, 16, woodDark);
        FillRect(gym, 17, 0, 6, 15, woodLight);
        FillRect(gym, 25, 0, 6, 15, woodLight);
        FillRect(gym, 24, 0, 1, 16, new Color32(40, 40, 48, 255)); // divider

        // Gym badge emblem
        FillRect(gym, 19, 20, 10, 8, accent);
        FillRect(gym, 20, 21, 8, 6, primary);
        FillRect(gym, 22, 23, 4, 2, Color.white);

        // "GYM" text area
        FillRect(gym, 14, 17, 20, 3, accent);

        // Windows
        Color32 glow = new Color32(240, 232, 160, 255);
        FillRect(gym, 10, 10, 5, 6, glow);
        FillRect(gym, 33, 10, 5, 6, glow);

        // Decorative border
        for (int x = 8; x < 40; x += 4)
        {
            gym.SetPixel(x, 29, accent);
            gym.SetPixel(x + 1, 29, accent);
        }

        SavePNG(gym, TilesetPath + "/Buildings/" + name + ".png");
    }

    // ================================================================
    // PLAYER SPRITE SHEET (16x24 per frame, 4 directions × 3 frames = 12 frames)
    // ================================================================
    static void GeneratePlayerSpriteSheet()
    {
        // Layout: 3 columns (idle, walk1, walk2) × 4 rows (down, left, right, up)
        int fw = 16, fh = 24;
        Texture2D sheet = CreateTex(fw * 3, fh * 4);

        Color hat = new Color32(216, 48, 48, 255);
        Color hatBrim = new Color32(248, 248, 248, 255);
        Color shirt = new Color32(200, 56, 56, 255);
        Color pants = new Color32(48, 72, 152, 255);
        Color shoes = new Color32(72, 56, 40, 255);
        Color hair = new Color32(48, 32, 24, 255);
        Color eyes = new Color32(24, 24, 32, 255);
        Color skin = skinLight;

        // Draw each frame
        for (int dir = 0; dir < 4; dir++)
        {
            for (int frame = 0; frame < 3; frame++)
            {
                int ox = frame * fw;
                int oy = dir * fh;
                DrawCharacterFrame(sheet, ox, oy, fw, fh, dir, frame,
                    skin, hair, shirt, pants, shoes, hat, hatBrim, eyes);
            }
        }

        SavePNG(sheet, CharacterPath + "/Player/player_spritesheet.png");
        Debug.Log("[Character] Player sprite sheet generated.");
    }

    static void DrawCharacterFrame(Texture2D tex, int ox, int oy, int fw, int fh,
        int direction, int frame, Color skin, Color hair, Color shirt, Color pants,
        Color shoes, Color hat, Color hatBrim, Color eyes)
    {
        int walkOffset = (frame == 1) ? 1 : (frame == 2) ? -1 : 0;

        // Shoes (y 0-2)
        FillRect(tex, ox + 4, oy + 0, 3, 3, shoes);
        FillRect(tex, ox + 9, oy + 0 + walkOffset, 3, 3, shoes);

        // Pants (y 3-8)
        FillRect(tex, ox + 4, oy + 3, 8, 5, pants);

        // Shirt (y 8-14)
        FillRect(tex, ox + 3, oy + 8, 10, 6, shirt);
        // Arms
        FillRect(tex, ox + 1, oy + 9, 2, 4, shirt);
        FillRect(tex, ox + 13, oy + 9, 2, 4, shirt);
        // Hands
        FillRect(tex, ox + 1, oy + 9, 2, 1, skin);
        FillRect(tex, ox + 13, oy + 9, 2, 1, skin);

        // Neck (y 14)
        FillRect(tex, ox + 6, oy + 14, 4, 1, skin);

        // Head (y 15-21)
        FillRect(tex, ox + 4, oy + 15, 8, 6, skin);

        if (direction == 0) // Facing down (front)
        {
            // Eyes
            tex.SetPixel(ox + 5, oy + 17, eyes);
            tex.SetPixel(ox + 6, oy + 17, eyes);
            tex.SetPixel(ox + 9, oy + 17, eyes);
            tex.SetPixel(ox + 10, oy + 17, eyes);
            // Mouth
            tex.SetPixel(ox + 7, oy + 16, new Color32(200, 100, 100, 255));
            tex.SetPixel(ox + 8, oy + 16, new Color32(200, 100, 100, 255));
            // Hair
            FillRect(tex, ox + 3, oy + 19, 10, 3, hair);
            FillRect(tex, ox + 3, oy + 18, 2, 2, hair);
            FillRect(tex, ox + 11, oy + 18, 2, 2, hair);
            // Hat
            FillRect(tex, ox + 3, oy + 21, 10, 3, hat);
            FillRect(tex, ox + 2, oy + 21, 1, 1, hatBrim);
            FillRect(tex, ox + 13, oy + 21, 1, 1, hatBrim);
        }
        else if (direction == 3) // Facing up (back)
        {
            FillRect(tex, ox + 3, oy + 15, 10, 7, hair);
            FillRect(tex, ox + 3, oy + 21, 10, 3, hat);
        }
        else // Side views
        {
            int d = (direction == 1) ? 0 : 1;
            tex.SetPixel(ox + 6 + d * 3, oy + 17, eyes);
            tex.SetPixel(ox + 7 + d * 2, oy + 17, eyes);
            FillRect(tex, ox + 3 + d, oy + 19, 9, 3, hair);
            FillRect(tex, ox + 3 + d, oy + 21, 10, 3, hat);
        }
    }

    // ================================================================
    // NPC SPRITE SHEETS
    // ================================================================
    static void GenerateNPCSpriteSheets()
    {
        // NPC variations
        var npcConfigs = new (string name, Color shirt, Color hair, Color pants)[]
        {
            ("npc_teacher_m", new Color32(64, 96, 160, 255), new Color32(80, 56, 32, 255), new Color32(56, 56, 64, 255)),
            ("npc_teacher_f", new Color32(160, 64, 96, 255), new Color32(96, 40, 24, 255), new Color32(56, 56, 72, 255)),
            ("npc_villager_m", new Color32(96, 160, 64, 255), new Color32(48, 32, 24, 255), new Color32(72, 56, 40, 255)),
            ("npc_villager_f", new Color32(200, 160, 64, 255), new Color32(160, 96, 32, 255), new Color32(120, 72, 48, 255)),
            ("npc_trainer_m", new Color32(200, 72, 48, 255), new Color32(24, 24, 32, 255), new Color32(40, 40, 56, 255)),
            ("npc_mentor", new Color32(160, 160, 176, 255), new Color32(200, 200, 208, 255), new Color32(80, 80, 96, 255)),
        };

        int fw = 16, fh = 24;
        foreach (var cfg in npcConfigs)
        {
            Texture2D sheet = CreateTex(fw * 3, fh * 4);
            Color shoes = new Color32(72, 56, 40, 255);
            Color eyes = new Color32(24, 24, 32, 255);

            for (int dir = 0; dir < 4; dir++)
                for (int frame = 0; frame < 3; frame++)
                    DrawCharacterFrame(sheet, frame * fw, dir * fh, fw, fh, dir, frame,
                        skinLight, cfg.hair, cfg.shirt, cfg.pants, shoes, cfg.shirt, Color.clear, eyes);

            SavePNG(sheet, CharacterPath + "/NPCs/" + cfg.name + ".png");
        }
        Debug.Log("[Character] NPC sprite sheets generated.");
    }

    // ================================================================
    // GYM LEADER SPRITES
    // ================================================================
    static void GenerateGymLeaderSprites()
    {
        var leaders = new (string name, Color primary, Color secondary, Color hair)[]
        {
            ("leader_vari", new Color32(48, 120, 200, 255), new Color32(200, 168, 48, 255), new Color32(200, 168, 48, 255)),
            ("leader_linear", new Color32(64, 160, 80, 255), new Color32(240, 240, 240, 255), new Color32(40, 80, 32, 255)),
            ("leader_grammar", new Color32(200, 72, 120, 255), new Color32(248, 216, 176, 255), new Color32(120, 56, 32, 255)),
            ("leader_note", new Color32(160, 48, 200, 255), new Color32(248, 200, 48, 255), new Color32(32, 32, 48, 255)),
            ("leader_quad", new Color32(200, 120, 48, 255), new Color32(48, 48, 72, 255), new Color32(160, 80, 24, 255)),
            ("guardian", new Color32(80, 80, 96, 255), new Color32(192, 192, 216, 255), new Color32(176, 176, 200, 255)),
        };

        int fw = 16, fh = 24;
        foreach (var ldr in leaders)
        {
            Texture2D sheet = CreateTex(fw * 3, fh * 4);
            Color shoes = Color.black;
            Color eyes = new Color32(24, 24, 32, 255);

            for (int dir = 0; dir < 4; dir++)
                for (int frame = 0; frame < 3; frame++)
                    DrawCharacterFrame(sheet, frame * fw, dir * fh, fw, fh, dir, frame,
                        skinMid, ldr.hair, ldr.primary, new Color32(32, 32, 40, 255),
                        shoes, ldr.secondary, ldr.secondary, eyes);

            SavePNG(sheet, CharacterPath + "/GymLeaders/" + ldr.name + ".png");
        }
        Debug.Log("[Character] Gym leader sprites generated.");
    }

    // ================================================================
    // UI SPRITES
    // ================================================================
    static void GenerateUISprites()
    {
        // Dialog box background (9-slice ready, 48x24)
        Texture2D dialogBg = CreateTex(48, 24);
        FillRect(dialogBg, 0, 0, 48, 24, uiBg);
        // Border
        FillRect(dialogBg, 0, 0, 48, 2, uiBorder);
        FillRect(dialogBg, 0, 22, 48, 2, uiBorder);
        FillRect(dialogBg, 0, 0, 2, 24, uiBorder);
        FillRect(dialogBg, 46, 0, 2, 24, uiBorder);
        // Inner border
        FillRect(dialogBg, 2, 2, 44, 1, new Color32(80, 88, 120, 255));
        FillRect(dialogBg, 2, 21, 44, 1, new Color32(80, 88, 120, 255));
        FillRect(dialogBg, 2, 2, 1, 20, new Color32(80, 88, 120, 255));
        FillRect(dialogBg, 45, 2, 1, 20, new Color32(80, 88, 120, 255));
        SavePNG(dialogBg, UIPath + "/dialog_bg.png");

        // Button normal
        Texture2D btnNormal = CreateTex(32, 12);
        FillRect(btnNormal, 0, 0, 32, 12, new Color32(48, 56, 96, 255));
        FillRect(btnNormal, 0, 0, 32, 1, new Color32(32, 40, 72, 255));
        FillRect(btnNormal, 0, 11, 32, 1, new Color32(80, 88, 128, 255));
        FillRect(btnNormal, 1, 1, 30, 1, new Color32(72, 80, 120, 255));
        SavePNG(btnNormal, UIPath + "/btn_normal.png");

        // Button hover
        Texture2D btnHover = CreateTex(32, 12);
        FillRect(btnHover, 0, 0, 32, 12, new Color32(72, 80, 128, 255));
        FillRect(btnHover, 0, 0, 32, 1, new Color32(56, 64, 104, 255));
        FillRect(btnHover, 0, 11, 32, 1, new Color32(104, 112, 160, 255));
        SavePNG(btnHover, UIPath + "/btn_hover.png");

        // Button correct (green)
        Texture2D btnCorrect = CreateTex(32, 12);
        FillRect(btnCorrect, 0, 0, 32, 12, new Color32(48, 128, 56, 255));
        FillRect(btnCorrect, 0, 11, 32, 1, new Color32(72, 160, 80, 255));
        SavePNG(btnCorrect, UIPath + "/btn_correct.png");

        // Button wrong (red)
        Texture2D btnWrong = CreateTex(32, 12);
        FillRect(btnWrong, 0, 0, 32, 12, new Color32(176, 48, 48, 255));
        FillRect(btnWrong, 0, 11, 32, 1, new Color32(200, 72, 72, 255));
        SavePNG(btnWrong, UIPath + "/btn_wrong.png");

        // HP bar background
        Texture2D hpBg = CreateTex(64, 8);
        FillRect(hpBg, 0, 0, 64, 8, new Color32(40, 40, 48, 255));
        FillRect(hpBg, 1, 1, 62, 6, new Color32(24, 24, 32, 255));
        SavePNG(hpBg, UIPath + "/hp_bar_bg.png");

        // HP bar fill (green)
        Texture2D hpFill = CreateTex(62, 6);
        FillRect(hpFill, 0, 0, 62, 6, new Color32(64, 200, 72, 255));
        FillRect(hpFill, 0, 5, 62, 1, new Color32(80, 224, 88, 255));
        SavePNG(hpFill, UIPath + "/hp_bar_fill.png");

        // XP bar fill (blue)
        Texture2D xpFill = CreateTex(62, 4);
        FillRect(xpFill, 0, 0, 62, 4, new Color32(64, 128, 232, 255));
        FillRect(xpFill, 0, 3, 62, 1, new Color32(88, 152, 248, 255));
        SavePNG(xpFill, UIPath + "/xp_bar_fill.png");

        // Badge icon template
        Texture2D badge = CreateTex(16, 16);
        FillRect(badge, 4, 2, 8, 12, new Color32(200, 168, 48, 255));
        FillRect(badge, 2, 4, 12, 8, new Color32(200, 168, 48, 255));
        FillRect(badge, 6, 5, 4, 6, new Color32(248, 224, 120, 255));
        FillRect(badge, 5, 6, 6, 4, new Color32(248, 224, 120, 255));
        FillRect(badge, 7, 7, 2, 2, Color.white);
        SavePNG(badge, UIPath + "/badge_icon.png");

        // Continue arrow (for dialog)
        Texture2D arrow = CreateTex(8, 8);
        arrow.SetPixel(3, 1, uiText); arrow.SetPixel(4, 1, uiText);
        arrow.SetPixel(2, 2, uiText); arrow.SetPixel(5, 2, uiText);
        arrow.SetPixel(1, 3, uiText); arrow.SetPixel(6, 3, uiText);
        arrow.SetPixel(3, 3, uiText); arrow.SetPixel(4, 3, uiText);
        arrow.SetPixel(3, 4, uiText); arrow.SetPixel(4, 4, uiText);
        arrow.SetPixel(3, 5, uiText); arrow.SetPixel(4, 5, uiText);
        SavePNG(arrow, UIPath + "/continue_arrow.png");

        Debug.Log("[UI] UI sprites generated.");
    }

    // ================================================================
    // BATTLE ASSETS
    // ================================================================
    static void GenerateBattleAssets()
    {
        // Battle background (160x96 — scaled up)
        Texture2D battleBg = CreateTex(160, 96);
        // Sky
        for (int y = 48; y < 96; y++)
        {
            float t = (float)(y - 48) / 48f;
            Color sky = Color.Lerp(new Color32(120, 160, 232, 255), new Color32(72, 112, 200, 255), t);
            for (int x = 0; x < 160; x++)
                battleBg.SetPixel(x, y, sky);
        }
        // Ground
        for (int y = 0; y < 48; y++)
        {
            Color ground = (y % 4 < 2) ? grassMid : grassDark;
            for (int x = 0; x < 160; x++)
                battleBg.SetPixel(x, y, ground);
        }
        // Horizon line
        FillRect(battleBg, 0, 48, 160, 2, grassDark);
        SavePNG(battleBg, BattlePath + "/Backgrounds/battle_bg_grass.png");

        // Gym battle background
        Texture2D gymBg = CreateTex(160, 96);
        // Indoor ceiling
        FillRect(gymBg, 0, 60, 160, 36, new Color32(80, 72, 64, 255));
        // Indoor floor (tiled)
        for (int y = 0; y < 60; y++)
            for (int x = 0; x < 160; x++)
            {
                bool light = ((x / 8) + (y / 8)) % 2 == 0;
                gymBg.SetPixel(x, y, light ? new Color32(192, 184, 168, 255) : new Color32(160, 152, 136, 255));
            }
        SavePNG(gymBg, BattlePath + "/Backgrounds/battle_bg_gym.png");

        // Silver Mountain background
        Texture2D mtBg = CreateTex(160, 96);
        for (int y = 0; y < 96; y++)
        {
            float t = (float)y / 96f;
            Color bg = Color.Lerp(new Color32(32, 24, 48, 255), new Color32(80, 64, 120, 255), t);
            for (int x = 0; x < 160; x++)
                mtBg.SetPixel(x, y, bg);
        }
        // Mountain silhouette
        for (int x = 0; x < 160; x++)
        {
            int h = 30 + (int)(Mathf.Sin(x * 0.05f) * 15 + Mathf.Sin(x * 0.02f) * 10);
            for (int y = 0; y < h; y++)
                mtBg.SetPixel(x, y, new Color32(48, 40, 72, 255));
        }
        // Stars
        System.Random starRng = new System.Random(77);
        for (int i = 0; i < 30; i++)
        {
            int sx = starRng.Next(160), sy = starRng.Next(50, 96);
            mtBg.SetPixel(sx, sy, new Color32(248, 248, 200, 255));
        }
        SavePNG(mtBg, BattlePath + "/Backgrounds/battle_bg_silver_mountain.png");

        // Hit effect
        Texture2D hitFx = CreateTex(16, 16);
        Color hitYellow = new Color32(255, 240, 64, 255);
        Color hitWhite = new Color32(255, 255, 255, 255);
        hitFx.SetPixel(8, 14, hitWhite); hitFx.SetPixel(8, 13, hitYellow);
        hitFx.SetPixel(3, 10, hitYellow); hitFx.SetPixel(13, 10, hitYellow);
        hitFx.SetPixel(2, 5, hitYellow); hitFx.SetPixel(14, 5, hitYellow);
        hitFx.SetPixel(8, 2, hitWhite); hitFx.SetPixel(8, 1, hitYellow);
        hitFx.SetPixel(5, 8, hitWhite); hitFx.SetPixel(11, 8, hitWhite);
        SavePNG(hitFx, BattlePath + "/Effects/hit_effect.png");

        Debug.Log("[Battle] Battle assets generated.");
    }

    // ================================================================
    // UTILITY FUNCTIONS
    // ================================================================
    static Texture2D CreateTex(int w, int h)
    {
        Texture2D tex = new Texture2D(w, h, TextureFormat.RGBA32, false);
        tex.filterMode = FilterMode.Point;
        Color[] clear = new Color[w * h];
        for (int i = 0; i < clear.Length; i++) clear[i] = Color.clear;
        tex.SetPixels(clear);
        return tex;
    }

    static void FillRect(Texture2D tex, int x, int y, int w, int h, Color c)
    {
        for (int px = x; px < x + w && px < tex.width; px++)
            for (int py = y; py < y + h && py < tex.height; py++)
                if (px >= 0 && py >= 0) tex.SetPixel(px, py, c);
    }

    static void SetPixels(Texture2D tex, int[,] coords, Color c)
    {
        for (int i = 0; i < coords.GetLength(0); i++)
            if (coords[i, 0] >= 0 && coords[i, 0] < tex.width &&
                coords[i, 1] >= 0 && coords[i, 1] < tex.height)
                tex.SetPixel(coords[i, 0], coords[i, 1], c);
    }

    static void SavePNG(Texture2D tex, string path)
    {
        tex.Apply();
        byte[] png = tex.EncodeToPNG();
        string fullPath = Path.Combine(Application.dataPath.Replace("Assets", ""), path);
        string dir = Path.GetDirectoryName(fullPath);
        if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
        File.WriteAllBytes(fullPath, png);

#if UNITY_EDITOR
        // Import with pixel-art settings
        AssetDatabase.ImportAsset(path);
        TextureImporter importer = AssetImporter.GetAtPath(path) as TextureImporter;
        if (importer != null)
        {
            importer.textureType = TextureImporterType.Sprite;
            importer.spritePixelsPerUnit = 16;
            importer.filterMode = FilterMode.Point;
            importer.textureCompression = TextureImporterCompression.Uncompressed;
            importer.spriteImportMode = SpriteImportMode.Single;
            importer.mipmapEnabled = false;
            importer.SaveAndReimport();
        }
#endif
    }
}
