# Seasonal Texture System

## Overview
The seasonal texture system allows blocks in the game to dynamically change their appearance based on the in-game season. This system uses texture atlas overlays to efficiently swap block textures without duplicating the entire terrain atlas.

## Concept
The game has a time system where seasons change every 3 months of in-game time. When a season changes (or at game startup), specific blocks that have seasonal variants will have their textures updated to reflect the current season.

## Implementation Approach

### Texture Organization
- **Main Atlas**: `terrain.png` - Contains all base block textures
- **Seasonal Atlases**: `summer.png`, `spring.png`, `autumn.png`, `winter.png` - Contains only seasonal variant textures
- All textures are 16x16 pixels per tile
- Seasonal atlases only need to contain blocks that change with seasons (more compact, less duplication)

### Mapping System
A JSON configuration file maps terrain.png coordinates to seasonal atlas coordinates. This allows seasonal textures to be positioned anywhere in their respective atlases, independent of the terrain.png layout.

**Example JSON Structure:**
```json
{
  "grass": {
    "terrain": [0, 0],
    "summer": [0, 1],
    "spring": [0, 2],
    "autumn": [0, 3],
    "winter": [0, 4]
  },
  "oak_leaves": {
    "terrain": [5, 2],
    "summer": [1, 0],
    "spring": [1, 1],
    "autumn": [1, 2],
    "winter": [1, 3]
  },
  "dirt": {
    "terrain": [2, 0]
    // No seasonal variants - will never change
  }
}
```

### Runtime Flow
1. **Game Start / Season Change Event**
   - Check current in-game season
   - Load seasonal mapping JSON
   - Load appropriate seasonal atlas (e.g., `summer.png`)

2. **Texture Update**
   - For each block in the mapping that has a variant for current season:
     - Get source coordinates from seasonal atlas
     - Get destination coordinates from terrain.png
     - Copy 16x16 tile from seasonal atlas to terrain.png (in memory)

3. **Apply Changes**
   - Update the modified terrain.png texture in the voxel_library.tres
   - Texture changes apply immediately to all instances of affected blocks

## Benefits
- **Efficient Storage**: Only store textures that actually change seasonally
- **Flexible Layout**: Seasonal atlases can be organized independently from terrain.png
- **Performance**: Texture swapping happens only at season transitions, zero runtime cost during gameplay
- **Easy Expansion**: Add new seasonal blocks by updating JSON and adding tiles to seasonal atlases
- **Selective Seasons**: Blocks don't need all four seasons defined - only the ones that make sense

## Blocks Likely to Have Seasonal Variants
- Grass
- Tree leaves (oak, birch, pine, etc.)
- Crops/vegetation
- Water (frozen in winter?)
- Snow cover (appears in winter, gone in other seasons)

## Blocks That Won't Change
- Stone
- Dirt
- Sand
- Ores
- Manufactured blocks (iron, gold, etc.)

## Technical Considerations
- Use Godot's `Image.blit_rect()` for efficient tile copying
- Seasonal atlases can be smaller than terrain.png
- JSON file should be easily editable for quick iteration
- Consider smooth transitions between seasons (optional fade effect)
- Save current season in game save data

## Future Enhancements
- Transition effects (gradual color shift between seasons)
- Time-of-day variations using similar system
- Weather-based texture changes
- Regional variations (different biomes have different seasonal patterns)
