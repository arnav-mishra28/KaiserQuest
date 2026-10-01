using System;
using System.Collections.Generic;
using KaiserQuest.Knowledge;

namespace KaiserQuest.Story
{
    /// <summary>One keyed integer, because JsonUtility cannot serialise a dictionary.</summary>
    [Serializable]
    public class IntEntry
    {
        public int key;
        public int value;
    }

    /// <summary>One keyed float, for the same reason.</summary>
    [Serializable]
    public class FloatEntry
    {
        public int key;
        public float value;
    }

    /// <summary>How far a player has got in one realm.</summary>
    [Serializable]
    public class RealmProgressData
    {
        public string realm;
        public List<int> passed = new List<int>();
        public List<IntEntry> attempts = new List<IntEntry>();
        public List<FloatEntry> bestScore = new List<FloatEntry>();
        public List<string> badges = new List<string>();
        public int lastSaveIndex = 1;
        public bool completed;

        public bool HasPassed(int index)
        {
            return passed.Contains(index);
        }

        public int RecordAttempt(int index, float score)
        {
            IntEntry attemptEntry = FindAttempt(index);
            if (attemptEntry == null)
            {
                attemptEntry = new IntEntry();
                attemptEntry.key = index;
                attempts.Add(attemptEntry);
            }
            attemptEntry.value++;

            FloatEntry scoreEntry = FindScore(index);
            if (scoreEntry == null)
            {
                scoreEntry = new FloatEntry();
                scoreEntry.key = index;
                bestScore.Add(scoreEntry);
            }
            if (score > scoreEntry.value) scoreEntry.value = score;
            return attemptEntry.value;
        }

        public int AttemptsFor(int index)
        {
            IntEntry entry = FindAttempt(index);
            return entry != null ? entry.value : 0;
        }

        public float BestScoreFor(int index)
        {
            FloatEntry entry = FindScore(index);
            return entry != null ? entry.value : 0f;
        }

        public bool MarkPassed(int index, string badge)
        {
            bool already = passed.Contains(index);
            if (!already) passed.Add(index);
            if (!string.IsNullOrEmpty(badge) && !badges.Contains(badge)) badges.Add(badge);
            if (index >= lastSaveIndex) lastSaveIndex = index;
            return !already;
        }

        public int PassedCount { get { return passed.Count; } }

        private IntEntry FindAttempt(int index)
        {
            for (int i = 0; i < attempts.Count; i++) if (attempts[i].key == index) return attempts[i];
            return null;
        }

        private FloatEntry FindScore(int index)
        {
            for (int i = 0; i < bestScore.Count; i++) if (bestScore[i].key == index) return bestScore[i];
            return null;
        }
    }

    /// <summary>One climb of Silver Mountain.</summary>
    [Serializable]
    public class ArchivistAttemptData
    {
        public int number;
        public bool passed;
        public float scorePercent;
        public double timestamp;
    }

    /// <summary>One station of the Mastery Recap.</summary>
    [Serializable]
    public class RecapStepData
    {
        public int order;
        public string kind;
        public string concept;
        public string conceptName;
        public string title;
        public string body;
        public float mastery;
    }

    /// <summary>The persistent state of the summit for one realm.</summary>
    [Serializable]
    public class SilverMountainData
    {
        public const int AttemptsPerWindow = 3;
        public const double CooldownHours = 24.0;

        public string realm;
        public int attemptsRemaining = AttemptsPerWindow;
        public double cooldownUntil;
        public bool cleared;
        public double clearedAt;
        public List<ArchivistAttemptData> history = new List<ArchivistAttemptData>();
        public List<RecapStepData> recap = new List<RecapStepData>();

        /// <summary>Expire a cooldown and restore the attempts. Returns true if it expired.</summary>
        public bool Refresh(double now)
        {
            if (cooldownUntil > 0.0 && now >= cooldownUntil)
            {
                cooldownUntil = 0.0;
                attemptsRemaining = AttemptsPerWindow;
                return true;
            }
            return false;
        }

        public double CooldownRemaining(double now)
        {
            return cooldownUntil > 0.0 ? Math.Max(0.0, cooldownUntil - now) : 0.0;
        }
    }

    /// <summary>A save point in the world — a real place, not a bookmark in a menu.</summary>
    [Serializable]
    public class SavePointData
    {
        public string realm = "algebra";
        public int milestoneIndex = 1;
        public string place = "";
        public double savedAt;
    }

    /// <summary>
    /// The whole save.
    ///
    /// Versioned, and the knowledge trace travels with it: the 24-hour Silver
    /// Mountain cooldown only means anything if the model of what the player knows is
    /// still there when they come back.
    /// </summary>
    [Serializable]
    public class SaveGameData
    {
        public const int CurrentVersion = 2;

        public int version = CurrentVersion;
        public string playerId = "local";
        public string playerName = "Kai";
        public string appearanceId = "default";
        public string realm = "algebra";
        public double createdAt;
        public double updatedAt;

        public SavePointData savePoint = new SavePointData();
        public List<ConceptKnowledgeData> knowledge = new List<ConceptKnowledgeData>();
        public List<AttemptData> attempts = new List<AttemptData>();
        public List<RealmProgressData> realms = new List<RealmProgressData>();
        public List<SilverMountainData> mountains = new List<SilverMountainData>();
        public List<string> recentQuestionIds = new List<string>();

        public RealmProgressData RealmProgress(string realmId)
        {
            for (int i = 0; i < realms.Count; i++) if (realms[i].realm == realmId) return realms[i];
            RealmProgressData created = new RealmProgressData();
            created.realm = realmId;
            realms.Add(created);
            return created;
        }

        public SilverMountainData Mountain(string realmId)
        {
            for (int i = 0; i < mountains.Count; i++) if (mountains[i].realm == realmId) return mountains[i];
            SilverMountainData created = new SilverMountainData();
            created.realm = realmId;
            mountains.Add(created);
            return created;
        }
    }
}
