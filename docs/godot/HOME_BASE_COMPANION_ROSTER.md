# Home Base & Companion Roster System
**Design Document - The Long Nights**

## 🎯 Core Concept

Transform any location into a **Home Base** where inactive companions live, provide quests, and create a living hub with personality. One active companion adventures with the player, while benched companions become NPCs at home.

---

## 📋 Overview

### Key Features:
- **1 Active Companion** (current system unchanged)
- **2-4 Recruitable Companions** (stored in roster, benched at home)
- **Set Home Base Anywhere** (ruins or open ground)
- **Companion Quests & Interactions** (mini side-quests with rewards)
- **Special Home Structure** (spawns at chosen location)
- **Companion Swapping** (at home base only)

### Philosophy:
- **Depth over breadth** - One active companion, but multiple choices
- **Discovery-driven** - Find companions through gameplay
- **Strategic choices** - Bring the right companion for challenges
- **Living world** - Home feels alive with NPC companions

---

## 🏗️ PHASE 1: MVP - Core Functionality

**Goal:** Basic home base system with companion swapping

### 1.1 Set Home Base Location
**Trigger:** Player presses button while at ruin or on ground

**Implementation:**
```gdscript
# New file: HomeBaseManager.gd (AutoLoad singleton)
extends Node

var home_base_position: Vector3 = Vector3.ZERO
var has_home_base: bool = false
var home_base_ruin_id: String = ""  # If set at a ruin
var home_structure_node: Node3D = null

func set_home_base(position: Vector3, ruin_id: String = ""):
    home_base_position = position
    has_home_base = true
    home_base_ruin_id = ruin_id
    _spawn_home_structure()
    _relocate_benched_companions()
    print("🏠 Home Base established at: ", position)
    
func is_player_at_home(player_position: Vector3) -> bool:
    return has_home_base and player_position.distance_to(home_base_position) < 15.0
```

**UI Element:**
- New button in HUD when player is:
  - At a cleared/safe ruin
  - Standing on open ground for 3+ seconds
- Button text: **"⛺ Set Home Base"**
- Confirmation dialog: *"Make this your home? Your companions will gather here."*

**Save/Load:**
```gdscript
# Add to WorldManager save data:
"home_base_position": [x, y, z],
"has_home_base": true,
"home_base_ruin_id": "ruin_forest_01"
```

---

### 1.2 Spawn Home Structure (Simple)
**MVP Version:** Basic placeholder structure

**Structure Options:**
1. **Simple Tent + Campfire** (easiest, for testing)
   - Small tent mesh (or cube placeholder)
   - Campfire with particle effects
   - 2-3 log benches
   - Radius: ~10 blocks

2. **Wooden Shack** (medium complexity)
   - Simple voxel or mesh building
   - One room interior
   - Door that opens
   - Campfire outside

**Implementation:**
```gdscript
func _spawn_home_structure():
    # MVP: Simple tent scene
    const TentScene = preload("res://buildings/home_tent.tscn")
    home_structure_node = TentScene.instantiate()
    home_structure_node.global_position = home_base_position
    
    # Add to world (get reference to game node)
    var game = get_node_or_null("/root/Main/Game")
    if game:
        game.add_child(home_structure_node)
        print("🏕️ Home structure spawned")
```

**MVP Tent Scene Structure:**
```
home_tent.tscn
├─ Tent (MeshInstance3D or CSGBox3D)
├─ Campfire (with ParticleSystem)
├─ Benches (3x MeshInstance3D)
├─ CompanionSpawnPoints (Node3D markers)
│  ├─ SpawnPoint1
│  ├─ SpawnPoint2
│  └─ SpawnPoint3
└─ InteractionArea (Area3D for "Press E to manage roster")
```

---

### 1.3 Companion Roster System
**Storage:** Track all recruited companions

**CompanionManager Updates:**
```gdscript
# Add to CompanionManager.gd
class CompanionData:
    var companion_name: String = ""
    var race: String = "human"  # human, elf, dwarf, goblin, ghost
    var gender: String = "female"  # male, female (not used for ghost)
    var role: String = "healer"  # healer, tank, rogue, wizard
    var equipped_weapon_id: int = -1
    var equipped_accessory_id: int = -1
    var active_title: String = ""
    var title_emoji: String = ""
    var behavior_mode: String = "normal"
    var is_active: bool = false  # True = adventuring, False = at home

var companion_roster: Array[CompanionData] = []
var active_companion_index: int = 0

func add_to_roster(comp_data: CompanionData):
    companion_roster.append(comp_data)
    print("🎉 %s joined the roster!" % comp_data.companion_name)

func get_active_companion() -> CompanionData:
    if active_companion_index < companion_roster.size():
        return companion_roster[active_companion_index]
    return null

func get_benched_companions() -> Array:
    var benched = []
    for i in range(companion_roster.size()):
        if i != active_companion_index:
            benched.append(companion_roster[i])
    return benched
```

**Save/Load:**
```gdscript
# Add to CompanionManager.save_to_file()
var roster_data = []
for comp in companion_roster:
    roster_data.append({
        "name": comp.companion_name,
        "race": comp.race,
        "gender": comp.gender,
        "role": comp.role,
        "equipped_weapon_id": comp.equipped_weapon_id,
        "equipped_accessory_id": comp.equipped_accessory_id,
        "active_title": comp.active_title,
        "title_emoji": comp.title_emoji,
        "behavior_mode": comp.behavior_mode,
        "is_active": comp.is_active
    })

save_data["companion_roster"] = roster_data
save_data["active_companion_index"] = active_companion_index
```

---

### 1.4 Companion Swapping
**Location:** Only at home base

**UI Flow:**
1. Player approaches home base
2. Press **E** to open **"Manage Roster"** screen
3. Screen shows:
   - Active companion (highlighted green)
   - Benched companions (gray)
   - **[Swap]** button next to each benched companion

**Implementation:**
```gdscript
# In HomeBaseManager.gd
func swap_companion(new_index: int):
    if new_index == active_companion_index:
        print("⚠️ Already active!")
        return
    
    # Save current active companion's state to roster
    _save_active_companion_state()
    
    # Despawn current companion entity
    _despawn_active_companion()
    
    # Update active index
    CompanionManager.active_companion_index = new_index
    
    # Load new companion data
    _load_active_companion_data(new_index)
    
    # Respawn new companion entity
    _spawn_active_companion()
    
    print("🔄 Swapped to: %s" % CompanionManager.companion_roster[new_index].companion_name)

func _save_active_companion_state():
    var companions = get_tree().get_nodes_in_group("companions")
    if companions.size() > 0:
        var comp = companions[0]
        var data = CompanionManager.companion_roster[CompanionManager.active_companion_index]
        data.equipped_weapon_id = comp._equipped_inv_item.id if comp._equipped_inv_item else -1
        data.equipped_accessory_id = comp._equipped_accessory_item.id if comp._equipped_accessory_item else -1
        data.active_title = comp.active_title
        data.title_emoji = comp.title_emoji
        data.behavior_mode = comp.support_mode

func _despawn_active_companion():
    var companions = get_tree().get_nodes_in_group("companions")
    for comp in companions:
        comp.queue_free()

func _spawn_active_companion():
    # Call blocky_game._spawn_companion() or similar
    var game = get_node_or_null("/root/Main/Game")
    if game and game.has_method("_spawn_companion"):
        game._spawn_companion()
```

---

### 1.5 Benched Companions as NPCs
**Behavior:** Idle NPCs at home base

**Implementation:**
```gdscript
# In HomeBaseManager.gd
func _relocate_benched_companions():
    # Despawn any existing benched NPCs
    _despawn_benched_npcs()
    
    # Spawn benched companions as NPCs at home
    var benched = CompanionManager.get_benched_companions()
    var spawn_points = _get_companion_spawn_points()
    
    for i in range(min(benched.size(), spawn_points.size())):
        var comp_data = benched[i]
        var spawn_pos = spawn_points[i].global_position
        _spawn_benched_npc(comp_data, spawn_pos)

func _spawn_benched_npc(comp_data: CompanionData, position: Vector3):
    # Create simple NPC version of companion
    const CompanionNPC = preload("res://blocky_game/entities/companion_npc.gd")
    var npc = CompanionNPC.new()
    npc.companion_data = comp_data
    npc.global_position = position
    npc.add_to_group("benched_companions")
    
    # Add to world
    var game = get_node_or_null("/root/Main/Game")
    if game:
        game.add_child(npc)

func _get_companion_spawn_points() -> Array:
    if home_structure_node:
        var spawn_container = home_structure_node.get_node_or_null("CompanionSpawnPoints")
        if spawn_container:
            return spawn_container.get_children()
    return []
```

**companion_npc.gd (Simple version):**
```gdscript
extends GroundEntity
class_name CompanionNPC

var companion_data: CompanionManager.CompanionData

func _ready():
    # Load sprite based on race/gender
    var sprite_path = _get_sprite_path()
    _create_sprite(sprite_path, 0.004)
    
    # Set name label
    entity_name = companion_data.companion_name
    
    # Make stationary
    movement_speed = 0.0
    
    # Add simple idle animation (optional)

func _get_sprite_path() -> String:
    # Return sprite based on race/gender
    var base = "res://assets/art/player_avatars/"
    return base + "%s_%s.png" % [companion_data.race, companion_data.gender]
```

---

### 1.6 Roster UI Screen
**Design:** Simple list view (MVP)

**Roster UI Layout:**
```
╔═══════════════════════════════════╗
║     🏠 HOME BASE - ROSTER         ║
╠═══════════════════════════════════╣
║                                   ║
║ [✓ ACTIVE]                        ║
║ Sara the Healer (Elf Female)      ║
║ 🛡️ Paladin | ❤️ 100/100          ║
║ Weapon: Ice Bow                   ║
║ Accessory: Stone Skin Charm       ║
║                                   ║
║ ─────────────────────────────     ║
║                                   ║
║ [ ] BENCHED                       ║
║ Grok the Tank (Dwarf Male)        ║
║ 🏔️ Mountain | ❤️ 160/160         ║
║ Weapon: Stone Hammer              ║
║           [Swap Active] [Talk]    ║
║                                   ║
║ ─────────────────────────────     ║
║                                   ║
║ [ ] BENCHED                       ║
║ Lyra the Rogue (Human Female)     ║
║ 👻 Shadow Dancer | ❤️ 120/120    ║
║ Weapon: Throwing Knives           ║
║           [Swap Active] [Talk]    ║
║                                   ║
╠═══════════════════════════════════╣
║         [Close] [Save]            ║
╚═══════════════════════════════════╝
```

**Implementation:**
```gdscript
# New file: res://blocky_game/gui/roster_ui.gd
extends Control

var roster_container: VBoxContainer

func _ready():
    _create_ui()
    _populate_roster()

func _populate_roster():
    # Clear existing
    for child in roster_container.get_children():
        child.queue_free()
    
    # Active companion
    var active_data = CompanionManager.get_active_companion()
    if active_data:
        _create_companion_entry(active_data, true)
    
    # Benched companions
    var benched = CompanionManager.get_benched_companions()
    for comp_data in benched:
        _create_companion_entry(comp_data, false)

func _create_companion_entry(comp_data, is_active: bool):
    var entry = VBoxContainer.new()
    
    # Status badge
    var status_label = Label.new()
    status_label.text = "[✓ ACTIVE]" if is_active else "[ ] BENCHED"
    status_label.add_theme_color_override("font_color", Color.GREEN if is_active else Color.GRAY)
    entry.add_child(status_label)
    
    # Name + role
    var name_label = Label.new()
    name_label.text = "%s the %s (%s %s)" % [
        comp_data.companion_name,
        comp_data.role.capitalize(),
        comp_data.race.capitalize(),
        comp_data.gender.capitalize() if comp_data.race != "ghost" else ""
    ]
    entry.add_child(name_label)
    
    # Title + HP
    var stats_label = Label.new()
    var title_text = ("%s %s | " % [comp_data.title_emoji, comp_data.active_title]) if comp_data.active_title != "" else ""
    stats_label.text = title_text + "❤️ HP: ???/???"  # TODO: Get actual HP
    entry.add_child(stats_label)
    
    # Equipment
    var equip_label = Label.new()
    equip_label.text = "Weapon: %s" % _get_item_name(comp_data.equipped_weapon_id)
    entry.add_child(equip_label)
    
    # Buttons (only for benched)
    if not is_active:
        var button_box = HBoxContainer.new()
        
        var swap_btn = Button.new()
        swap_btn.text = "Swap Active"
        swap_btn.pressed.connect(_on_swap_pressed.bind(comp_data))
        button_box.add_child(swap_btn)
        
        var talk_btn = Button.new()
        talk_btn.text = "Talk"
        talk_btn.pressed.connect(_on_talk_pressed.bind(comp_data))
        button_box.add_child(talk_btn)
        
        entry.add_child(button_box)
    
    # Separator
    var separator = HSeparator.new()
    entry.add_child(separator)
    
    roster_container.add_child(entry)

func _on_swap_pressed(comp_data):
    # Find index of this companion
    var index = CompanionManager.companion_roster.find(comp_data)
    if index != -1:
        HomeBaseManager.swap_companion(index)
        _populate_roster()  # Refresh UI

func _on_talk_pressed(comp_data):
    # TODO: Open dialogue (Phase 2)
    print("💬 Talking to %s..." % comp_data.companion_name)

func _get_item_name(item_id: int) -> String:
    if item_id == -1:
        return "None"
    var item_db = get_node_or_null("/root/Main/Game/Items")
    if item_db:
        var item = item_db.get_item(item_id)
        if item:
            return item.base_info.name
    return "Unknown"
```

---

### 1.7 MVP Testing Checklist
- [ ] "Set Home Base" button appears at ruins/ground
- [ ] Home structure spawns at chosen location
- [ ] Roster saves/loads correctly
- [ ] Can swap companions at home base
- [ ] Swapped companion despawns/respawns correctly
- [ ] Benched companions appear as NPCs at home
- [ ] Equipment/titles transfer between swaps
- [ ] Roster UI displays all companions
- [ ] System persists through save/load

---

## 🎨 PHASE 2: Polish & Content

**Goal:** Make home feel alive and rewarding

### 2.1 Proper Home Structure

**Full House Design:**

**Exterior:**
- Rustic wooden lodge (10x10 blocks)
- Stone foundation + wooden walls
- Pitched roof with chimney
- Front porch with benches
- Campfire area (3x3 stone circle)
- Small garden plots (4x raised beds)
- Hitching post (for future mounts?)

**Interior - Ground Floor:**
- Entry hallway
- Common room (5x5):
  - Large table with 4 chairs
  - Fireplace with cooking pot
  - Weapon rack on wall
  - Storage chest
- Kitchen area:
  - Crafting table
  - Ingredient storage
  - Cooking station

**Interior - Upper Floor:**
- Accessed by ladder/stairs
- 4 sleeping alcoves (beds with privacy curtains)
- Personal storage chest per companion
- Window overlooking exterior
- Cozy lighting (lanterns)

**Building File Structure:**
```
home_base_lodge.tscn
├─ Structure (MeshInstance3D or CSG)
├─ Exterior
│  ├─ Campfire (ParticleSystem)
│  ├─ Benches (x3)
│  ├─ GardenPlots (x4 Node3D markers)
│  └─ CompanionWanderPoints (x8 markers)
├─ Interior_GroundFloor
│  ├─ Table + Chairs
│  ├─ Fireplace
│  ├─ WeaponRack
│  ├─ StorageChest (Area3D for interaction)
│  └─ CraftingStation
├─ Interior_UpperFloor
│  ├─ Beds (x4)
│  ├─ PersonalChests (x4)
│  └─ Ladder
└─ InteractionPoints
   ├─ RosterManagement (Area3D)
   ├─ Sleep (Area3D)
   └─ Storage (Area3D)
```

---

### 2.2 Companion AI at Home

**Behavior Patterns:**

**Time-Based Routines:**
- **Morning (6-12):** Companions at table eating, chatting
- **Afternoon (12-18):** Wandering outside, training dummy, garden
- **Evening (18-22):** Sitting by campfire, relaxing
- **Night (22-6):** In beds upstairs

**Wander Points:**
```gdscript
# In CompanionNPC
var wander_points: Array[Node3D] = []
var current_wander_target: int = 0
var wander_timer: float = 0.0
const WANDER_INTERVAL = 10.0  # Change destination every 10s

func _process(delta):
    wander_timer += delta
    if wander_timer >= WANDER_INTERVAL:
        wander_timer = 0.0
        _pick_new_wander_point()
    
    _move_to_wander_point(delta)

func _pick_new_wander_point():
    if wander_points.size() > 0:
        current_wander_target = randi() % wander_points.size()

func _move_to_wander_point(delta):
    if wander_points.size() == 0:
        return
    
    var target_pos = wander_points[current_wander_target].global_position
    var direction = (target_pos - global_position).normalized()
    var distance = global_position.distance_to(target_pos)
    
    if distance > 1.0:
        global_position += direction * 2.0 * delta  # Slow walking speed
```

**Idle Animations:**
- Look around randomly
- Sit/stand transitions
- Tool usage (when at garden/training)
- Wave at player when approached

---

### 2.3 Companion Dialogue System

**Dialogue Types:**

**1. Greeting (when approached):**
```gdscript
var greetings = [
    "Hey there! Good to see you back.",
    "Welcome home! How was the adventure?",
    "Oh, you're back! I was just thinking about you.",
]

func _on_player_nearby():
    if randf() < 0.3:  # 30% chance to greet
        show_dialogue(greetings.pick_random())
```

**2. Status Comments (contextual):**
```gdscript
# Based on player stats, time, etc.
if player_hp < player_max_hp * 0.5:
    show_dialogue("You look hurt! Rest by the fire.")

if TimeManager.get_time_of_day() == "night":
    show_dialogue("It's getting late. You should rest.")

if player_kill_count > companion_data.moralThreshold:
    show_dialogue("You've been fighting a lot... Are you okay?")
```

**3. Quest Dialogue:**
```gdscript
# Check if companion has active quest
if has_active_quest():
    var quest = get_active_quest()
    if quest.is_complete():
        show_dialogue("Oh! You brought what I needed! Thank you!")
        _give_quest_reward()
    else:
        show_dialogue("Still looking for %s? (%d/%d)" % [
            quest.item_name,
            quest.current_progress,
            quest.required_amount
        ])
```

**Dialogue UI:**
```
┌─────────────────────────────┐
│  [Avatar] Sara              │
├─────────────────────────────┤
│                             │
│ "Welcome back! I was just   │
│  thinking about you."       │
│                             │
│                             │
│   [Continue]    [Ask Quest] │
└─────────────────────────────┘
```

---

### 2.4 Companion Quest System

**Quest Structure:**
```gdscript
# In CompanionManager.CompanionData
class CompanionQuest:
    var quest_id: String = ""
    var quest_type: String = ""  # "fetch", "combat", "craft"
    var description: String = ""
    var dialogue_active: String = ""  # When quest is active
    var dialogue_complete: String = ""  # When turning in
    
    # Fetch quest fields
    var item_id: int = -1
    var item_quantity: int = 0
    var current_quantity: int = 0
    
    # Combat quest fields
    var enemy_type: String = ""
    var kill_count: int = 0
    var current_kills: int = 0
    
    # Rewards
    var reward_item_id: int = -1
    var reward_buff: Dictionary = {}  # e.g., {"max_hp": 20, "duration": 600}
    
    var is_active: bool = false
    var is_complete: bool = false

var active_quest: CompanionQuest = null
```

**Quest Examples:**

**Sara (Elf Healer) - Pumpkin Pie:**
```gdscript
{
    "quest_id": "sara_pumpkin_pie",
    "quest_type": "fetch",
    "description": "Bring Sara 5 pumpkins",
    "dialogue_active": "I'd love to bake a pumpkin pie! Could you find me 5 pumpkins?",
    "dialogue_complete": "Perfect! Here, fresh pumpkin pie. It'll boost your health!",
    "item_id": 42,  # Pumpkin item ID
    "item_quantity": 5,
    "reward_item_id": 187,  # Pumpkin pie
    "reward_buff": {
        "max_hp_bonus": 20,
        "duration": 600  # 10 minutes
    }
}
```

**Grok (Dwarf Tank) - Sparring:**
```gdscript
{
    "quest_id": "grok_sparring",
    "quest_type": "combat",
    "description": "Spar with Grok 10 times",
    "dialogue_active": "Sitting around makes me soft. Fight me! Just friendly sparring.",
    "dialogue_complete": "Ha! Good matches. Take this training token!",
    "kill_count": 10,  # Special: spar count
    "reward_item_id": 215,  # Training token
    "reward_buff": {
        "attack_bonus": 2,
        "duration": 300  # 5 minutes
    }
}
```

**Lyra (Human Rogue) - Mushroom Gathering:**
```gdscript
{
    "quest_id": "lyra_mushrooms",
    "quest_type": "fetch",
    "description": "Collect 10 mushrooms for Lyra",
    "dialogue_active": "I need mushrooms for alchemy. Find me 10?",
    "dialogue_complete": "Excellent! Here's a shadow elixir I brewed.",
    "item_id": 89,  # Mushroom
    "item_quantity": 10,
    "reward_item_id": 223,  # Shadow elixir
    "reward_buff": {
        "stealth": true,
        "speed_bonus": 1.2,
        "duration": 180  # 3 minutes
    }
}
```

**Spooky (Friendly Ghost) - Skull Collection:**
```gdscript
{
    "quest_id": "ghost_skulls",
    "quest_type": "fetch",
    "description": "Bring Spooky 3 skulls",
    "dialogue_active": "Oooo... skulls... bring me... three...",
    "dialogue_complete": "Yesss... thank you... here... spectral gift...",
    "item_id": 15,  # Skull
    "item_quantity": 3,
    "reward_item_id": 250,  # Spectral charm
    "reward_buff": {
        "ghost_sight": true,  # Can see invisible enemies
        "duration": 300
    }
}
```

**Quest Tracking:**
```gdscript
# In HomeBaseManager or CompanionManager
func check_quest_progress(companion_index: int):
    var comp = CompanionManager.companion_roster[companion_index]
    if comp.active_quest and not comp.active_quest.is_complete:
        var quest = comp.active_quest
        
        if quest.quest_type == "fetch":
            # Check player inventory for items
            var inventory = _get_player_inventory()
            var count = inventory.count_item(quest.item_id)
            quest.current_quantity = count
            
            if count >= quest.item_quantity:
                quest.is_complete = true
                print("✅ Quest complete: %s" % quest.quest_id)

func turn_in_quest(companion_index: int):
    var comp = CompanionManager.companion_roster[companion_index]
    if comp.active_quest and comp.active_quest.is_complete:
        var quest = comp.active_quest
        
        # Remove items from inventory
        if quest.quest_type == "fetch":
            var inventory = _get_player_inventory()
            inventory.remove_item(quest.item_id, quest.item_quantity)
        
        # Give reward item
        if quest.reward_item_id >= 0:
            _give_player_item(quest.reward_item_id)
        
        # Apply buff
        if quest.reward_buff.size() > 0:
            _apply_buff_to_player(quest.reward_buff)
        
        # Clear quest
        comp.active_quest = null
        print("🎁 Quest turned in: %s" % quest.quest_id)
```

---

### 2.5 Home Base Benefits

**Interaction Points:**

**1. Sleep (Instant Heal):**
```gdscript
# On bed or sleeping bag
func _on_sleep_interaction():
    var player = get_tree().get_first_node_in_group("player")
    if player:
        player.current_hp = player.max_hp
        print("💤 Slept and restored to full health!")
        # Optional: Time skip, fade effect
```

**2. Storage Chest:**
```gdscript
# Extra inventory space (separate from player inventory)
var home_storage: Array[InventoryItem] = []
const STORAGE_SIZE = 20

func open_storage_chest():
    # Show UI with storage slots
    # Allow transfer between player inventory and storage
    pass
```

**3. Cooking Station:**
```gdscript
# Enhanced recipes at home
func get_cooking_bonus() -> float:
    return 1.5  # 50% better food buffs when cooked at home
```

**4. Training Dummy:**
```gdscript
# Practice combat, test damage
func attack_training_dummy(damage: int):
    print("Training Dummy: %d damage!" % damage)
    # Show floating damage numbers
```

**5. Garden Plots:**
```gdscript
# Plant seeds, harvest over time
class GardenPlot:
    var planted_seed: int = -1  # Seed item ID
    var growth_time: float = 0.0
    var growth_required: float = 3600.0  # 1 hour real time
    var is_ready: bool = false

var garden_plots: Array[GardenPlot] = [
    GardenPlot.new(), GardenPlot.new(), 
    GardenPlot.new(), GardenPlot.new()
]

func plant_seed(plot_index: int, seed_id: int):
    garden_plots[plot_index].planted_seed = seed_id
    garden_plots[plot_index].growth_time = 0.0
    garden_plots[plot_index].is_ready = false

func _process(delta):
    for plot in garden_plots:
        if plot.planted_seed >= 0 and not plot.is_ready:
            plot.growth_time += delta
            if plot.growth_time >= plot.growth_required:
                plot.is_ready = true
                print("🌱 Garden plot ready to harvest!")
```

---

## 👥 PHASE 3: Companion Recruitment

**Goal:** Find companions through gameplay

### 3.1 Recruitable Companions

**From entities.json:**
- Human Male (Tank, Wizard, Rogue)
- Human Female (Healer, Tank, Wizard, Rogue)
- Elf Male (Rogue, Wizard)
- Elf Female (Healer, Rogue)
- Dwarf Male (Tank)
- Dwarf Female (Tank, Healer)
- Goblin Male (Rogue, Wizard)
- Goblin Female (Rogue, Wizard)
- **Ghost (Friendly)** - Special recruit!

**Recruitment Methods:**

**1. Rescue Mission (Ruin Objective):**
```gdscript
# New ruin objective type
{
    "type": "rescue",
    "description": "Rescue the lost traveler",
    "target_position": Vector3(x, y, z),
    "companion_to_recruit": {
        "race": "human",
        "gender": "male",
        "role": "tank",
        "name": "Marcus"
    }
}

# When player reaches target:
func _on_rescue_complete(companion_data):
    CompanionManager.add_to_roster(companion_data)
    DialogueManager.show_dialogue("Thank you! I'll come to your home base!")
```

**2. Random Encounter:**
```gdscript
# Rare chance when exploring
if randf() < 0.01 and not _has_pending_recruit():  # 1% per minute
    _spawn_recruitable_npc()

func _spawn_recruitable_npc():
    # Spawn NPC near player
    # Has ! marker above head
    # Dialogue: "I'm looking for a group to join..."
    # Quest: Complete task → They join roster
```

**3. Seasonal Event:**
```gdscript
# During Blood Moon
if TimeManager.is_blood_moon():
    if player_kill_count >= 100:
        # Battle-hungry companion appears
        _offer_recruitment("goblin_male", "rogue", "Grimfang")
```

**4. Achievement Unlock:**
```gdscript
# Track player achievements
if player.total_enemies_defeated >= 50:
    _unlock_companion_recruit("dwarf_male", "tank", "Thorin")

if player.total_flowers_collected >= 100:
    _unlock_companion_recruit("elf_female", "healer", "Elara")
```

**5. Friendly Ghost - Special:**
```gdscript
# Very rare spawn in ruins
# Appears as ethereal white ghost (not hostile)
# Following player, curious
# Can "tame" by giving skulls (quest)

{
    "race": "ghost",
    "gender": "",  # Not applicable
    "role": "wizard",  # Uses magic
    "name": "Spooky",
    "moralThreshold": 0,  # Ghost doesn't judge morality
    "special_abilities": ["Phase Through Walls", "Spectral Sight"]
}

# Recruitment quest:
# 1. Find friendly ghost in ruin
# 2. Ghost follows you
# 3. Bring 3 skulls to ghost
# 4. Ghost joins roster!
```

---

### 3.2 Companion Personalities

**Personality System:**
```gdscript
# In CompanionData
class PersonalityTraits:
    var chattiness: float = 0.5  # How often they talk
    var friendliness: float = 0.8  # Warm vs cold
    var humor: String = "sarcastic"  # sarcastic, cheerful, serious
    var topic_preferences: Array = ["combat", "nature", "magic"]

var personality: PersonalityTraits = PersonalityTraits.new()
```

**Race-Based Personalities:**

**Human:**
- Balanced, practical
- Talks about strategy, trade
- Moderate chattiness

**Elf:**
- Philosophical, nature-loving
- Talks about forests, seasons
- Judges violence (moralThreshold: 500)

**Dwarf:**
- Gruff, loyal
- Talks about crafting, mining
- Less chatty but warm

**Goblin:**
- Chaotic, opportunistic
- Talks about explosions, schemes
- Very chatty, dark humor

**Ghost:**
- Mysterious, otherworldly
- Talks in... broken... sentences...
- Rare speech but impactful

**Personality-Driven Dialogue:**
```gdscript
func get_contextual_dialogue() -> String:
    match personality.humor:
        "sarcastic":
            return "Oh, you're back. Thought you got lost again."
        "cheerful":
            return "Yay! You're back! Did you bring anything fun?"
        "serious":
            return "Welcome back. Report on your mission?"
    return "Hello."
```

---

### 3.3 Companion Progression (Optional)

**Level/XP System:**
```gdscript
# In CompanionData
var level: int = 1
var xp: int = 0
var xp_to_next_level: int = 100

func gain_xp(amount: int):
    xp += amount
    while xp >= xp_to_next_level:
        level_up()

func level_up():
    level += 1
    xp -= xp_to_next_level
    xp_to_next_level = int(xp_to_next_level * 1.5)
    
    # Stat increases
    max_hp += 5
    attack += 1
    
    print("🎉 %s leveled up to %d!" % [companion_name, level])
```

**XP Sources:**
- Combat with active companion: +10 XP per enemy
- Completing quests: +50 XP
- Time at home (passive): +1 XP per minute

---

## 📊 Technical Requirements

### Save/Load Data Structure
```json
{
  "home_base": {
    "has_home": true,
    "position": [100, 64, 200],
    "ruin_id": "ruin_forest_01",
    "garden_plots": [
      {"seed_id": 42, "growth_time": 1200.5, "ready": false},
      {"seed_id": -1, "growth_time": 0, "ready": false},
      {"seed_id": 15, "growth_time": 3600, "ready": true},
      {"seed_id": -1, "growth_time": 0, "ready": false}
    ]
  },
  "companion_roster": [
    {
      "name": "Sara",
      "race": "elf",
      "gender": "female",
      "role": "healer",
      "level": 5,
      "xp": 230,
      "equipped_weapon_id": 23,
      "equipped_accessory_id": 45,
      "active_title": "Paladin",
      "title_emoji": "🛡️",
      "behavior_mode": "defensive",
      "is_active": true,
      "active_quest": {
        "quest_id": "sara_pumpkin_pie",
        "current_quantity": 3,
        "is_complete": false
      },
      "personality": {
        "chattiness": 0.7,
        "friendliness": 0.9,
        "humor": "cheerful"
      }
    },
    {
      "name": "Grok",
      "race": "dwarf",
      "gender": "male",
      "role": "tank",
      "level": 3,
      "xp": 80,
      "equipped_weapon_id": 8,
      "equipped_accessory_id": 67,
      "active_title": "Mountain",
      "title_emoji": "🏔️",
      "behavior_mode": "guard",
      "is_active": false,
      "active_quest": null,
      "personality": {
        "chattiness": 0.3,
        "friendliness": 0.8,
        "humor": "serious"
      }
    }
  ],
  "active_companion_index": 0
}
```

---

## 🎮 User Experience Flow

### First Time Setup
1. Player completes quiz → Gets first companion (Sara)
2. Day 2-3: Player finds good ruin location
3. Prompt appears: **"This would make a great home base!"**
4. Player presses button → Tent/structure spawns
5. Sara automatically goes to home
6. Tutorial message: *"Visit your home base to manage your roster!"*

### Daily Loop
1. **Morning:** Visit home, check companion quests
2. **Adventure:** Take active companion on exploration
3. **Find Items:** Collect quest items while adventuring
4. **Return Home:** Turn in quests, get rewards
5. **Swap Companion:** Choose different companion for next day
6. **Rest:** Sleep at home to heal, advance time

### Recruitment Flow
1. **Discover:** Find recruitable companion in world
2. **Quest:** Complete their recruitment quest
3. **Join Roster:** They appear at home base
4. **Get to Know:** Talk, learn personality, get quests
5. **Strategic Choice:** Decide who to bring on next adventure

---

## 🚀 Implementation Priority

### MVP (Phase 1) - ~2-3 days
- [ ] HomeBaseManager singleton
- [ ] "Set Home Base" button + confirmation
- [ ] Simple tent/campfire structure
- [ ] CompanionData class + roster array
- [ ] Swap companion function
- [ ] Basic roster UI screen
- [ ] Benched companions as NPCs
- [ ] Save/load integration

### Polish (Phase 2) - ~1 week
- [ ] Full house structure (3D model or voxel)
- [ ] Companion wander AI at home
- [ ] Dialogue system
- [ ] 5-10 companion quests
- [ ] Home benefits (sleep, storage, cooking)
- [ ] Garden plot system
- [ ] Quest tracking UI

### Content (Phase 3) - ~1-2 weeks
- [ ] 8-12 recruitable companions
- [ ] Rescue mission ruin objectives
- [ ] Random encounter system
- [ ] Friendly ghost special recruitment
- [ ] Companion personality system
- [ ] Level/XP progression
- [ ] Additional quest types (combat, craft)

---

## 🎨 Art Assets Needed

### Structures
- [ ] Home tent (MVP)
- [ ] Wooden lodge building
- [ ] Campfire with particles
- [ ] Log benches (x3)
- [ ] Garden plots (x4)
- [ ] Training dummy
- [ ] Storage chest
- [ ] Cooking station
- [ ] Weapon rack

### UI Elements
- [ ] Roster screen background
- [ ] Companion portrait frames
- [ ] Quest icons (fetch, combat, craft)
- [ ] Home base map marker icon
- [ ] "Set Home Base" button icon

### VFX
- [ ] Companion swap effect (particle burst)
- [ ] Quest complete effect
- [ ] Level up effect
- [ ] Garden growth stages

---

## 🐛 Edge Cases & Considerations

### What if player sets home in dangerous area?
- Solution: Only allow home base at "safe" locations:
  - Cleared ruins (all enemies defeated)
  - Open ground away from spawn points
  - Not in water or lava

### What if player wants to move home?
- Solution: Add "Relocate Home" option (costs resources?)
- Or: Allow only once per week (in-game time)

### What if companion dies while active?
- Solution: Companion "defeated" state, not dead
- Returns to home base, injured for 1 day
- Player must continue alone or swap

### What if player has no home but finds recruitable companion?
- Solution: Companion says *"Set up a home base first, then I'll join you!"*
- Adds to "pending recruits" list
- Auto-joins roster when home is established

### Save file compatibility
- New fields have defaults
- Old saves work but start with empty roster (except quiz companion)

---

## 📝 Notes & Future Ideas

### Possible Expansions:
- **Home Upgrades:** Spend resources to add rooms, decorations
- **Companion Romance:** Relationship system with benefits
- **Companion Skills:** Unique abilities (lockpicking, herbalism)
- **Home Defense:** Raids on home base (tower defense mini-game?)
- **Multiple Homes:** Outposts across the map
- **Companion Gifts:** Give items to increase friendship
- **Photo Mode:** Take pictures of companions at home
- **Seasonal Decorations:** Home changes for holidays
- **💧 Water Crystal (Aqua Orb):** Terraforming tool for base building
  - Throwable item that absorbs water in radius when placed in lake/river
  - Stores captured water blocks (displays count: "Contains 973 water")
  - Can be placed elsewhere to release water over time
  - Creates lakes, moats, waterfalls, fountains at home base
  - Perfect for sky ruin bases - bring water up for decoration/farming
  - Could have variants: Blue (water), White (ice/snow), Red (lava?)
  - Mid-tier magic item, craftable or found in dungeons
  - Makes base building more creative and Minecraft-like

### Building & Farming Features (Core Survival Loop):
- **Farm Plots:** Plant crops near home base (wheat, carrots, pumpkins)
- **Water Irrigation:** Use water crystals or natural water for crops
- **Animal Pens:** Tame and breed animals for food/resources  
- **Storage Chests:** Keep items at home without carrying everything
- **Crafting Stations:** Enhanced workbenches, furnaces, cooking stations
- **Defensive Walls:** Build perimeter protection (especially for sky ruins!)
- **Lighting System:** Torches, lanterns to keep home safe at night
- **Tent → House Progression:** Start with tent, upgrade to cabin, then lodge

### Technical Optimizations:
- Despawn home structure when far away (save performance)
- LOD system for home building
- Async loading for companion NPC spawns
- Compress save data (binary instead of JSON?)

---

## ✅ Success Metrics

**MVP is successful if:**
- [ ] Players can set a home base
- [ ] Companions can be swapped
- [ ] System persists through saves
- [ ] No major bugs or crashes

**Phase 2 is successful if:**
- [ ] Players engage with companion quests
- [ ] Home base feels "alive" and useful
- [ ] Positive player feedback on polish

**Phase 3 is successful if:**
- [ ] Players collect multiple companions
- [ ] Companion choice affects strategy
- [ ] High replay value from different rosters

---

## 🎯 Conclusion

The Home Base & Companion Roster system transforms companion management from a technical feature into an emotional core of the game. Players form connections with multiple companions, make strategic choices, and have a place to call "home" in a dangerous world.

**Start with MVP, iterate based on feedback, and build toward the vision!** 🏡✨
