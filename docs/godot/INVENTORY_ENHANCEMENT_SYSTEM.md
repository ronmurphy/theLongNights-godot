# Inventory Management & Enhancement System

## Overview
A progressive inventory system that expands with backpack upgrades, includes QoL stacking features, weapon enhancement through merging, and home storage at the crashed tower.

---

## Backpack System

### Backpack Tiers
**Current:** 9 columns × 3 rows = 27 bag slots + 9 hotbar = 36 total

**Tier Progression:**
- **Tier 0 (Starting):** 9×3 bag (27 slots) + 9 hotbar = 36 total ✓ Current
- **Tier 1 (Small Pack):** 9×4 bag (36 slots) + 9 hotbar = 45 total
- **Tier 2 (Large Pack):** 9×5 bag (45 slots) + 9 hotbar = 54 total
- **Tier 3 (Expedition Pack):** 9×6 bag (54 slots) + 9 hotbar = 63 total

### Window Size Consideration
**Godot Default:** 1280×720 (or 1152×648 for project settings)

**UI Constraints:**
- Each inventory slot: ~48×48 pixels
- 9 columns = 432 pixels wide
- 6 rows max = 288 pixels tall (reasonable)
- With padding/borders: ~500×400 pixels total
- **SAFE:** 9×6 fits comfortably in 720p window

**Alternative: Tabbed System** (Optional Future)
- Tabs: "Weapons" | "Tools" | "Blocks" | "Consumables"
- Each tab: 9×3 grid (27 slots)
- 4 tabs × 27 = 108 total slots
- More organization, same screen space
- Complexity: Higher (tab switching, filtering)

**Decision:** Start with **physical expansion (9×6 max)** for simplicity. Consider tabs later if needed.

---

## Quality of Life Features

### Stack-All Button
**Purpose:** Automatically combine partial stacks of the same item

**Location:** Bottom of inventory UI (next to close button)

**Behavior:**
```gdscript
func stack_all_items():
    var item_stacks = {}  # item_id -> array of slot indices

    # Group same items
    for i in range(inventory.size()):
        var item = inventory[i]
        if item != null and item.is_stackable():
            if not item_stacks.has(item.id):
                item_stacks[item.id] = []
            item_stacks[item.id].append(i)

    # Combine stacks
    for item_id in item_stacks:
        var slots = item_stacks[item_id]
        if slots.size() > 1:
            _merge_item_stacks(slots)

    _refresh_ui()
```

**Example:**
```
Before Stack-All:
Slot 5: Torch ×12
Slot 12: Torch ×8
Slot 23: Torch ×5

After Stack-All:
Slot 5: Torch ×25
Slot 12: Empty
Slot 23: Empty
```

**Visual Feedback:**
- Button glow/pulse when mergeable stacks exist
- "Stacks Combined: 3 → 1" message on click
- Satisfying "whoosh" sound effect

---

## Weapon Enhancement System

### Core Concept
**Duplicate weapons merge to create enhanced versions (+1, +2, +3, etc.)**

### How It Works

**When Picking Up Duplicate:**
1. Player already has "Grappling Hook +0" in inventory
2. Player picks up another "Grappling Hook"
3. System detects duplicate
4. Message: "Grappling Hook absorbed! Enhanced to +1"
5. Original item upgraded, duplicate consumed
6. Visual: Item glows briefly in inventory

**Enhancement Levels:**
- **+0:** Base item (default)
- **+1:** 10% improvement
- **+2:** 20% improvement
- **+3:** 30% improvement + bonus effect
- **+4:** 40% improvement + bonus effect
- **+5 (MAX):** 50% improvement + ultimate effect

### Enhancement Benefits by Item Type

#### Melee Weapons (Climbing Claws, Machete)
- **+0:** Base damage
- **+1:** +10% attack speed
- **+2:** +20% attack speed
- **+3:** +30% attack speed + lifesteal (heal 5 HP per hit)
- **+4:** +40% attack speed + lifesteal + knockback
- **+5:** +50% attack speed + lifesteal + knockback + critical hits (15% chance 2× damage)

#### Ranged Weapons (Rocket Launcher, Ice Bow)
- **+0:** Base damage, base reload
- **+1:** +10% faster reload
- **+2:** +20% faster reload
- **+3:** +30% faster reload + larger explosion/freeze radius
- **+4:** +40% faster reload + larger radius + piercing
- **+5:** +50% faster reload + larger radius + piercing + homing

#### Tools (Grappling Hook, Throwing Knives)
- **+0:** Base cooldown, base range
- **+1:** -10% cooldown
- **+2:** -20% cooldown + +10% range
- **+3:** -30% cooldown + +20% range + special effect
- **+4:** -40% cooldown + +30% range + special effect
- **+5:** -50% cooldown + +50% range + ultimate special

#### Consumables (Torches)
- **Already stackable, not enhanceable**
- Stack size remains count-based

### Visual Indicators
**In Inventory:**
- Item name shows level: "Grappling Hook +3"
- Glowing border (color intensity = level)
  - +1: Faint white glow
  - +2: Bright white glow
  - +3: Blue glow (rare)
  - +4: Purple glow (epic)
  - +5: Gold glow (legendary)
- Stat tooltips show bonuses

**In Hotbar:**
- Level number badge on icon (top-right corner)
- Glow effect

### Implementation Structure
```gdscript
# In InventoryItem.gd
var enhancement_level: int = 0
var max_enhancement: int = 5

func get_display_name() -> String:
    if enhancement_level > 0:
        return base_name + " +" + str(enhancement_level)
    return base_name

func get_enhancement_bonus(stat: String) -> float:
    match stat:
        "cooldown_reduction":
            return enhancement_level * 0.10
        "damage_bonus":
            return enhancement_level * 0.10
        "range_bonus":
            return enhancement_level * 0.10
    return 0.0

func has_special_effect(effect: String) -> bool:
    match effect:
        "lifesteal":
            return enhancement_level >= 3
        "knockback":
            return enhancement_level >= 4
        "critical":
            return enhancement_level >= 5
    return false
```

### Merging Logic
```gdscript
# In Inventory.gd
func try_merge_duplicate(new_item: InventoryItem) -> bool:
    # Find existing item of same type
    for i in range(slots.size()):
        var existing = slots[i]
        if existing != null and existing.id == new_item.id:
            if existing.enhancement_level < existing.max_enhancement:
                # Merge!
                existing.enhancement_level += 1
                _show_enhancement_message(existing)
                return true  # Item consumed

    return false  # No merge, add normally

func _show_enhancement_message(item: InventoryItem):
    var msg = item.get_display_name() + " enhanced!"
    # Show floating text above hotbar
    FloatingText.create(msg, Color.GOLD)
```

---

## Storage System

### Crashed Tower Storage
**Purpose:** Long-term storage for items not currently needed

**Location:** Inside crashed tower (spawn point)

**Implementation:**
- **2-4 storage chests** placed inside tower structure
- Each chest: 9×3 grid (27 slots) - same as bag
- Total storage: 54-108 slots (2-4 chests)
- Persistent across sessions (saved to world.config)

**Chest Placement:**
```
Inside crashed tower:
- Chest 1: Weapons & Tools (left side)
- Chest 2: Consumables & Resources (right side)
- (Optional) Chest 3: Building Blocks
- (Optional) Chest 4: Rare Items / Artifacts
```

**UI:**
- Click chest → Opens chest inventory (top) + player inventory (bottom)
- Drag items between chest and player
- "Transfer All" button (move all items one direction)
- "Sort" button (organizes chest contents)

**Visual:**
- Wooden chests with glowing runes (matching portal theme)
- Different colored runes per chest (red = weapons, green = consumables)

### Home Base Building
**Inspired by:** Player who built around crashed tower! 🏠

**Encourage Player-Built Bases:**
- Crashed tower portal is permanent (always accessible via home stones)
- Storage chests make it natural "hub"
- Players can build walls, rooms, structures around it
- Future: Workbenches, furnaces, farm plots nearby

**No Forced Building:**
- Chests work fine without player buildings
- Building is optional aesthetic/roleplay choice

---

## Backpack Upgrade Items

### Finding Backpack Upgrades
**Drop Locations:**
- Tier 1 (Small Pack): Common chest drop (30% chance in first 3 ruins)
- Tier 2 (Large Pack): Uncommon chest drop (15% chance after 5 ruins)
- Tier 3 (Expedition Pack): Rare chest drop (8% chance after 10 ruins)

**Item Properties:**
```gdscript
{
    "id": 13,  # Small Backpack
    "name": "Small Backpack",
    "type": TYPE_ITEM,
    "icon": "res://items/backpack_small/backpack_small_sprite.png",
    "stackable": false,
    "use_behavior": "upgrade_inventory",
    "upgrade_to_tier": 1
}
```

**Usage:**
1. Player finds backpack in chest
2. Right-click in inventory → "Use"
3. Confirmation: "Upgrade to Small Backpack? (9×4 slots)"
4. Inventory expands immediately
5. Backpack item consumed
6. Existing items remain in place

**Visual Feedback:**
- Inventory panel smoothly expands
- New row appears with animation
- "Inventory Expanded!" message

---

## Future: Cooking & Farming System

### Brief Overview (To Be Designed Later)

**Farm System:**
- Plant crops near crashed tower
- Water, sunlight, time = growth
- Harvest vegetables, herbs, grains

**Cooking System:**
- Cooking station (campfire or furnace)
- Combine ingredients for meals
- Meals provide buffs (HP regen, speed, damage)

**Integration with Inventory:**
- Food items stackable (like torches)
- Cooked meals = consumable items
- Buffs displayed in HUD

*Full design document needed - see COOKING_FARMING_SYSTEM.md (future)*

---

## Implementation Phases

### Phase 1: Stack-All Button (Immediate QoL)
**Goal:** Quick inventory cleanup

**Tasks:**
1. Add "Stack All" button to inventory UI
2. Implement stacking algorithm
3. Add visual feedback (items merge animation)
4. Test with torches, portal compasses, blocks
5. Add sound effect

**Time Estimate:** 1-2 hours

### Phase 2: Backpack Upgrades (Expansion)
**Goal:** More inventory space

**Tasks:**
1. Create backpack upgrade items (3 tiers)
2. Add to chest loot tables
3. Implement inventory expansion on use
4. Test UI scaling (9×4, 9×5, 9×6)
5. Save/load backpack tier

**Time Estimate:** 2-3 hours

### Phase 3: Weapon Enhancement (Core System)
**Goal:** Make duplicates valuable

**Tasks:**
1. Add enhancement_level to InventoryItem
2. Implement merge detection on pickup
3. Add stat bonuses per level
4. Create visual indicators (glows, badges)
5. Update item tooltips to show bonuses
6. Test with all weapon types

**Time Estimate:** 4-5 hours

### Phase 4: Crashed Tower Storage (Home Base)
**Goal:** Long-term storage solution

**Tasks:**
1. Place 2-4 chests inside crashed tower
2. Create chest interaction system
3. Implement chest inventory UI
4. Add persistence (save chest contents)
5. Test transfer, sorting, loading

**Time Estimate:** 3-4 hours

---

## Balance Considerations

### Enhancement Progression
- **Early Game (0-5 ruins):** +0 to +1 items (learning mechanics)
- **Mid Game (5-15 ruins):** +2 to +3 items (power spike, special effects unlock)
- **Late Game (15+ ruins):** +4 to +5 items (optimization, preparing for bosses)

### Duplicate Drop Rates
- **Common weapons** (grappling hook, throwing knives): High duplication rate
- **Rare weapons** (rocket launcher, ice bow): Medium duplication rate
- **Unique items** (future legendaries): No duplication

### Storage Limits
- Total possible slots with max backpack + 4 chests: 63 + 108 = 171 slots
- Should be MORE than enough for endgame
- Encourages organization and choice

---

## Technical Notes

### Inventory Slot Calculation
```gdscript
# In Inventory.gd
const BASE_BAG_ROWS = 3
const HOTBAR_SLOTS = 9

var backpack_tier: int = 0  # 0-3

func get_total_bag_slots() -> int:
    return HOTBAR_SLOTS * (BASE_BAG_ROWS + backpack_tier)

func get_total_slots() -> int:
    return get_total_bag_slots() + HOTBAR_SLOTS
```

### Enhancement Stat Application
```gdscript
# In weapon script (e.g., grappling_hook.gd)
func get_cooldown() -> float:
    var base_cooldown = 2.0
    var reduction = inventory_item.get_enhancement_bonus("cooldown_reduction")
    return base_cooldown * (1.0 - reduction)

func get_range() -> float:
    var base_range = 30.0
    var bonus = inventory_item.get_enhancement_bonus("range_bonus")
    return base_range * (1.0 + bonus)
```

### Chest Persistence
```gdscript
# In WorldManager.gd
var _world_data = {
    # ... existing fields ...
    "crashed_tower_chests": [
        {"slot_0": {...}, "slot_1": {...}, ...},  # Chest 1
        {"slot_0": {...}, "slot_1": {...}, ...},  # Chest 2
        # ... etc
    ]
}
```

---

## Design Rationale

### Why Physical Expansion over Tabs?
- **Simpler UI:** No tab switching, everything visible
- **Faster gameplay:** See all items at once
- **Godot-friendly:** 9×6 fits 720p comfortably
- **Future-proof:** Can add tabs later if needed

### Why Enhancement over Selling?
- **Survival feel:** No currency/economy breaking immersion
- **Progression:** Getting +5 weapons feels earned
- **Simplicity:** No shop UI, pricing, merchant NPCs
- **Replayability:** Finding duplicates always useful

### Why Crashed Tower Storage?
- **Narrative significance:** Home base at origin point
- **Convenience:** Purple home stones teleport here
- **Player building:** Encourages base construction
- **Safe location:** Permanent, never despawns

---

## Version History
- **v0.1** - Initial design document (2025-01-XX)
