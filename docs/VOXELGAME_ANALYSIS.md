# Voxelgame Codebase Analysis

**Date**: October 25, 2025
**Purpose**: Understanding what we inherited to build The Long Nights

---

## Project Overview

**What It Is**: A Minecraft-like demo built with Godot 4.5 + Zylann's Voxel Module
**Total Files**: 53 scripts and scenes in `blocky_game/`

---

## Core Architecture

### Main Entry Point
- **`main.tscn`** / **`main.gd`** - Launcher with menu system
  - Handles singleplayer, client, and server modes
  - Creates instances of `BlockyGame`

### Game Core
- **`blocky_game.tscn`** / **`blocky_game.gd`** - The actual game instance
  - Network modes: Singleplayer, Client, Host
  - Contains VoxelTerrain node (from C++ module)
  - Manages players, lighting, random ticks, water
  - **KEY**: This is where we'll integrate TimeManager!

---

## Systems Breakdown

### 1. Voxel Terrain System
**Files**: Uses C++ VoxelTerrain node
- `VoxelTerrain` - Main terrain node (from module)
- `VoxelLibrary` - Block definitions (res://blocky_game/blocks/voxel_library.tres)
- `generator/` - Terrain generation scripts

**Features**:
- Infinite terrain generation
- Chunk-based rendering
- Multithreaded meshing
- LOD support (level of detail)
- Save/load support

### 2. Block System
**Location**: `blocky_game/blocks/`

**Defined Blocks**:
```gdscript
- air          (ID 0, transparent)
- dirt         (basic block)
- grass        (has top texture)
- log          (rotatable, axial)
- planks       (crafted wood)
- glass        (transparent)
- leaves       (transparent, foliage)
- tall_grass   (decorative)
- dead_shrub   (decorative)
- stairs       (complex geometry)
- rail         (custom behavior, has script)
- water        (fluid, special handling)
```

**Block Properties**:
- `name` - Display name
- `gui_model` - 3D model for inventory (.obj files)
- `rotation_type` - NONE, AXIAL, Y, CUSTOM
- `voxels` - Array of voxel IDs (for rotations)
- `transparent` - Boolean
- `directory` - Path to block assets

**Files**:
- `blocks.gd` - Block registry and definitions
- `block.gd` - Individual block class
- `voxel_library.tres` - Voxel module library resource
- Each block folder contains: textures, models, scripts

### 3. Player System
**Location**: `blocky_game/player/`

**Components**:
- `character_avatar.tscn` - Local player
- `remote_character.tscn` - Multiplayer other players
- `character_controller.gd` - Movement physics
- `avatar_camera.gd` - First-person camera
- `avatar_interaction.gd` - Block breaking/placing
- `remote_interaction.gd` - Multiplayer sync
- `inventory_item.gd` - Held item in hand

**Features**:
- First-person movement (WASD)
- Jump, sprint, crouch
- Fly mode (toggle with F)
- Block interaction (break/place)
- Inventory management
- Hand-held item rendering

### 4. GUI System
**Location**: `blocky_game/gui/`

**Components**:
- `hotbar/` - Bottom inventory bar (9 slots)
- `inventory/` - Full inventory screen
- `block_sprite_generator.gd` - Generates 2D block icons
- `inventory_item_display.gd` - Item rendering in GUI
- `center.gd` - Crosshair

**Features**:
- Hotbar (1-9 keys to select)
- Full inventory (press I or E)
- Drag-and-drop items
- Auto-generated block sprites
- Crosshair center marker

### 5. Items System
**Location**: `blocky_game/items/`

**Components**:
- `item.gd` - Base item class
- `item_db.gd` - Item database/registry
- `rocket_launcher/` - Example complex item (can remove)

**Features**:
- Stackable items
- Usable items
- Weapons/tools

### 6. Generator System
**Location**: `blocky_game/generator/`

**Files**:
- Terrain generation scripts
- Structure placement (trees, etc.)
- `structure.gd` - Structure definition

**Features**:
- Noise-based terrain
- Biome support
- Structure generation (trees)
- Can be extended for sky temples!

### 7. Water System
**File**: `blocky_game/water.gd`

**Features**:
- Fluid simulation
- Water spread/flow
- Water rendering

### 8. Random Ticks
**File**: `blocky_game/random_ticks.gd`

**Features**:
- Updates random blocks over time
- Grass spreading
- Can be used for crop growth!

### 9. Multiplayer
**Files**:
- `blocky_game.gd` (network setup)
- `upnp_helper.gd` (port forwarding)
- `remote_character.gd` (other players)

**Features**:
- Host/Join servers
- Player synchronization
- Voxel synchronization
- **Note**: Can keep or remove for single-player only

### 10. Debug System
**File**: `blocky_game/debug_info.gd`

**Features**:
- FPS counter
- Position display
- Memory stats
- Voxel stats (visible in your screenshot!)

---

## File/Folder Structure

```
blocky_game/
├── main.tscn              # Menu entry point
├── main.gd
├── blocky_game.tscn       # Game scene ← INTEGRATE TimeManager HERE
├── blocky_game.gd         # Game logic
├── blocks/                # Block definitions
│   ├── blocks.gd          # Block registry
│   ├── voxel_library.tres # Voxel module data
│   ├── dirt/
│   ├── grass/
│   ├── log/
│   └── ... (12 block types)
├── player/                # Player controller
│   ├── character_avatar.tscn
│   ├── character_controller.gd
│   ├── avatar_interaction.gd
│   └── ...
├── gui/                   # UI elements
│   ├── hotbar/
│   ├── inventory/
│   └── ...
├── items/                 # Item system
│   ├── item_db.gd
│   └── rocket_launcher/   ← Can remove
├── generator/             # World generation
│   └── structure.gd
├── water.gd               # Water simulation
├── random_ticks.gd        # Block updates
├── debug_info.gd          # Debug overlay
└── upnp_helper.gd         # Multiplayer networking
```

---

## What We Can Use for The Long Nights

### ✅ Keep As-Is
1. **Voxel terrain system** - Perfect, works great
2. **Player controller** - Movement feels good
3. **Block breaking/placing** - Exactly what we need
4. **Inventory/hotbar** - Already works
5. **Block system** - Easy to add new blocks
6. **Generator system** - Can extend for temples
7. **Random ticks** - Perfect for farming
8. **Debug info** - Helpful during development

### 🔧 Modify
1. **GUI** - Reskin for The Long Nights aesthetic
2. **Crafting** - Replace with material-selection system
3. **Blocks** - Replace with our textures from `assets/`
4. **Items** - Add weapons, tools, food

### ➕ Add (Our Features)
1. **TimeManager** - Day/night, bloodmoon cycle
2. **Enemy system** - Billboard sprites
3. **WaveManager** - Bloodmoon spawning
4. **Companion NPC** - Follower with dialogue
5. **DialogueSystem** - Visual novel style
6. **Boss system** - Ghost King
7. **Kill counter** - For final boss twist
8. **Sky temples** - Floating structures
9. **Food system** - Hunger/eating
10. **Special items** - Temple artifacts → Ghost Rod

### ❌ Remove (Don't Need)
1. **Rocket launcher** - Not our game style
2. **Multiplayer** (maybe?) - Can keep if you want co-op
3. **UPNP helper** - If removing multiplayer

---

## References to Rename

### Search for these strings:
- "blocky_game" (directory name)
- "BlockyGame" (class name)
- "Blocky Game" (display text)
- "VoxelBlockyGame" (in UPNP helper)

### Files that need renaming:
```
blocky_game/ → long_nights/
blocky_game.gd → long_nights_game.gd
blocky_game.tscn → long_nights_game.tscn
```

### Code references:
- `const BlockyGame = preload("./blocky_game.gd")`
- `const ROOT = "res://blocky_game/blocks"`
- Window title: "VoxelBlockyGame"

---

## Integration Plan: TimeManager

### Where to Add
**File**: `blocky_game/blocky_game.gd`
**Location**: In `_ready()` function

### Steps:
1. Copy TimeManager to autoload
2. Connect TimeManager signals
3. Update lighting based on time
4. Show day counter in GUI
5. Trigger bloodmoon at day 7

### Example Integration:
```gdscript
func _ready():
	# ... existing code ...

	# Add TimeManager connection
	TimeManager.bloodmoon_started.connect(_on_bloodmoon_started)
	TimeManager.bloodmoon_ended.connect(_on_bloodmoon_ended)
	TimeManager.hour_changed.connect(_on_hour_changed)

func _on_hour_changed(hour: int):
	# Update sun angle
	var sun_rotation = (hour / 24.0) * TAU
	_light.rotation.x = sun_rotation

func _on_bloodmoon_started():
	# Red sky, spawn enemies
	_light.light_color = Color(1.0, 0.3, 0.3)

func _on_bloodmoon_ended():
	# Normal sky
	_light.light_color = Color(1.0, 1.0, 0.9)
```

---

## Next Actions

1. ✅ Understand codebase (this document!)
2. [ ] Rename blocky_game → long_nights
3. [ ] Add TimeManager as autoload
4. [ ] Integrate time/bloodmoon into game
5. [ ] Test day/night cycle works
6. [ ] Add bloodmoon visual effects
7. [ ] Start enemy system

---

## Key Discoveries

1. **It's well-structured** - Clean separation of concerns
2. **Extensible** - Easy to add new blocks, items, systems
3. **Multiplayer optional** - Can remove if not needed
4. **Voxel module is powerful** - Handles all the hard rendering stuff
5. **Good foundation** - Perfect base for The Long Nights

---

**Conclusion**: This codebase is exactly what we needed. It handles all the difficult voxel stuff (rendering, culling, terrain generation) and gives us a solid foundation to build The Long Nights gameplay on top of.
