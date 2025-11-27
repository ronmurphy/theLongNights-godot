extends Node

## PushBlockManager - Scans for push_block voxels and spawns PushBlock entities
## Manages the lifecycle of puzzle blocks in the world

const PushBlock = preload("res://blocky_game/entities/push_block.gd")

var _terrain: VoxelTerrain = null
var _blocks_node: Node = null
var _push_block_id: int = -1
var _tracked_blocks: Dictionary = {}  # {Vector3i: PushBlock} - maps block position to entity
var _scan_timer := 0.0
const SCAN_INTERVAL := 1.0  # Scan every 1 second


func _ready():
	# Find terrain
	_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")
	if _terrain == null:
		push_warning("PushBlockManager: Could not find VoxelTerrain")
		return

	# Find blocks node
	_blocks_node = get_node_or_null("/root/Main/Game/Blocks")
	if _blocks_node == null:
		push_warning("PushBlockManager: Could not find Blocks node")
		return

	# Get push_block voxel ID (not block ID!)
	var push_block = _blocks_node.get_block_by_name("push_block")
	if push_block and push_block.base_info.voxels.size() > 0:
		_push_block_id = push_block.base_info.voxels[0]  # Get VOXEL ID, not block ID
		print("🎯 PushBlockManager initialized (push_block voxel ID: %d)" % _push_block_id)
	else:
		push_warning("PushBlockManager: Could not find push_block in Blocks")


func _process(delta: float):
	if _terrain == null or _push_block_id == -1:
		return

	_scan_timer += delta
	if _scan_timer >= SCAN_INTERVAL:
		_scan_timer = 0.0
		_scan_for_push_blocks()


func _scan_for_push_blocks():
	"""Scan nearby area for push_block voxels and spawn entities"""
	# Get player position for scanning around them
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var player_pos = player.global_position
	var scan_radius = 50  # Scan 50 blocks around player

	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	# Scan area around player
	for x in range(-scan_radius, scan_radius + 1):
		for y in range(-10, 10):  # Scan 10 blocks up and down
			for z in range(-scan_radius, scan_radius + 1):
				# Only scan occasionally to avoid performance hit
				if randf() > 0.01:  # Only check 1% of blocks each scan
					continue

				var check_pos = Vector3i(
					int(player_pos.x) + x,
					int(player_pos.y) + y,
					int(player_pos.z) + z
				)

				var voxel_id = vt.get_voxel(check_pos)

				# Found a push_block voxel
				if voxel_id == _push_block_id:
					if not _tracked_blocks.has(check_pos):
						_spawn_push_block(check_pos)

	# Clean up entities for blocks that no longer exist
	_cleanup_removed_blocks()


func _spawn_push_block(block_pos: Vector3i):
	"""Spawn a PushBlock entity at the given block position
	Auto-detects if this is a puzzle room by checking for nearby test blocks"""
	# REMOVE the voxel from terrain (entity will replace it)
	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE
	vt.set_voxel(block_pos, 0)  # 0 = air, remove the voxel

	# Check if this is a puzzle room by looking for test blocks nearby
	var is_puzzle_room = _is_near_test_block(block_pos, vt)

	if is_puzzle_room:
		# Spawn as a puzzle block with correct settings
		var room_id = "puzzle_room_%d_%d_%d" % [block_pos.x, block_pos.y, block_pos.z]
		var has_gravity = true  # Default to gravity (most puzzle rooms have it)
		spawn_puzzle_block(block_pos, has_gravity, room_id)
		print("🎮 Auto-detected puzzle room! Spawned puzzle push_block at %s" % block_pos)
		return

	# Create entity
	var push_block = Node3D.new()
	push_block.set_script(PushBlock)

	# Add to scene FIRST (must be in tree before setting global_position)
	var game = get_node("/root/Main/Game")
	if game:
		game.add_child(push_block)

		# NOW set position (after node is in tree)
		push_block.global_position = Vector3(
			block_pos.x + 0.5,
			block_pos.y + 0.5,
			block_pos.z + 0.5
		)

		# DON'T track it (we removed the voxel, so cleanup would delete it)
		# The entity now exists independently and will be found via "push_blocks" group

		print("🎯 Spawned PushBlock at %s (voxel removed)" % block_pos)


func _is_near_test_block(block_pos: Vector3i, voxel_tool) -> bool:
	"""Check if there's a test block within a reasonable distance (indicates puzzle room)"""
	const SEARCH_RADIUS = 15  # Puzzle rooms are typically 10-12 blocks wide
	const TEST_BLOCK_ID = 45  # test block ID

	# Search in a cube around the push_block
	for x in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
		for y in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
			for z in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
				var check_pos = block_pos + Vector3i(x, y, z)
				var voxel_id = voxel_tool.get_voxel(check_pos)

				if voxel_id != 0:
					# Convert voxel ID to block ID
					var raw_mapping = _blocks_node.get_raw_mapping(voxel_id)
					if raw_mapping and raw_mapping.block_id == TEST_BLOCK_ID:
						return true  # Found a test block nearby!

	return false  # No test block found


func _cleanup_removed_blocks():
	"""Remove entities for blocks that have been destroyed"""
	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	var blocks_to_remove = []

	for block_pos in _tracked_blocks.keys():
		var voxel_id = vt.get_voxel(block_pos)

		# Block was destroyed
		if voxel_id != _push_block_id:
			var entity = _tracked_blocks[block_pos]
			if is_instance_valid(entity):
				entity.queue_free()

			blocks_to_remove.append(block_pos)
			print("🗑️ Removed PushBlock at %s (block destroyed)" % block_pos)

	# Clean up tracking
	for block_pos in blocks_to_remove:
		_tracked_blocks.erase(block_pos)


func create_push_block_at(world_pos: Vector3i):
	"""Manually create a push block at a specific position (called by projectiles)"""
	# Check if entity already exists at this position
	var push_blocks = get_tree().get_nodes_in_group("push_blocks")
	for block in push_blocks:
		if not is_instance_valid(block):
			continue

		var entity_voxel_pos = Vector3i(
			int(floor(block.global_position.x)),
			int(floor(block.global_position.y)),
			int(floor(block.global_position.z))
		)

		if entity_voxel_pos == world_pos:
			print("⚠️ Entity already exists at %s, not spawning" % world_pos)
			return  # Already has an entity

	# No entity exists, spawn one
	_spawn_push_block(world_pos)


func spawn_puzzle_block(world_pos: Vector3i, has_gravity: bool, room_id: String) -> Node3D:
	"""
	Spawn a push_block for a puzzle room with specific settings
	- has_gravity: whether the block falls (false for zero-G rooms)
	- room_id: identifier for room reset and goal tracking
	Returns the spawned block entity
	"""
	# Remove voxel if it exists
	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE
	vt.set_voxel(world_pos, 0)  # Remove voxel

	# Create entity
	var push_block = Node3D.new()
	push_block.set_script(PushBlock)

	# Add to scene FIRST
	var game = get_node("/root/Main/Game")
	if game:
		game.add_child(push_block)

		# Set position
		var spawn_pos = Vector3(
			world_pos.x + 0.5,
			world_pos.y + 0.5,
			world_pos.z + 0.5
		)
		push_block.global_position = spawn_pos

		# Configure puzzle room settings
		push_block.spawn_position = spawn_pos  # For reset
		push_block.puzzle_room_id = room_id
		push_block.gravity = 20.0 if has_gravity else 0.0  # Zero-G or normal

		var gravity_str = "WITH gravity" if has_gravity else "ZERO-G"
		print("🎯 Spawned PUZZLE push_block at %s (%s, room: %s)" % [world_pos, gravity_str, room_id])

		return push_block

	return null


func convert_entities_to_voxels_for_save():
	"""
	CRITICAL: Convert all push_block entities back to voxels before save
	This ensures push_blocks persist across save/load cycles
	Puzzle room blocks are placed at their CURRENT position (not reset to spawn)
	The teleport_stone they unlocked will remain (it's already a voxel)
	"""
	if _terrain == null or _push_block_id == -1:
		return

	var push_blocks = get_tree().get_nodes_in_group("push_blocks")
	if push_blocks.is_empty():
		return

	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	var converted_count = 0

	for block in push_blocks:
		if not is_instance_valid(block):
			continue

		# Get the block's current voxel position (snapped to grid)
		var voxel_pos = Vector3i(
			int(floor(block.global_position.x)),
			int(floor(block.global_position.y)),
			int(floor(block.global_position.z))
		)

		# Check if location is editable (chunk loaded)
		var check_aabb = AABB(Vector3(voxel_pos), Vector3(1, 1, 1))
		if vt.is_area_editable(check_aabb):
			# Place push_block voxel at current position
			vt.set_voxel(voxel_pos, _push_block_id)
			converted_count += 1

			# Remove the entity (will be recreated on load)
			block.queue_free()

			print("💾 Converted push_block entity to voxel at %s for save" % voxel_pos)

	if converted_count > 0:
		print("💾 PRE-SAVE: Converted %d push_block entities to voxels" % converted_count)
