extends Node

## CaveMushroomSpawner - Places glowing mushrooms on cave walls/floors
## Creates billboard mushrooms using the food/mushroom.png texture with glow lights

## Settings
const MUSHROOM_CHECK_INTERVAL = 15.0  # Check every 15 seconds
const MUSHROOM_PLACEMENT_DISTANCE = 30.0  # Place mushrooms within this distance
const MIN_MUSHROOM_SPACING = 5.0  # Minimum distance between mushrooms
const MUSHROOM_SPAWN_CHANCE = 0.3  # 30% chance to spawn on valid position

var _check_timer := 0.0
var _placed_mushroom_positions := []  # Track where we've placed mushrooms
var _terrain : VoxelTerrain = null


func _ready():
	print("🍄 CaveMushroomSpawner initialized")


func _process(delta: float):
	_check_timer += delta

	if _check_timer >= MUSHROOM_CHECK_INTERVAL:
		_check_timer = 0.0
		_try_place_mushrooms()


func _try_place_mushrooms():
	"""Try to place glowing mushrooms near player if in a cave"""
	# Find player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Only place mushrooms if player is underground (in caves)
	# More mushrooms at deeper depths
	var player_y = player.global_position.y
	if player_y >= -10.0:
		return

	# Get terrain reference
	if _terrain == null:
		_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")
		if _terrain == null:
			return

	# Try to place mushrooms around player
	var mushrooms_placed = 0
	var max_attempts = 30
	var max_mushrooms = 2  # Place fewer mushrooms per interval (they're decorative)

	# More mushrooms in deeper caves
	if player_y < -150:
		max_mushrooms = 3
	if player_y < -300:
		max_mushrooms = 4

	for i in max_attempts:
		if mushrooms_placed >= max_mushrooms:
			break

		# Random chance to skip (don't fill caves with mushrooms)
		if randf() > MUSHROOM_SPAWN_CHANCE:
			continue

		var mushroom_pos = _find_mushroom_placement_position(player.global_position)
		if mushroom_pos != Vector3.ZERO:
			_place_mushroom(mushroom_pos)
			mushrooms_placed += 1


func _find_mushroom_placement_position(player_pos: Vector3) -> Vector3:
	"""Find a suitable floor or wall position for a mushroom near the player"""
	# Random position around player
	var angle = randf() * TAU
	var distance = randf_range(8.0, MUSHROOM_PLACEMENT_DISTANCE)

	var test_pos = player_pos + Vector3(
		cos(angle) * distance,
		randf_range(-4.0, 2.0),  # Vertical variation
		sin(angle) * distance
	)

	# Check if this position is too close to existing mushrooms
	for existing_pos in _placed_mushroom_positions:
		if test_pos.distance_to(existing_pos) < MIN_MUSHROOM_SPACING:
			return Vector3.ZERO  # Too close to existing mushroom

	# Check if this is a good mushroom position (on floor or wall)
	if not _is_valid_mushroom_position(test_pos):
		return Vector3.ZERO

	return test_pos


func _is_valid_mushroom_position(pos: Vector3) -> bool:
	"""Check if position is suitable for a mushroom (on floor or wall)"""
	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	# Check if this position is air
	var block_at_pos = vt.get_voxel(Vector3i(pos))
	if block_at_pos != 0:  # 0 = AIR
		return false

	# Check for floor (block below) or wall (block to side)
	var has_surface = false

	# Check floor (preferred)
	var below_pos = pos + Vector3.DOWN
	var block_below = vt.get_voxel(Vector3i(below_pos))
	if block_below != 0:
		has_surface = true

	# Also check walls if no floor
	if not has_surface:
		var wall_directions = [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
		for dir in wall_directions:
			var check_pos = pos + dir
			var block = vt.get_voxel(Vector3i(check_pos))
			if block != 0:
				has_surface = true
				break

	return has_surface


func _place_mushroom(position: Vector3):
	"""Spawn a glowing mushroom billboard at the position"""
	# Create billboard sprite
	var mushroom = Sprite3D.new()
	mushroom.texture = load("res://assets/art/food/mushroom.png")
	mushroom.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mushroom.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	mushroom.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mushroom.pixel_size = 0.01  # Size of the billboard
	mushroom.modulate = Color(0.8, 1.0, 0.9, 1.0)  # Slight greenish glow tint

	# Add glow light (if graphics settings allow)
	if GraphicsSettings.should_create_torch_light():
		var light = OmniLight3D.new()
		light.light_color = Color(0.4, 0.8, 0.5)  # Greenish glow
		light.light_energy = 1.5
		light.omni_range = 4.0  # Smaller range than torches
		light.omni_attenuation = 0.8
		mushroom.add_child(light)

	# Add to game scene
	var game = get_node_or_null("/root/Main/Game")
	if not game:
		mushroom.queue_free()
		return

	game.add_child(mushroom)
	mushroom.global_position = position

	# Track this mushroom position
	_placed_mushroom_positions.append(position)

	# Limit tracking array to prevent memory bloat (keep last 150 mushrooms)
	if _placed_mushroom_positions.size() > 150:
		_placed_mushroom_positions.pop_front()

	print("🍄 Placed glowing mushroom at %s (Y=%.1f)" % [position, position.y])
