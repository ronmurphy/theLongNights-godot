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
	_register_defensive_structures()
	_register_production_structures()
	_register_underground_structures()
	_register_land_expansions()
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


func _register_defensive_structures() -> void:
	"""Register defensive structures (walls, gates, towers)"""

	# WALL SECTION
	var wall = StructureBlueprint.new(
		"wall_section",
		"Wall Section",
		Vector3i(10, 5, 1),
		"defensive",
		"A 10-block long defensive wall. Connect multiple sections to build perimeter walls.",
		100  # 100 rust blocks
	)
	_build_wall_template(wall)
	_blueprints["wall_section"] = wall

	# GATEHOUSE
	var gatehouse = StructureBlueprint.new(
		"gatehouse",
		"Gatehouse",
		Vector3i(7, 8, 5),
		"defensive",
		"Fortified entrance with archway and tower on top. Perfect for base entrances.",
		700  # 700 rust blocks
	)
	_build_gatehouse_template(gatehouse)
	_blueprints["gatehouse"] = gatehouse

	# CORNER TOWER
	var corner_tower = StructureBlueprint.new(
		"corner_tower",
		"Corner Tower",
		Vector3i(5, 8, 5),
		"defensive",
		"Small defensive tower for wall corners. Provides elevated vantage point.",
		400  # 400 rust blocks
	)
	_build_corner_tower_template(corner_tower)
	_blueprints["corner_tower"] = corner_tower


func _register_production_structures() -> void:
	"""Register production/crafting structures"""

	# WELL
	var well = StructureBlueprint.new(
		"well",
		"Well",
		Vector3i(5, 6, 5),
		"production",
		"Stone well with wooden roof. Essential for water collection.",
		250  # 250 rust blocks
	)
	_build_well_template(well)
	_blueprints["well"] = well

	# FORGE
	var forge = StructureBlueprint.new(
		"forge",
		"Forge",
		Vector3i(6, 5, 6),
		"production",
		"Workshop with chimney. Perfect for crafting and smithing.",
		600  # 600 rust blocks
	)
	_build_forge_template(forge)
	_blueprints["forge"] = forge

	# GREENHOUSE
	var greenhouse = StructureBlueprint.new(
		"greenhouse",
		"Greenhouse",
		Vector3i(8, 5, 6),
		"production",
		"Glass-roofed structure for protected farming. Grow crops year-round.",
		500  # 500 rust blocks
	)
	_build_greenhouse_template(greenhouse)
	_blueprints["greenhouse"] = greenhouse

	# SMOKEHOUSE
	var smokehouse = StructureBlueprint.new(
		"smokehouse",
		"Smokehouse",
		Vector3i(4, 5, 4),
		"production",
		"Small building for preserving and smoking food.",
		300  # 300 rust blocks
	)
	_build_smokehouse_template(smokehouse)
	_blueprints["smokehouse"] = smokehouse


func _register_underground_structures() -> void:
	"""Register underground structures (dig down into platform)"""

	# ROOT CELLAR - Extends 3 blocks DOWN from placement point
	var root_cellar = StructureBlueprint.new(
		"root_cellar",
		"Root Cellar",
		Vector3i(6, 5, 6),  # 5 height includes 3 below ground, 2 above
		"underground",
		"Semi-underground storage. Digs 3 blocks down into platform. Stays cool for food storage.",
		350  # 350 rust blocks
	)
	_build_root_cellar_template(root_cellar)
	_blueprints["root_cellar"] = root_cellar

	# UNDERGROUND BUNKER - Extends 5 blocks DOWN from placement point
	var bunker = StructureBlueprint.new(
		"bunker",
		"Underground Bunker",
		Vector3i(10, 8, 10),  # 8 height includes 5 below ground, 3 above
		"underground",
		"Fortified underground bunker. Digs 5 blocks down into platform. Safe shelter from threats.",
		800  # 800 rust blocks
	)
	_build_bunker_template(bunker)
	_blueprints["bunker"] = bunker


func _register_land_expansions() -> void:
	"""Register land expansion platforms (special - no templates, triggers platform generation)"""

	# DISABLED - Terrain expansions are currently disabled
	# TODO: Re-enable when system is working properly

	## WILDERNESS EXPANSION - Natural terrain with hills and trees
	#var wilderness = StructureBlueprint.new(
		#"wilderness_expansion",
		#"Wilderness Expansion",
		#Vector3i(160, 10, 160),  # 10x10 chunks
		#"land_expansion",
		#"⚠️ PLACE ON EDGE OF HOMEBASE! Natural platform (160x160 blocks) with rolling hills and trees. Spawns 10 blocks away. First one FREE, then 500 rust blocks.",
		#500  # 500 rust blocks (after first free)
	#)
	## No template needed - handled by PlatformExpansion.gd
	#_blueprints["wilderness_expansion"] = wilderness

	## CONSTRUCTION PLATFORM - Flat building surface
	#var construction = StructureBlueprint.new(
		#"construction_platform",
		#"Construction Platform",
		#Vector3i(160, 10, 160),  # 10x10 chunks
		#"land_expansion",
		#"⚠️ PLACE ON EDGE OF HOMEBASE! Flat platform (160x160 blocks) for organized building. Spawns 10 blocks away. First one FREE, then 400 rust blocks.",
		#400  # 400 rust blocks (after first free)
	#)
	## No template needed - handled by PlatformExpansion.gd
	#_blueprints["construction_platform"] = construction

	## TERRAIN EXTRACTION - Rips terrain from ground and lifts to sky (LORE ACCURATE!)
	#var extraction = StructureBlueprint.new(
		#"terrain_extraction",
		#"Terrain Extraction",
		#Vector3i(160, 20, 160),  # 10x10 chunks
		#"land_expansion",
		#"⚠️ PLACE ON EDGE OF HOMEBASE! Rips a 160x160x20 chunk of terrain from the ground beneath you and places it in the sky. LORE ACCURATE sky ruin creation! Spawns 10 blocks away. First one FREE ONLY!",
		#0  # Always FREE (one-time only)
	#)
	## No template needed - handled by PlatformExpansion.gd
	#_blueprints["terrain_extraction"] = extraction


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

	# A-frame roof (y=2): Complete roof coverage
	# Fill entire top layer to create solid A-frame roof
	for z in range(5):
		for x in range(1, 4):  # x=1,2,3 (narrower than base)
			bp.add_block(Vector3i(x, 2, z), "planks")


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

	# Peaked roof (y=3) - Complete fill for solid roof
	# Fill entire roof area to create solid peaked roof
	for x in range(7):
		for z in range(7):
			bp.add_block(Vector3i(x, 3, z), "planks")


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

	# Peaked roof (y=4) - Complete fill for solid roof
	# Fill entire roof area to create solid peaked roof
	for x in range(10):
		for z in range(10):
			bp.add_block(Vector3i(x, 4, z), "planks")


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

	# Peaked roof (y=7) - Complete fill for solid roof
	# Fill entire roof area to create solid peaked roof
	for x in range(15):
		for z in range(15):
			bp.add_block(Vector3i(x, 7, z), "planks")


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

	# Barn-style peaked roof (y=5) - Complete fill for solid roof
	# Fill entire roof area to create solid barn roof
	for x in range(8):
		for z in range(10):
			bp.add_block(Vector3i(x, 5, z), "planks")


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

	# Slanted roof (y=3) - Complete fill for solid roof
	# Fill entire roof area to create solid slanted roof
	for x in range(6):
		for z in range(6):
			bp.add_block(Vector3i(x, 3, z), "planks")


func _build_wall_template(bp: StructureBlueprint) -> void:
	"""Build wall section (10x5x1) - Straight defensive wall"""
	# Size is 10x5x1, valid coords: x=0-9, y=0-4, z=0

	# Build solid wall - 10 blocks long, 5 blocks high, 1 block thick
	for y in range(5):
		for x in range(10):
			bp.add_block(Vector3i(x, y, 0), "stone")


func _build_gatehouse_template(bp: StructureBlueprint) -> void:
	"""Build gatehouse (7x8x5) - Fortified entrance with archway and tower"""
	# Size is 7x8x5, valid coords: x=0-6, y=0-7, z=0-4

	# Floor
	for x in range(7):
		for z in range(5):
			bp.add_block(Vector3i(x, 0, z), "stone")

	# Walls with archway entrance (3x3 opening at center)
	for y in range(1, 6):
		# Front wall (z=0) with archway at x=2-4
		for x in range(7):
			if not (x >= 2 and x <= 4 and y <= 3):  # 3-wide, 3-tall archway
				bp.add_block(Vector3i(x, y, 0), "stone")

		# Back wall (z=4) with archway
		for x in range(7):
			if not (x >= 2 and x <= 4 and y <= 3):
				bp.add_block(Vector3i(x, y, 4), "stone")

		# Side walls (solid)
		for z in range(1, 4):
			bp.add_block(Vector3i(0, y, z), "stone")
			bp.add_block(Vector3i(6, y, z), "stone")

	# Tower section (y=6-7) - Narrower observation deck
	for y in range(6, 8):
		# Corner posts
		bp.add_block(Vector3i(0, y, 0), "stone")
		bp.add_block(Vector3i(6, y, 0), "stone")
		bp.add_block(Vector3i(0, y, 4), "stone")
		bp.add_block(Vector3i(6, y, 4), "stone")

		# Walls between corners
		for x in range(1, 6):
			bp.add_block(Vector3i(x, y, 0), "stone")
			bp.add_block(Vector3i(x, y, 4), "stone")
		for z in range(1, 4):
			bp.add_block(Vector3i(0, y, z), "stone")
			bp.add_block(Vector3i(6, y, z), "stone")


func _build_corner_tower_template(bp: StructureBlueprint) -> void:
	"""Build corner tower (5x8x5) - Small defensive tower"""
	# Size is 5x8x5, valid coords: x=0-4, y=0-7, z=0-4

	# Floor (stone base)
	for x in range(5):
		for z in range(5):
			bp.add_block(Vector3i(x, 0, z), "stone")

	# Tower walls (y=1-6) - hollow interior
	for y in range(1, 7):
		# Four corners (solid pillars)
		bp.add_block(Vector3i(0, y, 0), "stone")
		bp.add_block(Vector3i(4, y, 0), "stone")
		bp.add_block(Vector3i(0, y, 4), "stone")
		bp.add_block(Vector3i(4, y, 4), "stone")

		# Walls between corners (with arrow slits every 2 levels)
		for i in range(1, 4):
			# North wall (z=0)
			if not (i == 2 and y % 2 == 0):  # Arrow slit in center
				bp.add_block(Vector3i(i, y, 0), "stone")
			# South wall (z=4)
			if not (i == 2 and y % 2 == 0):
				bp.add_block(Vector3i(i, y, 4), "stone")
			# West wall (x=0)
			if not (i == 2 and y % 2 == 0):
				bp.add_block(Vector3i(0, y, i), "stone")
			# East wall (x=4)
			if not (i == 2 and y % 2 == 0):
				bp.add_block(Vector3i(4, y, i), "stone")

	# Crenellated top (y=7) - battlements
	for x in range(5):
		for z in range(5):
			# Add battlements at corners and edges (checkerboard pattern)
			if (x + z) % 2 == 0 or x == 0 or x == 4 or z == 0 or z == 4:
				bp.add_block(Vector3i(x, 7, z), "stone")


func _build_well_template(bp: StructureBlueprint) -> void:
	"""Build well (5x6x5) - Stone well with wooden roof"""
	# Size is 5x6x5, valid coords: x=0-4, y=0-5, z=0-4

	# Stone base and well shaft (y=0-2)
	# Outer ring at ground level
	for x in range(5):
		for z in range(5):
			# Ring pattern - solid edges, hollow center
			if x == 0 or x == 4 or z == 0 or z == 4:
				bp.add_block(Vector3i(x, 0, z), "stone")
				bp.add_block(Vector3i(x, 1, z), "stone")
				bp.add_block(Vector3i(x, 2, z), "stone")

	# Wooden posts (y=3-4) at four corners
	bp.add_block(Vector3i(0, 3, 0), "log_y")
	bp.add_block(Vector3i(4, 3, 0), "log_y")
	bp.add_block(Vector3i(0, 3, 4), "log_y")
	bp.add_block(Vector3i(4, 3, 4), "log_y")
	bp.add_block(Vector3i(0, 4, 0), "log_y")
	bp.add_block(Vector3i(4, 4, 0), "log_y")
	bp.add_block(Vector3i(0, 4, 4), "log_y")
	bp.add_block(Vector3i(4, 4, 4), "log_y")

	# Roof (y=5) - planks covering the well
	for x in range(5):
		for z in range(5):
			bp.add_block(Vector3i(x, 5, z), "planks")


func _build_forge_template(bp: StructureBlueprint) -> void:
	"""Build forge (6x5x6) - Workshop with chimney"""
	# Size is 6x5x6, valid coords: x=0-5, y=0-4, z=0-5

	# Floor (stone - heat resistant)
	for x in range(6):
		for z in range(6):
			bp.add_block(Vector3i(x, 0, z), "stone")

	# Walls (y=1-3) - mixture of stone and planks
	for y in range(1, 4):
		# Front wall (z=0) with entrance at x=2
		for x in range(6):
			if not (x == 2 and y <= 2):  # 1-wide entrance
				if y == 1:
					bp.add_block(Vector3i(x, y, 0), "stone")
				else:
					bp.add_block(Vector3i(x, y, 0), "planks")

		# Back wall (z=5) - solid stone (heat protection)
		for x in range(6):
			bp.add_block(Vector3i(x, y, 5), "stone")

		# Side walls
		for z in range(1, 5):
			bp.add_block(Vector3i(0, y, z), "planks")
			bp.add_block(Vector3i(5, y, z), "planks")

	# Chimney (back corner, y=4+) - extends upward
	bp.add_block(Vector3i(5, 4, 5), "stone")
	bp.add_block(Vector3i(4, 4, 5), "stone")
	bp.add_block(Vector3i(5, 4, 4), "stone")

	# Roof (y=4) - planks with hole for chimney
	for x in range(6):
		for z in range(6):
			# Skip chimney area
			if not (x >= 4 and z >= 4):
				bp.add_block(Vector3i(x, 4, z), "planks")


func _build_greenhouse_template(bp: StructureBlueprint) -> void:
	"""Build greenhouse (8x5x6) - Glass structure for farming"""
	# Size is 8x5x6, valid coords: x=0-7, y=0-4, z=0-5

	# Floor (planks)
	for x in range(8):
		for z in range(6):
			bp.add_block(Vector3i(x, 0, z), "planks")

	# Walls (y=1-3) - glass with wooden frame
	for y in range(1, 4):
		# Front wall (z=0) with entrance at x=3-4
		for x in range(8):
			if not (x >= 3 and x <= 4 and y <= 2):  # Entrance
				if x % 2 == 0:  # Every other block is wood frame
					bp.add_block(Vector3i(x, y, 0), "planks")
				else:
					bp.add_block(Vector3i(x, y, 0), "glass")

		# Back wall (z=5) - glass with frame
		for x in range(8):
			if x % 2 == 0:
				bp.add_block(Vector3i(x, y, 5), "planks")
			else:
				bp.add_block(Vector3i(x, y, 5), "glass")

		# Side walls - mostly glass
		for z in range(1, 5):
			if z % 2 == 0:
				bp.add_block(Vector3i(0, y, z), "planks")
				bp.add_block(Vector3i(7, y, z), "planks")
			else:
				bp.add_block(Vector3i(0, y, z), "glass")
				bp.add_block(Vector3i(7, y, z), "glass")

	# Glass roof (y=4) - full glass coverage
	for x in range(8):
		for z in range(6):
			bp.add_block(Vector3i(x, 4, z), "glass")


func _build_smokehouse_template(bp: StructureBlueprint) -> void:
	"""Build smokehouse (4x5x4) - Small smoking building"""
	# Size is 4x5x4, valid coords: x=0-3, y=0-4, z=0-3

	# Floor (stone)
	for x in range(4):
		for z in range(4):
			bp.add_block(Vector3i(x, 0, z), "stone")

	# Walls (y=1-3) - mostly solid with small vents
	for y in range(1, 4):
		# Front wall (z=0) with entrance at x=1
		for x in range(4):
			if not (x == 1 and y <= 2):
				bp.add_block(Vector3i(x, y, 0), "planks")

		# Other walls solid
		for x in range(4):
			bp.add_block(Vector3i(x, y, 3), "planks")
		for z in range(1, 3):
			bp.add_block(Vector3i(0, y, z), "planks")
			bp.add_block(Vector3i(3, y, z), "planks")

	# Roof with chimney hole (y=4)
	for x in range(4):
		for z in range(4):
			# Leave center open for smoke
			if not (x >= 1 and x <= 2 and z >= 1 and z <= 2):
				bp.add_block(Vector3i(x, 4, z), "planks")


func _build_root_cellar_template(bp: StructureBlueprint) -> void:
	"""Build root cellar (6x5x6) - Semi-underground storage
	Extends 3 blocks DOWN from placement point (y=-3 to y=1)"""
	# Size is 6x5x6, valid coords: x=0-5, y=-3 to 1, z=0-5

	# Entrance hatch at ground level (y=0-1)
	for x in range(6):
		for z in range(6):
			if x >= 2 and x <= 3 and z >= 2 and z <= 3:
				# Leave center open as entrance hatch
				pass
			else:
				bp.add_block(Vector3i(x, 0, z), "planks")

	# Slanted roof/mound (y=1) - partial coverage
	for x in range(6):
		for z in range(6):
			if x == 0 or x == 5 or z == 0 or z == 5:
				bp.add_block(Vector3i(x, 1, z), "planks")

	# UNDERGROUND SECTION (negative Y)
	# Floor (y=-3) - stone
	for x in range(6):
		for z in range(6):
			bp.add_block(Vector3i(x, -3, z), "stone")

	# Underground walls (y=-2 to y=-1)
	for y in range(-2, 0):
		# All four walls
		for x in range(6):
			bp.add_block(Vector3i(x, y, 0), "stone")
			bp.add_block(Vector3i(x, y, 5), "stone")
		for z in range(1, 5):
			bp.add_block(Vector3i(0, y, z), "stone")
			bp.add_block(Vector3i(5, y, z), "stone")


func _build_bunker_template(bp: StructureBlueprint) -> void:
	"""Build underground bunker (10x8x10) - Fortified underground shelter
	Extends 5 blocks DOWN from placement point (y=-5 to y=2)"""
	# Size is 10x8x10, valid coords: x=0-9, y=-5 to 2, z=0-9

	# Entrance structure at ground level (y=0-2)
	for x in range(10):
		for z in range(10):
			# Build entrance bunker top (armored hatch area)
			if x == 0 or x == 9 or z == 0 or z == 9:
				bp.add_block(Vector3i(x, 0, z), "stone")
				bp.add_block(Vector3i(x, 1, z), "stone")

	# Entrance hatch opening (center 4x4)
	# Leave y=0 center open for stairs/ladder access

	# Low profile roof (y=2) - minimal above-ground visibility
	for x in range(10):
		for z in range(10):
			if x <= 1 or x >= 8 or z <= 1 or z >= 8:
				bp.add_block(Vector3i(x, 2, z), "stone")

	# UNDERGROUND SECTION (negative Y)
	# Floor (y=-5) - reinforced stone
	for x in range(10):
		for z in range(10):
			bp.add_block(Vector3i(x, -5, z), "stone")

	# Underground walls (y=-4 to y=-1) - thick stone walls
	for y in range(-4, 0):
		# All four walls - double thick
		for x in range(10):
			bp.add_block(Vector3i(x, y, 0), "stone")
			bp.add_block(Vector3i(x, y, 1), "stone")
			bp.add_block(Vector3i(x, y, 9), "stone")
			bp.add_block(Vector3i(x, y, 8), "stone")
		for z in range(2, 8):
			bp.add_block(Vector3i(0, y, z), "stone")
			bp.add_block(Vector3i(1, y, z), "stone")
			bp.add_block(Vector3i(9, y, z), "stone")
			bp.add_block(Vector3i(8, y, z), "stone")


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
