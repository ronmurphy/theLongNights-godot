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
	"""Spawn a PushBlock entity at the given block position"""
	# REMOVE the voxel from terrain (entity will replace it)
	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE
	vt.set_voxel(block_pos, 0)  # 0 = air, remove the voxel

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
