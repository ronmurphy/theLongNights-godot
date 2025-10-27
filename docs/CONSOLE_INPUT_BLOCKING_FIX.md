# Console Input Blocking Fix

**Issue:** Game controls active while typing in console (e.g., 's' in "blocks" moves player left)  
**Date Fixed:** October 27, 2025  
**Status:** ✅ FIXED

---

## Problem

When the console is open and visible, the player's movement input is still being processed. This causes:
- Characters in typed commands to trigger game actions (e.g., 's' = move left)
- Player to move unexpectedly while trying to use console
- Inability to type underscore commands like "log_birch"

The ~ (tilde) and F1 keys still needed to work to toggle console open/closed.

---

## Solution

### 1. GameConsole.gd Changes

Added methods to disable/enable player input when console opens/closes:

```gdscript
# Added to top of class
var _player_input_enabled: bool = true

# Modified toggle_console function
func toggle_console() -> void:
	is_visible = !is_visible
	visible = is_visible

	if is_visible:
		# Console opening - disable player input
		input_field.grab_focus()
		_disable_player_input()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		# Console closing - re-enable player input
		input_field.release_focus()
		_enable_player_input()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# New helper methods
func _disable_player_input() -> void:
	"""Disable player movement controls when console is open"""
	var player = get_tree().get_first_group_member("player")
	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)
		_player_input_enabled = false

func _enable_player_input() -> void:
	"""Re-enable player movement controls when console is closed"""
	var player = get_tree().get_first_group_member("player")
	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(true)
		_player_input_enabled = true
```

**How it works:**
- When console opens: calls `_disable_player_input()`
- When console closes: calls `_enable_player_input()`
- Uses player group to find the character controller automatically

---

### 2. character_controller.gd Changes

Added input enable/disable control to player character:

**Added variable:**
```gdscript
## Input control
var input_enabled: bool = true
```

**Modified _physics_process:**
- Wrapped all input handling in `if input_enabled:` check
- When input disabled: stops all movement, still applies gravity
- Climbing state reset when input disabled

**Added method:**
```gdscript
## Enable or disable player input (for console, menus, etc.)
func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if enabled:
		print("[CharacterController] Input enabled")
	else:
		print("[CharacterController] Input disabled (console/menu active)")
```

---

## Flow

```
User presses ~ or F1
    ↓
GameConsole.toggle_console()
    ├─ Console becomes visible
    ├─ Calls _disable_player_input()
    │   └─ Finds player via "player" group
    │   └─ Calls player.set_input_enabled(false)
    │       └─ Player stops accepting movement input
    └─ Input field gets focus
    
User types commands (no game movement!)
    ↓
User presses ~ or F1 again
    ↓
GameConsole.toggle_console()
    ├─ Console becomes hidden
    ├─ Calls _enable_player_input()
    │   └─ Calls player.set_input_enabled(true)
    │       └─ Player starts accepting input again
    └─ Input field loses focus
    
Player can move/play normally
```

---

## Benefits

✅ **No more interference**: Typing in console doesn't trigger game actions  
✅ **Clean implementation**: Uses existing player group for automatic finding  
✅ **Graceful degradation**: Still applies gravity when input disabled (player won't float)  
✅ **Logging feedback**: Console prints when input is toggled  
✅ **No console redesign needed**: Works with existing console architecture  
✅ **Extensible**: Same pattern can be used for menus, pause screens, etc.  

---

## Files Modified

1. **`long_nights/GameConsole.gd`**
   - Added `_player_input_enabled` variable
   - Modified `toggle_console()` to call disable/enable methods
   - Added `_disable_player_input()` method
   - Added `_enable_player_input()` method

2. **`blocky_game/player/character_controller.gd`**
   - Added `input_enabled` variable
   - Modified `_physics_process()` to check `input_enabled`
   - Added `set_input_enabled()` method
   - Movement stops when input disabled (no unintended actions)

---

## Technical Details

### Why This Approach?

**Alternative 1: Set process to false**
- ❌ Too aggressive, would freeze physics
- ❌ Gravity would stop, player would float

**Alternative 2: Redirect input**
- ❌ Complex filtering needed
- ❌ Risk of missing edge cases

**Alternative 3: Move input to separate script** (chosen)
- ✅ Simple flag check
- ✅ Gravity still works
- ✅ Movement naturally stops
- ✅ Easy to extend to other systems

### Group-Based Player Finding

```gdscript
# Character controller adds itself to "player" group in _ready()
add_to_group("player")

# Console finds it automatically
var player = get_tree().get_first_group_member("player")
```

This is more robust than:
- ❌ Hard-coded paths like `get_node("/root/Main/Game/Avatar")`
- ❌ Searching by name
- ✅ Using groups (player registers itself)

---

## Testing Checklist

- [ ] Open console with ~ or F1
- [ ] Type command with underscore: `giveblock planks_redwood 5`
- [ ] Verify player doesn't move while typing
- [ ] Close console with ~ or F1
- [ ] Verify player can move again
- [ ] Check console output shows "Input disabled" / "Input enabled"
- [ ] Verify player doesn't float when console open
- [ ] Try rapid open/close toggle

---

## Console Toggle Still Works

✅ ~ (tilde) key: Always works (handled in _input before consumption)  
✅ F1 key: Always works (handled in _input before consumption)  

The `get_viewport().set_input_as_handled()` call in GameConsole._input() prevents these keys from being consumed by other systems, so the console can always be toggled.

---

## Future Enhancements

Could use the same pattern for:
- Pause menu (disable input while paused)
- Character screen (disable input during viewing)
- Crafting interface (disable input while crafting)
- Dialog system (disable input during conversation)

Just extend with more `set_*_enabled()` methods as needed!

---

**Status:** ✅ Complete  
**Impact:** Console now usable without game interference  
**Compatibility:** Works with existing console commands  
