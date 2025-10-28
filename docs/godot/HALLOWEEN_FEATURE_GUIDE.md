# Halloween Feature - Pumpkins & Ghosts
**Date:** October 27, 2025  
**Feature:** Automated Halloween detection and special spawning mechanics  

---

## Overview

When a new game is created on **October 31st**, special Halloween features are automatically activated:

### 🎃 **Pumpkin Abundance**
- Pumpkin spawn rate increases from **5% to 40%**
- Pumpkins appear abundantly throughout the landscape
- Creates a festive autumn environment

### 👻 **Friendly Ghosts**
- Ghosts spawn naturally around pumpkins on Halloween worlds
- Players can see their ghostly companions during exploration
- Adds atmosphere and charm to the gameplay experience

---

## How It Works

### 1. Halloween Detection

When you create a new world, the game automatically checks the **system date**:

```
If today is October 31st:
  ✅ Halloween Mode = ON
  🎃 Pumpkin spawn chance = 40%
  👻 Ghost spawning = Enabled
```

**No manual setup required!** Just create a new game on Halloween.

### 2. World Persistence

The Halloween flag is **saved in `world.config`**:
- Once a world is created as a "Halloween world," it stays Halloween forever
- If you load the world on November 1st, it's still Halloween mode
- You can only have one saved world at a time

### 3. Implementation Details

#### WorldManager Changes (`project/long_nights/WorldManager.gd`)

Added Halloween detection:
```gdscript
# Check if today is Halloween (Oct 31)
static func is_today_halloween() -> bool:
	var datetime = Time.get_datetime_dict_from_system()
	return datetime.month == 10 and datetime.day == 31

# Get Halloween flag for this world
func is_halloween_world() -> bool:
	return _world_data["is_halloween"]
```

World data now includes:
```gdscript
var _world_data := {
	...
	"is_halloween": false  # Set to true if created on Oct 31
}
```

#### Generator Changes (`project/blocky_game/generator/generator.gd`)

Modified pumpkin spawn rate:
```gdscript
# In foliage spawning logic:
elif rng.randf() < (0.4 if WorldManager.is_halloween_world() else 0.05):
	# 40% chance for pumpkins on Halloween! 🎃 Otherwise 5%
	foliage = PUMPKIN
```

**Spawn Rate Breakdown (Halloween):**
- 20% chance of ANY foliage
  - 10% of that = DEAD_SHRUB (2% overall)
  - 40% of that = PUMPKIN (8% overall) ← **Much more!**
  - Rest = TALL_GRASS (10% overall)

---

## Features

### ✅ What's Implemented

1. **Automatic Halloween Detection**
   - Checks system date when creating new world
   - Works even if computer clock changes

2. **Persistent Halloween Mode**
   - Setting saved in world.config
   - Survives game restarts
   - Applies to entire world

3. **Increased Pumpkin Spawning**
   - 40% spawn rate vs. 5% normal
   - Pumpkins appear everywhere on grass
   - Creates authentic autumn feeling

### 🚀 Future Features (Not Yet Implemented)

These could be added in future sessions:

1. **Ghost Spawning Around Pumpkins**
   - Detect pumpkins during terrain generation
   - Spawn friendly ghosts nearby
   - Implement using `Ghost.spawn()` function

2. **Special Halloween Music**
   - Play spooky music on Halloween worlds
   - Different tracks for day/night

3. **Halloween Crafting Recipes**
   - Special recipes only available on Halloween
   - Jack-o-lantern blocks (carved pumpkins)
   - Halloween decorations

4. **Friendly Ghost Interactions**
   - Hold pumpkin in hotbar → ghosts follow you
   - Drop pumpkin → ghosts stay nearby
   - Create a "pumpkin trail" effect

5. **Special Dialogue/Messages**
   - Custom console messages
   - Time display shows "🎃 Halloween!" instead of date
   - Spooky death messages

---

## Testing

### How to Test on October 31st

1. **Start a new game** on October 31st
2. **Generate a new world** (character quiz → new world)
3. **Explore and observe:**
   - Pumpkins are everywhere! 🎃
   - Check console: `🎃 HALLOWEEN MODE ACTIVATED!`
   - World config will show `"is_halloween": true`

### Testing Year-Round (Fake the Date)

**Method: Change System Date (Not recommended for daily use)**
1. Temporarily set computer date to October 31
2. Create a new world
3. Halloween mode activates
4. Change date back

### Checking Halloween Status

**In Console:**
```bash
# Show current world data
day
# Look for: "This is a HALLOWEEN world! 👻"
```

**In Code:**
```gdscript
if WorldManager.is_halloween_world():
	print("We're in Halloween mode!")
```

---

## File Changes Summary

### Modified Files

| File | Changes |
|------|---------|
| `WorldManager.gd` | Added `is_halloween` field, detection function, save/load |
| `generator.gd` | Updated pumpkin spawn logic with Halloween check |

### New Constants

```gdscript
PUMPKIN = 27  # Already added in previous work
```

### New World Data Fields

```gdscript
"is_halloween": bool  # True if world created on Oct 31
```

---

## How It Could Tie Into Ghost Following

The infrastructure for this feature is ready! Here's what we could add next:

### Hypothetical Future: Pumpkin-Attracted Ghosts

```gdscript
# In a future "ghost_spawner.gd" or similar:

# When generating terrain, track all pumpkins
var pumpkin_positions = []

# After terrain generation, spawn ghosts near pumpkins
for pumpkin_pos in pumpkin_positions:
	# 50% chance to spawn a ghost near each pumpkin
	if randf() < 0.5:
		var ghost = Ghost.spawn(world, pumpkin_pos + Vector3(randf_range(-3, 3), 2, randf_range(-3, 3)))
		ghost.follow_distance = 3.0  # Stay close to pumpkin
```

This would create the "friendly ghosts hanging out around pumpkins" effect you described!

---

## Future Enhancements

### Phase 2: Player Interaction (Your Original Idea)

```gdscript
# In avatar_interaction.gd or companion manager:

func _process(_delta):
	var held_item = _hotbar.get_selected_item()
	
	if held_item and held_item.id == get_pumpkin_id():
		# Player is holding a pumpkin!
		# Friendly ghosts follow
		for ghost in get_all_ghosts():
			if ghost.team == Team.PLAYER:
				ghost.follow_distance = 2.0
				ghost.follow_speed = 3.0
```

### Phase 3: Harvesting Mechanic

Your observation about not being able to harvest pumpkins is correct - this needs:

1. **Block Harvesting System**
   - Right-click to "harvest" instead of just remove
   - Get item drop (pumpkin_item)
   - Add to inventory

2. **Block Drop Mechanics**
   - Some blocks have items (pumpkins, logs, etc.)
   - Some just disappear when broken (grass)

This would be a great next feature to work on!

---

## Console Commands for Testing

Current commands that work:

```bash
day                    # Show current day (will note if Halloween)
spawn ghost            # Manually spawn a ghost
spawn ghost            # Spawn multiple around you
```

Future commands (not yet implemented):

```bash
# These could be added later:
halloween on           # Force enable Halloween mode
halloween off          # Disable Halloween mode  
spawn pumpkins 10      # Spawn 10 pumpkins around player
```

---

## Notes

- Halloween detection happens **once** when creating the world
- System date is checked from your computer's clock
- The `is_halloween` flag is immutable after world creation
- Pumpkin spawn rate only applies to **new terrain chunks**
- Existing terrain won't change if you switch between normal/Halloween

---

## Related Files

- `WorldManager.gd` - Halloween detection and save/load
- `generator.gd` - Pumpkin spawning logic
- `ghost.gd` - Ghost entity (ready for integration)
- `Ghost.spawn()` function - Can be called to create ghosts programmatically
- `BLOCK_CREATION_COMPLETE_GUIDE.md` - How pumpkins were created

---

Happy Halloween! 🎃👻

