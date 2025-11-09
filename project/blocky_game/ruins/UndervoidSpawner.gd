extends Node

# Spawns Undervoid structures into deep caves
# Places structures with purple beacon lights on large islands

const UndervoidStructures = preload("res://blocky_game/ruins/undervoid_structures.gd")
const UndervoidBeacon = preload("res://blocky_game/items/light_orb/undervoid_beacon.gd")
const AbyssGolem = preload("res://blocky_game/entities/abyss_golem.gd")

@onready var _undervoid_structures: UndervoidStructures = null
@onready var _blocks = null  # Will be set to the Blocks node
@onready var _terrain = null  # Will be set to the VoxelTerrain node
@onready var _game = null  # Game node for placing beacons and entities
@onready var _registry = null  # Will be set to UndervoidRegistry

# Chunk-based spawning system
const CHUNK_SIZE = 16  # Godot voxel default chunk size
const STRUCTURE_SPAWN_CHANCE = 0.08  # 8% chance per chunk (roughly 1 in 12-13 chunks)
var _processed_chunks: Dictionary = {}  # Track which chunks we've checked: Vector2i -> bool
var _world_seed: int = 131183  # Default seed (matches world gen)
var _check_timer: float = 0.0
const CHECK_INTERVAL = 3.0  # Check for new chunks every 3 seconds


func _ready():
	print("🟣 UndervoidSpawner ready - chunk-based spawning enabled")


func initialize(undervoid_structures: UndervoidStructures, blocks_node: Node, terrain_node: Node, game_node: Node, registry):
	"""Initialize the spawner with required dependencies"""
	_undervoid_structures = undervoid_structures
	_blocks = blocks_node
	_terrain = terrain_node
	_game = game_node
	_registry = registry
	print("🟣 UndervoidSpawner initialized")


func _process(delta: float):
	"""Periodically check for new chunks to spawn structures in"""
	_check_timer += delta

	if _check_timer >= CHECK_INTERVAL:
		_check_timer = 0.0
		_check_nearby_chunks_for_structures()


func _check_nearby_chunks_for_structures():
	"""Check chunks around player and spawn structures if needed"""
	# Only spawn if player is in Undervoid
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var player_y = player.global_position.y
	if player_y > -150:
		return  # Not in Undervoid yet

	# Get player's chunk coordinates
	var player_pos = player.global_position
	var player_chunk_x = int(floor(player_pos.x / CHUNK_SIZE))
	var player_chunk_z = int(floor(player_pos.z / CHUNK_SIZE))

	# Check chunks in a radius around player (e.g., 8 chunks = 128 blocks)
	const CHUNK_CHECK_RADIUS = 8

	for cx in range(player_chunk_x - CHUNK_CHECK_RADIUS, player_chunk_x + CHUNK_CHECK_RADIUS + 1):
		for cz in range(player_chunk_z - CHUNK_CHECK_RADIUS, player_chunk_z + CHUNK_CHECK_RADIUS + 1):
			var chunk_key = Vector2i(cx, cz)

			# Skip if we've already processed this chunk
			if _processed_chunks.has(chunk_key):
				continue

			# Mark as processed (even if we don't spawn anything)
			_processed_chunks[chunk_key] = true

			# Check if this chunk should have a structure (deterministic based on seed + chunk coords)
			if _should_chunk_have_structure(cx, cz):
				# Spawn structure in this chunk
				_spawn_structure_in_chunk(cx, cz)


func _should_chunk_have_structure(chunk_x: int, chunk_z: int) -> bool:
	"""Deterministically check if a chunk should have an Undervoid structure"""
	# Create a unique seed for this chunk based on world seed + chunk coords
	var chunk_seed = _world_seed + (chunk_x * 374761393) + (chunk_z * 668265263)

	# Use hash to get pseudo-random value between 0.0 and 1.0
	var rng = RandomNumberGenerator.new()
	rng.seed = chunk_seed
	var random_value = rng.randf()

	# Check if this chunk should have a structure (8% chance)
	return random_value < STRUCTURE_SPAWN_CHANCE


func _spawn_structure_in_chunk(chunk_x: int, chunk_z: int):
	"""Spawn an Undervoid structure somewhere in this chunk"""
	# Create RNG for this chunk
	var chunk_seed = _world_seed + (chunk_x * 374761393) + (chunk_z * 668265263)
	var rng = RandomNumberGenerator.new()
	rng.seed = chunk_seed

	# Pick a random position within the chunk
	var local_x = rng.randi_range(0, CHUNK_SIZE - 1)
	var local_z = rng.randi_range(0, CHUNK_SIZE - 1)

	# Convert to world coordinates
	var world_x = (chunk_x * CHUNK_SIZE) + local_x
	var world_z = (chunk_z * CHUNK_SIZE) + local_z

	# Pick a random depth within Undervoid range
	# Different depth zones for variety:
	var depth_zones = [-160, -180, -210, -240, -270, -300, -330, -360, -400, -450, -480, -495]
	var depth = depth_zones[rng.randi_range(0, depth_zones.size() - 1)]

	var spawn_pos = Vector3(world_x, depth, world_z)

	print("🟣 Chunk-spawning structure at chunk (%d, %d) -> world pos %s" % [chunk_x, chunk_z, spawn_pos])

	# Spawn the structure (async)
	spawn_structure_at(spawn_pos, depth)


func spawn_structure_at(world_position: Vector3, depth: int = -200) -> bool:
	"""
	Spawn an Undervoid structure at the specified position
	Returns true if successful
	"""
	if _undervoid_structures == null:
		push_error("UndervoidSpawner not initialized - UndervoidStructures is null")
		return false

	if _terrain == null:
		push_error("UndervoidSpawner not initialized - Terrain is null")
		return false

	# Get structure template appropriate for this depth
	var template: UndervoidStructures.UndervoidStructure = _undervoid_structures.get_structure_for_depth(depth)

	if template == null:
		push_warning("No suitable Undervoid structure found for depth ", depth)
		return false

	print("🟣 Spawning Undervoid structure '", template.name, "' at position: ", world_position, " (depth: Y ", depth, ")")

	# FORCE CHUNK GENERATION: Create temporary VoxelViewer
	var temp_viewer = VoxelViewer.new()
	temp_viewer.position = world_position
	temp_viewer.view_distance = 20  # Larger for deep structures
	temp_viewer.requires_visuals = true
	temp_viewer.requires_collisions = true
	_terrain.add_child(temp_viewer)

	# Wait longer for deep Undervoid chunks to generate (Y -150 to -500)
	await get_tree().create_timer(3.0).timeout

	# Get the voxel tool for editing terrain
	var voxel_tool = _terrain.get_voxel_tool()
	if voxel_tool == null:
		temp_viewer.queue_free()
		push_error("Failed to get voxel tool from terrain")
		return false

	# Check if area is editable (chunks loaded)
	var structure_aabb = AABB(Vector3(world_position), Vector3(template.size))
	if not voxel_tool.is_area_editable(structure_aabb):
		push_warning("🟣 Structure area not loaded yet at ", world_position, " - waiting longer...")
		# Wait additional time for deep chunks
		await get_tree().create_timer(2.0).timeout

		# Check again
		if not voxel_tool.is_area_editable(structure_aabb):
			temp_viewer.queue_free()
			push_error("🟣 Failed to load chunks for structure at ", world_position)
			return false

	# Place each block in the template
	var blocks_placed = 0
	for block_data in template.blocks:
		var block_pos: Vector3i = block_data.pos
		var block_id: int = block_data.block_id
		var variant: int = block_data.get("variant", 0)

		# Calculate world position
		var world_block_pos = Vector3i(world_position) + block_pos

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

	# Place the purple beacon on top
	if _game != null:
		var beacon = Node3D.new()
		beacon.set_script(UndervoidBeacon)
		_game.add_child(beacon)
		beacon.global_position = world_position + template.beacon_pos
		print("🟣 Placed purple beacon at ", beacon.global_position)

	# Spawn Abyss Golem guardian(s) near the structure
	var guardian_count = _spawn_structure_guardians(world_position, template)

	# Clean up temporary VoxelViewer
	temp_viewer.queue_free()

	print("🟣 Placed ", blocks_placed, " blocks for Undervoid structure '", template.name, "'")

	# Register structure with UndervoidRegistry
	if _registry:
		_registry.register_structure(world_position, template.name, depth, guardian_count)

	return true


func can_spawn_at(world_position: Vector3, structure_size: Vector3i) -> bool:
	"""Check if there's enough solid ground at this position to spawn a structure"""
	if _terrain == null:
		return false

	var voxel_tool = _terrain.get_voxel_tool()
	if voxel_tool == null:
		return false

	# Check if there are solid blocks below (at least 3x3 solid foundation)
	var solid_count = 0
	var total_checks = 0

	for x in range(-1, 2):
		for z in range(-1, 2):
			total_checks += 1
			var check_pos = Vector3i(world_position) + Vector3i(x, -1, z)
			var voxel = voxel_tool.get_voxel(check_pos)
			if voxel != 0:  # Not air
				solid_count += 1

	# Need at least 7 out of 9 blocks solid
	return solid_count >= 7


func _spawn_structure_guardians(world_position: Vector3, template: UndervoidStructures.UndervoidStructure) -> int:
	"""Spawn Abyss Golem guardian(s) around the structure. Returns guardian count."""
	if _game == null:
		return 0

	# Scale guardians with structure size
	var num_guardians = 1
	var structure_volume = template.size.x * template.size.z

	if structure_volume >= 400:  # Void Fortress (30x30 = 900)
		num_guardians = 6  # Heavily guarded!
	elif structure_volume >= 300:  # Foundry Complex (20x20 = 400)
		num_guardians = 4
	elif structure_volume >= 150:  # Mining Camp (15x15 = 225)
		num_guardians = 3
	elif structure_volume >= 80:  # Mechanical Outpost (9x9 = 81)
		num_guardians = 2
	else:  # Small structures
		num_guardians = 1

	# Spawn positions around the structure perimeter
	var spawn_offsets = []

	# Add cardinal directions
	spawn_offsets.append(Vector3(template.size.x + 2, 1, template.size.z / 2))  # East
	spawn_offsets.append(Vector3(-2, 1, template.size.z / 2))  # West
	spawn_offsets.append(Vector3(template.size.x / 2, 1, template.size.z + 2))  # South
	spawn_offsets.append(Vector3(template.size.x / 2, 1, -2))  # North

	# Add diagonal corners for large structures
	if num_guardians > 4:
		spawn_offsets.append(Vector3(template.size.x + 2, 1, template.size.z + 2))  # SE
		spawn_offsets.append(Vector3(-2, 1, template.size.z + 2))  # SW
		spawn_offsets.append(Vector3(template.size.x + 2, 1, -2))  # NE
		spawn_offsets.append(Vector3(-2, 1, -2))  # NW

	# Shuffle for variety
	spawn_offsets.shuffle()

	for i in range(num_guardians):
		var spawn_pos = world_position + spawn_offsets[i % spawn_offsets.size()]
		_spawn_abyss_golem(spawn_pos)

	return num_guardians


func _spawn_abyss_golem(position: Vector3):
	"""Spawn a single Abyss Golem at the specified position"""
	var golem = Node3D.new()
	golem.set_script(AbyssGolem)

	_game.add_child(golem)
	golem.global_position = position

	print("🟣 Spawned Abyss Golem guardian at ", position)
