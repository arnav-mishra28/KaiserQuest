using UnityEngine;
using System.Collections.Generic;
using System.Linq;

/// <summary>
/// QuestionBank — Loads and serves questions from JSON data files.
/// Supports filtering by subject, topic, and difficulty.
/// </summary>
public class QuestionBank : MonoBehaviour
{
    public static QuestionBank Instance { get; private set; }

    [Header("Question Data Files")]
    public TextAsset mathQuestionsFile;
    public TextAsset englishQuestionsFile;
    public TextAsset musicQuestionsFile;

    private QuestionDatabase database;

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;
        DontDestroyOnLoad(gameObject);

        LoadQuestions();
    }

    private void LoadQuestions()
    {
        database = new QuestionDatabase();

        // Try loading from Resources if TextAssets not assigned
        if (mathQuestionsFile == null)
            mathQuestionsFile = Resources.Load<TextAsset>("Questions/math_questions");
        if (englishQuestionsFile == null)
            englishQuestionsFile = Resources.Load<TextAsset>("Questions/english_questions");
        if (musicQuestionsFile == null)
            musicQuestionsFile = Resources.Load<TextAsset>("Questions/music_questions");

        // Parse question files
        if (mathQuestionsFile != null)
        {
            var mathData = JsonUtility.FromJson<QuestionFileData>(mathQuestionsFile.text);
            if (mathData != null && mathData.questions != null)
                database.allQuestions.AddRange(mathData.questions);
        }

        if (englishQuestionsFile != null)
        {
            var engData = JsonUtility.FromJson<QuestionFileData>(englishQuestionsFile.text);
            if (engData != null && engData.questions != null)
                database.allQuestions.AddRange(engData.questions);
        }

        if (musicQuestionsFile != null)
        {
            var musicData = JsonUtility.FromJson<QuestionFileData>(musicQuestionsFile.text);
            if (musicData != null && musicData.questions != null)
                database.allQuestions.AddRange(musicData.questions);
        }

        // If no files loaded, use built-in fallback questions
        if (database.allQuestions.Count == 0)
        {
            Debug.LogWarning("[QuestionBank] No question files found. Loading built-in questions.");
            LoadBuiltInQuestions();
        }

        Debug.Log($"[QuestionBank] Loaded {database.allQuestions.Count} questions total.");
    }

    /// <summary>
    /// Get questions filtered by subject, topic, and difficulty.
    /// </summary>
    public List<QuestionData> GetQuestions(string subject, string topic, int difficulty, int count)
    {
        var filtered = database.allQuestions
            .Where(q => string.IsNullOrEmpty(subject) || q.subject.ToLower() == subject.ToLower())
            .Where(q => string.IsNullOrEmpty(topic) || q.topic.ToLower() == topic.ToLower())
            .Where(q => q.difficulty <= difficulty + 2 && q.difficulty >= Mathf.Max(1, difficulty - 2))
            .ToList();

        // Shuffle
        for (int i = filtered.Count - 1; i > 0; i--)
        {
            int j = Random.Range(0, i + 1);
            var temp = filtered[i];
            filtered[i] = filtered[j];
            filtered[j] = temp;
        }

        return filtered.Take(count).ToList();
    }

    /// <summary>
    /// Get mixed questions from all subjects (for Silver Mountain).
    /// </summary>
    public List<QuestionData> GetMixedQuestions(int difficulty, int count)
    {
        return GetQuestions("", "", difficulty, count);
    }

    /// <summary>
    /// Get fallback questions if no data files are loaded.
    /// </summary>
    public List<QuestionData> GetFallbackQuestions(int count)
    {
        if (database.allQuestions.Count == 0)
            LoadBuiltInQuestions();

        var shuffled = new List<QuestionData>(database.allQuestions);
        for (int i = shuffled.Count - 1; i > 0; i--)
        {
            int j = Random.Range(0, i + 1);
            var temp = shuffled[i];
            shuffled[i] = shuffled[j];
            shuffled[j] = temp;
        }
        return shuffled.Take(count).ToList();
    }

    private void LoadBuiltInQuestions()
    {
        // ============ MATH - ALGEBRA ============
        AddQuestion("Mathematics", "Variables", 1, "What is the value of x if x + 3 = 7?", 
            new List<string> { "4", "3", "7", "10" }, "4");
        AddQuestion("Mathematics", "Variables", 1, "If y = 5, what is 2y?", 
            new List<string> { "10", "7", "25", "5" }, "10");
        AddQuestion("Mathematics", "Variables", 1, "Solve: a - 4 = 6", 
            new List<string> { "10", "2", "4", "6" }, "10");
        AddQuestion("Mathematics", "Variables", 2, "If x = 3 and y = 4, what is x + y?", 
            new List<string> { "7", "12", "1", "34" }, "7");
        AddQuestion("Mathematics", "Variables", 2, "What is 3x when x = 5?", 
            new List<string> { "15", "8", "35", "2" }, "15");

        AddQuestion("Mathematics", "Linear Equations", 3, "Solve: 2x + 4 = 12", 
            new List<string> { "4", "6", "8", "3" }, "4");
        AddQuestion("Mathematics", "Linear Equations", 3, "Solve: 3x - 9 = 0", 
            new List<string> { "3", "9", "0", "-3" }, "3");
        AddQuestion("Mathematics", "Linear Equations", 4, "Solve: 5x + 10 = 35", 
            new List<string> { "5", "7", "3", "25" }, "5");
        AddQuestion("Mathematics", "Linear Equations", 5, "What is the slope of y = 3x + 2?", 
            new List<string> { "3", "2", "5", "1" }, "3");
        AddQuestion("Mathematics", "Linear Equations", 5, "Find x: 4x - 8 = 2x + 6", 
            new List<string> { "7", "14", "2", "1" }, "7");

        AddQuestion("Mathematics", "Quadratics", 6, "What is x² when x = 4?", 
            new List<string> { "16", "8", "12", "64" }, "16");
        AddQuestion("Mathematics", "Quadratics", 7, "Factor: x² - 9", 
            new List<string> { "(x+3)(x-3)", "(x+9)(x-1)", "x(x-9)", "(x-3)²" }, "(x+3)(x-3)");
        AddQuestion("Mathematics", "Quadratics", 8, "Solve: x² = 25", 
            new List<string> { "±5", "5", "25", "12.5" }, "±5");
        AddQuestion("Mathematics", "Quadratics", 9, "What is the vertex of y = (x-2)² + 3?", 
            new List<string> { "(2, 3)", "(3, 2)", "(-2, 3)", "(2, -3)" }, "(2, 3)");
        AddQuestion("Mathematics", "Quadratics", 10, "Discriminant of x² + 4x + 4 = 0?", 
            new List<string> { "0", "4", "8", "16" }, "0");

        AddQuestion("Mathematics", "Functions", 7, "If f(x) = 2x + 1, what is f(3)?", 
            new List<string> { "7", "6", "9", "5" }, "7");
        AddQuestion("Mathematics", "Functions", 8, "What is the domain of f(x) = 1/x?", 
            new List<string> { "All reals except 0", "All reals", "x > 0", "x ≥ 0" }, "All reals except 0");
        AddQuestion("Mathematics", "Functions", 9, "If f(x) = x² and g(x) = x+1, what is f(g(2))?", 
            new List<string> { "9", "5", "6", "4" }, "9");
        AddQuestion("Mathematics", "Functions", 10, "What type of function is f(x) = 2^x?", 
            new List<string> { "Exponential", "Linear", "Quadratic", "Logarithmic" }, "Exponential");

        AddQuestion("Mathematics", "Graphs", 8, "What shape does y = x² make?", 
            new List<string> { "Parabola", "Line", "Circle", "Hyperbola" }, "Parabola");
        AddQuestion("Mathematics", "Graphs", 9, "Where does y = 2x cross the y-axis?", 
            new List<string> { "(0, 0)", "(0, 2)", "(2, 0)", "(1, 2)" }, "(0, 0)");

        // ============ ENGLISH ============
        AddQuestion("Languages", "Grammar", 1, "Which word is a noun?", 
            new List<string> { "Cat", "Run", "Quickly", "Beautiful" }, "Cat");
        AddQuestion("Languages", "Grammar", 1, "Which is a verb?", 
            new List<string> { "Jump", "Table", "Red", "Slowly" }, "Jump");
        AddQuestion("Languages", "Grammar", 2, "Identify the adjective: 'The tall tree fell.'", 
            new List<string> { "Tall", "Tree", "Fell", "The" }, "Tall");
        AddQuestion("Languages", "Grammar", 3, "What is the past tense of 'go'?", 
            new List<string> { "Went", "Goed", "Gone", "Going" }, "Went");
        AddQuestion("Languages", "Grammar", 4, "Which sentence is correct?", 
            new List<string> { "She doesn't like it.", "She don't like it.", "She doesn't likes it.", "She don't likes it." }, "She doesn't like it.");
        AddQuestion("Languages", "Grammar", 5, "What is a pronoun?", 
            new List<string> { "A word that replaces a noun", "A describing word", "An action word", "A linking word" }, "A word that replaces a noun");

        AddQuestion("Languages", "Vocabulary", 1, "What does 'enormous' mean?", 
            new List<string> { "Very large", "Very small", "Very fast", "Very old" }, "Very large");
        AddQuestion("Languages", "Vocabulary", 2, "What is a synonym for 'happy'?", 
            new List<string> { "Joyful", "Sad", "Angry", "Tired" }, "Joyful");
        AddQuestion("Languages", "Vocabulary", 3, "What is the antonym of 'ancient'?", 
            new List<string> { "Modern", "Old", "Historic", "Classic" }, "Modern");
        AddQuestion("Languages", "Vocabulary", 4, "What does 'ambiguous' mean?", 
            new List<string> { "Having multiple meanings", "Very clear", "Extremely large", "Moving quickly" }, "Having multiple meanings");
        AddQuestion("Languages", "Vocabulary", 5, "'Benevolent' most closely means:", 
            new List<string> { "Kind and generous", "Evil and cruel", "Lazy and slow", "Smart and quick" }, "Kind and generous");

        AddQuestion("Languages", "Writing", 5, "What should start every sentence?", 
            new List<string> { "A capital letter", "A number", "A comma", "A small letter" }, "A capital letter");
        AddQuestion("Languages", "Writing", 6, "What comes at the end of a question?", 
            new List<string> { "Question mark (?)", "Period (.)", "Exclamation (!)", "Comma (,)" }, "Question mark (?)");
        AddQuestion("Languages", "Writing", 7, "What is a paragraph?", 
            new List<string> { "A group of related sentences", "A single word", "A type of poem", "A punctuation mark" }, "A group of related sentences");
        AddQuestion("Languages", "Writing", 8, "What is a thesis statement?", 
            new List<string> { "The main argument of an essay", "The title", "A question", "A bibliography" }, "The main argument of an essay");

        // ============ MUSIC THEORY ============
        AddQuestion("Music", "Notes", 1, "How many notes are in a musical octave?", 
            new List<string> { "8", "7", "12", "5" }, "8");
        AddQuestion("Music", "Notes", 1, "Which note comes after C?", 
            new List<string> { "D", "B", "E", "A" }, "D");
        AddQuestion("Music", "Notes", 2, "What is the symbol for a sharp?", 
            new List<string> { "#", "b", "&", "%" }, "#");
        AddQuestion("Music", "Notes", 3, "How many half steps are in an octave?", 
            new List<string> { "12", "8", "7", "14" }, "12");
        AddQuestion("Music", "Notes", 4, "What clef is used for higher-pitched instruments?", 
            new List<string> { "Treble clef", "Bass clef", "Alto clef", "Tenor clef" }, "Treble clef");

        AddQuestion("Music", "Scales", 3, "How many notes are in a major scale?", 
            new List<string> { "7", "8", "5", "12" }, "7");
        AddQuestion("Music", "Scales", 4, "What is the pattern of a major scale?", 
            new List<string> { "W-W-H-W-W-W-H", "W-H-W-W-H-W-W", "H-W-W-H-W-W-W", "W-W-W-H-W-W-H" }, "W-W-H-W-W-W-H");
        AddQuestion("Music", "Scales", 5, "What scale has no sharps or flats?", 
            new List<string> { "C major", "G major", "D major", "F major" }, "C major");

        AddQuestion("Music", "Chords", 4, "A major chord consists of:", 
            new List<string> { "Root, major 3rd, perfect 5th", "Root, minor 3rd, perfect 5th", "Root, perfect 4th, perfect 5th", "Root, major 2nd, perfect 5th" }, "Root, major 3rd, perfect 5th");
        AddQuestion("Music", "Chords", 5, "How many notes in a triad?", 
            new List<string> { "3", "2", "4", "5" }, "3");
        AddQuestion("Music", "Chords", 6, "What makes a chord 'minor'?", 
            new List<string> { "A flatted 3rd", "A sharped 5th", "A flatted 7th", "A sharped root" }, "A flatted 3rd");

        AddQuestion("Music", "Rhythm", 2, "How many beats does a whole note get?", 
            new List<string> { "4", "2", "1", "8" }, "4");
        AddQuestion("Music", "Rhythm", 3, "What does 4/4 time mean?", 
            new List<string> { "4 beats per measure", "4 measures per song", "4 notes per beat", "4 rests per measure" }, "4 beats per measure");
        AddQuestion("Music", "Rhythm", 4, "How many beats does a half note get?", 
            new List<string> { "2", "1", "4", "0.5" }, "2");
        AddQuestion("Music", "Rhythm", 5, "What is syncopation?", 
            new List<string> { "Accenting off-beats", "Playing very fast", "Playing very slow", "Repeating a note" }, "Accenting off-beats");
    }

    private void AddQuestion(string subject, string topic, int difficulty, string question, List<string> answers, string correct)
    {
        database.allQuestions.Add(new QuestionData
        {
            subject = subject,
            topic = topic,
            difficulty = difficulty,
            question = question,
            answers = answers,
            correctAnswer = correct
        });
    }
}

// ============================================================
// QUESTION DATA STRUCTURES
// ============================================================

[System.Serializable]
public class QuestionData
{
    public string subject;
    public string topic;
    public int difficulty;
    public string question;
    public List<string> answers;
    public string correctAnswer;
    public string explanation;
    public string hint;
}

[System.Serializable]
public class QuestionFileData
{
    public List<QuestionData> questions;
}

[System.Serializable]
public class QuestionDatabase
{
    public List<QuestionData> allQuestions = new List<QuestionData>();
}
