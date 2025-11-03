# Combat Ruins & Boss Progression System

## Overview
A three-tiered endgame progression system that scales from regular combat encounters to underground boss battles, culminating in a final boss fight unlocked through ritual at the crashed tower.

---

## Progression Tiers

### Tier 1: Sky Combat Ruins (Regular Endgame Content)
**Purpose:** Challenging encounters with better loot

**Properties:**
- **Spawn Rate:** 20% of all ruins are combat ruins
- **Visual:** Red pulsing light at teleport stones
- **Warning:** "⚠️ This stone emanates a dangerous aura..."
- **Enemies:** 3-5 enemies spawn immediately on arrival
- **Loot:** 2-6 chests (vs normal 1-3)
- **Clear Tracking:** Once cleared, portal changes from red to white
- **Respawn:** Enemies respawn on revisit (replayable)

**Combat Ruin Templates (Designed for Fighting):**
1. Arena Coliseum - Open pit with stone pillars
2. Ruined Garden Maze - Hedges and fallen trees
3. Broken Bridge Fortress - Multi-platform with gaps
4. Stone Outcrop Battlefield - Natural rock formations
5. Ancient Courtyard - Walled enclosure with buildings

### Tier 2: Underground Boss Battles (Progression Gates)
**Purpose:** Unique challenges that unlock final boss

**Unlock Requirement:**
- Clear **10 combat ruins** → Boss portal appears
- Boss portal has special appearance (gold/obsidian glow?)
- Portal is one-time use per boss
- 4 total boss fights (4 Ancient Artifacts)

**Arena Design:**
- **Location:** Underground (below bedrock)
- **Containment:** Bedrock-lined chambers
- **Size:** Large custom arenas (50x50x20 blocks)
- **Atmosphere:** Torchlit, claustrophobic, epic
- **Lighting:** Dramatic shadows, colored lights per boss
- **No Escape:** Sealed until boss defeated

**Boss Properties:**
- Unique mechanics per boss
- Higher HP pool than normal enemies
- Special attack patterns
- Visual tells for attacks
- Victory music/fanfare

**Rewards:**
- 1 **Ancient Artifact** (unique progression item)
- High-tier loot chests (5-10)
- Crafting materials
- Rare weapons/items

### Tier 3: Final Boss (Game Completion)
**Purpose:** Epic finale that requires full progression

**Unlock Requirements:**
1. Collect all 4 Ancient Artifacts (from boss battles)
2. Return to crashed tower (spawn point)
3. Have all 4 artifacts in hotbar + Portal Compass
4. Click on portal stone with compass

**Ritual Activation:**
- Visual effect when all 4 artifacts detected
- Portal transforms (special effect)
- Message: "The Ancient Artifacts resonate... A path opens to the Final Citadel"
- One-way trip (must defeat or die)

**Final Boss Arena:**
- **Location:** Epic sky ruin (custom design)
- **Scale:** Massive (100x100+ platform)
- **Multiple Phases:** Boss evolves through fight
- **Mechanics:** Combines elements from all 4 bosses
- **Victory:** Game completion screen, ending

**Rewards:**
- Ultimate weapon/item
- Endgame credits
- "New Game+" unlock (optional)
- Trophy/achievement

---

## Combat Ruin Template Designs

### 1. Arena Coliseum (Combat Variant)
```
Dimensions: 40x40x15 blocks
Theme: Roman gladiator arena

Layout:
- Center: 25x25 open fighting space
- Perimeter: Raised platforms (3 blocks high)
- Pillars: 8 stone columns (5 blocks tall) for cover
- Walls: Crumbling coliseum walls around edge
- Arches: 4 entrance arches (visual interest)

Spawn Points:
- Player: Center of raised platform (east side)
- Enemies: Scattered in arena floor (3-5 positions)

Chests:
- 3 in alcoves under raised platforms
- 1 on top of center pillar (parkour challenge)

Obstacles:
- Pillars provide cover from ranged attacks
- Broken statues near walls
- Sand/dirt floor texture variant
```

### 2. Ruined Garden Maze
```
Dimensions: 45x45x12 blocks
Theme: Overgrown sky gardens

Layout:
- Hedge walls: 4-block high vegetation barriers
- Pathways: 3-block wide corridors
- Center: Gazebo with portal stone
- Dead ends: 3-4 false paths
- Trees: Scattered throughout (vision blocking)

Spawn Points:
- Player: Center gazebo
- Enemies: Hidden in maze paths (ambush potential)

Chests:
- 2 in dead-end alcoves
- 1 in secret corner (behind tree)

Obstacles:
- Hedge walls block line of sight
- Fallen tree trunks (must jump over)
- Overgrown vines on structures
- Flower patches (decorative)
```

### 3. Broken Bridge Fortress
```
Dimensions: 50x30x20 blocks
Theme: Shattered fortress with gaps

Layout:
- 5 platforms at different heights
- Rope/stone bridges connecting (some broken)
- Central tower: 15 blocks tall
- Gaps: 5-8 block falls between platforms
- Ruins: Half-destroyed towers on edges

Spawn Points:
- Player: Top of central tower
- Enemies: Distributed across platforms (3-5)

Chests:
- 1 per platform (5 total)
- Requires jumping gaps to collect all

Obstacles:
- Broken walls provide cover
- Gaps create fall hazard
- Stairs/ramps between levels
- Rubble piles
```

### 4. Stone Outcrop Battlefield
```
Dimensions: 40x40x18 blocks
Theme: Natural rocky terrain

Layout:
- Large boulders: 5-7 huge rock formations
- Hills: Uneven ground (height variance 0-8 blocks)
- Valleys: Low spots between rocks
- Cliffs: Steep rock faces
- Natural pillars: Stone spires reaching up

Spawn Points:
- Player: Top of tallest rock (high ground)
- Enemies: Scattered in valleys and on rocks

Chests:
- 3 tucked behind large boulders
- 1 in cave entrance (small alcove)

Obstacles:
- Boulders block movement and vision
- Uneven terrain affects combat
- Small caves for hiding
- Stone spires for vertical gameplay
```

### 5. Ancient Courtyard
```
Dimensions: 35x35x14 blocks
Theme: Walled temple courtyard

Layout:
- Outer walls: 6 blocks high, enclosing space
- Buildings: 2 small structures (ruins)
- Courtyard: Open central area (20x20)
- Statues: 4 decorative statues on pedestals
- Gate: Entrance archway (player spawn)

Spawn Points:
- Player: Main gate entrance
- Enemies: Inside courtyard and buildings

Chests:
- 2 inside ruined buildings
- 1 behind statue
- 1 on wall walkway (accessible via stairs)

Obstacles:
- Walls channel movement
- Buildings provide interior combat
- Statue pedestals as cover
- Broken furniture inside buildings
```

---

## Underground Boss Arena Design

### General Structure
```
Dimensions: 60x60x25 blocks
Containment: Full bedrock shell (walls, floor, ceiling)
Interior: Varies per boss theme
Access: Portal appears in center, player spawns on edge
```

### Boss Arena Features
- **Indestructible Environment:** Bedrock prevents terrain destruction
- **Dramatic Lighting:** Colored lights matching boss theme
- **Pillars/Cover:** Strategic elements for dodging
- **Phase Transitions:** Arena may change during fight
- **Sealed Entry:** Portal closes after entry (must win or die)

### Four Boss Themes (Placeholder)
1. **Fire Boss:** Lava pools, flame pillars, volcanic theme
2. **Ice Boss:** Frozen pillars, slippery floor, blizzard effects
3. **Nature Boss:** Giant tree roots, vine obstacles, poisonous plants
4. **Shadow Boss:** Dark corners, teleport points, illusions

*Detailed boss mechanics to be designed per boss*

---

## Ancient Artifact System

### Item Properties
- **Name:** Ancient Artifact (each has unique subtitle)
- **Type:** Quest Item (cannot be dropped/destroyed)
- **Stack Size:** 1 (each artifact is unique)
- **Visual:** Glowing item with boss-themed color
- **Rarity:** Legendary (gold border)

### Four Artifacts (Concepts)
1. **Flame Heart Crystal** (Fire Boss) - Red glow
2. **Frozen Shard Core** (Ice Boss) - Blue glow
3. **Living Root Essence** (Nature Boss) - Green glow
4. **Shadow Veil Fragment** (Shadow Boss) - Purple glow

### Detection System
- Game tracks which artifacts player owns
- Crashed tower portal stone detects all 4 in hotbar
- Visual feedback when requirement met
- Confirmation dialog before activating final boss

---

## Final Boss Design (Placeholder)

### Arena: "The Final Citadel"
```
Size: 100x100x30 blocks
Theme: Floating fortress at extreme height
Layout:
- Central platform: 60x60 main fighting area
- Outer ring: 20-block wide walkway
- Towers: 4 corner towers (decorative/functional)
- Sky backdrop: Endless void below
- Weather: Dynamic (storm effects)
```

### Boss Mechanics (Concept)
- **Phase 1:** Ground combat, basic attacks
- **Phase 2:** Aerial movement, projectiles
- **Phase 3:** Summons minions, combines all element attacks
- **Phase 4:** Ultimate form, arena changes

### Victory Sequence
1. Boss defeated → drops ultimate loot
2. Portal opens to safety (or auto-teleport)
3. Credits roll
4. Return to crashed tower
5. Ending dialogue/achievement unlock

---

## Enemy Spawning System

### Combat Ruin Spawning
**Trigger:** Player teleports to combat ruin

**Spawn Logic:**
```gdscript
func _on_player_arrived_at_combat_ruin(ruin_data):
    if not ruin_data.enemies_defeated:
        var enemy_count = randi_range(3, 5)
        var spawn_points = _get_safe_spawn_points(ruin_data)

        for i in range(enemy_count):
            var spawn_pos = spawn_points[i % spawn_points.size()]
            _spawn_enemy_at_position(spawn_pos)

        # Mark as having active enemies
        ruin_data.has_active_enemies = true
```

**Safe Spawn Requirements:**
- Not too close to player (min 10 blocks)
- Not too far (max 30 blocks)
- On solid ground (raycast check)
- Clear space above (3 blocks)
- Not inside walls

### Boss Spawning
**Trigger:** Player enters boss arena

**Spawn Logic:**
- Boss spawns at designated point (arena center or throne)
- Entry portal seals immediately
- Boss music starts
- HUD shows boss health bar
- Arena boundaries activate (invisible walls)

---

## Tracking & Persistence

### RuinRegistry Extensions
```gdscript
# Existing RuinData additions:
var has_active_enemies: bool = false
var enemies_defeated: bool = false
var combat_clears_count: int = 0  # Global counter

# New BossData structure:
class BossData:
    var boss_id: String              # "fire_boss", "ice_boss", etc.
    var defeated: bool = false
    var artifact_collected: bool = false
    var arena_position: Vector3
    var unlock_combat_clears: int = 10  # Required clears to unlock
```

### WorldManager Extensions
```gdscript
var _world_data = {
    # ... existing fields ...
    "combat_ruins_cleared": 0,
    "bosses_defeated": [],
    "artifacts_collected": [],
    "final_boss_unlocked": false,
    "final_boss_defeated": false
}
```

---

## UI/UX Considerations

### Portal Compass Modal
- Show combat clear count: "Combat Ruins Cleared: 7/10" (before boss unlock)
- Boss portal indicator: 💀 icon
- Final boss portal: ⚔️ icon
- Artifact count in modal: "Ancient Artifacts: 3/4"

### Warning Dialogs
**Combat Ruin:**
```
⚠️ WARNING: Dangerous Portal Detected

This portal leads to a combat ruin.
Enemies await on the other side.

Continue?
[Teleport] [Cancel]
```

**Boss Portal:**
```
💀 BOSS PORTAL DETECTED

This portal leads to an underground boss arena.
You cannot return until the boss is defeated.

Prepare yourself.

[Enter Arena] [Cancel]
```

**Final Boss:**
```
⚔️ THE FINAL CITADEL AWAKENS

All four Ancient Artifacts resonate with power.
The path to the Final Boss is open.

This is your ultimate challenge.
Are you ready?

[Face Destiny] [Not Yet]
```

---

## Implementation Phases

### Phase 5A: Basic Combat Ruins
**Goal:** Get enemy spawning working
1. Implement enemy spawn on combat ruin arrival
2. Add safe spawn point detection
3. Test with existing ruin templates
4. Add combat clear tracking
5. Red → white portal color change on clear

### Phase 5B: Combat Ruin Templates
**Goal:** Design specialized combat arenas
1. Create 5 combat ruin templates
2. Add obstacles, cover, height variance
3. Place chest spawn points
4. Test spawn points for safety
5. Balance enemy positions

### Phase 6: Boss Portal System
**Goal:** Unlock progression gates
1. Add combat clear counter
2. Implement boss portal spawn (after 10 clears)
3. Add special portal appearance
4. Create underground arena generation
5. Add bedrock containment

### Phase 7: Boss Battles
**Goal:** Four unique bosses
1. Design boss enemy types
2. Implement boss mechanics
3. Create arena-specific effects
4. Add boss music/sounds
5. Implement Ancient Artifact drops

### Phase 8: Final Boss
**Goal:** Epic endgame encounter
1. Design Final Citadel arena
2. Create multi-phase boss
3. Implement ritual at crashed tower
4. Add victory sequence
5. Credits/ending

---

## Balance Considerations

### Difficulty Scaling
- **Combat Ruins:** Challenging but fair (3-5 normal enemies)
- **Boss Battles:** Significant challenge (requires skill/strategy)
- **Final Boss:** Peak difficulty (uses all learned mechanics)

### Reward Pacing
- Combat ruins provide steady loot income
- Boss battles give major progression items
- Final boss gives ultimate reward + completion

### Player Readiness
- Combat ruins teach combat mechanics
- 10 clears = player should be ready for boss
- Each boss teaches mechanics for final boss
- Final boss tests everything learned

---

## Technical Notes

### Bedrock Generation for Boss Arenas
```gdscript
func _create_boss_arena(center_pos: Vector3, boss_id: String):
    var terrain_tool = _terrain.get_voxel_tool()
    var bedrock_id = _block_types.get_block_by_name("bedrock").base_info.id
    var air_id = 0

    # Create bedrock shell (60x60x25)
    for x in range(-30, 30):
        for y in range(-5, 20):
            for z in range(-30, 30):
                var pos = Vector3i(center_pos) + Vector3i(x, y, z)

                # Outer shell = bedrock
                if x in [-30, 29] or z in [-30, 29] or y in [-5, 19]:
                    terrain_tool.set_voxel(pos, bedrock_id)
                else:
                    # Interior = air
                    terrain_tool.set_voxel(pos, air_id)

    # Add boss-specific decorations
    _decorate_boss_arena(center_pos, boss_id)
```

---

## Future Enhancements

### New Game+ Mode
- Replay with increased difficulty
- Retain artifacts (cosmetic)
- Harder enemy variants
- Better loot rolls

### Boss Rush Mode
- Fight all 4 bosses + final boss consecutively
- Special reward for completion
- Leaderboard/time tracking

### Additional Bosses
- More elemental bosses
- Optional super-bosses
- Secret boss (hidden unlock)

---

## Version History
- **v0.1** - Initial design document (2025-01-XX)
