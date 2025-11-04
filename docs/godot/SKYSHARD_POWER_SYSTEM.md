# Skyshard Enhancement Power System

## Overview

The Skyshard Power System allows players to enhance weapons and tools with permanent powers by infusing skyshards (rare drops from blood moon sky ruin kills). Each weapon can have ONE power, and players can use TWO powers simultaneously via the dual-slot system.

## Key Concepts

### Dual Power System
- **HOTBAR Slot** = Active powers that trigger when using the weapon (combat)
- **EQUIPMENT Slot** = Passive powers that are always active while equipped (buffs)
- Players can benefit from BOTH slots at once!

**Example Build:**
- Hotbar: Life Steal Sword → heals on every attack
- Equipment: Stone Skin Machete → +50% defense passively

### Enhancement Process
1. Player kills enemies in sky ruins (Y > 3000) during blood moon
2. Enemies drop skyshards (100% drop rate)
3. Player drags skyshards onto weapon/tool in inventory
4. System consumes up to 5 skyshards automatically
5. At 5 skyshards, modal appears with power selection
6. Player chooses ONE power (permanent, cannot change)
7. Weapon is now enhanced forever

## Data Structures

### InventoryItem (`inventory_item.gd`)
```gdscript
var skyshard_count := 0      # Number of skyshards infused (shows in UI)
var skyshard_power := ""     # Chosen power name (empty = not chosen yet)
```

Both fields are saved/loaded with inventory data.

### Power Definitions (`inventory.gd` line 1004-1015)
```gdscript
var powers = [
    {"name": "life_steal", "display": "Life Steal", "desc": "Heals 25% of damage dealt", "slot": "HOTBAR"},
    {"name": "stone_skin", "display": "Stone Skin", "desc": "+50% defense while equipped", "slot": "EQUIP"},
    # ... etc
]
```

## UI Components

### Visual Indicators
1. **Light Blue Counter** - Bottom-left of inventory slot, shows skyshard count (5 when maxed)
2. **Tooltip Enhancement** - Weapon tooltip shows `✨ Power: [Power Name]`
3. **Power Selection Modal** - Beautiful scrollable list with [Hotbar] ⚔️ or [Equip] 🛡️ icons

### Implementation Files
- `inventory_item_display.gd` - Renders skyshard counter and tooltip
- `inventory.gd` - Drag-drop logic, power modal, save/load

## Power Categories

### Active Powers (HOTBAR)
Trigger when weapon is used in combat. Check `inv_item_or_count.skyshard_power` in weapon's attack function.

| Power | Description | Status |
|-------|-------------|--------|
| life_steal | Heals 25% of damage dealt | ✅ Implemented |
| meteor_strike | Summons meteor on hit | ✅ Implemented |
| wind_dash | Speed boost for 3s after hit | ✅ Implemented |
| lightning_chain | Damage jumps to nearby enemies | ✅ Implemented |
| ice_burst | Freezes enemies in radius | ⏳ Pending |
| poison_cloud | Leaves poison AoE on impact | ⏳ Pending |
| knife_volley | Launches 3 knives on attack | ⏳ Pending |

### Passive Powers (EQUIP)
Always active while weapon is in equipment slot. Check equipped weapon in relevant system.

| Power | Description | Status |
|-------|-------------|--------|
| stone_skin | +50% defense | ✅ Implemented |
| moon_jump | Triple jump height | ✅ Implemented |
| flame_aura | Burns nearby enemies constantly | ✅ Implemented |

## Adding New Active Powers (HOTBAR)

### Step 1: Add Power to Modal List
Edit `inventory.gd` around line 1005:
```gdscript
{"name": "meteor_strike", "display": "Meteor Strike", "desc": "Summons meteor on hit", "slot": "HOTBAR"},
```

### Step 2: Implement in Weapon Scripts
For each weapon that should support this power (sword, machete, etc.):

**Pattern for Single-Target Weapons** (sword, machete):
```gdscript
func _slash_attack(entity: Node, attacker_pos: Vector3, inv_item_or_count):
    var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count

    # Deal damage
    var total_damage = DAMAGE + stack_count
    entity.take_damage(total_damage, self)

    # ⚡ SKYSHARD POWER: [Power Name]
    if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.skyshard_power == "power_name":
        # Implement power effect here
        print("⚡ Power triggered!")
```

**Pattern for AOE Weapons** (stone_hammer):
```gdscript
func _damage_nearby_entities(center: Vector3, radius: float, damage: int, knockback: float, inv_item_or_count = null):
    var total_effect = 0  # Accumulate effect across all hits

    for entity in entities:
        # ... damage logic ...

        # ⚡ SKYSHARD POWER: Check per enemy
        if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.skyshard_power == "power_name":
            total_effect += calculate_effect()

    # Apply total effect after loop
    if total_effect > 0:
        apply_power_effect(total_effect)
```

**Pattern for Cleave Weapons** (tree_feller):
```gdscript
func _cleave_attack(entity: Node, attacker_pos: Vector3, inv_item_or_count):
    # ... damage logic ...

    # ⚡ SKYSHARD POWER: Triggers PER enemy cleaved
    if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.skyshard_power == "power_name":
        apply_power_to_this_enemy()
```

### Step 3: Update Weapon Signatures
Ensure weapon supports inventory item parameter:

```gdscript
# In weapon.gd
func use(trans: Transform3D, inv_item_or_count = 1):
    var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count
    # ... pass inv_item_or_count to _use()

func _use(trans: Transform3D, inv_item_or_count):
    var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count
    # ... pass inv_item_or_count to attack function
```

### Weapons Supporting Active Powers
- ✅ Sword (`sword.gd`)
- ✅ Machete (`machete.gd`)
- ✅ Stone Hammer (`stone_hammer.gd`)
- ✅ Tree Feller (`tree_feller.gd`)
- ⏳ Ice Bow (`ice_bow.gd`) - needs implementation
- ⏳ Crossbow (`crossbow.gd`) - needs implementation
- ⏳ Fire Staff (`fire_staff.gd`) - needs implementation
- ⏳ Throwing Knives (`throwing_knives.gd`) - needs implementation
- ⏳ Rocket Launcher (`rocket_launcher.gd`) - needs implementation

## Adding New Passive Powers (EQUIP)

### Step 1: Add Power to Modal List
Same as active powers, but use `"slot": "EQUIP"`.

### Step 2: Implement in Relevant System
Passive powers check the equipped weapon from equipment slot.

**Pattern for Combat Stats** (like Stone Skin):
```gdscript
# In character_controller.gd or entity_base.gd
func take_damage(amount: int, from: Node = null) -> void:
    # Get equipped weapon
    var equipped_weapon = _get_equipped_weapon()

    # Check for passive power
    if equipped_weapon and equipped_weapon.skyshard_power == "stone_skin":
        # Apply buff
        var boosted_defense = int(defense * 1.5)
        print("🛡️ Stone Skin active! Defense: %d → %d" % [defense, boosted_defense])
```

**Pattern for Movement/Physics** (like Moon Jump):
```gdscript
# In character_controller.gd
func _physics_process(delta: float):
    # Get equipped weapon
    var equipped_weapon = _get_equipped_weapon()

    # Check for moon jump power
    var jump_multiplier = 1.0
    if equipped_weapon and equipped_weapon.skyshard_power == "moon_jump":
        jump_multiplier = 3.0
        print("🌙 Moon Jump active!")

    if _grounded and Input.is_key_pressed(KEY_SPACE):
        _velocity.y = jump_force * jump_multiplier
```

**Helper Function** (add to character_controller.gd if not present):
```gdscript
func _get_equipped_weapon():
    """Get the player's equipped weapon item data"""
    var inventory = get_node_or_null("Inventory")
    if not inventory:
        return null

    if inventory.has_method("get_player_equipped_weapon"):
        return inventory.get_player_equipped_weapon()

    return null
```

## Implementation Examples

### Life Steal (Active - HOTBAR)
**Location:** All melee weapons (`sword.gd`, `machete.gd`, etc.)
```gdscript
# In _slash_attack or _cleave_attack function
if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.skyshard_power == "life_steal":
    var heal_amount = int(total_damage * 0.25)  # 25% of damage dealt
    var player = get_tree().get_first_node_in_group("player")
    if player and player.has_method("heal"):
        player.heal(heal_amount)
        print("💚 Life Steal! Healed %d HP" % heal_amount)
```

### Stone Skin (Passive - EQUIP)
**Location:** `character_controller.gd:332-336`
```gdscript
# In take_damage function
var equipped_weapon = _get_equipped_weapon()
if equipped_weapon and equipped_weapon.skyshard_power == "stone_skin":
    effective_defense = int(defense * 1.5)  # +50% defense
    print("🛡️ Stone Skin active! Defense boosted: %d → %d" % [defense, effective_defense])
```

### Meteor Strike (Active - HOTBAR)
**Location:** All melee weapons (sword, machete, stone_hammer, tree_feller)
```gdscript
# In _slash_attack or _cleave_attack function
if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.skyshard_power == "meteor_strike":
    var target_pos = entity.global_position
    var sky_pos = Vector3(target_pos.x, target_pos.y + 50.0, target_pos.z)
    _spawn_meteor(sky_pos, target_pos, stack_count)
    print("☄️ Meteor Strike! Calling down meteor on %s" % entity.entity_name)

func _spawn_meteor(sky_pos: Vector3, target_pos: Vector3, stack_count: int):
    var meteor = Node3D.new()
    meteor.set_script(Meteor)
    var game_node = get_node("/root/Main/Game")
    game_node.add_child(meteor)
    meteor.initialize(sky_pos, target_pos, stack_count)
```

### Moon Jump (Passive - EQUIP)
**Location:** `character_controller.gd:159-168`
```gdscript
# In _physics_process, when handling jump input
if _grounded and Input.is_key_pressed(KEY_SPACE):
    var jump_multiplier = 1.0
    var equipped_weapon = _get_equipped_weapon()
    if equipped_weapon and equipped_weapon.skyshard_power == "moon_jump":
        jump_multiplier = 3.0
        print("🌙 Moon Jump active! Tripled jump height!")

    _velocity.y = jump_force * jump_multiplier
    _grounded = false
```

### Wind Dash (Active - HOTBAR)
**Location:** All melee weapons + `character_controller.gd:386-391`
```gdscript
# In weapon attack function
if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.skyshard_power == "wind_dash":
    var player = get_tree().get_first_node_in_group("player")
    if player and player.has_method("activate_wind_dash"):
        player.activate_wind_dash()

# In character_controller.gd
func activate_wind_dash() -> void:
    _wind_dash_active = true
    _wind_dash_time = 3.0
    print("💨 Wind Dash activated! Speed doubled for 3 seconds!")

# Speed multiplier applied during movement calculation (line 160-162)
var effective_speed = speed
if _wind_dash_active:
    effective_speed *= 2.0  # Double speed during Wind Dash
motor = motor.normalized() * effective_speed
```

### Lightning Chain (Active - HOTBAR)
**Location:** All melee weapons
```gdscript
# In weapon attack function
if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.skyshard_power == "lightning_chain":
    _lightning_chain(entity.global_position, int(total_damage * 0.5), entity)

func _lightning_chain(origin: Vector3, chain_damage: int, primary_target: Node):
    const CHAIN_RADIUS = 5.0
    const MAX_CHAINS = 3

    var entities = get_tree().get_nodes_in_group("entities")
    var chained = 0

    for entity in entities:
        if chained >= MAX_CHAINS:
            break

        if not entity.is_alive or entity.team != EntityBase.Team.ENEMY or entity == primary_target:
            continue

        var distance = entity.global_position.distance_to(origin)
        if distance <= CHAIN_RADIUS:
            entity.take_damage(chain_damage, self)
            chained += 1
            print("⚡ Lightning chained to %s for %d damage!" % [entity.entity_name, chain_damage])

    if chained > 0:
        print("⚡ Lightning Chain! Hit %d additional enemies" % chained)
```

### Flame Aura (Passive - EQUIP)
**Location:** `character_controller.gd:126-132, 403-424`
```gdscript
# In _physics_process, check every 1 second
_flame_aura_timer += delta
if _flame_aura_timer >= 1.0:
    _flame_aura_timer = 0.0
    var equipped_weapon = _get_equipped_weapon()
    if equipped_weapon and equipped_weapon.skyshard_power == "flame_aura":
        _apply_flame_aura()

func _apply_flame_aura() -> void:
    const FLAME_RADIUS = 4.0
    const FLAME_DAMAGE = 5

    var entities = get_tree().get_nodes_in_group("entities")
    var burned_count = 0

    for entity in entities:
        if not entity.is_alive or entity.team != EntityBase.Team.ENEMY:
            continue

        var distance = entity.global_position.distance_to(global_position)
        if distance <= FLAME_RADIUS:
            entity.take_damage(FLAME_DAMAGE, self)
            burned_count += 1

    if burned_count > 0:
        print("🔥 Flame Aura! Burned %d nearby enemies for %d damage each" % [burned_count, FLAME_DAMAGE])
```

## Combat Priority Fix

**Important:** Melee weapons check for entities BEFORE attempting to mine blocks.

**Location:** `avatar_interaction.gd:184-207`
```gdscript
# Check if aiming at an entity (prioritize combat over mining)
var target_entity = _find_nearest_entity_in_crosshair()
var aiming_at_entity = target_entity != null

# Only mine if NOT aiming at entity
if mining_power > 0 and hit != null and _action_use_held and not aiming_at_entity:
    # Mine block
elif _action_use:
    # OR if aiming at entity (prioritize combat!)
    if mining_power == 0 or hit == null or not _action_use_held or aiming_at_entity:
        item.use(_head.global_transform, inv_item)
```

## Save/Load System

Powers persist automatically via inventory serialization:

**Serialize** (`inventory.gd:1064-1070`):
```gdscript
data["slots"].append({
    "type": item.type,
    "id": item.id,
    "count": item.count,
    "skyshard_count": item.skyshard_count,
    "skyshard_power": item.skyshard_power
})
```

**Deserialize** (`inventory.gd:1112-1114`):
```gdscript
item.skyshard_count = slot_data.get("skyshard_count", 0)
item.skyshard_power = slot_data.get("skyshard_power", "")
```

## Testing Checklist

### For Active Powers (HOTBAR)
- [ ] Power appears in modal with `[Hotbar] ⚔️` tag
- [ ] Power is selectable at 5 skyshards
- [ ] Weapon shows power in tooltip after selection
- [ ] Light blue "5" appears in inventory slot
- [ ] Power triggers when attacking enemies
- [ ] Console shows power activation message
- [ ] Power effect works as described
- [ ] Works with weapon stacking bonus
- [ ] Prevents adding more skyshards after selection

### For Passive Powers (EQUIP)
- [ ] Power appears in modal with `[Equip] 🛡️` tag
- [ ] Power is selectable at 5 skyshards
- [ ] Weapon shows power in tooltip after selection
- [ ] Light blue "5" appears in inventory slot
- [ ] Power activates when weapon in equipment slot
- [ ] Console shows power activation message
- [ ] Power effect works as described
- [ ] No effect when weapon in hotbar/inventory

### General
- [ ] Power choice is permanent (cannot change)
- [ ] Attempting to add more skyshards shows warning
- [ ] Power persists after save/load
- [ ] Works with multiplayer (RPC compatibility)

## Common Pitfalls

1. **Forgetting `typeof()` check** - Always check if parameter is object before accessing properties
2. **Wrong slot type** - Make sure active powers check hotbar weapon, passive check equipment
3. **Not passing `inv_item_or_count`** - Every attack function needs this parameter
4. **Signature mismatch** - Base class `item.gd` must match child weapon signatures
5. **Missing save/load** - Powers won't persist if not in serialize/deserialize

## Future Enhancements

- [ ] Add visual effects for each power (particles, shaders)
- [ ] Add sound effects for power activation
- [ ] Implement companion weapon skyshard support
- [ ] Add power cooldowns for balance
- [ ] Create power tier system (unlock stronger versions at 10, 15 skyshards)
- [ ] Add power combinations (2+ powers = special effect)

## Related Files

### Core System
- `project/blocky_game/player/inventory_item.gd` - Data structure
- `project/blocky_game/gui/inventory/inventory.gd` - Drag-drop, modal, save/load
- `project/blocky_game/gui/inventory_item_display.gd` - UI rendering

### Combat
- `project/blocky_game/player/avatar_interaction.gd` - Weapon usage, combat priority
- `project/blocky_game/player/character_controller.gd` - Player stats, passive powers

### Weapons (Active Powers)
- `project/blocky_game/items/sword/sword.gd`
- `project/blocky_game/items/machete/machete.gd`
- `project/blocky_game/items/stone_hammer/stone_hammer.gd`
- `project/blocky_game/items/tree_feller/tree_feller.gd`
- (Plus 5 more projectile weapons to implement)

### Items
- `project/blocky_game/items/item_db.gd` - Item registry (skyshard ID: 21)
- `project/blocky_game/items/skyshard/skyshard.gd` - Skyshard item definition
