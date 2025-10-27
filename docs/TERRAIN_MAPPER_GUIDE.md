# Terrain Mapper Tool - User Guide

## Overview
The Terrain Mapper is a visual tool for creating new blocks in The Long Nights. It helps you map texture coordinates and generate the code needed to add blocks to the game.

## Opening the Mapper
- Press **Ctrl+T** to toggle the Terrain Mapper open/closed
- Game controls are automatically disabled while the mapper is open
- Game controls are automatically re-enabled when you close it

## Using the Terrain Mapper

### 1. Select a Texture
- The terrain atlas (16×16 grid) is displayed on the left
- Click on any cell in the grid to select that texture location
- The selected cell will be highlighted with a green border

### 2. View Generated Information
The right panel displays all the information you need:

**Grid Coordinates:**
- Shows (x, y) position in the 16×16 grid
- Example: (3, 5)

**UV Coordinates:**
- Shows the texture mapping coordinates for 3D models
- Example: U: 0.1875 - 0.2500, V: 0.3125 - 0.3750

**blocks.gd Template:**
- Copy-paste ready code to add to blocks.gd
- Example:
```gdscript
_create_block({
    "name": "new_block_3_5",
    "gui_model": "new_block_3_5.obj",
    "rotation_type": ROTATION_TYPE_NONE,
    "voxels": ["new_block_3_5"],
    "transparent": false
})
```

**OBJ File Template:**
- Instructions for creating/modifying the OBJ file
- Shows exact UV coordinates to use for all 6 faces

## Workflow to Add a New Block

### Step 1: Find an Empty Cell
1. Open Terrain Mapper (Ctrl+T)
2. Click on an empty cell in the texture grid
3. Take note of the grid coordinates and UV values

### Step 2: Create the Texture
1. Close the Terrain Mapper (Ctrl+T or click CLOSE button)
2. Open `terrain.png` in GIMP or your image editor
3. Navigate to the grid cell you selected
4. Draw your new block texture (16×16 pixels in that grid square)
5. Save the file

### Step 3: Create the OBJ File
1. Open `dirt.obj` as a template
2. Rename it to match your block name (e.g., `new_block_3_5.obj`)
3. Replace all the `vt` (texture coordinate) lines with the values shown in the mapper
4. Copy all other content from dirt.obj as-is
5. Save in `/project/blocky_game/blocks/` folder

### Step 4: Update blocks.gd
1. Open `/project/blocky_game/blocks/blocks.gd`
2. Find the `_init()` function where blocks are defined
3. Copy-paste the template code from the mapper into this function
4. Customize the name and properties as needed
5. Save the file

### Step 5: Test
1. Launch the game
2. Your new block should be available in the world!

## Example: Adding a "Marble" Block

**Mapper shows (5, 2):**
- Grid Coordinates: (5, 2)
- UV: U: 0.3125 - 0.3750, V: 0.1250 - 0.1875

**In GIMP:**
- Navigate to grid square (5, 2) on terrain.png
- Draw your marble texture there

**Create marble.obj:**
- Copy dirt.obj to marble.obj
- Update vt lines to the UV coordinates from mapper

**In blocks.gd, add:**
```gdscript
_create_block({
    "name": "marble",
    "gui_model": "marble.obj",
    "rotation_type": ROTATION_TYPE_NONE,
    "voxels": ["marble"],
    "transparent": false
})
```

## Tips

- **Grid is 16×16:** That's 256 possible texture locations, plenty of room!
- **Reuse OBJ files:** All simple cube blocks use nearly identical OBJ files - just UV coordinates differ
- **Texture size:** Each grid square is designed for 16×16 pixel textures
- **Multiple variations:** Can create variants by using different grid squares (e.g., marble_dark, marble_light)
- **Transparent blocks:** Set `"transparent": true` for vegetation, glass, etc.

## Troubleshooting

**Block doesn't appear:**
- Check the block name matches between blocks.gd and .obj file
- Verify OBJ file is in `/project/blocky_game/blocks/` folder
- Check UV coordinates are correct in OBJ file

**Wrong texture on block:**
- Verify UV coordinates match between mapper and OBJ file
- Check that terrain.png was saved with your new texture
- Verify the grid cell in terrain.png has the correct texture

**Texture upside down or mirrored:**
- OBJ coordinate system uses bottom-left origin
- The mapper automatically inverts V coordinates for this
- If still wrong, swap min/max V values in OBJ file

## Closing the Mapper

Press **Ctrl+T** again or click the **CLOSE** button to close the mapper and return to the game.
