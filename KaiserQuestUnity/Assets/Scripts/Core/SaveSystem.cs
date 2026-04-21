// SaveSystem.cs — JSON Persistence
using UnityEngine;
using System.IO;
using System.Collections.Generic;

[System.Serializable]
public class SaveData
{
    public string                    playerName   = "Arix";
    public string                    activeSubject= "";
    public string                    activeBranch = "";
    public List<BranchEntry>         branches     = new();
}

[System.Serializable]
public class BranchEntry
{
    public string     key;
    public BranchData data;
}

public static class SaveSystem
{
    private static string SavePath => Path.Combine(Application.persistentDataPath, "kq_save.json");

    public static void Save()
    {
        var gm  = GameManager.Instance;
        var sd  = new SaveData();
        sd.playerName    = gm.PlayerName;
        sd.activeSubject = gm.ActiveSubject;
        sd.activeBranch  = gm.ActiveBranch;
        foreach (var kv in gm.AllBranches)
            sd.branches.Add(new BranchEntry { key = kv.Key, data = kv.Value });
        File.WriteAllText(SavePath, JsonUtility.ToJson(sd, true));
    }

    public static void Load()
    {
        if (!File.Exists(SavePath)) return;
        try {
            var sd = JsonUtility.FromJson<SaveData>(File.ReadAllText(SavePath));
            if (sd == null) return;
            var gm = GameManager.Instance;
            gm.PlayerName    = sd.playerName;
            gm.ActiveSubject = sd.activeSubject;
            gm.ActiveBranch  = sd.activeBranch;
            var dict = new Dictionary<string, BranchData>();
            foreach (var entry in sd.branches) dict[entry.key] = entry.data;
            gm.SetAllBranches(dict);
        } catch (System.Exception e) {
            Debug.LogWarning("Save load error: " + e.Message);
        }
    }

    public static void Delete()
    {
        if (File.Exists(SavePath)) File.Delete(SavePath);
    }
}
