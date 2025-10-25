extends Node3D
## WorldGenerator - Handles voxel terrain generation
## CRITICAL FIX: Never regenerates saved chunks - persistence is source of truth
## This is where Minecraft-like world creation happens

class_name WorldGenerator

# Constants
const CHUNK_SIZE = 16  # 16x16x16 voxels per chunk
const WORLD_HEIGHT = 256
const RENDER_DISTANCE = 3  # chunks in each direction
const WORLD_SEED = 12345  # Should be configurable per world

# Voxel data (0 = empty, 1 = solid)
var chunks: Dictionary = {}  # Dictionary[Vector3i, Array] - RAM cache only
var persistence: ChunkPersistence

func _ready() -> void:
	print("🌍 WorldGenerator initializing...")
	persistence = ChunkPersistence.new()
	add_child(persistence)
	generate_world()

func generate_world() -> void:
	print("🏗️ Generating world...")

	# Load or generate a flat test world
	for x in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
		for z in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
			_load_or_generate_chunk(Vector3i(x, 0, z))

	print("✅ World generation complete")

## Load chunk from disk, or generate if new
## CRITICAL: We prefer disk over regeneration
func _load_or_generate_chunk(chunk_pos: Vector3i) -> void:
	# Try to load from disk first
	var chunk_data = persistence.load_chunk(chunk_pos)

	# If loaded, apply any modifications and use it
	if chunk_data.size() > 0:
		chunk_data = persistence.apply_modifications(chunk_pos, chunk_data)
		chunks[chunk_pos] = chunk_data
		return

	# Only generate if file doesn't exist
	var generated_data = _generate_chunk_data(chunk_pos)
	chunks[chunk_pos] = generated_data

	# Save to disk immediately so it's never regenerated again
	persistence.save_chunk(chunk_pos, generated_data, WORLD_SEED)

## Generate new chunk (only called for new chunks)
func _generate_chunk_data(chunk_pos: Vector3i) -> Array:
	var chunk_data = []
	chunk_data.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
	chunk_data.fill(0)

	# Fill with grass and dirt for now
	for local_x in range(CHUNK_SIZE):
		for local_z in range(CHUNK_SIZE):
			for local_y in range(CHUNK_SIZE):
				var world_y = chunk_pos.y * CHUNK_SIZE + local_y

				# Grass at y=0, dirt below
				if world_y == 0:
					var index = local_y * CHUNK_SIZE * CHUNK_SIZE + local_z * CHUNK_SIZE + local_x
					chunk_data[index] = 1  # Grass
				elif world_y < 0 and world_y > -5:
					var index = local_y * CHUNK_SIZE * CHUNK_SIZE + local_z * CHUNK_SIZE + local_x
					chunk_data[index] = 1  # Dirt

	return chunk_data

## Get voxel at world position
func get_voxel(world_pos: Vector3i) -> int:
	var chunk_pos = Vector3i(
		world_pos.x / CHUNK_SIZE,
		world_pos.y / CHUNK_SIZE,
		world_pos.z / CHUNK_SIZE
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
		world_pos.x / CHUNK_SIZE,
		world_pos.y / CHUNK_SIZE,
		world_pos.z / CHUNK_SIZE
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
		print("✏️ Modified voxel at %s (chunk %s): %d → %d" % [world_pos, chunk_pos, old_value, value])
