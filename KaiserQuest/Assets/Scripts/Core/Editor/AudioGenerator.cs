using UnityEngine;
using System.IO;
#if UNITY_EDITOR
using UnityEditor;
#endif

/// <summary>
/// AudioGenerator — Generates retro-style 8-bit sound effects as WAV files.
/// Creates all the sound effects needed for KaiserQuest: menu clicks, battle sounds,
/// victory/defeat jingles, level up, badge earned, dialog beeps, and background music loops.
/// Run from menu: KaiserQuest > Generate Audio
/// </summary>
public class AudioGenerator
{
    static int sampleRate = 22050; // Low sample rate for retro feel
    static string audioPath = "Assets/Audio";

#if UNITY_EDITOR
    [MenuItem("KaiserQuest/Generate Audio")]
    public static void GenerateAll()
    {
        string fullPath = Path.Combine(Application.dataPath.Replace("Assets", ""), audioPath);
        if (!Directory.Exists(fullPath)) Directory.CreateDirectory(fullPath);
        string sfxPath = fullPath + "/SFX";
        string musicPath = fullPath + "/Music";
        if (!Directory.Exists(sfxPath)) Directory.CreateDirectory(sfxPath);
        if (!Directory.Exists(musicPath)) Directory.CreateDirectory(musicPath);

        // Sound Effects
        GenerateMenuSelect(sfxPath);
        GenerateMenuConfirm(sfxPath);
        GenerateMenuBack(sfxPath);
        GenerateDialogBeep(sfxPath);
        GenerateCorrectAnswer(sfxPath);
        GenerateWrongAnswer(sfxPath);
        GenerateHitDamage(sfxPath);
        GenerateLevelUp(sfxPath);
        GenerateBadgeEarned(sfxPath);
        GenerateVictoryJingle(sfxPath);
        GenerateDefeatJingle(sfxPath);
        GenerateBattleStart(sfxPath);
        GenerateHealSound(sfxPath);
        GenerateFootstep(sfxPath);
        GenerateEncounterAlert(sfxPath);

        // Music Loops
        GenerateOverworldMusic(musicPath);
        GenerateBattleMusic(musicPath);
        GenerateGymMusic(musicPath);
        GenerateMenuMusic(musicPath);

        AssetDatabase.Refresh();
        Debug.Log("[AudioGenerator] All audio generated!");
    }
#endif

    // ================================================================
    // SOUND EFFECTS
    // ================================================================

    static void GenerateMenuSelect(string path)
    {
        float[] samples = new float[sampleRate / 8]; // 0.125s
        for (int i = 0; i < samples.Length; i++)
        {
            float t = (float)i / sampleRate;
            float freq = 800 + t * 2000;
            samples[i] = Mathf.Sin(2 * Mathf.PI * freq * t) * (1f - t * 8f) * 0.4f;
        }
        SaveWAV(path + "/menu_select.wav", samples);
    }

    static void GenerateMenuConfirm(string path)
    {
        float[] samples = new float[sampleRate / 4]; // 0.25s
        for (int i = 0; i < samples.Length; i++)
        {
            float t = (float)i / sampleRate;
            float freq = 440 + t * 880;
            float env = Mathf.Max(0, 1f - t * 4f);
            samples[i] = (Mathf.Sin(2 * Mathf.PI * freq * t) + 
                          Mathf.Sin(2 * Mathf.PI * freq * 1.5f * t) * 0.3f) * env * 0.35f;
        }
        SaveWAV(path + "/menu_confirm.wav", samples);
    }

    static void GenerateMenuBack(string path)
    {
        float[] samples = new float[sampleRate / 6]; // ~0.17s
        for (int i = 0; i < samples.Length; i++)
        {
            float t = (float)i / sampleRate;
            float freq = 600 - t * 1200;
            freq = Mathf.Max(freq, 100);
            float env = Mathf.Max(0, 1f - t * 6f);
            samples[i] = Mathf.Sin(2 * Mathf.PI * freq * t) * env * 0.3f;
        }
        SaveWAV(path + "/menu_back.wav", samples);
    }

    static void GenerateDialogBeep(string path)
    {
        float[] samples = new float[sampleRate / 20]; // 0.05s
        for (int i = 0; i < samples.Length; i++)
        {
            float t = (float)i / sampleRate;
            samples[i] = (Mathf.Sin(2 * Mathf.PI * 1200 * t) > 0 ? 1f : -1f) * 
                         Mathf.Max(0, 1f - t * 20f) * 0.15f; // Square wave, very short
        }
        SaveWAV(path + "/dialog_beep.wav", samples);
    }

    static void GenerateCorrectAnswer(string path)
    {
        int len = sampleRate / 2; // 0.5s
        float[] samples = new float[len];
        for (int i = 0; i < len; i++)
        {
            float t = (float)i / sampleRate;
            float freq1 = (i < len / 3) ? 523.25f : (i < len * 2 / 3) ? 659.25f : 783.99f; // C5-E5-G5
            float env = Mathf.Max(0, 1f - t * 2f) * 0.8f;
            samples[i] = Mathf.Sin(2 * Mathf.PI * freq1 * t) * env * 0.35f;
        }
        SaveWAV(path + "/correct_answer.wav", samples);
    }

    static void GenerateWrongAnswer(string path)
    {
        int len = sampleRate / 3;
        float[] samples = new float[len];
        for (int i = 0; i < len; i++)
        {
            float t = (float)i / sampleRate;
            float freq = 200 - t * 300;
            freq = Mathf.Max(freq, 80);
            float env = Mathf.Max(0, 1f - t * 3f);
            // Buzzy square wave
            samples[i] = (Mathf.Sin(2 * Mathf.PI * freq * t) > 0 ? 1f : -1f) * env * 0.25f;
        }
        SaveWAV(path + "/wrong_answer.wav", samples);
    }

    static void GenerateHitDamage(string path)
    {
        int len = sampleRate / 5;
        float[] samples = new float[len];
        System.Random rng = new System.Random(42);
        for (int i = 0; i < len; i++)
        {
            float t = (float)i / sampleRate;
            float env = Mathf.Max(0, 1f - t * 5f);
            // Noise burst + low freq
            float noise = (float)(rng.NextDouble() * 2 - 1);
            samples[i] = (noise * 0.5f + Mathf.Sin(2 * Mathf.PI * 100 * t)) * env * 0.3f;
        }
        SaveWAV(path + "/hit_damage.wav", samples);
    }

    static void GenerateLevelUp(string path)
    {
        int len = sampleRate; // 1s
        float[] samples = new float[len];
        for (int i = 0; i < len; i++)
        {
            float t = (float)i / sampleRate;
            // Rising arpeggio C-E-G-C
            float freq;
            if (t < 0.2f) freq = 523.25f;       // C5
            else if (t < 0.4f) freq = 659.25f;   // E5
            else if (t < 0.6f) freq = 783.99f;   // G5
            else freq = 1046.5f;                   // C6

            float env = Mathf.Max(0, 1f - (t % 0.2f) * 3f) * Mathf.Max(0, 1f - t * 0.5f);
            samples[i] = (Mathf.Sin(2 * Mathf.PI * freq * t) + 
                          Mathf.Sin(2 * Mathf.PI * freq * 2f * t) * 0.2f) * env * 0.3f;
        }
        SaveWAV(path + "/level_up.wav", samples);
    }

    static void GenerateBadgeEarned(string path)
    {
        int len = (int)(sampleRate * 1.5f); // 1.5s
        float[] samples = new float[len];
        float[] melody = { 523.25f, 587.33f, 659.25f, 783.99f, 1046.5f, 1046.5f };
        float noteLen = 1.5f / melody.Length;

        for (int i = 0; i < len; i++)
        {
            float t = (float)i / sampleRate;
            int noteIdx = Mathf.Min((int)(t / noteLen), melody.Length - 1);
            float noteT = (t % noteLen) / noteLen;
            float env = Mathf.Max(0, 1f - noteT * 2f) * Mathf.Max(0, 1f - t * 0.3f);
            samples[i] = (Mathf.Sin(2 * Mathf.PI * melody[noteIdx] * t) +
                          Mathf.Sin(2 * Mathf.PI * melody[noteIdx] * 1.5f * t) * 0.3f) * env * 0.3f;
        }
        SaveWAV(path + "/badge_earned.wav", samples);
    }

    static void GenerateVictoryJingle(string path)
    {
        int len = sampleRate * 2; // 2s
        float[] samples = new float[len];
        // Classic victory fanfare
        float[] notes = { 392f, 392f, 392f, 523.25f, 466.16f, 523.25f, 659.25f, 783.99f };
        float noteLen = 2f / notes.Length;

        for (int i = 0; i < len; i++)
        {
            float t = (float)i / sampleRate;
            int noteIdx = Mathf.Min((int)(t / noteLen), notes.Length - 1);
            float noteT = (t % noteLen) / noteLen;
            float env = Mathf.Max(0, 1f - noteT * 1.5f);
            samples[i] = (Mathf.Sin(2 * Mathf.PI * notes[noteIdx] * t) * 0.7f +
                          Mathf.Sin(2 * Mathf.PI * notes[noteIdx] * 2f * t) * 0.15f +
                          Mathf.Sin(2 * Mathf.PI * notes[noteIdx] * 3f * t) * 0.08f) * env * 0.3f;
        }
        SaveWAV(path + "/victory_jingle.wav", samples);
    }

    static void GenerateDefeatJingle(string path)
    {
        int len = (int)(sampleRate * 1.5f);
        float[] samples = new float[len];
        float[] notes = { 440f, 415.3f, 392f, 349.23f, 329.63f, 293.66f };
        float noteLen = 1.5f / notes.Length;

        for (int i = 0; i < len; i++)
        {
            float t = (float)i / sampleRate;
            int noteIdx = Mathf.Min((int)(t / noteLen), notes.Length - 1);
            float noteT = (t % noteLen) / noteLen;
            float env = Mathf.Max(0, 1f - noteT * 1.5f) * Mathf.Max(0, 1f - t * 0.4f);
            samples[i] = Mathf.Sin(2 * Mathf.PI * notes[noteIdx] * t) * env * 0.25f;
        }
        SaveWAV(path + "/defeat_jingle.wav", samples);
    }

    static void GenerateBattleStart(string path)
    {
        int len = sampleRate / 2;
        float[] samples = new float[len];
        for (int i = 0; i < len; i++)
        {
            float t = (float)i / sampleRate;
            float freq = 200 + t * 1600; // Rising sweep
            float env = Mathf.Max(0, 1f - t * 2f);
            samples[i] = (Mathf.Sin(2 * Mathf.PI * freq * t) > 0 ? 1f : -1f) * env * 0.25f;
        }
        SaveWAV(path + "/battle_start.wav", samples);
    }

    static void GenerateHealSound(string path)
    {
        int len = sampleRate / 2;
        float[] samples = new float[len];
        for (int i = 0; i < len; i++)
        {
            float t = (float)i / sampleRate;
            float freq = 600 + Mathf.Sin(t * 20f) * 200;
            float env = Mathf.Max(0, 1f - t * 2f);
            samples[i] = Mathf.Sin(2 * Mathf.PI * freq * t) * env * 0.2f;
        }
        SaveWAV(path + "/heal.wav", samples);
    }

    static void GenerateFootstep(string path)
    {
        int len = sampleRate / 15; // very short
        float[] samples = new float[len];
        System.Random rng = new System.Random(11);
        for (int i = 0; i < len; i++)
        {
            float t = (float)i / sampleRate;
            float env = Mathf.Max(0, 1f - t * 15f);
            samples[i] = (float)(rng.NextDouble() * 2 - 1) * env * 0.15f;
        }
        SaveWAV(path + "/footstep.wav", samples);
    }

    static void GenerateEncounterAlert(string path)
    {
        int len = sampleRate / 3;
        float[] samples = new float[len];
        for (int i = 0; i < len; i++)
        {
            float t = (float)i / sampleRate;
            float freq = (i < len / 2) ? 880 : 1108;
            float env = Mathf.Max(0, 1f - (t % 0.17f) * 4f);
            samples[i] = Mathf.Sin(2 * Mathf.PI * freq * t) * env * 0.3f;
        }
        SaveWAV(path + "/encounter_alert.wav", samples);
    }

    // ================================================================
    // MUSIC LOOPS (simple 8-bit style)
    // ================================================================

    static void GenerateOverworldMusic(string path)
    {
        int len = sampleRate * 8; // 8 second loop
        float[] samples = new float[len];

        // C major melody pattern
        float[] melody = { 523.25f, 587.33f, 659.25f, 587.33f, 523.25f, 440f, 392f, 440f,
                          523.25f, 659.25f, 783.99f, 659.25f, 523.25f, 587.33f, 523.25f, 440f };
        float[] bass = { 130.81f, 130.81f, 146.83f, 146.83f, 164.81f, 164.81f, 130.81f, 130.81f,
                        130.81f, 130.81f, 146.83f, 146.83f, 164.81f, 164.81f, 130.81f, 130.81f };

        float noteLen = 8f / melody.Length;

        for (int i = 0; i < len; i++)
        {
            float t = (float)i / sampleRate;
            int noteIdx = (int)(t / noteLen) % melody.Length;
            float noteT = (t % noteLen) / noteLen;

            // Melody (triangle wave)
            float melodyVal = Mathf.PingPong(t * melody[noteIdx] * 2, 1f) * 2 - 1;
            float melodyEnv = Mathf.Max(0, 1f - noteT * 0.5f);

            // Bass (sine)
            float bassVal = Mathf.Sin(2 * Mathf.PI * bass[noteIdx] * t);
            float bassEnv = 0.6f;

            // Drums (every beat)
            float drumVal = 0;
            float beatPos = (t * 2) % 1f;
            if (beatPos < 0.05f)
            {
                System.Random drng = new System.Random((int)(t * 100));
                drumVal = (float)(drng.NextDouble() * 2 - 1) * (1f - beatPos * 20f) * 0.5f;
            }

            samples[i] = (melodyVal * melodyEnv * 0.15f + bassVal * bassEnv * 0.1f + drumVal * 0.08f);
        }
        SaveWAV(path + "/overworld_theme.wav", samples);
    }

    static void GenerateBattleMusic(string path)
    {
        int len = sampleRate * 6;
        float[] samples = new float[len];

        float[] melody = { 329.63f, 329.63f, 392f, 440f, 523.25f, 440f, 392f, 329.63f,
                          349.23f, 392f, 440f, 523.25f, 587.33f, 523.25f, 440f, 392f };
        float[] bass = { 164.81f, 164.81f, 196f, 196f, 220f, 220f, 164.81f, 164.81f,
                        174.61f, 174.61f, 196f, 196f, 220f, 220f, 196f, 164.81f };
        float noteLen = 6f / melody.Length;

        for (int i = 0; i < len; i++)
        {
            float t = (float)i / sampleRate;
            int noteIdx = (int)(t / noteLen) % melody.Length;
            float noteT = (t % noteLen) / noteLen;

            // Aggressive square wave melody
            float melodyVal = Mathf.Sin(2 * Mathf.PI * melody[noteIdx] * t) > 0 ? 1f : -1f;
            float melodyEnv = Mathf.Max(0, 1f - noteT * 0.3f);

            // Pulse bass
            float bassVal = Mathf.Sin(2 * Mathf.PI * bass[noteIdx] * t) > 0.3f ? 1f : -1f;

            // Fast drums
            float drumVal = 0;
            float beatPos = (t * 4) % 1f; // faster beat
            if (beatPos < 0.03f)
            {
                System.Random drng = new System.Random((int)(t * 200));
                drumVal = (float)(drng.NextDouble() * 2 - 1) * (1f - beatPos * 33f);
            }

            samples[i] = (melodyVal * melodyEnv * 0.12f + bassVal * 0.06f + drumVal * 0.1f);
        }
        SaveWAV(path + "/battle_theme.wav", samples);
    }

    static void GenerateGymMusic(string path)
    {
        int len = sampleRate * 6;
        float[] samples = new float[len];

        float[] melody = { 440f, 523.25f, 587.33f, 659.25f, 587.33f, 523.25f, 440f, 392f,
                          440f, 587.33f, 659.25f, 783.99f, 659.25f, 587.33f, 523.25f, 440f };
        float noteLen = 6f / melody.Length;

        for (int i = 0; i < len; i++)
        {
            float t = (float)i / sampleRate;
            int noteIdx = (int)(t / noteLen) % melody.Length;
            float noteT = (t % noteLen) / noteLen;

            float val = Mathf.Sin(2 * Mathf.PI * melody[noteIdx] * t) * 0.5f +
                        Mathf.Sin(2 * Mathf.PI * melody[noteIdx] * 2f * t) * 0.2f;
            float env = Mathf.Max(0, 1f - noteT * 0.4f);

            float bass = Mathf.Sin(2 * Mathf.PI * melody[noteIdx] * 0.25f * t) * 0.3f;

            samples[i] = (val * env * 0.15f + bass * 0.08f);
        }
        SaveWAV(path + "/gym_theme.wav", samples);
    }

    static void GenerateMenuMusic(string path)
    {
        int len = sampleRate * 8;
        float[] samples = new float[len];

        float[] melody = { 392f, 440f, 523.25f, 440f, 392f, 349.23f, 392f, 440f,
                          523.25f, 587.33f, 659.25f, 587.33f, 523.25f, 440f, 392f, 440f };
        float noteLen = 8f / melody.Length;

        for (int i = 0; i < len; i++)
        {
            float t = (float)i / sampleRate;
            int noteIdx = (int)(t / noteLen) % melody.Length;
            float noteT = (t % noteLen) / noteLen;

            // Gentle sine melody
            float val = Mathf.Sin(2 * Mathf.PI * melody[noteIdx] * t);
            float env = Mathf.Max(0, 1f - noteT * 0.3f) * 0.7f;

            // Soft pad
            float pad = Mathf.Sin(2 * Mathf.PI * melody[noteIdx] * 0.5f * t) * 0.2f;

            samples[i] = (val * env * 0.12f + pad * 0.06f);
        }
        SaveWAV(path + "/menu_theme.wav", samples);
    }

    // ================================================================
    // WAV FILE WRITER
    // ================================================================
    static void SaveWAV(string filepath, float[] samples)
    {
        short[] intSamples = new short[samples.Length];
        for (int i = 0; i < samples.Length; i++)
        {
            float s = Mathf.Clamp(samples[i], -1f, 1f);
            intSamples[i] = (short)(s * 32767);
        }

        using (var stream = new FileStream(filepath, FileMode.Create))
        using (var writer = new BinaryWriter(stream))
        {
            int subChunk2Size = intSamples.Length * 2;
            int chunkSize = 36 + subChunk2Size;

            // RIFF header
            writer.Write(System.Text.Encoding.ASCII.GetBytes("RIFF"));
            writer.Write(chunkSize);
            writer.Write(System.Text.Encoding.ASCII.GetBytes("WAVE"));

            // fmt sub-chunk
            writer.Write(System.Text.Encoding.ASCII.GetBytes("fmt "));
            writer.Write(16); // subchunk size
            writer.Write((short)1); // PCM
            writer.Write((short)1); // mono
            writer.Write(sampleRate);
            writer.Write(sampleRate * 2); // byte rate
            writer.Write((short)2); // block align
            writer.Write((short)16); // bits per sample

            // data sub-chunk
            writer.Write(System.Text.Encoding.ASCII.GetBytes("data"));
            writer.Write(subChunk2Size);
            foreach (short s in intSamples)
                writer.Write(s);
        }
    }
}
