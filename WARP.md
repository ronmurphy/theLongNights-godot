# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

---

## Project Overview

**The Long Nights** - Voxel survival game rebuilt in Godot 4.5 from a JavaScript codebase. Features procedural world generation, voxel-based building, magical weapons, companion system, and day/night cycle with bloodmoon events.

**Engine:** Godot 4.5 with Zylann's Voxel Module v1.5  
**Language:** GDScript 2.0  
**Platform:** Windows (primary development on Linux/Arch)

---

## Essential Commands

### Running the Game
This is a Godot project. On Windows, you need to open it with the Godot editor:
- Open Godot 4.5 editor
- Import/open the `project/` directory
- Press F5 to run the game

**Note:** This project requires a custom Godot build with Zylann's voxel module. Standard Godot builds will not work.

### In-Game Console
Press `~` (tilde) or `F1` to open the debug console. Essential commands:

```bash
# Time & Day Management
time set 12              # Set to noon
day set 7                # Set to Day 7 (bloodmoon day)
week set 3               # Set to week 3

# Items & Testing
give torch 50            # Give 50 torches
give machete             # Give machete tool
list items               # List all available items

# Creative Mode
creative on              # Enable creative mode (instant breaking, all blocks)
creative off             # Return to survival mode

# Graphics & Debug
fps true                 # Show FPS counter
fog true/false           # Toggle fog rendering
```

### Terrain Mapper Tool
Press `Ctrl+T` in-game to open the Terrain Mapper - a visual tool for creating new block textures and getting UV coordinates from the terrain atlas.

---

## Architecture Overview

### Autoload Singletons (Global Systems)
Located in `project/long_nights/`, registered in `project.godot`:

- **TimeManager.gd** - Day/night cycle, week progression, bloodmoon events
- **MusicManager.gd** - Crossfading music system with day/night/bloodmoon tracks
- **WorldManager.gd** - World save/load, seed management, Halloween detection
- **GraphicsSettings.gd** - Quality profiles (Low/Medium/High) with adaptive rendering
- **PlayerData.gd** - Player stats, name, race/gender from character quiz
- **CompanionManager.gd** - Companion stats, name, hunting system integration
- **DialogueManager.gd** - Visual novel-style dialogue with portraits and variables
- **HuntingSystem.gd** - Companion hunting mechanics with loot generation
- **GrassShaderController.gd** - Wind effects on foliage
- **GameConsole** - Debug console (not autoload, added to scene tree)

### Scene Structure
```
main.tscn (Entry Point)
├── CharacterQuiz (Character creation flow)
└── blocky_game.tscn (Main Game Scene)
    ├── VoxelTerrain (Voxel world with generator)
    ├── Avatar (Player with CharacterBody3D)
    │   ├── character_controller.gd (Uses VoxelBoxMover, not CharacterBody3D)
    │   ├── avatar_interaction.gd (Block mining, placement, item usage)
    │   └── Inventory + Hotbar UI
    ├── WorldEnvironment (Day/night lighting, fog, SDFGI)
    ├── PartyUI (Companion management interface)
    └── PauseMenu (Settings access)
```

### Core Systems Architecture

#### 1. Voxel System (Zylann Module)
- **Generator:** `blocky_game/generator/generator.gd` - Procedural terrain with heightmap, caves, ores, foliage
- **Block Library:** `blocky_game/blocks/blocks.gd` - Block definitions (47 block types)
- **Voxel Library:** `blocky_game/blocks/voxel_library.tres` - 3D models and collision
- **Terrain Texture:** `blocky_game/blocks/terrain.png` - 16×16 texture atlas (256 slots)

**Key Insight:** Blocks use OBJ models with UV coordinates mapped to the shared terrain atlas. Multi-texture blocks (like pumpkin) assign different UV coords per face.

#### 2. Item & Inventory System
- **Base Class:** `blocky_game/items/item.gd` - All items extend this
- **Database:** `blocky_game/items/item_db.gd` - Central item registry (20 items)
- **Structure:** Each item has folder: `items/{name}/{name}.gd` + `{name}_sprite.png`
- **Item Types:** 
  - `TYPE_BLOCK = 0` - Voxel blocks for building
  - `TYPE_ITEM = 1` - Tools, weapons, consumables

**Stacking:** Only torches stack (count field). Weapons have infinite ammo (count always 1).

#### 3. Character Controller Physics
**CRITICAL:** Uses `VoxelBoxMover`, NOT `CharacterBody3D`!

Located: `blocky_game/player/character_controller.gd`

- Custom physics for voxel terrain collision
- Special states: `_grappling`, `_climbing`
- **Never override velocity during special movement states**

#### 4. Projectile System Pattern
All projectiles follow this pattern:

```gdscript
extends Node3D

func initialize(start_pos: Vector3, target_pos: Vector3, params...):
    global_position = start_pos
    # Calculate trajectory
    # Set up visuals (mesh, particles, lights)

func _process(delta):
    # Update position/rotation
    # Check collisions
    # Handle impact
```

Examples: `ice_arrow.gd`, `meteor.gd`, `throwing_knife.gd`, `thrown_torch.gd`

#### 5. Companion & Entity System
- **Base Classes:** `entity_base.gd`, `ground_entity.gd`, `flying_entity.gd`
- **Companion:** `entities/companion.gd` - Player ally with hunting AI
- **Enemies:** Ghost, Goblin Grunt, Troglodyte, Rat
- **Hunting Mode:** Companion wanders 20-80 blocks, discovers items hourly (60% chance)

#### 6. World Generation & Persistence
- **Seed-based:** All generation uses world seed from `WorldManager`
- **Save Location:** `user://save/` (Windows: `%APPDATA%\Godot\app_userdata\The Long Nights\save\`)
- **World Config:** `user://save/world.config` - JSON with seed, position, time, Halloween flag
- **Terrain Streaming:** Voxel module handles chunk loading/unloading automatically

#### 7. Graphics Quality System
Three profiles dynamically adjust:
- Voxel view distance (64 / 112 / 128 chunks)
- Camera far clip (synced to 98% of voxel distance)
- Shadows, torch lights, particle counts
- SDFGI (disabled in Low/Medium, enabled in High)
- Dynamic fog (day/night/bloodmoon color schemes)

**Fog Detail:** Camera-relative, fades in at ~70% of far clip, hides chunk loading edge naturally.

---

## GDScript Conventions

### Naming & Style
```gdscript
# Private variables/functions: underscore prefix
var _private_var := 0
func _private_function() -> void:
    pass

# Public: no prefix
var public_var: int = 0
func public_function() -> int:
    return 0

# Constants: UPPER_SNAKE_CASE
const MAX_HEALTH = 100
```

### Type Hints (Required for Performance)
```gdscript
# Variable declarations
var velocity: Vector3 = Vector3.ZERO
var _health: int = 100

# Function signatures
func calculate_damage(attacker: Node3D, multiplier: float) -> int:
    return int(base_damage * multiplier)
```

### Signals
```gdscript
# Declaration
signal health_changed(old_value: int, new_value: int)

# Emission
health_changed.emit(old_hp, new_hp)

# Connection (Godot 4.x syntax)
player.health_changed.connect(_on_player_health_changed)
```

### Node References
```gdscript
# Preferred: @onready with type hints
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _inventory: Inventory = get_node("/root/Main/Game/Avatar/Inventory")

# Scene tree navigation
var terrain = get_node("/root/Main/Game/VoxelTerrain")
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

### Parabolic Arc Trajectory (Throwing)
```gdscript
var horizontal_dist = Vector2(to_target.x, to_target.z).length()
var flight_time = horizontal_dist / throw_power

var horizontal_dir = Vector3(to_target.x, 0, to_target.z).normalized()
var horizontal_vel = horizontal_dir * throw_power

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
    var block_id = terrain_tool.get_voxel(hit.position)
```

### Creating Runtime 3D Meshes
```gdscript
var mesh_inst = MeshInstance3D.new()
var mesh = CylinderMesh.new()
mesh.radius = 0.1
mesh.height = 0.5
mesh_inst.mesh = mesh

var mat = StandardMaterial3D.new()
mat.albedo_color = Color(1.0, 0.5, 0.2)
mat.emission_enabled = true
mat.emission = Color(1.0, 0.4, 0.0)
mat.emission_energy_multiplier = 3.0
mesh_inst.material_override = mat

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

## Block Creation Workflow

Full guide: `docs/godot/BLOCK_CREATION_COMPLETE_GUIDE.md`

### Quick Steps:
1. **Add texture** to `blocky_game/blocks/terrain.png` (16×16 grid)
2. **Press Ctrl+T** in-game to open Terrain Mapper
3. **Click grid cell** containing texture → copy UV coordinates
4. **Create OBJ file** in `blocky_game/blocks/{name}/{name}.obj`
   - Single-texture: Use `dirt.obj` as template
   - Multi-texture: Use `pumpkin.obj` as template
5. **Register in blocks.gd:** Add `_create_block()` call
6. **Add to voxel_library.tres** (via Godot Inspector)
7. **Add to generator.gd** for world spawning (optional)

---

## Special Features

### Halloween System
- Auto-detects October 31st on world creation
- Sets `is_halloween` flag in world config (persists)
- Halloween worlds spawn pumpkins at 40% rate (vs 5% normal)
- Located: `long_nights/WorldManager.gd` + `generator.gd`

### Companion Hunting
- Send companion to hunt for 4, 8, or 24 in-game hours
- Discovers items hourly (60% chance)
- Race-based loot tables:
  - Goblins: Find ores/materials only
  - Elves: Find berries/honey (3× chance)
  - Dwarves: Find eggs/rabbit (2× chance)
  - Humans: Balanced across all food
- Returns with inventory of items
- Located: `long_nights/HuntingSystem.gd`

### Dialogue System
- Visual novel-style with character portraits
- Variable substitution: `{{player_name}}`, `{{companion_name}}`
- Progress tracking (one-time dialogues with `"once": true`)
- Manual advance: X key or left-click
- JSON format in `assets/data/dialogues/`
- Located: `long_nights/DialogueManager.gd`, `blocky_game/gui/dialogue/`

### Falling Leaf Particles
- When breaking leaves with machete/tree_feller
- Samples actual color from terrain.png texture
- Spawns 8 particles that fall 2 blocks over 1 second
- Only on non-Low graphics settings
- Located: `blocky_game/player/avatar_interaction.gd:_spawn_falling_particles()`

### Creative Mode
- Toggle with `creative on/off` console command
- Backs up survival inventory, loads creative loadout (all blocks)
- Instant block breaking, no collection
- Restores survival inventory on exit
- Located: `blocky_game/player/avatar_interaction.gd:set_creative_mode()`

---

## Art Asset Pipeline

### Item Sprites
1. Create 16×16 PNG in `assets/art/tools/`
2. Copy to `project/blocky_game/items/{name}/{name}_sprite.png`
3. Delete `.import` file
4. Reload Godot project or restart editor

### Block Textures
1. Edit `assets/art/blocks/` (16×16 per block)
2. Composite into `project/blocky_game/blocks/terrain.png`
3. Delete `terrain.png.import`
4. Restart Godot

**Art Style:** Gothic aesthetic, dark tones, bright flame/magic effects

---

## File Locations Reference

### Configuration
- **Project Settings:** `project/project.godot` - Autoloads, physics, rendering
- **Export Presets:** `project/export_presets.cfg` - Windows export config
- **World Seed/Save:** `user://save/world.config` - JSON world data

### Core Scripts
- **Autoloads:** `project/long_nights/*.gd`
- **Player:** `project/blocky_game/player/`
- **Items:** `project/blocky_game/items/`
- **Entities:** `project/blocky_game/entities/`
- **Generator:** `project/blocky_game/generator/generator.gd`

### Assets
- **Music:** `assets/music/` - OGG files (forestDay, forestNight, bloodMoon)
- **Art:** `assets/art/` - Source PNGs before importing
- **Dialogues:** `assets/data/dialogues/` - JSON dialogue data

### Documentation
- **Progress Log:** `docs/godot/PROGRESS.md` - Session-by-session implementation log
- **Claude Context:** `docs/godot/CLAUDE.md` - Comprehensive AI assistant context (Linux paths)
- **Guides:** `docs/godot/BLOCK_CREATION_COMPLETE_GUIDE.md`, etc.

---

## Known Issues & Limitations

### Godot/Voxel Module
- VoxelBoxMover has different API than CharacterBody3D (not compatible)
- Raycasts return Vector3i, must convert to Vector3
- Transparent blocks (grass, dead_shrub) are non-targetable by raycasts
- Custom Godot build required - standard builds lack voxel module

### Current TODOs
- Thrown torches not yet pickupable after landing
- Music volume mute (=) key not implemented
- Enemy AI needs expansion
- Health/damage system incomplete
- Crafting system planned but not implemented

---

## Testing Notes

### Console Testing Workflow
```bash
# Test time progression
time set 21           # Nighttime
day set 7             # Bloodmoon day
bloodmoon start       # Force bloodmoon

# Test items
give torch 10
give machete
creative on           # Test creative mode

# Test graphics
fps true
fog false             # Disable fog to test view distance
```

### Multiplayer Testing
Not currently set up for easy testing. RPC infrastructure exists but requires manual server/client launch.

---

## Windows-Specific Notes

This codebase was developed on Linux (Arch). Key differences for Windows:
- Godot paths use forward slashes internally (`res://`)
- Save location: `%APPDATA%\Godot\app_userdata\The Long Nights\`
- PowerShell instead of bash for CLI commands
- Must use custom Godot build with voxel module (cannot use official Windows build)

---

## Dependencies & Build Requirements

**Required:**
- Godot 4.5 custom build with Zylann's voxel module v1.5
- Windows export templates matching custom build version
- Jolt Physics (set in project.godot)

**Custom Build Sources:**
- Godot: https://github.com/Zylann/godot_voxel
- Export templates must match exact custom build version

---

## Additional Context from Rules

### From CLAUDE.md (Linux Paths Adapted)
- Original Linux paths: `/home/brad/Godot/theLongNights/`
- Windows equivalent: `C:\Users\Brad\Documents\Godot\theLongNights\`
- Old JavaScript version exists at `theLongNights.old/` (reference only)
- Custom Godot executable on Linux: `godot.linuxbsd.editor.x86_64` (not applicable to Windows)

### Project History
- **Started:** October 25, 2025
- **Current Session:** October 31, 2025 (Session 5)
- **Origin:** Complete remake of JavaScript voxel game
- **Reason for Remake:** Better performance, 3D voxel capabilities, easier multiplayer, maintainable codebase

---

## Quick Reference

### Godot 4.x Changes from 3.x
- `@onready` replaces `onready var`
- `signal_name.emit()` replaces `emit_signal("signal_name")`
- `signal_name.connect()` replaces `connect("signal_name", ...)`
- `Node.call_deferred()` syntax unchanged
- `VoxelBuffer.CHANNEL_TYPE` for voxel data access

### Important Godot Concepts
- **Node:** Base unit in scene tree
- **Scene:** Collection of nodes saved as .tscn
- **Autoload:** Global singleton nodes
- **Signal:** Event system for decoupled communication
- **@onready:** Deferred node initialization (after `_ready()`)
- **@export:** Expose variable in inspector

### Transform3D Structure
```gdscript
trans.origin         # Vector3 position
trans.basis          # Basis (rotation/scale)
trans.basis.z        # Forward direction
-trans.basis.z       # Direction camera faces
```
