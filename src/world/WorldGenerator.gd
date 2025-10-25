extends Node3D
## WorldGenerator - Handles voxel terrain generation
## This is where Minecraft-like world creation happens

class_name WorldGenerator

# Constants
const CHUNK_SIZE = 16  # 16x16x16 voxels per chunk
const WORLD_HEIGHT = 256
const RENDER_DISTANCE = 3  # chunks in each direction

# Voxel data (0 = empty, 1 = solid)
var chunks: Dictionary = {}  # Dictionary[Vector3i, Array]

func _ready() -> void:
	print("🌍 WorldGenerator initializing...")
	generate_world()

func generate_world() -> void:
	print("🏗️ Generating world...")

	# Generate a flat test world for now
	for x in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
		for z in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
			_generate_chunk(Vector3i(x, 0, z))

	print("✅ World generation complete")

func _generate_chunk(chunk_pos: Vector3i) -> void:
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

	chunks[chunk_pos] = chunk_data
	print("Generated chunk at %s" % chunk_pos)

## Get voxel at world position
func get_voxel(world_pos: Vector3i) -> int:
	var chunk_pos = Vector3i(
		world_pos.x / CHUNK_SIZE,
		world_pos.y / CHUNK_SIZE,
		world_pos.z / CHUNK_SIZE
	)

	if not chunks.has(chunk_pos):
		return 0  # Empty

	var local_pos = Vector3i(
		world_pos.x % CHUNK_SIZE,
		world_pos.y % CHUNK_SIZE,
		world_pos.z % CHUNK_SIZE
	)

	var chunk = chunks[chunk_pos]
	var index = local_pos.y * CHUNK_SIZE * CHUNK_SIZE + local_pos.z * CHUNK_SIZE + local_pos.x
	return chunk[index] if index < chunk.size() else 0

## Set voxel at world position
func set_voxel(world_pos: Vector3i, value: int) -> void:
	var chunk_pos = Vector3i(
		world_pos.x / CHUNK_SIZE,
		world_pos.y / CHUNK_SIZE,
		world_pos.z / CHUNK_SIZE
	)

	if not chunks.has(chunk_pos):
		_generate_chunk(chunk_pos)

	var local_pos = Vector3i(
		world_pos.x % CHUNK_SIZE,
		world_pos.y % CHUNK_SIZE,
		world_pos.z % CHUNK_SIZE
	)

	var chunk = chunks[chunk_pos]
	var index = local_pos.y * CHUNK_SIZE * CHUNK_SIZE + local_pos.z * CHUNK_SIZE + local_pos.x
	if index < chunk.size():
		chunk[index] = value
		print("Set voxel at %s to %d" % [world_pos, value])
