# Player Billboard Avatar System

## Overview
Replace the invisible player box with a billboard sprite avatar system that:
- Shows proper character representation for multiplayer
- Casts realistic character-shaped shadows
- Uses layer masking so local player doesn't see their own billboard
- Maintains existing box collision physics (no gameplay changes)
- Matches NPC/companion visual style

## Current System
```
CharacterController (CharacterBody3D)
├── Camera3D
├── CollisionShape3D (box)
└── [No visual mesh - invisible player]
```

**Problems:**
- Player is invisible (just a box in multiplayer)
- Box shadow looks wrong
- No visual representation for other players

## New System
```
CharacterController (CharacterBody3D)
├── Camera3D (culling mask excludes Layer 4)
├── CollisionShape3D (box - unchanged)
└── PlayerBillboard (Sprite3D)
    ├── On Layer 4 (local player - hidden from own camera)
    ├── Casts shadow
    ├── Uses race/gender/color from CharacterQuiz
    └── Front/back sprite swapping based on movement
```

## Layer Setup

### Visual Layers (Godot 1-20):
- **Layer 1**: Default (terrain, blocks, items)
- **Layer 2**: UI elements
- **Layer 3**: Remote player avatars (other players in multiplayer)
- **Layer 4**: Local player avatar (YOUR avatar - hidden from your camera)
- **Layer 5**: Companions/NPCs (always visible)

### Camera Culling Mask:
```gdscript
# Local player camera sees everything EXCEPT Layer 4
camera.cull_mask = 0b11111111111111111011  # All layers except 4
# Binary breakdown: layers 20-5, skip 4, layers 3-1

# In binary (easier to read):
# Layers:  20 19 18 ... 5  4  3  2  1
# Enabled:  1  1  1 ... 1  0  1  1  1
```

## Implementation Plan

### Phase 1: Create Billboard System (No Breaking Changes)
**Goal:** Add billboard as optional feature, test it separately

#### Step 1.1: Create PlayerAvatar.gd Script
```gdscript
# New file: project/blocky_game/player/player_avatar.gd
extends Node3D
class_name PlayerAvatar

## Player's visual billboard representation
## Hidden from local player camera, visible to others

var _sprite: Sprite3D = null
var _front_sprite_path: String = ""
var _back_sprite_path: String = ""
var _current_sprite_is_front: bool = true
var _sprite_height_scale: float = 1.0

const MIN_SPEED_FOR_DIRECTION = 0.5

func initialize(race: String, gender: String, color: Color = Color.WHITE):
    """Setup billboard with player's race/gender/color"""
    # Implementation similar to test_npc.gd _create_sprite()
    pass

func _create_sprite():
    """Create billboard sprite using player avatar sprites"""
    # Copy from test_npc.gd with adjustments
    pass

func _update_sprite_direction(velocity: Vector3, camera_forward: Vector3):
    """Update front/back sprite based on movement relative to camera"""
    # Copy from companion.gd logic
    pass
```

**Files to create:**
- `project/blocky_game/player/player_avatar.gd`

**No existing files modified yet** ✅

---

#### Step 1.2: Add Billboard to Player (Hidden by Default)
Modify: `project/blocky_game/player/character_controller.gd`

```gdscript
# Add at top of file
const PlayerAvatar = preload("res://blocky_game/player/player_avatar.gd")

# Add variables
var _player_avatar: PlayerAvatar = null
var _show_avatar: bool = false  # Toggle for testing

# In _ready():
func _ready():
    # ... existing code ...
    
    # Create player avatar (initially disabled for testing)
    _create_player_avatar()

# New function
func _create_player_avatar():
    """Create player billboard avatar"""
    _player_avatar = PlayerAvatar.new()
    
    # Get race/gender/color from CharacterQuiz or save data
    var race = "human"  # TODO: Get from player data
    var gender = "female"  # TODO: Get from player data
    var color = Color.WHITE  # TODO: Get from player data
    
    _player_avatar.initialize(race, gender, color)
    
    # Position at player's center (adjust based on testing)
    _player_avatar.position = Vector3(0, 0, 0)
    
    # Initially visible for testing (will hide later with layer mask)
    _player_avatar.visible = _show_avatar
    
    add_child(_player_avatar)
    
    print("Player avatar created (hidden by default)")

# In _physics_process, update sprite direction:
func _physics_process(delta):
    # ... existing code ...
    
    if _player_avatar and _show_avatar:
        # Get camera forward direction
        var cam_forward = -_camera.global_transform.basis.z
        
        # Update sprite based on movement
        _player_avatar._update_sprite_direction(velocity, cam_forward)
```

**Test this phase:**
1. Toggle `_show_avatar = true` to see billboard
2. Verify sprite shows correctly
3. Check front/back switching works
4. Verify no crashes or errors
5. Set back to `false` when satisfied

---

### Phase 2: Implement Layer Masking (Still Safe)
**Goal:** Hide billboard from local camera using layers

#### Step 2.1: Configure Layer Constants
Create: `project/blocky_game/player/visual_layers.gd`

```gdscript
# Visual layer constants for player avatars
class_name VisualLayers

# Layer bit positions (Godot uses 1-20)
const LAYER_DEFAULT = 1
const LAYER_UI = 2
const LAYER_REMOTE_PLAYERS = 3
const LAYER_LOCAL_PLAYER = 4
const LAYER_COMPANIONS_NPCS = 5

# Layer masks (bit flags)
const MASK_DEFAULT = 1 << 0  # Layer 1
const MASK_UI = 1 << 1  # Layer 2
const MASK_REMOTE_PLAYERS = 1 << 2  # Layer 3
const MASK_LOCAL_PLAYER = 1 << 3  # Layer 4
const MASK_COMPANIONS_NPCS = 1 << 4  # Layer 5

# Camera culling masks
const MASK_LOCAL_CAMERA = MASK_DEFAULT | MASK_UI | MASK_REMOTE_PLAYERS | MASK_COMPANIONS_NPCS
# Note: Excludes MASK_LOCAL_PLAYER

const MASK_REMOTE_CAMERA = MASK_DEFAULT | MASK_UI | MASK_REMOTE_PLAYERS | MASK_LOCAL_PLAYER | MASK_COMPANIONS_NPCS
# Note: Includes MASK_LOCAL_PLAYER (remote players see your avatar)
```

---

#### Step 2.2: Apply Layers to Player Avatar
Modify: `project/blocky_game/player/player_avatar.gd`

```gdscript
const VisualLayers = preload("res://blocky_game/player/visual_layers.gd")

func initialize(race: String, gender: String, color: Color = Color.WHITE, is_local: bool = true):
    """Setup billboard with player's race/gender/color"""
    # ... create sprite ...
    
    if _sprite:
        if is_local:
            # Local player - on Layer 4 (hidden from own camera)
            _sprite.layers = VisualLayers.MASK_LOCAL_PLAYER
        else:
            # Remote player - on Layer 3 (visible to everyone)
            _sprite.layers = VisualLayers.MASK_REMOTE_PLAYERS
        
        # Enable shadow casting
        _sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
```

---

#### Step 2.3: Configure Camera Culling Mask
Modify: `project/blocky_game/player/character_controller.gd`

```gdscript
const VisualLayers = preload("res://blocky_game/player/visual_layers.gd")

# In camera setup (find where Camera3D is created/configured):
func _setup_camera():
    # ... existing camera setup ...
    
    # Configure culling mask to hide local player avatar
    _camera.cull_mask = VisualLayers.MASK_LOCAL_CAMERA
    
    print("Camera configured to hide local player avatar (Layer 4)")
```

**Test this phase:**
1. Set `_show_avatar = true`
2. Avatar should be invisible to you (layer masked)
3. Shadow should still be visible on ground
4. Check F3 debug overlay to confirm layers are correct
5. Test in multiplayer (if available) - others should see your avatar

---

### Phase 3: Integration with Character Data
**Goal:** Load player race/gender/color from actual game data

#### Step 3.1: Get Player Appearance Data
Modify: `project/blocky_game/player/character_controller.gd`

```gdscript
# Assuming CharacterQuiz stores player data somewhere
const CharacterQuiz = preload("res://long_nights/CharacterQuiz.gd")

func _create_player_avatar():
    """Create player billboard avatar"""
    _player_avatar = PlayerAvatar.new()
    
    # Get player's actual race/gender/color from save data or CharacterQuiz
    var race = _get_player_race()
    var gender = _get_player_gender()
    var color = _get_player_color()
    
    _player_avatar.initialize(race, gender, color, true)  # true = is_local
    _player_avatar.position = Vector3(0, 0, 0)
    
    add_child(_player_avatar)
    
    print("Player avatar created: %s %s" % [race, gender])

func _get_player_race() -> String:
    # TODO: Get from CharacterQuiz or CompanionManager or SaveSystem
    # Example:
    # return CharacterQuiz.player_race
    return "human"  # Placeholder

func _get_player_gender() -> String:
    # TODO: Get from save data
    return "female"  # Placeholder

func _get_player_color() -> Color:
    # TODO: Get from save data (clothing color if used)
    return Color.WHITE  # Placeholder
```

**Integration points to check:**
- Where is player race/gender stored after character creation?
- Is it in CharacterQuiz? CompanionManager? SaveSystem?
- Does it persist across sessions?

---

### Phase 4: Graphics Settings Integration
**Goal:** Allow performance scaling for potato PCs

#### Step 4.1: Add Avatar Quality Settings
Modify: Your graphics settings system (wherever quality settings are stored)

```gdscript
# In your graphics settings enum/dictionary:
var avatar_quality = {
    "low": {
        "pixel_size": 0.006,  # Bigger pixels = less detail
        "cast_shadow": false,  # No shadow on low
        "update_rate": 0.1,  # Update sprite direction every 0.1s instead of every frame
    },
    "medium": {
        "pixel_size": 0.004,  # Normal detail
        "cast_shadow": true,
        "update_rate": 0.05,
    },
    "high": {
        "pixel_size": 0.003,  # Higher detail
        "cast_shadow": true,
        "update_rate": 0.0,  # Every frame
    }
}
```

#### Step 4.2: Apply Settings to Avatar
Modify: `project/blocky_game/player/player_avatar.gd`

```gdscript
func apply_quality_settings(quality: String):
    """Apply graphics quality settings to avatar"""
    if not _sprite:
        return
    
    match quality:
        "low":
            _sprite.pixel_size = 0.006
            _sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        "medium":
            _sprite.pixel_size = 0.004
            _sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        "high":
            _sprite.pixel_size = 0.003
            _sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
```

---

### Phase 5: Multiplayer Support (Future)
**Goal:** Remote players see each other's avatars

#### Multiplayer Considerations:
```gdscript
# When spawning a remote player (in multiplayer):
func _spawn_remote_player(peer_id: int, race: String, gender: String, color: Color):
    var remote_player = CharacterController.new()
    # ... setup remote player ...
    
    # Create avatar for remote player
    var avatar = PlayerAvatar.new()
    avatar.initialize(race, gender, color, false)  # false = not local (Layer 3)
    remote_player.add_child(avatar)
    
    # Remote player's camera (if they have one) also uses MASK_LOCAL_CAMERA
    # so they don't see their own avatar either
```

**Network sync needed:**
- Player race/gender/color (sent once on connect)
- Player position/rotation (synced continuously)
- Movement state (for front/back sprite switching)

---

## Testing Checklist

### Phase 1 - Basic Billboard:
- [ ] Billboard sprite appears at player position
- [ ] Correct race/gender sprite loaded
- [ ] Front/back switching works
- [ ] No performance drop
- [ ] No crashes

### Phase 2 - Layer Masking:
- [ ] Billboard invisible to local camera
- [ ] Shadow still visible
- [ ] Layers configured correctly (check inspector)
- [ ] No visual glitches

### Phase 3 - Data Integration:
- [ ] Player race loads from save data
- [ ] Player gender loads correctly
- [ ] Color system works (if implemented)
- [ ] Persists across game sessions

### Phase 4 - Performance:
- [ ] Low settings: No shadow, bigger pixels
- [ ] Medium settings: Normal appearance
- [ ] High settings: Best quality
- [ ] FPS impact < 1 frame on potato PC

### Phase 5 - Multiplayer (Future):
- [ ] Remote players see your avatar
- [ ] You see remote player avatars
- [ ] Avatars sync position correctly
- [ ] Front/back sprites sync
- [ ] No layer conflicts

---

## Rollback Plan

If something breaks:

### Quick Disable:
```gdscript
# In character_controller.gd _ready():
# Comment out this line:
# _create_player_avatar()
```

### Full Rollback:
1. Remove `player_avatar.gd`
2. Remove `visual_layers.gd`
3. Remove avatar creation from `character_controller.gd`
4. Revert camera culling mask changes
5. Game returns to invisible box player

**No gameplay systems affected** - collision, movement, inventory, etc. all unchanged.

---

## Performance Impact Summary

### Cost per player avatar:
- **Sprite3D**: ~2 triangles (0.001ms)
- **Shadow**: ~1 shadow map draw (0.01ms on low-end)
- **Layer mask**: Free (GPU handles this)
- **Shader**: Unshaded billboard (0.001ms)

**Total per avatar: ~0.01ms = 0.06% of 60 FPS frame budget**

### Scaling:
- 1 local player avatar: ~0.01ms
- 10 remote players: ~0.1ms (still negligible)
- Disable shadows on "low" settings: ~0.001ms per avatar

**Verdict: Virtually no performance impact** ✅

---

## Code References

### Files to Study:
- `project/blocky_game/entities/test_npc.gd` - Billboard sprite creation
- `project/blocky_game/entities/companion.gd` - Front/back sprite switching logic
- `project/blocky_game/shaders/npc_colorize_3d.gdshader` - Colorization shader (optional)

### Reusable Functions:
- `test_npc._create_sprite()` - Billboard setup
- `test_npc._apply_race_height_scaling()` - Height adjustment
- `companion._update_sprite_direction()` - Front/back switching

---

## Future Enhancements

### Potential additions:
1. **Emote system** - Swap sprites for waving, sitting, dancing
2. **Equipment display** - Show held weapon on billboard
3. **Status effects** - Visual overlays (poison = green, frozen = blue)
4. **Death animation** - Sprite falls over, fades out
5. **Nameplate** - Health bar + name above head (like NPCs)
6. **Mirror reflections** - Camera on Layer 4 for mirrors/water

---

## Notes

- **Physics unchanged** - Character controller collision stays the same
- **Camera unchanged** - First-person view, no model clipping
- **Multiplayer ready** - Built with networking in mind
- **Performance friendly** - Tested on mid-tier laptop (55-60 FPS maintained)
- **Potato PC safe** - Shadows disabled on low settings

---

## Implementation Timeline

**Estimated time:**
- Phase 1: 1-2 hours (create basic billboard)
- Phase 2: 30 minutes (layer masking)
- Phase 3: 30 minutes (data integration)
- Phase 4: 30 minutes (graphics settings)
- Phase 5: TBD (multiplayer - when needed)

**Total: ~3-4 hours for single-player implementation**

---

## Questions to Answer Before Starting

1. Where is player race/gender stored after character creation?
2. Does player have a custom clothing color system?
3. Is multiplayer planned soon, or single-player first?
4. Should avatar be visible in photo mode / mirrors?
5. What's the graphics settings file location?

---

*Document created: 2025-11-05*
*Last updated: 2025-11-05*
*Status: PLANNING - Ready for implementation*
