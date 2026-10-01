using System;
using System.Collections.Generic;
using KaiserQuest.Knowledge;
using UnityEngine;

namespace KaiserQuest.Story
{
    /// <summary>
    /// One playable look.
    ///
    /// The protagonist is an Explorer of Knowledge, not a chosen one, so the presets
    /// are reading as much as dressing: colours borrowed from the three realms'
    /// accents, with the free choice of which realm to start in left to the player.
    /// Stored as hex so a save file stays human-readable.
    /// </summary>
    [Serializable]
    public class AppearancePreset
    {
        public string id;
        public string name;
        public string description;

        public string skin;
        public string hair;
        public string shirt;
        public string pants;
        public string shoes;
        public string hat;
        public string hatBrim;
        public string eyes;
        public string outline;

        public Color Skin { get { return CharacterCreation.ColorOf(skin, new Color(0.96f, 0.82f, 0.68f)); } }
        public Color Hair { get { return CharacterCreation.ColorOf(hair, new Color(0.2f, 0.15f, 0.1f)); } }
        public Color Shirt { get { return CharacterCreation.ColorOf(shirt, new Color(0.85f, 0.2f, 0.2f)); } }
        public Color Pants { get { return CharacterCreation.ColorOf(pants, new Color(0.2f, 0.3f, 0.6f)); } }
        public Color Shoes { get { return CharacterCreation.ColorOf(shoes, new Color(0.3f, 0.25f, 0.2f)); } }
        public Color Hat { get { return CharacterCreation.ColorOf(hat, Shirt); } }
        public Color HatBrim { get { return CharacterCreation.ColorOf(hatBrim, Color.white); } }
        public Color Eyes { get { return CharacterCreation.ColorOf(eyes, new Color(0.1f, 0.1f, 0.15f)); } }
        public Color Outline { get { return CharacterCreation.ColorOf(outline, new Color(0.15f, 0.12f, 0.1f)); } }
    }

    /// <summary>One realm a player may start in, with the case for each.</summary>
    public class RealmChoice
    {
        public string Id;
        public string Name;
        public string Section;
        public string Tagline;
        public string Sigil;
        public string Accent;
        public int ConceptCount;
    }

    /// <summary>
    /// Character creation.
    ///
    /// The player picks a name, a look, and which realm to enter first. They do not
    /// pick a difficulty, a class, or a level: there is no stat to allocate, because
    /// the only thing that grows in this game is what they understand.
    /// </summary>
    public static class CharacterCreation
    {
        public const string DefaultName = "Kai";
        public const int MaxNameLength = 12;
        public const string DefaultAppearanceId = "explorer";

        private static List<AppearancePreset> _appearances;

        public static List<AppearancePreset> Appearances
        {
            get
            {
                if (_appearances == null) _appearances = BuildAppearances();
                return _appearances;
            }
        }

        public static AppearancePreset FindAppearance(string id)
        {
            List<AppearancePreset> presets = Appearances;
            if (string.IsNullOrEmpty(id)) return presets[0];
            for (int i = 0; i < presets.Count; i++)
            {
                if (presets[i].id == id) return presets[i];
            }
            return presets[0];
        }

        /// <summary>
        /// Names go on a save file and into dialogue, so: trimmed, length-capped,
        /// control characters stripped, and never empty.
        /// </summary>
        public static string ValidateName(string raw)
        {
            if (string.IsNullOrEmpty(raw)) return DefaultName;

            string trimmed = raw.Trim();
            if (trimmed.Length > MaxNameLength) trimmed = trimmed.Substring(0, MaxNameLength);

            string cleaned = string.Empty;
            for (int i = 0; i < trimmed.Length; i++)
            {
                char c = trimmed[i];
                if (char.IsControl(c)) continue;
                if (c == '\n' || c == '\r' || c == '\t') continue;
                cleaned += c;
            }
            cleaned = cleaned.Trim();
            return cleaned.Length > 0 ? cleaned : DefaultName;
        }

        /// <summary>The realms a new player may choose between, read from the graph.</summary>
        public static List<RealmChoice> Realms(KnowledgeEngine engine)
        {
            List<RealmChoice> choices = new List<RealmChoice>();
            if (engine == null || engine.Graph == null) return choices;

            IList<RealmData> realms = engine.Graph.Realms;
            for (int i = 0; i < realms.Count; i++)
            {
                RealmData realm = realms[i];
                if (realm == null) continue;

                RealmChoice choice = new RealmChoice();
                choice.Id = realm.id;
                choice.Name = realm.name;
                choice.Section = realm.section;
                choice.Tagline = realm.tagline;
                choice.Sigil = realm.sigil;
                choice.Accent = realm.accent;
                choice.ConceptCount = engine.Graph.ConceptsOfRealm(realm.id).Count;
                choices.Add(choice);
            }
            return choices;
        }

        /// <summary>Build the save for a newly created explorer and persist it.</summary>
        public static SaveGameData Create(
            string name, string appearanceId, string realmId, string playerId = "local")
        {
            AppearancePreset appearance = FindAppearance(appearanceId);
            SaveGameData save = SaveSystem.NewGame(
                playerId, ValidateName(name), appearance.id, realmId);

            // The starting point is a real place in the realm, not a menu screen.
            Milestone first = null;
            KnowledgeEngine engine = KnowledgeEngine.Instance;
            if (engine != null && engine.Graph != null)
            {
                List<Milestone> milestones = MilestoneCatalog.Build(engine.Graph, save.realm);
                if (milestones.Count > 0) first = milestones[0];
            }
            if (first != null)
            {
                save.savePoint.milestoneIndex = first.Index;
                save.savePoint.place = first.Place;
            }

            SaveSystem.Save(save);
            return save;
        }

        /// <summary>Parse "#rrggbb" or "rrggbb", falling back rather than throwing.</summary>
        public static Color ColorOf(string hex, Color fallback)
        {
            if (string.IsNullOrEmpty(hex)) return fallback;
            string value = hex.Trim();
            if (value.StartsWith("#")) value = value.Substring(1);
            if (value.Length != 6 && value.Length != 8) return fallback;

            int r, g, b;
            if (!TryHex(value.Substring(0, 2), out r)) return fallback;
            if (!TryHex(value.Substring(2, 2), out g)) return fallback;
            if (!TryHex(value.Substring(4, 2), out b)) return fallback;

            float alpha = 1f;
            if (value.Length == 8)
            {
                int a;
                if (TryHex(value.Substring(6, 2), out a)) alpha = a / 255f;
            }
            return new Color(r / 255f, g / 255f, b / 255f, alpha);
        }

        private static bool TryHex(string pair, out int value)
        {
            value = 0;
            int high = HexDigit(pair[0]);
            int low = HexDigit(pair[1]);
            if (high < 0 || low < 0) return false;
            value = high * 16 + low;
            return true;
        }

        private static int HexDigit(char c)
        {
            if (c >= '0' && c <= '9') return c - '0';
            if (c >= 'a' && c <= 'f') return c - 'a' + 10;
            if (c >= 'A' && c <= 'F') return c - 'A' + 10;
            return -1;
        }

        private static AppearancePreset Make(
            string id, string name, string description, string skin, string hair, string shirt,
            string pants, string shoes, string hat, string hatBrim, string eyes, string outline)
        {
            AppearancePreset preset = new AppearancePreset();
            preset.id = id;
            preset.name = name;
            preset.description = description;
            preset.skin = skin;
            preset.hair = hair;
            preset.shirt = shirt;
            preset.pants = pants;
            preset.shoes = shoes;
            preset.hat = hat;
            preset.hatBrim = hatBrim;
            preset.eyes = eyes;
            preset.outline = outline;
            return preset;
        }

        private static List<AppearancePreset> BuildAppearances()
        {
            List<AppearancePreset> presets = new List<AppearancePreset>();

            presets.Add(Make("explorer", "Explorer",
                "The one you start with: a red field cap and no particular plan.",
                "f5d1a8", "33261a", "d93333", "3350a0", "4d4033", "d93333", "ffffff", "1a1a26", "26201a"));

            presets.Add(Make("scholar", "Scholar",
                "Ink-blue coat, hair tied back. Reads the question twice.",
                "e8c49a", "1f1a2e", "2f5d8c", "23304d", "3a3a44", "2f5d8c", "d9e6f2", "10131c", "1c1a24"));

            presets.Add(Make("axiom", "Axiom",
                "Realm of Algebra's colours. Says the working out loud.",
                "efcfa6", "3d2b1f", "2e7d5b", "1f4038", "2b2b2b", "2e7d5b", "cdefdf", "121913", "1b231d"));

            presets.Add(Make("lexicon", "Lexicon",
                "Realm of Languages' colours. Argues about the wording.",
                "f0d6b4", "7a4a1f", "8a5a2b", "4a3a2a", "3a2e22", "8a5a2b", "f2e2c8", "1e1710", "241c14"));

            presets.Add(Make("resonant", "Resonant",
                "Realm of Music's colours. Hears the answer before saying it.",
                "e2bd93", "241a33", "7a3f9e", "3a2450", "2a2a33", "7a3f9e", "e6d5f5", "14101e", "1e1729"));

            presets.Add(Make("ember", "Ember",
                "Sun-bleached and quick. Answers on instinct, then checks it.",
                "d9a878", "9e3b1f", "e07a2a", "553322", "3f2e22", "e07a2a", "ffe4c2", "221610", "261a12"));

            return presets;
        }
    }
}
