# The Long Nights - Godot Rewrite
**Project Status**: Early Development - Core Systems Built
**Last Updated**: October 25, 2025
**Language**: GDScript (Godot 4.5)
**Platform**: Linux (Arch)

---

## 🎮 Project Overview

A **Minecraft-like survival game** being rebuilt from JavaScript (which hit architectural limits) to **Godot 4.5** for proper 3D game support.

### Core Game Loop
- **7-day week cycle** with peaceful day/night progression
- **Day 7 night = Bloodmoon** - escalating enemy waves (10 + week×10 enemies)
- **Player strategies**: Build defensive structures OR fight enemies
- **Progression**: Explore 4 main ruins, unlock items, craft Ghost Rod
- **Plot twist**: Kill tracker shows kills as ghosts in endless final wave
- **Secondary systems**: Farming, companion hunts, crafting, voxel building

---

## 🏗️ Architecture Overview

### 🎯 Core Design Principle
**Rule #1: Code must run on lower-end hardware** (AMD Radeon 610M and similar integrated GPUs)
- Chunk size: **12×12×12** (balanced between detail and performance)
- Render distance: 3 chunks (27 chunks loaded max)
- No heavy post-processing or particle effects
- Optimize for integrated GPUs, not discrete ones

### Current File Structure
```
theLongNights/
├── Main.tscn                          # Entry scene (minimal wrapper)
├── src/
│   ├── Main.gd                        # Scene builder (creates everything in code)
│   ├── systems/
│   │   ├── GameManager.gd             # Singleton, game state hub
│   │   └── TimeManager.gd             # 7-day cycles, Bloodmoon triggers
│   ├── world/
│   │   ├── WorldGenerator.gd          # Chunk generation + LOD
│   │   └── ChunkPersistence.gd        # Save/load chunks, mods tracking
│   └── player/
│       └── Player.gd                  # CharacterBody3D, movement, inventory
├── assets/                            # All art, music, data from JS version
│   ├── art/
│   ├── data/
│   ├── fonts/
│   ├── music/
│   ├── sfx/
│   └── quest-images/
├── docs/                              # Design docs (JS version reference)
└── project.godot                      # Configuration

```

### Key Systems

#### **GameManager** (src/systems/GameManager.gd)
- Singleton pattern - only one instance ever
- Initializes TimeManager and other systems
- Handles pause/resume
- Emits signals for game events
- Catches player death events

#### **TimeManager** (src/systems/TimeManager.gd)
- Tracks: weeks, days (1-7), hours (0-23), minutes
- **3 real minutes = 1 in-game hour**
- Signals: `day_changed`, `hour_changed`, `bloodmoon_started`, `bloodmoon_ended`
- Bloodmoon triggers on **day 7, 10 PM (22:00) to 2 AM (02:00)**
- Difficulty scales: `1.0 + (week - 1) × 0.3`

#### **WorldGenerator** (src/world/WorldGenerator.gd)
- Chunk-based terrain (12×12×12 voxels per chunk, Minecraft-like)
- **CRITICAL**: Never regenerates saved chunks (prevents bedrock bug)
- Workflow:
  1. Try to load chunk from disk
  2. If loaded, apply .mod file modifications
  3. If new, generate, save to disk
  4. Player modifications written to separate .mod files
- Constants: `CHUNK_SIZE=12`, `RENDER_DISTANCE=3`, `WORLD_SEED=12345`

#### **ChunkPersistence** (src/world/ChunkPersistence.gd)
- **Solves the bedrock corruption bug** from JS version
- Files: `user://worlds/chunk_X_Y_Z.chunk` (binary) + `.mod` (JSON)
- Flow:
  ```
  chunk_X_Y_Z.chunk  ← original generated data (NEVER regenerated)
  chunk_X_Y_Z.mod    ← accumulated player modifications

  On load:
  1. Read .chunk file
  2. Apply all mods from .mod file
  3. In-game chunk = original + all player changes
  ```
- Methods: `save_chunk()`, `load_chunk()`, `apply_modifications()`, `record_modification()`

#### **Player** (src/player/Player.gd)
- CharacterBody3D with physics
- Movement: WASD, Jump: Space
- Health: 100 HP (takes damage, dies at 0)
- Inventory: Dictionary of items by name
- Camera: First-person view with offset
- Collision: Capsule shape (0.4r × 1.8h)

---

## 🔧 How the Scene is Built

**Main.tscn** is MINIMAL:
```
[node name="Main" type="Node3D"]
  script = res://src/Main.gd
```

**Main.gd** builds EVERYTHING programmatically in `_setup_scene()`:
1. Creates GameManager (singleton)
2. Creates WorldGenerator (chunk system)
3. Creates Player with Camera + Collision
4. Creates DirectionalLight for lighting
5. All in code - no editor clicking needed

This avoids Godot editor file issues and git conflicts.

---

## 🐛 The Bedrock Bug (NOW FIXED)

### Original Problem (JavaScript)
Teleport blocks and custom player-placed blocks would **corrupt to bedrock** when:
1. Player placed a teleport block
2. Left the chunk
3. Came back
4. Block was now bedrock (broken!)

**Root cause**: Chunks were regenerated on load instead of loaded from disk, losing player modifications.

### Godot Solution
**ChunkPersistence guarantees**:
- ✅ Chunks saved to disk immediately after generation
- ✅ Player mods stored in separate `.mod` files
- ✅ Chunks NEVER regenerate once saved
- ✅ Mods always applied consistently on load
- ✅ Source of truth is DISK, not RAM

Result: **Teleport blocks (and all custom blocks) stay permanent forever.**

---

## 🎯 Current State

### ✅ COMPLETED
- [x] Git + Git LFS setup
- [x] Core system architecture (GameManager, TimeManager)
- [x] Chunk persistence (bedrock bug FIX)
- [x] World generation (12×12×12 chunks, flat terrain)
- [x] Player controller with movement & fly mode
- [x] Scene setup (code-only, no editor complexity)
- [x] Asset import (all JS assets copied over)
- [x] **VOXEL RENDERING** - Chunks visible as 3D meshes
- [x] Chunk mesh generation using SurfaceTool
- [x] Seamless chunk alignment (no spacing grid)
- [x] Directory creation for persistence

### ⏳ TODO (Priority Order)
1. **Improve terrain generation** - Add hills, caves, biome variation
2. **Block texturing system** - Implement texture mapping (-all, -sides, -top, etc.)
3. **Block placement/destruction** - Click to build/mine
4. **Enemy system** - Billboarded sprites with animation
5. **Bloodmoon spawning** - Wave management
6. **Crafting UI** - Inventory display
7. **Farming system** - Plant/harvest mechanics
8. **Companion system** - NPC hunts
9. **Ruins** - Structure generation + exploration
10. **Spectral Hunt** - Ghost enemies

---

## 🚀 Running the Game

### Setup (One Time)
```bash
cd /home/brad/Godot/theLongNights
# Uninstall VSCode Godot extension (optional)
# Close VSCode
```

### Run Game
**Terminal 1** (Godot):
```bash
godot4 /home/brad/Godot/theLongNights &
# Godot opens in separate window
# Press F5 to play
```

**Terminal 2** (Claude Code):
```bash
cd /home/brad/Godot/theLongNights
claude code
# Make edits, I'll make changes to .gd files
# Godot auto-reloads on save
```

### Workflow
1. I edit `.gd` files in `/src/`
2. You press F5 in Godot to reload
3. Watch console output in Godot's "Output" tab
4. Report what you see/want
5. I iterate

### Control Scheme
**Movement**:
- **WASD** - Move horizontally
- **Space** - Jump (normal mode) / Up (fly mode)
- **Shift** - Down (fly mode only)
- **Tab** - Toggle fly mode on/off

---

## 📊 GDScript Quick Reference

### Class Declarations
```gdscript
class_name ClassName  # Makes class usable as ClassName.new()
```

### Common Patterns
```gdscript
# Singleton
class_name GameManager
static var instance: GameManager
func _ready():
    if instance == null:
        instance = self

# Signals
signal my_signal(param: int)
my_signal.emit(42)  # Trigger signal

# Export variables (visible in inspector)
@export var speed: float = 5.0

# Type hints (required)
func move(delta: float) -> void:
    velocity.y -= gravity * delta

# Arrays/Dictionaries
var inventory: Dictionary = {}  # Key: value
inventory["apple"] = 5
var chunks: Dictionary = {}  # Vector3i: Array of voxels
```

### Physics
```gdscript
extends CharacterBody3D  # For player movement
move_and_slide()         # Apply velocity + gravity

extends Node3D           # For static objects
position = Vector3(x, y, z)
```

---

## 📝 Key Files to Know

| File | Purpose |
|------|---------|
| `Main.gd` | Builds entire scene at startup |
| `GameManager.gd` | Central game state |
| `TimeManager.gd` | Day/night/Bloodmoon logic |
| `WorldGenerator.gd` | Chunk generation + loading |
| `ChunkPersistence.gd` | Save/load system |
| `Player.gd` | Player movement & stats |
| `project.godot` | Godot configuration |
| `Main.tscn` | Minimal entry scene |

---

## 🔗 GitHub
**Repository**: https://github.com/ronmurphy/theLongNights-godot
**Status**: Active development, commits after each session
**LFS**: Configured for `.png`, `.jpg`, `.ogg`, `.wav`, `.blend`, etc.

---

## 💡 Notes for Next Session

1. **Hot reload**: Godot auto-reloads GDScript when edited
2. **If broken**: Just press F5 again to restart
3. **Console**: Check "Output" tab in Godot for prints
4. **No VSCode needed**: All editing via Claude Code terminal
5. **Git is clean**: One terminal can handle git commits

---

## 🎯 Next Major Milestone

**Goal**: Render the voxel world so you can **SEE** the terrain chunks visually.

Currently chunks exist as data (Array of voxel IDs), but aren't rendered as 3D meshes. Once we add mesh generation, the world will become visible and you can walk around it.

This is the foundation for everything else (building, enemies, etc.).

---

**Created by**: Claude Code
**For**: Ron Murphy (@solo.dev)
**Game Engine**: Godot 4.5 (Forward+)
**Target Platform**: Linux/Windows/macOS (eventually)
