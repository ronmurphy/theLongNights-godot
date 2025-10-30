extends Node
## PlayerData - Singleton that stores player character data
## Set by the quiz, used throughout the game

const CharacterQuiz = preload("res://long_nights/CharacterQuiz.gd")

## Character attributes from quiz
var role: String = "tank"  # tank, wizard, healer, rogue
var race: String = "human"  # human, elf, dwarf, goblin
var gender: String = "male"  # male, female
var player_name: String = ""  # Player's chosen or default name

## Character stats (modified by role)
var max_hp: int = 100
var defense: int = 10
var attack_bonus: int = 0
var max_mana: int = 0
var current_mana: int = 0


## Apply quiz results and calculate stats
func set_character(p_role: String, p_race: String, p_gender: String, p_name: String = "") -> void:
	role = p_role
	race = p_race
	gender = p_gender

	# Set name (use provided or get default)
	if p_name != "":
		player_name = p_name
	else:
		player_name = CharacterQuiz.get_default_name(p_race, p_gender, false)

	# Apply role bonuses
	_apply_role_stats()

	print("PlayerData: Character set to %s (%s %s %s)" % [player_name, race, gender, role])
	print("  HP: %d, Defense: %d, Attack: +%d" % [max_hp, defense, attack_bonus])
	if max_mana > 0:
		print("  Mana: %d" % max_mana)


func _apply_role_stats() -> void:
	match role:
		"tank":
			max_hp = 150  # 50% more HP
			defense = 20  # Double defense
			attack_bonus = 5  # Moderate attack bonus

		"wizard":
			max_hp = 80  # 20% less HP
			defense = 5  # Half defense
			attack_bonus = 15  # High spell damage
			max_mana = 100
			current_mana = 100

		"healer":
			max_hp = 100  # Normal HP
			defense = 10  # Normal defense
			attack_bonus = 0  # No attack bonus
			max_mana = 100
			current_mana = 100

		"rogue":
			max_hp = 90  # 10% less HP
			defense = 8  # Slightly less defense
			attack_bonus = 20  # Highest attack bonus (crits!)


## Get avatar sprite path
func get_avatar_path(state: String = "") -> String:
	return CharacterQuiz.get_avatar_path(race, gender, state)


## Get display name for role
func get_role_name() -> String:
	return CharacterQuiz.get_role_name(role)


## Get display name for race
func get_race_name() -> String:
	return CharacterQuiz.get_race_name(race)


## Save character data
func save_to_file() -> void:
	var save_data = {
		"role": role,
		"race": race,
		"gender": gender,
		"player_name": player_name
	}

	var file = FileAccess.open("user://player_character.save", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("PlayerData: Character saved")


## Load character data
func load_from_file() -> bool:
	if not FileAccess.file_exists("user://player_character.save"):
		return false

	var file = FileAccess.open("user://player_character.save", FileAccess.READ)
	if not file:
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		return false

	var save_data = json.data
	if typeof(save_data) != TYPE_DICTIONARY:
		return false

	set_character(
		save_data.get("role", "tank"),
		save_data.get("race", "human"),
		save_data.get("gender", "male"),
		save_data.get("player_name", "")  # Load saved name, or get default if empty
	)
	print("PlayerData: Character loaded from save")
	return true
