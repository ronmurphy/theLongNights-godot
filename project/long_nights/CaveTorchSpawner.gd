extends Node

## CaveTorchSpawner - Places torches on cave walls for lighting
## Places thrown torches (the ones that stick to walls) in caves near the player

const ThrownTorch = preload("res://blocky_game/projectiles/thrown_torch.gd")

## Settings
const TORCH_CHECK_INTERVAL = 10.0  # Check every 10 seconds
const TORCH_PLACEMENT_DISTANCE = 25.0  # Place torches within this distance of player
const MIN_TORCH_SPACING = 8.0  # Minimum distance between torches
const TORCH_HEIGHT_OFFSET = 1.5  # Height above floor to place torches

var _check_timer := 0.0
var _placed_torch_positions := []  # Track where we've placed torches
var _terrain : VoxelTerrain = null


func _ready():
	print("🔥 CaveTorchSpawner initialized")


func _process(delta: float):
	_check_timer += delta

	if _check_timer >= TORCH_CHECK_INTERVAL:
		_check_timer = 0.0
		_try_place_torches()


func _try_place_torches():
	"""Try to place torches near player if in a cave"""
	# Find player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Only place torches if player is underground (in caves)
	if player.global_position.y >= -10.0:
		return

	# Get terrain reference
	if _terrain == null:
		_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")
		if _terrain == null:
			return

	# Try to place a few torches around player
	var torches_placed = 0
	var max_attempts = 20

	for i in max_attempts:
		if torches_placed >= 3:
			break  # Max 3 torches per check interval

		var torch_pos = _find_torch_placement_position(player.global_position)
		if torch_pos != Vector3.ZERO:
			_place_torch(torch_pos)
			torches_placed += 1


func _find_torch_placement_position(player_pos: Vector3) -> Vector3:
	"""Find a suitable wall position for a torch near the player"""
	# Random position around player
	var angle = randf() * TAU
	var distance = randf_range(10.0, TORCH_PLACEMENT_DISTANCE)

	var test_pos = player_pos + Vector3(
		cos(angle) * distance,
		randf_range(-3.0, 3.0),  # Slight vertical variation
		sin(angle) * distance
	)

	# Check if this position is too close to existing torches
	for existing_pos in _placed_torch_positions:
		if test_pos.distance_to(existing_pos) < MIN_TORCH_SPACING:
			return Vector3.ZERO  # Too close to existing torch

	# Check if this is a good torch position (wall nearby, air in front)
	if not _is_valid_torch_position(test_pos):
		return Vector3.ZERO

	return test_pos


func _is_valid_torch_position(pos: Vector3) -> bool:
	"""Check if position is suitable for a torch (air with wall behind)"""
	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	# Check if this position is air
	var block_at_pos = vt.get_voxel(Vector3i(pos))
	if block_at_pos != 0:  # 0 = AIR
		return false

	# Check for a wall in at least one cardinal direction
	var directions = [
		Vector3.LEFT, Vector3.RIGHT,
		Vector3.FORWARD, Vector3.BACK
	]

	var has_wall = false
	for dir in directions:
		var check_pos = pos + dir
		var block = vt.get_voxel(Vector3i(check_pos))
		if block != 0:  # Found a wall
			has_wall = true
			break

	return has_wall


func _place_torch(position: Vector3):
	"""Spawn a thrown torch at the position (will stick to nearby wall)"""
	var torch = Node3D.new()
	torch.set_script(ThrownTorch)

	# Add to game scene
	var game = get_node_or_null("/root/Main/Game")
	if not game:
		return

	game.add_child(torch)

	# Set torch position and make it static (landed)
	torch.global_position = position
	torch.rotation = Vector3.ZERO  # Upright
	torch.lifetime = 600.0  # 10 minutes lifetime for cave torches
	torch.set_physics_process(false)  # Don't process physics (it's stuck)

	# Track this torch position
	_placed_torch_positions.append(position)

	# Limit tracking array to prevent memory bloat (keep last 100 torches)
	if _placed_torch_positions.size() > 100:
		_placed_torch_positions.pop_front()

	print("🔥 Placed cave torch at %s" % position)
