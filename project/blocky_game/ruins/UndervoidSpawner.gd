extends Node

# Spawns Undervoid structures into deep caves
# Places structures with purple beacon lights on large islands

const UndervoidStructures = preload("res://blocky_game/ruins/undervoid_structures.gd")
const UndervoidCityBuilding = preload("res://blocky_game/ruins/undervoid_city_building.gd")
const UndervoidBeacon = preload("res://blocky_game/items/light_orb/undervoid_beacon.gd")
const AbyssGolem = preload("res://blocky_game/entities/abyss_golem.gd")

@onready var _undervoid_structures: UndervoidStructures = null
@onready var _city_building: UndervoidCityBuilding = null  # City building templates
@onready var _blocks = null  # Will be set to the Blocks node
@onready var _terrain = null  # Will be set to the VoxelTerrain node
@onready var _game = null  # Game node for placing beacons and entities
@onready var _registry = null  # Will be set to UndervoidRegistry
@onready var _generator = null  # Generator for height queries

# Chunk-based spawning system
const CHUNK_SIZE = 16  # Godot voxel default chunk size
const STRUCTURE_SPAWN_CHANCE = 0.08  # 8% chance per chunk (roughly 1 in 12-13 chunks)
const CITY_BUILDING_SPAWN_CHANCE = 0.10  # 10% chance per chunk at city level
const CITY_LEVEL_MIN_Y = -490  # Top of rust hills layer
const CITY_LEVEL_MAX_Y = -490  # Buildings spawn at this level (above rust hills)
var _processed_chunks: Dictionary = {}  # Track which chunks we've checked: Vector2i -> bool
var _processed_city_chunks: Dictionary = {}  # Track city chunks separately
var _world_seed: int = 131183  # Default seed (matches world gen)
var _check_timer: float = 0.0
const CHECK_INTERVAL = 3.0  # Check for new chunks every 3 seconds


func _ready():
	print("🟣 UndervoidSpawner ready - chunk-based spawning enabled")


func initialize(undervoid_structures: UndervoidStructures, blocks_node: Node, terrain_node: Node, game_node: Node, registry, generator_node: Node = null):
	"""Initialize the spawner with required dependencies"""
	_undervoid_structures = undervoid_structures
	_blocks = blocks_node
	_terrain = terrain_node
	_game = game_node
	_registry = registry
	_generator = generator_node

	# Initialize city building system
	_city_building = UndervoidCityBuilding.new()
	_city_building._ready()  # Create building templates

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

			# Check for normal Undervoid structures (mid-levels)
			if not _processed_chunks.has(chunk_key):
				_processed_chunks[chunk_key] = true
				if _should_chunk_have_structure(cx, cz):
					_spawn_structure_in_chunk(cx, cz)

			# Check for city-level buildings (above rust hills Y -490 to -500)
			if not _processed_city_chunks.has(chunk_key):
				_processed_city_chunks[chunk_key] = true
				if player_y <= CITY_LEVEL_MAX_Y:  # Player deep enough for city spawning
					if _should_chunk_have_city_building(cx, cz):
						_spawn_city_building_in_chunk(cx, cz)


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


func _should_chunk_have_city_building(chunk_x: int, chunk_z: int) -> bool:
	"""Deterministically check if a chunk should have a city building at Y -510-512"""
	# Use different seed offset for city chunks to avoid conflicts
	var chunk_seed = (_world_seed * 2) + (chunk_x * 374761393) + (chunk_z * 668265263)

	var rng = RandomNumberGenerator.new()
	rng.seed = chunk_seed
	var random_value = rng.randf()

	# Check if this chunk should have a city building (10% chance)
	return random_value < CITY_BUILDING_SPAWN_CHANCE


func _spawn_city_building_in_chunk(chunk_x: int, chunk_z: int):
	"""Spawn a city building in a chunk at Y -510-512 (bedrock level)"""
	# Create RNG for this chunk
	var chunk_seed = (_world_seed * 2) + (chunk_x * 374761393) + (chunk_z * 668265263)
	var rng = RandomNumberGenerator.new()
	rng.seed = chunk_seed

	# Pick a random position within the chunk with margin for building size
	var local_x = rng.randi_range(2, CHUNK_SIZE - 10)
	var local_z = rng.randi_range(2, CHUNK_SIZE - 10)

	# Convert to world coordinates
	var world_x = (chunk_x * CHUNK_SIZE) + local_x
	var world_z = (chunk_z * CHUNK_SIZE) + local_z

	# Buildings spawn above rust hills (Y -490)
	# This places them on top of the generated rust hills terrain
	var spawn_y = CITY_LEVEL_MAX_Y

	var spawn_pos = Vector3(world_x, spawn_y, world_z)

	print("🟣 City chunk-spawning building at chunk (%d, %d) -> world pos %s" % [chunk_x, chunk_z, spawn_pos])

	# Spawn the city building
	spawn_city_building_at(spawn_pos)


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
	# Player falls FAST through underground, so chunks may not be ready immediately
	await get_tree().create_timer(4.0).timeout

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
		# Wait additional time for deep chunks (they take longer to generate)
		await get_tree().create_timer(3.0).timeout

		# Check again
		if not voxel_tool.is_area_editable(structure_aabb):
			push_warning("🟣 Structure area still not editable, waiting even longer...")
			await get_tree().create_timer(3.0).timeout

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

	# If this is a Void Fortress, spawn surrounding city buildings in a ring pattern
	if template.name == "Void Fortress":
		print("🟣 Void Fortress detected! Spawning surrounding city cluster...")
		_spawn_city_ring_around_fortress(world_position, template)

	# Clean up temporary VoxelViewer
	temp_viewer.queue_free()

	print("🟣 Placed ", blocks_placed, " blocks for Undervoid structure '", template.name, "'")

	# Register structure with UndervoidRegistry
	if _registry:
		_registry.register_structure(world_position, template.name, depth, guardian_count)

	return true


func spawn_city_building_at(world_position: Vector3) -> bool:
	"""
	Spawn a city building at the specified position (Y -510-512)
	Returns true if successful
	"""
	if _city_building == null:
		push_error("UndervoidSpawner not initialized - UndervoidCityBuilding is null")
		return false

	if _terrain == null:
		push_error("UndervoidSpawner not initialized - Terrain is null")
		return false

	# Get a random city building template
	var building: UndervoidCityBuilding.CityBuilding = _city_building.get_random_city_building()

	if building == null:
		push_warning("No city building templates available")
		return false

	print("🟣 Spawning city building '", building.name, "' at position: ", world_position)

	# FORCE CHUNK GENERATION: Create temporary VoxelViewer
	var temp_viewer = VoxelViewer.new()
	temp_viewer.position = world_position
	temp_viewer.view_distance = 16
	temp_viewer.requires_visuals = true
	temp_viewer.requires_collisions = true
	_terrain.add_child(temp_viewer)

	# Wait for chunks to generate at city level
	await get_tree().create_timer(2.0).timeout

	# Get the voxel tool for editing terrain
	var voxel_tool = _terrain.get_voxel_tool()
	if voxel_tool == null:
		temp_viewer.queue_free()
		push_error("Failed to get voxel tool from terrain")
		return false

	# Check if area is editable (chunks loaded) - include platform area in check
	var world_pos_i = Vector3i(world_position)
	var platform_width = building.footprint.x + 2
	var platform_depth = building.footprint.y + 2
	var platform_height = 5

	var building_aabb = AABB(Vector3(world_position) + Vector3(-1, -platform_height, -1),
							  Vector3(platform_width, building.height + platform_height, platform_depth))

	if not voxel_tool.is_area_editable(building_aabb):
		push_warning("🟣 City building area not loaded yet at ", world_position, " - waiting longer...")
		await get_tree().create_timer(3.0).timeout

		if not voxel_tool.is_area_editable(building_aabb):
			temp_viewer.queue_free()
			push_error("🟣 Failed to load chunks for city building at ", world_position)
			return false

	# First, place the foundation platform beneath the building
	var platform_blocks_placed = _place_foundation_platform(world_pos_i, building, voxel_tool)

	# Place each block in the building template
	var blocks_placed = 0

	for block_data in building.blocks:
		var block_pos: Vector3i = block_data.pos
		var block_id: int = block_data.block_id

		# Calculate world position
		var world_block_pos = world_pos_i + block_pos

		# Get the block and its voxel ID
		var block = _blocks.get_block(block_id)
		if block == null:
			push_warning("Block ID ", block_id, " not found, skipping")
			continue

		# Get the voxel value to place
		var voxel_id = block.base_info.voxels[0]  # City buildings use single variant

		# Place the block
		voxel_tool.set_voxel(world_block_pos, voxel_id)
		blocks_placed += 1

	# Clean up temporary VoxelViewer
	temp_viewer.queue_free()

	print("🟣 Placed ", platform_blocks_placed, " foundation blocks + ", blocks_placed, " blocks for city building '", building.name, "'")

	# Register building with UndervoidRegistry
	if _registry:
		_registry.register_structure(world_position, building.name + " (City)", CITY_LEVEL_MAX_Y, 0)

	return true


func _place_foundation_platform(world_pos: Vector3i, building: UndervoidCityBuilding.CityBuilding, voxel_tool) -> int:
	"""
	Place a foundation platform and support pillars beneath a city building
	The platform is larger than the building footprint (provides structural security)
	Platform has a hole in the middle to suggest "ruins below"
	Support pillars extend down to rust hills floor (Y -505-506)

	Platform structure:
	- Footprint: Building size + 2 blocks margin (e.g., 6x6 building = 8x8 platform)
	- Platform height: 5 blocks thick (Y -495 to Y -490)
	- Support pillars: Extend from Y -495 down to Y -505 (bedrock floor)
	- Style: Solid with hole in center showing "previous ruins" below
	"""
	var blocks_placed = 0

	# Calculate platform dimensions (2 blocks larger on each side)
	var platform_width = building.footprint.x + 2
	var platform_depth = building.footprint.y + 2
	var platform_height = 5  # Y -495 to -490 (5 blocks thick)
	var platform_start_y = CITY_LEVEL_MAX_Y - platform_height  # Y -495
	var pillar_bottom_y = -505  # Extend down to rust hills floor

	# Offset to center platform on building (1 block margin on each side)
	var offset_x = -1
	var offset_z = -1

	# Use rust block for platform (matches theme)
	var platform_block_id = 29  # RUST_BLOCK
	var block = _blocks.get_block(platform_block_id)
	if block == null:
		push_warning("Platform block not found, skipping foundation")
		return 0
	var platform_voxel_id = block.base_info.voxels[0]

	# Place solid platform with hole in middle
	for y in range(platform_height):
		var platform_y = platform_start_y + y

		for x in range(platform_width):
			for z in range(platform_depth):
				# Don't add world_pos.y - platform_y is absolute world Y already
				var world_block_pos = Vector3i(world_pos.x + offset_x + x, platform_y, world_pos.z + offset_z + z)

				# Determine if this block should be filled or part of the hole
				var is_edge = (x == 0 or x == platform_width - 1 or z == 0 or z == platform_depth - 1)
				var is_center = (x >= 2 and x < platform_width - 2 and z >= 2 and z < platform_depth - 2)

				# Create hole in center (leave empty to show ruins below)
				# Keep outer ring solid for structural integrity
				if is_edge or (y == 0 and is_center):  # Bottom and edges solid, rest of center hollow
					if voxel_tool.is_area_editable(AABB(Vector3(world_block_pos), Vector3(1, 1, 1))):
						voxel_tool.set_voxel(world_block_pos, platform_voxel_id)
						blocks_placed += 1
					else:
						push_warning("🟣 Platform block area not editable at ", world_block_pos)

	# Place support pillars from platform down to rust hills floor
	# Pillars at the edges for structural support
	var pillar_height = platform_start_y - pillar_bottom_y  # Distance from platform to floor

	for x in range(platform_width):
		for z in range(platform_depth):
			# Place pillars at all edge positions (creates supporting structure)
			var is_edge = (x == 0 or x == platform_width - 1 or z == 0 or z == platform_depth - 1)

			if is_edge:
				# Place pillar blocks from just below platform down to rust hills floor
				for pillar_y in range(pillar_height):
					var pillar_world_y = platform_start_y - 1 - pillar_y  # Start just below platform
					var world_block_pos = Vector3i(world_pos.x + offset_x + x, pillar_world_y, world_pos.z + offset_z + z)

					if voxel_tool.is_area_editable(AABB(Vector3(world_block_pos), Vector3(1, 1, 1))):
						voxel_tool.set_voxel(world_block_pos, platform_voxel_id)
						blocks_placed += 1

	if blocks_placed > 0:
		print("🟣 Placed ", blocks_placed, " foundation platform + pillar blocks")
	return blocks_placed


func _spawn_city_ring_around_fortress(fortress_pos: Vector3, fortress_template: UndervoidStructures.UndervoidStructure) -> void:
	"""
	Spawn city buildings in a ring pattern around a Void Fortress
	Creates a natural settlement cluster around the fortress beacon light

	Ring pattern:
	- 6-8 city buildings placed in cardinal + diagonal directions
	- Buildings spawn at Y -490 (above rust hills)
	- Distance from fortress: 40-60 blocks outward
	- Varied spacing to avoid perfect grid look
	"""
	var ring_count = 7  # Number of buildings in the ring
	var min_distance = 40.0
	var max_distance = 60.0

	# Create deterministic RNG based on fortress position
	var fortress_seed = _world_seed + int(fortress_pos.x * 1000) + int(fortress_pos.z * 2000)
	var rng = RandomNumberGenerator.new()
	rng.seed = fortress_seed

	for i in range(ring_count):
		# Calculate angle around fortress (divide circle into ring_count sections)
		var angle = (TAU / ring_count) * i
		# Add some randomness to angle for organic feel
		angle += rng.randf_range(-0.3, 0.3)

		# Calculate distance with randomness
		var distance = rng.randf_range(min_distance, max_distance)

		# Calculate building position in ring
		var offset_x = cos(angle) * distance
		var offset_z = sin(angle) * distance

		var building_spawn_pos = Vector3(
			fortress_pos.x + offset_x,
			CITY_LEVEL_MAX_Y,  # Y -490
			fortress_pos.z + offset_z
		)

		print("🟣 Spawning ring city building %d/%d at angle %.1f° distance %.1f blocks" % [i + 1, ring_count, angle * 180.0 / PI, distance])

		# Spawn the building (async, so it won't block)
		spawn_city_building_at(building_spawn_pos)


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
