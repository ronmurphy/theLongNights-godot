# Retrieval System Documentation

## Overview

The Retrieval system allows players and companions to recover thrown projectiles (spears, torches, light orbs) from the environment using the "Return" power. This is a quality-of-life feature that makes throwable items more practical for survival gameplay.

## System Architecture

### Core Concepts

1. **Retrievable Projectiles**: Spears, torches, and light orbs that can stick into blocks or hit entities
2. **Return Power**: A skyshard power that enables retrieval of stuck projectiles
3. **Accessory Slot**: Player and companion equipment slot that holds the Return power
4. **Raycast Detection**: Line-of-sight based retrieval targeting system

### Retrieval Flow

```
1. Player throws projectile (spear/torch/light_orb)
   ↓
2. Projectile hits entity or sticks in block
   ↓
3. If hit entity AND Return power active:
   - Projectile marked for retrieval
   - Wait 2-3 seconds (entity hit recovery time)
   - Trigger Return power effect
   ↓
4. Player looks at stuck projectile and right-clicks
   ↓
5. System checks:
   - Is accessory slot equipped?
   - Does it have Return power?
   ↓
6. If yes:
   - Raycast finds stuck projectile
   - Projectile retrieved to inventory
   - Particle burst + teleport effect
   - Projectile removed from scene
   ↓
7. If no:
   - Right-click does nothing / shows message
```

## Implementation Details

### 1. Return Power Definition

**Location**: `/long_nights/Powers.gd` (lines 20-36)

**Type**: HOTBAR power (active, triggered on event)

**Trigger**:
- Only on entity hits (not block hits)
- Automatically retrieves after 2-3 second delay
- Player doesn't need to do anything for entity hits

**Manual Retrieval**:
- Player right-clicks on stuck projectile in blocks
- System checks for Return power in accessory slot
- If present, retrieves to inventory

### 2. Projectile Modifications

**Files Modified**:
- `/blocky_game/projectiles/spear_projectile.gd`
- `/blocky_game/projectiles/thrown_torch.gd` (future)
- `/blocky_game/projectiles/light_orb.gd` (future)

**New Fields**:
```gdscript
var _can_be_retrieved := false  # Flag set after hitting entity with Return power
var _retrieval_cooldown := 0.0   # Prevents instant re-retrieval
```

**New Methods**:
```gdscript
func mark_for_retrieval() -> void:
    """Mark this projectile as retrievable after entity hit"""
    _can_be_retrieved = true
    # Extend lifetime if needed for retrieval window
```

### 3. Power Execution

**Location**: `/long_nights/Powers.gd`

**Function**:
```gdscript
func _power_return(ctx: Dictionary) -> void:
    # Called when projectile hits entity with Return power
    # ctx contains: entity, position, attacker, damage_dealt, stack_count

    # Mark projectile for retrieval (automatic return after delay)
    # Or trigger immediate retrieval if called from inventory
```

**Context Available**:
```gdscript
{
    "entity": Node,           # Hit entity
    "position": Vector3,      # Impact position
    "stack_count": int,       # Skyshard count (0-5)
    "damage_dealt": int,      # Total damage
    "attacker": Node          # Player or Companion
}
```

### 4. Retrieval Detection & Recovery

**Location**: `/blocky_game/player/avatar_interaction.gd`

**New Functions**:

#### `_find_retrievable_projectiles()` -> Array
- Raycasts from player position in look direction
- Finds stuck projectiles within line of sight
- Filters for retrievable projectiles only
- Returns array of found projectiles (closest first)

#### `_can_retrieve_projectiles()` -> bool
- Checks player's accessory slot for Return power
- Returns true if Return power is equipped

#### `_retrieve_projectile(projectile: Node, item_id: int)` -> void
- Removes projectile from scene
- Adds item to inventory
- Priority: empty hotbar slot > same power stack > same type > bag
- Triggers particle effect and sound

#### `_try_retrieve_projectile()` -> void
- Called when right-click is pressed (if aiming at stuck projectile)
- Checks for Return power in accessory slot
- Attempts retrieval if conditions met

### 5. Inventory Recovery Priority

When retrieving a projectile:

1. **First**: Look for empty hotbar slot (first available)
2. **Second**: Look for same item with same power in hotbar
3. **Third**: Look for same item (any power) in hotbar
4. **Fourth**: Look for empty slot in bag
5. **Fifth**: Look for same item in bag
6. **Fallback**: Inventory full message

### 6. Companion Support

**Implementation**:
- Companion checks their accessory slot for Return power
- Uses same retrieval logic as player
- Can retrieve items thrown by themselves or allies

**Location**: `/blocky_game/entities/companion.gd`
- Add check in combat/action methods
- Call same retrieval functions as player

## User Experience

### Player Perspective

**Entity Hits** (Automatic):
```
Throw spear at enemy → Hits! → Damage dealt + Return power triggers →
2 seconds later → Spear teleports back to hotbar with particle effect
```

**Block Hits** (Manual):
```
Throw spear at wall → Sticks in block → Look at spear → Right-click →
Check: Do I have Return power equipped? → YES → Spear returns to hotbar
```

### Companion Perspective

- Companion throws projectile with Return power equipped
- If hits entity: automatic retrieval after delay
- If hits block: companion can't retrieve (no right-click)
- **Future**: Could add AI logic to retrieve from blocks

## Technical Specifications

### Retrieval Range

- **Line of sight based** (raycast)
- **Unlimited practical range** (but respects LOS)
- **Detection radius**: 0.5 blocks (same as block detection)

### Retrieval Timing

- **Entity hits**: 2-3 second delay before retrieval
- **Block hits**: Manual right-click (instant on success)
- **Retrieval cooldown**: Prevents spam (1 second minimum)

### Visual Effects

- **Particle burst**: 20-30 particles, white/cyan color
- **Light flash**: Bright white light, 0.5 second duration
- **Sound**: Teleport/recall sound effect (if available)
- **Animation**: Projectile scales down or fades during retrieval

### Item Identification

Projectiles identified by script path:
- Spear: `"spear_projectile"` in script resource path
- Torch: `"thrown_torch"` in script resource path
- Light Orb: `"light_orb"` or `"flying_orb"` in script resource path

## Integration Points

### With Powers System
- Return power registered in Powers.gd
- Added to power selection modal in inventory.gd
- Context passed includes projectile reference

### With Inventory System
- Uses existing `_recover_projectiles_to_inventory()` function
- Respects item stacking rules
- Handles power conflicts when merging stacks

### With Projectile System
- Projectiles implement `mark_for_retrieval()` method
- Projectiles track `_can_be_retrieved` flag
- Projectiles stored in `/root/Main/Game` node tree

### With Avatar Interaction
- Right-click detection in `_physics_process()`
- Raycast from player head position
- Checks accessory slot for power

## Configuration

### Item ID Mappings
```gdscript
SPEAR_ITEM_ID = 41
TORCH_ITEM_ID = 6
LIGHT_ORB_ITEM_ID = 40
```

### Timing Constants
```gdscript
ENTITY_HIT_RETRIEVAL_DELAY = 2.5  # Seconds before auto-retrieval
RETRIEVAL_RAYCAST_DISTANCE = 100  # Blocks
RETRIEVAL_DETECTION_RADIUS = 0.5  # Blocks
```

### Visual Effects
```gdscript
PARTICLE_COUNT = 25
PARTICLE_LIFETIME = 0.5  # Seconds
LIGHT_FLASH_DURATION = 0.3  # Seconds
LIGHT_BRIGHTNESS = 2.0  # Intensity
```

## Future Enhancements

1. **Companion AI Retrieval**: Companions can retrieve from blocks if near item
2. **Tether Effect**: Projectile trails back visually instead of instant teleport
3. **Multiple Retrievals**: Chain retrieve multiple projectiles in sequence
4. **Retrieval Cooldown Visual**: Show timer on crosshair
5. **Sound Effects**: Custom retrieval/recall sounds
6. **Particles**: Different effects for each projectile type
7. **Animation Chains**: Projectile rotation/flip during retrieval

## Testing Checklist

- [ ] Return power appears in power selection modal
- [ ] Power can be applied to equipped accessory slot
- [ ] Spear retrieved after entity hit (automatic)
- [ ] Spear retrieved from block with right-click (manual)
- [ ] Torch retrieved with right-click
- [ ] Light orb retrieved with right-click
- [ ] Inventory priority logic works correctly
- [ ] Particle effects display on retrieval
- [ ] Companion can retrieve with Return power equipped
- [ ] Inventory full prevents retrieval
- [ ] Power conflicts handled correctly when stacking

## Files Modified/Created

### New Files
- `/docs/godot/retrieval.md` (this file)

### Modified Files
- `/long_nights/Powers.gd` - Add Return power function
- `/blocky_game/projectiles/spear_projectile.gd` - Add retrieval flag
- `/blocky_game/projectiles/thrown_torch.gd` - Add retrieval flag (future)
- `/blocky_game/projectiles/light_orb.gd` - Add retrieval flag (future)
- `/blocky_game/player/avatar_interaction.gd` - Add retrieval detection
- `/blocky_game/entities/companion.gd` - Add companion retrieval support
- `/blocky_game/gui/inventory/inventory.gd` - Add Return to modal

### Related Files (No Changes)
- `/blocky_game/player/inventory_item.gd` - Uses existing power system
- `/blocky_game/items/item_db.gd` - Already supports all items
- `/blocky_game/items/spear/spear.gd` - Already throws correctly
