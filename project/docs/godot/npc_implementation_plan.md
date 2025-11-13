# NPC System Implementation Plan

**Status:** Ready to implement (evening session)
**Estimated Time:** ~2 hours for MVP
**Dependencies:** testNPC system (✅), CookingModal (✅), Power Harmonization UI (✅)

---

## What's Already Built (90% Complete!)

### ✅ testNPC System (`blocky_game/entities/test_npc.gd`)
- Complete wandering NPC with sprites, health bars
- Race/gender support (human, elf, dwarf, goblin)
- Color-coded by role:
  - Green = Healer
  - Blue-gray = Tank
  - Purple = Rogue
  - Blue = Wizard
  - White = Utility (shopkeepers)
- Already spawns at home base via HomeBaseManager
- Has wander AI, sprite direction switching

### ✅ HomeBaseManager (`blocky_game/home_base_manager.gd`)
- `spawn_companion_npc()` - spawns benched companions as NPCs
- `_get_role_color()` - assigns colors by role
- Spawns NPCs in circle around home base (5 block radius)
- Save/load support

### ✅ Cooking System
- CookingModal UI complete and functional
- Console command `cooking` opens it
- Just needs NPC gating

### ✅ Power Harmonization
- Button in inventory UI (line 82-83 in inventory.gd)
- `_show_power_harmonization_modal()` function exists
- Full modal UI implemented
- Just needs NPC gating

---

## What's Missing (The Glue)

### ❌ NPC Right-Click Interaction
- Raycast detection for NPC entities
- Open dialog/shop modal on interaction
- Different modals based on NPC job type

### ❌ NPC Job Types System
Two categories of NPCs:

#### 1. Companion NPCs (Swappable)
- **Job Types:** healer, tank, rogue, wizard
- **Function:** Can swap with active companion
- **Interaction:**
  - Right-click → "Would you like to swap companions?"
  - Shows their stats/role
  - Swap button swaps active companion with this one

#### 2. Utility NPCs (Shopkeepers)
- **Job Types:** cook, blacksmith, merchant, armorer
- **Function:** Provide services/trades
- **Interaction:**
  - Right-click → Opens their specific UI
  - Cook → CookingModal
  - Armorer → Power Harmonization Modal
  - Merchant → Buy/Sell Shop (TODO)
  - Blacksmith → Rust→Iron Trade (TODO, see barter.md)

### ❌ Shop/Trade UI
- Buy/sell modal for merchant
- Trade calculator for blacksmith
- Time-gated completion tracking

---

## Implementation Steps (Tonight's Session)

### Step 1: Add Right-Click Detection (30 min)
**File:** `blocky_game/player/avatar_interaction.gd`

```gdscript
# Add to _physics_process or interaction handler
func _check_npc_interaction():
    if Input.is_action_just_pressed("right_click"):
        var hit = _raycast_for_interaction()
        if hit and hit.collider.is_in_group("npcs"):
            var npc = hit.collider
            _open_npc_dialog(npc)
```

**Tasks:**
- [x] Add raycast detection for NPC group
- [x] Create `_open_npc_dialog(npc)` function
- [x] Pass NPC reference to dialog handler

---

### Step 2: Add Job Type to testNPC (15 min)
**File:** `blocky_game/entities/test_npc.gd`

```gdscript
# Add variable
var npc_job: String = "companion"  # "companion", "cook", "blacksmith", "merchant", "armorer"
var npc_dialog: String = "Hello there!"  # Greeting text

# Update initialize() to accept job parameter
func initialize(race, gender, color, display_name, job = "companion", dialog = ""):
    npc_job = job
    npc_dialog = dialog if dialog != "" else _get_default_dialog(job)
```

**Tasks:**
- [x] Add `npc_job` and `npc_dialog` variables
- [x] Update `initialize()` signature
- [x] Create `_get_default_dialog(job)` helper function
- [x] Update HomeBaseManager to pass job type when spawning

---

### Step 3: Route to Existing UIs (30 min)
**File:** `blocky_game/player/avatar_interaction.gd` or new `npc_interaction_handler.gd`

```gdscript
func _open_npc_dialog(npc):
    var job = npc.npc_job

    match job:
        "cook":
            _open_cooking_modal()  # Reuse existing cooking command code

        "armorer":
            _open_harmonization_modal()  # Reuse existing inventory code

        "companion":
            _show_companion_swap_dialog(npc)

        "merchant", "blacksmith":
            _show_placeholder_dialog(npc, "Coming soon!")
```

**Tasks:**
- [x] Create dialog router function
- [x] Connect cook → CookingModal
- [x] Connect armorer → Power Harmonization
- [x] Create simple companion swap dialog
- [x] Add "Coming Soon" placeholder for merchant/blacksmith

---

### Step 4: Companion Swap Dialog (30 min)
**File:** New modal or extend existing dialog system

```gdscript
func _show_companion_swap_dialog(npc):
    # Create modal showing:
    # - NPC stats (race, gender, role, HP, damage, defense)
    # - Current active companion stats
    # - "Swap Companion" button
    # - "Cancel" button

    # On swap:
    # 1. Despawn active companion at current location
    # 2. Spawn NPC as active companion at player position
    # 3. Update CompanionManager roster
    # 4. Spawn old companion as NPC at home base
```

**Tasks:**
- [x] Create swap confirmation modal
- [x] Display both companion stats side-by-side
- [x] Implement swap logic
- [x] Update home base benched NPCs

---

### Step 5: Simple Merchant Shop (45 min)
**File:** New `blocky_game/gui/MerchantShopModal.gd`

```gdscript
# Reuse inventory UI patterns
# Two columns:
# - Left: Merchant's items for sale (with prices)
# - Right: Player's items to sell (with values)

# Example items:
BUY_ITEMS = {
    "cooking_ingredients": {
        "wheat": 5,      # 5 gold ore
        "berries": 3,
        "honey": 8
    },
    "tools": {
        "portal_compass": 10,
        "teleport_stone": 2
    }
}

SELL_PRICES = {
    "loot": {
        "skyshard": 2,
        "gold_ore": 1,
        "iron_block": 3
    }
}
```

**Tasks:**
- [x] Create merchant shop modal UI
- [x] Define buy/sell item lists
- [x] Add transaction handlers
- [x] Integrate with player inventory
- [x] Add gold ore as currency (or use barter system per barter.md)

---

## Testing Checklist

### Companion Swap
- [ ] Spawn testNPC at home base with "companion" job
- [ ] Right-click NPC → shows swap dialog
- [ ] Swap works and updates active companion
- [ ] Old companion appears as NPC at home base

### Cook NPC
- [ ] Spawn testNPC with "cook" job
- [ ] Right-click → opens CookingModal
- [ ] Can cook food via NPC
- [ ] Modal closes properly

### Armorer NPC
- [ ] Spawn testNPC with "armorer" job
- [ ] Right-click → opens Power Harmonization modal
- [ ] Can harmonize powers via NPC
- [ ] Modal closes properly

### Merchant Shop
- [ ] Spawn testNPC with "merchant" job
- [ ] Right-click → opens shop UI
- [ ] Can buy items (deducts payment)
- [ ] Can sell items (adds payment)
- [ ] Inventory updates correctly

---

## Console Commands for Testing

```gdscript
# Spawn NPCs with different jobs
npc human female white "Chef Emma" cook
npc dwarf male white "Armorer Thrain" armorer
npc elf female white "Merchant Lyra" merchant
npc goblin male white "Tank Grok" companion tank
```

**Note:** Need to update `npc` console command to accept job parameter

---

## Future Enhancements (Phase 2)

### Time-Gated Trades (Blacksmith)
- Store active trade in WorldManager
- Track completion time (next noon)
- Check on NPC interaction if trade ready
- Auto-add items to inventory when ready

### NPC Reputation System
- Track trades with each NPC
- Better rates with higher reputation
- Special dialog/items at high rep

### NPC Quests
- "Bring me 10 skyshards for special reward"
- Quest tracking UI
- Unique rewards

### More Shop Types
- Alchemist (potions/buffs)
- Builder (constructs structures)
- Farmer (grows crops while you adventure)

---

## File Structure

```
blocky_game/
├── entities/
│   └── test_npc.gd               ✅ Exists - needs job type added
├── gui/
│   ├── CookingModal.gd           ✅ Exists - ready to use
│   ├── inventory/inventory.gd    ✅ Exists - has harmonization
│   ├── MerchantShopModal.gd      ❌ TODO - create tonight
│   └── CompanionSwapDialog.gd    ❌ TODO - create tonight
├── player/
│   └── avatar_interaction.gd     ✅ Exists - add NPC raycast
└── home_base_manager.gd          ✅ Exists - update spawn calls

docs/godot/
├── barter.md                     ✅ Design doc (reference)
└── npc_implementation_plan.md    📄 This file
```

---

## Key Design Decisions

### Why Color-Coded Companions?
- Visual instant recognition of role
- No UI needed to identify healer vs tank
- Matches existing CompanionManager role system

### Why Two NPC Categories?
1. **Companions** - swappable, combat-focused, benched at home
2. **Shopkeepers** - permanent, utility-focused, stay at home

### Why Reuse Existing UIs?
- Cook uses CookingModal (already built)
- Armorer uses Power Harmonization (already built)
- Faster implementation, consistent UX

### Why Start Simple?
- Get basic interaction working first
- Add complexity (time gates, reputation) later
- Can playtest and iterate quickly

---

## Open Questions

1. **Currency or Barter?**
   - Option A: Use gold ore as currency (simple)
   - Option B: Pure barter like barter.md describes (immersive)
   - **Decision:** Start with gold ore, can add barter preferences later

2. **Where do Shopkeeper NPCs spawn?**
   - Option A: Always at home base (convenient)
   - Option B: Find them in world (exploration)
   - **Decision:** Home base for now, can add world spawns later

3. **Can shopkeeper NPCs wander?**
   - Option A: Stay stationary (easy to find)
   - Option B: Wander like current testNPC (more alive)
   - **Decision:** Wander with small radius (5 blocks), feels alive but findable

4. **Console command for spawning NPCs with jobs?**
   - Update: `npc <race> <gender> <color> <name> [job]`
   - Example: `npc human female white "Chef" cook`

---

## Success Criteria (MVP)

By end of tonight's session:
- ✅ Right-click NPC to interact
- ✅ Cook NPC opens CookingModal
- ✅ Armorer NPC opens Power Harmonization
- ✅ Companion NPC shows swap dialog (basic)
- ✅ Merchant NPC opens simple shop UI
- ✅ Can buy/sell at least 3 items
- ✅ All modals close properly
- ✅ No errors in console

**Stretch Goals:**
- Time-gated blacksmith trades
- NPC conversation dialog before shop
- Multiple merchants with different inventories

---

*"NPCs aren't just shopkeepers - they're your benched companions, your crafters, your survival team!"*
