extends Node
## CompanionManager - Singleton that manages companion data and spawning
## Determines companion race/role based on player's quiz choices
## Now supports multiple companions with roster system!

const CharacterQuiz = preload("res://long_nights/CharacterQuiz.gd")
const COMPANION_SAVE = "user://companion.save"

## Companion role mapping (complementary to player)
## Player Tank → Companion Healer
## Player Wizard → Companion Tank
## Player Healer → Companion Rogue
## Player Rogue → Companion Wizard

## Companion race is different from player for diversity

# ============================================================================
# LEGACY SINGLE COMPANION SYSTEM (for backwards compatibility)
# ============================================================================
var companion_race: String = "elf"
var companion_role: String = "healer"
var companion_gender: String = "female"  # All companions are female for now
var companion_name: String = ""  # Companion's personal name
var equipped_weapon_id: int = -1  # -1 means use default weapon

# Saved state for companion persistence
var saved_behavior_mode: String = "normal"
var saved_position: Variant = null  # Array [x,y,z] or null
var saved_guard_position: Variant = null  # Array [x,y,z] or null
var saved_accessory_id: int = -1
var saved_title: String = ""
var saved_title_emoji: String = ""

# ============================================================================
# NEW COMPANION ROSTER SYSTEM
# ============================================================================

## CompanionData - Stores all data for one companion
class CompanionData:
	var companion_name: String = ""
	var race: String = "human"  # human, elf, dwarf, goblin, ghost
	var gender: String = "female"  # male, female (not used for ghost)
	var role: String = "healer"  # healer, tank, rogue, wizard
	var equipped_weapon_id: int = -1
	var equipped_accessory_id: int = -1
	var active_title: String = ""
	var title_emoji: String = ""
	var behavior_mode: String = "normal"
	var is_active: bool = false  # True = adventuring with player, False = at home base
	var level: int = 1
	var xp: int = 0
	
	func to_dict() -> Dictionary:
		return {
			"companion_name": companion_name,
			"race": race,
			"gender": gender,
			"role": role,
			"equipped_weapon_id": equipped_weapon_id,
			"equipped_accessory_id": equipped_accessory_id,
			"active_title": active_title,
			"title_emoji": title_emoji,
			"behavior_mode": behavior_mode,
			"is_active": is_active,
			"level": level,
			"xp": xp
		}
	
	func from_dict(data: Dictionary) -> void:
		if data.has("companion_name"): companion_name = data.companion_name
		if data.has("race"): race = data.race
		if data.has("gender"): gender = data.gender
		if data.has("role"): role = data.role
		if data.has("equipped_weapon_id"): equipped_weapon_id = data.equipped_weapon_id
		if data.has("equipped_accessory_id"): equipped_accessory_id = data.equipped_accessory_id
		if data.has("active_title"): active_title = data.active_title
		if data.has("title_emoji"): title_emoji = data.title_emoji
		if data.has("behavior_mode"): behavior_mode = data.behavior_mode
		if data.has("is_active"): is_active = data.is_active
		if data.has("level"): level = data.level
		if data.has("xp"): xp = data.xp

## Companion roster - holds all recruited companions
var companion_roster: Array[CompanionData] = []
var active_companion_index: int = 0  # Which companion is currently active
var using_roster_system: bool = false  # True when player has multiple companions


## Determine companion based on player choices
func set_companion_from_player() -> void:
	# Companion role is complementary to player
	match PlayerData.role:
		"tank":
			companion_role = "healer"  # Tank needs healing
		"wizard":
			companion_role = "tank"  # Wizard needs protection
		"healer":
			companion_role = "rogue"  # Healer needs DPS
		"rogue":
			companion_role = "wizard"  # Rogue needs ranged support

	# Companion race is different from player (for variety)
	var races = ["human", "elf", "dwarf", "goblin"]
	races.erase(PlayerData.race)  # Remove player's race

	# Pick a race that makes sense with the role
	match companion_role:
		"tank":
			# Prefer dwarf for tank
			companion_race = "dwarf" if "dwarf" in races else races[0]
		"wizard":
			# Prefer elf for wizard
			companion_race = "elf" if "elf" in races else races[0]
		"healer":
			# Prefer elf for healer
			companion_race = "elf" if "elf" in races else races[0]
		"rogue":
			# Prefer goblin for rogue
			companion_race = "goblin" if "goblin" in races else races[0]

	# Set companion name based on race and gender
	companion_name = CharacterQuiz.get_default_name(companion_race, companion_gender, true)

	print("CompanionManager: Companion will be %s - %s %s (to complement %s %s)" % [
		companion_name, companion_race, companion_role, PlayerData.race, PlayerData.role
	])


## Get companion weapon path based on race
func get_companion_weapon() -> String:
	match companion_race:
		"dwarf":
			return "res://assets/art/tools/stone_hammer.png"
		"elf":
			return "res://assets/art/weapons/crossbow.png"  # Or ice_bow
		"goblin":
			# Female goblin uses throwing knives, male uses rocket launcher
			# Since all companions are female for now:
			return "res://assets/art/weapons/throwing_knives.png"
		"human":
			return "res://assets/art/weapons/machete.png"
		_:
			return ""


## Get companion stats based on role (same as PlayerData)
func get_companion_max_hp() -> int:
	match companion_role:
		"tank": return 150
		"wizard": return 80
		"healer": return 100
		"rogue": return 90
		_: return 100


func get_companion_defense() -> int:
	match companion_role:
		"tank": return 20
		"wizard": return 5
		"healer": return 10
		"rogue": return 8
		_: return 10


func get_companion_attack_bonus() -> int:
	match companion_role:
		"tank": return 5
		"wizard": return 15
		"healer": return 0
		"rogue": return 20
		_: return 0


## Get avatar path for companion
func get_avatar_path(state: String = "") -> String:
	return CharacterQuiz.get_avatar_path(companion_race, companion_gender, state)


## Get display name
func get_companion_name() -> String:
	return companion_name if companion_name != "" else CharacterQuiz.get_default_name(companion_race, companion_gender, true)


func get_role_name() -> String:
	return CharacterQuiz.get_role_name(companion_role)


## Save companion data (including equipped weapon)
func save_to_file() -> void:
	# If using roster system, save that instead
	if using_roster_system and not companion_roster.is_empty():
		var roster_data = save_roster_to_dict()
		var json_string = JSON.stringify(roster_data, "\t")
		
		var file = FileAccess.open(COMPANION_SAVE, FileAccess.WRITE)
		if file == null:
			push_error("CompanionManager: Failed to save roster")
			return
		
		file.store_string(json_string)
		file.close()
		print("CompanionManager: Saved %d companions to roster" % companion_roster.size())
		return
	
	# Legacy single companion save
	var save_data = {
		"race": companion_race,
		"role": companion_role,
		"gender": companion_gender,
		"companion_name": companion_name,
		"equipped_weapon_id": equipped_weapon_id,
		"behavior_mode": "normal",
		"position": null,
		"guard_position": null,
		"equipped_accessory_id": -1,
		"active_title": "",
		"title_emoji": ""
	}
	
	# Get live companion data if it exists
	var companions = Engine.get_main_loop().get_root().get_tree().get_nodes_in_group("companions")
	if companions.size() > 0:
		var companion = companions[0]
		save_data["behavior_mode"] = companion.support_mode
		save_data["position"] = [
			companion.global_position.x,
			companion.global_position.y,
			companion.global_position.z
		]
		if companion._is_guarding:
			save_data["guard_position"] = [
				companion._guard_position.x,
				companion._guard_position.y,
				companion._guard_position.z
			]
		
		# Get equipped accessory from companion if available
		if companion._equipped_accessory_item != null:
			save_data["equipped_accessory_id"] = companion._equipped_accessory_item.id
		
		# Save companion title
		save_data["active_title"] = companion.active_title
		save_data["title_emoji"] = companion.title_emoji

	var file = FileAccess.open("user://companion.save", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()


## Load companion data (including equipped weapon)
func load_from_file() -> bool:
	if not FileAccess.file_exists("user://companion.save"):
		return false
	
	var file = FileAccess.open("user://companion.save", FileAccess.READ)
	if not file:
		return false
	
	var file_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(file_text)
	if error != OK:
		push_warning("CompanionManager: Failed to parse save file")
		return false
	
	var save_data = json.data
	if typeof(save_data) != TYPE_DICTIONARY:
		return false
	
	# Check if this is a roster save
	if save_data.has("roster") and save_data.has("using_roster_system"):
		load_roster_from_dict(save_data)
		return true
	
	# Legacy single companion load
	companion_race = save_data.get("race", "elf")
	companion_role = save_data.get("role", "healer")
	companion_gender = save_data.get("gender", "female")
	companion_name = save_data.get("companion_name", "")
	equipped_weapon_id = save_data.get("equipped_weapon_id", -1)
	
	# Load behavior mode, position, and accessory
	saved_behavior_mode = save_data.get("behavior_mode", "normal")
	saved_position = save_data.get("position", null)
	saved_guard_position = save_data.get("guard_position", null)
	saved_accessory_id = save_data.get("equipped_accessory_id", -1)
	
	# Load companion title
	saved_title = save_data.get("active_title", "")
	saved_title_emoji = save_data.get("title_emoji", "")

	# If no name was saved, generate one
	if companion_name == "":
		companion_name = CharacterQuiz.get_default_name(companion_race, companion_gender, true)

	return true


# ============================================================================
# COMPANION ROSTER FUNCTIONS
# ============================================================================

func initialize_roster_from_legacy() -> void:
	"""Convert legacy single companion to roster system (for backwards compatibility)"""
	if companion_roster.is_empty() and companion_name != "":
		print("CompanionManager: Converting legacy companion to roster system")
		var companion_data = CompanionData.new()
		companion_data.companion_name = companion_name
		companion_data.race = companion_race
		companion_data.gender = companion_gender
		companion_data.role = companion_role
		companion_data.equipped_weapon_id = equipped_weapon_id
		companion_data.equipped_accessory_id = saved_accessory_id
		companion_data.active_title = saved_title
		companion_data.title_emoji = saved_title_emoji
		companion_data.behavior_mode = saved_behavior_mode
		companion_data.is_active = true
		
		companion_roster.append(companion_data)
		active_companion_index = 0
		using_roster_system = true
		print("  ✓ Converted: %s (%s %s)" % [companion_name, companion_race, companion_role])


func add_companion_to_roster(comp_data: CompanionData) -> void:
	"""Add a new companion to the roster"""
	companion_roster.append(comp_data)
	using_roster_system = true
	print("🎉 %s joined the roster! (%s %s)" % [comp_data.companion_name, comp_data.race, comp_data.role])


func get_active_companion() -> CompanionData:
	"""Get the currently active companion"""
	if companion_roster.is_empty():
		return null
	if active_companion_index >= companion_roster.size():
		active_companion_index = 0
	return companion_roster[active_companion_index]


func get_benched_companions() -> Array[CompanionData]:
	"""Get all companions that are NOT currently active"""
	var benched: Array[CompanionData] = []
	for i in range(companion_roster.size()):
		if i != active_companion_index:
			benched.append(companion_roster[i])
	return benched


func get_companion_count() -> int:
	"""Get total number of companions in roster"""
	return companion_roster.size()


func swap_to_companion(index: int) -> bool:
	"""Swap to a different companion by roster index"""
	if index < 0 or index >= companion_roster.size():
		push_error("CompanionManager: Invalid companion index %d" % index)
		return false
	
	if index == active_companion_index:
		print("CompanionManager: Companion already active")
		return false
	
	# Mark old as inactive
	if active_companion_index < companion_roster.size():
		companion_roster[active_companion_index].is_active = false
	
	# Mark new as active
	active_companion_index = index
	companion_roster[index].is_active = true
	
	print("🔄 Swapped to: %s" % companion_roster[index].companion_name)
	return true


func update_active_companion_from_scene(companion_node) -> void:
	"""Update active companion data from the live companion node"""
	var active = get_active_companion()
	if active and companion_node:
		active.equipped_weapon_id = companion_node._equipped_inv_item.id if companion_node._equipped_inv_item else -1
		active.equipped_accessory_id = companion_node._equipped_accessory_item.id if companion_node._equipped_accessory_item else -1
		active.active_title = companion_node.active_title
		active.title_emoji = companion_node.title_emoji
		active.behavior_mode = companion_node.support_mode


func save_roster_to_dict() -> Dictionary:
	"""Save entire roster to dictionary for world save"""
	var roster_data = []
	for comp in companion_roster:
		roster_data.append(comp.to_dict())
	
	return {
		"using_roster_system": using_roster_system,
		"active_companion_index": active_companion_index,
		"roster": roster_data
	}


func load_roster_from_dict(data: Dictionary) -> void:
	"""Load entire roster from dictionary"""
	companion_roster.clear()
	
	if data.has("using_roster_system"):
		using_roster_system = data.using_roster_system
	
	if data.has("active_companion_index"):
		active_companion_index = data.active_companion_index
	
	if data.has("roster"):
		for comp_dict in data.roster:
			var comp = CompanionData.new()
			comp.from_dict(comp_dict)
			companion_roster.append(comp)
		
		print("CompanionManager: Loaded %d companions from roster" % companion_roster.size())
