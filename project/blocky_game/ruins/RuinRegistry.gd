extends Node

# RuinRegistry - Global singleton for tracking all spawned ruins
# Stores persistent data about visited ruins, teleport stones, and portal network

# Portal/Stone Types
enum StoneType {
	NORMAL,    # Default portal - leads to new random ruin
	RETURN,    # Can be revisited from anywhere using Portal Compass
	HOME,      # Always returns to crashed tower (spawn point)
	COMBAT     # Leads to ruin with enemies and better loot
}

# Data structure for a single teleport stone
class TeleportStone:
	var local_pos: Vector3i          # Position relative to ruin base
	var stone_type: StoneType        # Type of portal
	var glow_color: Color            # Visual color for the light
	var has_been_used: bool = false  # Track if player used this specific stone
	var island_center: Vector3 = Vector3.ZERO  # For sky islands: center position to orient player toward

	func _init(pos: Vector3i, type: StoneType, color: Color):
		local_pos = pos
		stone_type = type
		glow_color = color

# Data structure for a tracked ruin
class RuinData:
	var position: Vector3                      # World position where ruin spawned
	var ruin_type: String                      # Template name (e.g., "coliseum")
	var ruin_name: String                      # Generated unique name (e.g., "The Grand Coliseum")
	var ruin_size: Vector3i                    # Bounding box dimensions (x, y, z)
	var teleport_stones: Array[TeleportStone]  # Array of teleport stones in this ruin
	var has_enemies: bool = false              # True for combat ruins
	var enemies_defeated: bool = false         # Track if combat cleared
	var chests_looted: Array[Vector3i] = []    # Track which chests opened
	var visit_count: int = 0                   # How many times visited
	var last_visited: int = 0                  # Game time timestamp (hours since start)

	func _init(pos: Vector3, type: String, name: String, size: Vector3i = Vector3i(10, 10, 10)):
		position = pos
		ruin_type = type
		ruin_name = name
		ruin_size = size

# Registry storage
var _ruins: Array[RuinData] = []
var _used_names: Dictionary = {}  # Track used names per ruin type to ensure uniqueness
var _island_puzzles: Dictionary = {}  # Track island puzzle data {push_block_pos: puzzle_data}

# Name generation data
var _name_prefixes = {
	"crashed_tower_small": {
		"prefixes": ["Fallen", "Broken", "Shattered", "Ruined"],
		"suffixes": ["Spire", "Tower", "Beacon", "Observatory"]
	},
	"coliseum": {
		"prefixes": ["The Grand", "Ancient", "Ruined", "Storm"],
		"suffixes": ["Coliseum", "Arena", "Battle Grounds", "Pit"]
	},
	"sky_garden": {
		"prefixes": ["Hanging", "Sky", "Celestial", "Floating"],
		"suffixes": ["Gardens", "Oasis", "Grove", "Sanctuary"]
	},
	"ancient_temple": {
		"prefixes": ["Temple of", "Sacred", "Ancient", "Holy"],
		"suffixes": ["Winds", "Sanctuary", "Shrine", "Sanctuary"]
	},
	"wizard_tower": {
		"prefixes": ["Wizard's", "Arcane", "Mage", "Sorcerer's"],
		"suffixes": ["Spire", "Tower", "Observatory", "Sanctum"]
	},
	"ruined_plaza": {
		"prefixes": ["Merchant", "Trade", "Central", "Ancient"],
		"suffixes": ["Square", "Plaza", "Court", "Forum"]
	},
	"desert_shrine": {
		"prefixes": ["Sand", "Desert", "Pyramid", "Dune"],
		"suffixes": ["Temple", "Sanctum", "Shrine", "Tomb"]
	},
	"floating_forest": {
		"prefixes": ["Floating", "Treetop", "Aerial", "Sky"],
		"suffixes": ["Grove", "Haven", "Woodland", "Canopy"]
	},
	"grand_castle": {
		"prefixes": ["Storm", "Cloud", "Sky", "Wind"],
		"suffixes": ["Keep", "Fortress", "Citadel", "Bastion"]
	},
	"sky_city_district": {
		"prefixes": ["Cloudtop", "Skyport", "Aerial", "High"],
		"suffixes": ["District", "Quarter", "Plaza", "Ward"]
	}
}


func _ready():
	print("RuinRegistry initialized")


func register_ruin(world_position: Vector3, ruin_type: String, teleport_positions: Array, ruin_size: Vector3i = Vector3i(10, 10, 10)) -> RuinData:
	"""
	Register a newly spawned ruin with the registry
	Returns the RuinData object for the registered ruin
	"""
	# Generate unique name
	var ruin_name = _generate_unique_name(ruin_type)

	# Create ruin data with size
	var ruin_data = RuinData.new(world_position, ruin_type, ruin_name, ruin_size)

	# Assign portal types and create teleport stones
	for teleport_pos in teleport_positions:
		var stone_type = _assign_portal_type(ruin_type, teleport_positions.size())
		var glow_color = _get_glow_color_for_type(stone_type, false)  # Not visited yet
		var stone = TeleportStone.new(Vector3i(teleport_pos), stone_type, glow_color)
		ruin_data.teleport_stones.append(stone)

	# Check if this is a combat ruin (20% chance)
	if randf() < 0.20:
		ruin_data.has_enemies = true
		# Update all stones to combat type for combat ruins
		for stone in ruin_data.teleport_stones:
			stone.stone_type = StoneType.COMBAT
			stone.glow_color = _get_glow_color_for_type(StoneType.COMBAT, false)

	# Add to registry
	_ruins.append(ruin_data)

	print("Registered ruin: ", ruin_name, " (", ruin_type, ") at ", world_position, " with ", ruin_data.teleport_stones.size(), " portal(s), size: ", ruin_size)

	return ruin_data


func get_ruin_at_position(world_position: Vector3, tolerance: float = 5.0) -> RuinData:
	"""
	Find a ruin at or near the given world position
	Returns null if no ruin found
	"""
	for ruin in _ruins:
		if ruin.position.distance_to(world_position) <= tolerance:
			return ruin
	return null


func get_all_ruins() -> Array[RuinData]:
	"""Return all registered ruins"""
	return _ruins


func get_visited_ruins() -> Array[RuinData]:
	"""Return only ruins that have been visited at least once"""
	var visited: Array[RuinData] = []
	for ruin in _ruins:
		if ruin.visit_count > 0:
			visited.append(ruin)
	return visited


func mark_ruin_visited(ruin_data: RuinData, current_game_time: int = 0):
	"""Mark a ruin as visited, increment visit count, update timestamp"""
	ruin_data.visit_count += 1
	ruin_data.last_visited = current_game_time
	print("Ruin '", ruin_data.ruin_name, "' visited (count: ", ruin_data.visit_count, ")")


func mark_stone_used(ruin_data: RuinData, stone_index: int):
	"""Mark a specific teleport stone as having been used"""
	if stone_index >= 0 and stone_index < ruin_data.teleport_stones.size():
		ruin_data.teleport_stones[stone_index].has_been_used = true
		# Update glow color to white (visited)
		if ruin_data.teleport_stones[stone_index].stone_type == StoneType.NORMAL:
			ruin_data.teleport_stones[stone_index].glow_color = _get_glow_color_for_type(StoneType.NORMAL, true)


func _generate_unique_name(ruin_type: String) -> String:
	"""Generate a unique name for the ruin type"""
	if not _name_prefixes.has(ruin_type):
		return "Unknown Ruin"

	var names_data = _name_prefixes[ruin_type]
	var prefixes = names_data["prefixes"]
	var suffixes = names_data["suffixes"]

	# Initialize used names tracking for this type
	if not _used_names.has(ruin_type):
		_used_names[ruin_type] = []

	# Try to generate a unique name (max 100 attempts to avoid infinite loop)
	for attempt in range(100):
		var prefix = prefixes[randi() % prefixes.size()]
		var suffix = suffixes[randi() % suffixes.size()]
		var name = prefix + " " + suffix

		if name not in _used_names[ruin_type]:
			_used_names[ruin_type].append(name)
			return name

	# Fallback: append number if we couldn't find unique name
	var base_name = prefixes[0] + " " + suffixes[0]
	var counter = _used_names[ruin_type].size()
	return base_name + " " + str(counter)


func _assign_portal_type(ruin_type: String, total_stones: int) -> StoneType:
	"""
	Assign a random portal type based on spawn chances
	- Return stones: 30% chance
	- Home stones: 10% chance per ruin (only one per ruin)
	- Normal: remaining
	"""
	# Home stones are rare and only one per ruin
	# We'll handle this specially - only first stone can be home, with 10% chance
	var rand = randf()

	if rand < 0.10:
		return StoneType.HOME
	elif rand < 0.40:  # 30% for return (0.10 to 0.40)
		return StoneType.RETURN
	else:
		return StoneType.NORMAL


func _get_glow_color_for_type(stone_type: StoneType, has_been_used: bool) -> Color:
	"""
	Get the appropriate glow color for a portal type
	- Blue/Cyan: Unvisited normal portal
	- White/Silver: Visited normal portal
	- Red: Combat portal
	- Green: Return stone
	- Purple: Home stone
	"""
	match stone_type:
		StoneType.NORMAL:
			if has_been_used:
				return Color(0.9, 0.9, 1.0)  # White - visited
			else:
				return Color(0.4, 0.7, 1.0)  # Blue - unvisited
		StoneType.RETURN:
			return Color(0.2, 1.0, 0.4)  # Green
		StoneType.HOME:
			return Color(0.8, 0.3, 1.0)  # Purple
		StoneType.COMBAT:
			return Color(1.0, 0.2, 0.2)  # Red
		_:
			return Color(0.4, 0.7, 1.0)  # Default blue


## ============================================================================
## ISLAND PUZZLE SYSTEM
## ============================================================================

func register_island_puzzle(puzzle_data: Dictionary):
	"""Register a sky island puzzle for tracking and completion detection"""
	var push_block_pos = puzzle_data.get("push_block_spawn")
	if push_block_pos:
		_island_puzzles[push_block_pos] = puzzle_data
		print("🧩 Registered island puzzle at push_block pos: ", push_block_pos)


func get_island_puzzle_at(push_block_pos: Vector3i) -> Dictionary:
	"""Get island puzzle data for a push_block at the given position
	Searches in a radius since the block may have moved from its spawn position"""
	# First try exact match
	if _island_puzzles.has(push_block_pos):
		print("[DEBUG] RuinRegistry: Found exact match for puzzle at: ", push_block_pos)
		return _island_puzzles[push_block_pos]
	
	# If no exact match, search nearby (the block may have been pushed)
	const SEARCH_RADIUS = 20  # Search within 20 blocks
	for puzzle_spawn_pos in _island_puzzles.keys():
		var distance = push_block_pos.distance_to(puzzle_spawn_pos)
		if distance <= SEARCH_RADIUS:
			print("[DEBUG] RuinRegistry: Found nearby puzzle at ", puzzle_spawn_pos, " (distance: ", distance, ")")
			return _island_puzzles[puzzle_spawn_pos]
	
	print("[DEBUG] RuinRegistry: No puzzle found near: ", push_block_pos)
	return {}


func mark_island_puzzle_solved(push_block_pos: Vector3i):
	"""Mark an island puzzle as solved"""
	if _island_puzzles.has(push_block_pos):
		_island_puzzles[push_block_pos]["solved"] = true
		print("✅ Island puzzle at ", push_block_pos, " marked as solved")


## ============================================================================
## SAVE/LOAD SYSTEM
## ============================================================================

func serialize_registry() -> Dictionary:
	"""Serialize all ruin data for saving to world.config"""
	var data = {
		"ruins": [],
		"used_names": _used_names
	}

	# Serialize each ruin
	for ruin in _ruins:
		var ruin_dict = {
			"position": [ruin.position.x, ruin.position.y, ruin.position.z],
			"ruin_type": ruin.ruin_type,
			"ruin_name": ruin.ruin_name,
			"has_enemies": ruin.has_enemies,
			"enemies_defeated": ruin.enemies_defeated,
			"chests_looted": [],
			"visit_count": ruin.visit_count,
			"last_visited": ruin.last_visited,
			"teleport_stones": []
		}

		# Serialize chests looted
		for chest_pos in ruin.chests_looted:
			ruin_dict["chests_looted"].append([chest_pos.x, chest_pos.y, chest_pos.z])

		# Serialize teleport stones
		for stone in ruin.teleport_stones:
			ruin_dict["teleport_stones"].append({
				"local_pos": [stone.local_pos.x, stone.local_pos.y, stone.local_pos.z],
				"stone_type": stone.stone_type,
				"glow_color": [stone.glow_color.r, stone.glow_color.g, stone.glow_color.b, stone.glow_color.a],
				"has_been_used": stone.has_been_used,
				"island_center": [stone.island_center.x, stone.island_center.y, stone.island_center.z]
			})

		data["ruins"].append(ruin_dict)

	print("RuinRegistry: Serialized ", _ruins.size(), " ruins")
	return data


func deserialize_registry(data: Dictionary) -> void:
	"""Load ruin data from save file"""
	if not data.has("ruins"):
		print("RuinRegistry: No ruins data to load")
		return

	# Clear existing data
	_ruins.clear()
	_used_names.clear()

	# Restore used names
	if data.has("used_names"):
		_used_names = data["used_names"]

	# Deserialize each ruin
	for ruin_dict in data["ruins"]:
		# Create ruin data
		var pos_array = ruin_dict["position"]
		var position = Vector3(pos_array[0], pos_array[1], pos_array[2])
		var ruin_data = RuinData.new(position, ruin_dict["ruin_type"], ruin_dict["ruin_name"])

		# Restore properties
		ruin_data.has_enemies = ruin_dict.get("has_enemies", false)
		ruin_data.enemies_defeated = ruin_dict.get("enemies_defeated", false)
		ruin_data.visit_count = ruin_dict.get("visit_count", 0)
		ruin_data.last_visited = ruin_dict.get("last_visited", 0)

		# Restore chests looted
		if ruin_dict.has("chests_looted"):
			for chest_array in ruin_dict["chests_looted"]:
				ruin_data.chests_looted.append(Vector3i(chest_array[0], chest_array[1], chest_array[2]))

		# Restore teleport stones
		if ruin_dict.has("teleport_stones"):
			for stone_dict in ruin_dict["teleport_stones"]:
				var local_pos_array = stone_dict["local_pos"]
				var local_pos = Vector3i(local_pos_array[0], local_pos_array[1], local_pos_array[2])

				var color_array = stone_dict["glow_color"]
				var glow_color = Color(color_array[0], color_array[1], color_array[2], color_array[3])

				var stone = TeleportStone.new(local_pos, stone_dict["stone_type"], glow_color)
				stone.has_been_used = stone_dict.get("has_been_used", false)

				# Restore island_center if present (for sky islands)
				if stone_dict.has("island_center"):
					var center_array = stone_dict["island_center"]
					stone.island_center = Vector3(center_array[0], center_array[1], center_array[2])

				ruin_data.teleport_stones.append(stone)

		_ruins.append(ruin_data)

	print("RuinRegistry: Loaded ", _ruins.size(), " ruins from save data")
