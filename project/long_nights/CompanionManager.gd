extends Node
## CompanionManager - Singleton that manages companion data and spawning
## Determines companion race/role based on player's quiz choices

const CharacterQuiz = preload("res://long_nights/CharacterQuiz.gd")

## Companion role mapping (complementary to player)
## Player Tank → Companion Healer
## Player Wizard → Companion Tank
## Player Healer → Companion Rogue
## Player Rogue → Companion Wizard

## Companion race is different from player for diversity

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
	var save_data = {
		"race": companion_race,
		"role": companion_role,
		"gender": companion_gender,
		"companion_name": companion_name,
		"equipped_weapon_id": equipped_weapon_id,
		"behavior_mode": "normal",
		"position": null,
		"guard_position": null,
		"equipped_accessory_id": -1
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

	# If no name was saved, generate one
	if companion_name == "":
		companion_name = CharacterQuiz.get_default_name(companion_race, companion_gender, true)

	return true
