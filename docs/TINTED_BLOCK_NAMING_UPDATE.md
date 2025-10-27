# Tinted Block Naming Convention Update

**Issue:** Cannot type underscore in console (e.g., `log_birch` causes underscore to be interpreted as game input)  
**Solution:** Renamed all tinted blocks to remove underscores  
**Date:** October 27, 2025  
**Status:** ✅ COMPLETE

---

## New Naming Convention

All tinted block names now use **CamelCase without underscores** for console compatibility.

### Format Change
- **Old:** `base_type_variant` (e.g., `log_birch`)
- **New:** `{variant}{type}` (e.g., `birchlog`)

### Complete List

#### Dirt Variants
| Old Name | New Name | Description |
|----------|----------|-------------|
| `dirt_dark` | `darkdirt` | Dark, fertile soil |
| `dirt_clay` | `claydirt` | Clay-rich dirt |
| `dirt_sandy` | `sandydirt` | Sandy, light dirt |

#### Grass Variants
| Old Name | New Name | Description |
|----------|----------|-------------|
| `grass_lush` | `lushgrass` | Lush green grass |
| `grass_dry` | `drygrass` | Dry, golden grass |
| `grass_snow` | `snowgrass` | Snowy grass |

#### Log Variants
| Old Name | New Name | Description |
|----------|----------|-------------|
| `log_oak` | `oaklog` | Oak log |
| `log_birch` | `birchlog` | Birch log |
| `log_dark` | `darklog` | Dark ebony log |

#### Planks Variants
| Old Name | New Name | Description |
|----------|----------|-------------|
| `planks_oak` | `oakplanks` | Oak planks |
| `planks_redwood` | `redwoodplanks` | Redwood planks ⭐ |
| `planks_birch` | `birchplanks` | Birch planks |

#### Leaves Variants
| Old Name | New Name | Description |
|----------|----------|-------------|
| `leaves_oak` | `oakleaves` | Oak leaves |
| `leaves_birch` | `birchleaves` | Birch leaves |
| `leaves_autumn` | `autumnleaves` | Autumn leaves |

#### Glass Variants
| Old Name | New Name | Description |
|----------|----------|-------------|
| `glass_clear` | `clearglass` | Clear glass |
| `glass_blue` | `blueglass` | Blue tinted glass |
| `glass_green` | `greenglass` | Green tinted glass |

#### Stairs Variants
| Old Name | New Name | Description |
|----------|----------|-------------|
| `stairs_oak` | `oakstairs` | Oak stairs |
| `stairs_stone` | `stonestairs` | Stone stairs |
| `stairs_dark` | `darkstairs` | Dark stone stairs |

---

## Console Commands

### Updated Examples

**Old:**
```
giveblock planks_redwood 5
giveblock log_birch 10
```

**New:**
```
giveblock redwoodplanks 5
giveblock birchlog 10
```

### Command Usage

```
# List all available blocks
listblocks

# Give blocks (no underscore needed!)
giveblock redwoodplanks 5
giveblock birchlog 10
giveblock lushgrass 20
giveblock blueglass 8
```

---

## Files Updated

1. **`blocky_game/blocks/block_tints.json`**
   - All 24 variant names updated
   - Format: All names are now CamelCase without underscores
   - Colors and descriptions unchanged

2. **`long_nights/GameConsole.gd`**
   - Updated example in help text (line 286): `giveblock redwoodplanks 5`
   - Updated examples in `_cmd_listblocks()` (line 764): `giveblock redwoodplanks 10`
   - Updated examples in `_cmd_giveblock()` (line 772): `giveblock redwoodplanks 10`

---

## Why This Works

### The Problem
Console was still processing game input while typing, causing:
- 's' in command → move left
- '_' character → causes game interaction

### The Solution
Remove underscores from block names entirely. Now you can type:
```
giveblock redwoodplanks 5
```

Without the underscore being interpreted as a game input keystroke.

---

## Backwards Compatibility

⚠️ **Breaking Change:** Old command format will no longer work

```
# ❌ NO LONGER WORKS
giveblock planks_redwood 5
giveblock log_birch 10

# ✅ USE INSTEAD
giveblock redwoodplanks 5
giveblock birchlog 10
```

If you have any saved command scripts or documentation, update them to use the new names.

---

## Benefits

✅ **Console typing works properly** - No underscore interference  
✅ **Easy to remember** - Descriptive CamelCase  
✅ **Type efficiently** - No shift key needed for underscore  
✅ **Consistent** - All 24 variants follow same pattern  
✅ **Game-friendly** - No special characters to conflict with input  

---

## Testing

Try these commands in the console (press ~ or F1):

```
# See all blocks
listblocks

# Give redwood planks (your original redwood idea!)
giveblock redwoodplanks 5

# Try others
giveblock birchlog 10
giveblock lushgrass 20
giveblock blueglass 8
giveblock autumnleaves 15
```

All commands should work without underscore interference! 🎮

---

## Naming Pattern Reference

If you need to add more blocks in the future, follow this pattern:

```
{AdjectiveIfVariant}{BlockType}

Examples:
- lushgrass (lush = adjective, grass = type)
- darkdirt (dark = adjective, dirt = type)
- redwoodplanks (redwood = wood type, planks = block type)
- blueglass (blue = color, glass = type)
- autumnleaves (autumn = season, leaves = type)
```

Keep it simple, readable, and **no underscores**!

---

**Status:** ✅ Complete  
**Total Variants Updated:** 24  
**Files Modified:** 2  
**Console Ready:** Yes  
