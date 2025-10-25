# The Long Nights - Godot Rewrite Progress

**Current Date**: October 25, 2025
**Status**: Early Development - Voxel Rendering Complete
**Version**: 0.1.0-alpha

---

## ✅ Completed Milestones

### Phase 1: Architecture & Foundation
- [x] Git + Git LFS setup for large assets
- [x] Core system architecture (GameManager, TimeManager, WorldGenerator)
- [x] Chunk persistence system (prevents bedrock corruption bug)
- [x] Player controller with first-person movement
- [x] Scene setup (code-only, no editor complexity)
- [x] Asset import (all JS assets copied over)

### Phase 2: World Rendering
- [x] Chunk-based terrain generation (12×12×12 voxels per chunk)
- [x] Mesh generation from voxel data using SurfaceTool
- [x] Chunk visualization system (ChunkView)
- [x] Seamless chunk alignment with proper positioning
- [x] Fly mode for easy testing and exploration (Tab to toggle)

### Phase 3: Data Persistence
- [x] Save chunks to disk immediately after generation
- [x] Load chunks from disk (never regenerate)
- [x] Player modifications stored in separate `.mod` files
- [x] Proper directory creation for `user://worlds/`

---

## 🎯 Current State

### Working Features
- **Terrain Rendering**: Flat green voxel world, 12×12×12 chunks
- **Chunk System**: 49 chunks generated (7×7 grid at render distance 3)
- **Persistence**: All chunks saved to `user://worlds/` with mod tracking
- **Player Movement**: WASD for horizontal, Space/Shift for vertical (in fly mode)
- **Fly Mode**: Tab to toggle, Space up, Shift down
- **Time System**: 7-day cycles tracked (not yet visible)

### Technical Specs
- **Chunk Size**: 12×12×12 voxels (balanced for lower-end hardware)
- **Render Distance**: 3 chunks in each direction (27 chunks max)
- **Hardware Target**: AMD Radeon 610M (integrated GPU)
- **Save Format**: Binary `.chunk` files + JSON `.mod` files

---

## 🚀 Next Priority Queue

1. **Improve Terrain Generation** - Add variation (hills, caves, multiple biomes)
2. **Block Texturing System** - Implement texture mapping with naming conventions:
   - `-all` → all 6 faces
   - `-sides` → 4 sides only
   - `-top`, `-bottom`, `-top-bottom` → specific faces
3. **Block Placement/Destruction** - Click to build/mine blocks
4. **Enemy System** - Billboarded sprites with animation
5. **Bloodmoon Spawning** - Wave management and difficulty scaling
6. **Crafting UI** - Inventory display and item crafting
7. **Farming System** - Plant/harvest mechanics
8. **Companion System** - NPC hunts
9. **Ruins** - Structure generation and exploration
10. **Spectral Hunt** - Ghost enemies in final wave

---

## 🏗️ Architecture Changes from JavaScript

| System | JS Version | Godot Version | Notes |
|--------|-----------|---------------|-------|
| Chunk Size | 8×8×8 | 12×12×12 | Better balance, optimized for hardware |
| Rendering | Three.js | Godot 4.5 Forward+ | Native 3D support |
| Persistence | JSON files | Binary + JSON | More efficient |
| Player | Babylon.js | CharacterBody3D | Physics-based movement |
| Scene System | Manual DOM | Code-only GDScript | Git-friendly, no editor conflicts |

---

## 📊 Performance Notes

- **Voxel Count**: 1,728 voxels per chunk (12³)
- **Max Chunks**: 27 (3³ render distance)
- **Vertex Count**: ~144 vertices per solid chunk (rough estimate)
- **Target FPS**: 60 on integrated GPUs
- **Memory**: Optimized for lower-end hardware (no heavy effects)

---

## 🔧 File Structure

```
src/
├── Main.gd                    # Scene builder
├── systems/
│   ├── GameManager.gd         # Singleton game state
│   └── TimeManager.gd         # Day/night cycles
├── world/
│   ├── WorldGenerator.gd      # Chunk generation
│   ├── ChunkPersistence.gd    # Save/load system
│   ├── MeshGenerator.gd       # Voxel → Mesh conversion
│   └── ChunkView.gd           # Visual chunk representation
└── player/
    └── Player.gd              # Player controller

assets/
├── art/blocks/                # Block textures with naming conventions
├── data/                      # Game data files
└── music/ + sfx/             # Audio assets
```

---

## 🎮 Control Scheme

**Movement**:
- WASD - Move horizontally
- Space - Jump (normal) / Up (fly mode)
- Shift - Down (fly mode only)
- Tab - Toggle fly mode

---

## 🐛 Known Issues

- None at this time! Rendering is clean and chunks align properly.

---

## 📝 Design Principles

**Rule #1: Code must run on lower-end hardware**
- Target: AMD Radeon 610M (integrated GPU)
- 12×12×12 chunks for detail without heavy rendering
- Render distance of 3 chunks
- No post-processing or particle effects

---

## 🔗 Links

- **Repository**: https://github.com/ronmurphy/theLongNights-godot
- **Engine**: Godot 4.5 (Forward+ rendering)
- **Platform**: Linux (also supporting Windows/macOS)

---

**Last Updated**: October 25, 2025
**Session Duration**: ~2 hours
**Next Session Focus**: Terrain variation and block textures
