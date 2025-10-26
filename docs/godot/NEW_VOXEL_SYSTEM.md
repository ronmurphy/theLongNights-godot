# New Voxel System Architecture

**Date**: October 25, 2025
**Status**: Fresh implementation - ready for testing

---

## Overview

Complete rebuild of the voxel rendering system with proper architecture from the ground up.

## New File Structure

```
src/world/
├── BlockRegistry.gd     - Singleton managing block types and textures
├── Chunk.gd             - Individual 12×12×12 chunk with neighbor awareness
├── MeshBuilder.gd       - Static mesh generation with proper face culling
├── World.gd             - Infinite terrain manager with chunk pooling
└── ChunkPersistence.gd  - (kept from old system) Save/load chunks

src/world_old/          - Backup of old broken system
```

---

## Key Improvements Over Old System

### 1. **Proper Cross-Chunk Face Culling**
- Chunks now have neighbor references (north, south, east, west, up, down)
- `Chunk.get_voxel_safe()` checks neighbor chunks when position is out of bounds
- MeshBuilder only renders faces exposed to air or transparent blocks
- No more missing faces at chunk boundaries!

### 2. **Object Pooling**
- Chunks are reused from a pool instead of destroyed
- Eliminates garbage collection stuttering
- Much smoother chunk loading/unloading

### 3. **Proper Y-Level Loading**
- Loads chunks relative to player's vertical position
- Only loads ±3 chunks vertically around player
- No more rendering underground chunks when on surface

### 4. **Rate-Limited Loading**
- `MAX_CHUNKS_PER_FRAME = 3` prevents stuttering
- Prioritizes closest chunks first (distance-based rings)
- Smooth terrain streaming as player moves

### 5. **Clean Architecture**
- **BlockRegistry**: Central block definitions (extensible for new blocks)
- **Chunk**: Data storage + neighbor management
- **MeshBuilder**: Pure mesh generation logic (stateless)
- **World**: Terrain management + infinite loading

---

## Block Registry

All block types defined in `BlockRegistry.gd`:

```gdscript
const AIR = 0
const GRASS = 1
const DIRT = 2
const STONE = 3
```

Each block has:
- `name`: String identifier
- `solid`: Boolean (for collision/culling)
- `transparent`: Boolean (for rendering through)
- `textures`: Dictionary mapping faces to texture names
  - Supports: "top", "bottom", "sides", "all", or specific faces

---

## Chunk System

### Chunk Coordinates
- Each chunk is 12×12×12 voxels
- Chunk position is in **chunk coordinates** (not world units)
- World position = chunk_pos × 12

### Neighbor System
```
     [up]
      |
[west]-[chunk]-[east]
      |
    [down]

    [north] = +Z
    [south] = -Z
```

### Face Culling Logic
1. For each solid voxel, check all 6 faces
2. For each face, check adjacent voxel (using `get_voxel_safe`)
3. If adjacent is air or transparent → render face
4. If adjacent is solid → skip face (hidden by neighbor)

---

## World Manager

### Constants
- `RENDER_DISTANCE = 5` (horizontal)
- `VERTICAL_RENDER_DISTANCE = 3` (vertical)
- `MAX_CHUNKS_PER_FRAME = 3` (rate limit)

### Terrain Generation
- Base height: 32 blocks
- Variation: ±16 blocks (height range 16-48)
- Simplex noise with frequency 0.02
- Layer structure:
  - Top block: Grass
  - Next 3 blocks: Dirt
  - Below: Stone

### Loading Strategy
1. Player moves to new chunk
2. Calculate chunks needed in render distance
3. Load closest chunks first (distance ring 0, then 1, 2, etc.)
4. Limit to 3 chunks per frame
5. Update neighbors for new chunks
6. Build meshes
7. Unload chunks beyond render distance

---

## How It Works

### Startup Sequence
1. `Main.gd` creates `World` node
2. World creates `BlockRegistry` and `ChunkPersistence`
3. World generates spawn chunks (5×5 area, 3 chunks vertically)
4. All chunks get neighbor references
5. Meshes built for all chunks
6. Player spawns at Y=40

### Runtime Chunk Loading
1. Player moves (monitored every frame)
2. When player enters new chunk:
   - Check which chunks should be loaded
   - Load up to 3 chunks (from disk or generate)
   - Update all neighbor references
   - Build meshes for new chunks
   - Unload far chunks (return to pool)

### Mesh Building
1. `MeshBuilder.build_mesh(chunk)` called
2. Iterate through all 1,728 voxels
3. For each solid voxel:
   - Check all 6 faces
   - Render face if exposed to air
4. Use `SurfaceTool` to build mesh
5. Auto-generate normals for correct lighting
6. Return `ArrayMesh` or null if empty

---

## Current Limitations & Future Work

### Textures
- Currently using **vertex colors** (grass=green, dirt=brown, stone=gray)
- Next step: Implement texture atlas
- BlockRegistry already supports per-face texture mapping

### Greedy Meshing
- Not implemented yet (each voxel face = 2 triangles)
- Current system works but could be optimized
- Greedy meshing would combine adjacent same-type faces

### Structure Generation
- No structures yet (temples, ruins, etc.)
- World.gd has clean architecture for adding structure generators

### Biomes
- Single biome currently
- Easy to add: pass (x,z) to biome selector → block type

---

## Testing Checklist

- [ ] Chunks render without missing faces
- [ ] No stuttering when moving
- [ ] Chunks load smoothly at distance
- [ ] Chunks unload when far away
- [ ] No visual artifacts at chunk boundaries
- [ ] Terrain looks natural (hills and valleys)
- [ ] Player can fly and walk normally
- [ ] Vertical movement loads/unloads chunks properly

---

## Configuration

Easy to adjust in `World.gd`:

```gdscript
const RENDER_DISTANCE = 5              # View distance
const VERTICAL_RENDER_DISTANCE = 3     # Vertical range
const MAX_CHUNKS_PER_FRAME = 3         # Loading speed
const BASE_TERRAIN_HEIGHT = 32         # Average height
const TERRAIN_VARIATION = 16           # Hill/valley size
```

---

## File Sizes

Extremely lightweight:
- `BlockRegistry.gd`: ~110 lines
- `Chunk.gd`: ~140 lines
- `MeshBuilder.gd`: ~160 lines
- `World.gd`: ~260 lines

**Total: ~670 lines of clean, documented code**

Compare to old system: ~800 lines of tangled, buggy code

---

## Next Steps

1. **Test the system** - Run and verify it works
2. **Add texture atlas** - Combine block textures into one image
3. **Implement texture loading** - Use your `-all`, `-sides`, `-top`, `-bottom` convention
4. **Add block breaking/placing** - Raycasting + modify voxel + rebuild mesh
5. **Structure generation** - Temples, ruins, trees

---

**Status**: Ready for testing! 🚀
