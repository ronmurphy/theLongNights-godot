# Save System Bug Report: Voxel Region File Corruption

## Issue Summary

**Error**: `LUT block size corruption` errors appearing when playing on saved games
```
E 0:01:13:205   debug_check: LUT 2960 (9, 0, 11): block size 536870968 at offset 106004 is larger than remaining size 260604
  <C++ Source>  modules/voxel/streams/region/region_file.cpp:710 @ debug_check()
```

**Severity**: HIGH - Corrupts saved game data, causes performance issues, prevents normal gameplay in Undervoid

**Status**: DOCUMENTED - Needs fix for future saves

---

## Root Cause Analysis

### The Problem

The save system has a **timing/synchronization issue** between:
1. **Entity-to-Voxel Conversion** (PushBlockManager)
2. **Terrain Region File Saving** (VoxelStreamRegionFiles)

When these operations don't synchronize properly, the voxel region file's LUT (Look-Up Table) header becomes corrupted.

### Technical Details

**File Locations**:
- Save orchestration: `/long_nights/WorldManager.gd` (lines 175-176)
- Entity conversion: `/blocky_game/PushBlockManager.gd` (lines 203-247)
- Save trigger: `/blocky_game/gui/PauseMenu.gd` (lines 157-183)
- Exit save: `/blocky_game/blocky_game.gd` (lines 317-321)
- Region files: `user://save/` directory

**The Sequence (Currently Broken)**:

```
PauseMenu._save_game()
  ├─ Update player position
  ├─ Sync companion equipment
  ├─ Call WorldManager.save_world()
  │   └─ PushBlockManager.convert_entities_to_voxels_for_save()
  │       └─ Writes voxels directly to terrain
  │       └─ Defers entity deletion (queue_free)
  └─ Call terrain.save_modified_blocks()  ← PROBLEM: Happens AFTER conversion
      └─ Writes region files
      └─ May conflict with chunk generation still in progress
```

**Why This Corrupts Data**:

1. Push blocks are converted to voxels (written to terrain)
2. Entities are marked for deletion (deferred, not immediate)
3. Terrain save writes region files
4. If chunk generation is still happening simultaneously, **LUT headers misalign**
5. Region file corruption: block size field doesn't match actual data
6. Voxel engine cannot parse the corrupted region file on next load

### When This Manifests

- After saving a game with push blocks present
- Most common in Undervoid (where structures are being spawned and saved)
- Can accumulate over multiple save/load cycles
- Once corrupted, errors persist and grow worse

---

## Current Status

**Current Save Status**: Corrupted (likely unrecoverable due to LUT header damage)

**New Games**: Will continue to have this bug until fixed

**Next Game After Fix**: Should not experience this issue

---

## Solution: Save Pipeline Synchronization

### The Fix

Move terrain save INSIDE the world save function with proper synchronization:

**File**: `/long_nights/WorldManager.gd`

**Current Code (Broken)** (lines 168-176):
```gdscript
func save_world() -> bool:
    # ... serialize player data ...
    var json_string = JSON.stringify(save_data)
    var file = FileAccess.open(world_path, FileAccess.WRITE)
    file.store_string(json_string)

    if push_block_manager.has_method("convert_entities_to_voxels_for_save"):
        push_block_manager.convert_entities_to_voxels_for_save()
    # ← Terrain save happens AFTER this, in caller
```

**Fixed Code**:
```gdscript
var _saving := false  # Add save lock flag

func save_world() -> bool:
    if _saving:
        push_error("Save already in progress!")
        return false

    _saving = true

    # Step 1: Convert entities to voxels FIRST
    if push_block_manager and push_block_manager.has_method("convert_entities_to_voxels_for_save"):
        push_block_manager.convert_entities_to_voxels_for_save()

        # Step 2: Wait for deferred deletions to complete
        await get_tree().process_frame
        await get_tree().process_frame

    # Step 3: THEN save terrain (preventing concurrent operations)
    var terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")
    if terrain:
        terrain.save_modified_blocks()

    # Step 4: Finally save world metadata
    var save_data = {
        # ... existing save data ...
    }
    var json_string = JSON.stringify(save_data)
    var file = FileAccess.open(world_path, FileAccess.WRITE)
    if file:
        file.store_string(json_string)
        print("✓ World saved successfully")
    else:
        push_error("Failed to save world metadata")
        _saving = false
        return false

    _saving = false
    return true
```

**File**: `/blocky_game/gui/PauseMenu.gd`

**Current Code (lines 157-183)**:
```gdscript
func _save_game():
    # ... sync code ...
    WorldManager.save_world()
    terrain.save_modified_blocks()  ← Happens after
```

**Fixed Code**:
```gdscript
func _save_game():
    # ... sync code ...
    var success = await WorldManager.save_world()  # Wait for complete save
    if success:
        print("Game saved successfully!")
    else:
        print("Save failed - check logs")
```

---

## Implementation Checklist

- [ ] Add `_saving` flag to WorldManager
- [ ] Move terrain save into `save_world()` function
- [ ] Add frame waits after entity conversion
- [ ] Update PauseMenu to `await` the save
- [ ] Update exit save in blocky_game.gd to use new system
- [ ] Test saving with push blocks present
- [ ] Test saving during Undervoid exploration
- [ ] Verify no LUT errors appear
- [ ] Test new game + multiple save/load cycles
- [ ] Document the fix in commit message

---

## Prevention Measures for Future

### 1. Save Lock Flag
Prevents concurrent save attempts:
```gdscript
var _saving := false
if _saving:
    return false  # Prevent nested saves
```

### 2. Atomic Save Operations
All entity and terrain operations in single uninterruptible block

### 3. Async/Await Pattern
Use `await` to ensure operations complete in correct order

### 4. Validation Check
Could add post-save validation:
```gdscript
# After save completes
if _validate_region_files():
    print("✓ Region files OK")
else:
    print("✗ Region file corruption detected - restore from backup")
```

### 5. Backup Before Save
Keep backup of region files:
```gdscript
# Before save
_backup_region_files()
# ... perform save ...
# If failed: _restore_region_files()
```

---

## Related Code Sections

### PushBlockManager Conversion
**File**: `/blocky_game/PushBlockManager.gd` (lines 203-247)
- Converts push block entities to voxels
- Uses deferred deletion (queue_free)
- Called during save

### WorldManager Save
**File**: `/long_nights/WorldManager.gd` (lines 168-225)
- Orchestrates world save
- Calls push block conversion
- Saves world metadata

### PauseMenu Save Trigger
**File**: `/blocky_game/gui/PauseMenu.gd` (lines 157-183)
- User initiates save via pause menu
- Syncs companion equipment
- Calls world save

### Exit Save
**File**: `/blocky_game/blocky_game.gd` (lines 317-321)
- Saves on window close
- Uses `NOTIFICATION_WM_CLOSE_REQUEST`
- Also needs update to use new save system

---

## Impact Assessment

**Current Saves**:
- May have corrupted region files
- Will continue to see LUT errors
- Limited gameplay possible but not ideal

**New Saves (After Fix)**:
- Should not experience this issue
- Proper synchronization prevents corruption
- Safe to play indefinitely without corruption

**Development Impact**:
- Moderate refactoring needed
- ~2-3 hours of work
- Should include testing on multiple save cycles

---

## Notes for Tomorrow

- This is a **save system architecture issue**, not related to the Undervoid performance optimizations we completed
- The Undervoid fixes are working correctly
- The LUT errors are from **pre-existing corruption** in the saved game
- Fix is **non-critical for current gameplay** but important for next playtesting cycle
- Consider starting fresh game after implementing the fix to test it properly

---

## References

- **Voxel Region File System**: Godot VoxelStreamRegionFiles (C++ module)
- **LUT Error Location**: `modules/voxel/streams/region/region_file.cpp:710`
- **Save System Files**: WorldManager, PauseMenu, PushBlockManager, blocky_game.gd
- **Related Issue**: Entity-to-voxel conversion timing conflicts with terrain serialization
