extends Node

## VoidRuinLibrary - Library of void challenge templates
## Each challenge spawns at Y -612 in the void
## Completing challenges rewards stat potions

class VoidChallengeTemplate:
	var name: String
	var challenge_type: String  # "combat", "parkour", "puzzle", "gauntlet"
	var reward_potion: String  # "hppotion", "luckpotion", "defpotion", "atkpotion"
	var size: Vector3i  # Bounding box size
	var blocks: Array  # Array of {pos: Vector3i, block_id: int, variant: int}
	var beacon_positions: Array  # Array of Vector3i - VoidBeacon light positions
	var weight: float = 1.0  # For weighted random selection

	func _init(p_name: String, p_type: String, p_reward: String, p_size: Vector3i, p_blocks: Array, p_beacons: Array, p_weight: float = 1.0):
		name = p_name
		challenge_type = p_type
		reward_potion = p_reward
		size = p_size
		blocks = p_blocks
		beacon_positions = p_beacons
		weight = p_weight


# All available void challenge templates
var _challenge_templates: Array[VoidChallengeTemplate] = []


func _ready():
	print("Initializing VoidRuinLibrary")
	_create_challenge_templates()


func _create_challenge_templates():
	"""Create all void challenge templates"""
	# Combat challenges → HP Potion
	_challenge_templates.append(_create_combat_arena_simple())

	# Parkour challenges → Luck Potion
	_challenge_templates.append(_create_parkour_platforms_simple())

	# Puzzle challenges → Defense Potion
	_challenge_templates.append(_create_puzzle_void_simple())

	# Gauntlet challenges → Attack Potion
	_challenge_templates.append(_create_gauntlet_mixed())

	print("Loaded ", _challenge_templates.size(), " void challenge template(s)")


func _create_combat_arena_simple() -> VoidChallengeTemplate:
	"""
	Combat Arena - Simple 10x10 platform with push_block/test_block
	Player must either kill all enemies OR reach the push_block and complete puzzle
	Reward: HP Potion
	"""
	var blocks = []

	# Main platform (10x10 obsidian platform)
	for x in range(10):
		for z in range(10):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": 21, "variant": 0})  # obsidian

	# Small side platform (5x5) with push_block
	for x in range(12, 17):
		for z in range(2, 7):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": 21, "variant": 0})  # obsidian

	# Push block on side platform (entity will be spawned)
	blocks.append({"pos": Vector3i(14, 1, 4), "block_id": 26, "variant": 0})  # push_block

	# Test block target on side platform
	blocks.append({"pos": Vector3i(15, 1, 4), "block_id": 27, "variant": 0})  # test_block

	# VoidBeacons at corners of main platform
	var beacons = [
		Vector3i(0, 1, 0),
		Vector3i(9, 1, 9)
	]

	return VoidChallengeTemplate.new(
		"void_combat_arena_simple",
		"combat",
		"hppotion",
		Vector3i(17, 3, 10),
		blocks,
		beacons,
		1.0
	)


func _create_parkour_platforms_simple() -> VoidChallengeTemplate:
	"""
	Parkour Challenge - Jump across floating platforms to reach push_block
	Reward: Luck Potion
	"""
	var blocks = []

	# Start platform (5x5)
	for x in range(5):
		for z in range(5):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": 33, "variant": 0})  # ruin_stone

	# Parkour platforms (3x3 each, staggered heights)
	var platform_positions = [
		{"offset": Vector3i(7, 0, 2), "size": 3},
		{"offset": Vector3i(11, 1, 4), "size": 3},
		{"offset": Vector3i(15, 0, 2), "size": 3},
		{"offset": Vector3i(19, -1, 4), "size": 3},
	]

	for platform in platform_positions:
		for x in range(platform.size):
			for z in range(platform.size):
				var pos = platform.offset + Vector3i(x, 0, z)
				blocks.append({"pos": pos, "block_id": 33, "variant": 0})  # ruin_stone

	# Goal platform (4x4) with push_block and test_block
	for x in range(23, 27):
		for z in range(2, 6):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": 33, "variant": 0})  # ruin_stone

	# Push block and test block on goal platform
	blocks.append({"pos": Vector3i(24, 1, 3), "block_id": 26, "variant": 0})  # push_block
	blocks.append({"pos": Vector3i(25, 1, 3), "block_id": 27, "variant": 0})  # test_block

	# Beacons at start and goal
	var beacons = [
		Vector3i(2, 1, 2),  # Start platform
		Vector3i(24, 1, 3)  # Goal platform
	]

	return VoidChallengeTemplate.new(
		"void_parkour_simple",
		"parkour",
		"luckpotion",
		Vector3i(27, 3, 8),
		blocks,
		beacons,
		1.0
	)


func _create_puzzle_void_simple() -> VoidChallengeTemplate:
	"""
	Puzzle Challenge - Navigate push_blocks to test_block target
	Reward: Defense Potion
	"""
	var blocks = []

	# Puzzle platform (12x12)
	for x in range(12):
		for z in range(12):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": 19, "variant": 0})  # ruin_floor

	# Walls around the edges (simple border)
	for x in range(12):
		blocks.append({"pos": Vector3i(x, 1, 0), "block_id": 18, "variant": 0})  # ruin_stone wall
		blocks.append({"pos": Vector3i(x, 1, 11), "block_id": 18, "variant": 0})
	for z in range(1, 11):
		blocks.append({"pos": Vector3i(0, 1, z), "block_id": 18, "variant": 0})
		blocks.append({"pos": Vector3i(11, 1, z), "block_id": 18, "variant": 0})

	# Push block (start position)
	blocks.append({"pos": Vector3i(2, 1, 2), "block_id": 26, "variant": 0})  # push_block

	# Test block target (goal position)
	blocks.append({"pos": Vector3i(9, 1, 9), "block_id": 27, "variant": 0})  # test_block

	# A few obstacle blocks to make it more puzzle-like
	blocks.append({"pos": Vector3i(6, 1, 5), "block_id": 18, "variant": 0})  # obstacle
	blocks.append({"pos": Vector3i(5, 1, 7), "block_id": 18, "variant": 0})  # obstacle

	# Beacons in corners
	var beacons = [
		Vector3i(1, 2, 1),
		Vector3i(10, 2, 10)
	]

	return VoidChallengeTemplate.new(
		"void_puzzle_simple",
		"puzzle",
		"defpotion",
		Vector3i(12, 3, 12),
		blocks,
		beacons,
		1.0
	)


func _create_gauntlet_mixed() -> VoidChallengeTemplate:
	"""
	Gauntlet Challenge - Parkour + Combat mixed
	Navigate platforms while enemies spawn, reach push_block
	Reward: Attack Potion
	"""
	var blocks = []

	# Start platform (6x6)
	for x in range(6):
		for z in range(6):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": 21, "variant": 0})  # obsidian

	# Combat area platform (8x8, elevated)
	for x in range(8, 16):
		for z in range(1, 9):
			blocks.append({"pos": Vector3i(x, 2, z), "block_id": 21, "variant": 0})  # obsidian

	# Final goal platform (5x5)
	for x in range(18, 23):
		for z in range(2, 7):
			blocks.append({"pos": Vector3i(x, 0, z), "block_id": 21, "variant": 0})  # obsidian

	# Push block and test block on goal platform
	blocks.append({"pos": Vector3i(20, 1, 4), "block_id": 26, "variant": 0})  # push_block
	blocks.append({"pos": Vector3i(21, 1, 4), "block_id": 27, "variant": 0})  # test_block

	# Beacons
	var beacons = [
		Vector3i(3, 1, 3),   # Start
		Vector3i(12, 3, 5),  # Combat area
		Vector3i(20, 1, 4)   # Goal
	]

	return VoidChallengeTemplate.new(
		"void_gauntlet_mixed",
		"gauntlet",
		"atkpotion",
		Vector3i(23, 4, 9),
		blocks,
		beacons,
		1.0
	)


## Public API Functions

func get_random_challenge() -> VoidChallengeTemplate:
	"""Get a random void challenge template (weighted)"""
	if _challenge_templates.is_empty():
		push_error("No void challenge templates available!")
		return null

	# Calculate total weight
	var total_weight = 0.0
	for template in _challenge_templates:
		total_weight += template.weight

	# Roll random number
	var roll = randf() * total_weight

	# Find which template was selected
	var current_weight = 0.0
	for template in _challenge_templates:
		current_weight += template.weight
		if roll <= current_weight:
			return template

	# Fallback to first template
	return _challenge_templates[0]


func get_challenge_by_type(challenge_type: String) -> VoidChallengeTemplate:
	"""Get a random challenge of a specific type"""
	var matching_templates = []

	for template in _challenge_templates:
		if template.challenge_type == challenge_type:
			matching_templates.append(template)

	if matching_templates.is_empty():
		push_warning("No void challenges found for type: ", challenge_type)
		return null

	# Return random from matching templates
	return matching_templates[randi() % matching_templates.size()]


func get_challenge_by_name(challenge_name: String) -> VoidChallengeTemplate:
	"""Get a specific challenge by name"""
	for template in _challenge_templates:
		if template.name == challenge_name:
			return template

	push_warning("Void challenge not found: ", challenge_name)
	return null
