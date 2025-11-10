# Camera Modes - Character Viewing & Photo Mode

This document describes the camera modes available for viewing your character and taking screenshots.

## Overview

The Long Nights includes two special camera modes that let you view your character from third-person perspective:
- **charview** - Automatic 8-second orbit around your character
- **photo** - Manual camera control for screenshots

Both modes make your billboard avatar visible (normally shadow-only in first-person) and hide the collision box mesh for clean viewing.

---

## charview - Character View Orbit

Automatically orbits the camera 360° around your character over 8 seconds, giving you a full view of your avatar.

### Usage
```
charview
```

### Features
- **Automatic Rotation**: Camera completes one full orbit in 8 seconds
- **Front/Back Sprite Switching**: Billboard texture changes appropriately as camera moves
- **Collision Box Hidden**: Wireframe collision mesh is hidden during orbit
- **Auto-Return**: Camera automatically returns to first-person after completion
- **Shadow-Only Toggle**: Avatar switches from shadow-only to visible during orbit

### Technical Details
- Orbit radius: 3.0 units
- Orbit height: 1.5 units (at player's chest level)
- Rotation speed: TAU / 8.0 radians per second
- Camera looks at player center (1.0 unit above ground)

### Implementation
Located in `character_controller.gd`:
- `start_camera_orbit()` - Begins the orbit
- `_update_camera_orbit(delta)` - Handles rotation each frame
- `stop_camera_orbit()` - Returns to first-person

---

## photo - Photo Mode

Manual camera control mode for taking screenshots with full freedom to position the camera.

### Usage
```
photo
```

### Controls
| Key | Action |
|-----|--------|
| **Arrow Keys** | Rotate camera (yaw and pitch) |
| **Q** | Zoom in (decrease distance) |
| **E** | Zoom out (increase distance) |
| **F5** | Take screenshot |
| **P or ESC** | Exit photo mode |

### Features
- **Manual Camera Control**: Full freedom to rotate and zoom
- **UI Hiding**: All UI elements (hotbar, party UI, health bars) are hidden
- **Screenshot System**: Capture PNG files with timestamps
- **Smart Sprite Switching**: Front/back textures update based on camera angle
- **Companion Visibility**: Perfect for group shots with your companions
- **Collision Box Hidden**: Clean view without wireframe mesh

### Camera Limits
- **Distance**: 1.0 to 10.0 units
- **Pitch**: -89° to +89° (prevents gimbal lock)
- **Yaw**: Unlimited rotation

### Camera Speeds
- Rotation: 2.0 radians per second
- Zoom: 2.0 units per second
- Movement: 5.0 units per second

### Screenshot System
Screenshots are saved to:
```
user://screenshots/screenshot_YYYYMMDD_HHMMSS.png
```

The console displays the full path after each screenshot:
```
📸 Screenshot saved: user://screenshots/screenshot_20251110_143522.png
   Location: /home/username/.local/share/godot/app_userdata/TheLongNights/screenshots/screenshot_20251110_143522.png
```

Screenshots include:
- Full viewport resolution
- No UI elements (clean shots)
- Your character and any nearby companions
- Current lighting and sky

### Technical Details

#### Starting Photo Mode
```gdscript
func start_photo_mode():
    _photo_mode = true
    _photo_camera_yaw = 0.0
    _photo_camera_pitch = -20.0 * (PI / 180.0)  # Start looking down slightly
    _photo_camera_distance = 3.0
    _hide_collision_box_mesh(true)
    _player_avatar.set_shadow_only_mode(false)
    input_enabled = false
    _set_ui_visible(false)
```

#### Camera Positioning
The camera position is calculated using spherical coordinates:
```gdscript
var cam_x = cos(_photo_camera_yaw) * cos(_photo_camera_pitch) * _photo_camera_distance
var cam_y = sin(_photo_camera_pitch) * _photo_camera_distance + 1.0
var cam_z = sin(_photo_camera_yaw) * cos(_photo_camera_pitch) * _photo_camera_distance
```

Camera always looks at player center (1.0 unit above ground):
```gdscript
var player_center_global = global_position + Vector3(0, 1.0, 0)
_head.look_at(player_center_global, Vector3.UP)
```

#### Sprite Direction Update
The billboard front/back texture is updated based on camera position:
```gdscript
var player_forward = -global_transform.basis.z
var cam_direction = (_head.global_position - global_position).normalized()
var dot = player_forward.normalized().dot(cam_direction.normalized())
_player_avatar.force_sprite_direction(dot > 0)
```

### Implementation
Located in `character_controller.gd`:
- `start_photo_mode()` - Enters photo mode
- `_update_photo_mode(delta)` - Processes input and updates camera
- `stop_photo_mode()` - Exits and restores first-person
- `_take_screenshot()` - Captures and saves screenshot
- `_set_ui_visible(bool)` - Shows/hides UI elements

---

## Avatar System Integration

Both camera modes rely on the player avatar system implemented in `player_avatar.gd`:

### Shadow-Only Mode
In normal first-person gameplay, the player avatar uses shadow-only rendering to avoid cluttering the view:
```gdscript
sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
```

### Visible Mode
During camera modes, the avatar becomes fully visible:
```gdscript
sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
```

### Sprite Direction
The avatar uses race/gender-specific sprite sheets with front and back textures:
```gdscript
# Front view (when camera is in front)
sprite.texture = load("res://assets/art/player_avatars/%s/%s_front.png" % [race, gender])

# Back view (when camera is behind)
sprite.texture = load("res://assets/art/player_avatars/%s/%s_back.png" % [race, gender])
```

### Billboard Configuration
- **Type**: `BILLBOARD_FIXED_Y` - Stays upright, rotates horizontally only
- **Double-sided**: Ensures sprite is visible from any angle
- **Pixel size**: 0.004 for proper scale
- **Height scaling**: Race-specific (goblin 0.75x, dwarf 0.8x, human 1.0x, elf 1.15x)

---

## Common Use Cases

### Taking Character Portraits
1. Enter photo mode: `photo`
2. Use arrow keys to find a flattering angle
3. Zoom in with Q for a close-up
4. Press F5 to capture
5. Exit with P or ESC

### Group Shots with Companions
1. Position yourself near companions
2. Enter photo mode: `photo`
3. Zoom out with E to frame everyone
4. Adjust angle with arrow keys
5. Capture with F5

### Quick Character Reference
1. Use charview for a quick 360° view
2. Camera automatically orbits and returns
3. See front and back of your character

### Outfit Checks
1. After changing equipment/colors
2. Use charview for automatic rotation
3. Or use photo mode for specific angles

---

## Troubleshooting

### Avatar Not Visible
- Ensure you completed the character quiz (sets race/gender/role)
- Check that avatar sprites exist in `assets/art/player_avatars/`
- Verify `PlayerData.race` and `PlayerData.gender` are set

### UI Still Visible in Photo Mode
- UI hiding targets specific node names (HotBar, PartyUI)
- Check if your UI nodes match expected names
- Modify `_set_ui_visible()` to include additional UI elements

### Screenshots Not Saving
- Check console for error messages
- Verify write permissions to user data directory
- Screenshots folder is created automatically
- Path shown in console after each capture

### Camera Clipping Through Terrain
- Photo mode doesn't have collision detection
- Manually adjust camera position if it clips
- Stay in open areas for best results

---

## Future Enhancements

Potential improvements for camera modes:

- **Camera smoothing**: Ease-in/ease-out for more cinematic orbits
- **Pause time**: Freeze game state during photo mode
- **Filters/effects**: Post-processing options for screenshots
- **Pose system**: Let player trigger animation poses
- **Camera collision**: Prevent camera from clipping through blocks
- **Save camera presets**: Store favorite camera angles
- **Time of day control**: Adjust lighting for perfect shots
- **Companion poses**: Have companions face camera
- **Screenshot gallery**: In-game viewer for saved screenshots
- **Share system**: Upload screenshots to community gallery

---

## Related Documentation

- [Player Avatar System](./PLAYER_AVATAR_SYSTEM.md) - Billboard sprite implementation
- [Character Quiz](./CHARACTER_QUIZ.md) - Race/gender selection system
- [Console Commands](./CONSOLE_COMMANDS.md) - Complete command reference
- [Shadow System](./SHADOW_SYSTEM.md) - Shadow-only rendering details

---

## Code References

### Main Files
- `project/blocky_game/player/character_controller.gd` - Camera mode implementations
- `project/blocky_game/player/player_avatar.gd` - Avatar billboard system
- `project/long_nights/GameConsole.gd` - Console command registration

### Key Functions
```gdscript
# Character orbit
character_controller.start_camera_orbit()
character_controller.stop_camera_orbit()
character_controller._update_camera_orbit(delta)

# Photo mode
character_controller.start_photo_mode()
character_controller.stop_photo_mode()
character_controller._update_photo_mode(delta)
character_controller._take_screenshot()
character_controller._set_ui_visible(visible)

# Avatar control
player_avatar.set_shadow_only_mode(enabled)
player_avatar.force_sprite_direction(show_front)
player_avatar.update_sprite_direction(velocity, cam_forward)
```

---

Last updated: November 10, 2025
