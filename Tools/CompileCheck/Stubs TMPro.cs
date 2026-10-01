// Verification-only stubs for TextMeshPro (outside Assets/, same rationale as the
// uGUI stubs: the harness can typecheck legacy scripts without the package DLLs,
// and the real assemblies win inside the Editor).
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.UI;

namespace TMPro
{
    public class TMP_Text : UnityEngine.UI.UIBehaviour
    {
        public virtual string text { get; set; }
        public int fontSize { get; set; }
        public TextAlignmentOptions alignment { get; set; }
        public bool enableWordWrapping { get; set; }
        public Color color { get; set; }
        public float alpha { get; set; }
    }

    public enum TextAlignmentOptions
    {
        Left,
        Center,
        Right,
        TopLeft,
        Top,
        TopRight,
        BottomLeft,
        Bottom,
        BottomRight
    }

    public class TextMeshProUGUI : TMP_Text
    {
        public override string text { get; set; }
    }

    public class TextMeshPro : TMP_Text
    {
        public override string text { get; set; }
    }

    public class TMP_InputField : UnityEngine.UI.Selectable
    {
        public string text { get; set; }
        public TMPro.TextMeshProUGUI textComponent { get; set; }
        public TMPro.TMP_Text placeholder { get; set; }
        public UnityEvent<string> onSubmit = new UnityEvent<string>();
        public UnityEvent<string> onValueChanged = new UnityEvent<string>();

        public void SetTextWithoutNotify(string value) { text = value; }
        public void ActivateInputField() { }
        public void DeactivateInputField() { }
    }
}
