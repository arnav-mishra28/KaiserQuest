using UnityEngine;
using UnityEngine.Tilemaps;
using System.Collections.Generic;

/// <summary>
/// ProceduralWorldGenerator — Generates the overworld map procedurally.
/// Creates a Pokemon-style region with cities, routes, grass, water, and trees.
/// Uses the PixelSpriteGenerator for tile sprites.
/// </summary>
public class ProceduralWorldGenerator : MonoBehaviour
{
    [Header("Tilemaps")]
    public Tilemap groundTilemap;
    public Tilemap pathTilemap;
    public Tilemap decorationTilemap;
    public Tilemap collisionTilemap;
    public Tilemap waterTilemap;

    [Header("Tiles (auto-generated if null)")]
    public TileBase grassTile;
    public TileBase pathTile;
    public TileBase waterTile;
    public TileBase treeTile;
    public TileBase wallTile;

    [Header("World Settings")]
    public int worldWidth = 200;
    public int worldHeight = 200;
    public float perlinScale = 0.1f;
    public int seed = 42;

    [Header("City Prefabs")]
    public GameObject cityPrefab;
    public GameObject gymPrefab;
    public GameObject npcPrefab;
    public GameObject signPrefab;
    public GameObject encounterZonePrefab;

    [Header("Generated Cities")]
    public List<GeneratedCity> generatedCities = new List<GeneratedCity>();

    // The 20 cities + starter town + Silver Mountain
    private readonly string[] cityNames = {
        "Origin Village",       // Starter
        "Numeria",              // Gym 1: Variables
        "Equaton",              // Gym 2: Linear Equations  
        "Lexicon",              // Gym 3: Grammar
        "Harmonia",             // Gym 4: Notes
        "Quadralis",            // Gym 5: Quadratics
        "Verbum",               // Gym 6: Vocabulary
        "Rhythmia",             // Gym 7: Rhythm
        "Polynova",             // Gym 8: Polynomials
        "Syntaxia",             // Gym 9: Writing
        "Scalara",              // Gym 10: Scales
        "Graphton",             // Gym 11: Graphs
        "Prosdia",              // Gym 12: Sentence Structure
        "Chordwell",            // Gym 13: Chords
        "Functionburg",         // Gym 14: Functions
        "Morphia",              // Gym 15: Word Forms
        "Composia",             // Gym 16: Composition
        "Integra",              // Gym 17: Advanced Algebra
        "Eloqua",               // Gym 18: Advanced English
        "Fortissimo",           // Gym 19: Advanced Music
        "Omnium",               // Gym 20: Mixed Mastery
        "Silver Mountain"       // Final Boss
    };

    private readonly string[] gymTopics = {
        "", // Starter (no gym)
        "Variables", "Linear Equations", "Grammar", "Notes",
        "Quadratics", "Vocabulary", "Rhythm", "Polynomials",
        "Writing", "Scales", "Graphs", "Sentence Structure",
        "Chords", "Functions", "Word Forms", "Composition",
        "Advanced Algebra", "Advanced English", "Advanced Music",
        "Mixed Mastery", "" // Silver Mountain
    };

    private readonly string[] gymSubjects = {
        "",
        "Mathematics", "Mathematics", "Languages", "Music",
        "Mathematics", "Languages", "Music", "Mathematics",
        "Languages", "Music", "Mathematics", "Languages",
        "Music", "Mathematics", "Languages", "Music",
        "Mathematics", "Languages", "Music",
        "Mixed", ""
    };

    private readonly string[] gymLeaderNames = {
        "",
        "Prof. Vari", "Dr. Linear", "Ms. Grammar", "Maestro Note",
        "Prof. Quad", "Lord Lexis", "DJ Rhythm", "Dr. Poly",
        "Author Syn", "Scale Master", "Graph Sage", "Prose Knight",
        "Chord Queen", "Function King", "Morpho Lord", "Composer X",
        "Algebra Lord", "Language Master", "Music Sage",
        "Omni Kaiser", "The Guardian"
    };

    public void GenerateWorld()
    {
        Random.InitState(seed);

        // Step 1: Generate base terrain
        GenerateTerrain();

        // Step 2: Place cities
        PlaceCities();

        // Step 3: Connect cities with paths
        ConnectCities();

        // Step 4: Add encounter zones (tall grass)
        AddEncounterZones();

        // Step 5: Add decorations (trees, rocks)
        AddDecorations();

        Debug.Log("[WorldGen] World generation complete!");
    }

    private void GenerateTerrain()
    {
        float offsetX = Random.Range(0f, 10000f);
        float offsetY = Random.Range(0f, 10000f);

        for (int x = -worldWidth / 2; x < worldWidth / 2; x++)
        {
            for (int y = -worldHeight / 2; y < worldHeight / 2; y++)
            {
                float noise = Mathf.PerlinNoise(
                    (x + offsetX) * perlinScale,
                    (y + offsetY) * perlinScale
                );

                Vector3Int pos = new Vector3Int(x, y, 0);

                if (noise < 0.25f)
                {
                    // Water
                    if (waterTilemap != null && waterTile != null)
                    {
                        waterTilemap.SetTile(pos, waterTile);
                        collisionTilemap?.SetTile(pos, wallTile);
                    }
                }
                else
                {
                    // Grass
                    if (groundTilemap != null && grassTile != null)
                    {
                        groundTilemap.SetTile(pos, grassTile);
                    }
                }
            }
        }
    }

    private void PlaceCities()
    {
        generatedCities.Clear();

        // Place cities in a rough progression path
        // Starting from bottom-left, moving to top-right for Silver Mountain
        float radius = worldWidth * 0.35f;
        float angleStep = 360f / (cityNames.Length - 1);

        for (int i = 0; i < cityNames.Length; i++)
        {
            Vector2 position;

            if (i == 0)
            {
                // Starter town at center-bottom
                position = new Vector2(0, -worldHeight * 0.3f);
            }
            else if (i == cityNames.Length - 1)
            {
                // Silver Mountain at the top
                position = new Vector2(0, worldHeight * 0.35f);
            }
            else
            {
                // Distribute cities in a spiral pattern
                float angle = (i - 1) * angleStep * Mathf.Deg2Rad;
                float r = radius * (0.3f + 0.7f * ((float)i / cityNames.Length));
                position = new Vector2(
                    Mathf.Cos(angle) * r * 0.8f,
                    Mathf.Sin(angle) * r * 0.5f + (i * worldHeight * 0.02f) - worldHeight * 0.15f
                );
            }

            // Snap to grid
            position = new Vector2(
                Mathf.Round(position.x),
                Mathf.Round(position.y)
            );

            // Create city area (clear a rectangular area)
            int citySize = (i == 0 || i == cityNames.Length - 1) ? 12 : 8;
            ClearAreaForCity(position, citySize);

            // Place city
            GeneratedCity city = new GeneratedCity
            {
                cityName = cityNames[i],
                position = position,
                size = citySize,
                hasGym = (i > 0 && i < cityNames.Length - 1),
                gymIndex = i > 0 ? i : -1,
                gymTopic = i < gymTopics.Length ? gymTopics[i] : "",
                gymSubject = i < gymSubjects.Length ? gymSubjects[i] : "",
                leaderName = i < gymLeaderNames.Length ? gymLeaderNames[i] : "",
                isSilverMountain = (i == cityNames.Length - 1)
            };

            generatedCities.Add(city);

            // Spawn city objects
            SpawnCityObjects(city);
        }
    }

    private void ClearAreaForCity(Vector2 center, int size)
    {
        int halfSize = size / 2;
        for (int x = (int)center.x - halfSize; x <= (int)center.x + halfSize; x++)
        {
            for (int y = (int)center.y - halfSize; y <= (int)center.y + halfSize; y++)
            {
                Vector3Int pos = new Vector3Int(x, y, 0);

                // Clear water and collisions
                waterTilemap?.SetTile(pos, null);
                collisionTilemap?.SetTile(pos, null);
                decorationTilemap?.SetTile(pos, null);

                // Set path ground
                if (pathTilemap != null && pathTile != null)
                    pathTilemap.SetTile(pos, pathTile);
            }
        }
    }

    private void SpawnCityObjects(GeneratedCity city)
    {
        // City sign
        if (signPrefab != null)
        {
            GameObject sign = Instantiate(signPrefab, new Vector3(city.position.x, city.position.y - city.size / 2, 0), Quaternion.identity);
            sign.name = $"Sign_{city.cityName}";
            // Set sign text via component
            var npc = sign.GetComponent<NPCController>();
            if (npc != null)
            {
                npc.npcName = "Sign";
                npc.dialogLines = new List<string> { $"Welcome to {city.cityName}!" };
            }
        }

        // Gym building (if applicable)
        if (city.hasGym && gymPrefab != null)
        {
            Vector3 gymPos = new Vector3(city.position.x, city.position.y + 2, 0);
            GameObject gym = Instantiate(gymPrefab, gymPos, Quaternion.identity);
            gym.name = $"Gym_{city.cityName}";

            GymData gymData = gym.GetComponent<GymData>();
            if (gymData != null)
            {
                gymData.gymIndex = city.gymIndex - 1;
                gymData.gymName = $"{city.cityName} Gym";
                gymData.cityName = city.cityName;
                gymData.gymTopic = city.gymTopic;
                gymData.gymSubject = city.gymSubject;
                gymData.leaderName = city.leaderName;
                gymData.gymDifficulty = city.gymIndex;
                gymData.badgeName = $"{city.cityName} Badge";
            }
        }

        // Silver Mountain boss
        if (city.isSilverMountain && npcPrefab != null)
        {
            Vector3 bossPos = new Vector3(city.position.x, city.position.y + 3, 0);
            GameObject boss = Instantiate(npcPrefab, bossPos, Quaternion.identity);
            boss.name = "SilverMountain_Guardian";

            NPCController npc = boss.GetComponent<NPCController>();
            if (npc != null)
            {
                npc.npcName = "The Guardian";
                npc.npcType = NPCType.SilverMountainBoss;
                npc.battleLevel = 100;
                npc.xpReward = 1000;
            }
        }

        // NPCs
        if (npcPrefab != null)
        {
            // Add 2-3 NPCs per city
            int npcCount = Random.Range(2, 4);
            for (int i = 0; i < npcCount; i++)
            {
                Vector2 npcPos = city.position + new Vector2(
                    Random.Range(-city.size / 3f, city.size / 3f),
                    Random.Range(-city.size / 3f, city.size / 3f)
                );

                GameObject npcObj = Instantiate(npcPrefab, new Vector3(npcPos.x, npcPos.y, 0), Quaternion.identity);
                npcObj.name = $"NPC_{city.cityName}_{i}";

                NPCController npcCtrl = npcObj.GetComponent<NPCController>();
                if (npcCtrl != null)
                {
                    npcCtrl.npcName = GetRandomNPCName();
                    npcCtrl.npcType = Random.value > 0.5f ? NPCType.Villager : NPCType.Teacher;
                    npcCtrl.dialogLines = GetCityDialog(city.cityName);
                    npcCtrl.teachingTopic = city.gymTopic;
                    npcCtrl.battleLevel = Mathf.Max(1, city.gymIndex);
                    npcCtrl.xpReward = 30 + city.gymIndex * 10;
                }
            }
        }
    }

    private void ConnectCities()
    {
        // Connect each city to the next in sequence
        for (int i = 0; i < generatedCities.Count - 1; i++)
        {
            DrawPath(generatedCities[i].position, generatedCities[i + 1].position);
        }

        // Add some cross-connections for variety
        for (int i = 0; i < generatedCities.Count - 2; i += 3)
        {
            if (i + 2 < generatedCities.Count)
            {
                DrawPath(generatedCities[i].position, generatedCities[i + 2].position);
            }
        }
    }

    private void DrawPath(Vector2 from, Vector2 to)
    {
        // Simple L-shaped path (horizontal then vertical)
        Vector2 current = from;
        int pathWidth = 2;

        // Horizontal
        int dirX = to.x > from.x ? 1 : -1;
        while (Mathf.Abs(current.x - to.x) > 1)
        {
            for (int w = -pathWidth / 2; w <= pathWidth / 2; w++)
            {
                Vector3Int pos = new Vector3Int((int)current.x, (int)current.y + w, 0);
                if (pathTilemap != null && pathTile != null)
                    pathTilemap.SetTile(pos, pathTile);
                waterTilemap?.SetTile(pos, null);
                collisionTilemap?.SetTile(pos, null);
            }
            current.x += dirX;
        }

        // Vertical
        int dirY = to.y > current.y ? 1 : -1;
        while (Mathf.Abs(current.y - to.y) > 1)
        {
            for (int w = -pathWidth / 2; w <= pathWidth / 2; w++)
            {
                Vector3Int pos = new Vector3Int((int)current.x + w, (int)current.y, 0);
                if (pathTilemap != null && pathTile != null)
                    pathTilemap.SetTile(pos, pathTile);
                waterTilemap?.SetTile(pos, null);
                collisionTilemap?.SetTile(pos, null);
            }
            current.y += dirY;
        }
    }

    private void AddEncounterZones()
    {
        if (encounterZonePrefab == null) return;

        // Add encounter zones between cities (tall grass areas)
        for (int i = 0; i < generatedCities.Count - 1; i++)
        {
            Vector2 midpoint = (generatedCities[i].position + generatedCities[i + 1].position) / 2f;
            midpoint += new Vector2(Random.Range(-5f, 5f), Random.Range(-5f, 5f));

            GameObject zone = Instantiate(encounterZonePrefab, 
                new Vector3(midpoint.x, midpoint.y, 0), Quaternion.identity);
            zone.name = $"EncounterZone_{i}";

            EncounterZone ez = zone.GetComponent<EncounterZone>();
            if (ez != null)
            {
                ez.minDifficulty = Mathf.Max(1, i);
                ez.maxDifficulty = i + 3;
                ez.encounterRate = 0.12f;
                ez.xpReward = 20 + i * 10;
            }

            // Create tall grass visual in tilemap
            int zoneSize = Random.Range(4, 8);
            for (int x = -zoneSize; x <= zoneSize; x++)
            {
                for (int y = -zoneSize; y <= zoneSize; y++)
                {
                    Vector3Int pos = new Vector3Int((int)midpoint.x + x, (int)midpoint.y + y, 0);
                    // Darker grass for encounter zones
                    if (groundTilemap != null && grassTile != null)
                        groundTilemap.SetTile(pos, grassTile);
                }
            }
        }
    }

    private void AddDecorations()
    {
        // Add trees around the world
        System.Random rng = new System.Random(seed + 100);

        for (int x = -worldWidth / 2; x < worldWidth / 2; x += 3)
        {
            for (int y = -worldHeight / 2; y < worldHeight / 2; y += 3)
            {
                // Don't place trees on cities or paths
                Vector3Int pos = new Vector3Int(x, y, 0);
                if (pathTilemap != null && pathTilemap.HasTile(pos)) continue;
                if (waterTilemap != null && waterTilemap.HasTile(pos)) continue;

                // Check if near a city
                bool nearCity = false;
                foreach (var city in generatedCities)
                {
                    if (Vector2.Distance(new Vector2(x, y), city.position) < city.size + 3)
                    {
                        nearCity = true;
                        break;
                    }
                }
                if (nearCity) continue;

                // Random tree placement
                if (rng.Next(100) < 15) // 15% chance
                {
                    if (decorationTilemap != null && treeTile != null)
                    {
                        decorationTilemap.SetTile(pos, treeTile);
                        collisionTilemap?.SetTile(pos, wallTile);
                    }
                }
            }
        }
    }

    private string GetRandomNPCName()
    {
        string[] names = {
            "Scholar Ada", "Prof. Binary", "Student Cody", "Teacher Diana",
            "Sage Erik", "Mentor Flora", "Guide Galen", "Healer Iris",
            "Knight Jasper", "Sage Kira", "Monk Leo", "Oracle Maya",
            "Scholar Nyx", "Prof. Orion", "Guide Petra", "Sage Quinn"
        };
        return names[Random.Range(0, names.Length)];
    }

    private List<string> GetCityDialog(string cityName)
    {
        return new List<string>
        {
            $"Welcome to {cityName}!",
            "Knowledge is fading from the world...",
            "Only a true scholar can restore it!",
            "The gym here will test your knowledge. Are you ready?"
        };
    }
}

[System.Serializable]
public class GeneratedCity
{
    public string cityName;
    public Vector2 position;
    public int size;
    public bool hasGym;
    public int gymIndex;
    public string gymTopic;
    public string gymSubject;
    public string leaderName;
    public bool isSilverMountain;
}
