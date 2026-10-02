using UnityEngine;
using UnityEngine.Tilemaps;

/// <summary>
/// The tile palette the world generator paints with, built in code at runtime.
///
/// The generator's tile fields (grass, path, water, tree, wall) are plain
/// references, and every SetTile call in the generator is guarded against them
/// being null. Nothing ever assigned them, so the generator would faithfully
/// carve out terrain and paint exactly nothing — the player stood in a void.
///
/// The tiles are built here rather than authored as assets for the same reason
/// the rest of the game is: the project ships without .meta files, so a scene or
/// asset reference made in the editor would not survive a fresh clone. Sprites
/// come from <see cref="PixelSpriteGenerator"/>; Tile assets are created the
/// moment they are needed.
/// </summary>
public static class RuntimeTileset
{
    public static TileBase Grass { get; private set; }
    public static TileBase Path { get; private set; }
    public static TileBase Water { get; private set; }
    public static TileBase Tree { get; private set; }
    public static TileBase Wall { get; private set; }

    public static bool Ready { get { return Grass != null; } }

    public static void Build()
    {
        PixelSpriteGenerator sprites = PixelSpriteGenerator.Instance;
        if (sprites == null)
        {
            Debug.LogWarning("[Tileset] No sprite generator yet — tiles not built.");
            return;
        }

        if (Grass == null) Grass = Make(sprites.GenerateGrassTile(), Tile.ColliderType.None);
        if (Path == null) Path = Make(sprites.GeneratePathTile(), Tile.ColliderType.None);
        if (Water == null) Water = Make(sprites.GenerateWaterTile(), Tile.ColliderType.None);
        if (Tree == null) Tree = Make(sprites.GenerateTreeTile(), Tile.ColliderType.None);

        // The collision tile carries the collider, not the look. ColliderType.Grid
        // gives the whole cell a collider regardless of the sprite, so water and
        // tree cells block movement even though their visible tiles are drawn on
        // separate tilemaps.
        if (Wall == null) Wall = Make(sprites.GenerateWallTile(), Tile.ColliderType.Grid);
    }

    /// <summary>Hand the palette to the generator, without overwriting tiles a scene assigned.</summary>
    public static void ApplyTo(ProceduralWorldGenerator generator)
    {
        if (generator == null) return;
        if (!Ready) Build();

        if (generator.grassTile == null) generator.grassTile = Grass;
        if (generator.pathTile == null) generator.pathTile = Path;
        if (generator.waterTile == null) generator.waterTile = Water;
        if (generator.treeTile == null) generator.treeTile = Tree;
        if (generator.wallTile == null) generator.wallTile = Wall;

        if (generator.grassTile == null)
            Debug.LogWarning("[Tileset] World generator has no tiles — the world will be empty.");
    }

    private static TileBase Make(Sprite sprite, Tile.ColliderType colliderType)
    {
        if (sprite == null) return null;

        Tile tile = ScriptableObject.CreateInstance<Tile>();
        tile.sprite = sprite;
        tile.colliderType = colliderType;
        return tile;
    }
}
