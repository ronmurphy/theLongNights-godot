# Adding Ice Block - Complete Guide

**Date:** November 1, 2025  
**Method:** Using TerrainMapper auto-edit + Manual voxel_library.tres setup

---

## Quick Summary

The TerrainMapper correctly calculates the next block ID by counting entries in `voxel_library.tres`. As of now, there are **47 blocks**, so ice will be **block ID 47**.

---

## Step-by-Step Process

### 1. Prepare Ice Texture

**Add to terrain.png:**
- Open `blocky_game/blocks/terrain.png` in image editor
- Find an empty grid cell (e.g., [3, 1] or any unused spot)
- Draw your ice texture (16×16 pixels)
- Light cyan/white colors: `#D0F0FF` to `#A0D0E0`
- Save the file

### 2. Use TerrainMapper

**In-game:**
```bash
# Press Ctrl+T to open TerrainMapper
```

**Steps:**
1. Click "Single Texture" mode (ice is same on all sides)
2. Click the grid cell with your ice texture
3. Check the sprite preview - looks good?
4. Enable "⚠️ Auto-edit project files (EXPERIMENTAL)"
5. Click "SAVE BLOCK"
6. Enter block name: **`ice`**
7. Click OK

**What auto-edit does:**
- ✅ Adds `const ICE = 47` to `generator.gd`
- ✅ Adds `_create_block()` call to `blocks.gd`
- ❌ Does NOT edit `voxel_library.tres` (you do this manually)

### 3. Add to voxel_library.tres (MANUAL)

**In Godot Editor:**

1. Navigate to `res://blocky_game/blocks/voxel_library.tres`
2. Click to open it in the Inspector
3. Expand the `models` array
4. Click the "+" button to add a new entry (this will be index 47)
5. Expand the new entry
6. Set properties:
   - `resource_name`: "ice" (lowercase)
   - `mesh`: Navigate to `res://blocky_game/blocks/ice/ice.obj`
   - `material_override_0`: `res://blocky_game/blocks/terrain_material.tres`
   - `collision_enabled`: ✅ **TRUE** (ice is solid!)
   - `collision_aabbs`: Add one entry: `AABB(0, 0, 0, 1, 1, 1)`
   - `collision_mask`: 1
   - `transparent`: false
7. Save the resource (Ctrl+S)

**IMPORTANT:** The array index MUST match the const ID in generator.gd (47).

### 4. Verify Auto-Edit Results

**Check generator.gd:**
```gdscript
// Around line 47-57, you should see:
const TEST = 46
const ICE = 47  // ← Should be added here
```

**Check blocks.gd:**
```gdscript
// In _init() function, at the end before func get_block():
_create_block({
    "name": "ice",
    "gui_model": "ice.obj",
    "rotation_type": ROTATION_TYPE_NONE,
    "voxels": ["ice"],
    "transparent": false
})
```

### 5. Test the Ice Block

**In-game console:**
```bash
give ice
# Place some ice blocks
# Walk on them - they should be solid!
```

---

## Why This Approach is Better

### Option A: Dynamic Collision Toggle (My Original Attempt)
❌ **Problem:** Can't find nodes at runtime - path issues  
❌ **Problem:** Complex state management for water/ice  
❌ **Problem:** Requires texture swapping system integration  

### Option B: Separate Ice Block (Current Approach)
✅ **Advantage:** Ice is just a normal solid block  
✅ **Advantage:** TerrainMapper handles 90% of work automatically  
✅ **Advantage:** Can give ice blocks to players  
✅ **Advantage:** No runtime collision toggling needed  

---

## Winter Season Integration

Once ice block is added, we can implement winter water freezing:

### Approach 1: Simple Swap
```gdscript
# In WinterIceSystem.gd
func freeze_water():
    # Find all water blocks in loaded chunks
    # Replace with ice blocks (ID 47)
    # Store positions for thawing later

func thaw_water():
    # Replace all ice blocks back to water
    # Resume water flow system
```

### Approach 2: Visual Only (Easier)
```gdscript
# Just use seasonal texture system
# Ice texture shows in winter (via winter.png)
# But water still non-solid
# Trade-off: not as immersive
```

**Recommendation:** Start with Approach 2 (visual only) since you already have winter water texture. Add Approach 1 (solid ice) later if players request it.

---

## TerrainMapper Block Counter - Verified Correct

**How it works:**
```gdscript
// Line 1143-1161 in TerrainMapper.gd
func _get_next_block_id_from_library(library_path: String) -> int:
    var file = FileAccess.open(library_path, FileAccess.READ)
    var content = file.get_as_text()
    
    // Count "resource_name =" occurrences
    var regex = RegEx.new()
    regex.compile("resource_name\\s*=")
    var matches = regex.search_all(content)
    
    var block_count = matches.size()
    return block_count  // This IS the next available ID
```

**Why this is correct:**
- Voxel library is 0-indexed
- If there are 47 blocks (IDs 0-46), next ID is 47
- `resource_name` appears exactly once per block
- Regex counts them accurately

**Current count:** 47 blocks (verified by grep)  
**Next ID:** 47 ✅

---

## Troubleshooting

### "Auto-edit failed" Message

**Cause:** File permissions, syntax errors, or unexpected file format

**Fix:**
1. Check console output for specific error
2. Manually add the code using instructions.txt
3. TerrainMapper still saved the OBJ and sprite files

### Ice Block Not Showing in Game

**Cause:** voxel_library.tres index doesn't match generator.gd const

**Fix:**
1. Open voxel_library.tres
2. Count the entries - should be 48 total (0-47)
3. Entry 47 should be "ice"
4. If not, you added ice to wrong index

### Ice Block Not Solid

**Cause:** Collision not enabled in voxel_library.tres

**Fix:**
1. Open voxel_library.tres → models → entry 47
2. Set `collision_enabled = true`
3. Set `collision_aabbs = [AABB(0,0,0,1,1,1)]`

### TerrainMapper Can't Find Insertion Point

**Cause:** generator.gd or blocks.gd format changed

**Fix:**
1. Use the manual instructions from `_instructions.txt`
2. Copy/paste the const and _create_block() code
3. TerrainMapper still created the OBJ file correctly

---

## Summary Checklist

- [ ] Ice texture added to terrain.png
- [ ] TerrainMapper opened (Ctrl+T)
- [ ] Ice texture cell selected
- [ ] Auto-edit enabled and block saved
- [ ] voxel_library.tres updated (entry 47)
- [ ] Collision enabled on ice voxel
- [ ] Tested ice block in-game (give ice)
- [ ] Ice is solid and walkable

---

## Next Steps

Once ice block works:

1. **Option A:** Implement water→ice swapping in winter (complex, immersive)
2. **Option B:** Use visual-only ice texture in winter (simple, good enough)
3. **Option C:** Both - visual ice texture + solid ice blocks players can craft

**My Recommendation:** Go with Option B for now. The winter water texture already looks frozen, and players won't notice it's not solid unless they try to walk on water. You can add solid ice later if it becomes a feature request.
