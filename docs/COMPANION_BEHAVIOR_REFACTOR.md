# Companion Behavior & Inventory Refactor

**Status:** Step 1 of 5 complete ✅  
**Started:** 2025-11-04  
**Goal:** Add companion behavior modes (Normal/Aggressive/Defensive) and accessory slot

---

## Overall Plan (5 Steps)

1. ✅ **Adjust layout/sizing** - Make room for new features
2. ⏳ **Add accessory slot** - Second equip slot for companion
3. ⏳ **Add behavior buttons** - UI for Normal/Aggressive/Defensive modes
4. ⏳ **Implement behavior system** - Logic in companion.gd
5. ⏳ **Update PartyUI** - Show behavior mode under HP bar

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

## Step 2: Add Accessory Slot (NEXT STEP)

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
