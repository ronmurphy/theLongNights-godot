# Throw Power - Design Document

## Overview
An EQUIP slot skyshard power that allows throwing melee weapons (sword, machete, etc.) to deal increased damage to entities.

## Power Type
- **Slot**: EQUIP (accessory slot)
- **Name**: "Throw"
- **Description**: "Throw melee weapons to deal 2x damage + stack bonus to entities"

## Mechanics

### Activation
- Player has Throw power equipped in accessory slot
- Player holds a melee weapon (sword, machete, etc.) in hotbar
- Right-click on entity or in entity's direction
- Weapon is thrown with parabolic arc

### Damage Calculation
```
throw_damage = (weapon_base_damage * 2) + stack_count
```

Example:
- Sword with 15 base damage, stack of 5
- Throw damage = (15 * 2) + 5 = 35 damage
- vs normal melee = 15 + 5 = 20 damage

### Weapon Retrieval - Two Options

#### Option A: Billboard Pickup (Simpler)
- When weapon lands, spawn a ground pickup item
- Uses 2D sprite billboard (same as item icon)
- Player walks over to auto-pickup
- Reuses existing item drop/pickup system (chest loot, enemy drops)
- **Pros**: Simple, reuses existing code
- **Cons**: Player must walk to weapon

#### Option B: Return Power Integration
- Thrown weapon becomes retrievable projectile
- If player also has Return power equipped, can retrieve remotely
- Otherwise behaves like Option A
- **Pros**: Synergy with Return power, more magical feel
- **Cons**: Requires both powers, more complex

## Implementation Notes

### Existing Code to Reuse
1. **Projectile System**: `spear_projectile.gd` as template
2. **Parabolic Arc**: Torch and spear throwing logic
3. **Entity Targeting**: Spear melee `_find_target_entity()`
4. **Damage with Stack Bonus**: Spear already implements this
5. **Retrieval System**: Return power infrastructure (if using Option B)

### New Code Needed
1. Right-click handler for melee weapons (similar to spear throw)
2. Generic weapon projectile script (or extend spear_projectile)
3. 2x damage modifier when thrown
4. Billboard sprite for dropped weapons (if using Option A)
5. Item pickup collision/trigger (if using Option A)

### Eligible Weapons
Initially support melee weapons:
- Sword (ID: varies)
- Machete (ID: varies)
- Stone Hammer (ID: varies)
- Any weapon with melee attack but not normally throwable

**NOT eligible:**
- Spear (already throwable)
- Rocket Launcher (already ranged)
- Torches (not weapons)

## User Experience

### With Throw Power Only
1. Equip claws with Throw power in accessory slot
2. Select sword from hotbar
3. Right-click on enemy
4. Sword flies through air, hits for 2x damage
5. Sword drops as pickup on ground
6. Walk over to retrieve sword

### With Throw + Return Power
1. Equip item with Throw in accessory
2. Equip item with Return in other accessory slot (or same item with both powers?)
3. Throw weapon at enemy (2x damage)
4. Switch to empty hotbar slot
5. Right-click near landed weapon to retrieve it remotely
6. Back in inventory, ready to throw again

## Design Questions to Resolve Later

1. **Can one item have both Throw AND Return powers?**
   - Would create ultimate throwing weapon synergy
   - Might be too powerful?

2. **Should thrown weapons stick into entities or bounce off?**
   - Stick: More dramatic, but might look weird
   - Bounce: More realistic, land on ground

3. **Cooldown needed?**
   - Prevent spam throwing?
   - Or let stack depletion be the limiting factor?

4. **Does weapon consume durability/count when thrown?**
   - Currently stacks don't break down
   - Throwing could be "free" if you retrieve

5. **Should ALL damage be from throw, or keep melee option?**
   - Probably keep both: right-click throw, left-click melee
   - Gives tactical choice

## Priority
- **Status**: Deferred
- **Reason**: After extensive Return power implementation, team needs break from power debugging
- **Next Steps**: Focus on Undervoid terrain generation first
- **Revisit**: When ready for new power implementation

## Related Files
- `blocky_game/items/spear/spear.gd` - Hybrid melee/throw example
- `blocky_game/projectiles/spear_projectile.gd` - Projectile template
- `blocky_game/player/avatar_interaction.gd` - Power checking, retrieval
- `blocky_game/gui/inventory/inventory.gd` - Power definitions

## Notes
- Throw + Return combo would create a "boomerang weapon" playstyle
- Could add special VFX for thrown weapons (spinning trail, impact flash)
- Billboard sprites already exist in item_db, just need to spawn them as 3D billboards
