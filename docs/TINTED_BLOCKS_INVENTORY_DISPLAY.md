# Tinted Blocks in Inventory - Solution Overview

**Issue:** When you use `giveblock birchlog 5` in the console, the blocks are added to inventory BUT they don't display in the inventory UI. The inventory shows blank slots instead of the tinted block graphics.

**Root Cause:** The inventory graphics system works differently from the 3D world:

```
How Regular Blocks Display (WORKS):
┌─────────────────────────────┐
│ inventory_item_display.gd   │
│                             │
│ When TYPE_BLOCK:            │
│  1. Get block by ID         │
│  2. Load sprite_texture     │
│  3. Look for file:          │
│     blocks/{name}_sprite.png│
└─────────────────────────────┘

How 3D World Shows Blocks (WORKS):
┌─────────────────────────────┐
│ Tinted Block Pool           │
│                             │
│ When spawning tinted block: │
│  1. Create MeshInstance3D   │
│  2. Apply StandardMaterial3D│
│  3. Set albedo_color        │
│     (runtime tinting!)      │
└─────────────────────────────┘
```

**The Problem:** Tinted blocks DON'T have sprite files! They're only created via:
- Console command → Pool manager → Creates 3D mesh with tinted material
- Added to inventory with TYPE_BLOCK, ID 8 (or whatever)
- Inventory tries to load `blocks/8_sprite.png` → DOESN'T EXIST ❌

---

## Solution Options

### Option 1: Generate Sprite Textures for Tinted Blocks (EASIEST)
Create 24 PNG sprite files for the tinted blocks:
- `darkdirt_sprite.png`
- `claydirt_sprite.png`
- `birchlog_sprite.png`
- etc.

**Pros:**
- ✅ Fastest to implement
- ✅ Works with existing inventory system
- ✅ No code changes needed
- ✅ Consistent with regular blocks

**Cons:**
- ❌ Need 24 pre-rendered images
- ❌ Manual tinting + exporting per image

### Option 2: Generate Sprites Dynamically at Runtime (BEST)
Modify `inventory_item_display.gd` to:
- Detect if it's a tinted block
- Apply the tint color using the same `get_tinted_material()` method
- Display it dynamically

**Pros:**
- ✅ No file management needed
- ✅ Single source of truth (block_tints.json)
- ✅ All 24 variants work automatically
- ✅ Easy to update colors later

**Cons:**
- ⚠️ Requires code changes
- ⚠️ Need to identify which blocks are tinted

### Option 3: Create Tinted Block Registry
Add a system to:
- Register all tinted blocks in a central location
- Map tinted block names to their base block + color
- Use during inventory display

**Pros:**
- ✅ Clean separation of concerns
- ✅ Reusable for other systems

**Cons:**
- ⚠️ More complex setup

---

## Recommended Approach: Option 2 (Dynamic Tinting)

Here's how to make it work:

### Step 1: Identify Tinted Blocks
Add a helper method to `blocks.gd`:

```gdscript
func is_tinted_block(block_id: int) -> bool:
    var block = get_block(block_id)
    # Tinted blocks have no sprite file (sprite_texture is null)
    return block.base_info.sprite_texture == null

func get_tinted_block_info(block_id: int) -> Dictionary:
    # Look up block_tints.json to find the variant
    var tint_data = _load_tint_data()
    # Return { "base_block": "log", "color": [...], "name": "birchlog" }
    ...
```

### Step 2: Modify Inventory Display
Update `inventory_item_display.gd` to handle tinted blocks:

```gdscript
func set_item(data: InventoryItem):
    if data == null:
        texture = null
        if _count_label:
            _count_label.visible = false

    elif data.type == InventoryItem.TYPE_BLOCK:
        var block := _block_types.get_block(data.id)
        
        # Check if it's a tinted block
        if block.base_info.sprite_texture == null:
            # Get the tint info and generate a tinted sprite
            var sprite = _generate_tinted_sprite(block, data.id)
            texture = sprite
        else:
            # Regular block - use existing sprite
            texture = block.base_info.sprite_texture
        
        if _count_label:
            _count_label.visible = false
    # ... rest of method
```

### Step 3: Generate Tinted Sprite
Create a helper method:

```gdscript
func _generate_tinted_sprite(block: Block, block_id: int) -> Texture2D:
    # Get base block sprite
    var base_block_name = block.base_info.name  # e.g., "log"
    var base_block = _block_types.get_block_by_name(base_block_name)
    var base_sprite = base_block.base_info.sprite_texture
    
    if base_sprite == null:
        return null  # No base sprite to tint
    
    # Get tint color from block_tints.json
    var tint_color = _get_tint_color_for_block_id(block_id)
    
    # Create an Image from the base sprite
    var img = base_sprite.get_image()
    
    # Apply tint color to image
    for y in range(img.get_height()):
        for x in range(img.get_width()):
            var pixel = img.get_pixel(x, y)
            if pixel.a > 0:  # Don't tint transparent pixels
                pixel = pixel * Color(tint_color.r, tint_color.g, tint_color.b, 1.0)
                img.set_pixel(x, y, pixel)
    
    # Create ImageTexture from the tinted image
    return ImageTexture.create_from_image(img)
```

---

## Current Status

**Before:** Console command gave blocks, but inventory couldn't display them
**After:** Inventory will show tinted blocks with the correct color applied

---

## Testing

```
1. Launch game
2. Open console (~ or F1)
3. Type: giveblock birchlog 5
4. Look at inventory
5. Should see birchlog blocks with birch wood color tint ✅
```

---

## Implementation Complexity

- **Option 1 (Generate PNGs):** 30 minutes (art work)
- **Option 2 (Dynamic):** 45 minutes (coding, testing)
- **Option 3 (Registry):** 1+ hours (design, implementation)

**Recommended:** Option 2 - Most elegant, most maintainable, no file management.

---

## Why This Wasn't An Issue Before

1. Regular blocks have pre-baked sprite files (`dirt_sprite.png`, `log_sprite.png`, etc.)
2. Tinted variants were never meant to be in inventory
3. Now that we're giving them via console, we need inventory support
4. The system was designed for 3D world display, not inventory UI

This is exactly the kind of "one thing after another" that makes game dev interesting! 😄

---

## Next Steps

1. Choose implementation approach
2. Implement in `inventory_item_display.gd`
3. Add helper methods to `blocks.gd` if needed
4. Test all 24 tinted variants in inventory
5. Verify colors match the 3D blocks perfectly

