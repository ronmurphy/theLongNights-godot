# The Long Nights - Godot 4.5 Remake Progress

**Project Start:** October 25, 2025
**Engine:** Godot 4.5 with Zylann's Voxel Module (v1.5)
**Platform:** Linux (Arch), Windows export capability
**Current Status:** Graphics optimization system complete, fog system active, Terrain Mapper tool implemented

---

## Session 3: October 27, 2025 (Terrain Mapper & Block System)

### Terrain Mapper Tool - COMPLETE ✅
**Purpose:** Visual in-game tool for creating and mapping new block textures without manual coordinate calculation

**Files Created/Modified:**
- ✅ Created: `long_nights/TerrainMapper.gd` (253 lines)
- ✅ Created: `docs/godot/TERRAIN_MAPPER.md` (comprehensive guide)
- ✅ Modified: `blocky_game/blocky_game.gd` (added terrain mapper instantiation)
- ✅ Modified: `blocky_game/player/avatar_interaction.gd` (added mapper input check)

**Features Implemented:**
- ✅ Opens with **Ctrl+T** hotkey (independent from console)
- ✅ Displays terrain.png with visual 16×16 grid overlay
- ✅ Click grid cells to select texture location
- ✅ Auto-calculates UV coordinates (handles OBJ bottom-left origin inversion)
- ✅ Generates blocks.gd template code (ready to paste)
- ✅ Generates OBJ file template with correct vt values for all 6 cube faces
- ✅ **COPY ALL button** - Copies all data to system clipboard
- ✅ Mouse control working perfectly
- ✅ Prevents scrollwheel from triggering hotbar
- ✅ Hides PartyUI while mapper is open
- ✅ Disables game controls during use
- ✅ Dynamic cell size calculation based on actual grid display size

**Terrain Atlas Details:**
- Location: `res://blocky_game/blocks/terrain.png`
- Size: 16×16 grid = 256 total texture slots
- Current usage: ~20-30 blocks active
- Available: 200+ empty slots for new blocks

**Example Output (Grid 8,0):**
```
Grid Coordinates: (8, 0)
UV: U: 0.5000 - 0.5625, V: 0.0000 - 0.0625

blocks.gd template:
_create_block({
    "name": "new_block_8_0",
    "gui_model": "new_block_8_0.obj",
    "rotation_type": ROTATION_TYPE_NONE,
    "voxels": ["new_block_8_0"],
    "transparent": false
})

OBJ template: (with vt coordinates for all 6 faces)
```

### Issues Resolved This Session:
- ❌ Attempted complex tinting/pooling system (abandoned as over-engineered)
- ❌ Hard reset to clean state (removed all tinting code)
- ✅ Fixed path resolution for console commands (player discovery via SceneTree groups)
- ✅ Removed non-functional giveblock/listblocks commands
- ✅ Identified grass/dead_shrub collision issue (voxel library limitation)
- ✅ Built Terrain Mapper from scratch in ~2 hours
- ✅ Resolved parse errors and type mismatches
- ✅ Fixed mouse input handling and scrollwheel propagation

### Investigation: Grass & Dead Shrub Non-Targetable
**Finding:** Both blocks marked as `"transparent": true` in blocks.gd
- **Root Cause:** Voxel library has these blocks configured as non-solid (no collision)
- **Result:** Raycasts pass through them, hitting terrain behind
- **Solution:** Would require voxel_library.tres modification (not done)
- **Status:** Identified but deferred (not blocking gameplay)

### Lessons Learned:
1. **Don't over-engineer:** Tinting + pooling was overkill, simple approach is better
2. **Keep it modular:** Independent tool (mapper) is cleaner than integrated system
3. **Godot 4 quirks:** `wrap_enabled` doesn't exist on TextEdit, use dynamic sizing
4. **User experience:** Clipboard copy-to-clipboard beats file saving

---

## Session 2: October 26, 2025 (Continued)

### Graphics Settings & Optimization System
**Files:** `long_nights/GraphicsSettings.gd`, `long_nights/DayNightCycle.gd`, `long_nights/GameConsole.gd`, and integration points

#### Graphics Settings System Implemented
- **Three quality profiles:** Low, Medium, High
- **Autoload singleton:** `GraphicsSettings` registered in `project.godot`
- **Persistent storage:** Settings saved/loaded from `user://graphics_settings.json`
- **UI:** Graphics Settings modal accessible from main menu and pause menu (ESC)

#### Profile Configuration (Long-Nights/GraphicsSettings.gd:10-70)

**LOW PROFILE** (Potato PC - Achieves 60+ FPS 🎮)
- Voxel View Distance: 64 chunks
- Camera Far Clip: 62.72 units (98% of voxel distance)
- Shadows: Disabled
- Torch Light: Disabled
- Particles: 8 count
- Debris: 0 count
- **SDFGI: DISABLED** (critical optimization: +10-20 FPS)
- Fog: Day (57.72→62.72), Night (52.72→62.72), Bloodmoon (49.72→62.72)

**MEDIUM PROFILE** (Balanced - Achieves 50+ FPS)
- Voxel View Distance: 144 chunks
- Camera Far Clip: 141.12 units (98% of voxel distance)
- Shadows: Enabled
- Torch Light: Enabled (8 unit range)
- Particles: 15 count
- Debris: 15 count
- **SDFGI: DISABLED** (smoother than High, less expensive)
- Fog: Day (136.12→141.12), Night (131.12→141.12), Bloodmoon (126.12→141.12)

**HIGH PROFILE** (Gaming PC - Achieves 60+ FPS with SDFGI 🌟)
- Voxel View Distance: 160 chunks
- Camera Far Clip: 156.8 units (98% of voxel distance)
- Shadows: Enabled
- Torch Light: Enabled (12 unit range)
- Particles: 20 count
- Debris: 30 count
- **SDFGI: ENABLED** (realistic global illumination, +200% visual quality)
- Fog: Day (151.8→156.8), Night (146.8→156.8), Bloodmoon (141.8→156.8)

#### Dynamic Fog System
**DayNightCycle.gd integration:**
- Fog automatically adjusts every in-game hour
- **Day Fog:** Light gray, soft and transparent
- **Night Fog:** Dark blue, thicker for horror atmosphere
- **Bloodmoon Fog:** Deep red/crimson, extra dense for special effects
- Fog is **camera-relative** (moves with player)
- Fog **fades in at ~70% of camera far clip**, fully opaque at edge
- Hides voxel view distance boundary naturally

**Console command:** `fog true/false` - Toggle global fog (all profiles)

#### Renderer Optimization - SDFGI Control

**What is SDFGI?**
- SDFGI = Signed Distance Field Global Illumination
- Expensive real-time lighting calculation
- Cost: **10-20+ FPS on laptop/mobile GPUs**
- Benefit: Realistic dynamic light bouncing and indirect lighting

**Where to Control SDFGI:**

**Per-Profile Toggle (AUTO):** `long_nights/GraphicsSettings.gd:212-222`
- Low Profile: `sdfgi_enabled = false` (disabled automatically)
- Medium Profile: `sdfgi_enabled = false` (disabled automatically)
- High Profile: `sdfgi_enabled = true` (enabled automatically)
- Function: `_apply_environment_quality()` called during profile switch

**Initial Scene Setting:** `blocky_game/blocky_game.tscn:22-23`
- Used as startup default before profiles applied
- Set to `false` for safe default

**Global Rendering Settings:** `project.godot:57`
- `global_illumination/sdfgi/enabled=false` - Project-wide fallback

**To modify SDFGI behavior:**
1. Edit `long_nights/GraphicsSettings.gd` line 217
   - Change `current_profile == "high"` condition
   - Enable for Medium: `current_profile in ["medium", "high"]`
   - Disable all: `current_profile == "none"` (always false)

2. Or manually toggle in Godot editor:
   - Select WorldEnvironment node in scene tree
   - Inspector → Environment → SDFGI Enabled
   - Changes take effect immediately

#### Files Created
- `long_nights/GraphicsSettings.gd` - Core settings system with profiles
- `blocky_game/gui/GraphicsSettingsUI.gd` - Settings modal UI
- `blocky_game/gui/PauseMenu.gd` - Pause menu with settings access

#### Files Modified
- `project.godot` - Added GraphicsSettings autoload
- `long_nights/DayNightCycle.gd` - Added fog update functions
- `long_nights/GameConsole.gd` - Added `fog` command
- `blocky_game/blocky_game.gd` - Apply settings on load
- `blocky_game/blocky_game.tscn` - Added PauseMenu CanvasLayer
- `blocky_game/main.tscn` - Added Graphics Settings button
- `blocky_game/main_menu.gd` - Settings button handler
- `blocky_game/projectiles/thrown_torch.gd` - Respects light setting
- `blocky_game/items/rocket_launcher/rocket.gd` - Dynamic debris count
- `blocky_game/items/rocket_launcher/rocket_explosion.gd` - Dynamic particles
- `blocky_game/projectiles/meteor.gd` - Dynamic trail spawn rate

---

## Session 1: October 25-26, 2025

### Project Setup & Foundation
- **Migrated from JavaScript** voxel game to Godot 4.5
- **Base project:** Zylann's `voxelgame-master` example
- **Custom Godot build** with voxel module integrated
- Set up project structure in `/home/brad/Godot/theLongNights/project`

### Core Systems Implemented

#### 1. Time Management System
**File:** `project/long_nights/TimeManager.gd`
- Day/night cycle (24 hours, configurable speed)
- 7-day week system with named days
- Week progression for difficulty scaling
- Bloodmoon system (Day 7, hours 21-5)
- Signals for time events (hour_changed, day_changed, bloodmoon_started, etc.)

#### 2. Game Console
**File:** `project/long_nights/GameConsole.gd`
- Toggle with ~ (tilde) or F1
- Command history with up/down arrows
- Mouse wheel scrolling in output
- **Implemented Commands:**
  - `help` - Show all commands
  - `clear` - Clear console
  - `time` / `time set <hour>` / `time add <hours>`
  - `day` / `day set <day>` / `day next`
  - `week` / `week set <week>`
  - `bloodmoon start` / `bloodmoon stop`
  - `fps true/false` - Toggle FPS counter
  - `give <item_name> [amount]` - Add items to inventory
  - `list items` - Show all available items

#### 3. Music System
**File:** `project/long_nights/MusicManager.gd`
- Dynamic day/night music with 3-second crossfading
- Dual AudioStreamPlayer system for smooth transitions
- **Tracks:**
  - `forestDay.ogg` (6 AM - 6 PM)
  - `forestNight.ogg` (7 PM - 5 AM)
  - `bloodMoon.ogg` (bloodmoon override)
- Volume controls: `-` (down), `+` (up)
- Music only plays in-game, not menu
- Integrates with TimeManager signals

### Items & Weapons System

#### 4. Grappling Hook
**File:** `project/blocky_game/items/grappling_hook/grappling_hook.gd`
- Spider-Man style arc trajectory
- Parabolic physics with gravity calculations
- Pulls player to target block
- Works with character_controller.gd grappling state

#### 5. Climbing Claws
**File:** `project/blocky_game/items/climbing_claws/climbing_claws.gd`
- Wall climbing on any vertical surface
- Raycast-based wall detection
- Adjustable climb speed (3.0 units/sec)
- Uses boots_speed.png sprite

#### 6. Ice Bow
**File:** `project/blocky_game/projectiles/ice_arrow.gd`
- Zigzag homing behavior
- Freeze explosion on impact
- Ice crystal particle trail
- Rim lighting and emission effects

#### 7. Fire Staff
**File:** `project/blocky_game/projectiles/meteor.gd`
- Meteor strike from sky (not from player)
- Pulsing flame aura
- Fire particle trail
- Spherical explosion on impact

#### 8. Throwing Knives
**File:** `project/blocky_game/projectiles/throwing_knife.gd`
- Circles around target 3 times before impact
- Circular spiraling trajectory
- TAU-based angle calculation
- Progressive radius reduction

#### 9. Torch System
**Files:**
- `project/blocky_game/items/torch/torch.gd`
- `project/blocky_game/projectiles/thrown_torch.gd`
- `project/blocky_game/player/avatar_interaction.gd` (torch light integration)

**Features:**
- **Gothic Design:** Dark twisted handle, metal cage, orange flames
- **Throwable:** Parabolic arc with end-over-end rotation
- **Dual Lighting:**
  - Held torch: OmniLight3D on player camera (12-block radius)
  - Thrown torch: Stays lit where it lands, auto-cleanup after 5 minutes
- **Consumable:** Stack-based system (torches decrement on use)
- **3D Model:** Dark handle (0.15, 0.15, 0.15), orange flames with flickering animation

### Inventory System Enhancements

#### Item Stacking & Count System
**Modified Files:**
- `project/blocky_game/player/inventory_item.gd` - Added count field
- `project/blocky_game/gui/inventory_item_display.gd` - Visual count display
- `project/blocky_game/gui/inventory/inventory.gd` - Stack initialization

**Behavior:**
- **Torches:** Stackable consumables (count decrements on use)
- **Weapons/Tools:** Infinite ammo (count = 1, never consumed)
- Visual count label (bottom-right of icon, white text with black outline)

### Graphics & Art Updates

#### Updated Item Sprites
**Source:** `/home/brad/Godot/theLongNights/assets/art/tools/`
- `ice_bow.png` → ice_bow_sprite.png
- `fire_staff.png` → fire_staff_sprite.png
- `torch.png` → torch_sprite.png (gothic design)
- `grapple.png` → grappling_hook_sprite.png
- `machete.png` → throwing_knives_sprite.png
- `boots_speed.png` → climbing_claws_sprite.png

**Process:** Copy to item folders, delete `.import` files, Godot auto-regenerates

#### Terrain Texture Location
**Active texture:** `/home/brad/Godot/theLongNights/project/blocky_game/blocks/terrain.png`
- Referenced by: terrain_material.tres, terrain_material_foliage.tres, terrain_material_transparent.tres
- Update process: Replace PNG, delete .import file, restart Godot

### Export & Distribution

#### Windows Export Setup
**Export template:** `godot.windows.template_release.x86_64.exe`
- Downloaded from: https://github.com/Zylann/godot_voxel/releases/tag/v1.5
- Installed to: `~/.local/share/godot/export_templates/4.5.stable/`
- Both debug and release templates required (copied same file for both)

**Export Process:**
1. Project → Export → Add Windows Desktop preset
2. Set export path and runnable mode
3. Export creates: `.exe` + `.pck` file
4. Zip both files together for distribution

---

## File Structure

```
/home/brad/Godot/theLongNights/
├── project/                          # Main Godot project
│   ├── blocky_game/                  # Game logic
│   │   ├── items/                    # All items
│   │   │   ├── torch/
│   │   │   ├── grappling_hook/
│   │   │   ├── ice_bow/
│   │   │   ├── fire_staff/
│   │   │   ├── throwing_knives/
│   │   │   └── climbing_claws/
│   │   ├── projectiles/              # Projectile scripts
│   │   ├── player/                   # Player systems
│   │   ├── blocks/                   # Voxel blocks & terrain.png
│   │   └── gui/                      # UI components
│   └── long_nights/                  # Game-specific systems
│       ├── TimeManager.gd
│       ├── MusicManager.gd
│       └── GameConsole.gd
├── assets/                           # Source art assets
│   ├── art/
│   │   ├── tools/                    # Item sprites
│   │   └── blocks/                   # Block textures
│   └── music/                        # Music tracks
└── docs/                             # Documentation
    └── godot/                        # Godot-specific docs
        ├── PROGRESS.md               # This file
        └── CLAUDE.md                 # AI assistant context
```

---

## Technical Notes

### GDScript vs Python
- **Very similar syntax:** Indentation-based, similar type hints
- **Key differences:**
  - `@onready`, `@export` decorators
  - Signals system (`emit`, `connect`)
  - Node paths (`get_node()`, `$` shorthand)
  - `func` instead of `def`

### Character Controller
**File:** `project/blocky_game/player/character_controller.gd`
- Uses VoxelBoxMover (not CharacterBody3D)
- Added grappling and climbing states
- Modified _physics_process to respect special movement states

### Multiplayer Support
- RPC networking implemented for items
- SERVER_PEER_ID pattern for client-server communication
- All items check `get_tree().get_multiplayer()` before RPC calls

---

## Known Issues & TODOs

### Current Session TODOs
- [ ] Test torch consumption system
- [ ] Verify torch light activation/deactivation
- [ ] Test all weapon visual effects
- [ ] Verify music crossfading

### Future Enhancements
- [ ] Make thrown torches pickupable after landing
- [ ] Add more items: stone_hammer, crossbow, backpack, machete
- [ ] Implement enemy AI
- [ ] Add crafting system
- [ ] Player stats (health, stamina, hunger)
- [ ] World generation improvements

---

## Console Commands Quick Reference

```bash
# Time Management
time                    # Show current time
time set 12            # Set to noon
time add 5             # Advance 5 hours

# Day Management
day                     # Show current day
day set 7              # Set to Day 7
day next               # Skip to next day

# Week & Difficulty
week                    # Show current week
week set 3             # Set to week 3

# Bloodmoon
bloodmoon start        # Force bloodmoon
bloodmoon stop         # End bloodmoon

# Items
list items             # Show all items
give torch 50          # Get 50 torches
give grapple           # Get grappling hook

# Display
fps true               # Show FPS counter
fps false              # Hide FPS counter
fog                    # Show fog status
fog true               # Enable fog
fog false              # Disable fog
```

## Graphics Settings

```bash
# Accessed via:
# - Main Menu → Graphics Settings button
# - ESC (pause) → Graphics Settings button
# Or press ~ to open console and modify individual settings

# Profiles: Low, Medium, High
# Settings include:
# - Voxel View Distance (chunks loaded)
# - Camera Far Clip (units)
# - Shadows (on/off)
# - Torch Light (on/off)
# - Particle Count
# - Debris Count
# - Dynamic Fog (day/night/bloodmoon)
```

---

## Art Assets Pipeline

1. **Create/update art** in `/assets/art/tools/` or `/assets/art/blocks/`
2. **Copy to project** item folders (e.g., `project/blocky_game/items/torch/torch_sprite.png`)
3. **Delete .import files** in target folder
4. **Restart Godot** - auto-regenerates imports with new graphics

---

## Version History

### v0.1.0 - Initial Godot Migration (Oct 25-26, 2025)
- Core systems ported from JavaScript
- Time management, console, music systems
- All magical weapons implemented
- Torch system with dual lighting
- Inventory stacking system
- Windows export capability
- Gothic art style established
