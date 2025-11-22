extends Node

# Library of pre-built ruin structures
# Each ruin is a template that can be placed in the world

class RuinTemplate:
	var name: String
	var size: Vector3i  # Bounding box size
	var blocks: Array  # Array of {pos: Vector3i, block_id: int, variant: int}
	var teleport_stone_pos: Vector3i  # Position of PRIMARY teleport stone (for backward compatibility)
	var teleport_stone_positions: Array  # Array of Vector3i - supports multiple teleport stones
	var weight: float = 1.0  # For weighted random selection

	func _init(p_name: String, p_size: Vector3i, p_blocks: Array, p_teleport_pos, p_weight: float = 1.0):
		name = p_name
		size = p_size
		blocks = p_blocks
		weight = p_weight

		# Support both single teleport stone and multiple teleport stones
		if p_teleport_pos is Array:
			teleport_stone_positions = p_teleport_pos
			teleport_stone_pos = p_teleport_pos[0] if p_teleport_pos.size() > 0 else Vector3i.ZERO
		else:
			teleport_stone_pos = p_teleport_pos
			teleport_stone_positions = [p_teleport_pos]


# All available ruin templates
var _ruin_templates: Array[RuinTemplate] = []


func _ready():
	print("Initializing RuinLibrary")
	_create_ruin_templates()


func _create_ruin_templates():
	# Create all ruin templates
	_ruin_templates.append(_create_crashed_tower_small())
	_ruin_templates.append(_create_coliseum())
	_ruin_templates.append(_create_sky_garden())
	_ruin_templates.append(_create_ancient_temple())
	_ruin_templates.append(_create_wizard_tower())
	_ruin_templates.append(_create_ruined_plaza())
	_ruin_templates.append(_create_desert_shrine())
	_ruin_templates.append(_create_floating_forest())
	# Mega-ruins with multiple teleport stones
	_ruin_templates.append(_create_grand_castle())
	_ruin_templates.append(_create_sky_city_district())
	# Expansion platforms (no teleport stones, just building space)
	_ruin_templates.append(_create_flat_platform_120x120())

	print("Loaded ", _ruin_templates.size(), " ruin template(s)")


func _create_crashed_tower_small() -> RuinTemplate:
	"""
	A small crashed tower - partially buried and broken
	Looks like it fell from the sky at an angle
	Size: approximately 20x9x20 (with landmass)
	"""
	var blocks = []

	# FLOATING LANDMASS - large dirt/grass island
	var landmass_size = 18
	var landmass_offset = -5  # Center the ruin on the landmass

	# Multiple layers of dirt
	for layer in range(-3, 0):  # 3 layers of dirt below surface
		for x in range(landmass_size):
			for z in range(landmass_size):
				blocks.append({"pos": Vector3i(x + landmass_offset, layer, z + landmass_offset), "block_id": 1, "variant": 0})  # dirt

	# Grass top layer
	for x in range(landmass_size):
		for z in range(landmass_size):
			blocks.append({"pos": Vector3i(x + landmass_offset, 0, z + landmass_offset), "block_id": 2, "variant": 0})  # grass

	# Impact crater effect - some dirt showing through
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

	# Teleport stone in the center of the room with safe landing
	var teleport_pos = Vector3i(3, 2, 3)
	_create_safe_landing_platform(blocks, teleport_pos, 19)  # ruin_floor platform
	blocks.append({"pos": teleport_pos, "block_id": 20, "variant": 0})  # teleport_stone

	# SPECIAL CHEST - This first chest always gives the grappling hook!
	# Place it near the teleport stone
	blocks.append({"pos": Vector3i(4, 2, 2), "block_id": 28, "variant": 0})  # chest

	# Decorative broken tower top piece (offset to the side like it fell off)
	blocks.append({"pos": Vector3i(6, 2, 3), "block_id": 18, "variant": 0})
	blocks.append({"pos": Vector3i(6, 3, 3), "block_id": 18, "variant": 0})
	blocks.append({"pos": Vector3i(7, 2, 3), "block_id": 19, "variant": 0})

	return RuinTemplate.new("crashed_tower_small", Vector3i(20, 10, 20), blocks, teleport_pos, 1.0)


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


func _create_safe_landing_platform(blocks: Array, teleport_pos: Vector3i, floor_block_id: int = 19) -> void:
	"""
	Creates a safe 3x3 platform around a teleport stone position
	teleport_pos should be the position where the teleport stone will be placed
	floor_block_id is the block type for the platform (default: ruin_floor)
	"""
	# Create platform one block below the teleport stone
	var platform_y = teleport_pos.y - 1

	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var platform_pos = Vector3i(teleport_pos.x + dx, platform_y, teleport_pos.z + dz)
			# Add platform block (this will be added to blocks array, potentially overwriting decorations)
			blocks.append({"pos": platform_pos, "block_id": floor_block_id, "variant": 0})


func _add_random_chests(blocks: Array, chest_positions: Array) -> void:
	"""
	Add chests at random positions from the provided array
	chest_positions is an array of Vector3i positions where chests could be placed
	Will place 1-3 chests randomly
	"""
	if chest_positions.is_empty():
		return

	var num_chests = randi() % 3 + 1  # 1 to 3 chests
	num_chests = min(num_chests, chest_positions.size())

	# Shuffle and pick random positions
	var shuffled = chest_positions.duplicate()
	shuffled.shuffle()

	for i in range(num_chests):
		blocks.append({"pos": shuffled[i], "block_id": 28, "variant": 0})  # chest


func _create_coliseum() -> RuinTemplate:
	"""
	A large circular arena with tiered stone seating
	Size: approximately 35x11x35 (with landmass)
	Open center for combat/events
	"""
	var blocks = []
	var center = Vector3i(17, 0, 17)
	var arena_radius = 5
	var outer_radius = 12

	# FLOATING LANDMASS - large dirt/grass island
	var landmass_size = 34
	var landmass_offset = 0

	# Multiple layers of dirt
	for layer in range(-3, 0):  # 3 layers of dirt below surface
		for x in range(landmass_size):
			for z in range(landmass_size):
				blocks.append({"pos": Vector3i(x + landmass_offset, layer, z + landmass_offset), "block_id": 1, "variant": 0})  # dirt

	# Grass top layer
	for x in range(landmass_size):
		for z in range(landmass_size):
			blocks.append({"pos": Vector3i(x + landmass_offset, 0, z + landmass_offset), "block_id": 2, "variant": 0})  # grass

	# Base floor - ruin floor in the center arena
	for x in range(center.x - arena_radius, center.x + arena_radius + 1):
		for z in range(center.z - arena_radius, center.z + arena_radius + 1):
			var dist = Vector2(x - center.x, z - center.z).length()
			if dist <= arena_radius:
				blocks.append({"pos": Vector3i(x, 0, z), "block_id": 19, "variant": 0})  # ruin_floor

	# Tiered seating (3 levels) - circular arrangement
	for tier in range(1, 4):
		var tier_radius_min = arena_radius + tier * 2
		var tier_radius_max = arena_radius + tier * 2 + 1
		var tier_height = tier

		for x in range(center.x - outer_radius, center.x + outer_radius + 1):
			for z in range(center.z - outer_radius, center.z + outer_radius + 1):
				var dist = Vector2(x - center.x, z - center.z).length()
				if dist >= tier_radius_min and dist <= tier_radius_max:
					# Seating steps
					for h in range(tier_height):
						blocks.append({"pos": Vector3i(x, h, z), "block_id": 18, "variant": 0})  # ruin_stone
					# Top of step
					blocks.append({"pos": Vector3i(x, tier_height, z), "block_id": 19, "variant": 0})  # ruin_floor

	# Add some decorative columns at cardinal directions
	var column_positions = [
		center + Vector3i(0, 0, outer_radius - 1),
		center + Vector3i(0, 0, -outer_radius + 1),
		center + Vector3i(outer_radius - 1, 0, 0),
		center + Vector3i(-outer_radius + 1, 0, 0)
	]

	for col_pos in column_positions:
		for y in range(0, 6):
			blocks.append({"pos": col_pos + Vector3i(0, y, 0), "block_id": 18, "variant": 0})

	# Teleport stone in center of arena with safe landing (note: teleport_pos is at y=0, stone at y=1)
	var teleport_pos = center + Vector3i(0, 1, 0)
	_create_safe_landing_platform(blocks, teleport_pos, 19)  # ruin_floor platform
	blocks.append({"pos": teleport_pos, "block_id": 20, "variant": 0})  # teleport_stone

	# Add random chests around the arena seating
	var chest_positions = [
		center + Vector3i(-8, 4, -8),
		center + Vector3i(8, 4, -8),
		center + Vector3i(-8, 4, 8),
		center + Vector3i(8, 4, 8),
		center + Vector3i(0, 4, -10),
		center + Vector3i(0, 4, 10)
	]
	_add_random_chests(blocks, chest_positions)

	return RuinTemplate.new("coliseum", Vector3i(35, 11, 35), blocks, teleport_pos, 1.0)


func _create_sky_garden() -> RuinTemplate:
	"""
	An open garden with grass, trees, and flowers
	Size: approximately 30x15x30 (with landmass)
	Peaceful natural area floating in the sky
	"""
	var blocks = []
	var size_x = 28
	var size_z = 28

	# FLOATING LANDMASS - large dirt/grass island
	# Multiple layers of dirt for floating island effect
	for layer in range(-3, 0):  # 3 layers of dirt below surface
		for x in range(size_x):
			for z in range(size_z):
				blocks.append({"pos": Vector3i(x, layer, z), "block_id": 1, "variant": 0})  # dirt

	# Dirt base layer at ground level
	for x in range(size_x):
		for z in range(size_z):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": 1, "variant": 0})  # dirt

	# Grass layer on top - full landmass coverage
	for x in range(size_x):
		for z in range(size_z):
			blocks.append({"pos": Vector3i(x, 1, z), "block_id": 2, "variant": 0})  # grass

	# Add trees (using logs and leaves) - center kept clear for teleport
	var tree_positions = [
		Vector3i(6, 2, 6),
		Vector3i(21, 2, 6),
		Vector3i(6, 2, 21),
		Vector3i(21, 2, 21),
		Vector3i(10, 2, 14),
		Vector3i(17, 2, 14)
		# Center area kept clear for teleport stone
	]

	for tree_base in tree_positions:
		# Tree trunk
		for y in range(0, 5):
			blocks.append({"pos": tree_base + Vector3i(0, y, 0), "block_id": 3, "variant": 1})  # log_y

		# Leaf canopy
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				for dy in range(4, 7):
					if abs(dx) + abs(dz) <= 3 and not (abs(dx) == 2 and abs(dz) == 2):
						blocks.append({"pos": tree_base + Vector3i(dx, dy, dz), "block_id": 10, "variant": 0})  # leaves

	# Add tall grass scattered around
	for i in range(30):
		var grass_x = randi() % (size_x - 2) + 1
		var grass_z = randi() % (size_z - 2) + 1
		# Avoid tree positions
		var too_close = false
		for tree_pos in tree_positions:
			if Vector2(grass_x - tree_pos.x, grass_z - tree_pos.z).length() < 3:
				too_close = true
				break
		if not too_close:
			blocks.append({"pos": Vector3i(grass_x, 2, grass_z), "block_id": 6, "variant": 0})  # tall_grass

	# Decorative stone border
	for x in range(size_x):
		blocks.append({"pos": Vector3i(x, 1, 0), "block_id": 14, "variant": 0})  # stone
		blocks.append({"pos": Vector3i(x, 1, size_z - 1), "block_id": 14, "variant": 0})
	for z in range(size_z):
		blocks.append({"pos": Vector3i(0, 1, z), "block_id": 14, "variant": 0})
		blocks.append({"pos": Vector3i(size_x - 1, 1, z), "block_id": 14, "variant": 0})

	# Teleport stone in center with safe landing platform
	var teleport_pos = Vector3i(14, 2, 14)  # Center of 28x28 area
	_create_safe_landing_platform(blocks, teleport_pos, 19)  # ruin_floor platform
	blocks.append({"pos": teleport_pos, "block_id": 20, "variant": 0})  # teleport_stone

	# Add random chests near trees and borders
	var chest_positions = [
		Vector3i(3, 2, 3),
		Vector3i(24, 2, 3),
		Vector3i(3, 2, 24),
		Vector3i(24, 2, 24),
		Vector3i(7, 2, 14),
		Vector3i(20, 2, 14)
	]
	_add_random_chests(blocks, chest_positions)

	return RuinTemplate.new("sky_garden", Vector3i(30, 15, 30), blocks, teleport_pos, 1.2)


func _create_ancient_temple() -> RuinTemplate:
	"""
	A temple with columns and a raised platform
	Size: approximately 26x13x26 (with landmass)
	Classical architecture feel
	"""
	var blocks = []

	# FLOATING LANDMASS - large dirt/grass island
	var landmass_size = 26
	var landmass_offset = 0

	# Multiple layers of dirt
	for layer in range(-3, 0):  # 3 layers of dirt below surface
		for x in range(landmass_size):
			for z in range(landmass_size):
				blocks.append({"pos": Vector3i(x + landmass_offset, layer, z + landmass_offset), "block_id": 1, "variant": 0})  # dirt

	# Grass top layer
	for x in range(landmass_size):
		for z in range(landmass_size):
			blocks.append({"pos": Vector3i(x + landmass_offset, 0, z + landmass_offset), "block_id": 2, "variant": 0})  # grass

	# Foundation platform - raised
	for x in range(1, 15):
		for z in range(1, 15):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": 18, "variant": 0})  # ruin_stone
			blocks.append({"pos": Vector3i(x, 1, z), "block_id": 19, "variant": 0})  # ruin_floor

	# Steps leading up to platform (front entrance)
	for step in range(3):
		for x in range(5, 11):
			blocks.append({"pos": Vector3i(x, step, 0), "block_id": 18, "variant": 0})

	# Columns around perimeter
	var column_positions = [
		Vector3i(2, 2, 2), Vector3i(13, 2, 2),
		Vector3i(2, 2, 13), Vector3i(13, 2, 13),
		Vector3i(2, 2, 7), Vector3i(13, 2, 7),
		Vector3i(7, 2, 2), Vector3i(7, 2, 13)
	]

	for col_pos in column_positions:
		for y in range(0, 7):
			blocks.append({"pos": col_pos + Vector3i(0, y, 0), "block_id": 18, "variant": 0})

	# Partial roof/ceiling
	for x in range(3, 13):
		for z in range(3, 13):
			# Only place ceiling in outer ring, leave center open
			if x < 6 or x > 9 or z < 6 or z > 9:
				blocks.append({"pos": Vector3i(x, 8, z), "block_id": 19, "variant": 0})

	# Central altar/platform
	for x in range(6, 10):
		for z in range(6, 10):
			blocks.append({"pos": Vector3i(x, 2, z), "block_id": 18, "variant": 0})

	# Teleport stone on the altar with safe landing
	var teleport_pos = Vector3i(7, 3, 7)
	_create_safe_landing_platform(blocks, teleport_pos, 18)  # ruin_stone platform (altar is stone)
	blocks.append({"pos": teleport_pos, "block_id": 20, "variant": 0})

	# Add random chests around the temple
	var chest_positions = [
		Vector3i(3, 2, 3),
		Vector3i(11, 2, 3),
		Vector3i(3, 2, 11),
		Vector3i(11, 2, 11),
		Vector3i(7, 2, 2),
		Vector3i(7, 2, 12)
	]
	_add_random_chests(blocks, chest_positions)

	return RuinTemplate.new("ancient_temple", Vector3i(26, 13, 26), blocks, teleport_pos, 1.0)


func _create_wizard_tower() -> RuinTemplate:
	"""
	A tall vertical tower structure
	Size: approximately 20x25x20 (with landmass)
	Multiple floors with glass windows
	"""
	var blocks = []
	var landmass_size = 20
	var landmass_offset = 0

	# FLOATING LANDMASS - large dirt/grass island
	# Multiple layers of dirt
	for layer in range(-3, 0):  # 3 layers of dirt below surface
		for x in range(landmass_size):
			for z in range(landmass_size):
				blocks.append({"pos": Vector3i(x + landmass_offset, layer, z + landmass_offset), "block_id": 1, "variant": 0})  # dirt

	# Grass top layer
	for x in range(landmass_size):
		for z in range(landmass_size):
			blocks.append({"pos": Vector3i(x + landmass_offset, 0, z + landmass_offset), "block_id": 2, "variant": 0})  # grass

	var base_x = 5  # Center tower on landmass
	var base_z = 5

	# Tower walls - hollow cylinder
	for y in range(0, 18):
		for x in range(base_x, base_x + 9):
			for z in range(base_z, base_z + 9):
				# Only build walls, not filled
				if x == base_x or x == base_x + 8 or z == base_z or z == base_z + 8:
					# Add windows every 4 levels on non-corner blocks
					if y % 4 == 2 and x != base_x and x != base_x + 8 and z != base_z and z != base_z + 8:
						blocks.append({"pos": Vector3i(x, y, z), "block_id": 7, "variant": 0})  # glass
					else:
						blocks.append({"pos": Vector3i(x, y, z), "block_id": 18, "variant": 0})  # ruin_stone

	# Floors every 4 levels
	for floor_y in [0, 4, 8, 12, 16]:
		for x in range(base_x + 1, base_x + 8):
			for z in range(base_z + 1, base_z + 8):
				blocks.append({"pos": Vector3i(x, floor_y, z), "block_id": 19, "variant": 0})  # ruin_floor

	# Decorative top - spire
	for y in range(18, 22):
		var offset = y - 18
		for x in range(base_x + 2 + offset, base_x + 7 - offset):
			for z in range(base_z + 2 + offset, base_z + 7 - offset):
				blocks.append({"pos": Vector3i(x, y, z), "block_id": 18, "variant": 0})

	# Teleport stone on ground floor with safe landing
	var teleport_pos = Vector3i(4, 1, 4)
	_create_safe_landing_platform(blocks, teleport_pos, 19)  # ruin_floor platform
	blocks.append({"pos": teleport_pos, "block_id": 20, "variant": 0})

	# Add random chests on different floors of the tower
	var chest_positions = [
		Vector3i(base_x + 2, 5, base_z + 2),   # Floor 2
		Vector3i(base_x + 6, 5, base_z + 6),
		Vector3i(base_x + 2, 9, base_z + 2),   # Floor 3
		Vector3i(base_x + 6, 9, base_z + 6),
		Vector3i(base_x + 2, 13, base_z + 2),  # Floor 4
		Vector3i(base_x + 6, 13, base_z + 6)
	]
	_add_random_chests(blocks, chest_positions)

	return RuinTemplate.new("wizard_tower", Vector3i(20, 25, 20), blocks, teleport_pos, 0.8)


func _create_ruined_plaza() -> RuinTemplate:
	"""
	A large open paved area with some decorative elements
	Size: approximately 32x8x32 (with landmass)
	Great for spawning or gathering
	"""
	var blocks = []

	# FLOATING LANDMASS - large dirt/grass island
	var landmass_size = 32
	var landmass_offset = 0

	# Multiple layers of dirt
	for layer in range(-3, 0):  # 3 layers of dirt below surface
		for x in range(landmass_size):
			for z in range(landmass_size):
				blocks.append({"pos": Vector3i(x + landmass_offset, layer, z + landmass_offset), "block_id": 1, "variant": 0})  # dirt

	# Grass top layer
	for x in range(landmass_size):
		for z in range(landmass_size):
			blocks.append({"pos": Vector3i(x + landmass_offset, 0, z + landmass_offset), "block_id": 2, "variant": 0})  # grass

	var size = 20

	# Paved floor
	for x in range(size):
		for z in range(size):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": 19, "variant": 0})  # ruin_floor

	# Decorative stone pattern in floor (cross pattern)
	for i in range(size):
		blocks.append({"pos": Vector3i(i, 0, int(size / 2)), "block_id": 18, "variant": 0})
		blocks.append({"pos": Vector3i(int(size / 2), 0, i), "block_id": 18, "variant": 0})

	# Corner pillars
	var corners = [
		Vector3i(1, 0, 1), Vector3i(size - 2, 0, 1),
		Vector3i(1, 0, size - 2), Vector3i(size - 2, 0, size - 2)
	]

	for corner in corners:
		for y in range(0, 5):
			blocks.append({"pos": corner + Vector3i(0, y, 0), "block_id": 18, "variant": 0})

	# Some scattered crates and decorations
	var crate_positions = [
		Vector3i(3, 1, 3), Vector3i(16, 1, 3),
		Vector3i(3, 1, 16), Vector3i(16, 1, 16),
		Vector3i(10, 1, 5), Vector3i(5, 1, 10)
	]

	for crate_pos in crate_positions:
		blocks.append({"pos": crate_pos, "block_id": 25, "variant": 0})  # crate

	# Teleport stone in center on raised platform with safe landing
	var teleport_pos = Vector3i(int(size / 2), 1, int(size / 2))
	blocks.append({"pos": Vector3i(int(size / 2), 0, int(size / 2)), "block_id": 18, "variant": 0})
	_create_safe_landing_platform(blocks, teleport_pos, 19)  # ruin_floor platform
	blocks.append({"pos": teleport_pos, "block_id": 20, "variant": 0})

	return RuinTemplate.new("ruined_plaza", Vector3i(32, 8, 32), blocks, teleport_pos, 1.3)


func _create_desert_shrine() -> RuinTemplate:
	"""
	A sandstone pyramid-like shrine structure
	Size: approximately 25x15x25 (with landmass)
	Desert/Egyptian aesthetic
	"""
	var blocks = []

	# FLOATING LANDMASS - sand/sandstone island
	var landmass_size = 25
	var landmass_offset = 0

	# Multiple layers of sandstone for desert island
	for layer in range(-3, 0):  # 3 layers below surface
		for x in range(landmass_size):
			for z in range(landmass_size):
				blocks.append({"pos": Vector3i(x + landmass_offset, layer, z + landmass_offset), "block_id": 24, "variant": 0})  # sand_stone

	# Sand top layer
	for x in range(landmass_size):
		for z in range(landmass_size):
			blocks.append({"pos": Vector3i(x + landmass_offset, 0, z + landmass_offset), "block_id": 23, "variant": 0})  # sand

	var center = Vector3i(12, 0, 12)  # Center on the landmass

	# Pyramid-like structure
	for level in range(6):
		var level_size = 7 - level
		var offset = level

		for x in range(-level_size, level_size + 1):
			for z in range(-level_size, level_size + 1):
				# Only build perimeter at higher levels
				if level == 0 or abs(x) == level_size or abs(z) == level_size:
					blocks.append({"pos": center + Vector3i(x, level, z), "block_id": 24, "variant": 0})  # sand_stone

	# Central chamber at ground level
	for x in range(-2, 3):
		for z in range(-2, 3):
			blocks.append({"pos": center + Vector3i(x, 0, z), "block_id": 24, "variant": 0})
			if abs(x) < 2 and abs(z) < 2:
				blocks.append({"pos": center + Vector3i(x, 1, z), "block_id": 0, "variant": 0})  # air (hollow)

	# Entrance
	blocks.append({"pos": center + Vector3i(0, 1, -3), "block_id": 0, "variant": 0})  # air
	blocks.append({"pos": center + Vector3i(0, 2, -3), "block_id": 0, "variant": 0})

	# Decorative columns inside chamber
	var inner_columns = [
		center + Vector3i(-1, 1, -1), center + Vector3i(1, 1, -1),
		center + Vector3i(-1, 1, 1), center + Vector3i(1, 1, 1)
	]

	for col in inner_columns:
		blocks.append({"pos": col, "block_id": 24, "variant": 0})
		blocks.append({"pos": col + Vector3i(0, 1, 0), "block_id": 24, "variant": 0})

	# Teleport stone in center of chamber with safe landing
	var teleport_pos = center + Vector3i(0, 1, 0)
	_create_safe_landing_platform(blocks, teleport_pos, 24)  # sand_stone platform
	blocks.append({"pos": teleport_pos, "block_id": 20, "variant": 0})

	return RuinTemplate.new("desert_shrine", Vector3i(25, 15, 25), blocks, teleport_pos, 0.9)


func _create_floating_forest() -> RuinTemplate:
	"""
	A natural-looking floating grove with multiple trees
	Size: approximately 34x19x34 (with landmass)
	Dense forest feeling
	"""
	var blocks = []
	var size_x = 32
	var size_z = 32

	# FLOATING LANDMASS - irregular dirt/grass island with depth
	# Multiple layers of dirt for floating island effect
	for layer in range(-3, 0):  # 3 layers of dirt below surface
		for x in range(size_x):
			for z in range(size_z):
				# Create irregular edge even in lower layers
				# FIXED: Increased guaranteed radius from 14 to 18 (4 blocks wider all around)
				var dist_to_center = Vector2(x - size_x/2, z - size_z/2).length()
				if dist_to_center < 18 or (dist_to_center < 20 and randi() % 2 == 0):
					blocks.append({"pos": Vector3i(x, layer, z), "block_id": 1, "variant": 0})  # dirt

	# Dirt and grass base (irregular shape at surface)
	for x in range(size_x):
		for z in range(size_z):
			# Create irregular edge
			# FIXED: Increased guaranteed radius from 14 to 18 (4 blocks wider all around)
			var dist_to_center = Vector2(x - size_x/2, z - size_z/2).length()
			if dist_to_center < 18 or (dist_to_center < 20 and randi() % 2 == 0):
				blocks.append({"pos": Vector3i(x, 0, z), "block_id": 1, "variant": 0})  # dirt
				blocks.append({"pos": Vector3i(x, 1, z), "block_id": 2, "variant": 0})  # grass

	# Plant many trees
	var tree_positions = [
		Vector3i(5, 2, 5), Vector3i(16, 2, 5), Vector3i(5, 2, 16), Vector3i(16, 2, 16),
		Vector3i(11, 2, 11), Vector3i(7, 2, 11), Vector3i(15, 2, 11),
		Vector3i(11, 2, 7), Vector3i(11, 2, 15), Vector3i(8, 2, 8),
		Vector3i(13, 2, 8), Vector3i(8, 2, 13), Vector3i(13, 2, 13)
	]

	for tree_base in tree_positions:
		# Vary tree heights
		var tree_height = 4 + (randi() % 3)

		# Tree trunk
		for y in range(0, tree_height):
			blocks.append({"pos": tree_base + Vector3i(0, y, 0), "block_id": 3, "variant": 1})  # log_y

		# Leaf canopy
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				for dy in range(tree_height - 2, tree_height + 2):
					if abs(dx) + abs(dz) <= 3 and not (abs(dx) == 2 and abs(dz) == 2 and dy == tree_height + 1):
						blocks.append({"pos": tree_base + Vector3i(dx, dy, dz), "block_id": 10, "variant": 0})  # leaves

	# Add undergrowth
	for i in range(50):
		var grass_x = randi() % (size_x - 2) + 1
		var grass_z = randi() % (size_z - 2) + 1
		blocks.append({"pos": Vector3i(grass_x, 2, grass_z), "block_id": 6, "variant": 0})  # tall_grass

	# Small clearing in the middle with teleport stone
	for x in range(9, 13):
		for z in range(9, 13):
			# Remove grass and add stone circle
			blocks.append({"pos": Vector3i(x, 1, z), "block_id": 14, "variant": 0})  # stone

	# Teleport stone with safe landing
	var teleport_pos = Vector3i(11, 2, 11)
	_create_safe_landing_platform(blocks, teleport_pos, 14)  # stone platform
	blocks.append({"pos": teleport_pos, "block_id": 20, "variant": 0})

	return RuinTemplate.new("floating_forest", Vector3i(34, 19, 34), blocks, teleport_pos, 1.1)


func _create_grand_castle() -> RuinTemplate:
	"""
	A massive castle with towers and courtyards
	Size: approximately 50x28x50 (with landmass)
	Has 3 teleport stones in different towers
	"""
	var blocks = []

	# FLOATING LANDMASS - large dirt/grass island
	var landmass_size = 50
	var landmass_offset = 0

	# Multiple layers of dirt
	for layer in range(-3, 0):  # 3 layers of dirt below surface
		for x in range(landmass_size):
			for z in range(landmass_size):
				blocks.append({"pos": Vector3i(x + landmass_offset, layer, z + landmass_offset), "block_id": 1, "variant": 0})  # dirt

	# Grass top layer
	for x in range(landmass_size):
		for z in range(landmass_size):
			blocks.append({"pos": Vector3i(x + landmass_offset, 0, z + landmass_offset), "block_id": 2, "variant": 0})  # grass

	# Main courtyard floor
	for x in range(10, 30):
		for z in range(10, 30):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": 19, "variant": 0})  # ruin_floor

	# Outer walls (hollow rectangle)
	for x in range(8, 32):
		for z in [8, 31]:
			for y in range(0, 8):
				blocks.append({"pos": Vector3i(x, y, z), "block_id": 18, "variant": 0})  # ruin_stone
	for z in range(8, 32):
		for x in [8, 31]:
			for y in range(0, 8):
				blocks.append({"pos": Vector3i(x, y, z), "block_id": 18, "variant": 0})

	# Battlements on walls
	for x in range(8, 32, 2):
		blocks.append({"pos": Vector3i(x, 8, 8), "block_id": 18, "variant": 0})
		blocks.append({"pos": Vector3i(x, 8, 31), "block_id": 18, "variant": 0})
	for z in range(8, 32, 2):
		blocks.append({"pos": Vector3i(8, 8, z), "block_id": 18, "variant": 0})
		blocks.append({"pos": Vector3i(31, 8, z), "block_id": 18, "variant": 0})

	# Three corner towers (each will have a teleport stone)
	var tower_positions = [
		Vector3i(5, 0, 5),     # Northwest tower
		Vector3i(34, 0, 5),    # Northeast tower
		Vector3i(5, 0, 34)     # Southwest tower
	]

	var teleport_positions = []

	for tower_base in tower_positions:
		# Tower walls (4x4 hollow)
		for y in range(0, 15):
			for dx in range(4):
				for dz in range(4):
					if dx == 0 or dx == 3 or dz == 0 or dz == 3:
						blocks.append({"pos": tower_base + Vector3i(dx, y, dz), "block_id": 18, "variant": 0})

		# Tower floors every 5 levels
		for floor_y in [0, 5, 10]:
			for dx in range(1, 3):
				for dz in range(1, 3):
					blocks.append({"pos": tower_base + Vector3i(dx, floor_y, dz), "block_id": 19, "variant": 0})

		# Tower top
		for dx in range(-1, 5):
			for dz in range(-1, 5):
				if abs(dx - 1.5) <= 2 and abs(dz - 1.5) <= 2:
					blocks.append({"pos": tower_base + Vector3i(dx, 15, dz), "block_id": 18, "variant": 0})

		# Place teleport stone in each tower (on ground floor) with safe landing
		var teleport_pos = tower_base + Vector3i(1, 1, 1)
		_create_safe_landing_platform(blocks, teleport_pos, 19)  # ruin_floor platform
		blocks.append({"pos": teleport_pos, "block_id": 20, "variant": 0})
		teleport_positions.append(teleport_pos)

	# Central keep building
	for x in range(17, 23):
		for z in range(17, 23):
			# Walls
			if x == 17 or x == 22 or z == 17 or z == 22:
				for y in range(0, 12):
					blocks.append({"pos": Vector3i(x, y, z), "block_id": 18, "variant": 0})
			# Floor
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": 19, "variant": 0})

	# Gateway entrance (south side)
	for y in range(1, 5):
		blocks.append({"pos": Vector3i(19, y, 8), "block_id": 0, "variant": 0})  # air
		blocks.append({"pos": Vector3i(20, y, 8), "block_id": 0, "variant": 0})

	return RuinTemplate.new("grand_castle", Vector3i(50, 28, 50), blocks, teleport_positions, 0.6)


func _create_sky_city_district() -> RuinTemplate:
	"""
	A section of a floating city with multiple buildings
	Size: approximately 55x21x55 (with landmass)
	Has 4 teleport stones in different buildings
	Includes streets, buildings, and a central plaza
	"""
	var blocks = []

	# FLOATING LANDMASS - large dirt/grass island
	var landmass_size = 55
	var landmass_offset = 0

	# Multiple layers of dirt
	for layer in range(-3, 0):  # 3 layers of dirt below surface
		for x in range(landmass_size):
			for z in range(landmass_size):
				blocks.append({"pos": Vector3i(x + landmass_offset, layer, z + landmass_offset), "block_id": 1, "variant": 0})  # dirt

	# Grass top layer
	for x in range(landmass_size):
		for z in range(landmass_size):
			blocks.append({"pos": Vector3i(x + landmass_offset, 0, z + landmass_offset), "block_id": 2, "variant": 0})  # grass

	# Street grid (paved roads)
	# Main street running north-south
	for z in range(0, 45):
		for x in range(20, 25):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": 19, "variant": 0})  # ruin_floor

	# Main street running east-west
	for x in range(0, 45):
		for z in range(20, 25):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": 19, "variant": 0})

	# Central plaza at intersection
	for x in range(18, 27):
		for z in range(18, 27):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": 19, "variant": 0})

	# Four buildings in the quadrants, each with a teleport stone
	var building_bases = [
		Vector3i(5, 0, 5),      # Northwest building
		Vector3i(30, 0, 5),     # Northeast building
		Vector3i(5, 0, 30),     # Southwest building
		Vector3i(30, 0, 30)     # Southeast building
	]

	var teleport_positions = []

	for i in range(building_bases.size()):
		var base = building_bases[i]
		var building_width = 12
		var building_depth = 12
		var building_height = 8 + (i * 2)  # Varying heights

		# Building foundation
		for x in range(building_width):
			for z in range(building_depth):
				blocks.append({"pos": base + Vector3i(x, 0, z), "block_id": 19, "variant": 0})

		# Building walls
		for y in range(1, building_height):
			for x in range(building_width):
				for z in range(building_depth):
					if x == 0 or x == building_width - 1 or z == 0 or z == building_depth - 1:
						# Add windows on some levels
						if y % 3 == 1 and x % 3 == 1 and x != 0 and x != building_width - 1:
							blocks.append({"pos": base + Vector3i(x, y, z), "block_id": 7, "variant": 0})  # glass
						else:
							blocks.append({"pos": base + Vector3i(x, y, z), "block_id": 18, "variant": 0})  # ruin_stone

		# Roof
		for x in range(building_width):
			for z in range(building_depth):
				blocks.append({"pos": base + Vector3i(x, building_height, z), "block_id": 19, "variant": 0})

		# Interior floor
		for x in range(1, building_width - 1):
			for z in range(1, building_depth - 1):
				blocks.append({"pos": base + Vector3i(x, 1, z), "block_id": 19, "variant": 0})

		# Doorway facing the street
		var door_x = int(building_width / 2)
		var door_z = 0 if base.z < 22 else building_depth - 1
		blocks.append({"pos": base + Vector3i(door_x, 1, door_z), "block_id": 0, "variant": 0})  # air
		blocks.append({"pos": base + Vector3i(door_x, 2, door_z), "block_id": 0, "variant": 0})

		# Teleport stone inside each building with safe landing
		var teleport_pos = base + Vector3i(int(building_width / 2), 2, int(building_depth / 2))
		_create_safe_landing_platform(blocks, teleport_pos, 19)  # ruin_floor platform
		blocks.append({"pos": teleport_pos, "block_id": 20, "variant": 0})
		teleport_positions.append(teleport_pos)

		# Add some crates in each building
		if i % 2 == 0:
			blocks.append({"pos": base + Vector3i(2, 2, 2), "block_id": 25, "variant": 0})  # crate
			blocks.append({"pos": base + Vector3i(building_width - 3, 2, 2), "block_id": 25, "variant": 0})

	# Central fountain in plaza
	for x in range(21, 24):
		for z in range(21, 24):
			blocks.append({"pos": Vector3i(x, 1, z), "block_id": 14, "variant": 0})  # stone
	blocks.append({"pos": Vector3i(22, 2, 22), "block_id": 8, "variant": 0})  # water

	# Street lamps
	var lamp_positions = [
		Vector3i(20, 0, 15), Vector3i(24, 0, 15),
		Vector3i(20, 0, 29), Vector3i(24, 0, 29),
		Vector3i(15, 0, 20), Vector3i(29, 0, 20),
		Vector3i(15, 0, 24), Vector3i(29, 0, 24)
	]

	for lamp in lamp_positions:
		for y in range(1, 4):
			blocks.append({"pos": lamp + Vector3i(0, y, 0), "block_id": 18, "variant": 0})
		blocks.append({"pos": lamp + Vector3i(0, 4, 0), "block_id": 7, "variant": 0})  # glass

	return RuinTemplate.new("sky_city_district", Vector3i(55, 21, 55), blocks, teleport_positions, 0.5)


func _create_flat_platform_120x120() -> RuinTemplate:
	"""
	A simple 120x120 flat platform for base expansion
	Just 3 layers: 1 layer dirt bottom, 1 layer dirt middle, 1 layer grass top
	Has a teleport stone in the center for player to arrive at
	"""
	var blocks = []
	var platform_size = 120

	# Bottom layer - dirt
	for x in range(platform_size):
		for z in range(platform_size):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": 1, "variant": 0})  # dirt

	# Middle layer - dirt
	for x in range(platform_size):
		for z in range(platform_size):
			blocks.append({"pos": Vector3i(x, 1, z), "block_id": 1, "variant": 0})  # dirt

	# Top layer - grass
	for x in range(platform_size):
		for z in range(platform_size):
			blocks.append({"pos": Vector3i(x, 2, z), "block_id": 2, "variant": 0})  # grass

	# Teleport stone in the center with safe landing platform
	var center = int(platform_size / 2)
	var teleport_pos = Vector3i(center, 3, center)
	_create_safe_landing_platform(blocks, teleport_pos, 19)  # ruin_floor platform
	blocks.append({"pos": teleport_pos, "block_id": 20, "variant": 0})  # teleport_stone

	print("Created flat_platform_120x120 with ", blocks.size(), " blocks (120x120x3) + teleport stone at center")

	return RuinTemplate.new("flat_platform_120x120", Vector3i(120, 4, 120), blocks, teleport_pos, 0.0)
