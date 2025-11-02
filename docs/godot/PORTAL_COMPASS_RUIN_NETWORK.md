# Portal Compass & Ruin Network System

## Overview
A persistent teleportation network that tracks visited ruins and allows players to navigate between them using a consumable item called the **Portal Compass**.

---

## Core Concepts

### 1. Persistent Ruin Tracking
- All spawned ruins are tracked with position, type, name, and portal properties
- Ruins persist for the game session (could be saved later)
- Each ruin can have one or more teleport stones with different properties

### 2. Visual Glow Color System
Teleport stones use colored lights to communicate their function:

| Color | Meaning | Behavior |
|-------|---------|----------|
| 🔵 **Blue/Cyan** | Unvisited Portal | Leads to a new random ruin (current default) |
| ⚪ **White/Silver** | Visited Portal | Previously used, still works |
| 🔴 **Red** | Combat Portal | Leads to ruin with 3-5 enemies, better loot |
| 💚 **Green** | Return Stone | Two-way portal, can teleport back here |
| 🟣 **Purple** | Home Stone | Always returns to crashed tower (spawn) |

### 3. Portal Compass Item
**Item Properties:**
- **Name**: Portal Compass
- **Type**: Consumable tool (like torches)
- **Item ID**: 12
- **Icon**: `project/assets/art/tools/compass.png` or `ancientAmulet.png`
- **Stack Size**: Starts at 2-3 per chest find
- **Usage**: -1 per teleport navigation
- **Rarity**: Uncommon (15-20% chest drop chance)

**Behavior:**
1. Player holds Portal Compass in active hotbar slot
2. Click on any teleport stone
3. Opens navigation modal showing all visited ruins
4. Player selects destination
5. Consumes 1 compass charge
6. Teleports to selected ruin's teleport stone

---

## Ruin Properties

### Named Landmarks
Each ruin gets a unique generated name on first visit:

**Examples:**
- Coliseum variants: "The Grand Coliseum", "Ancient Arena", "Battle Grounds"
- Sky City variants: "Cloudtop District", "Skyport Quarter", "Aerial Plaza"
- Castle variants: "Storm Keep", "Cloud Fortress", "Sky Citadel"
- Temple variants: "Temple of Winds", "Sacred Sanctuary", "Ancient Shrine"
- Tower variants: "Wizard's Spire", "Arcane Tower", "Mage Observatory"
- Garden variants: "Hanging Gardens", "Sky Oasis", "Celestial Grove"
- Forest variants: "Floating Grove", "Treetop Haven", "Aerial Woodland"
- Plaza variants: "Merchant Square", "Trade Plaza", "Central Court"
- Desert variants: "Sand Temple", "Desert Sanctum", "Pyramid Shrine"

### Combat Ruins (Red Glow)
- **Spawn Chance**: 20% when generating new ruins
- **Enemy Count**: 3-5 enemies spawned on arrival
- **Loot Bonus**: 2x chest spawn chance (2-6 chests instead of 1-3)
- **Warning**: "⚠️ This stone emanates a dangerous aura..." message before teleport
- **Visual**: Red pulsing light, perhaps with red particles

### Return Stones (Green Glow)
- **Spawn Chance**: 30% of teleport stones in ruins
- **Behavior**: Can be revisited from anywhere using Portal Compass
- **Purpose**: Creates strategic "hub" points in the network
- **Strategic Value**: Players might seek these out to create safe navigation points

### Home Stones (Purple Glow)
- **Spawn Chance**: 10% chance per ruin to have ONE home stone
- **Behavior**: Always teleports back to crashed tower (spawn point)
- **Purpose**: Emergency escape / "I'm lost" safety net
- **One-Way**: Cannot use Portal Compass to return to the purple stone's ruin

---

## Data Structure

### Ruin Tracking Object
```gdscript
{
    "position": Vector3(x, y, z),           # World position where ruin spawned
    "ruin_type": "coliseum",                # Template name
    "ruin_name": "The Grand Coliseum",     # Generated unique name
    "teleport_stones": [                    # Array of teleport stones in this ruin
        {
            "local_pos": Vector3(x, y, z),  # Position relative to ruin base
            "stone_type": "return",          # "normal", "return", "home", "combat"
            "glow_color": Color(0, 1, 0),   # Green for return stones
            "has_been_used": true            # Track if player used this specific stone
        }
    ],
    "has_enemies": false,                   # True for combat ruins
    "enemies_defeated": false,              # Track if combat cleared
    "chests_looted": [Vector3i(), ...],     # Track which chests opened
    "visit_count": 1,                       # How many times visited
    "last_visited": 0                       # Game time timestamp
}
```

---

## Portal Compass Navigation Modal

### UI Design
**Layout:**
- **Title**: "Portal Compass - Select Destination"
- **Ruin List**: Scrollable list of visited ruins
- **Each Entry Shows**:
  - Colored indicator (circle/square matching portal glow color)
  - Ruin name
  - Ruin type (small text)
  - Distance from current position (optional)
  - Last visited info: "Current Location" / "2 portals ago" / "5 portals ago"
  - Special icons: ⚔️ for combat, 🏠 for home, ↩️ for return

**Interaction:**
1. Click a ruin entry → Highlight it
2. "Travel" button at bottom
3. "Cancel" button to close without using compass
4. Confirmation: "Travel to [Ruin Name]? (Uses 1 Portal Compass)"
5. On confirm: -1 compass, teleport to that ruin's primary teleport stone

### Future Enhancement (3D Wireframe)
- Could add 3D visualization later
- Mouse drag to rotate
- Click nodes in 3D space
- For now, simple list is functional and easier to debug

---

## Implementation Phases

### Phase 1: Foundation (Tracking System)
**Goal**: Track ruins and basic persistence

**Tasks:**
1. Create global ruin registry (singleton or Game node variable)
2. Modify RuinSpawner to register ruins when spawned
3. Generate unique ruin names on spawn
4. Track teleport stone positions and types
5. Assign random portal types (normal, return, home, combat)
6. Test: Spawn ruins, verify data structure

**Files to Modify:**
- `project/blocky_game/ruins/RuinSpawner.gd` - Add registration
- Create new: `project/blocky_game/ruins/RuinRegistry.gd` - Singleton

### Phase 2: Glow Color System
**Goal**: Visual feedback for portal types

**Tasks:**
1. Modify RuinSpawner `_add_teleport_stone_light()` function
2. Accept color parameter based on stone type
3. Update light color when spawning:
   - Blue (default): `Color(0.4, 0.7, 1.0)` - unvisited
   - White: `Color(0.9, 0.9, 1.0)` - visited
   - Red: `Color(1.0, 0.2, 0.2)` - combat
   - Green: `Color(0.2, 1.0, 0.4)` - return
   - Purple: `Color(0.8, 0.3, 1.0)` - home
4. Add pulsing animation for red combat portals
5. Test: Verify colors appear correctly

**Files to Modify:**
- `project/blocky_game/ruins/RuinSpawner.gd` - Light color system

### Phase 3: Portal Compass Item
**Goal**: Create the navigation item

**Tasks:**
1. Create Portal Compass item in ItemDB
2. Create behavior script `portal_compass.gd`
3. Set up icon (compass.png or ancientAmulet.png)
4. Add to chest loot table (15-20% chance, 2-3 stack)
5. Implement consumable behavior (count decrements)
6. Test: Find in chest, verify icon, verify count

**Files to Create:**
- `project/blocky_game/items/portal_compass.gd`

**Files to Modify:**
- `project/blocky_game/items/item_db.gd` - Add item ID 12
- `project/blocky_game/player/avatar_interaction.gd` - Add to chest loot table

### Phase 4: Navigation Modal UI
**Goal**: Portal selection interface

**Tasks:**
1. Create modal scene with Control node
2. Add ItemList or VBoxContainer for ruin entries
3. Add colored indicators (ColorRect or TextureRect)
4. Populate list from RuinRegistry
5. Handle selection and confirmation
6. Implement teleportation logic
7. Decrement Portal Compass count
8. Test: Open modal, select ruin, verify teleport

**Files to Create:**
- `project/blocky_game/gui/portal_compass_modal.tscn`
- `project/blocky_game/gui/portal_compass_modal.gd`

**Files to Modify:**
- `project/blocky_game/player/avatar_interaction.gd` - Detect compass + teleport stone click

### Phase 5: Combat Ruins
**Goal**: Dangerous portals with enemies

**Tasks:**
1. Mark 20% of ruins as combat ruins during generation
2. Spawn 3-5 enemies when player arrives at combat ruin
3. Increase chest count (2-6 instead of 1-3)
4. Add warning message before teleport
5. Track if enemies defeated
6. Test: Find red portal, verify enemies spawn

**Files to Modify:**
- `project/blocky_game/ruins/RuinSpawner.gd` - Combat ruin flag
- `project/blocky_game/player/avatar_interaction.gd` - Enemy spawning on arrival
- `project/blocky_game/ruins/RuinLibrary.gd` - Adjust chest counts

### Phase 6: Polish & Features
**Goal**: Final touches

**Tasks:**
1. Add "last visited" tracking
2. Implement visit count
3. Add distance calculations (optional)
4. Create sound effects for portal types
5. Add particle effects for combat portals
6. Implement chest loot tracking per ruin
7. Add warning dialogs for combat/home stones
8. Test full flow end-to-end

---

## Future Enhancements

### Save/Load System
- Persist ruin registry to save file
- Restore network on game load
- Track across game sessions

### NPC Integration
- Place NPCs in Sky City District
- Place NPCs in Grand Castle
- Merchants, quest givers, etc.

### Quest System
- "Find the Ancient Temple" quests
- "Clear 3 Combat Ruins" challenges
- Rewards: Portal Compass stacks, unique items

### Map Visualization
- 3D wireframe node graph (original idea)
- 2D map overlay
- Show connections between ruins
- Highlight current location

### Portal Linking
- Some ruins have multiple outgoing connections
- Create actual network graph instead of random jumps
- Design intentional "paths" through ruins

---

## Technical Notes

### Portal Compass Usage Detection
```gdscript
# In avatar_interaction.gd
if hit != null and _action_use:
    var hit_raw_id := _terrain_tool.get_voxel(hit.position)
    if hit_raw_id != 0:
        var rm := _block_types.get_raw_mapping(hit_raw_id)
        # Teleport stone is block ID 20
        if rm.block_id == 20:
            # Check if player holding Portal Compass (item ID 12)
            var inv_item = _hotbar.get_selected_item()
            if inv_item != null and inv_item.type == InventoryItem.TYPE_ITEM and inv_item.id == 12:
                # Player has compass - show navigation modal
                _show_portal_compass_modal(hit.position)
            else:
                # Normal teleport behavior
                _handle_teleport_stone_interaction(hit.position)
```

### Ruin Name Generation
Use arrays of prefixes and suffixes:
```gdscript
var coliseum_names = ["The Grand", "Ancient", "Ruined", "Storm"]
var coliseum_suffix = ["Coliseum", "Arena", "Battle Grounds", "Pit"]
var final_name = coliseum_names[randi() % coliseum_names.size()] + " " + coliseum_suffix[randi() % coliseum_suffix.size()]
```

Track used names to ensure uniqueness per type.

---

## Testing Checklist

### Phase 1 Testing
- [ ] Ruins are registered when spawned
- [ ] Ruin data persists in registry
- [ ] Unique names generated
- [ ] Portal types assigned correctly
- [ ] Can query registry for ruin info

### Phase 2 Testing
- [ ] Blue glow for unvisited portals
- [ ] White glow for visited portals
- [ ] Red glow for combat portals
- [ ] Green glow for return stones
- [ ] Purple glow for home stones
- [ ] Colors are clearly distinguishable

### Phase 3 Testing
- [ ] Portal Compass found in chests
- [ ] Correct icon displays
- [ ] Stack count shows correctly
- [ ] Item appears in hotbar
- [ ] Count decrements on use

### Phase 4 Testing
- [ ] Modal opens when using compass on portal
- [ ] All visited ruins listed
- [ ] Colored indicators match portal types
- [ ] Selection works correctly
- [ ] Teleportation occurs to correct ruin
- [ ] Compass count decrements
- [ ] Modal closes after teleport
- [ ] Cancel button works

### Phase 5 Testing
- [ ] Combat ruins spawn at 20% rate
- [ ] Red glow appears correctly
- [ ] Warning message shows
- [ ] 3-5 enemies spawn on arrival
- [ ] Extra chests present
- [ ] Combat cleared flag works

### Phase 6 Testing
- [ ] Visit count increments
- [ ] Last visited tracking works
- [ ] Sounds play correctly
- [ ] Particles appear
- [ ] Full loop: spawn → visit → compass → return → combat

---

## Design Rationale

### Why Consumable?
- Creates resource management tension
- Finding more compasses in chests feels rewarding
- Prevents trivial fast-travel abuse
- Encourages exploration to find more

### Why Track Everything?
- Enables future features (quests, maps, achievements)
- Good for debugging during development
- Can add data-driven features later
- Player progression visibility

### Why Color-Coded?
- Instant visual feedback
- No text needed
- Colorblind consideration: use distinct hues + brightness
- Memorable system

### Why Named Ruins?
- Creates memorable locations
- "Meet me at Storm Keep" vs "Meet me at ruin #5"
- Adds personality to procedural content
- Easier to reference in UI

---

## Known Limitations

1. **No Persistence**: Currently session-only, resets on game restart
2. **No Spatial Map**: Just a list, no visualization of network layout
3. **No Manual Portal Creation**: Players can't create their own portals
4. **Limited Network Control**: Connections are still somewhat random
5. **No Portal Upgrades**: Can't improve or customize portals

These are intentional for V1 and can be added later if needed.

---

## Implementation Timeline Estimate

- **Phase 1**: 2-3 hours (data structures, tracking)
- **Phase 2**: 1-2 hours (light colors, simple)
- **Phase 3**: 1-2 hours (item creation, straightforward)
- **Phase 4**: 3-4 hours (UI modal, most complex part)
- **Phase 5**: 2-3 hours (enemy spawning, loot tuning)
- **Phase 6**: 2-3 hours (polish, testing, balancing)

**Total**: ~12-17 hours of development time

---

## Version History
- **v0.1** - Initial design document (2025-01-13)
