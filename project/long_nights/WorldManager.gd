extends Node

# WorldManager - Handles world save/load, seed management, and backups

const SAVE_DIR = "user://save"
const WORLD_CONFIG = "user://save/world.config"
const BACKUP_DIR = "user://backups"

var _world_data := {
	"seed": 131183,
	"created_date": "",
	"last_played": "",
	"player_position": Vector3(0, 64, 0),
	"game_time_hours": 6,
	"game_time_days": 1,
	"game_time_weeks": 1,
	"blood_moon_count": 0,
	"is_halloween": false
}


func _ready():
	# Ensure backup directory exists
	DirAccess.make_dir_absolute(BACKUP_DIR)


# Check if a world save exists
func world_exists() -> bool:
	return FileAccess.file_exists(WORLD_CONFIG)


# Get current world seed
func get_seed() -> int:
	return _world_data["seed"]


# Get player spawn position
func get_player_position() -> Vector3:
	return _world_data["player_position"]


# Set player position (for saving)
func set_player_position(pos: Vector3) -> void:
	_world_data["player_position"] = pos


# Get blood moon count
func get_blood_moon_count() -> int:
	return _world_data["blood_moon_count"]


# Increment blood moon count (called when blood moon starts)
func increment_blood_moon_count() -> void:
	_world_data["blood_moon_count"] += 1
	save_world()
	print("WorldManager: Blood moon count increased to ", _world_data["blood_moon_count"])


# Check if today is Halloween (Oct 31)
static func is_today_halloween() -> bool:
	var datetime = Time.get_datetime_dict_from_system()
	return datetime.month == 10 and datetime.day == 31


# Get Halloween flag for this world
func is_halloween_world() -> bool:
	return _world_data["is_halloween"]


# Load world.config from disk
func load_world() -> bool:
	if not world_exists():
		print("WorldManager: No world.config found")
		return false

	var file = FileAccess.open(WORLD_CONFIG, FileAccess.READ)
	if file == null:
		push_error("WorldManager: Failed to open world.config for reading")
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("WorldManager: Failed to parse world.config JSON")
		return false

	var data = json.data
	if typeof(data) == TYPE_DICTIONARY:
		# Load data, keeping defaults for missing keys
		if "seed" in data:
			_world_data["seed"] = data["seed"]
		if "created_date" in data:
			_world_data["created_date"] = data["created_date"]
		if "last_played" in data:
			_world_data["last_played"] = data["last_played"]
		if "player_position" in data and typeof(data["player_position"]) == TYPE_ARRAY:
			var pos = data["player_position"]
			_world_data["player_position"] = Vector3(pos[0], pos[1], pos[2])
		if "game_time_hours" in data:
			_world_data["game_time_hours"] = data["game_time_hours"]
		if "game_time_days" in data:
			_world_data["game_time_days"] = data["game_time_days"]
		if "game_time_weeks" in data:
			_world_data["game_time_weeks"] = data["game_time_weeks"]
		if "blood_moon_count" in data:
			_world_data["blood_moon_count"] = data["blood_moon_count"]
		if "is_halloween" in data:
			_world_data["is_halloween"] = data["is_halloween"]

		# Load inventory data
		if "inventory" in data:
			_world_data["inventory"] = data["inventory"]

		# Load ruin registry data
		if "ruin_registry" in data:
			_world_data["ruin_registry"] = data["ruin_registry"]
			# Immediately deserialize into RuinRegistry
			if RuinRegistry.has_method("deserialize_registry"):
				RuinRegistry.deserialize_registry(data["ruin_registry"])

		print("WorldManager: World loaded - Seed: ", _world_data["seed"])
		if _world_data["is_halloween"]:
			print("🎃 This is a HALLOWEEN world! 👻")
		return true

	push_error("WorldManager: world.config is not a valid dictionary")
	return false


func load_inventory_if_exists() -> bool:
	"""Load inventory from save data if it exists. Returns true if inventory was loaded."""
	if not _world_data.has("inventory"):
		print("WorldManager: No saved inventory data found")
		return false

	# Find the player node (added to 'player' group in blocky_game.gd)
	var inventory = null
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		var player = player_nodes[0]
		inventory = player.get_node_or_null("Inventory")

	if inventory and inventory.has_method("deserialize_inventory"):
		inventory.deserialize_inventory(_world_data["inventory"])
		print("WorldManager: Loaded inventory data")
		return true
	else:
		print("WorldManager: Could not find inventory node")
		return false


# Save world.config to disk
func save_world() -> bool:
	# Update last played timestamp
	_world_data["last_played"] = Time.get_datetime_string_from_system()

	# Save inventory data
	var inventory = null
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		var player = player_nodes[0]
		inventory = player.get_node_or_null("Inventory")

	if inventory and inventory.has_method("serialize_inventory"):
		_world_data["inventory"] = inventory.serialize_inventory()
		print("WorldManager: Saved inventory data")

	# Save ruin registry data
	if RuinRegistry.has_method("serialize_registry"):
		_world_data["ruin_registry"] = RuinRegistry.serialize_registry()

	# Convert Vector3 to array for JSON
	var save_data = _world_data.duplicate()
	var pos = _world_data["player_position"]
	save_data["player_position"] = [pos.x, pos.y, pos.z]

	var json_string = JSON.stringify(save_data, "\t")

	# Ensure save directory exists
	DirAccess.make_dir_absolute(SAVE_DIR)

	var file = FileAccess.open(WORLD_CONFIG, FileAccess.WRITE)
	if file == null:
		push_error("WorldManager: Failed to open world.config for writing")
		return false

	file.store_string(json_string)
	file.close()

	print("WorldManager: World saved")
	return true


# Create a new world with given seed
func create_new_world(seed: int) -> bool:
	print("WorldManager: Creating new world with seed: ", seed)

	# Delete existing save
	delete_world()

	# Set up new world data
	_world_data["seed"] = seed
	_world_data["created_date"] = Time.get_datetime_string_from_system()
	_world_data["last_played"] = _world_data["created_date"]
	_world_data["player_position"] = Vector3(0, 64, 0)
	_world_data["game_time_hours"] = 6
	_world_data["game_time_days"] = 1
	_world_data["game_time_weeks"] = 1
	_world_data["blood_moon_count"] = 0
	
	# Check if this new world is being created on Halloween!
	_world_data["is_halloween"] = is_today_halloween()
	if _world_data["is_halloween"]:
		print("🎃 HALLOWEEN MODE ACTIVATED! Pumpkins will be abundant! 👻")

	# Save world.config
	return save_world()


# Delete the current world save
func delete_world() -> bool:
	print("WorldManager: Deleting world save...")

	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		print("WorldManager: No save directory to delete")
		return true

	# Recursively delete save directory
	var result = _delete_directory_recursive(SAVE_DIR)

	if result:
		print("WorldManager: World deleted successfully")
	else:
		push_error("WorldManager: Failed to delete world")

	return result


# Backup current world to timestamped folder
func backup_world() -> bool:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		push_error("WorldManager: No world to backup")
		return false

	# Create timestamp for backup name
	var datetime = Time.get_datetime_dict_from_system()
	var timestamp = "%04d-%02d-%02d_%02d-%02d-%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]

	var backup_path = BACKUP_DIR + "/world_backup_" + timestamp

	print("WorldManager: Backing up world to: ", backup_path)

	# Ensure backup directory exists
	DirAccess.make_dir_absolute(BACKUP_DIR)

	# Copy directory recursively
	var result = _copy_directory_recursive(SAVE_DIR, backup_path)

	if result:
		print("WorldManager: Backup created successfully at: ", backup_path)
	else:
		push_error("WorldManager: Backup failed")

	return result


# Recursively copy a directory
func _copy_directory_recursive(from_dir: String, to_dir: String) -> bool:
	var dir = DirAccess.open(from_dir)
	if dir == null:
		push_error("WorldManager: Failed to open source directory: ", from_dir)
		return false

	# Create destination directory
	var err = DirAccess.make_dir_recursive_absolute(to_dir)
	if err != OK:
		push_error("WorldManager: Failed to create destination directory: ", to_dir)
		return false

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var source_path = from_dir + "/" + file_name
		var dest_path = to_dir + "/" + file_name

		if dir.current_is_dir():
			# Recursively copy subdirectory
			if not _copy_directory_recursive(source_path, dest_path):
				return false
		else:
			# Copy file
			err = DirAccess.copy_absolute(source_path, dest_path)
			if err != OK:
				push_error("WorldManager: Failed to copy file: ", source_path)
				return false

		file_name = dir.get_next()

	dir.list_dir_end()
	return true


# Recursively delete a directory
func _delete_directory_recursive(dir_path: String) -> bool:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		push_error("WorldManager: Failed to open directory for deletion: ", dir_path)
		return false

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var file_path = dir_path + "/" + file_name

		if dir.current_is_dir():
			# Recursively delete subdirectory
			if not _delete_directory_recursive(file_path):
				return false
		else:
			# Delete file
			var err = DirAccess.remove_absolute(file_path)
			if err != OK:
				push_error("WorldManager: Failed to delete file: ", file_path)
				return false

		file_name = dir.get_next()

	dir.list_dir_end()

	# Delete the directory itself
	var err = DirAccess.remove_absolute(dir_path)
	if err != OK:
		push_error("WorldManager: Failed to delete directory: ", dir_path)
		return false

	return true
