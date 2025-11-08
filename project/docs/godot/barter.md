# The Undervoid & NPC Barter Economy

**Design Document - Created: 2025-01-08**

## Overview

The Undervoid is a dangerous floating-island realm beneath the surface world (below Y -10). It features a unique resource loop where players mine rust blocks, trade with NPCs to refine them into iron, and use iron blocks for blood moon defense - which eventually degrade back to rust, creating a renewable gameplay cycle.

---

## The Undervoid (Underground Area)

### Naming & Theme
- **Name:** "The Undervoid"
- **Alternative names considered:** The Fragments, The Shattered Depths, The Chasm
- **Theme:** Floating islands suspended in vast dark void above bedrock floor
- **Atmosphere:** Dangerous, mysterious, resource-rich but high-risk

### Current Structure
- Floating islands of various sizes scattered throughout
- Mostly empty space between islands (void)
- Bedrock floor at bottom (abrupt stop currently)
- Rich in rust_* blocks, with some gold and iron ore
- Rust Golems and other enemies spawn

### Terrain Generation Improvements (TODO)

#### 1. Larger Islands for Content
- **Goal:** Create landmark islands large enough for monster camps, NPC settlements, treasure rooms
- **Specs:**
  - Size: 30x30+ blocks (some up to 50x50)
  - Spawn at specific depths: Y -150, Y -250, Y -350
  - Deeper islands = larger size
  - Could contain pre-generated structures (camps, ruins, treasure vaults)

#### 2. Bedrock Floor Coating
- **Goal:** Make the bottom feel more natural, less abrupt
- **Implementation:**
  - Add generation layer from Y -400 to Y -390
  - Rolling "hills" made of: rust_blocks (primary), stone, dirt
  - Creates valleys and peaks on bedrock
  - Could hide treasure chests or small camps in valleys
  - Makes it feel like ancient seabed/wasteland

#### 3. Island Distribution
- **Upper Undervoid (Y -10 to Y -100):** Smaller islands, more scattered
- **Mid Undervoid (Y -100 to Y -250):** Medium islands, some large ones
- **Deep Undervoid (Y -250 to Y -400):** Large islands, more concentrated, highest danger

---

## Rust → Iron Resource Loop

### The Cycle

```
1. Mine rust_* blocks in Undervoid (dangerous)
   ↓
2. Trade with Blacksmith NPC (barter system)
   ↓
3. Receive refined iron blocks (next day at noon)
   ↓
4. Build iron fortress (protects for 3 blood moons)
   ↓
5. After 3rd blood moon: iron blocks degrade to rust_blocks
   ↓
6. Return to Undervoid for more rust (cycle repeats)
```

### Resource Properties

#### Rust Blocks
- **Location:** Abundant in Undervoid (everywhere)
- **Purpose:** Raw material for iron refining
- **Durability:** Medium - survives 1 blood moon assault before destroyed
- **Use Cases:**
  - Temporary fortifications
  - Trading material for iron
  - Emergency building material

#### Iron Blocks (Refined)
- **Source:** Refined from rust blocks via Blacksmith NPC
- **Durability:** High - survives 3 blood moon assaults
- **Degradation:** After 3rd blood moon, iron → rust
- **Trade Rate Examples:**
  - Base: 10 rust blocks → 1 iron block
  - With favorite food: 10 rust → 2 iron blocks
  - With disliked item: 15 rust → 1 iron block

### Strategic Choices
- **Build with rust:** Cheap, abundant, but only lasts 1 blood moon
- **Build with iron:** Expensive (requires NPC), lasts 3 blood moons
- **Live on Sky Ruins:** Safe from blood moon damage entirely (but inconvenient)

---

## NPC Barter System

### Core Concept
Instead of player-operated furnaces/crafting stations (Minecraft style), NPCs with jobs perform services in exchange for items the player values. This creates a **barter economy** with personality.

### Key Features
- **No currency:** Pure item-for-item/item-for-service trades
- **NPC Preferences:** Each NPC wants different things, values items differently
- **Time-Gated:** Work takes time (return tomorrow at noon)
- **Social Element:** Find NPCs, build relationships, remember who likes what

### NPC Job Types

#### 1. Blacksmith
- **Service:** Refines rust_* blocks into iron blocks
- **Location:** Large Undervoid island or safe surface location
- **Wants (in order of preference):**
  1. Pumpkin Pie (favorite!) - Best exchange rate
  2. Cooked meat/fish - Good rate
  3. Coal/fuel - Standard rate
  4. Eggs - Poor rate (doesn't like them)
- **Trade Examples:**
  ```
  10 rust blocks + 1 pumpkin pie = 2 iron blocks (tomorrow noon)
  10 rust blocks + 2 coal = 1 iron block (tomorrow noon)
  15 rust blocks + 3 eggs = 1 iron block (tomorrow noon)
  ```
- **Completion Time:** Next day at noon (game time)

#### 2. Cook
- **Service:** Cooks raw food into better meals
- **Integration:** Connects to existing cooking console command
- **Wants:**
  - Firewood (fuel)
  - Berries/honey (ingredients)
  - Cooking recipes (unlocks new dishes)
- **Trade Examples:**
  ```
  5 raw fish + 2 firewood = 5 grilled fish (tomorrow noon)
  3 berries + 2 honey + 1 wheat = berry honey bread (tomorrow noon)
  ```

#### 3. Armorer
- **Service:** Repairs/upgrades weapons and tools
- **Wants:**
  - Iron blocks (material)
  - Skyshards (for enchantments)
  - Rare ores (gold, diamonds)
- **Trade Examples:**
  ```
  Damaged sword + 2 iron blocks = Repaired sword (tomorrow noon)
  Sword + 5 skyshards + 3 iron = Powered sword (2 days)
  ```

#### 4. Merchant
- **Service:** Buys/sells rare items and curiosities
- **Wants:**
  - Gold ore/blocks
  - Gemstones
  - Rare drops from bosses
- **Trade Examples:**
  ```
  3 gold ore = 1 portal compass (tomorrow noon)
  10 gold ore = 1 rocket launcher (2 days)
  Boss trophy = Unique legendary item (3 days)
  ```

### NPC Integration with testNPC

#### Current testNPC System
- Already exists in codebase
- Can be placed in world
- Needs right-click interaction added

#### Required Implementation

1. **Right-Click to Talk**
   - Detect player right-click on testNPC
   - Open existing dialog modal system
   - Show NPC greeting + job description

2. **Trade Modal UI**
   ```
   ┌─────────────────────────────────────┐
   │  Blacksmith - "Need some iron?"    │
   ├─────────────────────────────────────┤
   │  YOUR ITEMS:                        │
   │  [10x Rust Blocks]  [Select]       │
   │  [3x Pumpkin Pie]   [Select]       │
   │  [5x Coal]          [Select]       │
   │                                     │
   │  TRADE OFFER:                       │
   │  Give: 10 Rust + 1 Pumpkin Pie     │
   │  Get:  2 Iron Blocks                │
   │                                     │
   │  Ready: Wednesday Noon              │
   │                                     │
   │  [Accept Trade]  [Cancel]          │
   └─────────────────────────────────────┘
   ```

3. **Time-Gated Completion**
   - Player accepts trade → Items removed from inventory
   - Game stores: NPC ID, completion time, output items
   - Player returns after deadline (noon next day minimum)
   - Right-click NPC → "Your order is ready!" → Items added to inventory

4. **Barter Rate Calculation**
   ```gdscript
   func calculate_trade_rate(npc_type: String, items_offered: Array) -> Dictionary:
       var base_rate = NPC_BASE_RATES[npc_type]
       var preference_multiplier = 1.0

       for item in items_offered:
           if item in NPC_FAVORITE_ITEMS[npc_type]:
               preference_multiplier = 2.0  # Double output
           elif item in NPC_DISLIKED_ITEMS[npc_type]:
               preference_multiplier = 0.66  # 33% penalty

       return {
           "input": items_offered,
           "output_count": base_rate * preference_multiplier,
           "completion_time": get_next_noon()
       }
   ```

---

## Monster Camps & Danger Zones

### Depth-Based Danger Scaling

#### Tier 1: Surface Caves (Y 0 to Y -50)
- Normal enemy spawn rates
- Surface animals still spawn (rabbits, deer)
- Relatively safe

#### Tier 2: Deep Caves (Y -50 to Y -150)
- 50% increased enemy spawn rate
- No surface animals spawn
- Introduction of "Depths" enemies

#### Tier 3: The Undervoid (Y -150 to Y -300)
- 2x enemy spawn rate
- Elite enemy variants appear (10% chance)
- Monster camps on large islands

#### Tier 4: The Abyss (Y -300 to Y -400)
- 3x enemy spawn rate
- Only hardest enemies spawn
- Boss lairs and treasure vaults

### Monster Camps (TODO)

#### Structure
- **Location:** Large islands (20x20+ blocks)
- **Enemies:** 5-10 enemies clustered together
- **Features:**
  - Campfire (light source + thematic)
  - Crude walls made of rust_blocks (thematic!)
  - Wooden/stone structures
  - 1 guaranteed treasure chest in center

#### Loot
- Pre-powered weapons (skyshards already installed)
- Stacks of refined iron blocks
- Rare food items
- Portal compasses

#### Mechanics
- Enemies patrol around camp
- Alert nearby enemies if player spotted
- Chest only accessible after clearing camp
- Respawns after 10 minutes (game time)

### Elite Enemy Variants

#### Visual Design
- Glowing red/purple aura
- Particle effects
- Slightly larger model scale (1.2x)

#### Stats
- 2x HP
- 1.5x Attack Damage
- 1.5x Movement Speed
- 10% chance to replace normal enemy spawn

#### Loot
- Guaranteed powered weapon drop
- Extra skyshards
- Rare materials

---

## Implementation Priority

### Phase 1: Foundation (Morning Session)
1. ✅ Terrain Generation Improvements
   - Larger islands at key depths
   - Bedrock floor coating
   - Island size variation

### Phase 2: NPC Barter System
1. Right-click interaction on testNPC
2. Dialog modal integration
3. Trade UI modal
4. Barter rate calculation
5. Time-gated completion system
6. Item exchange mechanics

### Phase 3: Danger Scaling
1. Depth-based spawn multipliers
2. Remove animals below Y -50
3. Elite enemy variant system
4. Monster camp generation

### Phase 4: Polish & Balance
1. NPC personality/dialog variety
2. Trade rate balancing
3. Camp respawn tuning
4. Loot table refinement

---

## Design Philosophy

### Why This Works

1. **Renewable Resources:** Iron → rust creates sustainable loop, not one-time mining
2. **Risk/Reward:** Dangerous Undervoid = valuable resources = better defenses
3. **Social Gameplay:** NPCs add personality, not just machines
4. **Strategic Depth:**
   - Which NPC to trade with?
   - What items to offer?
   - When to upgrade base?
   - Where to build (Sky Ruins vs surface)?
4. **Time Management:** Can't rush everything, must plan ahead
5. **Escape Valve:** Sky Ruins offer safety for those who want it

### Differences from Minecraft

| Minecraft | The Long Nights |
|-----------|-----------------|
| Dig down, find iron | Explore dangerous Undervoid floating islands |
| Punch furnace, wait | Trade with NPC, return tomorrow |
| Iron is permanent | Iron degrades to rust after 3 blood moons |
| No social element | NPCs with preferences and personality |
| Static caves | Floating islands, void hazards |

---

## Future Expansion Ideas

### NPC Variety
- Alchemist (potions/buffs)
- Enchanter (weapon powers)
- Builder (constructs structures for you)
- Farmer (grows crops while you adventure)

### Undervoid Features
- Void tendrils (tentacles from below)
- Gravity anomalies (jump higher/slower fall)
- Echo system (sound attracts enemies)
- Treasure islands (tiny 3x3 with chest, risky grapple)

### Advanced Trading
- NPC reputation system (better rates with friendship)
- Bulk orders (trade 100 rust at once for bonus)
- Rush orders (pay extra for same-day completion)
- NPC quests (special requests for unique rewards)

---

## Technical Notes

### Terrain Generation
- Generator code: `blocky_game/generator/generator.gd`
- Need to add island size variation based on Y level
- Bedrock coating layer at Y -400 to -390
- Consider performance impact of larger islands

### NPC System
- Base: testNPC entity
- Add right-click detection via raycast
- Store active trades in WorldManager save data
- Time completion checks on noon trigger

### Resource Degradation
- Track blood moon count per iron block
- After 3rd blood moon: replace iron block with rust_block
- Store in WorldManager block metadata

---

*"The Undervoid awaits... and so do the NPCs who can help you survive it."*
