using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using KaiserQuest.Knowledge;
using UnityEngine;

namespace KaiserQuest.Story
{
    /// <summary>One line of the save-slot list.</summary>
    [Serializable]
    public class SaveSummary
    {
        public string playerId;
        public string name;
        public string realm;
        public string levelLabel;
        public int milestoneIndex = 1;
        public string place;
        public double updatedAt;
        public List<string> clearedRealms = new List<string>();
    }

    /// <summary>
    /// Save storage.
    ///
    /// The v0.1 game kept everything in PlayerPrefs as a single blob, which cannot
    /// express what Silver Mountain needs: a save *point* the player is returned to
    /// when they fail the summit, per-realm progress, and a knowledge trace that must
    /// survive a 24-hour cooldown.
    ///
    /// So saves are versioned JSON files, one per player, written atomically (temp
    /// file then replace) so a crash mid-write cannot corrupt an existing save. This
    /// is also the "save point throughout the world" architecture: the save point is a
    /// real position in the world, not a bookmark in a menu.
    ///
    /// A direct port of services/save_store.py, with the same file format.
    /// </summary>
    public static class SaveSystem
    {
        public const int CurrentVersion = SaveGameData.CurrentVersion;

        private static readonly Regex SafeId = new Regex("[^A-Za-z0-9_.-]", RegexOptions.Compiled);

        /// <summary>Where saves live. On Android this is app-private storage.</summary>
        public static string DirectoryPath
        {
            get { return Path.Combine(Application.persistentDataPath, "saves"); }
        }

        /// <summary>Player ids become filenames, so they are sanitised, not trusted.</summary>
        public static string SafePlayerId(string playerId)
        {
            if (string.IsNullOrEmpty(playerId)) return "unknown";
            string cleaned = SafeId.Replace(playerId, "_");
            if (cleaned.Length > 120) cleaned = cleaned.Substring(0, 120);
            cleaned = cleaned.Trim('.', '_');
            return cleaned.Length > 0 ? cleaned : "unknown";
        }

        public static string PathFor(string playerId)
        {
            return Path.Combine(DirectoryPath, SafePlayerId(playerId) + ".json");
        }

        public static bool Exists(string playerId)
        {
            return File.Exists(PathFor(playerId));
        }

        /// <summary>
        /// Write a save atomically.
        ///
        /// The temporary file is fully flushed before it replaces the real one, so a
        /// crash or a battery pull mid-write leaves the previous save intact rather
        /// than a half-written file — which matters a great deal when the thing being
        /// written is the record of what a player knows.
        /// </summary>
        public static bool Save(SaveGameData data)
        {
            if (data == null || string.IsNullOrEmpty(data.playerId)) return false;

            try
            {
                Directory.CreateDirectory(DirectoryPath);

                data.version = CurrentVersion;
                data.updatedAt = Clock.Now;

                string path = PathFor(data.playerId);
                string tempPath = Path.Combine(DirectoryPath, ".tmp-" + Guid.NewGuid().ToString("N") + ".json");

                string json = JsonUtility.ToJson(data, true);
                using (FileStream stream = new FileStream(tempPath, FileMode.Create, FileAccess.Write, FileShare.None))
                {
                    byte[] bytes = new UTF8Encoding(false).GetBytes(json);
                    stream.Write(bytes, 0, bytes.Length);
                    stream.Flush(true);
                }

                if (File.Exists(path))
                {
                    File.Replace(tempPath, path, null);
                }
                else
                {
                    File.Move(tempPath, path);
                }
                return true;
            }
            catch (Exception error)
            {
                Debug.LogError("[SaveSystem] Could not write save for '" + data.playerId + "': " + error.Message);
                return false;
            }
        }

        /// <summary>
        /// Read a save.
        ///
        /// A corrupt file is reported and treated as "no save" rather than thrown, so
        /// a bad file can never make the game unlaunchable. A save from a *newer*
        /// build is loaded anyway, with a warning: refusing to load a file the player
        /// can see is worse than reading the fields this build understands.
        /// </summary>
        public static SaveGameData Load(string playerId)
        {
            string path = PathFor(playerId);
            if (!File.Exists(path)) return null;

            try
            {
                string json = File.ReadAllText(path, Encoding.UTF8);
                SaveGameData data = JsonUtility.FromJson<SaveGameData>(json);
                if (data == null) return null;

                if (data.version > CurrentVersion)
                {
                    Debug.LogWarning("[SaveSystem] Save '" + SafePlayerId(playerId) + "' is version " + data.version
                        + " but this build understands " + CurrentVersion + "; loading anyway.");
                }

                if (data.savePoint == null) data.savePoint = new SavePointData();
                if (data.knowledge == null) data.knowledge = new List<KaiserQuest.Knowledge.ConceptKnowledgeData>();
                if (data.attempts == null) data.attempts = new List<KaiserQuest.Knowledge.AttemptData>();
                if (data.realms == null) data.realms = new List<RealmProgressData>();
                if (data.mountains == null) data.mountains = new List<SilverMountainData>();
                if (data.recentQuestionIds == null) data.recentQuestionIds = new List<string>();
                return data;
            }
            catch (Exception error)
            {
                Debug.LogError("[SaveSystem] Corrupt save for '" + playerId + "' (" + error.Message
                    + "); starting fresh.");
                return null;
            }
        }

        public static bool Delete(string playerId)
        {
            try
            {
                string path = PathFor(playerId);
                if (!File.Exists(path)) return false;
                File.Delete(path);
                return true;
            }
            catch (Exception error)
            {
                Debug.LogError("[SaveSystem] Could not delete save for '" + playerId + "': " + error.Message);
                return false;
            }
        }

        /// <summary>Every save, newest first, for the continue screen.</summary>
        public static List<SaveSummary> List()
        {
            List<SaveSummary> summaries = new List<SaveSummary>();
            try
            {
                if (!Directory.Exists(DirectoryPath)) return summaries;

                string[] files = Directory.GetFiles(DirectoryPath, "*.json");
                for (int i = 0; i < files.Length; i++)
                {
                    string fileName = Path.GetFileNameWithoutExtension(files[i]);
                    if (fileName.StartsWith(".tmp-")) continue;

                    SaveGameData data = Load(fileName);
                    if (data == null) continue;

                    RealmProgressData progress = data.RealmProgress(data.realm);
                    SaveSummary summary = new SaveSummary();
                    summary.playerId = data.playerId;
                    summary.name = data.playerName;
                    summary.realm = data.realm;
                    summary.levelLabel = progress.PassedCount + " / 20 milestones";
                    summary.milestoneIndex = data.savePoint != null ? data.savePoint.milestoneIndex : 1;
                    summary.place = data.savePoint != null ? data.savePoint.place : string.Empty;
                    summary.updatedAt = data.updatedAt;
                    for (int r = 0; r < data.mountains.Count; r++)
                    {
                        if (data.mountains[r].cleared) summary.clearedRealms.Add(data.mountains[r].realm);
                    }
                    summaries.Add(summary);
                }

                summaries.Sort(delegate (SaveSummary a, SaveSummary b)
                {
                    return b.updatedAt.CompareTo(a.updatedAt);
                });
            }
            catch (Exception error)
            {
                Debug.LogError("[SaveSystem] Could not list saves: " + error.Message);
            }
            return summaries;
        }

        /// <summary>A brand new save for a brand new explorer.</summary>
        public static SaveGameData NewGame(string playerId, string playerName, string appearanceId, string realm)
        {
            SaveGameData data = new SaveGameData();
            data.version = CurrentVersion;
            data.playerId = SafePlayerId(playerId);
            data.playerName = string.IsNullOrEmpty(playerName) ? "Kai" : playerName;
            data.appearanceId = string.IsNullOrEmpty(appearanceId) ? "default" : appearanceId;
            data.realm = string.IsNullOrEmpty(realm) ? "algebra" : realm;
            data.createdAt = Clock.Now;
            data.updatedAt = Clock.Now;

            data.savePoint = new SavePointData();
            data.savePoint.realm = data.realm;
            data.savePoint.milestoneIndex = 1;
            data.savePoint.place = string.Empty;
            data.savePoint.savedAt = Clock.Now;

            data.RealmProgress(data.realm);
            data.Mountain(data.realm);
            return data;
        }
    }
}
