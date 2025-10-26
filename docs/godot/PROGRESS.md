# The Long Nights - Godot 4.5 Remake Progress

**Project Start:** October 25, 2025
**Engine:** Godot 4.5 with Zylann's Voxel Module (v1.5)
**Platform:** Linux (Arch), Windows export capability

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
