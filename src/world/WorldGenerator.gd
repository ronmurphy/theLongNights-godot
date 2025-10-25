extends Node3D
## WorldGenerator - Handles voxel terrain generation
## CRITICAL FIX: Never regenerates saved chunks - persistence is source of truth
## This is where Minecraft-like world creation happens

class_name WorldGenerator

# Constants
const CHUNK_SIZE = 12  # 12x12x12 voxels per chunk (Minecraft-like, optimized for lower-end hardware)
const WORLD_HEIGHT = 256
const RENDER_DISTANCE = 3  # chunks in each direction
const WORLD_SEED = 12345  # Should be configurable per world
const BASE_HEIGHT = 32  # Base terrain height
const HEIGHT_VARIATION = 16  # Max height variation (+/- from base)

# Voxel data (0 = empty, 1 = solid)
var chunks: Dictionary = {}  # Dictionary[Vector3i, Array] - RAM cache only
var persistence: ChunkPersistence
var chunk_views: Dictionary = {}  # Dictionary[Vector3i, ChunkView] - visual representations
var player_ref: Node3D = null  # Reference to player for infinite terrain
var last_player_chunk: Vector3i = Vector3i(999999, 999999, 999999)  # Track player chunk position
var texture_manager: BlockTextureManager
var noise: FastNoiseLite  # Terrain height noise

func _ready() -> void:
	print("WorldGenerator initializing...")

	# Create noise generator for terrain
	noise = FastNoiseLite.new()
	noise.seed = WORLD_SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.02  # Lower = smoother, larger features

	# Create texture manager
	texture_manager = BlockTextureManager.new()
	add_child(texture_manager)

	# Create persistence
	persistence = ChunkPersistence.new()
	add_child(persistence)

	generate_world()

func generate_world() -> void:
	print("Generating initial spawn chunks...")

	# Load or generate initial spawn area (multiple Y levels for terrain)
	for x in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
		for z in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
			# Generate chunks at different heights
			for y in range(0, 5):  # Y chunks 0-4 (covers heights 0-60)
				_load_or_generate_chunk(Vector3i(x, y, z))

	print("Initial spawn chunks loaded. Infinite terrain system active.")

## Set player reference (called by Main.gd after player is created)
func set_player(player: Node3D) -> void:
	player_ref = player
	print("Player reference set for infinite terrain")

## Update terrain based on player position (called every frame)
func _process(_delta: float) -> void:
	if player_ref == null:
		return

	# Get current player chunk position
	var player_chunk = Vector3i(
		floori(player_ref.position.x / CHUNK_SIZE),
		0,  # Only load chunks at y=0 for now (ground level)
		floori(player_ref.position.z / CHUNK_SIZE)
	)

	# Only update if player moved to a different chunk
	if player_chunk == last_player_chunk:
		return

	last_player_chunk = player_chunk

	# Load chunks around player
	_update_chunks_around_player(player_chunk)

## Load/unload chunks based on player position
func _update_chunks_around_player(player_chunk: Vector3i) -> void:
	# Load chunks in render distance
	for x in range(player_chunk.x - RENDER_DISTANCE, player_chunk.x + RENDER_DISTANCE + 1):
		for z in range(player_chunk.z - RENDER_DISTANCE, player_chunk.z + RENDER_DISTANCE + 1):
			# Load multiple Y levels for terrain
			for y in range(0, 5):  # Y chunks 0-4
				var chunk_pos = Vector3i(x, y, z)

				# Skip if already loaded
				if chunks.has(chunk_pos):
					continue

				# Load/generate this chunk
				_load_or_generate_chunk(chunk_pos)

	# Unload chunks outside render distance
	var chunks_to_unload: Array[Vector3i] = []
	for chunk_pos in chunks.keys():
		var distance = max(
			abs(chunk_pos.x - player_chunk.x),
			abs(chunk_pos.z - player_chunk.z)
		)

		# Unload if too far (render distance + 1 for buffer)
		if distance > RENDER_DISTANCE + 1:
			chunks_to_unload.append(chunk_pos)

	# Actually unload the chunks
	for chunk_pos in chunks_to_unload:
		_unload_chunk(chunk_pos)

## Unload a chunk from memory (saves are already on disk)
func _unload_chunk(chunk_pos: Vector3i) -> void:
	# Remove from RAM
	chunks.erase(chunk_pos)

	# Remove visual representation
	if chunk_views.has(chunk_pos):
		var chunk_view = chunk_views[chunk_pos]
		chunk_view.queue_free()
		chunk_views.erase(chunk_pos)

	print("📤 Unloaded chunk %s" % chunk_pos)

## Load chunk from disk, or generate if new
## CRITICAL: We prefer disk over regeneration
func _load_or_generate_chunk(chunk_pos: Vector3i) -> void:
	# Try to load from disk first
	var chunk_data = persistence.load_chunk(chunk_pos)

	# If loaded, apply any modifications and use it
	if chunk_data.size() > 0:
		chunk_data = persistence.apply_modifications(chunk_pos, chunk_data)
		chunks[chunk_pos] = chunk_data
		_render_chunk(chunk_pos, chunk_data)
		return

	# Only generate if file doesn't exist
	var generated_data = _generate_chunk_data(chunk_pos)
	chunks[chunk_pos] = generated_data

	# Save to disk immediately so it's never regenerated again
	persistence.save_chunk(chunk_pos, generated_data, WORLD_SEED)

	# Render the chunk
	_render_chunk(chunk_pos, generated_data)

## Generate new chunk data (only called for new chunks)
func _generate_chunk_data(chunk_pos: Vector3i) -> Array:
	var chunk_data = []
	chunk_data.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
	chunk_data.fill(0)

	# Generate terrain with noise-based height
	for local_x in range(CHUNK_SIZE):
		for local_z in range(CHUNK_SIZE):
			# Get world position for this column
			var world_x = chunk_pos.x * CHUNK_SIZE + local_x
			var world_z = chunk_pos.z * CHUNK_SIZE + local_z

			# Sample noise for height (-1 to 1)
			var noise_value = noise.get_noise_2d(world_x, world_z)

			# Convert to actual height
			var height = BASE_HEIGHT + int(noise_value * HEIGHT_VARIATION)

			# Fill column with blocks
			for local_y in range(CHUNK_SIZE):
				var world_y = chunk_pos.y * CHUNK_SIZE + local_y

				# Determine block type based on depth
				var block_type = 0  # Air by default
				if world_y <= height:
					if world_y == height:
						block_type = 1  # Grass on top
					elif world_y > height - 4:
						block_type = 2  # Dirt layer (3 blocks deep)
					else:
						block_type = 3  # Stone below

				# Set voxel
				if block_type > 0:
					var index = local_y * CHUNK_SIZE * CHUNK_SIZE + local_z * CHUNK_SIZE + local_x
					chunk_data[index] = block_type

	return chunk_data

## Get voxel at world position
func get_voxel(world_pos: Vector3i) -> int:
	var chunk_pos = Vector3i(
		floori(float(world_pos.x) / CHUNK_SIZE),
		floori(float(world_pos.y) / CHUNK_SIZE),
		floori(float(world_pos.z) / CHUNK_SIZE)
	)

	if not chunks.has(chunk_pos):
		_load_or_generate_chunk(chunk_pos)

	var local_pos = Vector3i(
		world_pos.x % CHUNK_SIZE,
		world_pos.y % CHUNK_SIZE,
		world_pos.z % CHUNK_SIZE
	)

	var chunk = chunks[chunk_pos]
	var index = local_pos.y * CHUNK_SIZE * CHUNK_SIZE + local_pos.z * CHUNK_SIZE + local_pos.x
	return chunk[index] if index < chunk.size() else 0

## Set voxel at world position AND record modification
func set_voxel(world_pos: Vector3i, value: int) -> void:
	var chunk_pos = Vector3i(
		floori(float(world_pos.x) / CHUNK_SIZE),
		floori(float(world_pos.y) / CHUNK_SIZE),
		floori(float(world_pos.z) / CHUNK_SIZE)
	)

	if not chunks.has(chunk_pos):
		_load_or_generate_chunk(chunk_pos)

	var local_pos = Vector3i(
		world_pos.x % CHUNK_SIZE,
		world_pos.y % CHUNK_SIZE,
		world_pos.z % CHUNK_SIZE
	)

	var chunk = chunks[chunk_pos]
	var index = local_pos.y * CHUNK_SIZE * CHUNK_SIZE + local_pos.z * CHUNK_SIZE + local_pos.x

	if index < chunk.size():
		var old_value = chunk[index]
		chunk[index] = value

		# Record this modification to disk
		persistence.record_modification(chunk_pos, local_pos, old_value, value)
		print("Modified voxel at %s (chunk %s): %d -> %d" % [world_pos, chunk_pos, old_value, value])

## Create a visual representation of a chunk and add it to the scene
func _render_chunk(chunk_pos: Vector3i, chunk_data: Array) -> void:
	# Create a ChunkView node
	var chunk_view = ChunkView.new()
	add_child(chunk_view)
	chunk_view.setup(chunk_pos, chunk_data, texture_manager)
	chunk_views[chunk_pos] = chunk_view
