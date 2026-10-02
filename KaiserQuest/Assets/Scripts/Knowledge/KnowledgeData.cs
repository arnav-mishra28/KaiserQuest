using System;
using System.Collections.Generic;

namespace KaiserQuest.Knowledge
{
    /// <summary>
    /// Serialisable mirrors of the JSON the content pipeline exports.
    ///
    /// These are separate from the older QuestionData in Battle/QuestionBank.cs on
    /// purpose. That type loads the legacy battle banks, which key on display names
    /// ("Mathematics" / "Variables"); this one loads the verified story bank, which
    /// keys on ids ("math" / "variables"). Keeping them apart means neither path
    /// can silently break the other.
    ///
    /// Every field name here must match the exported JSON exactly: Unity's
    /// JsonUtility matches on field name and leaves anything it cannot match at its
    /// default value, without warning.
    /// </summary>
    [Serializable]
    public class ConceptData
    {
        public string id;
        public string name;
        public string domain;
        public string realm;
        public List<string> prereqs = new List<string>();
        public List<string> keywords = new List<string>();
        public int level = 1;
    }

    [Serializable]
    public class DomainData
    {
        public string id;
        public string name;
        public string realm;
        public List<ConceptData> concepts = new List<ConceptData>();
    }

    [Serializable]
    public class RealmData
    {
        public string id;
        public string name;
        public string section;
        public string sigil;
        public string accent;
        public string tagline;
        public List<DomainData> domains = new List<DomainData>();
    }

    [Serializable]
    public class GraphData
    {
        public int version;
        public List<RealmData> realms = new List<RealmData>();
    }

    [Serializable]
    public class MisconceptionData
    {
        public string id;
        public string name;
        public string concept;
        public string pattern;
        public string remedy;
        public List<string> drills = new List<string>();
        public int severity = 3;

        public bool IsGeneral
        {
            get { return concept == "*"; }
        }
    }

    [Serializable]
    public class MisconceptionFile
    {
        public List<MisconceptionData> misconceptions = new List<MisconceptionData>();
    }

    [Serializable]
    public class MisconceptionTag
    {
        public string distractor;
        public string misconceptionId;
    }

    [Serializable]
    public class BankQuestion
    {
        public string id;
        public string subject;
        public string topic;
        public string concept;
        public string question;
        public List<string> options = new List<string>();
        public string correctAnswer;
        public string explanation;
        public int difficulty = 3;
        public float expectedTimeMs;
        public List<MisconceptionTag> misconceptionTags = new List<MisconceptionTag>();

        /// <summary>
        /// The misconception this distractor encodes, or null. The generator that
        /// built the wrong option knows which broken rule produces it, so this is an
        /// exact answer rather than a guess.
        /// </summary>
        public string MisconceptionFor(string chosen)
        {
            if (string.IsNullOrEmpty(chosen) || misconceptionTags == null) return null;
            for (int i = 0; i < misconceptionTags.Count; i++)
            {
                if (misconceptionTags[i] != null && misconceptionTags[i].distractor == chosen)
                    return misconceptionTags[i].misconceptionId;
            }
            return null;
        }

        public bool IsCorrect(string chosen)
        {
            if (chosen == null) return false;
            if (chosen.Trim() == (correctAnswer ?? string.Empty).Trim()) return true;
            float a, b;
            if (float.TryParse(chosen.Trim(), out a) &&
                float.TryParse((correctAnswer ?? string.Empty).Trim(), out b))
            {
                return Math.Abs(a - b) < 1e-6f;
            }
            return false;
        }
    }

    [Serializable]
    public class BankFile
    {
        public string subject;
        public int count;
        public List<BankQuestion> questions = new List<BankQuestion>();
    }

    /// <summary>Which bank file(s) hold one realm's questions.</summary>
    [Serializable]
    public class RealmBankEntry
    {
        public string realm;
        public List<string> subjects = new List<string>();
    }

    /// <summary>
    /// The realm-to-bank mapping, exported by the content pipeline as
    /// `Knowledge/banks.json`.
    ///
    /// Banks are named by subject ('math') and campaigns are played by realm
    /// ('algebra'), and the client cannot work out one from the other. The game
    /// shipped once looking for `bank_algebra.json`, finding nothing, and refusing
    /// every trial for want of questions; this file is what stops that recurring —
    /// the mapping is content, so the content declares it.
    /// </summary>
    [Serializable]
    public class BankMap
    {
        public List<RealmBankEntry> realms = new List<RealmBankEntry>();

        public List<string> SubjectsFor(string realmId)
        {
            if (string.IsNullOrEmpty(realmId)) return null;

            for (int i = 0; i < realms.Count; i++)
            {
                if (realms[i] != null && realms[i].realm == realmId) return realms[i].subjects;
            }
            return null;
        }
    }

    /// <summary>Persisted knowledge state for one concept.</summary>
    [Serializable]
    public class ConceptKnowledgeData
    {
        public string concept;
        public float pKnown;

        public int attempts;
        public int correct;
        public int hints;
        public int fastErrors;

        public double lastPracticed;
        public double firstPracticed;
        public int difficultyCeiling;
        public int referenceLevel = 2;
        public float stability;

        public float pInit = BKTParams.DefaultPInit;
        public float pLearn = BKTParams.DefaultPLearn;
        public float pGuess = BKTParams.DefaultPGuess;
        public float pSlip = BKTParams.DefaultPSlip;
    }

    /// <summary>Persisted record of one answered question.</summary>
    [Serializable]
    public class AttemptData
    {
        public string concept;
        public string questionId;
        public bool correct;
        public int difficulty = 2;
        public float responseTimeMs;
        public float expectedTimeMs;
        public int hintsUsed;
        public int tries = 1;
        public string chosen;
        public string correctAnswer;
        public string misconceptionId;
        public string domain;
        public string realm;
        public double timestamp;
    }
}
