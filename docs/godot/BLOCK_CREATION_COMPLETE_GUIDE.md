# Complete Block Creation Guide: From Texture to World Spawning
**Last Updated:** October 27, 2025  
**Author:** Brad (with GitHub Copilot)  
**Time Estimate:** 1-2 hours per block

This guide walks through the complete process of creating and adding a new block to The Long Nights, using the pumpkin block as a real-world example.

---

## Table of Contents
1. [Overview](#overview)
2. [Step 1: Prepare Your Textures](#step-1-prepare-your-textures)
3. [Step 2: Use Terrain Mapper to Get Coordinates](#step-2-use-terrain-mapper-to-get-coordinates)
4. [Step 3: Create the OBJ File](#step-3-create-the-obj-file)
5. [Step 4: Add Block Definition to blocks.gd](#step-4-add-block-definition-to-blocksgd)
6. [Step 5: Add Voxel Model to Library](#step-5-add-voxel-model-to-library)
7. [Step 6: Add to World Generator](#step-6-add-to-world-generator)
8. [Quick Reference](#quick-reference)

---

## Overview

Creating a new block involves:
- **Texturing**: Drawing pixel art for your block's surfaces
- **Mapping**: Using the Terrain Mapper tool to locate textures in the atlas
- **Modeling**: Creating a 3D cube model (OBJ file) with proper texture coordinates
- **Registration**: Adding the block to the game's block system
- **Spawning**: Configuring world generation to place your block

### Block Types

**Single-Texture Blocks** (e.g., dirt, glass)
- All 6 faces use the same texture
- Use `dirt.obj` as your template
- Simplest approach
- **Example:** `dirt.obj`, `glass.obj`

**Multi-Texture Blocks** (e.g., grass, pumpkin)
- Different textures for different faces
- Top, sides, and/or bottom each have unique textures
- Use `grass.obj` or `pumpkin.obj` as your template
- More complex but more visually interesting
- **Example:** `pumpkin.obj` (top, 4 sides, bottom)

---

## Step 1: Prepare Your Textures

### Location
Your textures go in the **terrain atlas**:
```
/project/blocky_game/blocks/terrain.png
```

This is a **256×256 pixel image** divided into a **16×16 grid** of texture cells (16 pixels each).

### Grid Coordinates
- Grid coordinates range from **(0,0)** to **(15,15)**
- (0,0) is top-left
- (15,15) is bottom-right
- Each cell is **16×16 pixels**

### For Pumpkin Example
```
Row 15 (bottom row):
- Column 0 (15,0): pumpkin_top
- Column 1 (15,1): pumpkin_side
- Column 2 (15,2): pumpkin_bottom
```

### Design Tips
- Keep textures **16×16 pixels** (they'll scale to the grid cell)
- Use the same visual style as existing blocks
- For multi-texture blocks, ensure visual continuity between faces

---

## Step 2: Use Terrain Mapper to Get Coordinates

The **Terrain Mapper** is a visual tool that shows your texture atlas and calculates UV coordinates.

### How to Open
```
In-game: Press Ctrl+T
```

### How to Use
1. **Find your texture** on the grid preview
2. **Click the grid cell** where your texture is located
3. The mapper displays:
   - **Grid coordinates** (e.g., 15, 0)
   - **UV coordinates** (texture mapping values)
   - **blocks.gd template** (starter code)
   - **OBJ template** (texture coordinates for all 6 faces)

### Understanding UV Coordinates
UV coordinates tell the 3D engine where to find textures:
- **U**: Horizontal position (0 = left, 1 = right)
- **V**: Vertical position (0 = top, 1 = bottom)
- Each grid cell spans from `cell/16` to `(cell+1)/16`

**Example for grid (15,0):**
```
U: 0.9375 - 1.0000  (15/16 to 16/16)
V: 0.0000 - 0.0625  (0/16 to 1/16)
```

### For Multi-Texture Blocks
Click each texture location to get the UV coordinates:
1. Click **(15,0)** → Get top face UV coordinates
2. Click **(15,1)** → Get side face UV coordinates  
3. Click **(15,2)** → Get bottom face UV coordinates

**Save all three outputs** - you'll need them for the OBJ file.

---

## Step 3: Create the OBJ File

### Location
Create a folder for your block:
```
/project/blocky_game/blocks/{block_name}/
Example: /project/blocky_game/blocks/pumpkin/
```

### File Structure
```
pumpkin/
├── pumpkin.obj          ← 3D model with texture coords
└── pumpkin_sprite.png   ← GUI inventory icon
```

### Creating the OBJ File

#### For Single-Texture Blocks
1. Copy `dirt.obj` to your folder and rename it
2. Change the object name in the first few lines
3. Replace all `vt` (vertex texture) values with the ones from Terrain Mapper
4. Keep vertices `v`, normals `vn`, and faces `f` unchanged

**Example: Creating `glass.obj`**
```gdscript
# Copy dirt.obj to glass.obj, then edit:

# Change this line:
o Dirt_Cube.005
# To:
o Glass_Cube

# Replace all vt lines with values from Terrain Mapper
# Keep everything else the same
```

#### For Multi-Texture Blocks (Pumpkin Example)

The OBJ file has 6 face groups. You need to assign different UV coordinates to each:

**Structure:**
```
# Face 1 (TOP):    Use texture from (15,0)
# Faces 2-5 (SIDES): Use texture from (15,1) - same for all 4 sides
# Face 6 (BOTTOM):  Use texture from (15,2)
```

**Complete pumpkin.obj example:**

```obj
# Blender v2.83.0 OBJ File: 'blocks.blend'
# www.blender.org
# Multi-texture pumpkin block
# Top: (15,0) | Sides: (15,1) | Bottom: (15,2)
o Pumpkin_Cube

# Vertices (same for all blocks - 8 corners of a cube)
v 1.000000 1.000000 1.000000
v 1.000000 0.000000 1.000000
v 0.000000 1.000000 1.000000
v 0.000000 0.000000 1.000000
v 1.000000 1.000000 0.000000
v 1.000000 0.000000 0.000000
v 0.000000 1.000000 0.000000
v 0.000000 0.000000 0.000000

# Texture Coordinates
# Face 1 (TOP) - from grid (15,0)
vt 0.9375 1.0000
vt 1.0000 1.0000
vt 1.0000 0.9375
vt 0.9375 0.9375

# Face 2 (LEFT) - from grid (15,1)
vt 0.9375 0.9375
vt 1.0000 0.9375
vt 1.0000 0.8750
vt 0.9375 0.8750

# Face 3 (BACK) - from grid (15,1)
vt 0.9375 0.9375
vt 1.0000 0.9375
vt 1.0000 0.8750
vt 0.9375 0.8750

# Face 4 (FRONT) - from grid (15,1)
vt 0.9375 0.9375
vt 1.0000 0.9375
vt 1.0000 0.8750
vt 0.9375 0.8750

# Face 5 (RIGHT) - from grid (15,1)
vt 0.9375 0.9375
vt 1.0000 0.9375
vt 1.0000 0.8750
vt 0.9375 0.8750

# Face 6 (BOTTOM) - from grid (15,2)
vt 0.9375 0.8750
vt 1.0000 0.8750
vt 1.0000 0.8125
vt 0.9375 0.8125

# Normals (same for all blocks - defines face direction)
vn 0.0000 1.0000 0.0000
vn -1.0000 0.0000 0.0000
vn 0.0000 0.0000 -1.0000
vn 0.0000 -1.0000 0.0000
vn 0.0000 0.0000 1.0000
vn 1.0000 0.0000 0.0000

s off
# Faces reference vertices/textures/normals
f 1/1/1 5/2/1 7/3/1 3/4/1
f 4/5/2 3/6/2 7/7/2 8/8/2
f 8/9/3 7/10/3 5/11/3 6/12/3
f 6/13/4 2/14/4 4/15/4 8/16/4
f 2/17/5 1/18/5 3/19/5 4/20/5
f 6/21/6 5/22/6 1/23/6 2/24/6
```

**Key Points:**
- Lines 1-8: `v` (vertices) - **NEVER change these**
- Lines 10-29: `vt` (texture coordinates) - **Replace with Terrain Mapper values**
- Lines 31-36: `vn` (normals) - **NEVER change these**
- Lines 38-43: `f` (faces) - **NEVER change these**

---

## Step 4: Add Block Definition to blocks.gd

### File Location
```
/project/blocky_game/blocks/blocks.gd
```

### How It Works
Each block is registered using the `_create_block()` function. This tells the game about your block's properties.

### Add Your Block
Find the list of `_create_block()` calls and add your block at the end (before the `func get_block()` line).

**For Pumpkin:**
```gdscript
_create_block({
    "name": "pumpkin",
    "gui_model": "pumpkin.obj",
    "rotation_type": ROTATION_TYPE_NONE,
    "voxels": ["pumpkin"],
    "transparent": false
})
```

### Property Explanations

| Property | Value | Meaning |
|----------|-------|---------|
| `"name"` | `"pumpkin"` | Identifier used in console commands and code |
| `"gui_model"` | `"pumpkin.obj"` | OBJ file in your block's folder |
| `"rotation_type"` | `ROTATION_TYPE_NONE` | No rotation (solid block) |
| | `ROTATION_TYPE_AXIAL` | Rotates on X/Y/Z axes (logs) |
| | `ROTATION_TYPE_Y` | Rotates only on Y axis (stairs) |
| | `ROTATION_TYPE_CUSTOM_BEHAVIOR` | Special behavior (rails) |
| `"voxels"` | `["pumpkin"]` | Voxel name (must match voxel library) |
| `"transparent"` | `false` | Solid block (true = see-through) |
| `"backface_culling"` | `true` | Optional - hides back faces |

### Complete Example (blocks.gd snippet)
```gdscript
	_create_block({
		"name": "dead_shrub",
		"gui_model": "dead_shrub.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["dead_shrub"],
		"transparent": true,
		"backface_culling": false
	})
	_create_block({
		"name": "pumpkin",           # ← Your new block
		"gui_model": "pumpkin.obj",
		"rotation_type": ROTATION_TYPE_NONE,
		"voxels": ["pumpkin"],
		"transparent": false
	})
```

---

## Step 5: Add Voxel Model to Library

The **voxel library** is where you configure the 3D mesh, material, and collision for your block.

### File Location
```
/project/blocky_game/blocks/voxel_library.tres
```

### How to Add (In Godot Editor)

1. **Open the file** `voxel_library.tres` in Godot Inspector
2. **Scroll to** the `Models` array
3. **Click "Add Element"** button
4. **Configure the new entry:**

| Setting | Value |
|---------|-------|
| Type | `VoxelBlockyModelMesh` |
| Resource Name | `pumpkin` |
| Mesh | `res://blocky_game/blocks/pumpkin/pumpkin.obj` |
| Material Override 0 | `res://blocky_game/blocks/terrain_material.tres` |
| Collision AABB | `[AABB(0, 0, 0, 1, 1, 1)]` |
| Mesh Collision > 0 | `On` |

**Collision AABB Explained:**
```
AABB(x, y, z, width, height, depth)
AABB(0, 0, 0, 1, 1, 1) = Full 1×1×1 cube collision box
```

### Result
After saving, your block should appear in the voxel library at index 27 (if pumpkin is the last block added).

---

## Step 6: Add to World Generator

Now your block can spawn in the world!

### File Location
```
/project/blocky_game/generator/generator.gd
```

### Step 1: Add Constant

Find the block ID constants at the top:

```gdscript
const AIR = 0
const DIRT = 1
const GRASS = 2
const WATER_FULL = 14
const WATER_TOP = 13
const LOG = 4
const LEAVES = 25
const TALL_GRASS = 8
const DEAD_SHRUB = 26
const PUMPKIN = 27        # ← Add this line
```

**How do I know it's 27?**
- Blocks are numbered in order as they appear in the voxel library
- Count from the top: AIR(0), DIRT(1), GRASS(2)... DEAD_SHRUB(26)
- PUMPKIN is the next one after DEAD_SHRUB, so it's **27**

### Step 2: Add Spawn Logic

Find where foliage is spawned (look for `TALL_GRASS` and `DEAD_SHRUB`):

**Location:** Around line 145-150 in `generator.gd`

**Original code:**
```gdscript
if relative_height < block_size and rng.randf() < 0.2:
    var foliage = TALL_GRASS
    if rng.randf() < 0.1:
        foliage = DEAD_SHRUB
    buffer.set_voxel(foliage, x, relative_height, z, _CHANNEL)
```

**Modified code (with pumpkin):**
```gdscript
if relative_height < block_size and rng.randf() < 0.2:
    var foliage = TALL_GRASS
    if rng.randf() < 0.1:
        foliage = DEAD_SHRUB
    elif rng.randf() < 0.05:
        foliage = PUMPKIN
    buffer.set_voxel(foliage, x, relative_height, z, _CHANNEL)
```

### Understanding Spawn Rates

The logic is a **probability cascade**:

```
20% chance of ANY foliage
├─ 10% of that = DEAD_SHRUB (2% overall)
├─ 5% of that = PUMPKIN (1% overall)
└─ Rest = TALL_GRASS (~17% overall)
```

**To adjust pumpkin spawn rate:**
- `rng.randf() < 0.05` = 5% chance
- Change `0.05` to `0.10` for 10% chance
- Change `0.05` to `0.02` for 2% chance

### Common Spawn Rate Values
```
0.01 = 1% (very rare)
0.05 = 5% (rare)
0.10 = 10% (occasional)
0.25 = 25% (common)
0.50 = 50% (very common)
```

---

## Quick Reference

### File Locations Summary
```
Block OBJ files:
  /project/blocky_game/blocks/{block_name}/{block_name}.obj

Block registration:
  /project/blocky_game/blocks/blocks.gd
  (Add to _init() function)

Voxel library configuration:
  /project/blocky_game/blocks/voxel_library.tres
  (Edit in Godot Inspector)

World generation:
  /project/blocky_game/generator/generator.gd
  (Add constant and spawn logic)
```

### Process Checklist

```
□ Add textures to terrain.png (16×16 pixel cells)
□ Open Terrain Mapper (Ctrl+T) and get UV coordinates
□ Create block folder: /blocky_game/blocks/{name}/
□ Create OBJ file using template (dirt.obj or pumpkin.obj)
□ Add pumpkin_sprite.png to block folder
□ Add _create_block() entry to blocks.gd
□ Add voxel model to voxel_library.tres
□ Add const {BLOCK} = X to generator.gd
□ Add spawn logic to generator.gd (if wanted)
□ Test in game!
```

### OBJ Template Selection

| Block Type | Use This Template | Example |
|-----------|-------------------|---------|
| Single texture, all faces same | `dirt.obj` | Dirt, Glass, Stone |
| Multi-texture, different per face | `grass.obj` or `pumpkin.obj` | Grass, Log, Pumpkin |
| Rotating block | `stairs.obj` or `log.obj` | Stairs, Logs, Rails |

---

## Troubleshooting

### Pumpkin appears but texture is wrong
- Check voxel library material override is `terrain_material.tres` (NOT blocky_terrain version)
- Verify UV coordinates in OBJ file match Terrain Mapper output
- Reload the voxel library (save and refresh Godot)

### Block doesn't appear in world
- Verify block ID constant is added to generator.gd
- Check spawn probability isn't set to 0
- Verify block name in blocks.gd matches voxel name

### Block doesn't render
- Confirm OBJ file path in blocks.gd is correct
- Verify mesh exists at that path
- Check voxel library entry has a valid mesh assigned

### Texture appears upside down or rotated
- This is a Blender/OBJ orientation issue
- Check if the OBJ file's vt coordinates need adjustment
- Compare with working block's OBJ file

---

## Next Steps

You're now ready to:
1. **Add more blocks** - Use this guide to repeat the process
2. **Implement Halloween feature** - Increase pumpkin spawn rate on Oct 31
3. **Add ghost entities** - Create friendly ghosts that appear with pumpkins
4. **Create rotating blocks** - Use `ROTATION_TYPE_Y` for blocks that can be placed in different orientations

Happy block creating! 🎃

