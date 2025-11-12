# The Long Nights - Code Architecture Documentation

## Overview

**The Long Nights** is a voxel-based survival RPG built in Godot 4.5 with deep procedural generation, companion AI, time progression, combat, and extensive crafting/building systems. The game features a unique narrative centered around deep underground mining that has broken gravity, with fallen civilizations discoverable in the depths.

**Engine**: Godot 4.5
**Physics**: Jolt Physics
**Main Scene**: `res://blocky_game/main.tscn`
**Multiplayer**: Supported via ENet networking

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Game Entry Points](#game-entry-points)
3. [Major Game Systems](#major-game-systems)
4. [Key Files and Scripts](#key-files-and-scripts)
5. [Data Flow and System Interactions](#data-flow-and-system-interactions)
6. [Architecture Patterns](#architecture-patterns)
7. [Unique Features](#unique-features)

---

## Project Structure

```
/home/user/theLongNights-godot/
├── project/                          # Main Godot project directory
│   ├── blocky_game/                  # Core game implementation
│   │   ├── main.gd                   # Main menu and game launcher
│   │   ├── blocky_game.gd            # Game coordinator
│   │   ├── generator/                # World generation
│   │   ├── player/                   # Player controller and avatar
│   │   ├── entities/                 # NPCs, enemies, animals
│   │   ├── items/                    # Item system (50+ items)
│   │   ├── blocks/                   # Block type definitions
│   │   ├── ruins/                    # Structure generation
│   │   ├── gui/                      # User interface
│   │   └── cooking/                  # Cooking recipes
│   ├── long_nights/                  # Autoload singletons (global systems)
│   │   ├── TimeManager.gd            # Time and calendar
│   │   ├── WorldManager.gd           # Save/load system
│   │   ├── EnemySpawner.gd           # Enemy spawning
│   │   ├── CompanionManager.gd       # Companion persistence
│   │   ├── Powers.gd                 # Skyshard power system
│   │   └── [other managers]
│   ├── assets/                       # Game assets
│   │   ├── art/                      # Sprites and textures
│   │   ├── data/                     # JSON configuration
│   │   └── sounds/                   # Audio files
│   ├── addons/                       # Third-party addons
│   │   └── zylann.voxel/             # Voxel engine
│   └── common/                       # Shared utilities
└── docs/                             # Documentation
```

---

## Game Entry Points

### Main Menu Flow (`blocky_game/main.gd`)

The main menu provides three pathways into the game:

1. **New Game** → Character Quiz → World Creation → Game Start
2. **Continue Game** → Load World + Character Data → Game Start
3. **Multiplayer** → Host Server or Connect to Client

### Character Creation System

**Location**: `blocky_game/player/CharacterQuiz.gd`

The character quiz presents 4 personality questions that determine:
- **Role**: Warrior, Ranger, Healer, or Wizard
- **Race**: Human, Elf, Dwarf, or Goblin
- **Gender**: Male or Female

These choices affect:
- Player base stats
- Companion type
- Starting equipment
- Visual appearance

### Game Initialization (`blocky_game/blocky_game.gd`)

The main game coordinator initializes all systems in `_ready()`:

```gdscript
1. Set network mode (singleplayer/client/host)
2. Initialize voxel terrain with multiplayer sync
3. Set up day/night cycle and time systems
4. Find safe spawn position
5. Spawn player character
6. Spawn companion with AI
7. Initialize all subsystems:
   - Enemy spawner
   - Animal spawner
   - Ruin spawners (surface + underground)
   - UI systems (hotbar, party, time display, console)
   - Seasonal systems
   - Home base manager
8. Load saved game state if continuing
```

---

## Major Game Systems

### 1. World & Terrain System

#### Voxel Terrain

**Primary File**: `blocky_game/generator/generator.gd`

The game uses the Godot Voxel addon for procedural terrain generation:

- **Seed-based generation**: Same seed produces identical worlds
- **Heightmap noise**: Controls surface elevation
- **Multi-layer generation**: Surface, caves, underground zones
- **60+ block types**: Dirt, grass, stone, ores, water, rails, etc.

#### Block System

**Primary File**: `blocky_game/blocks/blocks.gd`

Centralized block registry with:
- Block ID mapping
- Rotation types: None, Axial, Y-rotation, Custom
- Transparency handling
- Seasonal texture variants (spring, summer, autumn, winter)
- Hardness values for mining

#### World Layer Structure

```
Y > 0:      Surface (grass, trees, structures)
Y = 0-10:   Ground level
Y < -10:    Underground (caves, ores)
Y < -150:   Undervoid zone (special gravity)
Y = -490:   City ruins layer
Y = -510:   Rust hills terrain
```

**Key Methods**:
- `generator.gd::generate_block()`: Determines block type at position
- `blocks.gd::get_block_data()`: Retrieves block properties
- `VoxelTool.set_voxel()`: Modifies terrain

---

### 2. Player System

#### Character Controller

**Primary File**: `blocky_game/player/character_controller.gd` (1,200+ lines)

Handles all player movement and physics:

**Key Features**:
- First-person movement with `VoxelBoxMover`
- Depth-based gravity reduction (mining lore mechanic)
- HP system: 100 HP base, 1 HP regen per 3 minutes
- Defense stat reduces incoming damage
- Combat with d20 roll-to-hit system
- Photo mode with pose cycling (Press P)

**Key Methods**:
- `_physics_process()`: Movement and gravity
- `handle_movement()`: WASD controls
- `handle_jump()`: Jump logic
- `take_damage()`: Damage and death handling
- `toggle_photo_mode()`: Screenshot mode

#### Avatar Interaction

**Primary File**: `blocky_game/player/avatar_interaction.gd` (2,000+ lines)

Manages all player interactions with the world:

**Key Features**:
- Block breaking with mining power calculation
- Block placement and terrain modification
- Item usage from hotbar (9 slots)
- Food consumption and healing
- Ranged item support (rockets, grappling, magic)
- Creative mode toggle
- Entity interaction caching (performance optimization)

**Key Methods**:
- `_physics_process()`: Raycast for block targeting
- `break_block()`: Mining logic with break time calculation
- `place_block()`: Block placement validation
- `use_item()`: Item activation
- `handle_hotbar_input()`: Keys 1-9 for item selection

#### Player Avatar

**Primary File**: `blocky_game/player/player_avatar.gd`

Visual representation system:
- Billboard sprite rendering
- Race/gender-specific sprite sheets
- Animations: front, back, jumping, running
- Direction switching based on movement

---

### 3. Companion System

**Primary File**: `blocky_game/entities/companion.gd` (1,800+ lines)

Advanced AI-controlled ally that follows and assists the player.

#### AI States

- **IDLE**: Standing at position
- **FOLLOWING**: Tracking player within follow distance
- **ATTACKING**: Engaging hostile entities

#### Behavior Modes

Selectable by player to customize companion behavior:

- **Normal**: Default following (6 blocks away, 10 block attack range)
- **Aggressive**: Closer following (4 blocks), larger attack range (15 blocks)
- **Defensive**: Further following (8 blocks), smaller attack range (6 blocks)
- **Guard**: Stays at designated position

#### Title System

Dynamic titles based on **Role + Equipment + Behavior**:

Examples:
- Warrior + Sword + Aggressive = "Berserker"
- Ranger + Crossbow + Normal = "Sniper"
- Healer + Any + Defensive = "Medic"
- Wizard + Fire Staff + Aggressive = "Pyromancer"

Titles grant stat bonuses and special abilities.

#### Key Features

- Auto-attacks what player attacks
- Weapon loadout from `CompanionManager`
- Skyshard powers support
- **Hunting mode**: Wanders and gathers items
- Auto-eat from player's inventory
- Teleports if too far from player (>50 blocks)
- Sprite direction switching

#### Key Methods

- `_physics_process()`: AI state machine update
- `follow_player()`: Pathfinding to player
- `attack_entity()`: Combat logic
- `update_title()`: Calculate synergy title
- `start_hunting()`: Enter hunting mode

---

### 4. Entity & Combat System

#### EntityBase

**Primary File**: `blocky_game/entities/entity_base.gd`

Base class for all living entities (enemies, animals, NPCs).

**Core Stats**:
- HP (health points)
- Attack damage
- Defense (reduces incoming damage)
- Movement speed

**Teams**:
- Neutral (animals)
- Player (player + companion)
- Enemy (hostile entities)

**Combat System**:

```gdscript
1. Attacker rolls d20 (must roll ≥10 to hit)
2. If hit: Calculate damage = max(1, damage - damage * (defense/100))
3. Apply Skyshard powers if equipped
4. Target takes damage → flash red, blood VFX
5. If HP ≤ 0: Die and drop loot
```

**Key Methods**:
- `take_damage(amount)`: Damage handling
- `die()`: Death logic and loot drops
- `attack(target)`: Perform attack with d20 roll

#### Enemy Types

All located in `blocky_game/entities/`:

**Ground Enemies**:
- **Goblin Grunt** (`goblin_grunt.gd`): Basic melee enemy
- **Troglodyte** (`troglodyte.gd`): Cave dweller
- **Rat** (`rat.gd`): Weak, fast
- **Rust Golem** (`rust_golem.gd`): Strong, slow, rust hills
- **Abyss Golem** (`abyss_golem.gd`): Deep underground

**Flying Enemies**:
- **Ghost** (`ghost.gd`): Phases through terrain
- **Sky Golem** (`sky_golem.gd`): Aerial patrol

**Animals** (Neutral):
- Rabbit, Fish, Cat, Grey Cat, Bluejay, Swallow

#### Enemy Spawner

**Primary File**: `long_nights/EnemySpawner.gd`

Controls when and where enemies appear:

**Spawn Logic**:
- Time-based: More enemies at night
- **Blood Moon events**: 7th day, 9PM-2AM (massive spawn increase)
- Distance-based around player
- Difficulty scaling by week (+30% per week)
- Depth-based enemy types (Depths spawner for underground)

**Key Methods**:
- `_on_hour_changed()`: Hourly spawn check
- `spawn_enemies_near_player()`: Position calculation
- `get_spawn_count()`: Difficulty scaling

---

### 5. Item System

**Primary File**: `blocky_game/items/item_db.gd`

Database of 50+ items organized by category.

#### Item Categories

**Weapons**:
- Rocket Launcher, Grappling Hook, Fire Staff, Ice Bow
- Throwing Knives, Crossbow, Sword, Spear
- Stone Hammer, Machete, Tree Feller

**Tools**:
- Torch (light source)
- Portal Compass (navigation)
- Light Orb (throwable light)

**Food (Raw)**:
- Egg, Rabbit, Berries, Honey, Fish, Mushroom, Pumpkin, Wheat Seeds

**Food (Cooked)**:
- Grilled Fish (+15 HP)
- Berry Honey Snack (+20 HP)
- Egg Mushroom Omelette (+25 HP)
- Pumpkin Pie (+30 HP)
- Roasted Rabbit (+35 HP)
- Fish Mushroom Stew (+40 HP)
- Hunter's Feast (+50 HP)
- Super Stew (+60 HP)

**Materials**:
- Stone Ore, Coal, Iron Ore, Gold Ore
- Skyshard (rare, grants powers)

#### Item Behavior Pattern

Each item is a script with:
- `use()` method defining behavior
- Sprite for UI display
- Damage/healing values
- Special effects

**Example**: `items/rocket/rocket.gd`
```gdscript
func use(character_controller, avatar_interaction):
    # Spawn rocket projectile
    # Apply damage on impact
    # Create explosion VFX
```

---

### 6. Cooking System

**Primary File**: `blocky_game/gui/CookingModal.gd`

Recipe-based cooking interface.

**How It Works**:
1. Access via console command: `cooking`
2. Select recipe from list
3. Check if ingredients in inventory
4. Combine items → Create cooked food (better healing)

**Recipe Storage**: `blocky_game/cooking/recipes.gd`

Example recipe:
```gdscript
{
    "name": "Pumpkin Pie",
    "ingredients": ["pumpkin", "egg", "honey"],
    "result": "pumpkin_pie"
}
```

---

### 7. Powers System

**Primary File**: `long_nights/Powers.gd`

Skyshard-based power system with two types:

#### Hotbar Powers (Active - Triggered on Attack)

- **Meteor Strike**: Swarm of 5 meteors in X pattern
- **Lightning Chain**: Arcs between nearby enemies
- **Life Steal**: Heal for damage dealt
- **Ice Burst**: AOE freeze effect
- **Poison Cloud**: DOT area
- **Knife Volley**: Multi-projectile attack
- **Wind Dash**: Speed boost after attack
- **Return**: Boomerang effect on thrown items

#### Equip Powers (Passive)

- **Stone Skin**: 1.5x defense multiplier
- **Moon Jump**: 3x jump height
- **Flame Aura**: Burn nearby enemies continuously
- **Glide**: Slow fall + air control

**Activation**: Equipped via item slots, power strength scales with stack count.

**Key Methods**:
- `execute_hotbar_power()`: Trigger active power
- `apply_equip_powers()`: Update passive effects

---

### 8. Time & Day/Night System

#### TimeManager

**Primary File**: `long_nights/TimeManager.gd`

Manages in-game time progression:

**Time Scale**:
- 75 real seconds = 1 in-game hour
- 30 real minutes = 1 in-game day
- 3.5 real hours = 1 in-game week

**Systems**:
- 24-hour day cycle
- 7-day week system
- Blood Moon on day 7, 9PM-2AM
- 4 seasons: spring, summer, autumn, winter
- Difficulty scaling: +30% per week

**Signals**:
- `hour_changed(hour)`
- `day_changed(day)`
- `week_changed(week)`
- `season_changed(season)`

**Key Methods**:
- `advance_hour()`: Increment time
- `is_blood_moon()`: Check Blood Moon active
- `get_difficulty_multiplier()`: Week-based scaling

#### DayNightCycle

**Primary File**: `long_nights/DayNightCycle.gd`

Visual representation of time:

**Features**:
- Sun/moon rotation around world
- Dynamic sky colors: dawn → day → dusk → night
- Blood Moon red lighting
- Underground time locking (always night visuals when Y < -10)
- Fog density changes by time

**Key Methods**:
- `_process()`: Update sun position and lighting
- `update_sky_color()`: Transition between times
- `apply_blood_moon_effects()`: Red tint and fog

---

### 9. Ruins & Structure System

#### Surface Ruins

**Primary File**: `blocky_game/ruins/RuinSpawner.gd`

Generates crashed ruins near spawn:

**Features**:
- Procedural structure generation
- Template library (`RuinLibrary`)
- Position registry to avoid overlaps
- Deterministic seeding

**Structures**:
- Small ruins (10x10)
- Medium ruins (20x20)
- Large ruins (30x30)

#### Undervoid System (Y < -150)

Multiple specialized spawners for deep underground:

##### UndervoidSpawner

**Primary File**: `blocky_game/ruins/UndervoidSpawner.gd`

**Void Fortresses**:
- Spawn at Y -450 to -500
- Purple beacon lights (permanent light sources)
- Ancient structures from fallen civilization

**City Building Ring**:
- 7 buildings around each fortress
- Creates abandoned city aesthetic

##### City Building System

**Primary File**: `blocky_game/ruins/undervoid_city_building.gd`

**Building Templates**:
1. Small Dwelling (10x10x15)
2. Warehouse (20x15x20)
3. Tall Tower (15x15x40)
4. Cylindrical Building (diameter 20, height 30)

**Spawn Logic**:
- Y -490 layer
- 10% chance per chunk
- Foundation platforms on rust hills
- Deterministic seeding for consistency

##### Structures

**Primary File**: `blocky_game/ruins/undervoid_structures.gd`

**Structure Types**:
- Rusted Shrine
- Mechanical Outpost
- Mining Camp
- Foundry Complex
- Void Observatory

---

### 10. Save System

The game uses a multi-file save system with JSON serialization.

#### WorldManager

**Primary File**: `long_nights/WorldManager.gd`

**Save Location**: `user://save/world.config`

**Saved Data**:
- World seed
- Player position (x, y, z)
- Game time (hours, days, weeks, season)
- Blood Moon count
- Halloween flag
- Inventory data (serialized)
- Ruin registry (spawned structures)
- Home base data

**Backup System**: `user://backups/world_backup_[timestamp]/`

**Key Methods**:
- `save_world()`: Write all data to JSON
- `load_world()`: Read and restore game state
- `create_backup()`: Copy save to backup folder

#### CompanionManager

**Primary File**: `long_nights/CompanionManager.gd`

**Save Location**: `user://companion_data.json`

**Saved Data**:
- Race, role, gender, name
- Equipment (weapon, accessory)
- Position (x, y, z)
- Behavior mode
- Guard position
- Title and emoji

**Key Methods**:
- `save_to_file()`: Write companion data
- `load_from_file()`: Restore companion state

#### PlayerData

**Primary File**: `long_nights/PlayerData.gd`

**Save Location**: `user://player_data.json`

**Saved Data**:
- Role (Warrior/Ranger/Healer/Wizard)
- Race (Human/Elf/Dwarf/Goblin)
- Gender (Male/Female)
- Name

Created from `CharacterQuiz` results.

---

### 11. UI Systems

#### Hotbar

**Primary File**: `blocky_game/gui/hotbar/hotbar.gd`

**Features**:
- 9 slots mapped to keys 1-9
- Shows item sprites and stack counts
- Drag-and-drop from inventory
- Selected slot highlight

**Key Methods**:
- `update_slot(index, item)`: Refresh display
- `select_slot(index)`: Change active item

#### Inventory

**Primary File**: `blocky_game/gui/inventory/inventory.gd`

**Features**:
- Grid-based item storage
- Stack management (up to 99 per slot)
- Equipment slots for companion
- Serialization for saving
- Drag-and-drop interface

**Key Methods**:
- `add_item(item_name, count)`: Add to inventory
- `remove_item(item_name, count)`: Remove from inventory
- `serialize()`: Convert to JSON for saving
- `deserialize(data)`: Load from JSON

#### Party UI

**Primary File**: `long_nights/PartyUI.gd`

Displays party member status:

**Shows**:
- Player and companion portraits
- HP bars with current/max
- Status effects
- Behavior mode indicators
- Title displays

**Updates in real-time** via signals from entities.

#### Time Display

**Primary File**: `long_nights/TimeDisplay.gd`

Shows current game time:
- **Format**: HH:MM (e.g., "14:30")
- **Day name**: "Day 1", "Day 2", etc.
- **Week number**: "Week 1", "Week 2", etc.

Connected to `TimeManager.hour_changed` signal.

#### Game Console

**Primary File**: `long_nights/GameConsole.gd`

Debug console with commands (press `` ` `` to open):

**Common Commands**:
- `give <item>`: Add items to inventory
- `cooking`: Open cooking UI
- `npc <race> <gender> <color> <name>`: Spawn test NPC
- `hunt <hours>`: Send companion hunting
- `tp <x> <y> <z>`: Teleport player
- `time <hour>`: Set time of day
- `day <num>`: Set day number
- `save`/`load`: Manual save/load
- `seed`: Show world seed

**Key Methods**:
- `execute_command(command_string)`: Parse and run command

---

### 12. Special Systems

#### Hunting System

**Primary File**: `long_nights/HuntingSystem.gd`

Send companion to gather resources:

**How It Works**:
1. Player uses console: `hunt 5` (hunt for 5 in-game hours)
2. Companion enters hunting state
3. Every in-game hour: Find 1-3 items based on race
4. Auto-returns to player with loot

**Race-based Loot Tables**:
- **Goblin**: Ores (stone, coal, iron, gold)
- **Elf**: Berries, honey, wheat
- **Dwarf**: Stone, iron, coal
- **Human**: Balanced mix

**Key Methods**:
- `start_hunt(hours)`: Begin hunting
- `_on_hour_changed()`: Check for loot drops
- `end_hunt()`: Return companion

#### Seasonal Texture System

**Primary File**: `long_nights/SeasonalTextureSystem.gd`

Changes textures based on season:

**Affected Blocks**:
- Grass (green in spring/summer, brown in autumn, white in winter)
- Leaves (green → yellow/red → bare)
- Water (blue → icy)

**Affected Sprites**:
- Companion appearance changes per season

#### Winter Ice System

**Primary File**: `long_nights/WinterIceSystem.gd`

Freezes water in winter season:

**How It Works**:
1. When season changes to winter
2. Scan for water blocks
3. Replace with ice blocks
4. When season ends, revert to water

#### Lamp Manager

**Primary File**: `long_nights/LampManager.gd`

Tracks placed light sources:

**Features**:
- Stores lamp positions
- Saves/loads lamp data
- Updates lighting when lamps placed/removed
- Optimizes light calculations

#### Home Base Manager

**Primary File**: `blocky_game/home_base_manager.gd`

Protected spawn area:

**Features**:
- Prevents enemy spawns near home
- Building area marking
- Teleport points
- Safe zone for new players

#### Dialogue System

**Primary File**: `long_nights/DialogueManager.gd`

JSON-based conversation trees:

**Features**:
- Branching dialogues
- Companion introductions
- Quest dialogue (future)
- Choice-based responses

**Dialogue Files**: `assets/data/dialogues/*.json`

---

## Key Files and Scripts

### Autoload Singletons (Global Access)

All located in `long_nights/` and accessible globally via their script names:

| Script | Purpose | Key Responsibilities |
|--------|---------|---------------------|
| `TimeManager.gd` | Time and calendar | Hour/day/week progression, Blood Moon, seasons |
| `WorldManager.gd` | Save/load system | World persistence, backups |
| `PlayerData.gd` | Character data | Role, race, gender storage |
| `CompanionManager.gd` | Companion config | Equipment, behavior, persistence |
| `EnemySpawner.gd` | Enemy spawning | Time-based spawning, difficulty scaling |
| `Powers.gd` | Skyshard powers | Hotbar and equip power execution |
| `HuntingSystem.gd` | Companion hunting | Resource gathering, loot tables |
| `LampManager.gd` | Light sources | Lamp tracking and lighting |
| `HomeBaseManager.gd` | Protected area | Spawn safety, teleports |
| `WinterIceSystem.gd` | Seasonal freezing | Water → ice conversion |
| `DialogueManager.gd` | Conversations | NPC dialogue trees |
| `MusicManager.gd` | Background music | Track switching, volume |
| `GraphicsSettings.gd` | Visual quality | Quality presets |
| `PerformanceMonitor.gd` | Optimization | FPS tracking, profiling |
| `GrassShaderController.gd` | Wind effects | Grass animation |
| `PartyUI.gd` | Party display | HP bars, status |
| `TimeDisplay.gd` | Time UI | Clock display |
| `GameConsole.gd` | Debug console | Command execution |

### Core Game Scripts

| File Path | Lines | Purpose |
|-----------|-------|---------|
| `blocky_game/main.gd` | ~500 | Main menu, game launcher |
| `blocky_game/blocky_game.gd` | ~1,500 | Game coordinator, system initializer |
| `blocky_game/player/character_controller.gd` | 1,200+ | Player movement, physics, combat |
| `blocky_game/player/avatar_interaction.gd` | 2,000+ | Block interaction, item usage |
| `blocky_game/entities/companion.gd` | 1,800+ | Companion AI, behavior modes |
| `blocky_game/entities/entity_base.gd` | ~400 | Entity combat foundation |
| `blocky_game/generator/generator.gd` | ~1,000 | World terrain generation |
| `blocky_game/blocks/blocks.gd` | ~800 | Block type registry |
| `blocky_game/items/item_db.gd` | ~600 | Item database |

### Data Files (JSON)

Located in `assets/data/`:

- `recipes.json`: Cooking recipes
- `blueprints.json`: Building templates
- `plans.json`: Construction plans
- `personalityQuiz.json`: Character creation quiz
- `dialogues/*.json`: Conversation trees

---

## Data Flow and System Interactions

### Game Loop Flow

```
┌─────────────┐
│  Main Menu  │
└──────┬──────┘
       │
       ├─► New Game ──► Character Quiz ──► World Creation
       │
       ├─► Continue ──► Load Save Data
       │
       └─► Multiplayer ──► Host/Join Server
                │
                ▼
        ┌───────────────┐
        │  BlockyGame   │
        │   ._ready()   │
        └───────┬───────┘
                │
                ├─► Spawn Player at saved/spawn position
                ├─► Initialize Terrain Generation
                ├─► Add DayNightCycle (connects to TimeManager)
                ├─► Add EnemySpawner (connects to TimeManager)
                ├─► Spawn Companion (AI follows player)
                ├─► Add UI Systems (PartyUI, TimeDisplay, Console)
                ├─► Add Ruins Systems (RuinSpawner, UndervoidSpawner)
                └─► Load Saved Inventory/Progress
                        │
                        ▼
                ┌──────────────┐
                │  Game Loop   │
                └──────────────┘
```

### Every Frame Update

```
Player Input
    ├─► CharacterController._physics_process()
    │       ├─► handle_movement() (WASD)
    │       ├─► handle_jump() (Space)
    │       └─► apply_gravity()
    │
    ├─► AvatarInteraction._physics_process()
    │       ├─► raycast_block_target() (crosshair)
    │       ├─► break_block() (Left Click)
    │       ├─► place_block() (Right Click)
    │       └─► use_item() (Hotbar keys)
    │
    └─► Camera3D
            ├─► mouse_motion (rotation)
            └─► toggle_photo_mode() (P key)

Entity Updates (all entities)
    ├─► Companion._physics_process()
    │       ├─► AI state machine (IDLE/FOLLOWING/ATTACKING)
    │       ├─► pathfind_to_player()
    │       └─► attack_nearby_enemies()
    │
    └─► Enemy._physics_process()
            ├─► move_towards_player()
            └─► attack_if_in_range()

Visual Updates
    └─► DayNightCycle._process()
            ├─► rotate_sun() (based on TimeManager)
            ├─► update_sky_color()
            └─► adjust_fog_density()
```

### Every In-Game Hour (75 real seconds)

```
TimeManager.advance_hour()
    │
    ├─► Emit signal: hour_changed(hour)
    │
    ├─── Connected Systems ───┐
    │                          │
    ├─► HuntingSystem._on_hour_changed()
    │       └─► If hunting: find_loot()
    │
    ├─► EnemySpawner._on_hour_changed()
    │       ├─► calculate_spawn_count() (time, difficulty)
    │       └─► spawn_enemies_near_player()
    │
    ├─► DayNightCycle._on_hour_changed()
    │       └─► update_sun_position()
    │
    └─► TimeDisplay._on_hour_changed()
            └─► update_clock_text()

If new day:
    ├─► Emit signal: day_changed(day)
    ├─► Check for Blood Moon (day 7)
    └─► Update UI day display

If new week:
    ├─► Emit signal: week_changed(week)
    └─► Increase difficulty multiplier
```

### Combat Flow

```
Attacker attacks Target
    │
    ├─► EntityBase.attack(target)
    │       │
    │       ├─► Roll d20 (need ≥10 to hit)
    │       │
    │       ├─── If HIT ───►
    │       │               │
    │       │               ├─► Calculate damage
    │       │               │   = base_damage - (base_damage * target.defense/100)
    │       │               │
    │       │               ├─► Apply Skyshard powers (if equipped)
    │       │               │       ├─► Meteor Strike
    │       │               │       ├─► Lightning Chain
    │       │               │       └─► Life Steal (heal attacker)
    │       │               │
    │       │               └─► target.take_damage(final_damage)
    │       │
    │       └─── If MISS ───► Display "MISS" text
    │
    └─► Target.take_damage(amount)
            │
            ├─► HP -= amount
            ├─► Flash red sprite
            ├─► Spawn blood VFX
            │
            └─── If HP ≤ 0 ───►
                                │
                                └─► die()
                                        ├─► Play death animation
                                        ├─► Drop loot items
                                        └─► queue_free()
```

### Terrain Modification Flow

```
Player aims at block + clicks
    │
    └─► AvatarInteraction.break_block(pos)
            │
            ├─── Validation ───┐
            │                   │
            │   ├─► Check distance ≤ 5 blocks
            │   ├─► Check block is breakable
            │   └─► Check mining power sufficient
            │
            ├─► Calculate break_time = hardness / mining_power
            │
            ├─── Mining Progress ───┐
            │                        │
            │   ├─► Show progress particles
            │   └─► Wait for break_time
            │
            ├─── When Complete ───►
            │                       │
            │   ├─► VoxelTool.set_voxel(pos, AIR)
            │   ├─► Emit "block_broken" signal
            │   ├─► Drop block as item (if not creative)
            │   └─► Update terrain mesh
            │
            └─► Inventory.add_item(block_name, 1)
```

### Save/Load Flow

```
Player quits game OR auto-save triggers
    │
    └─── Save Process ───┐
                          │
                          ├─► WorldManager.save_world()
                          │       ├─► Gather world data (seed, time, position)
                          │       ├─► Serialize inventory
                          │       ├─► Serialize ruin registry
                          │       └─► Write to user://save/world.config
                          │
                          ├─► CompanionManager.save_to_file()
                          │       ├─► Gather companion data (race, equipment, position)
                          │       └─► Write to user://companion_data.json
                          │
                          └─► PlayerData.save_to_file()
                                  ├─► Gather player data (role, race, gender)
                                  └─► Write to user://player_data.json

Player selects "Continue"
    │
    └─── Load Process ───┐
                          │
                          ├─► WorldManager.load_world()
                          │       ├─► Read user://save/world.config
                          │       ├─► Set world seed
                          │       ├─► Restore time (hours, days, weeks)
                          │       ├─► Restore player position
                          │       ├─► Deserialize inventory
                          │       └─► Restore ruin registry
                          │
                          ├─► CompanionManager.load_from_file()
                          │       ├─► Read user://companion_data.json
                          │       └─► Restore companion state
                          │
                          └─► PlayerData.load_from_file()
                                  ├─► Read user://player_data.json
                                  └─► Restore character data
```

---

## Architecture Patterns

### Design Patterns Used

1. **Singleton Pattern** (Autoload)
   - Global access to managers via script name
   - Example: `TimeManager.get_current_hour()`

2. **Entity-Component Pattern**
   - `EntityBase` + specialized behaviors
   - Shared combat system, unique AI per entity

3. **State Machine**
   - Companion AI states: IDLE, FOLLOWING, ATTACKING
   - Clear state transitions

4. **Registry Pattern**
   - `item_db.gd`: Central item registry
   - `blocks.gd`: Central block registry
   - `RuinRegistry`: Tracks spawned structures

5. **Observer Pattern** (Signals)
   - `TimeManager.hour_changed` → Many systems listen
   - `EntityBase.died` → UI updates, loot drops
   - Loose coupling between systems

6. **Factory Pattern**
   - Structure spawners create buildings
   - Enemy spawner creates entities
   - Centralized instantiation

7. **Serialization**
   - JSON save/load for all persistent data
   - Custom serialize/deserialize methods

### Performance Optimizations

1. **Entity Caching**
   - `avatar_interaction.gd`: Refresh entity list every 0.5s
   - Avoids expensive `get_tree().get_nodes_in_group()` every frame

2. **Particle Pooling**
   - Reuse mining particles instead of creating new ones
   - Reduces garbage collection

3. **Chunk-based Processing**
   - Only process nearby chunks for spawning/generation
   - Distance-based LOD (Level of Detail)

4. **Deterministic Seeding**
   - Same seed = identical world
   - Avoids redundant random calculations
   - Reproducible for debugging

5. **Voxel View Distance Settings**
   - Configurable render distance
   - Graphics quality presets (Low/Medium/High)

6. **Occlusion Culling**
   - Enabled in rendering settings
   - Don't render hidden voxels

7. **Jolt Physics**
   - Faster physics engine than Godot default
   - Better performance for character controller

### Code Organization Principles

**Separation of Concerns**:
- UI scripts only handle display
- Logic scripts only handle game rules
- Data scripts only handle persistence

**Modular Systems**:
- Each system is self-contained
- Clear interfaces between systems
- Easy to add/remove features

**Autoload for Globals**:
- Shared state accessible anywhere
- No need to pass references through scene tree

**Preload Pattern**:
```gdscript
const ItemScene = preload("res://items/item.tscn")
var item = ItemScene.instantiate()
```
- Faster than `load()` at runtime
- Static resource loading

**Signal-based Communication**:
- Loose coupling between systems
- Example: TimeManager emits `hour_changed`, many systems respond
- No direct dependencies

---

## Unique Features

### 1. Deep Underground Lore

**Broken Gravity Mechanic**:
- As you dig deeper (Y < -150), gravity reduces
- Lore: Ancient miners over-mined, breaking the world's gravity
- Affects player movement and jump height

**Multi-layer Underground**:
- **Caves** (Y -10 to -150): Normal underground
- **Rust Hills** (Y -510): Rusty iron terrain
- **Undervoid** (Y < -150): Broken gravity zone
- **City Ruins** (Y -490): Fallen civilization layer

**Void Fortresses**:
- Ancient structures at Y -450 to -500
- Purple beacon lights (only light sources in deep dark)
- Ring cities of 7 buildings around each fortress
- Hints at ancient civilization story

---

### 2. Companion Synergy System

**Dynamic Titles**:
Titles change based on **Role + Equipment + Behavior**:

Examples:
- Warrior + Sword + Normal = "Knight"
- Warrior + Sword + Aggressive = "Berserker"
- Ranger + Crossbow + Normal = "Sniper"
- Ranger + Crossbow + Defensive = "Scout"
- Healer + Any + Defensive = "Medic"
- Wizard + Fire Staff + Aggressive = "Pyromancer"

**Stat Bonuses**:
Each title grants unique bonuses:
- Berserker: +20% attack, -10% defense
- Medic: +50% healing, auto-revive ally
- Pyromancer: Fire damage bonus, burn effect

**Visual Feedback**:
- Title displayed in Party UI
- Emoji indicator changes
- Companion sprite may change color

---

### 3. Blood Moon Events

**Trigger**: Every 7th day, 9PM-2AM (5 in-game hours)

**Effects**:
- **Massive enemy spawn increase** (5x normal rate)
- Red lighting across entire world
- Thick red fog
- All enemy stats boosted (+50% HP, +30% damage)
- "Blood Moon Rises" UI notification

**Tracking**:
- Blood Moon count saved in world data
- Statistics for player to review

**Strategic Importance**:
- High risk, high reward (more loot)
- Forces player to prepare defenses
- Creates memorable events

---

### 4. Hunting Mechanic

**How It Works**:
1. Player opens console: `hunt 5` (hunt for 5 hours)
2. Companion enters hunting state
3. Companion wanders area, no longer following
4. Every in-game hour: Finds 1-3 items
5. Auto-returns after time expires

**Race-based Loot**:
- **Goblin**: Ores (stone, coal, iron, gold)
- **Elf**: Plants (berries, honey, wheat, mushroom)
- **Dwarf**: Minerals (stone, iron, coal)
- **Human**: Balanced mix

**Benefits**:
- Passive resource gathering
- Time-efficient (hunt while player does other tasks)
- Encourages exploration of different playstyles

---

### 5. Photo Mode

**Activation**: Press `P`

**Features**:
- Freezes game time
- Free camera movement (WASD + mouse)
- Hides UI for clean screenshots
- **Pose cycling**: Press `P` again to change character pose
- Poses: idle, jumping, waving, attacking

**Use Cases**:
- Screenshots of builds
- Documenting exploration
- Creating thumbnails/content

---

### 6. Deterministic Procedural Generation

**Seed-based**:
- World seed (integer) controls all generation
- Same seed = identical world every time

**Applies to**:
- Terrain heightmap
- Cave positions
- Ruin locations
- City building placement
- Structure spawns
- Ore distribution

**Benefits**:
- Reproducible for debugging
- Shareable worlds (share seed with friends)
- Speedrun community friendly

**Implementation**:
```gdscript
# generator.gd
var rng = RandomNumberGenerator.new()
rng.seed = world_seed
# All random calls use rng, not global randomize()
```

---

### 7. Halloween World Flag

**Trigger**: World created on October 31

**Effect**: World permanently marked as "Halloween world"

**Changes**:
- Increased pumpkin spawn rate (+300%)
- Pumpkin blocks naturally generate on surface
- Special Halloween decorations in ruins
- Does NOT change after Oct 31 (permanent for that world)

**Storage**: Saved in `world.config`

---

### 8. Underground Visual Locking

**Mechanic**: When player Y < -10 (underground):
- Time display locks to "Night"
- Sun position fixed at night angle
- Sky darkens to night colors

**Purpose**:
- Creates immersive cave atmosphere
- Visually reinforces being underground
- Actual time still progresses (enemies still spawn on schedule)

**Implementation**:
```gdscript
# DayNightCycle.gd
if player.global_position.y < -10:
    lock_to_night_visuals()
else:
    follow_actual_time()
```

---

### 9. Skyshard Power System

**Skyshard**: Rare material found deep underground

**Usage**:
1. Find Skyshard (rare drop from golems)
2. Craft power items (Fire Staff = Staff + Skyshard)
3. Equip in hotbar or equipment slot
4. Power activates automatically

**Power Types**:

**Hotbar Powers** (attack-triggered):
- Meteor Strike (5 meteors in X pattern)
- Lightning Chain (arcs to 3 enemies)
- Life Steal (heal for damage dealt)

**Equip Powers** (passive):
- Stone Skin (1.5x defense)
- Moon Jump (3x jump height)
- Glide (slow fall + air control)

**Stacking**:
- Multiple Skyshards = stronger effect
- Meteor Strike with 3 Skyshards = 15 meteors

---

### 10. Voxel Terrain Multiplayer

**Modes**:
- **Singleplayer**: Local world
- **Host**: Server + local player
- **Client**: Connect to host

**Network Features**:
- **Terrain sync**: Block changes replicate to all clients
- **Character replication**: See other players' avatars
- **Companion sync**: All companions visible
- **Combat sync**: Damage and death replicated
- **UPNP**: Automatic port forwarding

**Limitations**:
- Host must stay online
- Peer-to-peer (no dedicated server)
- Terrain saves only on host

**Implementation**: Based on Godot ENet high-level multiplayer

---

## Summary

**The Long Nights** is a complex, well-architected voxel survival RPG with:

- **Deep systems**: Companion AI, time progression, procedural generation, powers
- **Rich world**: Multi-layer underground, ruins, structures, lore
- **Polished features**: Photo mode, hunting, Blood Moons, cooking
- **Robust engineering**: Modular design, save system, performance optimizations
- **Multiplayer support**: Client/server with terrain sync

The codebase demonstrates strong software engineering:
- Clear separation of concerns
- Extensive use of signals for decoupling
- Autoload singletons for global state
- Deterministic systems for reproducibility
- Comprehensive save/load system

**Key Takeaway**: This is a production-quality game with professional-grade architecture, extensive features, and thoughtful design decisions throughout.

---

## File Reference Quick List

### Most Important Files (by lines of code and functionality)

1. **avatar_interaction.gd** (2,000+ lines): Player-world interaction
2. **companion.gd** (1,800+ lines): Companion AI
3. **blocky_game.gd** (1,500+ lines): Game coordinator
4. **character_controller.gd** (1,200+ lines): Player movement
5. **generator.gd** (1,000+ lines): World generation
6. **blocks.gd** (800+ lines): Block registry
7. **item_db.gd** (600+ lines): Item database
8. **WorldManager.gd** (500+ lines): Save/load
9. **EnemySpawner.gd** (400+ lines): Enemy spawning
10. **TimeManager.gd** (300+ lines): Time system

---

*Documentation generated: 2025-11-12*
*Game Version: Godot 4.5*
*Codebase: /home/user/theLongNights-godot*
