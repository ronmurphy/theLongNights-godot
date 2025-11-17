extends Node

## StructureBlueprintLibrary - Central registry for purchasable structures
## Used by Michelle (town manager) to show available buildings
## Autoload singleton

# Blueprint class definition
class StructureBlueprint:
	var name: String
	var display_name: String
	var size: Vector3i  # Bounding box (width, height, depth)
	var blocks: Array  # [{pos: Vector3i, voxel_name: String}]
	var category: String  # "homebase", "utility", "decoration"
	var description: String
	var rust_block_cost: int
	var preview_icon_path: String

	func _init(
		p_name: String,
		p_display_name: String,
		p_size: Vector3i,
		p_category: String,
		p_description: String,
		p_rust_cost: int
	):
		name = p_name
		display_name = p_display_name
		size = p_size
		category = p_category
		description = p_description
		rust_block_cost = p_rust_cost
		blocks = []
		preview_icon_path = "res://assets/art/icons/structure_placeholder.png"

	func add_block(pos: Vector3i, voxel_name: String) -> void:
		"""Add a voxel to the structure template (stores voxel name like 'planks', 'log_y', 'glass')"""
		blocks.append({
			"pos": pos,
			"voxel_name": voxel_name
		})

	func get_block_count() -> int:
		"""Get total number of blocks in structure"""
		return blocks.size()

	func get_block_type_counts() -> Dictionary:
		"""Count blocks by type for cost calculation"""
		var counts = {}
		for block_data in blocks:
			var bid = block_data.block_id
			if not counts.has(bid):
				counts[bid] = 0
			counts[bid] += 1
		return counts


# Blueprint registry
var _blueprints: Dictionary = {}  # {name: StructureBlueprint}


func _ready():
	print("StructureBlueprintLibrary: Initializing...")
	_register_homebase_structures()
	_register_utility_structures()
	print("StructureBlueprintLibrary: Registered %d blueprints" % _blueprints.size())


## ============================================================================
## BLUEPRINT REGISTRATION
## ============================================================================

func _register_homebase_structures() -> void:
	"""Register homebase tier structures (Cave, Tent, Shack, Cabin, Lodge)"""

	# CAVE (Free starter home!)
	var cave = StructureBlueprint.new(
		"cave",
		"Cave",
		Vector3i(9, 5, 9),
		"homebase",
		"A simple stone cave dwelling. FREE starter home!",
		0  # FREE!
	)
	_build_cave_template(cave)
	_blueprints["cave"] = cave

	# TENT (Small, 1-room)
	var tent = StructureBlueprint.new(
		"tent",
		"Tent",
		Vector3i(5, 3, 5),
		"homebase",
		"A small tent for basic shelter. Perfect for starting out.",
		150  # 150 rust blocks
	)
	_build_tent_template(tent)
	_blueprints["tent"] = tent

	# SHACK (Medium, 1-room with door)
	var shack = StructureBlueprint.new(
		"shack",
		"Shack",
		Vector3i(7, 4, 7),
		"homebase",
		"A wooden shack with a door. More spacious than a tent.",
		400  # 400 rust blocks
	)
	_build_shack_template(shack)
	_blueprints["shack"] = shack

	# CABIN (Large, multi-room)
	var cabin = StructureBlueprint.new(
		"cabin",
		"Cabin",
		Vector3i(10, 5, 10),
		"homebase",
		"A cozy cabin with multiple rooms. Great for long-term living.",
		800  # 800 rust blocks
	)
	_build_cabin_template(cabin)
	_blueprints["cabin"] = cabin

	# LODGE (Very large, multi-story)
	var lodge = StructureBlueprint.new(
		"lodge",
		"Lodge",
		Vector3i(15, 8, 15),
		"homebase",
		"A grand lodge with multiple floors. The ultimate homebase.",
		1500  # 1500 rust blocks
	)
	_build_lodge_template(lodge)
	_blueprints["lodge"] = lodge


func _register_utility_structures() -> void:
	"""Register utility buildings (Barn, Watchtower, Storage, etc.)"""

	# SMALL BARN
	var barn = StructureBlueprint.new(
		"small_barn",
		"Small Barn",
		Vector3i(8, 6, 10),
		"utility",
		"A barn for storage and livestock. Wide interior space.",
		600  # 600 rust blocks
	)
	_build_barn_template(barn)
	_blueprints["small_barn"] = barn

	# WATCHTOWER
	var watchtower = StructureBlueprint.new(
		"watchtower",
		"Watchtower",
		Vector3i(5, 12, 5),
		"utility",
		"A tall tower for surveying the area. Includes ladder.",
		500  # 500 rust blocks
	)
	_build_watchtower_template(watchtower)
	_blueprints["watchtower"] = watchtower

	# STORAGE SHED
	var storage = StructureBlueprint.new(
		"storage_shed",
		"Storage Shed",
		Vector3i(6, 4, 6),
		"utility",
		"A simple shed for storing items and blocks.",
		300  # 300 rust blocks
	)
	_build_storage_template(storage)
	_blueprints["storage_shed"] = storage


## ============================================================================
## TEMPLATE BUILDERS
## ============================================================================

func _build_cave_template(bp: StructureBlueprint) -> void:
	"""Build cave structure (9x5x9) - Stone dome/half-sphere with 2x2 entrance"""
	# Size is 9x5x9, so valid coords are: x=0-8, y=0-4, z=0-8

	# Floor (stone)
	for x in range(9):
		for z in range(9):
			bp.add_block(Vector3i(x, 0, z), "stone")

	# Dome shape - hollow shell (only surface blocks, not filled)
	var center_x = 4.0
	var center_z = 4.0
	var center_y = 0.0  # Base at ground level
	var outer_radius = 4.5  # Outer radius of the dome
	var inner_radius = 3.5  # Inner radius (creates hollow shell)

	for y in range(1, 5):
		for x in range(9):
			for z in range(9):
				# Calculate distance from center point
				var dx = x - center_x
				var dy = y - center_y
				var dz = z - center_z
				var distance = sqrt(dx*dx + dy*dy + dz*dz)

				# Only place blocks in the shell (between inner and outer radius)
				if distance <= outer_radius and distance >= inner_radius:
					# Create 2x2 entrance at front (z=0, centered at x=3-4)
					var is_entrance = (z == 0 and (x == 3 or x == 4) and y <= 2)
					if not is_entrance:
						bp.add_block(Vector3i(x, y, z), "stone")


func _build_tent_template(bp: StructureBlueprint) -> void:
	"""Build tent structure (5x3x5) - A-frame tent"""
	# Size is 5x3x5, so valid coords are: x=0-4, y=0-2, z=0-4

	# Floor (5x5 planks)
	for x in range(5):
		for z in range(5):
			bp.add_block(Vector3i(x, 0, z), "planks")

	# A-frame walls (slanted sides)
	# Front and back walls (z=0 and z=4) - full height
	for y in range(1, 3):
		bp.add_block(Vector3i(1, y, 0), "planks")
		bp.add_block(Vector3i(2, y, 0), "planks")  # Center opening at z=0
		bp.add_block(Vector3i(3, y, 0), "planks")
		# Back wall solid
		for x in range(1, 4):
			bp.add_block(Vector3i(x, y, 4), "planks")

	# Side walls - slanted A-frame shape
	# Level 1 (y=1): Full width
	bp.add_block(Vector3i(0, 1, 1), "planks")
	bp.add_block(Vector3i(0, 1, 2), "planks")
	bp.add_block(Vector3i(0, 1, 3), "planks")
	bp.add_block(Vector3i(4, 1, 1), "planks")
	bp.add_block(Vector3i(4, 1, 2), "planks")
	bp.add_block(Vector3i(4, 1, 3), "planks")

	# Level 2 (y=2): Narrower (peak of A-frame)
	bp.add_block(Vector3i(1, 2, 1), "planks")
	bp.add_block(Vector3i(1, 2, 2), "planks")
	bp.add_block(Vector3i(1, 2, 3), "planks")
	bp.add_block(Vector3i(3, 2, 1), "planks")
	bp.add_block(Vector3i(3, 2, 2), "planks")
	bp.add_block(Vector3i(3, 2, 3), "planks")
	# Ridge line at peak
	bp.add_block(Vector3i(2, 2, 1), "planks")
	bp.add_block(Vector3i(2, 2, 2), "planks")
	bp.add_block(Vector3i(2, 2, 3), "planks")


func _build_shack_template(bp: StructureBlueprint) -> void:
	"""Build shack structure (7x4x7) - Wooden shack with windows and peaked roof"""
	# Size is 7x4x7, so valid coords are: x=0-6, y=0-3, z=0-6

	# Floor
	for x in range(7):
		for z in range(7):
			bp.add_block(Vector3i(x, 0, z), "planks")

	# Walls (y=1-2) with 2x2 entrance at front (z=0, centered)
	for y in range(1, 3):
		# Front wall (z=0) with 2x2 door opening at x=2-3
		for x in range(7):
			if not (x >= 2 and x <= 3 and y <= 2):  # Skip 2x2 entrance
				bp.add_block(Vector3i(x, y, 0), "planks")

		# Back wall (z=6) with windows
		for x in range(7):
			if x == 2 or x == 4:  # Glass windows at x=2 and x=4
				bp.add_block(Vector3i(x, y, 6), "glass")
			else:
				bp.add_block(Vector3i(x, y, 6), "planks")

		# Left wall (x=0) with window
		for z in range(1, 6):
			if z == 3 and y == 2:  # Glass window at middle
				bp.add_block(Vector3i(0, y, z), "glass")
			else:
				bp.add_block(Vector3i(0, y, z), "planks")

		# Right wall (x=6) with window
		for z in range(1, 6):
			if z == 3 and y == 2:  # Glass window at middle
				bp.add_block(Vector3i(6, y, z), "glass")
			else:
				bp.add_block(Vector3i(6, y, z), "planks")

	# Peaked roof (y=3)
	# Outer edges
	for x in range(7):
		bp.add_block(Vector3i(x, 3, 0), "planks")
		bp.add_block(Vector3i(x, 3, 6), "planks")
	for z in range(1, 6):
		bp.add_block(Vector3i(0, 3, z), "planks")
		bp.add_block(Vector3i(6, 3, z), "planks")
	# Ridge line down the middle
	for z in range(1, 6):
		bp.add_block(Vector3i(3, 3, z), "planks")


func _build_cabin_template(bp: StructureBlueprint) -> void:
	"""Build cabin structure (10x5x10) - Log cabin with windows and peaked roof"""
	# Size is 10x5x10, valid coords: x=0-9, y=0-4, z=0-9

	# Floor (planks)
	for x in range(10):
		for z in range(10):
			bp.add_block(Vector3i(x, 0, z), "planks")

	# Walls (y=1-3) - log_y for horizontal logs
	for y in range(1, 4):
		# Front wall (z=0) with 2x2 entrance at x=4-5
		for x in range(10):
			if not (x >= 4 and x <= 5 and y <= 2):  # Skip 2x2 entrance
				bp.add_block(Vector3i(x, y, 0), "log_y")

		# Back wall (z=9) with windows
		for x in range(10):
			if (x == 3 or x == 6) and y == 2:  # Glass windows
				bp.add_block(Vector3i(x, y, 9), "glass")
			else:
				bp.add_block(Vector3i(x, y, 9), "log_y")

		# Left wall (x=0) with window
		for z in range(1, 9):
			if z == 5 and y == 2:  # Glass window
				bp.add_block(Vector3i(0, y, z), "glass")
			else:
				bp.add_block(Vector3i(0, y, z), "log_y")

		# Right wall (x=9) with window
		for z in range(1, 9):
			if z == 5 and y == 2:  # Glass window
				bp.add_block(Vector3i(9, y, z), "glass")
			else:
				bp.add_block(Vector3i(9, y, z), "log_y")

	# Peaked roof (y=4)
	# Full perimeter
	for x in range(10):
		bp.add_block(Vector3i(x, 4, 0), "planks")
		bp.add_block(Vector3i(x, 4, 9), "planks")
	for z in range(1, 9):
		bp.add_block(Vector3i(0, 4, z), "planks")
		bp.add_block(Vector3i(9, 4, z), "planks")
	# Ridge lines
	for z in range(1, 9):
		bp.add_block(Vector3i(4, 4, z), "planks")
		bp.add_block(Vector3i(5, 4, z), "planks")


func _build_lodge_template(bp: StructureBlueprint) -> void:
	"""Build lodge structure (15x8x15) - Large multi-room log lodge"""
	# Size is 15x8x15, valid coords: x=0-14, y=0-7, z=0-14

	# Floor (planks)
	for x in range(15):
		for z in range(15):
			bp.add_block(Vector3i(x, 0, z), "planks")

	# First floor walls (y=1-3) - log_y
	for y in range(1, 4):
		# Front wall (z=0) with main entrance at x=6-7
		for x in range(15):
			if not (x >= 6 and x <= 7 and y <= 2):
				bp.add_block(Vector3i(x, y, 0), "log_y")

		# Back wall (z=14) with windows
		for x in range(15):
			if x in [4, 7, 10] and y == 2:
				bp.add_block(Vector3i(x, y, 14), "glass")
			else:
				bp.add_block(Vector3i(x, y, 14), "log_y")

		# Left and right walls with windows
		for z in range(1, 14):
			# Left wall
			if z in [4, 7, 10] and y == 2:
				bp.add_block(Vector3i(0, y, z), "glass")
			else:
				bp.add_block(Vector3i(0, y, z), "log_y")
			# Right wall
			if z in [4, 7, 10] and y == 2:
				bp.add_block(Vector3i(14, y, z), "glass")
			else:
				bp.add_block(Vector3i(14, y, z), "log_y")

	# Second floor (y=4-6) - partial walls
	for y in range(4, 7):
		# Outer wall sections only
		for x in range(15):
			if x < 3 or x > 11:  # Sides only
				bp.add_block(Vector3i(x, y, 0), "log_y")
				bp.add_block(Vector3i(x, y, 14), "log_y")
		for z in range(1, 14):
			if z < 3 or z > 11:  # Sections only
				bp.add_block(Vector3i(0, y, z), "log_y")
				bp.add_block(Vector3i(14, y, z), "log_y")

	# Peaked roof (y=7)
	for x in range(15):
		bp.add_block(Vector3i(x, 7, 0), "planks")
		bp.add_block(Vector3i(x, 7, 14), "planks")
	for z in range(1, 14):
		bp.add_block(Vector3i(0, 7, z), "planks")
		bp.add_block(Vector3i(14, 7, z), "planks")
	# Ridge line
	for z in range(1, 14):
		bp.add_block(Vector3i(7, 7, z), "planks")


func _build_barn_template(bp: StructureBlueprint) -> void:
	"""Build barn structure (8x6x10) - Barn with high peaked roof and wide entrance"""
	# Size is 8x6x10, valid coords: x=0-7, y=0-5, z=0-9

	# Floor
	for x in range(8):
		for z in range(10):
			bp.add_block(Vector3i(x, 0, z), "planks")

	# Walls (y=1-4)
	for y in range(1, 5):
		# Front wall (z=0) with wide barn door entrance (x=2-5)
		for x in range(8):
			if not (x >= 2 and x <= 5 and y <= 3):  # Wide entrance
				bp.add_block(Vector3i(x, y, 0), "planks")

		# Back wall (z=9) solid
		for x in range(8):
			bp.add_block(Vector3i(x, y, 9), "planks")

		# Side walls
		for z in range(1, 9):
			bp.add_block(Vector3i(0, y, z), "planks")
			bp.add_block(Vector3i(7, y, z), "planks")

	# Barn-style peaked roof (y=5)
	# Full perimeter
	for x in range(8):
		bp.add_block(Vector3i(x, 5, 0), "planks")
		bp.add_block(Vector3i(x, 5, 9), "planks")
	for z in range(1, 9):
		bp.add_block(Vector3i(0, 5, z), "planks")
		bp.add_block(Vector3i(7, 5, z), "planks")
	# High ridge in center
	for z in range(1, 9):
		bp.add_block(Vector3i(3, 5, z), "planks")
		bp.add_block(Vector3i(4, 5, z), "planks")


func _build_watchtower_template(bp: StructureBlueprint) -> void:
	"""Build watchtower structure (5x12x5) - Tower with spiral staircase"""
	# Size is 5x12x5, valid coords: x=0-4, y=0-11, z=0-4

	# Floor (base)
	for x in range(5):
		for z in range(5):
			bp.add_block(Vector3i(x, 0, z), "planks")

	# Walls (y=1-10) with windows every few levels
	for y in range(1, 11):
		# Four corners only for open interior
		bp.add_block(Vector3i(0, y, 0), "planks")
		bp.add_block(Vector3i(4, y, 0), "planks")
		bp.add_block(Vector3i(0, y, 4), "planks")
		bp.add_block(Vector3i(4, y, 4), "planks")

		# Wall sections between corners
		for i in range(1, 4):
			# North wall (z=0) with window every 3 levels
			if not (i == 2 and y % 3 == 0):
				bp.add_block(Vector3i(i, y, 0), "planks")
			elif y % 3 == 0:
				bp.add_block(Vector3i(i, y, 0), "glass")

			# Other walls
			bp.add_block(Vector3i(i, y, 4), "planks")  # South
			bp.add_block(Vector3i(0, y, i), "planks")  # West
			bp.add_block(Vector3i(4, y, i), "planks")  # East

		# Spiral staircase - stairs facing inward
		var stair_z = y % 4
		if stair_z == 0:
			bp.add_block(Vector3i(1, y, 1), "stairs_px")  # Facing +X (east)
		elif stair_z == 1:
			bp.add_block(Vector3i(3, y, 1), "stairs_pz")  # Facing +Z (south)
		elif stair_z == 2:
			bp.add_block(Vector3i(3, y, 3), "stairs_nx")  # Facing -X (west)
		elif stair_z == 3:
			bp.add_block(Vector3i(1, y, 3), "stairs_nz")  # Facing -Z (north)

	# Top platform (y=11) - flat roof for watchtower
	for x in range(5):
		for z in range(5):
			bp.add_block(Vector3i(x, 11, z), "planks")


func _build_storage_template(bp: StructureBlueprint) -> void:
	"""Build storage shed structure (6x4x6) - Simple shed with slanted roof"""
	# Size is 6x4x6, valid coords: x=0-5, y=0-3, z=0-5

	# Floor
	for x in range(6):
		for z in range(6):
			bp.add_block(Vector3i(x, 0, z), "planks")

	# Walls (y=1-2) with small entrance
	for y in range(1, 3):
		# Front wall (z=0) with 1x2 entrance at x=2
		for x in range(6):
			if not (x == 2 and y <= 2):
				bp.add_block(Vector3i(x, y, 0), "planks")

		# Back wall with small window
		for x in range(6):
			if x == 3 and y == 2:
				bp.add_block(Vector3i(x, y, 5), "glass")
			else:
				bp.add_block(Vector3i(x, y, 5), "planks")

		# Side walls
		for z in range(1, 5):
			bp.add_block(Vector3i(0, y, z), "planks")
			bp.add_block(Vector3i(5, y, z), "planks")

	# Slanted roof (y=3)
	for x in range(6):
		bp.add_block(Vector3i(x, 3, 0), "planks")
		bp.add_block(Vector3i(x, 3, 5), "planks")
	for z in range(1, 5):
		bp.add_block(Vector3i(0, 3, z), "planks")
		bp.add_block(Vector3i(5, 3, z), "planks")
	# Ridge
	for z in range(1, 5):
		bp.add_block(Vector3i(2, 3, z), "planks")
		bp.add_block(Vector3i(3, 3, z), "planks")


## ============================================================================
## PUBLIC API
## ============================================================================

func get_blueprint(blueprint_name: String) -> StructureBlueprint:
	"""Get a blueprint by name"""
	if _blueprints.has(blueprint_name):
		return _blueprints[blueprint_name]
	push_error("StructureBlueprintLibrary: Blueprint '%s' not found!" % blueprint_name)
	return null


func get_all_blueprints() -> Array:
	"""Get all registered blueprints"""
	return _blueprints.values()


func get_blueprints_by_category(category: String) -> Array:
	"""Get blueprints filtered by category"""
	var filtered = []
	for bp in _blueprints.values():
		if bp.category == category:
			filtered.append(bp)
	return filtered


func get_blueprint_names() -> Array:
	"""Get list of all blueprint names"""
	return _blueprints.keys()
