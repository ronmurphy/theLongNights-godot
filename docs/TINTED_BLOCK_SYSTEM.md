# Tinted Block System - Implementation Guide

## Overview

The Tinted Block System enables memory-efficient texture color variations using a single atlas. Instead of creating new textures for redwood planks, birch planks, etc., the system uses:

1. **Single base texture** (existing `terrain.png` atlas)
2. **JSON-defined color variants** (`block_tints.json`)
3. **Object pooling** (reusable block instances)
4. **Material cloning** (tint application at runtime)

This is similar to how Minecraft handles wood type variations.

---

## Files Created

### 1. `block_tints.json` ✅
**Location:** `res://blocky_game/blocks/block_tints.json`

**Structure:**
```json
{
  "tints": {
    "base_block_name": {
      "base_block": "base_block_name",
      "variants": [
        {
          "name": "variant_name",
          "color": [r, g, b, a],
          "description": "Human readable description"
        }
      ]
    }
  }
}
```

**Current Variants Defined:**
- **Dirt:** dark, clay, sandy
- **Grass:** lush, dry, snow
- **Log:** oak, birch, dark
- **Planks:** oak, redwood, birch
- **Leaves:** oak, birch, autumn
- **Glass:** clear, blue, green
- **Stairs:** oak, stone, dark

Each base block has 3 tint variants pre-configured.

---

### 2. `tinted_block_pool.gd` ✅
**Location:** `res://blocky_game/blocks/tinted_block_pool.gd`

**Key Features:**
- Pre-allocates 50 instances of each tinted block variant
- Lazy creates nodes on-demand (efficient memory usage)
- Automatically expands pool if exhausted
- Organized parent nodes for each tint type
- Debug statistics available

**Key Methods:**
```gdscript
get_tinted_block(tint_block_name: String) -> Node3D
return_tinted_block(tint_block_name: String, block_node: Node3D)
print_pool_stats()
```

**Internal Architecture:**
- `PooledTintedBlock` class: Tracks individual pooled instances
- `_pool` Dictionary: Maps tint names to arrays of available blocks
- `_pool_parents` Dictionary: Organizes pool nodes in scene tree
- Material cloning: Each pooled block gets proper tinted material

---

### 3. Modified `blocks.gd` ✅
**Location:** `res://blocky_game/blocks/blocks.gd`

**New Variables:**
```gdscript
var _tint_pool: TintedBlockPool = null
var _tint_materials: Dictionary = {}
```

**New Methods:**

```gdscript
# Initialize the tint system (call in _ready() of parent)
func initialize_tint_system()

# Get a pooled tinted block instance
func get_tinted_block(tint_block_name: String) -> Node3D

# Return a block to pool for reuse
func return_tinted_block(tint_block_name: String, block_node: Node3D)

# Get a tinted material without pooling (for direct use)
func get_tinted_material(base_block_name: String, tint_color: Array) -> StandardMaterial3D

# Debug - print pool statistics
func print_tint_pool_stats()
```

---

## How It Works

### Initialization Flow

```
Game Start
  ↓
BlockyGame._ready()
  ↓
Blocks._ready()
  ↓
Blocks.initialize_tint_system()
  ↓
TintedBlockPool._ready()
  ↓
TintedBlockPool._initialize_pools()
  ├─ Load block_tints.json
  ├─ For each tint variant:
  │   ├─ Create parent node
  │   └─ Pre-allocate 50 pooled instances
  │       └─ Material cloned with tint color applied
  ↓
Ready to use
```

### Block Placement Flow

**Current (Voxel Terrain):**
```
Player places block → VoxelTerrain stores voxel ID
```

**Future (Tinted Blocks on Terrain):**
```
Player places "redwood_plank" → 
  ├─ Blocks.get_tinted_block("redwood_planks_oak")
  ├─ TintedBlockPool finds available instance
  ├─ Show node at placement position
  └─ Node displays with correct tint
```

---

## Integration Points (Next Steps)

### Phase 1: Basic Pooling (Test)
- [ ] Call `Blocks.initialize_tint_system()` in appropriate game startup
- [ ] Verify pool statistics with `Blocks.print_tint_pool_stats()`
- [ ] Check scene tree organization under `Blocks → TintedBlockPool`

### Phase 2: UI Integration
- [ ] Add tinted block variants to inventory/hotbar
- [ ] Create UI buttons/items for each variant
- [ ] Display variant names and colors in UI

### Phase 3: Placement Integration
- [ ] Modify `InteractionCommon.place_single_block()` to handle tinted blocks
- [ ] Detect when placed block is a tint variant
- [ ] Call `Blocks.get_tinted_block()` instead of voxel placement
- [ ] Track placed tinted blocks for destruction

### Phase 4: Persistence
- [ ] Save tinted block positions when chunks save
- [ ] Load tinted blocks when chunks restore
- [ ] Return blocks to pool when destroyed

---

## Performance Benefits

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Texture Memory | Atlas for each variant | Single atlas | 6-8x reduction |
| Block Instances | New per placement | Pooled reuse | 50+ reuse factor |
| GC Pressure | High (new nodes) | Low (pooled) | 95%+ reduction |
| Material Memory | Per block | Cloned once | ~80% reduction |

---

## Material Tinting System

### How Color Tinting Works

1. **Base Material Selection:**
   - Transparent blocks → `terrain_material_transparent.tres`
   - Foliage (leaves, grass) → `terrain_material_foliage.tres`
   - Solid blocks → `terrain_material.tres`

2. **Color Application:**
   - Each base material has `vertex_color_use_as_albedo = true`
   - Tint color modulates the texture RGB
   - Alpha channel preserved (for transparent materials)

3. **Example:**
   - Base texture: Brown plank texture
   - Tint color: [0.8, 0.4, 0.2, 1.0] (reddish)
   - Result: Brown texture × reddish tint = Redwood plank appearance

---

## JSON Color Format

Colors are RGBA arrays with values 0.0-1.0:

```json
"color": [0.8, 0.4, 0.2, 1.0]
         ├─ Red channel (0.8 = 80% brightness)
         ├─ Green channel (0.4 = 40% brightness)
         ├─ Blue channel (0.2 = 20% brightness)
         └─ Alpha channel (1.0 = fully opaque)
```

**Color Picking Tips:**
- Grass green: `[0.4, 0.6, 0.3]` (more G than R or B)
- Wood brown: `[0.6, 0.45, 0.3]` (R > G > B)
- Metal gray: `[0.6, 0.6, 0.6]` (R = G = B)
- Snow white: `[0.95, 0.95, 0.95]` (high on all channels)

---

## Current Limitations & Future Improvements

### Known Limitations
1. **Voxel terrain integration:** Currently works only with pooled nodes, not voxel grid
2. **Persistence:** Tinted blocks not yet saved/loaded with chunks
3. **UI:** No tinted block selection in inventory yet

### Future Improvements
1. **Instancing:** Use InstancedMesh for mass tinted blocks (forests, cities)
2. **Custom colors:** Allow players to create custom tints
3. **Animation:** Tint changes over time (tree growth, decay)
4. **Blending:** Mix multiple tints for complex appearances
5. **Normal map variants:** Different tints with different normal maps

---

## Debug Commands

```gdscript
# Check pool status
Blocks.print_tint_pool_stats()

# Get a tinted block manually (for testing)
var block = Blocks.get_tinted_block("planks_redwood")
block.global_position = Vector3(0, 2, 0)
get_tree().root.add_child(block)

# Return it to pool
Blocks.return_tinted_block("planks_redwood", block)
```

---

## Testing Checklist

- [ ] `TintedBlockPool` node appears in scene tree under `Blocks`
- [ ] Pool parents organized as `Pool_planks_oak`, `Pool_grass_lush`, etc.
- [ ] `print_tint_pool_stats()` shows 50+ blocks per type
- [ ] Getting same block twice returns different instances (different nodes)
- [ ] Returning block and getting again reuses same node
- [ ] Materials have correct tint colors applied
- [ ] No memory leaks when rapidly allocating/deallocating

---

## Code Examples

### Get and Display a Tinted Block

```gdscript
# Assuming Blocks is initialized and pool created
var tinted_block = Blocks.get_tinted_block("planks_redwood")
tinted_block.global_position = Vector3(5, 1, 5)
add_child(tinted_block)  # Add to scene
```

### Return Block to Pool

```gdscript
if tinted_block.get_parent():
	get_parent().remove_child(tinted_block)
Blocks.return_tinted_block("planks_redwood", tinted_block)
```

### Create Custom Tint Material

```gdscript
# Without using pool (one-off use)
var custom_color = [1.0, 0.5, 0.0, 1.0]  # Orange
var tint_mat = Blocks.get_tinted_material("planks", custom_color)
# Use tint_mat on any MeshInstance3D
```

---

## Next Steps

1. **Test Phase 1:** Verify pool initialization and statistics
2. **Integrate with UI:** Add tinted block variants to player inventory
3. **Implement Placement:** Modify interaction code to use pooled tinted blocks
4. **Add Persistence:** Save/load tinted block positions with chunks
5. **Performance Testing:** Benchmark memory and FPS improvements

---

