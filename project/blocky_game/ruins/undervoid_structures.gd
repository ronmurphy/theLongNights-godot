extends Node

# Undervoid Structure Library
# Dangerous structures that spawn in the deep caves
# Each has a purple beacon light on top to attract players

# Block ID constants (actual block IDs, not voxel IDs)
const AIR = 0
const STONE = 14  # Block ID for stone
const RUIN_STONE = 18  # Block ID for ruin_stone
const RUIN_FLOOR = 19  # Block ID for ruin_floor
const RUST_BLOCK = 29  # Block ID for rust_block
const RUST_PIPE = 30  # Block ID for rust_pipe
const RUST_CUBE = 31  # Block ID for rust_cube
const CHEST = 28  # Block ID for chest

const UndervoidBeacon = preload("res://blocky_game/items/light_orb/undervoid_beacon.gd")

class UndervoidStructure:
	var name: String
	var size: Vector3i  # Bounding box size
	var blocks: Array  # Array of {pos: Vector3i, block_id: int, variant: int}
	var beacon_pos: Vector3  # World position to place purple beacon
	var chest_positions: Array  # Array of Vector3i for loot chests
	var weight: float = 1.0  # For weighted random selection
	var min_depth: int = -150  # Minimum Y level to spawn
	var max_depth: int = -400  # Maximum Y level to spawn

	func _init(p_name: String, p_size: Vector3i, p_blocks: Array, p_beacon_pos: Vector3, p_chest_pos: Array, p_min_depth: int = -150, p_max_depth: int = -400):
		name = p_name
		size = p_size
		blocks = p_blocks
		beacon_pos = p_beacon_pos
		chest_positions = p_chest_pos
		min_depth = p_min_depth
		max_depth = p_max_depth


# All available Undervoid structure templates
var _structures: Array[UndervoidStructure] = []


func _ready():
	print("Initializing UndervoidStructures")
	_create_structures()


func _create_structures():
	# Small structures (Y -150 to -200)
	_structures.append(_create_corrupted_altar())
	_structures.append(_create_rusted_shrine())

	# Medium structures (Y -200 to -300)
	_structures.append(_create_watchtower())
	_structures.append(_create_mechanical_outpost())

	# Large structures (Y -300 to -400)
	_structures.append(_create_mining_camp())
	_structures.append(_create_foundry_complex())

	# Massive fortress (Y -450 to -500, on rust hills)
	_structures.append(_create_void_fortress())

	print("Loaded ", _structures.size(), " Undervoid structure template(s)")


func get_random_structure() -> UndervoidStructure:
	"""Get a random Undervoid structure template"""
	if _structures.is_empty():
		return null
	return _structures[randi() % _structures.size()]


func get_structure_for_depth(depth: int) -> UndervoidStructure:
	"""Get a random structure appropriate for this depth"""
	var valid_structures = []
	for structure in _structures:
		# For Undervoid: depth is negative, more negative = deeper
		# min_depth is deepest (most negative), max_depth is shallowest (least negative)
		# depth should be between them: depth <= max_depth and depth >= min_depth
		if depth <= structure.max_depth and depth >= structure.min_depth:
			valid_structures.append(structure)

	if valid_structures.is_empty():
		return null
	return valid_structures[randi() % valid_structures.size()]


func _create_rusted_shrine() -> UndervoidStructure:
	"""
	A small rusted shrine with purple beacon on top
	Appears at Y -150 to -250 (Undead Crypts → Mechanical Warrens)
	Size: 9x7x9
	"""
	var blocks = []

	# Floor - rusted metal floor
	for x in range(7):
		for z in range(7):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": RUST_CUBE, "variant": 0})

	# Ruin stone base layer
	for x in range(1, 6):
		for z in range(1, 6):
			blocks.append({"pos": Vector3i(x, 1, z), "block_id": RUIN_STONE, "variant": 0})

	# Rust block walls (hollow center)
	for x in range(1, 6):
		for z in range(1, 6):
			if x == 1 or x == 5 or z == 1 or z == 5:  # Outer ring only
				blocks.append({"pos": Vector3i(x, 2, z), "block_id": RUST_BLOCK, "variant": 0})
				blocks.append({"pos": Vector3i(x, 3, z), "block_id": RUST_BLOCK, "variant": 0})

	# Corner pillars (rust pipes going up)
	var corners = [
		Vector3i(1, 4, 1),
		Vector3i(1, 4, 5),
		Vector3i(5, 4, 1),
		Vector3i(5, 4, 5)
	]
	for corner in corners:
		blocks.append({"pos": corner, "block_id": RUST_PIPE, "variant": 0})
		blocks.append({"pos": corner + Vector3i(0, 1, 0), "block_id": RUST_PIPE, "variant": 0})

	# Beacon platform on top (center)
	blocks.append({"pos": Vector3i(3, 6, 3), "block_id": RUST_CUBE, "variant": 0})

	# Chest in the center
	var chest_pos = Vector3i(3, 2, 3)
	blocks.append({"pos": chest_pos, "block_id": CHEST, "variant": 0})

	# Beacon will be placed at this world position (above the platform)
	var beacon_pos = Vector3(3.5, 7, 3.5)  # Center of platform, 1 block above

	return UndervoidStructure.new(
		"Rusted Shrine",
		Vector3i(7, 7, 7),
		blocks,
		beacon_pos,
		[chest_pos],
		-250,  # Min depth (Undead Crypts border)
		-150   # Max depth (higher = closer to surface in this inverted system)
	)


func _create_mechanical_outpost() -> UndervoidStructure:
	"""
	A taller mechanical structure with rust pipes
	Appears at Y -250 to -350 (Mechanical Warrens)
	Size: 11x10x11
	"""
	var blocks = []

	# Large rust floor base
	for x in range(9):
		for z in range(9):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": RUST_BLOCK, "variant": 0})

	# Stone foundation
	for x in range(1, 8):
		for z in range(1, 8):
			blocks.append({"pos": Vector3i(x, 1, z), "block_id": STONE, "variant": 0})

	# Hollow interior with rust pipe walls
	for y in range(2, 7):
		for x in range(2, 7):
			for z in range(2, 7):
				if x == 2 or x == 6 or z == 2 or z == 6:  # Walls only
					blocks.append({"pos": Vector3i(x, y, z), "block_id": RUST_PIPE, "variant": 0})

	# Corner towers (taller)
	var corners = [
		Vector3i(2, 0, 2),
		Vector3i(2, 0, 6),
		Vector3i(6, 0, 2),
		Vector3i(6, 0, 6)
	]
	for corner in corners:
		for y in range(7, 10):  # Taller towers
			blocks.append({"pos": corner + Vector3i(0, y, 0), "block_id": RUST_CUBE, "variant": 0})

	# Central platform for beacon
	blocks.append({"pos": Vector3i(4, 9, 4), "block_id": RUST_BLOCK, "variant": 0})

	# Two chests inside
	var chest_pos_1 = Vector3i(3, 2, 4)
	var chest_pos_2 = Vector3i(5, 2, 4)
	blocks.append({"pos": chest_pos_1, "block_id": CHEST, "variant": 0})
	blocks.append({"pos": chest_pos_2, "block_id": CHEST, "variant": 0})

	var beacon_pos = Vector3(4.5, 10, 4.5)

	return UndervoidStructure.new(
		"Mechanical Outpost",
		Vector3i(9, 10, 9),
		blocks,
		beacon_pos,
		[chest_pos_1, chest_pos_2],
		-350,  # Min depth (Deep Mechanical Warrens)
		-250   # Max depth
	)


func _create_corrupted_altar() -> UndervoidStructure:
	"""
	A small dark altar with ruin stone and rust
	Appears at Y -150 to -200 (Undead Crypts)
	Size: 7x5x7
	"""
	var blocks = []

	# Ruin stone floor (ancient)
	for x in range(7):
		for z in range(7):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": RUIN_FLOOR, "variant": 0})

	# Altar base (cross pattern)
	var altar_blocks = [
		Vector3i(3, 1, 1),
		Vector3i(3, 1, 2),
		Vector3i(3, 1, 3),
		Vector3i(3, 1, 4),
		Vector3i(3, 1, 5),
		Vector3i(1, 1, 3),
		Vector3i(2, 1, 3),
		Vector3i(4, 1, 3),
		Vector3i(5, 1, 3),
	]
	for pos in altar_blocks:
		blocks.append({"pos": pos, "block_id": RUIN_STONE, "variant": 0})

	# Central pillar
	blocks.append({"pos": Vector3i(3, 2, 3), "block_id": RUST_CUBE, "variant": 0})
	blocks.append({"pos": Vector3i(3, 3, 3), "block_id": RUST_CUBE, "variant": 0})
	blocks.append({"pos": Vector3i(3, 4, 3), "block_id": RUST_BLOCK, "variant": 0})

	# Chest at the base
	var chest_pos = Vector3i(3, 1, 3)
	# Don't place chest block - it's inside the altar

	var beacon_pos = Vector3(3.5, 5, 3.5)

	return UndervoidStructure.new(
		"Corrupted Altar",
		Vector3i(7, 5, 7),
		blocks,
		beacon_pos,
		[chest_pos],
		-200,  # Min depth
		-150   # Max depth
	)


func _create_watchtower() -> UndervoidStructure:
	"""
	A tall watchtower with beacon at the top
	Appears at Y -200 to -250 (Undead Crypts → Mechanical Warrens)
	Size: 7x12x7
	"""
	var blocks = []

	# Stone foundation
	for x in range(7):
		for z in range(7):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": STONE, "variant": 0})
			blocks.append({"pos": Vector3i(x, 1, z), "block_id": RUIN_STONE, "variant": 0})

	# Hollow tower walls (rust pipes)
	for y in range(2, 10):
		for x in range(1, 6):
			for z in range(1, 6):
				if x == 1 or x == 5 or z == 1 or z == 5:  # Walls only
					blocks.append({"pos": Vector3i(x, y, z), "block_id": RUST_PIPE, "variant": 0})

	# Corner reinforcements (rust cubes)
	var corners = [Vector3i(1, 0, 1), Vector3i(1, 0, 5), Vector3i(5, 0, 1), Vector3i(5, 0, 5)]
	for corner in corners:
		for y in range(2, 10):
			blocks.append({"pos": corner + Vector3i(0, y, 0), "block_id": RUST_CUBE, "variant": 0})

	# Top platform
	for x in range(2, 5):
		for z in range(2, 5):
			blocks.append({"pos": Vector3i(x, 10, z), "block_id": RUST_BLOCK, "variant": 0})

	# Beacon pedestal
	blocks.append({"pos": Vector3i(3, 11, 3), "block_id": RUST_CUBE, "variant": 0})

	# Chest inside at mid-level
	var chest_pos = Vector3i(3, 5, 3)
	blocks.append({"pos": chest_pos, "block_id": CHEST, "variant": 0})

	var beacon_pos = Vector3(3.5, 12, 3.5)

	return UndervoidStructure.new(
		"Watchtower",
		Vector3i(7, 12, 7),
		blocks,
		beacon_pos,
		[chest_pos],
		-250,  # Min depth
		-200   # Max depth
	)


func _create_mining_camp() -> UndervoidStructure:
	"""
	A spread-out mining camp with multiple buildings
	Appears at Y -250 to -350 (Mechanical Warrens)
	Size: 15x8x15
	"""
	var blocks = []

	# Main platform (rust blocks and stone)
	for x in range(15):
		for z in range(15):
			if randf() < 0.7:  # Not fully filled
				blocks.append({"pos": Vector3i(x, 0, z), "block_id": RUST_BLOCK, "variant": 0})

	# Building 1 (storage shed - left side)
	for x in range(2, 6):
		for z in range(2, 6):
			for y in range(1, 4):
				if x == 2 or x == 5 or z == 2 or z == 5:
					blocks.append({"pos": Vector3i(x, y, z), "block_id": RUST_PIPE, "variant": 0})
	# Roof
	for x in range(2, 6):
		for z in range(2, 6):
			blocks.append({"pos": Vector3i(x, 4, z), "block_id": RUST_BLOCK, "variant": 0})
	# Chest
	blocks.append({"pos": Vector3i(3, 1, 3), "block_id": CHEST, "variant": 0})

	# Building 2 (workshop - right side)
	for x in range(9, 13):
		for z in range(2, 6):
			for y in range(1, 4):
				if x == 9 or x == 12 or z == 2 or z == 5:
					blocks.append({"pos": Vector3i(x, y, z), "block_id": RUST_CUBE, "variant": 0})
	# Roof
	for x in range(9, 13):
		for z in range(2, 6):
			blocks.append({"pos": Vector3i(x, 4, z), "block_id": STONE, "variant": 0})
	# Chest
	blocks.append({"pos": Vector3i(10, 1, 3), "block_id": CHEST, "variant": 0})

	# Central beacon tower
	for y in range(1, 7):
		blocks.append({"pos": Vector3i(7, y, 7), "block_id": RUST_PIPE, "variant": 0})
	blocks.append({"pos": Vector3i(7, 7, 7), "block_id": RUST_CUBE, "variant": 0})

	var chest_pos_1 = Vector3i(3, 1, 3)
	var chest_pos_2 = Vector3i(10, 1, 3)
	var beacon_pos = Vector3(7.5, 8, 7.5)

	return UndervoidStructure.new(
		"Mining Camp",
		Vector3i(15, 8, 15),
		blocks,
		beacon_pos,
		[chest_pos_1, chest_pos_2],
		-350,  # Min depth
		-250   # Max depth
	)


func _create_foundry_complex() -> UndervoidStructure:
	"""
	Large industrial foundry with multiple chambers
	Appears at Y -300 to -400 (Deep Mechanical Warrens)
	Size: 20x10x20
	"""
	var blocks = []

	# Massive rust floor
	for x in range(20):
		for z in range(20):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": RUST_BLOCK, "variant": 0})
			if x > 0 and x < 19 and z > 0 and z < 19:
				blocks.append({"pos": Vector3i(x, 1, z), "block_id": STONE, "variant": 0})

	# Outer walls (hollow)
	for y in range(2, 8):
		for x in range(1, 19):
			for z in range(1, 19):
				if x == 1 or x == 18 or z == 1 or z == 18:
					blocks.append({"pos": Vector3i(x, y, z), "block_id": RUST_PIPE, "variant": 0})

	# Interior support pillars
	var pillars = [
		Vector3i(5, 0, 5), Vector3i(5, 0, 14),
		Vector3i(14, 0, 5), Vector3i(14, 0, 14),
		Vector3i(10, 0, 10)  # Center
	]
	for pillar in pillars:
		for y in range(2, 8):
			blocks.append({"pos": pillar + Vector3i(0, y, 0), "block_id": RUST_CUBE, "variant": 0})

	# Chests in chambers
	var chest_positions = [
		Vector3i(5, 2, 5),
		Vector3i(14, 2, 5),
		Vector3i(5, 2, 14),
		Vector3i(14, 2, 14)
	]
	for chest_pos in chest_positions:
		blocks.append({"pos": chest_pos, "block_id": CHEST, "variant": 0})

	# Central beacon tower (tall)
	for y in range(8, 10):
		blocks.append({"pos": Vector3i(10, y, 10), "block_id": RUST_PIPE, "variant": 0})
	blocks.append({"pos": Vector3i(10, 10, 10), "block_id": RUST_BLOCK, "variant": 0})

	var beacon_pos = Vector3(10.5, 11, 10.5)

	return UndervoidStructure.new(
		"Foundry Complex",
		Vector3i(20, 11, 20),
		blocks,
		beacon_pos,
		chest_positions,
		-400,  # Min depth
		-300   # Max depth
	)


func _create_void_fortress() -> UndervoidStructure:
	"""
	Massive fortress on rust hills above bedrock
	Appears at Y -450 to -500 (On rust hills)
	Size: 30x15x30 - LARGEST structure
	"""
	var blocks = []

	# Massive rust hill foundation
	for x in range(30):
		for z in range(30):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": RUST_BLOCK, "variant": 0})
			blocks.append({"pos": Vector3i(x, 1, z), "block_id": RUST_CUBE, "variant": 0})
			if x > 1 and x < 28 and z > 1 and z < 28:
				blocks.append({"pos": Vector3i(x, 2, z), "block_id": STONE, "variant": 0})

	# Outer fortress walls (thick)
	for y in range(3, 12):
		for x in range(2, 28):
			for z in range(2, 28):
				# Double-thick walls
				if x == 2 or x == 3 or x == 26 or x == 27 or z == 2 or z == 3 or z == 26 or z == 27:
					blocks.append({"pos": Vector3i(x, y, z), "block_id": RUST_CUBE, "variant": 0})

	# Corner towers (tall)
	var corner_towers = [
		Vector3i(2, 0, 2), Vector3i(2, 0, 26),
		Vector3i(26, 0, 2), Vector3i(26, 0, 26)
	]
	for tower in corner_towers:
		for y in range(3, 15):
			blocks.append({"pos": tower + Vector3i(0, y, 0), "block_id": RUST_PIPE, "variant": 0})
			blocks.append({"pos": tower + Vector3i(1, y, 0), "block_id": RUST_PIPE, "variant": 0})
			blocks.append({"pos": tower + Vector3i(0, y, 1), "block_id": RUST_PIPE, "variant": 0})
			blocks.append({"pos": tower + Vector3i(1, y, 1), "block_id": RUST_PIPE, "variant": 0})

	# Inner chambers with loot
	var chest_positions = []
	for i in range(6):
		var cx = 8 + (i % 3) * 7
		var cz = 8 + (i / 3) * 7
		var chest_pos = Vector3i(cx, 3, cz)
		blocks.append({"pos": chest_pos, "block_id": CHEST, "variant": 0})
		chest_positions.append(chest_pos)

	# Central throne room platform
	for x in range(12, 18):
		for z in range(12, 18):
			blocks.append({"pos": Vector3i(x, 3, z), "block_id": RUIN_STONE, "variant": 0})
			blocks.append({"pos": Vector3i(x, 4, z), "block_id": RUIN_FLOOR, "variant": 0})

	# Central beacon spire (very tall)
	for y in range(5, 14):
		blocks.append({"pos": Vector3i(15, y, 15), "block_id": RUST_PIPE, "variant": 0})
	blocks.append({"pos": Vector3i(15, 14, 15), "block_id": RUST_CUBE, "variant": 0})

	var beacon_pos = Vector3(15.5, 15, 15.5)

	return UndervoidStructure.new(
		"Void Fortress",
		Vector3i(30, 15, 30),
		blocks,
		beacon_pos,
		chest_positions,
		-500,  # Min depth (deepest)
		-450   # Max depth
	)


func get_all_structures() -> Array[UndervoidStructure]:
	"""Return all available Undervoid structures (for city building reuse)"""
	return _structures


func get_structure_as_city_building(structure: UndervoidStructure) -> Dictionary:
	"""
	Convert an UndervoidStructure to city building format
	This allows reusing existing structures as landmark buildings in the city
	Ignores the original Y depth settings
	"""
	return {
		"name": structure.name + " (Landmark)",
		"footprint": Vector2i(structure.size.x, structure.size.z),
		"height": structure.size.y,
		"blocks": structure.blocks,
		"doorways": [],  # Existing structures don't have explicit doorways, will be calculated
		"has_roof": true,  # Assume existing structures are sealed
		"chests": structure.chest_positions,
		"weight": 0.5  # Less frequent than custom city buildings
	}
