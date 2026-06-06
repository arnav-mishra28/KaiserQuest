using UnityEngine;
using System.Collections.Generic;

/// <summary>
/// SoundManager — Handles all audio playback: SFX and Music.
/// Manages music transitions, SFX stacking, and volume controls.
/// </summary>
public class SoundManager : MonoBehaviour
{
    public static SoundManager Instance { get; private set; }

    [Header("Audio Sources")]
    public AudioSource musicSource;
    public AudioSource sfxSource;
    public AudioSource ambientSource;

    [Header("Volume")]
    [Range(0, 1)] public float masterVolume = 1f;
    [Range(0, 1)] public float musicVolume = 0.5f;
    [Range(0, 1)] public float sfxVolume = 0.8f;

    [Header("Music Clips")]
    public AudioClip overworldTheme;
    public AudioClip battleTheme;
    public AudioClip gymTheme;
    public AudioClip menuTheme;
    public AudioClip silverMountainTheme;

    [Header("SFX Clips")]
    public AudioClip menuSelect;
    public AudioClip menuConfirm;
    public AudioClip menuBack;
    public AudioClip dialogBeep;
    public AudioClip correctAnswer;
    public AudioClip wrongAnswer;
    public AudioClip hitDamage;
    public AudioClip levelUp;
    public AudioClip badgeEarned;
    public AudioClip victoryJingle;
    public AudioClip defeatJingle;
    public AudioClip battleStart;
    public AudioClip healSound;
    public AudioClip footstep;
    public AudioClip encounterAlert;

    private string currentMusic = "";
    private float musicFadeTarget = 1f;

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;
        DontDestroyOnLoad(gameObject);

        // Auto-create audio sources if not assigned
        if (musicSource == null)
        {
            musicSource = gameObject.AddComponent<AudioSource>();
            musicSource.loop = true;
            musicSource.playOnAwake = false;
        }
        if (sfxSource == null)
        {
            sfxSource = gameObject.AddComponent<AudioSource>();
            sfxSource.loop = false;
            sfxSource.playOnAwake = false;
        }
        if (ambientSource == null)
        {
            ambientSource = gameObject.AddComponent<AudioSource>();
            ambientSource.loop = true;
            ambientSource.playOnAwake = false;
            ambientSource.volume = 0.3f;
        }

        // Try loading clips from Resources
        LoadClipsFromResources();
    }

    private void Start()
    {
        UpdateVolumes();
    }

    private void Update()
    {
        // Smooth music volume transitions
        if (musicSource != null)
        {
            float target = musicVolume * masterVolume * musicFadeTarget;
            musicSource.volume = Mathf.MoveTowards(musicSource.volume, target, Time.unscaledDeltaTime * 2f);
        }
    }

    // ================================================================
    // MUSIC
    // ================================================================

    public void PlayMusic(string musicName)
    {
        if (currentMusic == musicName) return;
        currentMusic = musicName;

        AudioClip clip = GetMusicClip(musicName);
        if (clip == null)
        {
            Debug.LogWarning($"[SoundManager] Music clip not found: {musicName}");
            return;
        }

        musicSource.clip = clip;
        musicSource.Play();
        musicFadeTarget = 1f;
    }

    public void StopMusic()
    {
        musicFadeTarget = 0f;
        currentMusic = "";
    }

    public void FadeOutMusic(float duration = 1f)
    {
        musicFadeTarget = 0f;
    }

    private AudioClip GetMusicClip(string name)
    {
        switch (name.ToLower())
        {
            case "overworld": return overworldTheme;
            case "battle": return battleTheme;
            case "gym": return gymTheme;
            case "menu": return menuTheme;
            case "silver_mountain": return silverMountainTheme;
            default: return null;
        }
    }

    // ================================================================
    // SOUND EFFECTS
    // ================================================================

    public void PlaySFX(string sfxName)
    {
        AudioClip clip = GetSFXClip(sfxName);
        if (clip != null)
        {
            sfxSource.PlayOneShot(clip, sfxVolume * masterVolume);
        }
    }

    public void PlaySFX(AudioClip clip)
    {
        if (clip != null)
        {
            sfxSource.PlayOneShot(clip, sfxVolume * masterVolume);
        }
    }

    private AudioClip GetSFXClip(string name)
    {
        switch (name.ToLower())
        {
            case "menu_select": return menuSelect;
            case "menu_confirm": return menuConfirm;
            case "menu_back": return menuBack;
            case "dialog_beep": return dialogBeep;
            case "correct": return correctAnswer;
            case "wrong": return wrongAnswer;
            case "hit": return hitDamage;
            case "level_up": return levelUp;
            case "badge": return badgeEarned;
            case "victory": return victoryJingle;
            case "defeat": return defeatJingle;
            case "battle_start": return battleStart;
            case "heal": return healSound;
            case "footstep": return footstep;
            case "encounter": return encounterAlert;
            default: return null;
        }
    }

    // ================================================================
    // VOLUME
    // ================================================================

    public void SetMasterVolume(float vol)
    {
        masterVolume = Mathf.Clamp01(vol);
        UpdateVolumes();
        PlayerPrefs.SetFloat("KQ_MasterVolume", masterVolume);
    }

    public void SetMusicVolume(float vol)
    {
        musicVolume = Mathf.Clamp01(vol);
        UpdateVolumes();
        PlayerPrefs.SetFloat("KQ_MusicVolume", musicVolume);
    }

    public void SetSFXVolume(float vol)
    {
        sfxVolume = Mathf.Clamp01(vol);
        PlayerPrefs.SetFloat("KQ_SFXVolume", sfxVolume);
    }

    private void UpdateVolumes()
    {
        if (musicSource != null)
            musicSource.volume = musicVolume * masterVolume;
    }

    private void LoadClipsFromResources()
    {
        // Try loading from Resources/Audio folder
        if (overworldTheme == null) overworldTheme = Resources.Load<AudioClip>("Audio/Music/overworld_theme");
        if (battleTheme == null) battleTheme = Resources.Load<AudioClip>("Audio/Music/battle_theme");
        if (gymTheme == null) gymTheme = Resources.Load<AudioClip>("Audio/Music/gym_theme");
        if (menuTheme == null) menuTheme = Resources.Load<AudioClip>("Audio/Music/menu_theme");

        if (menuSelect == null) menuSelect = Resources.Load<AudioClip>("Audio/SFX/menu_select");
        if (menuConfirm == null) menuConfirm = Resources.Load<AudioClip>("Audio/SFX/menu_confirm");
        if (menuBack == null) menuBack = Resources.Load<AudioClip>("Audio/SFX/menu_back");
        if (dialogBeep == null) dialogBeep = Resources.Load<AudioClip>("Audio/SFX/dialog_beep");
        if (correctAnswer == null) correctAnswer = Resources.Load<AudioClip>("Audio/SFX/correct_answer");
        if (wrongAnswer == null) wrongAnswer = Resources.Load<AudioClip>("Audio/SFX/wrong_answer");
        if (hitDamage == null) hitDamage = Resources.Load<AudioClip>("Audio/SFX/hit_damage");
        if (levelUp == null) levelUp = Resources.Load<AudioClip>("Audio/SFX/level_up");
        if (badgeEarned == null) badgeEarned = Resources.Load<AudioClip>("Audio/SFX/badge_earned");
        if (victoryJingle == null) victoryJingle = Resources.Load<AudioClip>("Audio/SFX/victory_jingle");
        if (defeatJingle == null) defeatJingle = Resources.Load<AudioClip>("Audio/SFX/defeat_jingle");
        if (battleStart == null) battleStart = Resources.Load<AudioClip>("Audio/SFX/battle_start");
        if (healSound == null) healSound = Resources.Load<AudioClip>("Audio/SFX/heal");
        if (footstep == null) footstep = Resources.Load<AudioClip>("Audio/SFX/footstep");
        if (encounterAlert == null) encounterAlert = Resources.Load<AudioClip>("Audio/SFX/encounter_alert");

        // Load saved volume preferences
        masterVolume = PlayerPrefs.GetFloat("KQ_MasterVolume", 1f);
        musicVolume = PlayerPrefs.GetFloat("KQ_MusicVolume", 0.5f);
        sfxVolume = PlayerPrefs.GetFloat("KQ_SFXVolume", 0.8f);
    }
}
