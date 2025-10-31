# Seasonal Textures System

**Status:** Planned (Art assets in progress)
**Last Updated:** October 31, 2025

## Overview

A dynamic seasonal texture system that changes specific block textures based on in-game season or real-world date. Instead of creating colorization variants (which requires code changes everywhere), we use separate seasonal texture atlases swapped at runtime.

## The Problem We're Solving

Previously attempted: Colorizing seasonal blocks meant:
- ❌ New block IDs/definitions for each seasonal variant
- ❌ Changes needed in mining code (recognize seasonal variants)
- ❌ Changes needed in inventory code (track seasonal blocks separately)
- ❌ Changes needed in placement code (which season variant to place?)
- ❌ High complexity for what should be a visual-only change

**Solution:** Material-based texture swapping - only the visuals change, block IDs stay the same.

## Architecture

### File Structure

```
blocky_game/blocks/
├── terrain.png                          (Base/spring textures - exists)
├── seasonal/
│   ├── spring.png                       (6 seasonal blocks)
│   ├── summer.png                       (6 seasonal blocks)
│   ├── autumn.png                       (6 seasonal blocks)
│   └── winter.png                       (6 seasonal blocks)
├── terrain_material.tres                (Base material, points to terrain.png)
└── terrain_material_seasonal.tres       (NEW: dynamically updates texture)
```

### Seasonal Blocks

These 6 blocks have seasonal variants:

1. **grass_top** - Green in spring/summer, brown in fall, white in winter
2. **grass_side** - Similar seasonal variation
3. **leaves** - Green → yellow-orange → brown → dead
4. **logs** - May have seasonal tinting/weathering
5. **tall_grass** - Green → golden → brown → dead
6. **dead_shrub** - May vary by season

All other blocks (stone, dirt, sand, etc.) remain unchanged.

### Material Swapping Strategy

**Current Setup:**
- All blocks use `terrain_material.tres` → references `terrain.png`
- Block mesh UV coordinates point into `terrain.png` atlas

**Implementation:**
- Keep `terrain.png` as base (spring/summer)
- Create parallel materials for each season:
  - `terrain_material_spring.tres` → `seasonal/spring.png`
  - `terrain_material_summer.tres` → `seasonal/summer.png`
  - `terrain_material_autumn.tres` → `seasonal/autumn.png`
  - `terrain_material_winter.tres` → `seasonal/winter.png`
- When season changes, re-assign materials to affected blocks

**Key Constraint:** All seasonal atlases have **identical coordinate layout**
- `grass_top` is at UV (0,0) in all seasonal PNGs
- `grass_side` is at UV (1,0) in all seasonal PNGs
- etc.

This means block meshes need NO changes - same UV coordinates work across all seasons.

## Implementation Plan

### Phase 1: Art Assets (In Progress)

1. **Create seasonal atlases** (artist task)
   - Extract the 6 seasonal blocks from main `terrain.png`
   - Create new minimal atlases: `spring.png`, `summer.png`, `autumn.png`, `winter.png`
   - Each atlas contains ONLY the 6 seasonal blocks
   - **All atlases use identical texture coordinate layout**
   - Color shifts for now (placeholder), replace with proper art later

2. **Create season_config.json**
   ```json
   {
     "seasonal_blocks": [
       "grass_top",
       "grass_side",
       "leaves",
       "logs",
       "tall_grass",
       "dead_shrub"
     ],
     "uv_coords": {
       "grass_top": [0, 0],
       "grass_side": [1, 0],
       "leaves": [0, 1],
       "logs": [1, 1],
       "tall_grass": [2, 0],
       "dead_shrub": [2, 1]
     }
   }
   ```

### Phase 2: Code Implementation (Ready When Assets Complete)

1. **Create SeasonManager.gd** (autoload)
   - Track current season (spring/summer/autumn/winter)
   - Load seasonal texture atlases on demand
   - Emit `season_changed(season_name)` signal
   - Provide API:
     - `get_current_season()` → returns season name
     - `set_season(season_name)` → changes season + updates textures
     - `toggle_real_world_sync(bool)` → enable/disable real-date sync
     - `get_season_from_date(datetime)` → calculate season from date

2. **Create seasonal materials** in Godot
   - Duplicate `terrain_material.tres` 4 times
   - Name them `terrain_material_spring.tres`, etc.
   - Update each to reference its seasonal PNG

3. **Modify blocks.gd**
   - Add method: `update_seasonal_materials(season_name)`
   - Lookup which blocks are seasonal from JSON
   - Re-assign material to each seasonal block

4. **Integrate with TimeManager**
   - Calculate season from `current_month`
   - Emit signal when season changes
   - SeasonManager listens and updates textures

5. **Add Console Commands**
   ```
   seasons status          # Show current season
   seasons set <name>      # Force season (spring/summer/autumn/winter)
   seasons sync_real on/off # Toggle real-world date sync
   ```

## Technical Details

### Material Assignment

Current state (voxel_library.tres):
```
Block "grass" → mesh + material_override_0 = terrain_material.tres
```

When season changes:
```
Block "grass" → mesh + material_override_0 = terrain_material_autumn.tres
```

The mesh UVs never change - they still point to (0,0) in the atlas. But because the material points to a different PNG, the texture displayed changes.

### Real-World Sync

Optional feature: Sync seasons to player's actual date
- January-March = Spring
- April-June = Summer
- July-September = Autumn
- October-December = Winter

Uses `Time.get_datetime_dict_from_system()` for system date.

### Performance

✅ **Minimal overhead:**
- Small atlases (only 6 blocks per season)
- Load one atlas into VRAM at a time
- Material assignment is cheap operation
- Chunks re-render naturally via Godot's material system

## Why This Approach?

| Approach | Pros | Cons |
|----------|------|------|
| **Colorization (old)** | Single texture file | Need separate block IDs everywhere |
| **Full seasonal terrain.pngs** | Works easily | Large file sizes, redundant data |
| **Material Swapping (chosen)** | ✅ Clean separation | Need multiple material files |
| | ✅ No code changes to mining/inventory | |
| | ✅ Small atlases | |
| | ✅ Easy to extend later | |

## Future Enhancements

Once working, can add:
- Weather effects (rain darkening, snow coverage)
- Time-of-day lighting (sunrise/sunset tinting)
- Dynamic ambient color based on season
- Seasonal mob spawn rates
- Seasonal plant growth mechanics

## Notes

- All seasonal atlases must have **identical coordinate layout**
- Ensure atlas dimensions are same across seasons (for consistency)
- Test with multiple seasons before committing
- Can gradually improve art quality in each seasonal atlas

## Related Systems

- **TimeManager** - Tracks in-game time (integration point)
- **GraphicsSettings** - Could add seasonal rendering options later
- **blocks.gd** - Material assignment logic
- **voxel_library.tres** - Block definitions
