// Verification-only stubs for the uGUI assembly. These let the compile harness
// (which runs outside Unity, without package DLLs) typecheck the legacy scripts
// that reference UnityEngine.UI. They are deliberately NOT under Assets/, so the
// Unity Editor never compiles them and the real package assemblies win at runtime.
using System;
using UnityEngine;
using UnityEngine.Events;

namespace UnityEngine.UI
{
    /// <summary>Stub of UnityEngine.UI.UIBehaviour (real one lives in UnityEngine.UI assembly).</summary>
    public class UIBehaviour : MonoBehaviour
    {
        public bool IsActive() { return enabled; }
    }

    public class Graphic : UIBehaviour
    {
        public Color color { get; set; }
        public Material material { get; set; }
        public bool raycastTarget { get; set; }
        public RectTransform rectTransform { get { return GetComponent<RectTransform>(); } }
    }

    public class Image : Graphic
    {
        public Sprite sprite { get; set; }
        public bool fillCenter { get; set; }
        public float fillAmount { get; set; }
    }

    public class Text : Graphic
    {
        public string text { get; set; }
        public int fontSize { get; set; }
        public TextAnchor alignment { get; set; }
        public Font font { get; set; }
        public bool supportRichText { get; set; }
        public bool resizeTextForBestFit { get; set; }
    }

    public class Button : Selectable
    {
        public ButtonClickedEvent onClick = new ButtonClickedEvent();

        public class ButtonClickedEvent : UnityEvent { }
    }

    public class Selectable : UIBehaviour
    {
        public bool interactable { get; set; }
        public bool IsInteractable() { return interactable; }
    }

    public class Slider : Selectable
    {
        public float minValue { get; set; }
        public float maxValue { get; set; }
        public float value { get; set; }
        public RectTransform fillRect { get; set; }
        public UnityEvent<float> onValueChanged = new UnityEvent<float>();
    }

    public class Toggle : Selectable
    {
        public bool isOn { get; set; }
        public UnityEvent<bool> onValueChanged = new UnityEvent<bool>();
    }

    public class Canvas : UIBehaviour
    {
        public RenderMode renderMode { get; set; }
        public int sortingOrder { get; set; }
        public Camera worldCamera { get; set; }
    }

    public class CanvasScaler : UIBehaviour
    {
        public ScaleMode uiScaleMode { get; set; }

        public enum ScaleMode
        {
            ConstantPixelSize,
            ScaleWithScreenSize
        }
    }

    public class CanvasGroup : UIBehaviour
    {
        public float alpha { get; set; }
        public bool interactable { get; set; }
        public bool blocksRaycasts { get; set; }
    }

    public class GraphicRaycaster : UIBehaviour { }
}

namespace UnityEngine.EventSystems
{
    /// <summary>Stub of the EventSystem package's EventTrigger (legacy scripts GetComponent it).</summary>
    public class EventTrigger : UnityEngine.UI.UIBehaviour
    {
        public class Entry
        {
            public EventTriggerType eventID;
        }
    }

    public enum EventTriggerType
    {
        PointerEnter,
        PointerExit,
        PointerClick
    }
}
