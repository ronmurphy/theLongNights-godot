extends Node
class_name FishingMinigame

## FishingMinigame - Main fishing minigame controller
## Handles the entire fishing sequence from initiation to completion

signal fishing_started
signal fishing_ended(caught: bool)

# References
var player: Node3D = null
var fish: Node3D = null
var fish_spawner: Node = null

# Fishing state
var is_fishing: bool = false
var wait_timer: float = 0.0
var wait_duration: float = 10.0 # was 30
var fish_bite_time: float = -1.0  # When fish will bite (-1 = not yet)
var fishing_ui: Node = null

# Bar minigame state
var attempt_count: int = 0
var max_attempts: int = 5
var successes_needed: int = 3
var successes: int = 0
var failures: int = 0
var target_zone_width: float = 0.4  # 40% of bar
var bar_fill_speed: float = 0.8  # Start slow: ~8 seconds to fill -> 0.125

# 3D fishing visuals
var fishing_line_mesh: MeshInstance3D = null
var fishing_hook_pos: Vector3 = Vector3.ZERO

func _ready():
	pass

func start_fishing(p_player: Node3D, p_fish: Node3D, p_spawner: Node) -> void:
	"""Initiate fishing minigame"""
	player = p_player
	fish = p_fish
	fish_spawner = p_spawner

	is_fishing = true
	wait_timer = 0.0
	attempt_count = 0
	successes = 0
	failures = 0

	# Generate random bite time (3-25 seconds)
	fish_bite_time = randf_range(3.0, 25.0)

	print("🎣 Fishing started! Fish will bite in %.1f seconds..." % fish_bite_time)

	# Disable player input (prevents movement, jumping, etc)
	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)
		print("  Disabled player input for fishing")

	# Set fishing mode in avatar_interaction
	var avatar_interaction = null
	for child in player.get_children():
		if child.get_script() and child.get_script().resource_path.contains("avatar_interaction"):
			avatar_interaction = child
			break

	if avatar_interaction and avatar_interaction.has_method("_set_fishing_mode"):
		avatar_interaction.call("_set_fishing_mode", true)

	# Create 3D fishing line
	_create_fishing_line()

	# Emit signal
	fishing_started.emit()

func _process(delta: float) -> void:
	"""Handle fishing sequence"""
	if not is_fishing:
		return

	# Update wait phase
	if fish_bite_time >= 0.0:
		wait_timer += delta

		# Check if fish bites
		if wait_timer >= fish_bite_time:
			_fish_bites()
			fish_bite_time = -1.0  # Mark as handled

func _fish_bites() -> void:
	"""Called when fish bites the line"""
	print("🐟 Fish bites!")

	# Create splash effect
	_create_splash_effect()

	# Play bite sound
	_play_bite_sound()

	# Despawn the fish from world (it's caught now)
	if fish and is_instance_valid(fish):
		fish.queue_free()

	# Start bar minigame
	_start_bar_minigame()

func _start_bar_minigame() -> void:
	"""Launch the bar filling minigame modal"""
	# Create and show fishing UI modal
	fishing_ui = load("res://blocky_game/fishing/FishingUI.gd").new()
	get_tree().root.add_child(fishing_ui)

	# Connect UI signals
	fishing_ui.attempt_completed.connect(_on_attempt_completed)
	fishing_ui.minigame_finished.connect(_on_minigame_finished)

	# Pass current state to UI
	fishing_ui.setup(attempt_count, max_attempts, successes_needed, successes, target_zone_width)
	fishing_ui.start_attempt(bar_fill_speed)

func _on_attempt_completed(success: bool) -> void:
	"""Called when player completes an attempt"""
	attempt_count += 1

	if success:
		successes += 1
		print("✓ Success! (%d/%d)" % [successes, successes_needed])
		_play_success_sound()

		# Shrink target zone for next attempt
		target_zone_width = max(0.15, target_zone_width - 0.1)

		# Speed progression: 8s -> 5s -> 2.5s
		if successes == 1:
			bar_fill_speed = 0.6  # 5 seconds to fill -> 0.2
		elif successes >= 2:
			bar_fill_speed = 0.4  # 2.5 seconds to fill = 0.4

		# Check if we won
		if successes >= successes_needed:
			_finish_fishing(true)
			return
	else:
		failures += 1
		print("✗ Miss! (%d/3)" % failures)
		_play_fail_sound()

		# Check if we lost
		if failures >= 3:
			_finish_fishing(false)
			return

	# Continue to next attempt
	if is_fishing:
		await get_tree().process_frame
		if fishing_ui and is_instance_valid(fishing_ui):
			fishing_ui.start_attempt(bar_fill_speed)

func _on_minigame_finished(caught: bool) -> void:
	"""Called when minigame ends (won or lost)"""
	_finish_fishing(caught)

func _finish_fishing(caught: bool) -> void:
	"""End the fishing minigame"""
	if not is_fishing:
		return

	is_fishing = false

	# Re-enable player input
	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(true)
		print("  Re-enabled player input after fishing")

	# Disable fishing mode in avatar_interaction
	var avatar_interaction = null
	for child in player.get_children():
		if child.get_script() and child.get_script().resource_path.contains("avatar_interaction"):
			avatar_interaction = child
			break

	if avatar_interaction and avatar_interaction.has_method("_set_fishing_mode"):
		avatar_interaction.call("_set_fishing_mode", false)

	# Clean up UI
	if fishing_ui and is_instance_valid(fishing_ui):
		fishing_ui.queue_free()

	# Clean up fishing line
	if fishing_line_mesh and is_instance_valid(fishing_line_mesh):
		fishing_line_mesh.queue_free()

	if caught:
		print("🎣 Fish caught!")
		_play_catch_sound()
		_give_fish_to_player()
		_remove_fish_icon_from_ui()
	else:
		print("🐟 Fish got away!")
		_play_escape_sound()
		_remove_fish_icon_from_ui()

	# Emit signal and queue self for deletion
	fishing_ended.emit(caught)
	queue_free()

func escape_fishing() -> void:
	"""Player presses ESC to exit fishing"""
	print("🎣 Fishing cancelled")

	# Despawn fish if not already gone
	if fish and is_instance_valid(fish):
		fish.queue_free()

	_finish_fishing(false)

func _create_fishing_line() -> void:
	"""Create 3D fishing line visuals"""
	# Create a simple line from player's hand to below the surface
	fishing_line_mesh = MeshInstance3D.new()

	var immediate_mesh = ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	# Start point: player's hand (approximate)
	var hand_pos = player.global_position + Vector3(0.5, 1.5, 0)

	# End point: fishing hook (below water surface)
	fishing_hook_pos = hand_pos + Vector3(0, -3, 0)

	immediate_mesh.surface_add_vertex(hand_pos)
	immediate_mesh.surface_add_vertex(fishing_hook_pos)
	immediate_mesh.surface_end()

	fishing_line_mesh.mesh = immediate_mesh

	# Add material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fishing_line_mesh.material_override = material

	get_tree().root.add_child(fishing_line_mesh)

func _create_splash_effect() -> void:
	"""Create visual splash effect when fish bites"""
	# For now, simple visual - can be enhanced with particles later
	var splash_pos = fishing_hook_pos
	print("💧 Splash at %s" % splash_pos)
	# TODO: Add particle effect here

func _play_bite_sound() -> void:
	"""Play sound when fish bites"""
	print("🔊 Bite sound")
	# TODO: Add sound effect

func _play_success_sound() -> void:
	"""Play sound on successful bar hit"""
	print("🔊 Success sound")
	# TODO: Add sound effect

func _play_fail_sound() -> void:
	"""Play sound on failed bar hit"""
	print("🔊 Fail sound")
	# TODO: Add sound effect

func _play_catch_sound() -> void:
	"""Play sound when fish is caught"""
	print("🔊 Catch sound")
	# TODO: Add sound effect

func _play_escape_sound() -> void:
	"""Play sound when fish escapes"""
	print("🔊 Escape sound")
	# TODO: Add sound effect

func _give_fish_to_player() -> void:
	"""Add caught fish to player inventory"""
	# Fish item ID is 26
	const FISH_ITEM_ID = 26

	# Get player's inventory
	var inventory = player.get_node_or_null("Inventory")
	if not inventory:
		print("⚠️ Could not find inventory")
		return

	# Try to add fish to existing stack or empty slot
	var added = false
	for i in range(inventory._slots.size()):
		var slot = inventory._slots[i]

		# Add to existing fish stack
		if slot != null and slot.type == 1 and slot.id == FISH_ITEM_ID:
			if slot.count < 99:  # Max stack size
				slot.count += 1
				added = true
				inventory._update_views()
				print("🐟 Added fish to stack (slot %d, total: %d)" % [i, slot.count])
				break

		# Add to empty slot
		if slot == null:
			# Create item using InventoryItem (like GameConsole does)
			const InventoryItem = preload("res://blocky_game/player/inventory_item.gd")
			var item = InventoryItem.new()
			item.id = FISH_ITEM_ID
			item.type = InventoryItem.TYPE_ITEM
			item.count = 1

			inventory._slots[i] = item
			added = true
			inventory._update_views()
			print("🐟 Added fish to inventory (slot %d)" % i)
			break

	if not added:
		print("⚠️ Inventory full - fish not added")

func _remove_fish_icon_from_ui() -> void:
	"""Remove fish icon from UI"""
	# Get PartyUI and remove fish icon
	var party_ui = get_tree().root.get_node_or_null("/root/Main/Game/PartyUI")
	if party_ui and party_ui.has_method("remove_fishing_icon"):
		party_ui.remove_fishing_icon()
