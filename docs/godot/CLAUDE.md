# Claude Code Context - The Long Nights (Godot Remake)

**Last Updated:** October 26, 2025, 12:45 AM
**Project:** The Long Nights - Godot 4.5 Remake
**Developer:** Brad
**AI Assistant:** Claude (Anthropic)

---

## Project Overview

This is a **complete remake** of The Long Nights voxel survival game, originally written in JavaScript, now being rebuilt in **Godot 4.5** with Zylann's voxel module. The project started October 25, 2025.

### Why the Remake?
- Better performance with native engine
- 3D voxel capabilities
- Easier multiplayer networking
- More maintainable codebase
- Better tooling and debugging

---

## Project Locations

### Working Directory
```bash
/home/brad/Godot/theLongNights/project/
```

### Old JavaScript Version (Reference Only)
```bash
/home/brad/Godot/theLongNights.old/
```

### Assets (Source Art)
```bash
/home/brad/Godot/theLongNights/assets/
```

### Godot Executable (Custom Build)
```bash
/home/brad/Godot/godot.linuxbsd.editor.x86_64
```

### Documentation
```bash
/home/brad/Godot/theLongNights/docs/godot/
```

---

## Technology Stack

### Engine & Tools
- **Godot:** 4.5.stable.custom_build.876b29033
- **Voxel Module:** Zylann's godot_voxel v1.5
- **Platform:** Linux (Arch), Windows export support
- **Language:** GDScript 2.0
- **Version Control:** Git

### Key Dependencies
- Custom Godot build with integrated voxel module
- Windows export template: `godot.windows.template_release.x86_64.exe`
- Export templates location: `~/.local/share/godot/export_templates/4.5.stable/`

---

## Architecture & Systems

### Core Autoload Singletons
Located in `project/long_nights/`

1. **TimeManager.gd**
   - Controls day/night cycle
   - Week-based progression
   - Bloodmoon system (Day 7, 21:00-05:00)
   - Signals: hour_changed, day_changed, week_changed, bloodmoon_started, bloodmoon_ended

2. **MusicManager.gd**
   - Dual AudioStreamPlayer crossfading (3 seconds)
   - Day/night track switching
   - Bloodmoon music override
   - Volume controls (-, +, =)

3. **GameConsole** (Node in scene tree)
   - Debug console (~ or F1 to toggle)
   - Command system with history
   - Full command list in PROGRESS.md

### Character Controller
**File:** `project/blocky_game/player/character_controller.gd`
- **IMPORTANT:** Uses `VoxelBoxMover`, NOT `CharacterBody3D`
- Custom physics for voxel terrain
- Special states: `_grappling`, `_climbing`
- Must NOT override velocity during special movement states

### Item System
**Base:** `project/blocky_game/items/item.gd`
**Database:** `project/blocky_game/items/item_db.gd`

**Item Structure:**
```
items/
  └── [item_name]/
      ├── [item_name].gd           # Behavior script
      └── [item_name]_sprite.png   # Inventory icon
```

**Item Types:**
- `TYPE_BLOCK = 0` - Voxel blocks
- `TYPE_ITEM = 1` - Tools, weapons, consumables

**Current Items (IDs):**
- 0: rocket_launcher
- 1: grappling_hook
- 2: climbing_claws
- 3: ice_bow
- 4: fire_staff
- 5: throwing_knives
- 6: torch

### Inventory System
**Main:** `project/blocky_game/gui/inventory/inventory.gd`
**Item Data:** `project/blocky_game/player/inventory_item.gd`

**Features:**
- 9x3 bag + 9x1 hotbar (36 slots total)
- Drag & drop between slots
- Item stacking (torch only)
- Count display on stackable items

**Stacking Rules:**
- **Torches (ID 6):** Stackable, count field used
- **Weapons/Tools:** Infinite ammo, count always 1

### Projectile System
**Location:** `project/blocky_game/projectiles/`

**Pattern:**
```gdscript
extends Node3D

func initialize(start_pos: Vector3, target_pos: Vector3, params...):
    global_position = start_pos
    # Calculate trajectory
    # Set up visuals
```

**Existing Projectiles:**
- `ice_arrow.gd` - Zigzag homing with freeze
- `meteor.gd` - Sky strike with explosion
- `throwing_knife.gd` - Spiral attack
- `thrown_torch.gd` - Parabolic arc with lighting

---

## Important File Paths

### Terrain Texture (Active)
```bash
/home/brad/Godot/theLongNights/project/blocky_game/blocks/terrain.png
```
- Used by: terrain_material.tres, terrain_material_foliage.tres, terrain_material_transparent.tres
- Update: Replace file, delete .import, restart Godot

### Music Files
```bash
/home/brad/Godot/theLongNights/assets/music/
├── forestDay.ogg       # 6 AM - 6 PM
├── forestNight.ogg     # 7 PM - 5 AM
└── bloodMoon.ogg       # Bloodmoon override
```

### Art Assets (Source)
```bash
/home/brad/Godot/theLongNights/assets/art/
├── tools/              # Item sprites
└── blocks/             # Block textures
```

---

## Coding Conventions

### GDScript Style
```gdscript
# Variables
var _private_var := value
var public_var : Type = value

# Functions
func _private_function() -> void:
    pass

func public_function(param: Type) -> ReturnType:
    return value

# Constants
const CONSTANT_NAME = value
```

### Node References
```gdscript
# Preferred: @onready
@onready var _node : Type = get_node("Path")

# Scene tree navigation
var terrain = get_node("/root/Main/Game/VoxelTerrain")
var inventory = get_node_or_null("/root/Main/Game/Avatar/Head/Inventory")
```

### Signals
```gdscript
# Declaration
signal event_name
signal event_with_params(param1: Type, param2: Type)

# Emission
event_name.emit()
event_with_params.emit(value1, value2)

# Connection
signal_source.signal_name.connect(_on_signal_name)
```

### Multiplayer RPC Pattern
```gdscript
const SERVER_PEER_ID = 1

func use(trans: Transform3D):
    var mp := get_tree().get_multiplayer()
    if mp.has_multiplayer_peer() and not mp.is_server():
        rpc_id(SERVER_PEER_ID, &"receive_use", trans)
    else:
        _use(trans)

@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D):
    _use(trans)
```

---

## Common Patterns

### Parabolic Arc Trajectory
```gdscript
# Calculate flight time
var horizontal_dist = Vector2(to_target.x, to_target.z).length()
var flight_time = horizontal_dist / throw_power

# Calculate velocities
var horizontal_dir = Vector3(to_target.x, 0, to_target.z).normalized()
var horizontal_vel = horizontal_dir * throw_power

# Vertical with arc height
var arc_height = 3.0
var vertical_vel = (vertical_dist + arc_height + 0.5 * GRAVITY * flight_time * flight_time) / flight_time

var initial_velocity = Vector3(horizontal_vel.x, vertical_vel, horizontal_vel.z)
```

### Voxel Raycasting
```gdscript
var terrain_tool = _terrain.get_voxel_tool()
terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE
var hit = terrain_tool.raycast(origin, direction, max_distance)

if hit != null:
    var hit_pos = Vector3(hit.position)  # Convert Vector3i to Vector3
    var previous_pos = Vector3(hit.previous_position)
```

### Creating 3D Meshes at Runtime
```gdscript
# Create mesh instance
var mesh_inst = MeshInstance3D.new()
var mesh = CylinderMesh.new()
mesh.radius = 0.1
mesh.height = 0.5
mesh_inst.mesh = mesh

# Create material
var mat = StandardMaterial3D.new()
mat.albedo_color = Color(1.0, 0.5, 0.2)
mat.emission_enabled = true
mat.emission = Color(1.0, 0.4, 0.0)
mat.emission_energy_multiplier = 3.0
mesh_inst.material_override = mat

# Add to scene
add_child(mesh_inst)
```

### Dynamic Lighting
```gdscript
var light = OmniLight3D.new()
light.light_color = Color(1.0, 0.5, 0.2)
light.light_energy = 2.0
light.omni_range = 12.0
light.omni_attenuation = 0.6
light.shadow_enabled = true
add_child(light)
```

---

## Art Asset Pipeline

### Item Sprites
1. Create/update sprite in `/assets/art/tools/[name].png`
2. Copy to `/project/blocky_game/items/[item_name]/[item_name]_sprite.png`
3. Delete corresponding `.import` file
4. Restart Godot (or use Project → Reload Current Project)

### Block Textures
1. Update in `/assets/art/blocks/`
2. Copy to `/project/blocky_game/blocks/terrain.png`
3. Delete `terrain.png.import`
4. Restart Godot

### Current Art Style
- **Gothic aesthetic** (not cartoon)
- Dark handles/wood tones (Color ~0.15, 0.15, 0.15)
- Bright orange/yellow flames (Color 1.0, 0.5, 0.2)
- Metal accents with metallic = 0.8

---

## Export & Distribution

### Windows Export Process
1. **Ensure templates installed:**
   - Location: `~/.local/share/godot/export_templates/4.5.stable/`
   - Files needed: `windows_release_x86_64.exe`, `windows_debug_x86_64.exe`

2. **In Godot Editor:**
   - Project → Export → Add → Windows Desktop
   - Set export path (e.g., `/home/brad/exports/windows/TheLongNights.exe`)
   - Runnable: ✓
   - Export Mode: Release
   - Click "Export Project..."

3. **Distribution:**
   - Zip together: `TheLongNights.exe` + `TheLongNights.pck`
   - Both files must stay in same folder
   - Send zip to Windows users

### Command Line Export (Alternative)
```bash
cd /home/brad/Godot/theLongNights/project
/home/brad/Godot/godot.linuxbsd.editor.x86_64 --export-release "Windows Desktop" /path/to/export.exe
```

---

## Console Commands (For Testing)

### Essential Commands
```bash
# Jump to specific times
time set 12        # Noon
time set 21        # 9 PM (bloodmoon start)
time set 6         # 6 AM (day music)

# Test progression
day set 7          # Bloodmoon day
week set 5         # Higher difficulty

# Get items quickly
give torch 50      # 50 torches
give grapple       # Grappling hook
list items         # See all items
```

---

## Working with Claude (AI Assistant)

### Best Practices
1. **Always specify exact file paths** - Claude has access to the full filesystem
2. **Reference line numbers** when discussing code (e.g., "avatar_interaction.gd:105")
3. **Provide context** about which system you're working on
4. **Check PROGRESS.md** before asking implementation questions

### What Claude Can Do
- Read/write files in the project
- Execute bash commands
- Search codebase with grep/glob
- Run Godot from command line (background processes)
- Create/modify GDScript files
- Update documentation

### What Claude Cannot Do (Currently)
- Open Godot GUI directly
- Click buttons in Godot editor
- See visual output (screenshots help!)
- Run the game and play-test
- Access files outside `/home/brad/Godot/theLongNights/`

---

## Graphics Settings System

### Overview
Adaptive graphics settings for multiple hardware tiers. Located in `long_nights/GraphicsSettings.gd` (autoload singleton).

### Three Quality Profiles: Low / Medium / High

**Settings Configuration Location:** `long_nights/GraphicsSettings.gd:10-70`

#### Low Profile (Potato PC Optimization)
```gdscript
"voxel_viewer_distance": 64      # Terrain loads in 64-unit radius
"camera_far_clip": 62.7          # 98% of voxel distance
"directional_light_shadows": false
"torch_light_enabled": false
"particle_count": 8
"debris_count": 0
```

**Fog Settings (starts fading at 70% of camera clip):**
- Day: 44.0 → 62.7 units
- Night: 30.0 → 62.7 units
- Bloodmoon: 25.0 → 62.7 units (deeper red horror effect)

#### Medium Profile (Balanced)
```gdscript
"voxel_viewer_distance": 112     # Terrain loads in 112-unit radius
"camera_far_clip": 109.8         # 98% of voxel distance
"directional_light_shadows": true
"torch_light_enabled": true (8.0 range)
"particle_count": 15
"debris_count": 15
```

**Fog Settings:**
- Day: 77.0 → 109.8 units
- Night: 55.0 → 109.8 units
- Bloodmoon: 44.0 → 109.8 units

#### High Profile (Gaming PC)
```gdscript
"voxel_viewer_distance": 128     # Terrain loads in 128-unit radius
"camera_far_clip": 125.4         # 98% of voxel distance
"directional_light_shadows": true
"torch_light_enabled": true (12.0 range)
"particle_count": 20
"debris_count": 30
```

**Fog Settings:**
- Day: 88.0 → 125.4 units
- Night: 63.0 → 125.4 units
- Bloodmoon: 50.0 → 125.4 units

### How Fog Works
- **Fog is camera-relative** (moves with player)
- **Fog starts fading in at ~70% of camera far clip**
- **Fog becomes fully opaque at camera far clip boundary**
- **Hides voxel view distance edge** naturally with atmosphere
- **Dynamic day/night colors:** Light gray (day), dark blue (night), deep red (bloodmoon)

### Accessing Graphics Settings in Code
```gdscript
# Get current profile name
var profile = GraphicsSettings.get_current_profile()

# Get specific setting
var voxel_distance = GraphicsSettings.get_setting("voxel_viewer_distance")
var camera_clip = GraphicsSettings.get_setting("camera_far_clip")

# Check fog status
if GraphicsSettings.get_fog_enabled():
    # Fog is active

# Fog getters
var day_start = GraphicsSettings.get_day_fog_start()
var night_density = GraphicsSettings.get_night_fog_end()
```

### Console Commands
```bash
# Switch profiles
# (Uses Graphics Settings button in main menu or pause menu)

# Fog control
fog true                          # Enable fog
fog false                         # Disable fog
fog                              # Show current fog status

# Testing different distances
day set 6                        # Daytime fog
day set 21                       # Nighttime fog
day set 7 && bloodmoon start    # Bloodmoon horror fog
```

### Files Modified for Graphics Settings
- `long_nights/GraphicsSettings.gd` - Core system, profiles, fog getters
- `long_nights/DayNightCycle.gd` - Applies fog based on time
- `long_nights/GameConsole.gd` - Fog command
- `blocky_game/blocky_game.gd` - Applies settings on game load
- `blocky_game/projectiles/thrown_torch.gd` - Respects torch light setting
- `blocky_game/items/rocket_launcher/rocket.gd` - Dynamic debris count
- `blocky_game/items/rocket_launcher/rocket_explosion.gd` - Dynamic particles
- `blocky_game/projectiles/meteor.gd` - Dynamic trail spawn rate
- `blocky_game/main.tscn` - Settings button on main menu
- `blocky_game/main_menu.gd` - Settings button handler
- `blocky_game/blocky_game.tscn` - PauseMenu CanvasLayer
- `blocky_game/gui/PauseMenu.gd` - Pause menu with settings access
- `blocky_game/gui/GraphicsSettingsUI.gd` - Settings UI modal
- `project.godot` - GraphicsSettings autoload registration

---

## Known Issues & Limitations

### Current Session
- Thrown torches not yet pickupable (TODO in thrown_torch.gd:128)
- Climbing claws may need wall detection tuning
- Music volume mute (=) not implemented yet
- Graphics settings may need fog density tuning for optimal visuals

### Godot/Voxel Module
- VoxelBoxMover has different API than CharacterBody3D
- Raycasts return Vector3i, must convert to Vector3
- Template version must match custom build version exactly

---

## Development Workflow

### Typical Session
1. Start Godot: `/home/brad/Godot/godot.linuxbsd.editor.x86_64`
2. Open project: `/home/brad/Godot/theLongNights/project/`
3. Press F5 to run game
4. Press ~ or F1 for console
5. Test with console commands
6. Update PROGRESS.md when implementing features

### File Editing
- **Via Claude:** Files updated directly in filesystem
- **Via Godot:** Use built-in script editor
- **External:** Any text editor (VSCode, vim, etc.)
- Godot auto-reloads changed files

### Testing Multiplayer
```bash
# Host (server + client)
cd /home/brad/Godot/theLongNights/project
/home/brad/Godot/godot.linuxbsd.editor.x86_64 --server

# Client
/home/brad/Godot/godot.linuxbsd.editor.x86_64 --client
```

---

## Quick Reference

### File Extensions
- `.gd` - GDScript files
- `.tscn` - Godot scene files (text format)
- `.tres` - Godot resource files (text format)
- `.import` - Godot import metadata (auto-generated, can delete to force reimport)

### Important Godot Concepts
- **Node:** Base unit in scene tree
- **Scene:** Collection of nodes saved as .tscn
- **Autoload:** Global singleton nodes
- **Signal:** Event system for decoupled communication
- **@onready:** Deferred node initialization
- **@export:** Expose variable in inspector

### Color Format (for code)
```gdscript
Color(r, g, b)       # 0.0 to 1.0
Color(r, g, b, a)    # With alpha
Color("#RRGGBB")     # Hex string
```

### Transform3D Structure
```gdscript
trans.origin         # Vector3 position
trans.basis          # Basis (rotation/scale)
trans.basis.z        # Forward direction
-trans.basis.z       # Direction camera faces
```

---

## Next Session Priorities

### Testing Needed
- [ ] Torch consumption (use torch, verify count decrements)
- [ ] Torch light activation (select torch in hotbar)
- [ ] All weapon effects (ice bow, fire staff, knives)
- [ ] Music crossfading (wait for time transitions)
- [ ] Windows export (test on Windows PC)

### Documentation
- [x] Update PROGRESS.md
- [x] Update CLAUDE.md
- [ ] Create item reference guide
- [ ] Document multiplayer setup

### Art
- [ ] More item sprites (stone_hammer, crossbow, backpack)
- [ ] Update terrain.png with new block textures
- [ ] Create particle effects for weapons

### Features
- [ ] Enemy AI basic implementation
- [ ] Health/damage system
- [ ] Hunger/stamina systems
- [ ] Basic crafting

---

## Useful Commands for Claude

```bash
# Find files
find /home/brad/Godot/theLongNights/project -name "*.gd" | grep [pattern]

# Search code
grep -r "pattern" /home/brad/Godot/theLongNights/project/blocky_game/

# List specific directory
ls -la /home/brad/Godot/theLongNights/project/blocky_game/items/

# Check Godot version
/home/brad/Godot/godot.linuxbsd.editor.x86_64 --version

# Run Godot in background (for testing)
cd /home/brad/Godot/theLongNights/project && /home/brad/Godot/godot.linuxbsd.editor.x86_64 --path . res://blocky_game/main.tscn &
```

---

## Contact & Resources

### Developer
- **Name:** Brad
- **Location:** Arch Linux
- **Timezone:** Midnight = session end time

### Official Resources
- **Godot Docs:** https://docs.godotengine.org/en/stable/
- **Voxel Module:** https://github.com/Zylann/godot_voxel
- **GDScript Reference:** https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/

### This Project
- **Documentation:** `/home/brad/Godot/theLongNights/docs/godot/`
- **Progress Tracking:** PROGRESS.md
- **AI Context:** CLAUDE.md (this file)

---

**Remember:** This is a fresh start with a new engine. We're building systems from scratch, not porting line-by-line. Focus on Godot best practices and clean architecture over direct JavaScript translations.

**Current Status:** Core systems functional, ready for gameplay implementation!
