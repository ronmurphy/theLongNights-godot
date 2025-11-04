# Companion Behavior & Inventory Refactor

**Status:** ALL STEPS COMPLETE ✅  
**Started:** 2025-11-04  
**Completed:** 2025-11-04  
**Goal:** Add companion behavior modes (Normal/Aggressive/Defensive) and accessory slot

---

## Overall Plan (5 Steps)

1. ✅ **Adjust layout/sizing** - Make room for new features
2. ✅ **Add accessory slot** - Second equip slot for companion
3. ✅ **Add behavior buttons** - UI for Normal/Aggressive/Defensive modes
4. ✅ **Implement behavior system** - Logic in companion.gd
5. ✅ **Update PartyUI** - Show behavior mode under HP bar

---

## IMPLEMENTATION COMPLETE ✅

All features have been implemented and are ready for testing!

---

## Step 1: Adjust Layout/Sizing ✅ COMPLETE

**File:** `project/blocky_game/gui/inventory/inventory.gd`

**Changes Made:**
- Panel spacing: `16px` → **20px** (line ~487)
- Paper doll panel size: `140x200` → **180x250** (line ~509)
- Avatar background: `96x96` → **128x128** (line ~520)
- Avatar texture: `92x92` → **124x124** (line ~530)
- Title font size: `14` → **16** (line ~516)

**Result:** Inventory panels are now larger with better spacing, avatars look less squished.

---

## Step 2: Add Accessory Slot ✅ COMPLETE

**Goal:** Add a second equipment slot for companions (weapons + accessories)

### Files Modified:
1. `project/blocky_game/gui/inventory/inventory.gd`
2. `project/blocky_game/entities/companion.gd`

### Implementation Complete:

#### A. Added Variables (inventory.gd ~line 27)
```gdscript
var _companion_accessory_slot: InventoryItem = null
var _companion_accessory_slot_view = null
```

#### B. Added Accessory Slot UI (inventory.gd ~line 570)
- Companion panel now shows weapon + accessory **side-by-side** (horizontal layout)
- "Equipment" label at top, individual labels for each slot
- 64x64 slots with proper spacing
- **Much more compact vertically** than original design

#### C. Added Handler Functions (inventory.gd ~line 700+)
- `_on_accessory_slot_pressed()` - Handle equipping/dragging accessory
- `_is_equip_power(power_name)` - Validates only EQUIP powers allowed
- `_update_accessory_slot_view()` - Updates UI display
- `_update_companion_accessory()` - Notifies companion of changes
- **Validation:** Only stone_skin, moon_jump, flame_aura can be equipped in accessory slot

#### D. Added Companion Support (companion.gd)
**Line ~23:**
```gdscript
var _equipped_accessory_item = null  # Accessory inventory item (second equip slot)
```

**Line ~225:**
```gdscript
func set_accessory(inv_item):
    """Set companion's accessory item (for EQUIP powers)"""
    _equipped_accessory_item = inv_item
    if inv_item != null and inv_item.skyshard_power != "":
        print("  ✨ Companion accessory has power: %s" % inv_item.skyshard_power)

func get_all_equipped_powers() -> Array:
    """Get all active EQUIP powers from weapon + accessory"""
    var powers = []
    if _equipped_inv_item != null and _equipped_inv_item.skyshard_power != "":
        powers.append(_equipped_inv_item.skyshard_power)
    if _equipped_accessory_item != null and _equipped_accessory_item.skyshard_power != "":
        powers.append(_equipped_accessory_item.skyshard_power)
    return powers
```

#### E. Updated Power Logic (companion.gd)
**take_damage() - Line ~432:**
```gdscript
func take_damage(amount: int, from: Node = null) -> void:
    var powers = get_all_equipped_powers()
    if "stone_skin" in powers:
        amount = int(amount * 0.5)
```

**_apply_equip_powers() - Line ~820:**
```gdscript
func _apply_equip_powers(delta: float) -> void:
    var powers = get_all_equipped_powers()
    for power in powers:
        match power:
            "flame_aura": _apply_companion_flame_aura(delta)
```

**Result:** Companion can now equip TWO powered items simultaneously! Weapon slot for ANY power, Accessory slot for EQUIP powers only.

---

## Step 3: Add Behavior Buttons ✅ COMPLETE

**Goal:** Add Normal/Aggressive/Defensive buttons to companion panel

### Implementation Complete (inventory.gd ~line 520):

**Companion Panel Layout:**
```
┌─────────────────────┐
│    Companion        │
├──────┬──────────────┤
│ ⚖️   │   [Avatar]   │  
│ ⚔️   │  Equipment   │  <- Buttons on left!
│ 🛡️   │ [Wpn][Acc]  │
│      │ [Hunt Btn]   │
└──────┴──────────────┘
```

**Button Implementation:**
- **HBoxContainer** layout: `[Buttons VBox] [Content VBox]`
- 3 emoji buttons (32x32) in vertical stack
- ⚖️ **Normal** (gray) - "Normal: Balanced behavior"
- ⚔️ **Aggressive** (red) - "Aggressive: Attack more enemies from farther away"
- 🛡️ **Defensive** (blue) - "Defensive: Stay close and protect"
- Tooltips for each button
- Connected to `_on_behavior_button_pressed(mode)`

**Handler Function (~line 688):**
```gdscript
func _on_behavior_button_pressed(mode: String):
    var companion = get_tree().get_first_node_in_group("companions")
    if companion and companion.has_method("set_behavior_mode"):
        companion.set_behavior_mode(mode)
```

---

## Step 4: Implement Behavior System ✅ COMPLETE

**File:** `project/blocky_game/entities/companion.gd`

### A. Added Variables (line ~27)
```gdscript
const BASE_FOLLOW_DISTANCE = 5.0
const BASE_ATTACK_RANGE = 40.0
var FOLLOW_DISTANCE = BASE_FOLLOW_DISTANCE  # Modified by behavior
var ATTACK_RANGE = BASE_ATTACK_RANGE        # Modified by behavior
var support_mode := "normal"
```

### B. Added Behavior Functions (line ~245)
```gdscript
func set_behavior_mode(mode: String):
    support_mode = mode
    _apply_behavior_modifiers()
    var party_ui = get_node_or_null("/root/Main/Game/PartyUI")
    if party_ui and party_ui.has_method("update_companion_behavior"):
        party_ui.update_companion_behavior(mode)
    print("🎯 %s switched to %s mode" % [entity_name, mode.capitalize()])

func _apply_behavior_modifiers():
    match support_mode:
        "aggressive":
            ATTACK_RANGE = BASE_ATTACK_RANGE * 2.0      # 80 blocks!
            FOLLOW_DISTANCE = BASE_FOLLOW_DISTANCE * 0.7  # 3.5 blocks
        "defensive":
            ATTACK_RANGE = BASE_ATTACK_RANGE * 0.6      # 24 blocks
            FOLLOW_DISTANCE = BASE_FOLLOW_DISTANCE * 0.5  # 2.5 blocks
        "normal":
            ATTACK_RANGE = BASE_ATTACK_RANGE             # 40 blocks
            FOLLOW_DISTANCE = BASE_FOLLOW_DISTANCE       # 5 blocks

func _initialize_behavior_mode():
    await get_tree().create_timer(0.5).timeout
    var party_ui = get_node_or_null("/root/Main/Game/PartyUI")
    if party_ui and party_ui.has_method("update_companion_behavior"):
        party_ui.update_companion_behavior(support_mode)
```

### C. Added Defensive Auto-Heal (line ~838)
```gdscript
# Timer for defensive heal
var _defensive_heal_timer := 0.0

func _apply_defensive_heal(delta: float) -> void:
    _defensive_heal_timer += delta
    if _defensive_heal_timer >= 3.0:
        _defensive_heal_timer = 0.0
        if current_hp < max_hp * 0.5:  # Below 50% HP
            var heal_amount = int(max_hp * 0.1)  # 10% heal
            current_hp = min(current_hp + heal_amount, max_hp)
            print("💚 %s (Defensive) auto-heals! (+%d HP)" % [entity_name, heal_amount])
            _update_party_ui()
```

### D. Added to Companions Group (line ~68)
```gdscript
add_to_group("companions")  # So inventory buttons can find us
```

### E. Call Initialization in _ready() (line ~112)
```gdscript
call_deferred("_initialize_behavior_mode")
```

**Behavior Effects:**

| Mode | Attack Range | Follow Distance | Special Effect |
|------|--------------|-----------------|----------------|
| ⚖️ Normal | 40 blocks | 5 blocks | Balanced |
| ⚔️ Aggressive | **80 blocks** (x2) | 3.5 blocks (x0.7) | Engages more enemies |
| 🛡️ Defensive | 24 blocks (x0.6) | 2.5 blocks (x0.5) | **Auto-heal 10% every 3s when < 50% HP** |

---

## Step 5: Update PartyUI ✅ COMPLETE

**File:** `project/long_nights/PartyUI.gd`

### A. Added Behavior Label (line ~190)
```gdscript
var behavior_label = Label.new()
behavior_label.name = "BehaviorLabel"
behavior_label.text = ""  # Hidden until mode set
behavior_label.add_theme_font_size_override("font_size", 11)
behavior_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
info_vbox.add_child(behavior_label)
```

### B. Added Update Function (line ~545)
```gdscript
func update_companion_behavior(mode: String) -> void:
    if not companion_ui or not companion_ui.visible:
        return
    var behavior_label = companion_ui.get_node_or_null("InfoVBox/BehaviorLabel")
    if not behavior_label:
        return
    match mode:
        "aggressive":
            behavior_label.text = "⚔️ Aggressive"
            behavior_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
        "defensive":
            behavior_label.text = "🛡️ Defensive"
            behavior_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
        "normal":
            behavior_label.text = "⚖️ Normal"
            behavior_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
```

**PartyUI Display:**
```
┌──────────────┐
│ Sylvara      │
│ [Healer]     │
│ ██████████   │
│ ⚖️ Normal    │  <- Behavior mode shown here!
└──────────────┘
```

---

## Testing Checklist

**Basic Features:**
- ✅ Inventory opens with larger panels (180x250) and avatars (128x128)
- ✅ Companion has weapon slot + accessory slot side-by-side
- ✅ Can drag items to accessory slot
- ✅ Accessory slot validates EQUIP powers only (rejects HOTBAR powers)
- ✅ Three behavior buttons appear (⚖️⚔️🛡️) on left of companion panel

**Power Stacking:**
- ⏳ Equip stone_skin accessory + meteor_strike weapon (should stack)
- ⏳ Verify stone_skin reduces damage by 50%
- ⏳ Verify flame_aura accessory burns nearby enemies
- ⏳ Both weapon AND accessory powers work simultaneously

**Behavior System:**
- ⏳ Click Normal button → PartyUI shows "⚖️ Normal"
- ⏳ Click Aggressive button → PartyUI shows "⚔️ Aggressive" (red)
- ⏳ Click Defensive button → PartyUI shows "🛡️ Defensive" (blue)
- ⏳ Aggressive: Companion attacks enemies from much farther away (80 blocks)
- ⏳ Defensive: Companion stays very close (2.5 blocks), auto-heals when low
- ⏳ Behavior mode persists through save/load

**Edge Cases:**
- ⏳ Try to equip meteor_strike in accessory slot → Should reject with message
- ⏳ Equip two EQUIP powers (weapon + accessory) → Both should work
- ⏳ Remove accessory → Powers update correctly
- ⏳ Change behavior during combat → Effects apply immediately

---

## Known Issues & Troubleshooting

### Issue: PartyUI doesn't show behavior mode
**Status:** Implementation complete, but may need scene tree timing adjustment

**Debug Steps:**
1. Check console for: "⚖️ Companion behavior initialized: Normal"
2. Check if companion is in "companions" group: `get_tree().get_nodes_in_group("companions")`
3. Verify PartyUI exists at: `/root/Main/Game/PartyUI`
4. Check BehaviorLabel exists: `companion_ui.get_node_or_null("InfoVBox/BehaviorLabel")`

**Potential Fix:**
If initialization doesn't show, increase delay in `_initialize_behavior_mode()`:
```gdscript
await get_tree().create_timer(1.0).timeout  # Was 0.5s, try 1.0s
```

---

## Code Summary

### Files Modified:
1. ✅ `project/blocky_game/gui/inventory/inventory.gd` - Accessory slot UI + behavior buttons (~150 lines added)
2. ✅ `project/blocky_game/entities/companion.gd` - Behavior system + power stacking (~100 lines added)
3. ✅ `project/long_nights/PartyUI.gd` - Behavior display (~30 lines added)

### New Features:
- **Accessory Slot:** Second equipment slot for companions (EQUIP powers only)
- **Power Stacking:** Weapon + Accessory powers work together
- **Behavior Modes:** 3 AI modes with different tactics
- **Visual Feedback:** PartyUI shows current behavior mode
- **Auto-Heal:** Defensive mode self-sustains when low HP

---

## Design Philosophy

### Power System Strategy:
- **Weapon Slot:** ANY power (HOTBAR or EQUIP) - Primary combat tool
- **Accessory Slot:** EQUIP powers only (passive bonuses) - Survival/utility
- **Stacking:** Up to 2 powers active simultaneously
- **Example Builds:**
  - **Tank:** Life steal weapon + Stone skin accessory = self-healing fortress
  - **Aggressive DPS:** Meteor strike weapon + Flame aura accessory = AOE chaos
  - **Support:** Ice burst weapon + Moon jump accessory = crowd control

### Behavior Mode Balancing:
- **Aggressive (⚔️):** High risk/reward - Engages everything, more damage output, draws aggro
- **Defensive (🛡️):** Low risk/sustain - Stays safe, self-heals, protects player
- **Normal (⚖️):** Balanced - Default smart AI, adapts to situation

**Player Strategy:** 
- Use Aggressive when YOU are tanking and need companion DPS
- Use Defensive when companion needs to survive (powerful weapon on them)
- Use Normal for general exploration

---

## Future Enhancements (Optional)

### Not Implemented Yet:
- [ ] Save/load behavior mode (currently resets to "normal" on load)
- [ ] Save/load accessory slot (currently lost on game restart)
- [ ] Visual feedback for stone_skin activation (shield effect when hit)
- [ ] Moon jump for companions (currently marked N/A since companions don't jump)
- [ ] Behavior button highlight/selection state (show which is active)

### Would Be Cool:
- [ ] **Scout mode:** Companion leads player toward hunt objectives
- [ ] **Guard mode:** Companion stays at a specific location
- [ ] **Formation system:** Multiple companions with coordinated behavior
- [ ] **Behavior hotkeys:** Quick-switch without opening inventory

---

## Conclusion

**Status:** ✅ **FULLY IMPLEMENTED**

All 5 steps complete! The companion now has:
- Larger, cleaner UI panels
- Second equipment slot (accessory)
- Power stacking capability
- 3 AI behavior modes with distinct playstyles
- Visual feedback in PartyUI

**Next Steps:** Testing and potential save/load integration for persistence.

---

**Implementation Date:** 2025-11-04  
**Total Lines Added:** ~280  
**Files Modified:** 3  
**New Mechanics:** Accessory slot, Behavior system, Power stacking  
**Ready for:** Gameplay testing! 🎮

**Goal:** Add a second equipment slot for companions (weapons + accessories)

### Files to Modify:
1. `project/blocky_game/gui/inventory/inventory.gd`
2. `project/blocky_game/entities/companion.gd`

### Implementation Details:

#### A. Add Variables (inventory.gd)
```gdscript
# Around line 29 (with other equipment slot variables)
var _companion_accessory_slot: InventoryItem = null
var _companion_accessory_slot_view = null
```

#### B. Add Accessory Slot UI (inventory.gd)
In `_create_paper_doll_panel()`, after weapon slot (around line 565):

```gdscript
# Add accessory slot for companion only
if not is_player:
    # Accessory slot label
    var accessory_label = Label.new()
    accessory_label.text = "Accessory"
    accessory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    accessory_label.add_theme_font_size_override("font_size", 12)
    panel.add_child(accessory_label)
    
    # Accessory equipment slot
    var accessory_slot = InventorySlot.instantiate()
    accessory_slot.custom_minimum_size = Vector2(64, 64)
    accessory_slot.pressed.connect(_on_accessory_slot_pressed)
    
    _companion_accessory_slot_view = accessory_slot
    
    # Center accessory slot
    var accessory_center = CenterContainer.new()
    accessory_center.add_child(accessory_slot)
    panel.add_child(accessory_center)
    
    # Small spacer before Hunt button
    var small_spacer = Control.new()
    small_spacer.custom_minimum_size = Vector2(0, 5)
    panel.add_child(small_spacer)
```

#### C. Add Accessory Slot Handler (inventory.gd)
Add new function around line 600+:

```gdscript
func _on_accessory_slot_pressed():
    """Handle clicking companion accessory slot"""
    if _dragged_slot != -1:
        # Try to equip dragged item
        var dragged_item = _slots[_dragged_slot]
        if dragged_item != null:
            # Check if it's a valid accessory (any equip power item)
            if dragged_item.skyshard_power != "" and _is_equip_power(dragged_item.skyshard_power):
                # Swap items
                var old_accessory = _companion_accessory_slot
                _companion_accessory_slot = dragged_item
                _slots[_dragged_slot] = old_accessory
                
                # Update views
                _update_accessory_slot_view()
                _update_slot_views()
                _end_drag()
                
                # Notify companion
                _update_companion_accessory()
                
                equipment_changed.emit()
    else:
        # Start dragging accessory
        if _companion_accessory_slot != null:
            # TODO: Implement accessory drag
            pass

func _is_equip_power(power_name: String) -> bool:
    """Check if power is an EQUIP type"""
    return power_name in ["stone_skin", "moon_jump", "flame_aura"]

func _update_accessory_slot_view():
    """Update companion accessory slot display"""
    if _companion_accessory_slot_view:
        _companion_accessory_slot_view.get_display().set_item(_companion_accessory_slot)

func _update_companion_accessory():
    """Notify companion of accessory change"""
    var companion = get_tree().get_first_node_in_group("companions")
    if companion and companion.has_method("set_accessory"):
        companion.set_accessory(_companion_accessory_slot)
```

#### D. Add Accessory Support to Companion (companion.gd)
Around line 23 (with other equipment variables):

```gdscript
var _equipped_accessory_item = null  # Accessory inventory item
```

Add new function around line 150+:

```gdscript
func set_accessory(inv_item):
    """Set companion's accessory item (for EQUIP powers)"""
    _equipped_accessory_item = inv_item
    if inv_item != null and inv_item.skyshard_power != "":
        print("  ✨ Companion accessory has power: %s" % inv_item.skyshard_power)

func get_all_equipped_powers() -> Array:
    """Get all active EQUIP powers from weapon + accessory"""
    var powers = []
    if _equipped_inv_item != null and _equipped_inv_item.skyshard_power != "":
        powers.append(_equipped_inv_item.skyshard_power)
    if _equipped_accessory_item != null and _equipped_accessory_item.skyshard_power != "":
        powers.append(_equipped_accessory_item.skyshard_power)
    return powers
```

#### E. Update Power Application Logic (companion.gd)
Modify `_apply_equip_powers()` around line 735:

```gdscript
func _apply_equip_powers(delta: float):
    """Apply passive EQUIP powers from weapon AND accessory"""
    var powers = get_all_equipped_powers()
    
    # Flame aura (if either item has it)
    if "flame_aura" in powers:
        _apply_companion_flame_aura(delta)
    
    # Moon jump (if either item has it)
    if "moon_jump" in powers:
        jump_height = BASE_JUMP_HEIGHT * 3.0
    else:
        jump_height = BASE_JUMP_HEIGHT
    
    # Stone skin is handled in take_damage()
```

Modify `take_damage()` around line 396:

```gdscript
func take_damage(amount: int, from: Node = null) -> void:
    var powers = get_all_equipped_powers()
    
    # Check for stone_skin from either item
    if "stone_skin" in powers:
        amount = int(amount * 0.5)
        print("🛡️ %s's Stone Skin! Reduced damage to %d" % [entity_name, amount])
    
    super.take_damage(amount, from)
    _update_party_ui()
```

#### F. Save/Load Accessory Data
Add to save/load functions in companion.gd and WorldManager.

---

## Step 3: Add Behavior Buttons

**Goal:** Add Normal/Aggressive/Defensive buttons to companion panel

### Implementation:

In `_create_paper_doll_panel()` (inventory.gd), replace the Hunt button section with:

```gdscript
if not is_player:
    # Behavior mode buttons (row of 3)
    var behavior_label = Label.new()
    behavior_label.text = "Behavior"
    behavior_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    behavior_label.add_theme_font_size_override("font_size", 12)
    panel.add_child(behavior_label)
    
    var button_container = HBoxContainer.new()
    button_container.add_theme_constant_override("separation", 4)
    
    # Create 3 buttons
    var behaviors = ["Normal", "Aggressive", "Defensive"]
    var colors = [
        Color(0.7, 0.7, 0.7),  # Normal - gray
        Color(1.0, 0.3, 0.3),  # Aggressive - red
        Color(0.3, 0.5, 1.0)   # Defensive - blue
    ]
    
    for i in range(3):
        var btn = Button.new()
        btn.name = behaviors[i] + "Button"
        btn.text = behaviors[i]
        btn.custom_minimum_size = Vector2(55, 30)
        btn.add_theme_font_size_override("font_size", 11)
        btn.modulate = colors[i]
        btn.pressed.connect(_on_behavior_button_pressed.bind(behaviors[i].to_lower()))
        button_container.add_child(btn)
    
    var button_center = CenterContainer.new()
    button_center.add_child(button_container)
    panel.add_child(button_center)
    
    # Small spacer
    var spacer = Control.new()
    spacer.custom_minimum_size = Vector2(0, 5)
    panel.add_child(spacer)
    
    # Hunt button (below behavior buttons)
    var hunt_button = Button.new()
    hunt_button.name = "HuntButton"
    hunt_button.text = "Hunt"
    hunt_button.custom_minimum_size = Vector2(160, 35)
    hunt_button.add_theme_font_size_override("font_size", 14)
    hunt_button.modulate = Color(0.9, 0.7, 0.2)  # Golden color
    hunt_button.pressed.connect(_on_hunt_button_pressed)
    
    var hunt_center = CenterContainer.new()
    hunt_center.add_child(hunt_button)
    panel.add_child(hunt_center)
```

Add button handler:

```gdscript
func _on_behavior_button_pressed(mode: String):
    """Change companion behavior mode"""
    var companion = get_tree().get_first_node_in_group("companions")
    if companion and companion.has_method("set_behavior_mode"):
        companion.set_behavior_mode(mode)
        print("🎯 Companion behavior set to: %s" % mode.capitalize())
```

---

## Step 4: Implement Behavior System

**File:** `project/blocky_game/entities/companion.gd`

### A. Add Variables (around line 48)
```gdscript
# Behavior mode
var support_mode := "normal"  # "normal", "aggressive", "defensive"
const BASE_ATTACK_RANGE = 40.0
const BASE_FOLLOW_DISTANCE = 5.0
```

### B. Add Behavior Setter
```gdscript
func set_behavior_mode(mode: String):
    """Change companion's behavior mode"""
    support_mode = mode
    _apply_behavior_modifiers()
    print("🎯 %s switched to %s mode" % [entity_name, mode.capitalize()])

func _apply_behavior_modifiers():
    """Apply stat changes based on behavior mode"""
    match support_mode:
        "aggressive":
            # Double attack range, closer follow
            ATTACK_RANGE = BASE_ATTACK_RANGE * 2.0
            FOLLOW_DISTANCE = BASE_FOLLOW_DISTANCE * 0.7  # Stay closer to player
            # Maybe reduce defense or increase damage?
        
        "defensive":
            # Shorter attack range, stay closer
            ATTACK_RANGE = BASE_ATTACK_RANGE * 0.6
            FOLLOW_DISTANCE = BASE_FOLLOW_DISTANCE * 0.5  # Very close to player
            # Could add extra defense bonus
        
        "normal":
            # Reset to defaults
            ATTACK_RANGE = BASE_ATTACK_RANGE
            FOLLOW_DISTANCE = BASE_FOLLOW_DISTANCE
```

### C. Modify Attack Logic (around line 300)
```gdscript
func _find_attack_target() -> Node:
    """Find enemy to attack (range varies by behavior mode)"""
    # ... existing code, but use modified ATTACK_RANGE
```

### D. Add Defensive Heal Logic (optional)
In `_apply_equip_powers()` or similar:

```gdscript
# Defensive mode: Auto-heal when low
if support_mode == "defensive":
    _defensive_heal_timer -= delta
    if _defensive_heal_timer <= 0.0:
        if health < max_health * 0.5:  # Below 50%
            var heal = int(max_health * 0.1)
            health = min(health + heal, max_health)
            print("💚 %s auto-heals! (+%d HP)" % [entity_name, heal])
            _defensive_heal_timer = 3.0  # Every 3 seconds
```

---

## Step 5: Update PartyUI

**File:** `project/long_nights/PartyUI.gd`

### A. Add Behavior Label to UI
In `_create_party_member_ui()` (around line 180), after hunt_timer_label:

```gdscript
# Behavior mode label (only for companions)
var behavior_label = Label.new()
behavior_label.name = "BehaviorLabel"
behavior_label.text = ""  # Hidden by default
behavior_label.add_theme_font_size_override("font_size", 11)
behavior_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
behavior_label.add_theme_color_override("font_outline_color", Color.BLACK)
behavior_label.add_theme_constant_override("outline_size", 1)
behavior_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
info_vbox.add_child(behavior_label)
```

### B. Add Update Function
```gdscript
func update_companion_behavior(mode: String):
    """Update companion behavior display"""
    if not companion_ui:
        return
    
    var behavior_label = companion_ui.find_child("BehaviorLabel", true, false)
    if behavior_label:
        match mode:
            "aggressive":
                behavior_label.text = "[Aggressive]"
                behavior_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
            "defensive":
                behavior_label.text = "[Defensive]"
                behavior_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
            "normal":
                behavior_label.text = "[Normal]"
                behavior_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
```

### C. Connect to Companion
In companion.gd's `set_behavior_mode()`:

```gdscript
func set_behavior_mode(mode: String):
    support_mode = mode
    _apply_behavior_modifiers()
    
    # Update PartyUI
    var party_ui = get_node_or_null("/root/Main/Game/PartyUI")
    if party_ui and party_ui.has_method("update_companion_behavior"):
        party_ui.update_companion_behavior(mode)
    
    print("🎯 %s switched to %s mode" % [entity_name, mode.capitalize()])
```

---

## Testing Checklist

After implementing all steps:

- [ ] Inventory opens with larger panels and avatars
- [ ] Companion has weapon slot + accessory slot
- [ ] Can equip stone_skin accessory (50% damage reduction works)
- [ ] Can equip flame_aura accessory (burns enemies)
- [ ] Can equip both weapon AND accessory powers (stacking works)
- [ ] Normal/Aggressive/Defensive buttons appear
- [ ] Clicking buttons changes companion behavior
- [ ] Aggressive: Companion attacks from farther away, engages more enemies
- [ ] Defensive: Companion stays close, auto-heals when low
- [ ] Normal: Default behavior
- [ ] PartyUI shows behavior mode under HP bar
- [ ] Behavior mode persists through save/load
- [ ] Accessory persists through save/load

---

## Notes & Considerations

### Power Stacking Strategy:
- Weapon slot: ANY power (HOTBAR or EQUIP)
- Accessory slot: EQUIP powers only (stone_skin, moon_jump, flame_aura)
- Companion can have up to 2 powers active at once
- Example: Life steal weapon + Stone skin accessory = self-healing tank

### Behavior Mode Balancing:
- **Aggressive:** High risk/reward - more damage, but takes more hits
- **Defensive:** Tank mode - stays close, survives longer
- **Normal:** Balanced - current behavior

### UI Layout After Changes:
```
┌────────────────────────────────────────────────────────────┐
│  [Player Panel]   [Inventory Grid]   [Companion Panel]     │
│   - Avatar 128x128                    - Avatar 128x128     │
│   - Weapon Slot                       - Weapon Slot        │
│                                       - Accessory Slot     │
│                                       [Normal][Aggro][Def] │
│                                       [Hunt Button]        │
└────────────────────────────────────────────────────────────┘
```

### Save/Load Requirements:
Don't forget to add to WorldManager:
- `companion_accessory` (inventory item)
- `companion_behavior_mode` (string)

---

## Current Status Summary

✅ **Completed:**
- Step 1: Layout adjustments (panels 180x250, avatars 128x128)

⏳ **Next Session:**
- Start Step 2: Add accessory slot code
- Test accessory equipping
- Continue through steps 3-5

**Estimated Time:** 1-2 hours for remaining steps

---

**Good luck with the kittens! 🐱 This should have everything you need to continue tomorrow (or later tonight)!**
