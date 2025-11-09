extends Node

# UndervoidEntranceGenerator - Creates surface entrance holes to the Undervoid
# 3x3 air shaft surrounded by rust pipes, extends up for visibility
# Purple beacon light at night to help players find them

const UndervoidBeacon = preload("res://blocky_game/items/light_orb/undervoid_beacon.gd")

var _registry = null
var _terrain = null
var _game = null
var _blocks = null

# Generator constants (from generator.gd)
const RUST_PIPE = 50

# Chunk-based spawning system
const CHUNK_SIZE = 16  # Godot voxel default chunk size
const ENTRANCE_SPAWN_CHANCE = 0.02  # 2% chance per chunk (rarer than structures)
var _processed_chunks: Dictionary = {}  # Track which chunks we've checked: Vector2i -> bool
var _world_seed: int = 131183  # Default seed (matches world gen)
var _check_timer: float = 0.0
const CHECK_INTERVAL = 5.0  # Check for new chunks every 5 seconds

func initialize(registry, terrain, game, blocks):
	"""Initialize with required dependencies"""
	_registry = registry
	_terrain = terrain
	_game = game
	_blocks = blocks
	print("🟣 UndervoidEntranceGenerator initialized - chunk-based spawning enabled")


func _ready():
	print("🟣 UndervoidEntranceGenerator ready - surface entrances will spawn as you explore")


func _process(delta: float):
	"""Periodically check for new chunks to spawn entrances in"""
	_check_timer += delta

	if _check_timer >= CHECK_INTERVAL:
		_check_timer = 0.0
		_check_nearby_chunks_for_entrances()


func _check_nearby_chunks_for_entrances():
	"""Check chunks around player and spawn entrances if needed"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Get player's chunk coordinates
	var player_pos = player.global_position
	var player_chunk_x = int(floor(player_pos.x / CHUNK_SIZE))
	var player_chunk_z = int(floor(player_pos.z / CHUNK_SIZE))

	# Check chunks in a radius around player (10 chunks = 160 blocks)
	const CHUNK_CHECK_RADIUS = 10

	for cx in range(player_chunk_x - CHUNK_CHECK_RADIUS, player_chunk_x + CHUNK_CHECK_RADIUS + 1):
		for cz in range(player_chunk_z - CHUNK_CHECK_RADIUS, player_chunk_z + CHUNK_CHECK_RADIUS + 1):
			var chunk_key = Vector2i(cx, cz)

			# Skip if we've already processed this chunk
			if _processed_chunks.has(chunk_key):
				continue

			# Mark as processed
			_processed_chunks[chunk_key] = true

			# Check if this chunk should have an entrance (deterministic)
			if _should_chunk_have_entrance(cx, cz):
				# Spawn entrance in this chunk
				_spawn_entrance_in_chunk(cx, cz)


func _should_chunk_have_entrance(chunk_x: int, chunk_z: int) -> bool:
	"""Deterministically check if a chunk should have an Undervoid entrance"""
	# Create a unique seed for this chunk (different offset than structures)
	var chunk_seed = _world_seed + (chunk_x * 982451653) + (chunk_z * 1664525) + 7777

	var rng = RandomNumberGenerator.new()
	rng.seed = chunk_seed
	var random_value = rng.randf()

	# Check if this chunk should have an entrance (2% chance - rarer than structures)
	return random_value < ENTRANCE_SPAWN_CHANCE


func _spawn_entrance_in_chunk(chunk_x: int, chunk_z: int):
	"""Spawn an Undervoid entrance somewhere in this chunk"""
	# Create RNG for this chunk
	var chunk_seed = _world_seed + (chunk_x * 982451653) + (chunk_z * 1664525) + 7777
	var rng = RandomNumberGenerator.new()
	rng.seed = chunk_seed

	# Pick a random position within the chunk
	var local_x = rng.randi_range(0, CHUNK_SIZE - 1)
	var local_z = rng.randi_range(0, CHUNK_SIZE - 1)

	# Convert to world coordinates
	var world_x = (chunk_x * CHUNK_SIZE) + local_x
	var world_z = (chunk_z * CHUNK_SIZE) + local_z

	print("🟣 Chunk-spawning entrance at chunk (%d, %d) -> world pos X:%d Z:%d" % [chunk_x, chunk_z, world_x, world_z])

	# Spawn the entrance (async)
	generate_entrance_at(world_x, world_z)


func generate_entrance_at(world_x: int, world_z: int):
	"""Generate a single entrance hole at the given X,Z coordinates"""
	if _terrain == null or _blocks == null:
		push_error("UndervoidEntranceGenerator: Missing dependencies")
		return

	# Find ground level at this position
	var voxel_tool = _terrain.get_voxel_tool()
	voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE

	var ground_y = _find_ground_level(world_x, world_z, voxel_tool)
	if ground_y == -1:
		return  # Failed to find ground

	var entrance_pos = Vector3(world_x, ground_y, world_z)

	print("🟣 Generating Undervoid entrance at X:", world_x, " Z:", world_z, " (ground Y:", ground_y, ")")

	# FORCE CHUNK GENERATION: Create temporary VoxelViewer
	var temp_viewer = VoxelViewer.new()
	temp_viewer.position = entrance_pos
	temp_viewer.view_distance = 16
	temp_viewer.requires_visuals = true
	temp_viewer.requires_collisions = true
	_terrain.add_child(temp_viewer)

	# Wait for chunks
	await get_tree().create_timer(2.0).timeout

	# Create the entrance shaft
	_create_entrance_shaft(world_x, ground_y, world_z, voxel_tool)

	# Add purple beacon light at entrance (visible at night)
	_create_entrance_beacon(entrance_pos)

	# Register with registry
	var depth = abs(ground_y - (-150))  # Distance from surface to Undervoid start
	if _registry:
		_registry.register_entrance(entrance_pos, depth)

	# Cleanup
	temp_viewer.queue_free()

	print("🟣 Undervoid entrance created!")


func _find_ground_level(x: int, z: int, voxel_tool) -> int:
	"""Find the ground level at X,Z by raycasting down from sky"""
	var start_y = 100
	var hit = voxel_tool.raycast(Vector3(x, start_y, z), Vector3.DOWN, 200)

	if hit:
		return int(hit.position.y) + 1  # Top of the block
	return -1  # Failed


func _create_entrance_shaft(center_x: int, ground_y: int, center_z: int, voxel_tool):
	"""Create the entrance shaft - 3x3 air with rust pipe surround"""

	# Get rust pipe voxel ID
	var rust_pipe_block = _blocks.get_block(30)  # rust_pipe block ID
	var rust_pipe_voxel = rust_pipe_block.base_info.voxels[0]

	# Extend 3 blocks above ground for visibility
	var top_y = ground_y + 3
	# Go down to Y -20 (just before Undead Crypts)
	var bottom_y = -20

	# Create 5x5 structure
	for x in range(-2, 3):  # -2, -1, 0, 1, 2
		for z in range(-2, 3):
			var world_x = center_x + x
			var world_z = center_z + z

			# Determine if this is air (center 3x3) or pipe (outer ring)
			var is_center = abs(x) <= 1 and abs(z) <= 1

			for y in range(bottom_y, top_y + 1):
				var world_pos = Vector3i(world_x, y, world_z)

				if is_center:
					# Center 3x3 - air shaft
					voxel_tool.set_voxel(world_pos, 0)  # AIR
				else:
					# Outer ring - rust pipes (but only if we're clearing blocks)
					# Don't place pipes in air above ground
					if y <= ground_y:
						voxel_tool.set_voxel(world_pos, rust_pipe_voxel)
					else:
						# Above ground, place pipes to make it visible
						voxel_tool.set_voxel(world_pos, rust_pipe_voxel)


func _create_entrance_beacon(position: Vector3):
	"""Create a purple beacon at the entrance (dimmer than structure beacons)"""
	if _game == null:
		return

	var beacon = Node3D.new()
	beacon.set_script(UndervoidBeacon)
	_game.add_child(beacon)

	# Place beacon floating above entrance
	beacon.global_position = position + Vector3(0, 4, 0)

	# Make entrance beacons dimmer/smaller
	# Note: Would need to modify UndervoidBeacon to accept intensity parameter
	# For now, standard purple beacon

	print("🟣 Entrance beacon placed at ", beacon.global_position)


func generate_world_entrances(world_seed: int):
	"""Generate 3-5 entrance holes scattered across the world"""
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed + 9999  # Offset for entrance generation

	var num_entrances = rng.randi_range(3, 5)

	print("🟣 Generating ", num_entrances, " Undervoid entrances across the world...")

	for i in range(num_entrances):
		# Random position within spawn area (within 500 blocks of origin)
		var x = rng.randi_range(-500, 500)
		var z = rng.randi_range(-500, 500)

		# Ensure entrances are spread apart (at least 200 blocks)
		var too_close = false
		if _registry:
			for existing in _registry.get_all_entrances():
				var dist = Vector2(x, z).distance_to(Vector2(existing.position.x, existing.position.z))
				if dist < 200:
					too_close = true
					break

		if not too_close:
			await generate_entrance_at(x, z)
			# Delay between generations to avoid lag
			await get_tree().create_timer(1.0).timeout

	print("🟣 World entrance generation complete!")
