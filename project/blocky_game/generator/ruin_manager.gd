## Manages flying ruins generation, tracking, and teleportation between them
extends Node

const RuinGenerator = preload("./ruin_generator.gd")
const Structure = preload("./structure.gd")

## List of all ruin structures that have been generated
var ruins: Array = []

## World positions of each ruin (for quick lookup)
var ruin_positions: Array[Vector3] = []

## Currently active teleport stone positions (for collision detection)
## Maps world position -> ruin index
var teleport_stone_positions: Dictionary = {}

## Horizontal spacing between ruins (X and Z spread)
var horizontal_spacing: float = 150.0

## Vertical spacing between ruins (Y spread)
var vertical_spacing: float = 80.0

## Base altitude for ruins
var base_altitude: float = 100.0

## Number of ruins to generate
var num_ruins: int = 5

## Random seed for ruin generation
var ruin_seed: int = 0

## Whether the ruin system is initialized
var is_initialized: bool = false


func _ready() -> void:
	# Get seed from world config if available
	if FileAccess.file_exists("user://save/world.config"):
		var file = FileAccess.open("user://save/world.config", FileAccess.READ)
		if file != null:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_string) == OK:
				var data = json.data
				if typeof(data) == TYPE_DICTIONARY and "seed" in data:
					ruin_seed = data["seed"]


## Initialize the ruin system - generate all ruins
## Must be called before using the system
func initialize(p_num_ruins: int = 5) -> void:
	num_ruins = p_num_ruins
	generate_ruins()
	is_initialized = true


## Generate all ruins
func generate_ruins() -> void:
	ruins.clear()
	ruin_positions.clear()
	teleport_stone_positions.clear()
	
	for i in range(num_ruins):
		# Randomize size between 8x8x8 and 25x25x25
		var rng = RandomNumberGenerator.new()
		rng.seed = ruin_seed + i
		
		var size_base = rng.randi_range(8, 25)
		var size_height = rng.randi_range(8, 20)
		var ruin_size = Vector3i(size_base, size_height, size_base)
		
		# Create generator and generate ruin
		var generator = RuinGenerator.new(ruin_size, ruin_seed + i, i, num_ruins)
		var ruin_structure = generator.generate()
		ruins.append(ruin_structure)
		
		# Calculate world position (arrange in a circle or pattern)
		var world_pos = _calculate_ruin_position(i)
		ruin_structure.offset = world_pos
		ruin_positions.append(world_pos)
		
		# Register teleport stone position
		# The teleport stone is at the center of the floor
		var teleport_pos = world_pos + Vector3(ruin_size.x / 2.0, 1.0, ruin_size.z / 2.0)
		teleport_stone_positions[teleport_pos] = i


## Calculate world position for a ruin based on its index
## Arranges ruins in a circular pattern at different altitudes
func _calculate_ruin_position(index: int) -> Vector3:
	var angle = (TAU / num_ruins) * index
	var radius = horizontal_spacing * num_ruins / TAU
	
	var x = cos(angle) * radius
	var z = sin(angle) * radius
	var y = base_altitude + (index * vertical_spacing)
	
	return Vector3(x, y, z)


## Get the ruin structure at the given index
func get_ruin(index: int) -> Structure:
	if index >= 0 and index < ruins.size():
		return ruins[index]
	return null


## Get the world position of a ruin
func get_ruin_position(index: int) -> Vector3:
	if index >= 0 and index < ruin_positions.size():
		return ruin_positions[index]
	return Vector3.ZERO


## Get the next ruin index (cycle with wrapping)
## If you're on ruin 0, next is 1, on last ruin, next is 0
func get_next_ruin_index(current_index: int) -> int:
	return (current_index + 1) % num_ruins


## Check if a world position is a teleport stone
## Returns the ruin index if yes, -1 if no
func get_ruin_index_at_teleport(world_pos: Vector3, tolerance: float = 0.5) -> int:
	for teleport_pos in teleport_stone_positions:
		if world_pos.distance_to(teleport_pos) <= tolerance:
			return teleport_stone_positions[teleport_pos]
	return -1


## Get the spawn position when teleporting to a ruin
## This is where the player will appear after teleporting
func get_teleport_spawn_position(target_ruin_index: int) -> Vector3:
	if target_ruin_index >= 0 and target_ruin_index < ruins.size():
		var ruin = ruins[target_ruin_index]
		var ruin_pos = ruin_positions[target_ruin_index]
		var ruin_size = Vector3(ruin.voxels.get_size())
		
		# Spawn at center of ruin, slightly above the floor
		return ruin_pos + Vector3(ruin_size.x / 2.0, 3.0, ruin_size.z / 2.0)
	
	return Vector3.ZERO


## Debug: Print all ruin information
func debug_print_ruins() -> void:
	print("=== RUIN SYSTEM DEBUG ===")
	print("Total ruins: ", num_ruins)
	print("Horizontal spacing: ", horizontal_spacing)
	print("Vertical spacing: ", vertical_spacing)
	print("Base altitude: ", base_altitude)
	print("")
	
	for i in range(ruins.size()):
		var ruin = ruins[i]
		var pos = ruin_positions[i]
		var size = ruin.voxels.get_size()
		print("Ruin %d: pos=%.1f,%.1f,%.1f size=%dx%dx%d" % [i, pos.x, pos.y, pos.z, size.x, size.y, size.z])
