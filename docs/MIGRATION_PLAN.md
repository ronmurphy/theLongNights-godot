# The Long Nights - Migration to Voxel Module

**Date**: October 25, 2025
**Status**: Planning phase

---

## What We Did

1. ✅ Renamed old project to `theLongNights.old`
2. ✅ Copied voxelgame-master as new `theLongNights`
3. ✅ Copied `.git` folder to maintain version control
4. ✅ Copied `assets/` from old project
5. ✅ Copied `docs/` from old project
6. ✅ Copied `TimeManager.gd` and `GameManager.gd` to `project/long_nights/`

---

## Project Structure

```
theLongNights/
├── .git/                      # Version control (from old project)
├── docs/                      # Documentation (from old project)
├── project/                   # Godot project root
│   ├── assets/                # Our block textures, music, etc. (from old)
│   ├── blocky_game/           # Voxelgame's working demo (BASE)
│   ├── long_nights/           # Our custom code
│   │   ├── TimeManager.gd     # Bloodmoon system
│   │   └── GameManager.gd     # Game state management
│   └── project.godot
└── theLongNights.old/         # Backup of our failed attempt
```

---

## Requirements

### Godot Version
- **Godot 4.5** with **Voxel module** compiled in
- Uses **Jolt Physics** (specified in project.godot)

### Getting the Right Godot Build
You mentioned "we use their build of godot with that module baked in"

Options:
1. Use Zylann's pre-built Godot with Voxel module
2. Compile Godot 4.5 with the Voxel module yourself
3. Check if there's a pure GDScript version (full_gdscript branch)

---

## The Long Nights Features to Implement

### Phase 1: Core Gameplay (Keep from voxelgame)
- ✅ Voxel terrain (already works)
- ✅ Player movement (already works)
- ✅ Block breaking/placing (already works)
- ✅ Inventory system (already works)

### Phase 2: The Long Nights Systems (Add to voxelgame)

#### Time & Bloodmoon System
- [x] TimeManager already created
- [ ] Integrate TimeManager into blocky_game
- [ ] Visual sky/lighting changes for bloodmoons
- [ ] Bloodmoon countdown UI

#### Enemy System
- [ ] Billboard sprite rendering (2D sprites facing camera)
- [ ] Enemy spawning system
- [ ] Wave manager for bloodmoons
- [ ] Enemy AI (chase player, attack)
- [ ] Kill counter (for final boss twist)

#### Companion System
- [ ] NPC character that follows player
- [ ] Visual novel style dialogue UI
- [ ] Dialogue tree system
- [ ] Companion AI (follow, assist)

#### Crafting System
- [ ] Modify existing inventory to match your design
- [ ] Material selection interface
- [ ] Recipe system (simpler than Minecraft patterns)
- [ ] Workbench interaction

#### Survival Mechanics
- [ ] Food/hunger system
- [ ] Health system (integrate with existing or replace)
- [ ] Resource harvesting

#### World Features
- [ ] Sky temple generation (4 floating structures)
- [ ] Mini-boss encounters
- [ ] Special item collection (4 items → Ghost Rod)
- [ ] Ghost Rod crafting

#### Final Boss
- [ ] Ghost King summon system
- [ ] Kill counter → enemy wave spawning
- [ ] Boss arena (50-block destruction radius)
- [ ] Cinematic ending sequence

---

## Integration Strategy

### Step 1: Get it Running
1. Open project in Godot with Voxel module
2. Test `blocky_game/main.tscn`
3. Verify terrain generation works
4. Verify player controls work

### Step 2: Add Time System
1. Add TimeManager as autoload
2. Create day/night sky shader
3. Add bloodmoon visual effects
4. Test time progression

### Step 3: Remove Unwanted Features
- [ ] Remove multiplayer code (or keep for later?)
- [ ] Remove rocket launcher
- [ ] Simplify to what we need

### Step 4: Add Enemy System
- [ ] Create Enemy scene with billboard sprite
- [ ] Create WaveManager for bloodmoon spawns
- [ ] Implement basic enemy AI
- [ ] Test spawning during bloodmoon

### Step 5: Iterate from there...

---

## Questions to Answer

1. **Do you have Godot with the Voxel module?**
   - If not, we need to get it

2. **Keep multiplayer?**
   - voxelgame has multiplayer
   - Could be cool for co-op survival?

3. **Art style?**
   - Use voxelgame's blocky style?
   - Or modify for different aesthetic?

4. **Block textures?**
   - We have assets in `assets/art/blocks/`
   - Need to integrate into voxel block system

---

## Next Steps

1. **TEST**: Open the project in Godot with Voxel module
2. **RUN**: Launch `blocky_game/main.tscn`
3. **VERIFY**: Confirm everything works
4. **PLAN**: Decide what to keep/remove
5. **BUILD**: Start integrating The Long Nights features

---

## File Locations

### From Old Project (saved)
- `/home/brad/Godot/theLongNights.old/`
- TimeManager: Copied to `project/long_nights/TimeManager.gd`
- GameManager: Copied to `project/long_nights/GameManager.gd`
- Assets: Copied to `project/assets/`

### New Project
- Main scene: `project/blocky_game/main.tscn`
- Player: `project/blocky_game/player/`
- Blocks: `project/blocky_game/blocks/`
- Generator: `project/blocky_game/generator/`

---

## Success Criteria

Phase 1 Complete when:
- [x] Project opens in Godot
- [ ] Voxel terrain renders correctly
- [ ] Player can move and interact
- [ ] No face culling bugs
- [ ] Smooth performance

Then we start adding The Long Nights features!
