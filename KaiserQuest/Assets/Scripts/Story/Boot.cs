using UnityEngine;

namespace KaiserQuest.Story
{
    /// <summary>
    /// Boot — the one entry point that cannot be miswired.
    ///
    /// The v0.2 game had to be played from the Overworld scene with GameBootstrap
    /// present and the menu scenes hand-wired; on a fresh clone the main menu drew
    /// nothing and Continue hit a null GameManager, so the game could not start at
    /// all. So the boot no longer depends on any scene containing anything.
    ///
    /// After the first scene loads — whichever scene, however bare — this creates
    /// GameBootstrap, which creates every manager, generates the world, and opens
    /// the story's first screen. Opening Overworld directly in the Editor still
    /// works: the bootstrap already in that scene takes precedence and this does
    /// nothing. Same game either way.
    /// </summary>
    public static class Boot
    {
        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void Bootstrap()
        {
            if (Object.FindObjectOfType<GameBootstrap>() != null) return;

            GameObject go = new GameObject("GameBootstrap");
            go.AddComponent<GameBootstrap>();
            Debug.Log("[Boot] No bootstrap in scene — created one. KaiserQuest is self-booting.");
        }
    }
}
