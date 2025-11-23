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
	_register_decorative_structures()
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

	# STONE COTTAGE (Alternative homebase)
	var stone_cottage = StructureBlueprint.new(
		"stone_cottage",
		"Stone Cottage",
		Vector3i(9, 5, 9),
		"homebase",
		"Sturdy stone cottage with wooden roof. More durable than wooden homes.",
		700  # 700 rust blocks
	)
	_build_stone_cottage_template(stone_cottage)
	_blueprints["stone_cottage"] = stone_cottage

	# SANDSTONE HOUSE (Desert aesthetic)
	var sandstone_house = StructureBlueprint.new(
		"sandstone_house",
		"Sandstone House",
		Vector3i(8, 5, 8),
		"homebase",
		"Desert-style sandstone house with flat roof. Cool in hot climates.",
		650  # 650 rust blocks
	)
	_build_sandstone_house_template(sandstone_house)
	_blueprints["sandstone_house"] = sandstone_house

	# BIRCH CABIN (Forest aesthetic)
	var birch_cabin = StructureBlueprint.new(
		"birch_cabin",
		"Birch Cabin",
		Vector3i(9, 5, 7),
		"homebase",
		"Cozy cabin built from light birch wood. Natural forest aesthetic.",
		550  # 550 rust blocks
	)
	_build_birch_cabin_template(birch_cabin)
	_blueprints["birch_cabin"] = birch_cabin


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

	# ROAD SECTION (Straight)
	var road = StructureBlueprint.new(
		"road_section",
		"Road Section",
		Vector3i(10, 1, 3),
		"utility",
		"Straight stone road section. Connect multiple to create pathways.",
		80  # 80 rust blocks
	)
	_build_road_template(road)
	_blueprints["road_section"] = road

	# ROAD CORNER
	var road_corner = StructureBlueprint.new(
		"road_corner",
		"Road Corner",
		Vector3i(5, 1, 5),
		"utility",
		"90-degree road corner. Connect with road sections.",
		50  # 50 rust blocks
	)
	_build_road_corner_template(road_corner)
	_blueprints["road_corner"] = road_corner

	# ROAD INTERSECTION
	var road_intersection = StructureBlueprint.new(
		"road_intersection",
		"Road Intersection",
		Vector3i(7, 1, 7),
		"utility",
		"4-way road intersection. Hub for connecting multiple roads.",
		120  # 120 rust blocks
	)
	_build_road_intersection_template(road_intersection)
	_blueprints["road_intersection"] = road_intersection


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

	# GUARD TOWER (Large, tall)
	var guard_tower = StructureBlueprint.new(
		"guard_tower",
		"Guard Tower",
		Vector3i(7, 15, 7),
		"defensive",
		"Tall stone guard tower with lookout platform. Maximum visibility and defense.",
		900  # 900 rust blocks
	)
	_build_guard_tower_template(guard_tower)
	_blueprints["guard_tower"] = guard_tower

	# FORTIFIED OUTPOST
	var outpost = StructureBlueprint.new(
		"fortified_outpost",
		"Fortified Outpost",
		Vector3i(9, 6, 9),
		"defensive",
		"Fortified stone outpost with thick walls. Defendable garrison building.",
		750  # 750 rust blocks
	)
	_build_fortified_outpost_template(outpost)
	_blueprints["fortified_outpost"] = outpost


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


func _register_decorative_structures() -> void:
	"""Register decorative structures (fountains, arches, etc.)"""

	# FOUNTAIN
	var fountain = StructureBlueprint.new(
		"fountain",
		"Fountain",
		Vector3i(7, 4, 7),
		"decorative",
		"Stone fountain with water. Decorative centerpiece for plazas.",
		200  # 200 rust blocks
	)
	_build_fountain_template(fountain)
	_blueprints["fountain"] = fountain

	# GARDEN ARCHWAY
	var archway = StructureBlueprint.new(
		"garden_archway",
		"Garden Archway",
		Vector3i(5, 5, 3),
		"decorative",
		"Decorative stone archway. Perfect entrance to gardens or pathways.",
		150  # 150 rust blocks
	)
	_build_archway_template(archway)
	_blueprints["garden_archway"] = archway

	# LAMP POST
	var lamp_post = StructureBlueprint.new(
		"lamp_post",
		"Lamp Post",
		Vector3i(3, 6, 3),
		"decorative",
		"Tall stone lamp post with glass top. Lights up your base.",
		100  # 100 rust blocks
	)
	_build_lamp_post_template(lamp_post)
	_blueprints["lamp_post"] = lamp_post

	# MARKET STALL
	var market_stall = StructureBlueprint.new(
		"market_stall",
		"Market Stall",
		Vector3i(5, 4, 4),
		"decorative",
		"Small wooden market stall with counter. Add life to your town.",
		180  # 180 rust blocks
	)
	_build_market_stall_template(market_stall)
	_blueprints["market_stall"] = market_stall

	# WOODEN BRIDGE
	var bridge = StructureBlueprint.new(
		"wooden_bridge",
		"Wooden Bridge",
		Vector3i(3, 2, 10),
		"decorative",
		"Wooden plank bridge. Connect platforms or span gaps.",
		140  # 140 rust blocks
	)
	_build_wooden_bridge_template(bridge)
	_blueprints["wooden_bridge"] = bridge

	# SHRINE
	var shrine = StructureBlueprint.new(
		"shrine",
		"Shrine",
		Vector3i(5, 6, 5),
		"decorative",
		"Ancient ruin stone shrine with steps. Mystical decorative monument.",
		250  # 250 rust blocks
	)
	_build_shrine_template(shrine)
	_blueprints["shrine"] = shrine

	# CAMPFIRE CIRCLE
	var campfire = StructureBlueprint.new(
		"campfire_circle",
		"Campfire Circle",
		Vector3i(7, 2, 7),
		"decorative",
		"Stone seating circle with central campfire pit. Gathering spot.",
		120  # 120 rust blocks
	)
	_build_campfire_circle_template(campfire)
	_blueprints["campfire_circle"] = campfire


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
	"""Register land expansion structures (flat terrain lots)"""

	# LAND LOT - 10×10 flat terrain (grass, 2 dirt, 1 stone)
	var land_lot = StructureBlueprint.new(
		"land_lot",
		"Land Lot (10×10)",
		Vector3i(10, 4, 10),  # 10×10 base, 4 layers tall
		"terrain",
		"Flat 10×10 land lot. Place multiple lots to expand your building area. Layers: grass, dirt, dirt, stone.",
		100  # 100 rust blocks
	)
	_build_land_lot_template(land_lot)
	_blueprints["land_lot"] = land_lot


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


func _build_fountain_template(bp: StructureBlueprint) -> void:
	"""Build fountain (7x4x7) - Stone fountain with water centerpiece"""
	# Size is 7x4x7, so valid coords are: x=0-6, y=0-3, z=0-6
	# Center at x=3, z=3

	# Base platform (stone)
	for x in range(7):
		for z in range(7):
			bp.add_block(Vector3i(x, 0, z), "stone")

	# Outer ring walls (1 block tall)
	for x in range(7):
		for z in range(7):
			# Ring at edge (not corners for nicer look)
			if (x == 0 or x == 6 or z == 0 or z == 6) and not (x in [0, 6] and z in [0, 6]):
				bp.add_block(Vector3i(x, 1, z), "stone")

	# Inner basin (2 blocks tall)
	for x in range(2, 5):
		for z in range(2, 5):
			if x == 2 or x == 4 or z == 2 or z == 4:
				bp.add_block(Vector3i(x, 1, z), "stone")
				bp.add_block(Vector3i(x, 2, z), "stone")

	# Water in center (3x3)
	for x in range(2, 5):
		for z in range(2, 5):
			bp.add_block(Vector3i(x, 1, z), "water_top")

	# Central pillar
	bp.add_block(Vector3i(3, 2, 3), "stone")
	bp.add_block(Vector3i(3, 3, 3), "stone")


func _build_archway_template(bp: StructureBlueprint) -> void:
	"""Build garden archway (5x5x3) - Decorative stone arch"""
	# Size is 5x5x3, so valid coords are: x=0-4, y=0-4, z=0-2
	# Entrance runs along Z axis (depth), center at x=2

	# Base blocks (stone)
	for x in range(5):
		for z in range(3):
			bp.add_block(Vector3i(x, 0, z), "stone")

	# Left pillar (x=0-1)
	for y in range(1, 5):
		bp.add_block(Vector3i(0, y, 0), "stone")
		bp.add_block(Vector3i(1, y, 0), "stone")
		bp.add_block(Vector3i(0, y, 2), "stone")
		bp.add_block(Vector3i(1, y, 2), "stone")

	# Right pillar (x=3-4)
	for y in range(1, 5):
		bp.add_block(Vector3i(3, y, 0), "stone")
		bp.add_block(Vector3i(4, y, 0), "stone")
		bp.add_block(Vector3i(3, y, 2), "stone")
		bp.add_block(Vector3i(4, y, 2), "stone")

	# Arch top (stone bricks)
	bp.add_block(Vector3i(2, 4, 0), "stone_bricks")
	bp.add_block(Vector3i(2, 4, 1), "stone_bricks")
	bp.add_block(Vector3i(2, 4, 2), "stone_bricks")


func _build_lamp_post_template(bp: StructureBlueprint) -> void:
	"""Build lamp post (3x6x3) - Tall stone post with glass lantern"""
	# Size is 3x6x3, so valid coords are: x=0-2, y=0-5, z=0-2
	# Center at x=1, z=1

	# Base (stone)
	for x in range(3):
		for z in range(3):
			bp.add_block(Vector3i(x, 0, z), "stone")

	# Central post (stone)
	for y in range(1, 5):
		bp.add_block(Vector3i(1, y, 1), "stone")

	# Lantern housing (glass with stone frame)
	# Stone frame
	bp.add_block(Vector3i(0, 5, 1), "stone")
	bp.add_block(Vector3i(2, 5, 1), "stone")
	bp.add_block(Vector3i(1, 5, 0), "stone")
	bp.add_block(Vector3i(1, 5, 2), "stone")

	# Glass panels
	bp.add_block(Vector3i(1, 5, 1), "glass")  # Center glow


func _build_market_stall_template(bp: StructureBlueprint) -> void:
	"""Build market stall (5x4x4) - Small wooden market stand"""
	# Size is 5x4x4, so valid coords are: x=0-4, y=0-3, z=0-3
	# Counter faces z=0 (front)

	# Floor (planks)
	for x in range(5):
		for z in range(4):
			bp.add_block(Vector3i(x, 0, z), "planks")

	# Back wall (z=3)
	for y in range(1, 4):
		for x in range(5):
			bp.add_block(Vector3i(x, y, 3), "planks")

	# Side walls
	for y in range(1, 4):
		bp.add_block(Vector3i(0, y, 1), "planks")
		bp.add_block(Vector3i(0, y, 2), "planks")
		bp.add_block(Vector3i(4, y, 1), "planks")
		bp.add_block(Vector3i(4, y, 2), "planks")

	# Counter (front, at z=0)
	for x in range(1, 4):
		bp.add_block(Vector3i(x, 1, 0), "planks")

	# Roof (overhang)
	for x in range(5):
		for z in range(4):
			bp.add_block(Vector3i(x, 3, z), "planks")

	# Add some crates for decoration
	bp.add_block(Vector3i(1, 1, 2), "crate")
	bp.add_block(Vector3i(3, 1, 2), "crate")


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


func _build_land_lot_template(bp: StructureBlueprint) -> void:
	"""Build 10×10 land lot - Flat terrain with grass, dirt, and stone layers
	4 layers: stone (bottom), dirt, dirt, grass (top)"""

	# Layer 0: Stone (bottom foundation)
	for x in range(10):
		for z in range(10):
			bp.add_block(Vector3i(x, 0, z), "stone")

	# Layer 1: Dirt
	for x in range(10):
		for z in range(10):
			bp.add_block(Vector3i(x, 1, z), "dirt")

	# Layer 2: Dirt
	for x in range(10):
		for z in range(10):
			bp.add_block(Vector3i(x, 2, z), "dirt")

	# Layer 3: Grass (top surface)
	for x in range(10):
		for z in range(10):
			bp.add_block(Vector3i(x, 3, z), "grass")


func _build_stone_cottage_template(bp: StructureBlueprint) -> void:
	"""Build stone cottage (9x5x9) - Stone walls with wooden roof"""
	# Size is 9x5x9, so valid coords are: x=0-8, y=0-4, z=0-8

	# Floor (stone)
	for x in range(9):
		for z in range(9):
			bp.add_block(Vector3i(x, 0, z), "stone")

	# Walls (stone) - hollow interior
	for y in range(1, 4):
		for x in range(9):
			# Front wall (z=0) with door
			if x < 3 or x > 5:
				bp.add_block(Vector3i(x, y, 0), "stone")
			# Back wall (z=8)
			bp.add_block(Vector3i(x, y, 8), "stone")
		for z in range(1, 8):
			# Left wall
			bp.add_block(Vector3i(0, y, z), "stone")
			# Right wall
			bp.add_block(Vector3i(8, y, z), "stone")

	# Roof (planks)
	for x in range(9):
		for z in range(9):
			bp.add_block(Vector3i(x, 4, z), "planks")

	# Windows (glass)
	bp.add_block(Vector3i(2, 2, 0), "glass")
	bp.add_block(Vector3i(6, 2, 0), "glass")
	bp.add_block(Vector3i(0, 2, 4), "glass")
	bp.add_block(Vector3i(8, 2, 4), "glass")


func _build_sandstone_house_template(bp: StructureBlueprint) -> void:
	"""Build sandstone house (8x5x8) - Desert style with flat roof"""
	# Size is 8x5x8, so valid coords are: x=0-7, y=0-4, z=0-7

	# Floor (sandstone)
	for x in range(8):
		for z in range(8):
			bp.add_block(Vector3i(x, 0, z), "sandstone")

	# Walls (sandstone) - hollow interior
	for y in range(1, 4):
		for x in range(8):
			# Front wall with door
			if x < 3 or x > 4:
				bp.add_block(Vector3i(x, y, 0), "sandstone")
			# Back wall
			bp.add_block(Vector3i(x, y, 7), "sandstone")
		for z in range(1, 7):
			# Left wall
			bp.add_block(Vector3i(0, y, z), "sandstone")
			# Right wall
			bp.add_block(Vector3i(7, y, z), "sandstone")

	# Flat roof (sandstone)
	for x in range(8):
		for z in range(8):
			bp.add_block(Vector3i(x, 4, z), "sandstone")

	# Small windows
	bp.add_block(Vector3i(1, 2, 0), "glass")
	bp.add_block(Vector3i(6, 2, 0), "glass")


func _build_birch_cabin_template(bp: StructureBlueprint) -> void:
	"""Build birch cabin (9x5x7) - Light birch wood construction"""
	# Size is 9x5x7, so valid coords are: x=0-8, y=0-4, z=0-6

	# Floor (birch planks - using planks)
	for x in range(9):
		for z in range(7):
			bp.add_block(Vector3i(x, 0, z), "planks")

	# Walls (birch logs)
	for y in range(1, 4):
		for x in range(9):
			# Front wall with door
			if x < 3 or x > 5:
				bp.add_block(Vector3i(x, y, 0), "birch_log_y")
			# Back wall
			bp.add_block(Vector3i(x, y, 6), "birch_log_y")
		for z in range(1, 6):
			# Left wall
			bp.add_block(Vector3i(0, y, z), "birch_log_y")
			# Right wall
			bp.add_block(Vector3i(8, y, z), "birch_log_y")

	# Roof (planks)
	for x in range(9):
		for z in range(7):
			bp.add_block(Vector3i(x, 4, z), "planks")

	# Windows
	bp.add_block(Vector3i(2, 2, 0), "glass")
	bp.add_block(Vector3i(6, 2, 0), "glass")


func _build_road_template(bp: StructureBlueprint) -> void:
	"""Build road section (10x1x3) - Straight stone road"""
	# Size is 10x1x3, so valid coords are: x=0-9, y=0, z=0-2

	# Simple stone road
	for x in range(10):
		for z in range(3):
			bp.add_block(Vector3i(x, 0, z), "stone")


func _build_road_corner_template(bp: StructureBlueprint) -> void:
	"""Build road corner (5x1x5) - 90 degree corner"""
	# Size is 5x1x5, so valid coords are: x=0-4, y=0, z=0-4

	# L-shaped corner (connects at x=0 and z=0)
	for x in range(5):
		for z in range(3):
			bp.add_block(Vector3i(x, 0, z), "stone")
	for x in range(3):
		for z in range(5):
			bp.add_block(Vector3i(x, 0, z), "stone")


func _build_road_intersection_template(bp: StructureBlueprint) -> void:
	"""Build road intersection (7x1x7) - 4-way crossroads"""
	# Size is 7x1x7, so valid coords are: x=0-6, y=0, z=0-6

	# Full 7x7 stone platform for intersection
	for x in range(7):
		for z in range(7):
			bp.add_block(Vector3i(x, 0, z), "stone")


func _build_guard_tower_template(bp: StructureBlueprint) -> void:
	"""Build guard tower (7x15x7) - Tall defensive tower"""
	# Size is 7x15x7, so valid coords are: x=0-6, y=0-14, z=0-6

	# Floor (stone)
	for x in range(7):
		for z in range(7):
			bp.add_block(Vector3i(x, 0, z), "stone")

	# Tower shaft (stone) - hollow interior from y=1 to y=11
	for y in range(1, 12):
		for x in range(7):
			# Front and back walls
			if x == 0 or x == 6:
				for z in range(7):
					bp.add_block(Vector3i(x, y, z), "stone")
			else:
				bp.add_block(Vector3i(x, y, 0), "stone")
				bp.add_block(Vector3i(x, y, 6), "stone")
		# Side walls (inner)
		for z in range(1, 6):
			bp.add_block(Vector3i(0, y, z), "stone")
			bp.add_block(Vector3i(6, y, z), "stone")

	# Lookout platform (y=12)
	for x in range(7):
		for z in range(7):
			bp.add_block(Vector3i(x, 12, z), "stone")

	# Battlements (y=13-14) - corners and edges
	for pos in [[0,13,0], [6,13,0], [0,13,6], [6,13,6],
				[0,14,0], [6,14,0], [0,14,6], [6,14,6],
				[3,13,0], [3,13,6], [0,13,3], [6,13,3]]:
		bp.add_block(Vector3i(pos[0], pos[1], pos[2]), "stone")


func _build_fortified_outpost_template(bp: StructureBlueprint) -> void:
	"""Build fortified outpost (9x6x9) - Thick-walled garrison"""
	# Size is 9x6x9, so valid coords are: x=0-8, y=0-5, z=0-8

	# Floor (stone)
	for x in range(9):
		for z in range(9):
			bp.add_block(Vector3i(x, 0, z), "stone")

	# Thick walls (double thick stone)
	for y in range(1, 5):
		# Outer walls (front and back)
		for x in range(9):
			# Front walls (z=0 and z=1) with door gap at center (x=4)
			if x != 4:
				bp.add_block(Vector3i(x, y, 0), "stone")
				bp.add_block(Vector3i(x, y, 1), "stone")
			# Back walls (z=8 and z=7)
			bp.add_block(Vector3i(x, y, 8), "stone")
			bp.add_block(Vector3i(x, y, 7), "stone")
		# Side walls (left and right)
		for z in range(2, 7):
			bp.add_block(Vector3i(0, y, z), "stone")
			bp.add_block(Vector3i(1, y, z), "stone")
			bp.add_block(Vector3i(8, y, z), "stone")
			bp.add_block(Vector3i(7, y, z), "stone")

	# Flat roof
	for x in range(9):
		for z in range(9):
			bp.add_block(Vector3i(x, 5, z), "stone")


func _build_wooden_bridge_template(bp: StructureBlueprint) -> void:
	"""Build wooden bridge (3x2x10) - Plank bridge"""
	# Size is 3x2x10, so valid coords are: x=0-2, y=0-1, z=0-9

	# Bridge deck (planks)
	for z in range(10):
		for x in range(3):
			bp.add_block(Vector3i(x, 0, z), "planks")

	# Railings (planks on sides)
	for z in range(10):
		bp.add_block(Vector3i(0, 1, z), "planks")
		bp.add_block(Vector3i(2, 1, z), "planks")


func _build_shrine_template(bp: StructureBlueprint) -> void:
	"""Build shrine (5x6x5) - Ancient ruin stone monument"""
	# Size is 5x6x5, so valid coords are: x=0-4, y=0-5, z=0-4
	# Center at x=2, z=2

	# Base platform (ruin_floor)
	for x in range(5):
		for z in range(5):
			bp.add_block(Vector3i(x, 0, z), "ruin_floor")

	# Steps (front, z=0 side)
	bp.add_block(Vector3i(1, 1, 0), "ruin_stone")
	bp.add_block(Vector3i(2, 1, 0), "ruin_stone")
	bp.add_block(Vector3i(3, 1, 0), "ruin_stone")
	bp.add_block(Vector3i(2, 2, 1), "ruin_stone")

	# Central altar pedestal (ruin_stone)
	for y in range(1, 4):
		bp.add_block(Vector3i(2, y, 2), "ruin_stone")
		bp.add_block(Vector3i(1, y, 2), "ruin_stone")
		bp.add_block(Vector3i(3, y, 2), "ruin_stone")
		bp.add_block(Vector3i(2, y, 3), "ruin_stone")

	# Top piece (ruin_floor)
	for x in range(1, 4):
		for z in range(2, 4):
			bp.add_block(Vector3i(x, 4, z), "ruin_floor")

	# Decorative pillars (corners)
	for y in range(1, 6):
		bp.add_block(Vector3i(0, y, 0), "ruin_stone")
		bp.add_block(Vector3i(4, y, 0), "ruin_stone")
		bp.add_block(Vector3i(0, y, 4), "ruin_stone")
		bp.add_block(Vector3i(4, y, 4), "ruin_stone")


func _build_campfire_circle_template(bp: StructureBlueprint) -> void:
	"""Build campfire circle (7x2x7) - Stone seating around firepit"""
	# Size is 7x2x7, so valid coords are: x=0-6, y=0-1, z=0-6
	# Center at x=3, z=3

	# Base floor (dirt/grass)
	for x in range(7):
		for z in range(7):
			bp.add_block(Vector3i(x, 0, z), "dirt")

	# Stone seating blocks (ring around center)
	# North
	bp.add_block(Vector3i(2, 1, 1), "stone")
	bp.add_block(Vector3i(3, 1, 1), "stone")
	bp.add_block(Vector3i(4, 1, 1), "stone")
	# South
	bp.add_block(Vector3i(2, 1, 5), "stone")
	bp.add_block(Vector3i(3, 1, 5), "stone")
	bp.add_block(Vector3i(4, 1, 5), "stone")
	# East
	bp.add_block(Vector3i(5, 1, 2), "stone")
	bp.add_block(Vector3i(5, 1, 3), "stone")
	bp.add_block(Vector3i(5, 1, 4), "stone")
	# West
	bp.add_block(Vector3i(1, 1, 2), "stone")
	bp.add_block(Vector3i(1, 1, 3), "stone")
	bp.add_block(Vector3i(1, 1, 4), "stone")

	# Central fire pit (stone ring)
	bp.add_block(Vector3i(3, 1, 2), "stone")
	bp.add_block(Vector3i(3, 1, 4), "stone")
	bp.add_block(Vector3i(2, 1, 3), "stone")
	bp.add_block(Vector3i(4, 1, 3), "stone")


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
