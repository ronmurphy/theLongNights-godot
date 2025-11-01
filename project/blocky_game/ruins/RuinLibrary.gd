extends Node

# Library of pre-built ruin structures
# Each ruin is a template that can be placed in the world

class RuinTemplate:
	var name: String
	var size: Vector3i  # Bounding box size
	var blocks: Array  # Array of {pos: Vector3i, block_id: int, variant: int}
	var teleport_stone_pos: Vector3i  # Position of the teleport stone within the structure
	var weight: float = 1.0  # For weighted random selection

	func _init(p_name: String, p_size: Vector3i, p_blocks: Array, p_teleport_pos: Vector3i, p_weight: float = 1.0):
		name = p_name
		size = p_size
		blocks = p_blocks
		teleport_stone_pos = p_teleport_pos
		weight = p_weight


# All available ruin templates
var _ruin_templates: Array[RuinTemplate] = []


func _ready():
	print("Initializing RuinLibrary")
	_create_ruin_templates()


func _create_ruin_templates():
	# Create the initial crashed tower ruin
	_ruin_templates.append(_create_crashed_tower_small())

	print("Loaded ", _ruin_templates.size(), " ruin template(s)")


func _create_crashed_tower_small() -> RuinTemplate:
	"""
	A small crashed tower - partially buried and broken
	Looks like it fell from the sky at an angle
	Size: approximately 7x9x7
	"""
	var blocks = []

	# Base/buried section - dirt and stone showing impact crater
	# Impact crater edge (dirt)
	for x in range(-1, 8):
		for z in range(-1, 8):
			if x == -1 or x == 7 or z == -1 or z == 7:
				blocks.append({"pos": Vector3i(x, 0, z), "block_id": 1, "variant": 0})  # dirt

	# Foundation layer - partially buried ruin stone
	for x in range(1, 6):
		for z in range(1, 6):
			blocks.append({"pos": Vector3i(x, 1, z), "block_id": 18, "variant": 0})  # ruin_stone

	# Floor layer
	for x in range(1, 6):
		for z in range(1, 6):
			blocks.append({"pos": Vector3i(x, 2, z), "block_id": 19, "variant": 0})  # ruin_floor

	# Walls - broken and incomplete (level 3-5)
	# South wall (mostly intact)
	for x in range(1, 6):
		blocks.append({"pos": Vector3i(x, 3, 1), "block_id": 18, "variant": 0})
		blocks.append({"pos": Vector3i(x, 4, 1), "block_id": 18, "variant": 0})
		if x != 3:  # Gap in middle for entrance
			blocks.append({"pos": Vector3i(x, 5, 1), "block_id": 18, "variant": 0})

	# West wall (damaged)
	for z in range(2, 6):
		blocks.append({"pos": Vector3i(1, 3, z), "block_id": 18, "variant": 0})
		if z != 4:  # Missing some blocks
			blocks.append({"pos": Vector3i(1, 4, z), "block_id": 18, "variant": 0})

	# East wall (heavily damaged)
	blocks.append({"pos": Vector3i(5, 3, 2), "block_id": 18, "variant": 0})
	blocks.append({"pos": Vector3i(5, 3, 3), "block_id": 18, "variant": 0})
	blocks.append({"pos": Vector3i(5, 4, 2), "block_id": 18, "variant": 0})
	blocks.append({"pos": Vector3i(5, 3, 5), "block_id": 18, "variant": 0})

	# North wall (mostly destroyed)
	blocks.append({"pos": Vector3i(2, 3, 5), "block_id": 18, "variant": 0})
	blocks.append({"pos": Vector3i(4, 3, 5), "block_id": 18, "variant": 0})
	blocks.append({"pos": Vector3i(4, 4, 5), "block_id": 18, "variant": 0})

	# Some damaged ceiling pieces (level 6)
	blocks.append({"pos": Vector3i(2, 6, 2), "block_id": 19, "variant": 0})
	blocks.append({"pos": Vector3i(3, 6, 2), "block_id": 19, "variant": 0})
	blocks.append({"pos": Vector3i(2, 6, 3), "block_id": 19, "variant": 0})

	# Broken glass window
	blocks.append({"pos": Vector3i(3, 4, 1), "block_id": 7, "variant": 0})  # glass

	# Stone rubble inside
	blocks.append({"pos": Vector3i(2, 2, 2), "block_id": 14, "variant": 0})  # stone
	blocks.append({"pos": Vector3i(4, 2, 4), "block_id": 14, "variant": 0})  # stone

	# Teleport stone in the center of the room
	var teleport_pos = Vector3i(3, 2, 3)
	blocks.append({"pos": teleport_pos, "block_id": 20, "variant": 0})  # teleport_stone

	# Decorative broken tower top piece (offset to the side like it fell off)
	blocks.append({"pos": Vector3i(6, 2, 3), "block_id": 18, "variant": 0})
	blocks.append({"pos": Vector3i(6, 3, 3), "block_id": 18, "variant": 0})
	blocks.append({"pos": Vector3i(7, 2, 3), "block_id": 19, "variant": 0})

	return RuinTemplate.new("crashed_tower_small", Vector3i(9, 7, 9), blocks, teleport_pos, 1.0)


func get_random_ruin() -> RuinTemplate:
	"""Get a random ruin template using weighted selection"""
	if _ruin_templates.is_empty():
		push_error("No ruin templates available!")
		return null

	# Calculate total weight
	var total_weight = 0.0
	for template in _ruin_templates:
		total_weight += template.weight

	# Random selection
	var rand_value = randf() * total_weight
	var current_weight = 0.0

	for template in _ruin_templates:
		current_weight += template.weight
		if rand_value <= current_weight:
			return template

	# Fallback to first template
	return _ruin_templates[0]


func get_ruin_by_name(ruin_name: String) -> RuinTemplate:
	"""Get a specific ruin template by name"""
	for template in _ruin_templates:
		if template.name == ruin_name:
			return template

	push_warning("Ruin template not found: ", ruin_name)
	return null


func get_all_ruin_names() -> Array:
	"""Get list of all available ruin template names"""
	var names = []
	for template in _ruin_templates:
		names.append(template.name)
	return names
