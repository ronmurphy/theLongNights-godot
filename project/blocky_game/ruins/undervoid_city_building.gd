extends Node

# Undervoid City Building System
# Modular building templates for the bedrock-level sprawling city at Y -510 to -512
# Buildings can be open-air ruins, sealed structures, or partially roofed

# Block ID constants
const AIR = 0
const STONE = 14
const RUIN_STONE = 18
const RUIN_FLOOR = 19
const RUST_BLOCK = 29
const RUST_PIPE = 30
const RUST_CUBE = 31
const CHEST = 28

class CityBuilding:
	var name: String
	var footprint: Vector2i  # XZ dimensions
	var height: int  # Number of blocks tall
	var blocks: Array  # [{"pos": Vector3i, "block_id": int}, ...]
	var doorways: Array[Vector3i]  # Absolute world positions of doorway centers (2x2)
	var has_roof: bool  # If false, open-air; if true, sealed at top
	var interior_chests: Array[Vector3i] = []
	var weight: float = 1.0

	func _init(p_name: String, p_footprint: Vector2i, p_height: int, p_blocks: Array,
			   p_doorways: Array[Vector3i], p_has_roof: bool = false,
			   p_chests: Array[Vector3i] = []):
		name = p_name
		footprint = p_footprint
		height = p_height
		blocks = p_blocks
		doorways = p_doorways
		has_roof = p_has_roof
		interior_chests = p_chests

	# Place this building at a world position
	func place_at(world_pos: Vector3i, voxel_tool) -> void:
		for block_data in blocks:
			var block_pos = world_pos + block_data.pos
			voxel_tool.set_voxel(block_pos, block_data.block_id)

	# Get all doorway positions in world space
	func get_doorways_at(world_pos: Vector3i) -> Array[Vector3i]:
		var world_doorways: Array[Vector3i] = []
		for door in doorways:
			world_doorways.append(world_pos + door)
		return world_doorways


var _city_buildings: Array[CityBuilding] = []


func _ready():
	print("Initializing UndervoidCityBuilding")
	_create_city_buildings()


func _create_city_buildings():
	# Create all city building templates
	_city_buildings.append(_create_small_dwelling())
	_city_buildings.append(_create_warehouse())
	_city_buildings.append(_create_tall_tower())
	_city_buildings.append(_create_cylindrical_building())

	print("Loaded ", _city_buildings.size(), " city building template(s)")


func get_random_city_building() -> CityBuilding:
	"""Get a random city building template"""
	if _city_buildings.is_empty():
		return null
	return _city_buildings[randi() % _city_buildings.size()]


func get_city_buildings() -> Array[CityBuilding]:
	"""Return all city building templates"""
	return _city_buildings


func _create_small_dwelling() -> CityBuilding:
	"""
	A modest dwelling with open floor plan
	Size: 6x6x4
	Walls: Rust pipes (4 blocks high)
	Roof: None (open-air/roofless)
	Doorway: 1x on front wall (2x2 opening)
	"""
	var blocks = []

	# Floor - rust block foundation
	for x in range(6):
		for z in range(6):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": RUST_BLOCK, "variant": 0})

	# Walls - rust pipes (4 blocks high) on perimeter
	for y in range(1, 4):  # Y 1-3 (3 blocks visible above floor)
		# North wall (z=0)
		for x in range(6):
			blocks.append({"pos": Vector3i(x, y, 0), "block_id": RUST_PIPE, "variant": 0})

		# South wall (z=5)
		for x in range(6):
			blocks.append({"pos": Vector3i(x, y, 5), "block_id": RUST_PIPE, "variant": 0})

		# East wall (x=5)
		for z in range(6):
			blocks.append({"pos": Vector3i(5, y, z), "block_id": RUST_PIPE, "variant": 0})

		# West wall (x=0)
		for z in range(6):
			blocks.append({"pos": Vector3i(0, y, z), "block_id": RUST_PIPE, "variant": 0})

	# Remove doorway opening (2x2 on front/north wall at ground level)
	# Doorway center will be at (2, 0, 0) - this creates a 2x2 opening
	# Remove blocks at (1,1,0), (2,1,0), (1,2,0), (2,2,0)
	blocks = _remove_doorway_blocks(blocks, Vector3i(2, 1, 0), Vector3i(0, 0, -1))

	var doorway_centers: Array[Vector3i] = [Vector3i(2, 1, 0)]

	return CityBuilding.new(
		"Small Dwelling",
		Vector2i(6, 6),
		4,
		blocks,
		doorway_centers,
		false  # No roof (open-air/ruins)
	)


func _create_warehouse() -> CityBuilding:
	"""
	A large warehouse with interior pillars
	Size: 10x10x5
	Walls: Rust blocks (5 blocks high)
	Roof: Sealed (flat rust block ceiling)
	Doorways: 2x (front and side, 2x2 openings)
	Interior: 2 support pillars, 1 chest
	"""
	var blocks = []

	# Floor - rust floor foundation
	for x in range(10):
		for z in range(10):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": RUST_BLOCK, "variant": 0})

	# Walls - rust blocks (5 blocks high) on perimeter
	for y in range(1, 5):  # Y 1-4 (4 blocks visible above floor)
		# North wall (z=0)
		for x in range(10):
			blocks.append({"pos": Vector3i(x, y, 0), "block_id": RUST_BLOCK, "variant": 0})

		# South wall (z=9)
		for x in range(10):
			blocks.append({"pos": Vector3i(x, y, 9), "block_id": RUST_BLOCK, "variant": 0})

		# East wall (x=9)
		for z in range(10):
			blocks.append({"pos": Vector3i(9, y, z), "block_id": RUST_BLOCK, "variant": 0})

		# West wall (x=0)
		for z in range(10):
			blocks.append({"pos": Vector3i(0, y, z), "block_id": RUST_BLOCK, "variant": 0})

	# Interior support pillars (rust cubes)
	for y in range(1, 5):
		blocks.append({"pos": Vector3i(3, y, 3), "block_id": RUST_CUBE, "variant": 0})
		blocks.append({"pos": Vector3i(3, y, 6), "block_id": RUST_CUBE, "variant": 0})
		blocks.append({"pos": Vector3i(6, y, 3), "block_id": RUST_CUBE, "variant": 0})
		blocks.append({"pos": Vector3i(6, y, 6), "block_id": RUST_CUBE, "variant": 0})

	# Roof - sealed at Y=5
	for x in range(10):
		for z in range(10):
			blocks.append({"pos": Vector3i(x, 5, z), "block_id": RUST_BLOCK, "variant": 0})

	# Remove doorways: front (north) and side (east)
	blocks = _remove_doorway_blocks(blocks, Vector3i(5, 1, 0), Vector3i(0, 0, -1))  # North door
	blocks = _remove_doorway_blocks(blocks, Vector3i(9, 1, 5), Vector3i(1, 0, 0))   # East door

	# Chest in interior
	var chest_pos = Vector3i(5, 1, 5)
	blocks.append({"pos": chest_pos, "block_id": CHEST, "variant": 0})

	var doorway_centers: Array[Vector3i] = [Vector3i(5, 1, 0), Vector3i(9, 1, 5)]
	var chest_positions: Array[Vector3i] = [chest_pos]

	return CityBuilding.new(
		"Warehouse",
		Vector2i(10, 10),
		5,
		blocks,
		doorway_centers,
		true,  # Has roof (sealed)
		chest_positions
	)


func _create_tall_tower() -> CityBuilding:
	"""
	A tall tower structure
	Size: 6x6x8
	Walls: Rust pipes (8 blocks high)
	Roof: Single block on top
	Doorway: 1x at ground level (2x2 opening)
	Interior: Hollow with center pillar
	"""
	var blocks = []

	# Floor - rust foundation
	for x in range(6):
		for z in range(6):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": RUST_BLOCK, "variant": 0})

	# Walls - rust pipes (8 blocks high) on perimeter
	for y in range(1, 8):  # Y 1-7 (7 blocks visible above floor)
		# Perimeter only
		for x in range(6):
			for z in range(6):
				if x == 0 or x == 5 or z == 0 or z == 5:
					blocks.append({"pos": Vector3i(x, y, z), "block_id": RUST_PIPE, "variant": 0})

	# Center pillar (rust cube)
	for y in range(1, 8):
		blocks.append({"pos": Vector3i(2, y, 2), "block_id": RUST_CUBE, "variant": 0})
		blocks.append({"pos": Vector3i(2, y, 3), "block_id": RUST_CUBE, "variant": 0})
		blocks.append({"pos": Vector3i(3, y, 2), "block_id": RUST_CUBE, "variant": 0})
		blocks.append({"pos": Vector3i(3, y, 3), "block_id": RUST_CUBE, "variant": 0})

	# Roof cap on top
	blocks.append({"pos": Vector3i(2, 8, 2), "block_id": RUST_CUBE, "variant": 0})
	blocks.append({"pos": Vector3i(2, 8, 3), "block_id": RUST_CUBE, "variant": 0})
	blocks.append({"pos": Vector3i(3, 8, 2), "block_id": RUST_CUBE, "variant": 0})
	blocks.append({"pos": Vector3i(3, 8, 3), "block_id": RUST_CUBE, "variant": 0})

	# Remove doorway on front (north wall)
	blocks = _remove_doorway_blocks(blocks, Vector3i(2, 1, 0), Vector3i(0, 0, -1))

	var doorway_centers: Array[Vector3i] = [Vector3i(2, 1, 0)]

	return CityBuilding.new(
		"Tall Tower",
		Vector2i(6, 6),
		8,
		blocks,
		doorway_centers,
		true  # Has roof
	)


func _create_cylindrical_building() -> CityBuilding:
	"""
	A cylindrical/round building for architectural variety
	Size: 8x8x6 (approximated circle in square space)
	Walls: Rust cubes (6 blocks high)
	Roof: Partial/dome-like
	Doorway: 1x (2x2 opening)
	Interior: Open circular space
	"""
	var blocks = []

	# Floor - circular pattern
	var center = Vector2(4, 4)
	var radius = 3.5
	for x in range(8):
		for z in range(8):
			var pos = Vector2(x + 0.5, z + 0.5)
			if center.distance_to(pos) <= radius:
				blocks.append({"pos": Vector3i(x, 0, z), "block_id": RUST_BLOCK, "variant": 0})

	# Walls - rust cubes in circular pattern (6 blocks high)
	for y in range(1, 6):  # Y 1-5
		for x in range(8):
			for z in range(8):
				var pos = Vector2(x + 0.5, z + 0.5)
				var dist = center.distance_to(pos)
				# Wall ring only (at radius)
				if dist > (radius - 0.7) and dist <= radius:
					blocks.append({"pos": Vector3i(x, y, z), "block_id": RUST_CUBE, "variant": 0})

	# Partial roof (dome-like, only covering some sections)
	for x in range(8):
		for z in range(8):
			var pos = Vector2(x + 0.5, z + 0.5)
			if center.distance_to(pos) <= radius * 0.6:  # Inner dome area
				if randf() < 0.6:  # 60% coverage = partial dome
					blocks.append({"pos": Vector3i(x, 6, z), "block_id": RUST_CUBE, "variant": 0})

	# Remove doorway opening (front, 2x2)
	blocks = _remove_doorway_blocks(blocks, Vector3i(4, 1, 0), Vector3i(0, 0, -1))

	var doorway_centers: Array[Vector3i] = [Vector3i(4, 1, 0)]

	return CityBuilding.new(
		"Cylindrical Building",
		Vector2i(8, 8),
		6,
		blocks,
		doorway_centers,
		false  # Open-air (partial roof)
	)


# Helper function to remove doorway blocks (2x2 opening)
# door_center: center position of the 2x2 doorway
# facing: direction the door faces (e.g., Vector3i(0, 0, -1) for north)
func _remove_doorway_blocks(blocks: Array, door_center: Vector3i, facing: Vector3i) -> Array:
	"""Remove blocks to create a 2x2 doorway opening"""
	var doorway_offsets = [
		Vector3i(0, 0, 0),
		Vector3i(1, 0, 0),
		Vector3i(0, 1, 0),
		Vector3i(1, 1, 0)
	]

	var blocks_to_remove = []
	for offset in doorway_offsets:
		var block_pos = door_center + offset
		blocks_to_remove.append(block_pos)

	# Remove blocks that match doorway positions
	blocks = blocks.filter(func(b): return not (b.pos in blocks_to_remove))
	return blocks
