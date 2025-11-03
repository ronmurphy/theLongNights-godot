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
	print("========================================")
	print("WORLDMANAGER: load_world() called")

	if not world_exists():
		print("WORLDMANAGER: No world.config found")
		print("========================================")
		return false

	print("WORLDMANAGER: Opening world.config for reading: ", WORLD_CONFIG)
	var file = FileAccess.open(WORLD_CONFIG, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("WorldManager: Failed to open world.config for reading (error %d)" % error)
		print("========================================")
		return false

	var json_string = file.get_as_text()
	file.close()
	print("WORLDMANAGER: Read JSON string (%d characters)" % json_string.length())

	print("WORLDMANAGER: Parsing JSON...")
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("WorldManager: Failed to parse world.config JSON (error %d)" % error)
		print("========================================")
		return false

	var data = json.data
	print("WORLDMANAGER: JSON parsed successfully, data type: ", typeof(data))

	if typeof(data) == TYPE_DICTIONARY:
		print("WORLDMANAGER: JSON data keys: ", data.keys())

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
			print("WORLDMANAGER: Found 'inventory' key in loaded JSON!")
			print("WORLDMANAGER: Inventory data type: ", typeof(data["inventory"]))
			_world_data["inventory"] = data["inventory"]
			if typeof(data["inventory"]) == TYPE_DICTIONARY and data["inventory"].has("slots"):
				print("WORLDMANAGER: Inventory has %d slots in loaded data" % data["inventory"]["slots"].size())
		else:
			print("WORLDMANAGER: No 'inventory' key found in loaded JSON")

		print("WORLDMANAGER: World loaded - Seed: ", _world_data["seed"])
		if _world_data["is_halloween"]:
			print("🎃 This is a HALLOWEEN world! 👻")
		print("WORLDMANAGER: load_world() SUCCESS!")
		print("========================================")
		return true

	push_error("WorldManager: world.config is not a valid dictionary")
	print("========================================")
	return false


func load_inventory_if_exists() -> bool:
	"""Load inventory from save data if it exists. Returns true if inventory was loaded."""
	print("========================================")
	print("WORLDMANAGER: load_inventory_if_exists() called")
	print("WORLDMANAGER: Checking if _world_data has 'inventory' key...")
	print("WORLDMANAGER: _world_data keys: ", _world_data.keys())

	if not _world_data.has("inventory"):
		print("WORLDMANAGER: No 'inventory' key in _world_data - no saved inventory")
		print("========================================")
		return false

	print("WORLDMANAGER: Found 'inventory' in _world_data!")
	print("WORLDMANAGER: Inventory data type: ", typeof(_world_data["inventory"]))
	if typeof(_world_data["inventory"]) == TYPE_DICTIONARY:
		print("WORLDMANAGER: Inventory dictionary keys: ", _world_data["inventory"].keys())

	print("WORLDMANAGER: Searching for player's inventory node...")

	# Find the player node (added to 'player' group in blocky_game.gd)
	var inventory = null
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		var player = player_nodes[0]
		print("WORLDMANAGER: Found player node: ", player.get_path())
		inventory = player.get_node_or_null("Inventory")
		if inventory:
			print("WORLDMANAGER: Found inventory at: ", inventory.get_path())
	else:
		print("WORLDMANAGER: No player found in 'player' group")

	if inventory == null:
		print("WORLDMANAGER: ERROR - Inventory node NOT FOUND!")
		print("========================================")
		return false

	print("WORLDMANAGER: Inventory node found: ", inventory.name)

	if not inventory.has_method("deserialize_inventory"):
		print("WORLDMANAGER: ERROR - Inventory node has no deserialize_inventory method!")
		print("========================================")
		return false

	print("WORLDMANAGER: Calling inventory.deserialize_inventory()...")
	inventory.deserialize_inventory(_world_data["inventory"])
	print("WORLDMANAGER: deserialize_inventory() completed")
	print("WORLDMANAGER: Inventory load SUCCESS!")
	print("========================================")
	return true


# Save world.config to disk
func save_world() -> bool:
	print("========================================")
	print("WORLDMANAGER: save_world() called")

	# Update last played timestamp
	_world_data["last_played"] = Time.get_datetime_string_from_system()
	print("WORLDMANAGER: Updated last_played timestamp")

	# Save inventory data
	print("WORLDMANAGER: Searching for player's inventory node...")

	# Find the player node (added to 'player' group in blocky_game.gd)
	var inventory = null
	var player_nodes = get_tree().get_nodes_in_group("player")
	if player_nodes.size() > 0:
		var player = player_nodes[0]
		print("WORLDMANAGER: Found player node: ", player.get_path())
		inventory = player.get_node_or_null("Inventory")
		if inventory:
			print("WORLDMANAGER: Found inventory at: ", inventory.get_path())
	else:
		print("WORLDMANAGER: No player found in 'player' group")

	if inventory == null:
		print("WORLDMANAGER: WARNING - Inventory node NOT FOUND! Saving without inventory data.")
	elif not inventory.has_method("serialize_inventory"):
		print("WORLDMANAGER: WARNING - Inventory has no serialize_inventory method!")
	else:
		print("WORLDMANAGER: Inventory node found, calling serialize_inventory()...")
		var inventory_data = inventory.serialize_inventory()
		_world_data["inventory"] = inventory_data
		print("WORLDMANAGER: Inventory data saved to _world_data")
		print("WORLDMANAGER: Inventory data type: ", typeof(inventory_data))
		if typeof(inventory_data) == TYPE_DICTIONARY and inventory_data.has("slots"):
			print("WORLDMANAGER: Inventory has %d slots in save data" % inventory_data["slots"].size())

	# Convert Vector3 to array for JSON
	var save_data = _world_data.duplicate()
	var pos = _world_data["player_position"]
	save_data["player_position"] = [pos.x, pos.y, pos.z]

	print("WORLDMANAGER: Converting to JSON...")
	var json_string = JSON.stringify(save_data, "\t")
	print("WORLDMANAGER: JSON string length: %d characters" % json_string.length())

	# Ensure save directory exists
	DirAccess.make_dir_absolute(SAVE_DIR)
	print("WORLDMANAGER: Ensured save directory exists: ", SAVE_DIR)

	print("WORLDMANAGER: Opening file for writing: ", WORLD_CONFIG)
	var file = FileAccess.open(WORLD_CONFIG, FileAccess.WRITE)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("WorldManager: Failed to open world.config for writing (error %d)" % error)
		print("========================================")
		return false

	print("WORLDMANAGER: Writing JSON to file...")
	file.store_string(json_string)
	file.close()

	print("WORLDMANAGER: File written and closed successfully")
	print("WORLDMANAGER: World save COMPLETE!")
	print("========================================")
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
