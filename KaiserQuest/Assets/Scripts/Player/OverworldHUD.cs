using UnityEngine;
using KaiserQuest.Story;

/// <summary>
/// The overworld's status plate: who you are, where you are, what the campaign
/// wants from you next, and how to control it — the four things a player needs at
/// a glance and would otherwise have to guess.
///
/// IMGUI again, for the same reason the story screens are: no canvases, no prefabs,
/// no editor wiring, so it cannot be lost to a fresh clone. It draws only when no
/// story screen is open, so it never competes with a trial for the screen.
/// </summary>
public class OverworldHUD : MonoBehaviour
{
    [Tooltip("How long the full control legend stays up before collapsing to a one-liner.")]
    public float legendSeconds = 90f;

    private float _startedAt;
    private GUIStyle _title;
    private GUIStyle _line;
    private GUIStyle _hint;

    private void Start()
    {
        _startedAt = Time.unscaledTime;
    }

    private void OnGUI()
    {
        // A story screen owns the whole display while it is open.
        if (StoryUI.BlocksWorldInput) return;

        StoryModeManager story = StoryModeManager.Instance;
        if (story == null || !story.Ready || story.Save == null) return;

        EnsureStyles();

        CampaignDetail campaign = story.CampaignDetail(story.ActiveRealmId);
        if (campaign == null) return;

        DrawStatus(story, campaign);
        DrawLegend();
    }

    private void DrawStatus(StoryModeManager story, CampaignDetail campaign)
    {
        const float width = 320f;
        const float height = 84f;
        Rect panel = new Rect(12f, 12f, width, height);
        GUI.Box(panel, GUIContent.none);

        Rect inner = new Rect(panel.x + 12f, panel.y + 8f, panel.width - 24f, panel.height - 16f);
        GUI.Label(new Rect(inner.x, inner.y, inner.width, 22f),
                  story.Save.playerName + "  \u2014  " + campaign.RealmName, _title);
        GUI.Label(new Rect(inner.x, inner.y + 22f, inner.width, 20f),
                  ProtectedRegion(campaign) + "  \u00b7  " + campaign.PassedCount + " / " + campaign.Total
                  + " milestones", _line);
        GUI.Label(new Rect(inner.x, inner.y + 42f, inner.width * 2f, 40f), Objective(campaign), _hint);
    }

    /// <summary>What the campaign wants next, in words rather than a lock icon.</summary>
    private static string Objective(CampaignDetail campaign)
    {
        if (campaign.Completed || campaign.MountainOpen)
            return "Silver Mountain is open \u2014 the Archivist is waiting at the summit.";

        Milestone current = campaign.Current;
        if (current == null)
            return "The road ahead is being written.";

        if (campaign.Entry == null || campaign.Entry.Allowed)
        {
            return "Milestone " + current.Index + ": find " + current.Keeper
                   + " at " + current.Place + ".";
        }

        // The mastery gate, said plainly: the player is told what faded and that
        // replaying is the way through, never merely that they are not allowed.
        string reason = campaign.Entry.Reasons != null && campaign.Entry.Reasons.Count > 0
            ? campaign.Entry.Reasons[0]
            : "your mastery of this chapter has faded.";
        return "Milestone " + current.Index + " is shut: " + reason
               + " Replay the previous trial to rebuild it.";
    }

    private static string ProtectedRegion(CampaignDetail campaign)
    {
        return string.IsNullOrEmpty(campaign.Region) ? "the road" : campaign.Region;
    }

    private void DrawLegend()
    {
        bool full = Time.unscaledTime - _startedAt < legendSeconds;

        if (full)
        {
            const float width = 320f;
            const float height = 74f;
            Rect panel = new Rect(12f, Screen.height - height - 12f, width, height);
            GUI.Box(panel, GUIContent.none);
            GUI.Label(new Rect(panel.x + 12f, panel.y + 8f, panel.width - 24f, 20f), "Controls", _title);
            GUI.Label(new Rect(panel.x + 12f, panel.y + 28f, panel.width - 24f, 20f),
                      "WASD / arrows \u2014 walk    \u00b7    Z \u2014 interact", _line);
            GUI.Label(new Rect(panel.x + 12f, panel.y + 48f, panel.width - 24f, 20f),
                      "Esc \u2014 story map / pause", _line);
            return;
        }

        GUI.Label(new Rect(12f, Screen.height - 30f, 300f, 22f),
                  "Z \u2014 interact    \u00b7    Esc \u2014 story map", _hint);
    }

    private void EnsureStyles()
    {
        if (_title != null) return;

        _title = new GUIStyle(GUI.skin.label);
        _title.fontSize = 15;
        _title.fontStyle = FontStyle.Bold;
        _title.normal.textColor = new Color(0.95f, 0.93f, 0.85f);

        _line = new GUIStyle(GUI.skin.label);
        _line.fontSize = 13;
        _line.normal.textColor = new Color(0.88f, 0.86f, 0.8f);

        _hint = new GUIStyle(GUI.skin.label);
        _hint.fontSize = 12;
        _hint.wordWrap = true;
        _hint.normal.textColor = new Color(0.78f, 0.85f, 0.95f);
    }
}
