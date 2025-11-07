extends Node

## CaveEntranceDecorator - Detects and decorates cave entrances
## Places rust_block frames and torches around cave openings at surface level

const ThrownTorch = preload("res://blocky_game/projectiles/thrown_torch.gd")

## Settings
const ENTRANCE_CHECK_INTERVAL = 30.0  # Check every 30 seconds
const ENTRANCE_SEARCH_DISTANCE = 40.0  # Search this far around player
const MIN_ENTRANCE_SPACING = 15.0  # Min distance between decorated entrances

var _check_timer := 0.0
var _decorated_entrance_positions := []  # Track decorated entrances
var _terrain : VoxelTerrain = null
var _blocks = null


func _ready():
	print("🚪 CaveEntranceDecorator initialized")


func _process(delta: float):
	_check_timer += delta

	if _check_timer >= ENTRANCE_CHECK_INTERVAL:
		_check_timer = 0.0
		_try_decorate_entrances()


func _try_decorate_entrances():
	"""Try to find and decorate cave entrances near player"""
	# Find player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Get terrain and blocks reference
	if _terrain == null:
		_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")
		_blocks = get_node_or_null("/root/Main/Game/Blocks")
		if _terrain == null or _blocks == null:
			return

	# Only decorate if player is near surface (Y > -20)
	if player.global_position.y < -20:
		return

	# Try to find cave entrances
	var entrances_decorated = 0
	var max_attempts = 15

	for i in max_attempts:
		if entrances_decorated >= 2:  # Max 2 per interval
			break

		var entrance_pos = _find_cave_entrance(player.global_position)
		if entrance_pos != Vector3.ZERO:
			_decorate_entrance(entrance_pos)
			entrances_decorated += 1


func _find_cave_entrance(player_pos: Vector3) -> Vector3:
	"""Find a cave entrance position near the player"""
	# Random position around player
	var angle = randf() * TAU
	var distance = randf_range(10.0, ENTRANCE_SEARCH_DISTANCE)

	var test_pos = player_pos + Vector3(
		cos(angle) * distance,
		randf_range(-5.0, 10.0),  # Check various heights
		sin(angle) * distance
	)

	# Check if too close to already decorated entrance
	for existing_pos in _decorated_entrance_positions:
		if test_pos.distance_to(existing_pos) < MIN_ENTRANCE_SPACING:
			return Vector3.ZERO

	# Check if this looks like a cave entrance
	if not _is_cave_entrance(test_pos):
		return Vector3.ZERO

	return test_pos


func _is_cave_entrance(pos: Vector3) -> bool:
	"""Check if position looks like a cave entrance (surface air with cave below)"""
	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	var check_pos = Vector3i(pos)

	# Must be air at this position
	if vt.get_voxel(check_pos) != 0:
		return false

	# Must have ground/grass above or nearby (at surface level)
	var has_surface_nearby = false
	for y_offset in range(-2, 3):
		var surface_pos = check_pos + Vector3i(0, y_offset, 0)
		var block_above = vt.get_voxel(surface_pos + Vector3i.UP)

		# Check if this is grass (surface)
		var grass_id = _blocks.get_block_by_name("grass").base_info.voxels[0]
		if block_above == grass_id or (y_offset >= 0 and block_above != 0):
			has_surface_nearby = true
			break

	if not has_surface_nearby:
		return false

	# Must have air continuing downward (cave below)
	var air_below_count = 0
	for y in range(1, 6):
		var below_pos = check_pos + Vector3i(0, -y, 0)
		if vt.get_voxel(below_pos) == 0:
			air_below_count += 1
		else:
			break

	# Cave entrance should have at least 3 blocks of air going down
	return air_below_count >= 3


func _decorate_entrance(position: Vector3):
	"""Place rust_block frames and torches around cave entrance"""
	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	var rust_block_id = _blocks.get_block_by_name("rust_block").base_info.voxels[0]

	# Place rust_block frame around the opening (horizontal ring)
	var frame_positions = [
		Vector3i(-1, 0, 0), Vector3i(1, 0, 0),
		Vector3i(0, 0, -1), Vector3i(0, 0, 1),
		Vector3i(-1, 0, -1), Vector3i(1, 0, -1),
		Vector3i(-1, 0, 1), Vector3i(1, 0, 1)
	]

	var center = Vector3i(position)
	for offset in frame_positions:
		var frame_pos = center + offset
		# Only place if there's a solid block and we're at the right height
		var block_at = vt.get_voxel(frame_pos)
		var block_below = vt.get_voxel(frame_pos + Vector3i.DOWN)

		# Place rust_block if there's ground below and either air or dirt/stone here
		if block_below != 0 and (block_at == 0 or block_at < 10):
			vt.set_voxel(frame_pos, rust_block_id)

	# Place 2 torches near the entrance
	_place_entrance_torch(position + Vector3(2, 0, 2))
	_place_entrance_torch(position + Vector3(-2, 0, -2))

	# Track this entrance
	_decorated_entrance_positions.append(position)

	# Limit tracking
	if _decorated_entrance_positions.size() > 50:
		_decorated_entrance_positions.pop_front()

	print("🚪 Decorated cave entrance at %s" % position)


func _place_entrance_torch(position: Vector3):
	"""Place a thrown torch near cave entrance"""
	var torch = Node3D.new()
	torch.set_script(ThrownTorch)

	# Add to game scene
	var game = get_node_or_null("/root/Main/Game")
	if not game:
		return

	game.add_child(torch)

	# Set torch position and make it static
	torch.global_position = position
	torch.rotation = Vector3.ZERO
	torch.lifetime = 1200.0  # 20 minutes for entrance torches
	torch.set_physics_process(false)

	print("  🔥 Placed entrance torch at %s" % position)
