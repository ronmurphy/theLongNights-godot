extends Node

# UndervoidRegistry - Tracks Undervoid entrances and spawned structures
# Similar to RuinRegistry but for the deep underground

# Data structure for a surface entrance
class UndervoidEntrance:
	var position: Vector3  # World position at surface level
	var depth: int  # How deep the hole goes
	var discovered: bool = false  # Has player found this entrance?

	func _init(pos: Vector3, d: int):
		position = pos
		depth = d

# Data structure for a spawned Undervoid structure
class UndervoidStructure:
	var position: Vector3  # World position where structure spawned
	var structure_type: String  # Template name (e.g., "Void Fortress")
	var depth: int  # Y level where placed
	var guardian_count: int  # How many Abyss Golems guard it
	var chests_looted: Array[Vector3i] = []  # Track which chests opened
	var visited: bool = false  # Has player been here?

	func _init(pos: Vector3, type: String, d: int, guardians: int):
		position = pos
		structure_type = type
		depth = d
		guardian_count = guardians

# Registry storage
var _entrances: Array[UndervoidEntrance] = []
var _structures: Array[UndervoidStructure] = []
var _has_entered_undervoid: bool = false  # Track first-time entry
var _structures_generated: bool = false  # Prevent duplicate generation


func _ready():
	print("🟣 UndervoidRegistry initialized")


func register_entrance(world_position: Vector3, depth: int) -> UndervoidEntrance:
	"""Register a surface entrance to the Undervoid"""
	var entrance = UndervoidEntrance.new(world_position, depth)
	_entrances.append(entrance)

	print("🟣 Registered Undervoid entrance at ", world_position, " (depth: ", depth, ")")
	return entrance


func register_structure(world_position: Vector3, structure_type: String, depth: int, guardian_count: int) -> UndervoidStructure:
	"""Register a spawned Undervoid structure"""
	var structure = UndervoidStructure.new(world_position, structure_type, depth, guardian_count)
	_structures.append(structure)

	print("🟣 Registered Undervoid structure: ", structure_type, " at ", world_position, " (Y ", depth, ") with ", guardian_count, " guardians")
	return structure


func mark_entrance_discovered(entrance_position: Vector3):
	"""Mark an entrance as discovered when player finds it"""
	for entrance in _entrances:
		if entrance.position.distance_to(entrance_position) < 5.0:
			if not entrance.discovered:
				entrance.discovered = true
				print("🟣 Discovered Undervoid entrance at ", entrance.position)
			return


func mark_structure_visited(structure_position: Vector3):
	"""Mark a structure as visited when player reaches it"""
	for structure in _structures:
		if structure.position.distance_to(structure_position) < 20.0:
			if not structure.visited:
				structure.visited = true
				print("🟣 Visited Undervoid structure: ", structure.structure_type)
			return


func get_all_entrances() -> Array[UndervoidEntrance]:
	"""Return all registered Undervoid entrances"""
	return _entrances


func get_nearest_entrance(from_position: Vector3) -> UndervoidEntrance:
	"""Get the closest entrance to a position"""
	if _entrances.is_empty():
		return null

	var nearest = _entrances[0]
	var nearest_dist = from_position.distance_to(nearest.position)

	for entrance in _entrances:
		var dist = from_position.distance_to(entrance.position)
		if dist < nearest_dist:
			nearest = entrance
			nearest_dist = dist

	return nearest


func get_nearest_structure(from_position: Vector3) -> UndervoidStructure:
	"""Get the closest structure to a position (for compass navigation)"""
	if _structures.is_empty():
		return null

	var nearest = _structures[0]
	var nearest_dist = from_position.distance_to(nearest.position)

	for structure in _structures:
		var dist = from_position.distance_to(structure.position)
		if dist < nearest_dist:
			nearest = structure
			nearest_dist = dist

	return nearest


func get_all_entrances() -> Array[UndervoidEntrance]:
	"""Get all registered entrances"""
	return _entrances


func get_all_structures() -> Array[UndervoidStructure]:
	"""Get all spawned structures"""
	return _structures


func set_entered_undervoid(entered: bool):
	"""Track that player has entered the Undervoid for first time"""
	if entered and not _has_entered_undervoid:
		_has_entered_undervoid = true
		print("🟣 Player entered the Undervoid for the first time!")


func has_entered_undervoid() -> bool:
	"""Check if player has ever entered the Undervoid"""
	return _has_entered_undervoid


func set_structures_generated(generated: bool):
	"""Mark that structures have been spawned"""
	_structures_generated = generated


func are_structures_generated() -> bool:
	"""Check if structures have been spawned yet"""
	return _structures_generated
