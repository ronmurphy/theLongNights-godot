## Generates flying ruins with teleport stones
## Each ruin is a hollow room with floor, walls, and a teleport stone
class_name RuinGenerator

const Structure = preload("./structure.gd")

# Block type constants (must match generator.gd)
const RUIN_STONE = 33
const RUIN_FLOOR = 34
const TELEPORT_STONE = 35

## Size of the ruin room (X, Y, Z)
var size: Vector3i = Vector3i(16, 12, 16)

## Random number generator for variety
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Index of this ruin in the ruin list (for teleportation)
var ruin_index: int = 0

## Total number of ruins (needed for cycle calculation)
var total_ruins: int = 1


func _init(p_size: Vector3i = Vector3i(16, 12, 16), p_seed: int = 0, p_index: int = 0, p_total: int = 1):
	size = p_size
	rng.seed = p_seed
	ruin_index = p_index
	total_ruins = p_total


## Generate a ruin structure
## Returns a Structure with the ruin layout
func generate() -> Structure:
	var structure = Structure.new()
	structure.voxels = VoxelBuffer.new()
	structure.voxels.create(size.x, size.y, size.z)
	
	# Clear with air
	structure.voxels.fill(0)
	
	# Create the floor (bottom layer)
	_create_floor(structure.voxels)
	
	# Create the walls (hollow room)
	_create_walls(structure.voxels)
	
	# Place the teleport stone at a random location on the floor
	_place_teleport_stone(structure.voxels)
	
	return structure


## Create the floor layer
func _create_floor(voxels: VoxelBuffer) -> void:
	var floor_y = 0
	var floor_thickness = 2
	
	for y in range(floor_y, min(floor_y + floor_thickness, size.y)):
		for x in range(size.x):
			for z in range(size.z):
				voxels.set_voxel(RUIN_FLOOR, x, y, z)


## Create the walls (hollow room with stone walls)
func _create_walls(voxels: VoxelBuffer) -> void:
	var wall_height = size.y - 2  # Leave some space at top
	var wall_thickness = 1
	
	# X-axis walls (front and back)
	for x in range(size.x):
		for y in range(2, wall_height):
			for z in range(wall_thickness):
				voxels.set_voxel(RUIN_STONE, x, y, z)  # Front wall
				voxels.set_voxel(RUIN_STONE, x, y, size.z - 1 - z)  # Back wall
	
	# Z-axis walls (left and right)
	for z in range(size.z):
		for y in range(2, wall_height):
			for x in range(wall_thickness):
				voxels.set_voxel(RUIN_STONE, x, y, z)  # Left wall
				voxels.set_voxel(RUIN_STONE, size.x - 1 - x, y, z)  # Right wall


## Place the teleport stone at a random location on the floor
func _place_teleport_stone(voxels: VoxelBuffer) -> void:
	# Find a random empty spot on the floor (y=1, just above the floor)
	var attempts = 0
	var max_attempts = 50
	var placed = false
	
	while attempts < max_attempts and not placed:
		var x = rng.randi_range(2, size.x - 3)  # Avoid edges
		var z = rng.randi_range(2, size.z - 3)
		
		# Check if spot is empty (no wall)
		if voxels.get_voxel(x, 1, z) == RUIN_FLOOR:
			voxels.set_voxel(TELEPORT_STONE, x, 1, z)
			placed = true
		
		attempts += 1
	
	# Fallback placement if random fails
	if not placed:
		voxels.set_voxel(TELEPORT_STONE, size.x / 2, 1, size.z / 2)


## Get the world position of the teleport stone in this ruin
## This is used to spawn the player when they teleport to this ruin
func get_teleport_spawn_position(ruin_world_position: Vector3) -> Vector3:
	# The teleport stone is placed around the middle of the floor
	# Offset to center + slight upward so player isn't stuck in floor
	return ruin_world_position + Vector3(size.x / 2.0, 2.0, size.z / 2.0)
