extends Node

## VoidRuinSpawner - Spawns challenge platforms in the void at Y -612
## Handles placement, block generation, and challenge setup
## Challenge completion rewards stat potions

const VoidRuinLibrary = preload("res://blocky_game/ruins/VoidRuinLibrary.gd")

const VOID_RUIN_Y = -612  # 100 blocks below bedrock (-512)

@onready var _void_ruin_library: VoidRuinLibrary = null
@onready var _blocks = null  # Will be set to the Blocks node
@onready var _terrain = null  # Will be set to the VoxelTerrain node
@onready var _void_challenge_manager = null  # VoidChallengeManager reference

# Track active void challenge for completion/return
var _active_challenge: Dictionary = {}  # {player_id: {origin_pos, challenge_type, ruin_pos}}


func _ready():
	print("VoidRuinSpawner ready")


func _physics_process(_delta):
	"""Monitor push_blocks in void challenges and respawn if they fall off"""
	_check_fallen_push_blocks()


func initialize(void_ruin_library: VoidRuinLibrary, blocks_node: Node, terrain_node: Node, void_challenge_manager: Node = null):
	"""Initialize the spawner with required dependencies"""
	_void_ruin_library = void_ruin_library
	_blocks = blocks_node
	_terrain = terrain_node
	_void_challenge_manager = void_challenge_manager
	print("VoidRuinSpawner initialized")


func spawn_void_ruin_for_player(origin_teleport_pos: Vector3, challenge_type: String = "") -> Vector3:
	"""
	Spawn a void ruin challenge for a player
	origin_teleport_pos: The void_teleport_stone position they came from (for return)
	challenge_type: "combat", "parkour", "puzzle", "gauntlet" (random if empty)
	Returns the spawn position, or Vector3.ZERO if failed
	"""
	if _void_ruin_library == null:
		push_error("VoidRuinSpawner not initialized - VoidRuinLibrary is null")
		return Vector3.ZERO

	if _terrain == null:
		push_error("VoidRuinSpawner not initialized - Terrain is null")
		return Vector3.ZERO

	# Get challenge template
	var template: VoidRuinLibrary.VoidChallengeTemplate = null
	if challenge_type.is_empty():
		template = _void_ruin_library.get_random_challenge()
	else:
		template = _void_ruin_library.get_challenge_by_type(challenge_type)

	if template == null:
		push_error("Failed to get void challenge template")
		return Vector3.ZERO

	# Calculate spawn position (random horizontal offset from origin, fixed Y at void level)
	var random_offset = Vector3(
		randf_range(-100, 100),
		0,
		randf_range(-100, 100)
	)
	var spawn_x = origin_teleport_pos.x + random_offset.x
	var spawn_z = origin_teleport_pos.z + random_offset.z
	var spawn_position = Vector3(spawn_x, VOID_RUIN_Y, spawn_z)

	print("Spawning void challenge '", template.name, "' (", template.challenge_type, ") at: ", spawn_position)

	# FORCE CHUNK GENERATION: Create temporary VoxelViewer
	print("Creating temporary VoxelViewer to generate void chunks...")
	var temp_viewer = VoxelViewer.new()
	temp_viewer.position = spawn_position
	temp_viewer.view_distance = 32
	temp_viewer.requires_visuals = true
	temp_viewer.requires_collisions = true
	_terrain.add_child(temp_viewer)

	# Wait for chunks to generate (CRITICAL: Player gravity disabled during this!)
	await get_tree().create_timer(2.0).timeout
	print("Void chunks generated, placing blocks...")

	# Get the voxel tool for editing terrain
	var voxel_tool = _terrain.get_voxel_tool()
	if voxel_tool == null:
		temp_viewer.queue_free()
		push_error("Failed to get voxel tool from terrain")
		return Vector3.ZERO

	# Place each block in the template
	var blocks_placed = 0
	for block_data in template.blocks:
		var block_pos: Vector3i = block_data.pos
		var block_id: int = block_data.block_id
		var variant: int = block_data.variant if "variant" in block_data else 0

		# Calculate world position
		var world_block_pos = Vector3i(spawn_position) + block_pos

		# Get the block and its voxel ID
		var block = _blocks.get_block(block_id)
		if block == null:
			push_warning("Block ID ", block_id, " not found, skipping")
			continue

		# Get the voxel value to place
		var voxel_id = block.base_info.voxels[variant] if variant < block.base_info.voxels.size() else block.base_info.voxels[0]

		# Place the block
		voxel_tool.set_voxel(world_block_pos, voxel_id)
		blocks_placed += 1

	# Setup challenge-specific mechanics
	_setup_void_challenge(template, spawn_position, origin_teleport_pos)

	# Clean up temporary VoxelViewer
	temp_viewer.queue_free()

	# Add VoidBeacon lighting
	_add_void_beacon_lights(spawn_position, template)

	print("Placed ", blocks_placed, " blocks for void challenge '", template.name, "' (", template.challenge_type, ")")
	return spawn_position


func _setup_void_challenge(template: VoidRuinLibrary.VoidChallengeTemplate, world_position: Vector3, origin_pos: Vector3):
	"""
	Set up void challenge mechanics:
	- Convert push_block voxels to entities
	- Spawn test_block target
	- Track challenge data for completion
	"""
	# Determine gravity setting (combat/gauntlet may have gravity, parkour might not)
	var has_gravity = not template.name.contains("zerog")

	# Find push_block and test_block positions in the template
	const PUSH_BLOCK_ID = 26  # push_block block ID
	const TEST_BLOCK_ID = 45  # test_block block ID (target) - glowing test block

	var push_block_positions = []
	var test_block_positions = []

	for block_data in template.blocks:
		var world_pos = Vector3i(world_position) + block_data.pos

		if block_data.block_id == PUSH_BLOCK_ID:
			push_block_positions.append(world_pos)
		elif block_data.block_id == TEST_BLOCK_ID:
			test_block_positions.append(world_pos)

	# Spawn push_block entities and track them
	var spawned_push_blocks = []
	var push_block_manager = get_node_or_null("/root/Main/Game/PushBlockManager")
	if push_block_manager:
		for pos in push_block_positions:
			# Tag push blocks with challenge info so we can detect completion
			var push_block = push_block_manager.spawn_puzzle_block(pos, has_gravity, template.name)
			if push_block:
				spawned_push_blocks.append({
					"node": push_block,
					"original_pos": pos,
					"has_gravity": has_gravity
				})

		# Wait a frame for push_blocks to be added to scene tree, then register with VoidChallengeManager
		if _void_challenge_manager:
			await get_tree().process_frame
			_void_challenge_manager._connect_to_existing_push_blocks()
			print("🔗 Registered void challenge push_blocks with VoidChallengeManager")

	# Get player to track their active challenge
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var player_id = player.get_instance_id()
		_active_challenge[player_id] = {
			"origin_pos": origin_pos,  # Void teleport stone they came from
			"challenge_type": template.challenge_type,  # For potion reward
			"ruin_pos": world_position,
			"ruin_name": template.name,
			"push_block_positions": push_block_positions,
			"test_block_positions": test_block_positions,
			"push_blocks": spawned_push_blocks  # Track entities for respawn
		}

	var gravity_str = "WITH gravity" if has_gravity else "ZERO-G"
	print("🌌 Void challenge '%s' setup! %d push_block(s), %d test_block(s) (%s)" % [
		template.name,
		push_block_positions.size(),
		test_block_positions.size(),
		gravity_str
	])


func _check_fallen_push_blocks():
	"""Check if any push_blocks fell below Y -650 and respawn them"""
	const RESPAWN_THRESHOLD = -650.0  # Platforms are at Y -612, so this catches blocks that fall off

	for player_id in _active_challenge.keys():
		var challenge_data = _active_challenge[player_id]

		if not challenge_data.has("push_blocks"):
			continue

		var push_blocks = challenge_data.push_blocks
		for i in range(push_blocks.size()):
			var push_block_data = push_blocks[i]
			var push_block_node = push_block_data.node

			# Check if node is still valid
			if not is_instance_valid(push_block_node):
				continue

			# Check if push_block fell below threshold
			if push_block_node.global_position.y < RESPAWN_THRESHOLD:
				print("🔄 Push block fell off platform (Y: %.1f), respawning..." % push_block_node.global_position.y)

				# Respawn at original position
				var original_pos = push_block_data.original_pos
				var has_gravity = push_block_data.has_gravity

				# Remove old push_block
				push_block_node.queue_free()

				# Spawn new one
				var push_block_manager = get_node_or_null("/root/Main/Game/PushBlockManager")
				if push_block_manager:
					push_block_manager.spawn_puzzle_block(original_pos, has_gravity, challenge_data.ruin_name)

					# Re-register with VoidChallengeManager (scan for all push_blocks)
					if _void_challenge_manager:
						await get_tree().process_frame
						_void_challenge_manager._connect_to_existing_push_blocks()
						print("✅ Push block respawned at: ", original_pos)

						# Update tracking data with new push_block reference
						var all_push_blocks = get_tree().get_nodes_in_group("push_blocks")
						for pb in all_push_blocks:
							if pb.global_position.distance_to(original_pos) < 1.0:
								push_blocks[i] = {
									"node": pb,
									"original_pos": original_pos,
									"has_gravity": has_gravity
								}
								break


func _add_void_beacon_lights(world_position: Vector3, template: VoidRuinLibrary.VoidChallengeTemplate):
	"""
	Add VoidBeacon lights to the challenge platforms
	Uses darker purple/void colors instead of bright teleport stone colors
	"""
	# Add lights at key positions (start platform, target platform)
	var beacon_positions = template.beacon_positions if template.beacon_positions else []

	for beacon_pos in beacon_positions:
		var world_beacon_pos = world_position + Vector3(beacon_pos)
		_add_void_beacon(world_beacon_pos, template.challenge_type)


func _add_void_beacon(position: Vector3, challenge_type: String):
	"""
	Add a glowing VoidBeacon light
	Color varies by challenge type:
	- Combat (HP): Dark red
	- Parkour (Luck): Dark green
	- Puzzle (Defense): Dark gray
	- Gauntlet (Attack): Dark yellow/orange
	"""
	var light = OmniLight3D.new()
	light.name = "VoidBeacon"
	light.position = position + Vector3(0.5, 0.5, 0.5)  # Center of block

	# Color by challenge type
	var beacon_color: Color
	match challenge_type:
		"combat":
			beacon_color = Color(0.5, 0.0, 0.0)  # Dark red
		"parkour":
			beacon_color = Color(0.0, 0.4, 0.0)  # Dark green
		"puzzle":
			beacon_color = Color(0.3, 0.3, 0.3)  # Dark gray
		"gauntlet":
			beacon_color = Color(0.5, 0.3, 0.0)  # Dark orange/yellow
		_:
			beacon_color = Color(0.2, 0.0, 0.3)  # Default dark purple (void)

	light.light_color = beacon_color
	light.light_energy = 1.5
	light.omni_range = 10.0
	light.omni_attenuation = 2.0

	_terrain.add_child(light)
	print("Added VoidBeacon at: ", position, " (", challenge_type, ")")


func get_active_challenge_for_player(player_id: int) -> Dictionary:
	"""Get the active challenge data for a player"""
	if _active_challenge.has(player_id):
		return _active_challenge[player_id]
	return {}


func clear_active_challenge(player_id: int):
	"""Clear challenge data after completion/return"""
	if _active_challenge.has(player_id):
		_active_challenge.erase(player_id)
		print("Cleared active challenge for player ", player_id)
