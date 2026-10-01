using UnityEngine;
using TMPro;
using System.Collections.Generic;

/// <summary>
/// WorldManager — Manages the overworld map, cities, routes, and transitions.
/// Handles the region map with all cities and connections.
/// </summary>
public class WorldManager : MonoBehaviour
{
    public static WorldManager Instance { get; private set; }

    [Header("Region")]
    public string regionName = "Kaiserland";
    public List<CityData> cities = new List<CityData>();
    public List<RouteData> routes = new List<RouteData>();

    [Header("Player")]
    public PlayerController player;
    public string currentCityName = "";

    [Header("Map")]
    public GameObject worldMapUI;
    public bool showingWorldMap = false;

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;
    }

    private void Start()
    {
        if (player == null)
            player = FindObjectOfType<PlayerController>();

        // Set initial city
        if (GameManager.Instance != null)
        {
            string lastCity = GameManager.Instance.playerData.lastSaveCity;
            SetCurrentCity(lastCity);
        }
    }

    private void Update()
    {
        // Toggle world map with M key
        if (Input.GetKeyDown(KeyCode.M))
        {
            ToggleWorldMap();
        }
    }

    public void SetCurrentCity(string cityName)
    {
        currentCityName = cityName;
        if (GameManager.Instance != null)
        {
            GameManager.Instance.currentCity = cityName;
        }
    }

    public CityData GetCity(string cityName)
    {
        return cities.Find(c => c.cityName == cityName);
    }

    private void ToggleWorldMap()
    {
        showingWorldMap = !showingWorldMap;
        if (worldMapUI != null)
            worldMapUI.SetActive(showingWorldMap);

        if (player != null)
            player.SetCanMove(!showingWorldMap);
    }
}

/// <summary>
/// CityData — Data for a city/town in the region.
/// </summary>
[System.Serializable]
public class CityData
{
    public string cityName;
    public string description;
    public CityTheme theme;
    public Vector2 mapPosition;
    public bool hasGym;
    public int gymIndex;
    public List<string> connectedCities;
    public List<string> availableQuests;
}

public enum CityTheme
{
    StarterTown,
    Forest,
    Mountain,
    Beach,
    Desert,
    Snow,
    Industrial,
    Ancient,
    Modern,
    Mystical
}

/// <summary>
/// RouteData — Connection between two cities.
/// </summary>
[System.Serializable]
public class RouteData
{
    public string routeName;
    public string fromCity;
    public string toCity;
    public int difficulty;
    public bool hasTrainers;
    public int trainerCount;
    public bool hasTallGrass; // Random encounters
}

/// <summary>
/// CityEntrance — Trigger that loads/transitions to a city area.
/// </summary>
public class CityEntrance : MonoBehaviour
{
    public string cityName;
    public string targetSceneName;
    public Vector3 playerSpawnPosition;
    public bool useSceneTransition = false;

    [Header("Visual")]
    public TextMeshPro cityNameSign;

    private void Start()
    {
        if (cityNameSign != null)
            cityNameSign.text = cityName;
    }

    public void Enter()
    {
        Debug.Log($"[CityEntrance] Entering {cityName}");

        WorldManager.Instance?.SetCurrentCity(cityName);

        if (useSceneTransition && !string.IsNullOrEmpty(targetSceneName))
        {
            SceneLoader.Instance?.LoadScene(targetSceneName);
        }
        else
        {
            // Just update the city name display
            if (GameManager.Instance != null)
                GameManager.Instance.currentCity = cityName;
        }
    }
}

/// <summary>
/// EncounterZone — Tall grass or similar area that triggers random knowledge battles.
/// </summary>
public class EncounterZone : MonoBehaviour
{
    [Header("Encounter Settings")]
    public float encounterRate = 0.15f; // 15% chance per step
    public int minDifficulty = 1;
    public int maxDifficulty = 5;
    public string encounterTopic = "";
    public int xpReward = 30;

    [Header("Trainer Names")]
    public List<string> randomTrainerNames = new List<string>
    {
        "Scholar", "Student", "Apprentice", "Learner", "Seeker"
    };

    public void CheckEncounter()
    {
        if (Random.value < encounterRate)
        {
            TriggerEncounter();
        }
    }

    private void TriggerEncounter()
    {
        string trainerName = randomTrainerNames[Random.Range(0, randomTrainerNames.Count)];
        int difficulty = Random.Range(minDifficulty, maxDifficulty + 1);

        var introLines = new List<DialogLine>
        {
            new DialogLine(trainerName, $"A wild {trainerName} appeared!")
        };

        DialogSystem.Instance.ShowDialog(introLines, () =>
        {
            BattleData data = new BattleData
            {
                opponentName = trainerName,
                topic = encounterTopic,
                difficulty = difficulty,
                xpReward = xpReward,
                isGymBattle = false,
                isSilverMountain = false
            };

            BattleManager.Instance?.StartBattle(data);
        });
    }
}
