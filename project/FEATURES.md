# The Long Nights - Feature Documentation

## Cooking System

### Overview
The cooking system allows players to combine raw food items to create cooked meals with better healing properties.

### Usage
1. **Open Cooking Interface**: Type `cooking` in the console (~ or F1)
2. **Select Ingredients**: Click on food items from the left panel to add them to ingredient slots
3. **Adjust Quantities**: Click the same item multiple times to cycle count (1→2→3→4→5→1)
4. **Remove Ingredients**: Click on an ingredient slot to remove it
5. **Cook**: Click the "🔥 Cook!" button to combine ingredients

### Getting Food Items
- **Grass Mining**: Mining grass blocks has a chance to drop:
  - Wheat seeds (1-4, common)
  - Berries (1-3, uncommon)
  - Eggs (1-3, rare)
  - Rabbit (1, very rare)
- **Console Command**: `give food` - gives 3x of each raw food type
- **Individual Items**: `give <item_name>` (e.g., `give fish`)

### Raw Food Items
- **Egg** (ID 13) - Heals 1 HP
- **Rabbit** (ID 14) - Heals 2 HP
- **Berries** (ID 15) - Heals 1 HP
- **Honey** (ID 16) - Heals 2 HP
- **Wheat Seeds** (ID 22) - Plant or cook
- **Pumpkin** (ID 24) - Heals 2 HP
- **Mushroom** (ID 25) - Heals 1 HP
- **Fish** (ID 26) - Heals 2 HP

### Recipes
Current recipes (order doesn't matter):
- **Grilled Fish** (ID 27): 1 Fish → Heals 4 HP
- **Berry Honey Snack** (ID 28): 1 Berries + 1 Honey → Heals 3 HP

### Food Consumption
1. Place food in hotbar (1-5 keys)
2. Select the hotbar slot
3. **Left-click** to consume
4. Cannot eat at full HP

### Technical Notes
- Recipe system: `project/blocky_game/cooking/recipes.gd`
- Cooking UI: `project/blocky_game/gui/CookingModal.gd`
- Item database: `project/blocky_game/items/item_db.gd`

---

## NPC System (Test NPCs)

### Overview
Spawn wandering NPCs with customizable race, gender, color, and name. These are test NPCs that don't persist between saves.

### Usage
Console command:
```
npc <race> <gender> <color> <name>
```

**Example:**
```
npc human female green Angelica
npc elf male orange Jerrod
npc dwarf female red Katrin
npc goblin male purple Zikk
```

### Parameters

#### Race (affects stats, speed, height)
- **Human**: Balanced stats, normal height, 0.85× speed
- **Elf**: Lower HP, higher damage, taller (1.15×), fastest (1.0× speed)
- **Dwarf**: Highest HP, lower damage, shorter (0.8×), slower (0.7× speed)
- **Goblin**: Lowest HP, highest damage, shortest (0.75×), slower (0.7× speed)

#### Gender
- **male** / **female**: Determines sprite appearance

#### Color
Available colors (tints clothing):
- red, green, blue, yellow
- orange, purple, pink, cyan
- white, black, gray/grey, brown

**Note**: Color tinting works best on white/light-colored areas of sprites. For best results, create NPC sprites with white clothing in `project/assets/art/npc_sprites/` folder.

#### Name
Any name you want to give the NPC (single word or use quotes for multi-word names)

### Sprite System

#### Sprite Locations (Priority Order)
1. **NPC Sprites** (recommended): `project/assets/art/npc_sprites/`
   - Make clothing areas white for best color tinting
   - Front: `{race}_{gender}.png`
   - Back: `{race}_{gender}_back.png`
   
2. **Player Avatars** (fallback): `project/assets/art/player_avatars/`
   - Uses existing player sprites if NPC sprites don't exist
   - Front: `{race}_{gender}.png`
   - Back: `{race}_{gender}_back.png`

#### Sprite Behavior
- **Billboard**: Always faces camera but stays upright
- **Direction Switching**: Shows back sprite when moving away from player, front sprite when moving toward player
- **Size**: Matches companion size (pixel_size = 0.004)
- **Height Scaling**: Automatically applied based on race

### AI Behavior
- **Wander**: Picks random direction every 2-5 seconds
- **Idle**: 30% chance to stop and idle for 2 seconds
- **Speed**: Based on race multiplier
- **Team**: Neutral (doesn't attack or get attacked)

### Technical Details
- Script: `project/blocky_game/entities/test_npc.gd`
- Extends: `GroundEntity` (uses terrain collision and gravity)
- Base stats from: `entities.json` companion data
- Speed multiplier from: `CharacterQuiz.get_race_speed_multiplier()`

### Limitations (Test NPCs)
- ❌ No persistence (despawn on game reload)
- ❌ No interaction/dialogue
- ❌ No inventory
- ❌ No combat
- ✅ Simple wandering AI
- ✅ Health bar and name display
- ✅ Proper collision and ground detection

### Future Plans
These test NPCs serve as a foundation for:
- Merchant NPCs
- Quest givers
- Companion recruitment
- Village inhabitants
- Job assignment system (cooking services, crafting, etc.)

---

## Additional Notes

### Console Access
- Press **~** (tilde) or **F1** to open console
- Type `help` to see all available commands
- Use **Up/Down arrows** to navigate command history

### Related Systems
- **Inventory System**: Handles food storage and hotbar
- **Item Database**: Defines all items including food
- **CharacterQuiz**: Provides race stats and speed multipliers
- **GroundEntity**: Base class for entities with terrain collision
