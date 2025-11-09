# Undervoid City Building System - Implementation Notes

## What Was Built

### 1. **UndervoidCityBuilding.gd** (New File)
- **Location:** `/blocky_game/ruins/undervoid_city_building.gd`
- **Purpose:** Modular city building templates for Y -490 (above rust hills layer)
- **Classes:** `CityBuilding` class with data structure for buildings

#### Four Base Building Templates:
1. **Small Dwelling** (6x6x4)
   - Open floor plan (no interior walls)
   - 1 doorway on front wall (2x2 opening)
   - Roofless (open-air ruins aesthetic)
   - ~60 blocks

2. **Warehouse** (10x10x5)
   - 4 support pillars inside
   - 2 doorways (front + side, 2x2 each)
   - Sealed roof
   - 1 interior chest
   - ~140 blocks

3. **Tall Tower** (6x6x8)
   - Hollow with center pillar (2x2)
   - 1 doorway at ground level
   - Roof cap on top
   - ~100 blocks

4. **Cylindrical Building** (8Ø x 6 high)
   - Circular footprint
   - Partial dome roof (~60% coverage for variety)
   - 1 doorway opening
   - Open-air interior
   - ~110 blocks

### 2. **Modified UndervoidSpawner.gd**
- **New Features:**
  - `_should_chunk_have_city_building()` - Deterministic spawning at Y -490 layer
  - `_spawn_city_building_in_chunk()` - Chunk-based city building placement
  - `spawn_city_building_at()` - Main function to place buildings
  - City building initialization in `initialize()` method
  - Separate tracking for city chunks vs. normal structure chunks

- **Spawning Logic:**
  - 10% chance per chunk to spawn a city building at Y -490
  - **Placement:** Above rust hills (Y -510 to -500 terrain, buildings at Y -490)
  - Deterministic seeding (reproducible world generation)
  - Buildings sit on top of generated rust hills landscape

### 3. **Modified undervoid_structures.gd**
- Added `get_all_structures()` - Return all structures for city reuse
- Added `get_structure_as_city_building()` - Convert structures to city format
- **Future capability:** Existing structures (Rusted Shrine, Foundry Complex, etc.) can be placed as "landmark buildings" in the city

### 4. **Modified blocky_game.gd**
- Updated UndervoidSpawner initialization to pass `null` for generator parameter
- System now ready for city building spawning

---

## How It Works

### City Generation Flow:
1. Player descends below Y -150 (Undervoid zone)
2. Every 3 seconds, spawner checks nearby chunks
3. For chunks at Y -490 level, spawner deterministically checks if building spawns (10% chance)
4. If yes: randomly selects a building template
5. Positions building within chunk (with margins for size)
6. Waits for chunks to load
7. Places all building blocks using voxel tool (on top of rust hills terrain)
8. Registers building in UndervoidRegistry

### Building Placement Features:
- **Level:** Y -490 (placed above rust hills, Y -510 to -500)
- **Foundation Platform:** Rust block platform (Y -495 to -490) beneath each building
  - Platform is 2 blocks larger than building footprint (e.g., 6x6 building = 8x8 platform)
  - 5 blocks thick for structural integrity
  - **Hollow center with opening** to suggest "ruins of previous civilization below"
  - Outer ring stays solid for support
- **Doorways:** 2x2 openings guaranteed on each building
- **Landscape visible:** Rust hills visible below the platform foundation
- **Deterministic:** Same world seed = same city layout every time
- **Scalable:** New buildings can be added easily

---

## Testing Checklist

When you test in-game, look for:

**Void Fortress + City Integration:**
- [ ] Void Fortress spawns with purple beacon (existing behavior)
- [ ] Ring of ~7 city buildings appears around the fortress
- [ ] Buildings form visible circle/ring pattern around fortress light
- [ ] Console shows "Ring city building X/7" messages
- [ ] Ring appears at different distances/angles (organic, not grid-like)

**Individual Buildings:**
- [ ] Buildings are fully visible on top of platforms (not floating)
- [ ] Foundation platforms visible beneath buildings (Y -495 to -490)
- [ ] Buildings have visible doorways (2x2 openings)
- [ ] Can see through center hole of platforms (suggests "ruins below")
- [ ] Rust hills terrain visible below the platforms
- [ ] Multiple building types appear in the ring
- [ ] Can walk through doorways and enter buildings
- [ ] Platform creates natural "raised settlement" appearance

**Overall Feel:**
- [ ] City feels like it's built around the Fortress light source
- [ ] Ring buildings are close enough to feel like a community
- [ ] Far enough from Fortress to not overlap/collide with it
- [ ] Thematically makes sense: "settlements around the light"

---

## How the City Clusters Around the Void Fortress

### Void Fortress Integration
When a **Void Fortress spawns**, it automatically triggers city building generation:

**Process:**
1. Void Fortress places at Y -450 to -500 (existing system)
2. Purple beacon light appears on top (existing system)
3. **NEW:** Ring of 7 city buildings spawns around the fortress
4. Buildings placed at Y -490 (above rust hills, below fortress)
5. Ring distance: 40-60 blocks outward from fortress center
6. Angle randomization: Creates organic, non-grid appearance

**Visual Result:**
- Fortress = central beacon light source
- Ring of buildings = settlements gathering around the light
- Creates natural "city district" effect
- Thematically: "People build where there is light"

**Deterministic Placement:**
- Ring positions are seeded by fortress location + world seed
- Same world seed = same ring placement every time
- Prevents chaos while maintaining procedural feel

---

## Next Steps (Phase 2 - Not Yet Implemented)

### Future Enhancements:
1. **Existing Structure Integration**
   - Reuse Rusted Shrine, Mechanical Outpost, Mining Camp, Foundry Complex
   - Place them at Y -510 as "landmark buildings"
   - Lower spawn weight (0.5) vs new buildings (1.0)

2. **Building Clustering**
   - Detect adjacent buildings
   - Reduce wall overlap for tight city feel
   - Create district-like neighborhoods

3. **Void Fortress Support**
   - Detect Void Fortresses above city
   - Extend support walls down to connect to buildings below
   - Creates visually unified mega-structures

4. **Regional Material Variation**
   - Different rust colors per district
   - Mix stone/rust blocks for variety
   - Create "aged" vs "intact" looking areas

5. **Interior Complexity**
   - Add more pillars/support structures to large buildings
   - Create internal chambers and compartments
   - Add interior doorways

---

## File Changes Summary

**New Files:**
- `/blocky_game/ruins/undervoid_city_building.gd` (500 lines)

**Modified Files:**
- `/blocky_game/ruins/UndervoidSpawner.gd` (+150 lines, city spawning methods)
- `/blocky_game/ruins/undervoid_structures.gd` (+20 lines, structure export methods)
- `/blocky_game/blocky_game.gd` (1 line, initialization parameter)

**Total Additions:** ~670 lines of well-organized, documented code
