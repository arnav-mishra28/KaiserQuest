// SubjectDB.cs — All Subjects, Branches, Questions, Gym Leaders
using UnityEngine;
using System.Collections.Generic;

[System.Serializable]
public class QuestionData
{
    public string   topic;
    public int      difficulty;
    public string   q;
    public string[] opts;
    public int      ans;
    public string   explain;
}

[System.Serializable]
public class GymLeaderData
{
    public string   name;
    public string   title;
    public string   badgeName;
    public int      gymNumber;
    public int      act;
    public int      xpReward;
    public Color    color;
    public string   world;
    public string[] intro;
    public string[] win;
    public string[] lose;
}

[System.Serializable]
public class BranchInfo
{
    public string name;
    public string icon;
    public Color  color;
    public string desc;
}

[System.Serializable]
public class SubjectInfo
{
    public string name;
    public string icon;
    public Color  color;
    public string desc;
    public Dictionary<string, BranchInfo> branches;
}

public static class SubjectDB
{
    // ── Subject / Branch Catalog ──────────────────────────────────────────────
    public static readonly Dictionary<string, SubjectInfo> Subjects = new()
    {
        ["math"] = new SubjectInfo {
            name="Mathematics", icon="∑", color=new Color(0.12f,0.38f,0.82f),
            desc="Equations are enemies.\nSolve them to survive!",
            branches = new() {
                ["algebra"]  = new BranchInfo{name="Algebra",  icon="x=", color=new Color(0.12f,0.38f,0.82f), desc="Variables & Equations"},
                ["geometry"] = new BranchInfo{name="Geometry", icon="△",  color=new Color(0.12f,0.63f,0.38f), desc="Shapes & Proofs"},
                ["calculus"] = new BranchInfo{name="Calculus", icon="∫",  color=new Color(0.63f,0.25f,0.12f), desc="Limits & Derivatives"},
            }
        },
        ["languages"] = new SubjectInfo {
            name="Languages", icon="A", color=new Color(0.75f,0.44f,0.06f),
            desc="Words shape reality.\nMaster the power of language!",
            branches = new() {
                ["english"] = new BranchInfo{name="English", icon="En", color=new Color(0.75f,0.44f,0.06f), desc="Grammar & Writing"},
                ["spanish"] = new BranchInfo{name="Spanish", icon="Es", color=new Color(0.75f,0.25f,0.25f), desc="El Español"},
                ["french"]  = new BranchInfo{name="French",  icon="Fr", color=new Color(0.25f,0.38f,0.75f), desc="Le Français"},
            }
        },
        ["music"] = new SubjectInfo {
            name="Music", icon="♪", color=new Color(0.50f,0.12f,0.75f),
            desc="Notes are creatures.\nChords are your power!",
            branches = new() {
                ["theory"]      = new BranchInfo{name="Theory",      icon="♩", color=new Color(0.50f,0.12f,0.75f), desc="Staff, Notes & Scales"},
                ["composition"] = new BranchInfo{name="Composition", icon="♫", color=new Color(0.75f,0.25f,0.56f), desc="Chords & Harmony"},
                ["history"]     = new BranchInfo{name="History",     icon="📜", color=new Color(0.12f,0.38f,0.63f), desc="Eras & Composers"},
            }
        },
    };

    // ── Get Gym Leader ────────────────────────────────────────────────────────
    public static GymLeaderData GetGymLeader(string subject, string branch, int gymNum)
    {
        string key = subject + ":" + branch;
        if (_leaders.TryGetValue(key, out var leaderMap) && leaderMap.TryGetValue(gymNum, out var leader))
            return leader;
        return GenericLeader(subject, branch, gymNum);
    }

    static GymLeaderData GenericLeader(string subject, string branch, int gymNum)
    {
        int act = gymNum <= 5 ? 1 : gymNum <= 12 ? 2 : 3;
        string[] diffNames = { "", "Easy","Easy","Medium","Medium","Hard","Hard","Hard","Expert","Expert","Expert","Expert","Expert","Master","Master","Master","Master","Grandmaster","Grandmaster","Grandmaster","Legend" };
        var branchInfo = Subjects.TryGetValue(subject, out var si) && si.branches.TryGetValue(branch, out var bi) ? bi : new BranchInfo{name=branch};
        var col = Subjects.TryGetValue(subject, out var si2) ? si2.color : Color.white;
        return new GymLeaderData {
            name = "Gym Leader " + gymNum,
            title = "Guardian of " + branchInfo.name + " Gym " + gymNum,
            badgeName = branchInfo.name + " Badge " + gymNum,
            gymNumber = gymNum, act = act,
            xpReward = 200 + gymNum * 50, color = col, world = subject + ":" + branch,
            intro = new[] { "Gym " + gymNum + " — " + diffNames[Mathf.Clamp(gymNum,1,20)] + "!", "I am the Guardian of " + branchInfo.name + " Gym " + gymNum + ".", (5 + Mathf.Min(gymNum, 7)) + " questions. Begin!" },
            win  = new[] { "★ " + branchInfo.name + " Badge " + gymNum + " earned! ★", "You grow stronger." },
            lose = new[] { "Defeated! Study more.", "Return when ready." }
        };
    }

    // ── Get Questions ─────────────────────────────────────────────────────────
    public static List<QuestionData> GetQuestions(string subject, string branch)
    {
        string key = subject + ":" + branch;
        if (_questions.TryGetValue(key, out var q)) return q;
        if (_questions.TryGetValue(subject + ":algebra", out var fallback)) return fallback;
        return new List<QuestionData>();
    }

    public static List<QuestionData> GetGymQuestions(string subject, string branch, int gymNum, int count)
    {
        var all = GetQuestions(subject, branch);
        if (all.Count == 0) return all;
        int minDiff = Mathf.Max(1, (gymNum - 1) / 5);
        var filtered = all.FindAll(q => q.difficulty >= minDiff);
        if (filtered.Count < count) filtered = new List<QuestionData>(all);
        return AdaptiveAI.AdaptiveSelect(filtered, subject + ":" + branch, GameManager.Instance.Level, count);
    }

    // ── Leader data ───────────────────────────────────────────────────────────
    static readonly Dictionary<string, Dictionary<int, GymLeaderData>> _leaders = new()
    {
        ["math:algebra"] = new() {
            [1]  = new GymLeaderData{name="Prof. Sprout", title="Teacher of Pallet Grove", badgeName="Seedling Badge", gymNumber=1, act=1, xpReward=200, color=new Color(0.38f,0.69f,0.19f), world="math:algebra", intro=new[]{"Welcome! I am Prof. Sprout.","Variables: where algebra begins.","3 questions. Let's go!"}, win=new[]{"Seedling Badge is yours!"}, lose=new[]{"Practice more!"}},
            [2]  = new GymLeaderData{name="Prof. Axiom",  title="Guardian of Variable Citadel", badgeName="Variable Badge", gymNumber=2, act=1, xpReward=300, color=new Color(0.12f,0.38f,0.82f), world="math:algebra", intro=new[]{"I am Professor Axiom!","Variables are my domain.","5 questions. Begin!"}, win=new[]{"Variable Badge!"}, lose=new[]{"Study variables!"}},
            [3]  = new GymLeaderData{name="Magistra Lin", title="Master of Equations", badgeName="Equation Badge", gymNumber=3, act=1, xpReward=350, color=new Color(0.06f,0.63f,0.38f), world="math:algebra", intro=new[]{"Linear equations rule here.","5 questions!"}, win=new[]{"Equation Badge!"}, lose=new[]{"Practice equations!"}},
            [4]  = new GymLeaderData{name="Elder Quadrix", title="Sage of Functions", badgeName="Function Badge", gymNumber=4, act=1, xpReward=400, color=new Color(0.75f,0.25f,0.12f), world="math:algebra", intro=new[]{"Functions reveal the universe.","6 questions!"}, win=new[]{"Function Badge!"}, lose=new[]{"Study functions!"}},
            [5]  = new GymLeaderData{name="Elder Crossway", title="Sage of the Crossroads", badgeName="Crossroads Badge", gymNumber=5, act=1, xpReward=450, color=new Color(0.50f,0.38f,0.12f), world="math:algebra", intro=new[]{"ACT 1 FINALE.","Are you ready? 6 questions!"}, win=new[]{"ACT 1 COMPLETE! Crossroads Badge!"}, lose=new[]{"Train harder!"}},
        }
    };

    // ── Question Banks ────────────────────────────────────────────────────────
    static readonly Dictionary<string, List<QuestionData>> _questions = new()
    {
        ["math:algebra"] = new() {
            new(){topic="variables",difficulty=1,q="What does a VARIABLE represent?", opts=new[]{"A fixed number","A symbol for an unknown","A math operation","An equation type"}, ans=1, explain="Variables (x,y,n) represent\nunknown or changing values."},
            new(){topic="variables",difficulty=1,q="If  x = 5,  what is  x + 3?", opts=new[]{"5","3","8","15"}, ans=2, explain="x + 3 = 5 + 3 = 8"},
            new(){topic="variables",difficulty=1,q="Solve:  x + 4 = 9", opts=new[]{"x=4","x=5","x=13","x=2"}, ans=1, explain="Subtract 4: x = 9 - 4 = 5"},
            new(){topic="variables",difficulty=1,q="Which is a VARIABLE?", opts=new[]{"7","3.14","y","100"}, ans=2, explain="Letters like y,x,z are variables."},
            new(){topic="variables",difficulty=1,q="If y=3x and x=4, find y.", opts=new[]{"7","34","12","1"}, ans=2, explain="y = 3 × 4 = 12"},
            new(){topic="variables",difficulty=1,q="If x=2, what is 5x?", opts=new[]{"7","10","52","25"}, ans=1, explain="5x = 5×2 = 10"},
            new(){topic="variables",difficulty=1,q="Solve:  x - 3 = 7", opts=new[]{"x=4","x=10","x=3","x=21"}, ans=1, explain="x = 7 + 3 = 10"},
            new(){topic="linear",difficulty=2,q="Solve:  2x = 14", opts=new[]{"x=7","x=12","x=28","x=2"}, ans=0, explain="x = 14÷2 = 7"},
            new(){topic="linear",difficulty=2,q="Solve:  3x + 1 = 10", opts=new[]{"x=3","x=4","x=9","x=11"}, ans=0, explain="3x=9, x=3"},
            new(){topic="linear",difficulty=2,q="Solve:  5x - 5 = 20", opts=new[]{"x=3","x=4","x=5","x=25"}, ans=2, explain="5x=25, x=5"},
            new(){topic="linear",difficulty=2,q="Slope of y = 3x + 2?", opts=new[]{"2","3","x","0"}, ans=1, explain="y=mx+b: slope m=3"},
            new(){topic="linear",difficulty=2,q="Solve:  x + 8 = 2x - 4", opts=new[]{"x=4","x=12","x=6","x=2"}, ans=1, explain="-x=-12, x=12"},
            new(){topic="functions",difficulty=3,q="If f(x)=2x+1, find f(3).", opts=new[]{"5","6","7","8"}, ans=2, explain="f(3) = 2(3)+1 = 7"},
            new(){topic="functions",difficulty=3,q="A FUNCTION maps each input to...", opts=new[]{"Zero outputs","Exactly one output","Two outputs","Many"}, ans=1, explain="One input → exactly one output."},
            new(){topic="functions",difficulty=3,q="If g(x)=x², find g(4).", opts=new[]{"8","12","16","4"}, ans=2, explain="g(4) = 4² = 16"},
            new(){topic="quadratic",difficulty=4,q="Standard form of a quadratic?", opts=new[]{"y=mx+b","ax²+bx+c=0","x=a+b","y=x+c"}, ans=1, explain="ax²+bx+c=0 where a≠0."},
            new(){topic="quadratic",difficulty=4,q="Solve:  x² = 9", opts=new[]{"x=3","x=±3","x=4.5","x=9"}, ans=1, explain="x=±√9=±3"},
            new(){topic="quadratic",difficulty=4,q="Factor:  x²+5x+6", opts=new[]{"(x+1)(x+6)","(x+2)(x+3)","(x-2)(x-3)","(x+3)(x+3)"}, ans=1, explain="(x+2)(x+3)=x²+5x+6 ✓"},
        },
        ["languages:english"] = new() {
            new(){topic="nouns",difficulty=1,q="What is a NOUN?", opts=new[]{"Action word","Describing word","Person/place/thing/idea","Connecting word"}, ans=2, explain="Nouns name things."},
            new(){topic="nouns",difficulty=1,q="Find the NOUN: 'The brave knight slept.'", opts=new[]{"brave","slept","The","knight"}, ans=3, explain="'knight' names a person."},
            new(){topic="nouns",difficulty=1,q="'London' is a...?", opts=new[]{"Common noun","Proper noun","Abstract noun","Verb"}, ans=1, explain="London = specific place → proper noun."},
            new(){topic="nouns",difficulty=1,q="Which is ABSTRACT?", opts=new[]{"Table","London","Freedom","River"}, ans=2, explain="Abstract = ideas you cannot touch."},
            new(){topic="verbs",difficulty=2,q="A VERB is a...", opts=new[]{"Describing word","Naming word","Action or state word","Connecting"}, ans=2, explain="Verbs express actions or states."},
            new(){topic="verbs",difficulty=2,q="Past tense of 'eat'?", opts=new[]{"eated","eat","ate","eating"}, ans=2, explain="eat → ate (irregular verb)"},
            new(){topic="verbs",difficulty=2,q="Future tense of 'run'?", opts=new[]{"ran","runs","will run","running"}, ans=2, explain="Future = will + base verb."},
            new(){topic="adjectives",difficulty=2,q="Comparative of 'big'?", opts=new[]{"most big","bigger","biggest","very big"}, ans=1, explain="big → bigger → biggest"},
            new(){topic="sentences",difficulty=3,q="A complete sentence needs...", opts=new[]{"Only noun","Only verb","Subject AND predicate","Adjective+noun"}, ans=2, explain="Subject (who) + predicate (what)."},
            new(){topic="sentences",difficulty=3,q="Which is COMPOUND?", opts=new[]{"She ran.","Dog barked.","He sang and she danced.","Morning."}, ans=2, explain="Two clauses joined by conjunction."},
            new(){topic="advanced",difficulty=4,q="A GERUND is...", opts=new[]{"A noun","A verb used as noun","A describing word","A clause"}, ans=1, explain="Gerund = verb+-ing as noun."},
        },
        ["music:theory"] = new() {
            new(){topic="staff",difficulty=1,q="Lines on a musical staff?", opts=new[]{"3","4","5","6"}, ans=2, explain="Standard staff = 5 lines."},
            new(){topic="staff",difficulty=1,q="Treble clef marks...", opts=new[]{"Loud notes","Higher note range","Tempo","Key signature"}, ans=1, explain="Treble clef = higher notes."},
            new(){topic="staff",difficulty=1,q="Spaces on treble clef spell?", opts=new[]{"EGBDF","FACE","ACEG","BDFA"}, ans=1, explain="4 spaces = F-A-C-E bottom to top."},
            new(){topic="notes",difficulty=1,q="A WHOLE NOTE gets how many beats?", opts=new[]{"1","2","3","4"}, ans=3, explain="Whole=4, Half=2, Quarter=1."},
            new(){topic="notes",difficulty=1,q="A QUARTER NOTE gets how many beats?", opts=new[]{"1","2","3","4"}, ans=0, explain="Quarter note = 1 beat."},
            new(){topic="chords",difficulty=2,q="A MAJOR chord sounds...", opts=new[]{"Sad","Bright/happy","Tense","Silent"}, ans=1, explain="Major chords sound bright/happy."},
            new(){topic="chords",difficulty=2,q="C-E-G forms a...", opts=new[]{"C minor","G major","C major triad","A minor"}, ans=2, explain="C-E-G = C major triad."},
            new(){topic="time",difficulty=2,q="4/4 time: beats per measure?", opts=new[]{"2","3","4","8"}, ans=2, explain="Top number = beats per bar."},
            new(){topic="scales",difficulty=3,q="A MAJOR SCALE has how many notes?", opts=new[]{"5","6","7","8"}, ans=3, explain="Major scale = 8 notes."},
            new(){topic="scales",difficulty=3,q="Semitones in an octave?", opts=new[]{"6","8","10","12"}, ans=3, explain="12 semitones per octave."},
            new(){topic="scales",difficulty=4,q="C major scale notes?", opts=new[]{"All black keys","C-D-E-F-G-A-B","C-D-Eb-F-G","C-E-G-B-D"}, ans=1, explain="C major = all white keys."},
        },
        ["languages:spanish"] = new() {
            new(){topic="basics",difficulty=1,q="'Hola' means...", opts=new[]{"Goodbye","Hello","Please","Thank you"}, ans=1, explain="Hola = Hello in Spanish."},
            new(){topic="basics",difficulty=1,q="'Gracias' means...", opts=new[]{"Please","Goodbye","Thank you","Sorry"}, ans=2, explain="Gracias = Thank you."},
            new(){topic="basics",difficulty=1,q="'Buenos días' means...", opts=new[]{"Good night","Good morning","Good afternoon","Hello"}, ans=1, explain="Buenos días = Good morning."},
            new(){topic="verbs",difficulty=2,q="'Yo hablo' means...", opts=new[]{"I listen","I speak","You speak","He speaks"}, ans=1, explain="Yo=I, hablo=speak (present)."},
            new(){topic="nouns",difficulty=2,q="'El libro' means...", opts=new[]{"The table","The book","The house","The car"}, ans=1, explain="Libro = book."},
            new(){topic="adjectives",difficulty=3,q="'Rojo' means...", opts=new[]{"Blue","Green","Red","Yellow"}, ans=2, explain="Rojo = Red."},
            new(){topic="sentences",difficulty=3,q="'¿Cómo te llamas?' means...", opts=new[]{"How are you?","Where from?","What is your name?","How old?"}, ans=2, explain="Cómo te llamas = What is your name?"},
        },
    };
}
