extends Node

# SaveArchiver - Handles archiving game saves as ZIP files with player name, companion name, date, time
# Archives are stored in user://saves/archives/
# Format: {PlayerName}_{CompanionName}_{YYYY-MM-DD}_{HH-MM-SS}.zip

const ARCHIVE_DIR = "user://saves/archives"
const SAVE_DIR = "user://save"
const TEMP_SCREENSHOT = "user://temp_screenshot.png"
const COMPANION_SAVE = "user://companion.save"
const DIALOGUE_SAVE = "user://dialogue_progress.json"

class ArchiveInfo:
	var filename: String
	var character_name: String
	var archive_path: String
	var date_time: String
	var thumbnail_data: PackedByteArray = PackedByteArray()

	func _to_string() -> String:
		return "[%s] %s" % [date_time, character_name]


# Initialize archive system
func _ready() -> void:
	# Ensure archive directory exists (create all parent directories too)
	DirAccess.make_dir_recursive_absolute(ARCHIVE_DIR)
	print("SaveArchiver: Archive system initialized at ", ARCHIVE_DIR)


# Get current character name from CompanionManager or default
func _get_character_name() -> String:
	var cm = get_node_or_null("/root/CompanionManager")
	if cm and cm.has_method("get_companion_name"):
		return cm.get_companion_name()
	return "Unknown"


# Get player name from PlayerData
func _get_player_name() -> String:
	if has_node("/root/PlayerData"):
		var pd = get_node("/root/PlayerData")
		if pd.player_name != null and pd.player_name != "":
			return pd.player_name
	return "Player"


# Create a timestamp string for archiving (YYYY-MM-DD_HH-MM-SS)
func _get_timestamp() -> String:
	var datetime = Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d_%02d-%02d-%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]


# Create a friendly date-time string (Mon, Jan 1, 2024 at 12:30:45 PM)
func _get_friendly_datetime() -> String:
	var datetime = Time.get_datetime_dict_from_system()
	var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

	# Calculate day of week using Zeller's algorithm
	var day_of_week = _calculate_day_of_week(datetime.year, datetime.month, datetime.day)
	var day_name = days[day_of_week]
	var month_name = months[datetime.month - 1]

	var hour_12 = datetime.hour % 12
	if hour_12 == 0:
		hour_12 = 12
	var am_pm = "AM" if datetime.hour < 12 else "PM"

	return "%s, %s %d, %d at %02d:%02d:%02d %s" % [
		day_name, month_name, datetime.day, datetime.year,
		hour_12, datetime.minute, datetime.second, am_pm
	]


# Calculate day of week (0 = Sunday, 6 = Saturday) using Zeller's algorithm
func _calculate_day_of_week(year: int, month: int, day: int) -> int:
	if month < 3:
		month += 12
		year -= 1
	var q = day
	var m = month
	var k = year % 100
	var j = year / 100
	var h = (q + ((13 * (m + 1)) / 5) + k + (k / 4) + (j / 4) - (2 * j)) % 7
	# Convert from Zeller (Saturday = 0) to our format (Sunday = 0)
	return (h + 6) % 7


# Generate archive filename from player name, companion name and timestamp
func _generate_archive_filename(player_name: String, companion_name: String) -> String:
	var timestamp = _get_timestamp()
	# Remove special characters from names for filename
	var safe_player = player_name.to_lower().replace(" ", "_")
	safe_player = safe_player.replace("'", "").replace('"', "")
	var safe_companion = companion_name.to_lower().replace(" ", "_")
	safe_companion = safe_companion.replace("'", "").replace('"', "")
	return "%s_%s_%s.zip" % [safe_player, safe_companion, timestamp]


# Archive the current game save with player name, companion name, date, time
func archive_current_save() -> bool:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		push_error("SaveArchiver: No save directory to archive")
		return false

	# Ensure archive directory exists
	if not DirAccess.dir_exists_absolute(ARCHIVE_DIR):
		print("SaveArchiver: Creating archive directory...")
		DirAccess.make_dir_recursive_absolute(ARCHIVE_DIR)

	var player_name = _get_player_name()
	var companion_name = _get_character_name()
	var archive_filename = _generate_archive_filename(player_name, companion_name)
	var archive_path = ARCHIVE_DIR + "/" + archive_filename

	print("SaveArchiver: Creating archive '%s'" % archive_filename)
	print("SaveArchiver: Player: %s, Companion: %s" % [player_name, companion_name])

	# Create the archive directly
	return _create_zip_archive(archive_path, player_name, companion_name)


# Create ZIP archive using ZIPPacker (for creating new archives)
func _create_zip_archive(archive_path: String, _player_name: String, _companion_name: String) -> bool:
	print("SaveArchiver: _create_zip_archive called with path: ", archive_path)
	var packer = ZIPPacker.new()
	var err = packer.open(archive_path)

	if err != OK:
		push_error("SaveArchiver: Failed to create ZIP file at ", archive_path, " Error: ", err)
		return false

	print("SaveArchiver: ZIP file opened successfully, packing save files...")

	# Add screenshot if it exists
	if FileAccess.file_exists(TEMP_SCREENSHOT):
		print("SaveArchiver: Adding screenshot...")
		var screenshot_data = FileAccess.get_file_as_bytes(TEMP_SCREENSHOT)
		err = packer.start_file("thumbnail.png")
		if err == OK:
			packer.write_file(screenshot_data)
			packer.close_file()
			print("SaveArchiver: ✓ Added thumbnail to archive")
		else:
			print("SaveArchiver: ✗ Failed to add thumbnail, error: ", err)
	else:
		print("SaveArchiver: No screenshot file found at: ", TEMP_SCREENSHOT)

	# Add companion save if it exists
	if FileAccess.file_exists(COMPANION_SAVE):
		print("SaveArchiver: Adding companion data...")
		var companion_data = FileAccess.get_file_as_bytes(COMPANION_SAVE)
		err = packer.start_file("companion.save")
		if err == OK:
			packer.write_file(companion_data)
			packer.close_file()
			print("SaveArchiver: ✓ Added companion data to archive")
		else:
			print("SaveArchiver: ✗ Failed to add companion data, error: ", err)
	else:
		print("SaveArchiver: No companion save found at: ", COMPANION_SAVE)

	# Add dialogue progress if it exists
	if FileAccess.file_exists(DIALOGUE_SAVE):
		print("SaveArchiver: Adding dialogue progress...")
		var dialogue_data = FileAccess.get_file_as_bytes(DIALOGUE_SAVE)
		err = packer.start_file("dialogue_progress.json")
		if err == OK:
			packer.write_file(dialogue_data)
			packer.close_file()
			print("SaveArchiver: ✓ Added dialogue progress to archive")
		else:
			print("SaveArchiver: ✗ Failed to add dialogue progress, error: ", err)
	else:
		print("SaveArchiver: No dialogue save found at: ", DIALOGUE_SAVE)

	# Recursively add all files from save directory
	print("SaveArchiver: Adding save directory files from: ", SAVE_DIR)
	if not _pack_directory_recursive(packer, SAVE_DIR, "save"):
		push_error("SaveArchiver: Failed to pack directory contents")
		packer.close()
		return false

	err = packer.close()
	if err != OK:
		push_error("SaveArchiver: Failed to close ZIP file")
		return false

	print("SaveArchiver: Archive created successfully at ", archive_path)
	return true


# Recursively pack directory contents into ZIP
func _pack_directory_recursive(packer: ZIPPacker, source_dir: String, zip_prefix: String) -> bool:
	var dir = DirAccess.open(source_dir)
	if dir == null:
		push_error("SaveArchiver: Failed to open directory: ", source_dir)
		return false

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var source_path = source_dir + "/" + file_name
		var zip_path = zip_prefix + file_name if zip_prefix.is_empty() else zip_prefix + "/" + file_name

		if dir.current_is_dir():
			# Recursively pack subdirectory
			if not _pack_directory_recursive(packer, source_path, zip_path):
				return false
		else:
			# Pack file
			var file_data = FileAccess.get_file_as_bytes(source_path)
			var err = packer.start_file(zip_path)
			if err != OK:
				push_error("SaveArchiver: Failed to add file to ZIP: ", zip_path)
				return false
			packer.write_file(file_data)
			packer.close_file()

		file_name = dir.get_next()

	dir.list_dir_end()
	return true


# Get list of all archives
func get_archives() -> Array[ArchiveInfo]:
	var archives: Array[ArchiveInfo] = []

	if not DirAccess.dir_exists_absolute(ARCHIVE_DIR):
		print("SaveArchiver: Archive directory does not exist, creating it...")
		DirAccess.make_dir_recursive_absolute(ARCHIVE_DIR)
		return archives

	var dir = DirAccess.open(ARCHIVE_DIR)
	if dir == null:
		push_error("SaveArchiver: Failed to open archive directory")
		return archives

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".zip"):
			var archive_info = ArchiveInfo.new()
			archive_info.filename = file_name
			archive_info.archive_path = ARCHIVE_DIR + "/" + file_name

			# Parse names from filename (format: playername_companionname_YYYY-MM-DD_HH-MM-SS.zip)
			var parts = file_name.trim_suffix(".zip").split("_")
			if parts.size() >= 5:
				# New format: playername_companionname_date_time
				var player_name = parts[0]
				var companion_name = parts[1]
				archive_info.character_name = "%s & %s" % [player_name.capitalize(), companion_name.capitalize()]
				archive_info.date_time = "%s_%s" % [parts[-2], parts[-1]]
			elif parts.size() >= 3:
				# Old format: companionname_date_time (backward compatibility)
				archive_info.character_name = parts[0].capitalize()
				archive_info.date_time = "%s_%s" % [parts[-2], parts[-1]]
			else:
				archive_info.character_name = "Unknown"
				archive_info.date_time = "Unknown"

			# Try to extract thumbnail
			archive_info.thumbnail_data = _extract_thumbnail_from_archive(archive_info.archive_path)

			archives.append(archive_info)

		file_name = dir.get_next()

	dir.list_dir_end()

	# Sort by date (newest first)
	archives.sort_custom(func(a, b): return a.archive_path > b.archive_path)

	return archives


# Extract thumbnail from ZIP archive
func _extract_thumbnail_from_archive(archive_path: String) -> PackedByteArray:
	var reader = ZIPReader.new()
	var err = reader.open(archive_path)

	if err != OK:
		print("SaveArchiver: Failed to open archive for reading thumbnail: ", archive_path)
		return PackedByteArray()

	if not reader.file_exists("thumbnail.png"):
		print("SaveArchiver: No thumbnail found in archive")
		reader.close()
		return PackedByteArray()

	var thumbnail_data = reader.read_file("thumbnail.png")
	reader.close()

	return thumbnail_data


# Restore archive to current save (overwrites current game)
func restore_archive(archive_path: String) -> bool:
	print("SaveArchiver: === RESTORE ARCHIVE START ===")
	if not FileAccess.file_exists(archive_path):
		push_error("SaveArchiver: Archive file not found: ", archive_path)
		return false

	print("SaveArchiver: Restoring from archive: ", archive_path)

	# Delete current save
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		print("SaveArchiver: Deleting current save directory...")
		if not _delete_directory_recursive(SAVE_DIR):
			push_error("SaveArchiver: Failed to delete current save")
			return false
		print("SaveArchiver: Current save deleted")

	# Extract archive
	print("SaveArchiver: Opening archive for extraction...")
	var reader = ZIPReader.new()
	var err = reader.open(archive_path)

	if err != OK:
		push_error("SaveArchiver: Failed to open archive for extraction: ", archive_path, " Error: ", err)
		return false

	print("SaveArchiver: Archive opened successfully")

	# Create save directory
	DirAccess.make_dir_absolute(SAVE_DIR)
	print("SaveArchiver: Created save directory")

	# Extract all files
	var files = reader.get_files()
	print("SaveArchiver: Found ", files.size(), " files in archive")
	
	var extracted_count = 0
	for file_path in files:
		print("SaveArchiver: Processing file: ", file_path)
		
		if file_path == "thumbnail.png":
			print("SaveArchiver: Skipping thumbnail")
			continue  # Skip thumbnail, it's not part of the game save

		# Extract file data
		var file_data = reader.read_file(file_path)
		print("SaveArchiver: Read ", file_data.size(), " bytes from ", file_path)
		var full_path = ""

		# Handle special files (companion, dialogue) that go in user:// root
		if file_path == "companion.save":
			full_path = COMPANION_SAVE
			print("SaveArchiver: Restoring companion data to: ", full_path)
		elif file_path == "dialogue_progress.json":
			full_path = DIALOGUE_SAVE
			print("SaveArchiver: Restoring dialogue progress to: ", full_path)
		elif file_path.begins_with("save/"):
			# Regular save files - remove 'save/' prefix and put in SAVE_DIR
			full_path = SAVE_DIR + "/" + file_path.substr(5)
			print("SaveArchiver: Restoring save file to: ", full_path)
		else:
			# Old format compatibility - files without prefix
			full_path = SAVE_DIR + "/" + file_path
			print("SaveArchiver: Restoring file (old format) to: ", full_path)

		# Ensure parent directory exists
		var parent_dir = full_path.get_base_dir()
		if parent_dir != "":
			DirAccess.make_dir_recursive_absolute(parent_dir)

		var file = FileAccess.open(full_path, FileAccess.WRITE)
		if file == null:
			var error = FileAccess.get_open_error()
			push_error("SaveArchiver: Failed to write extracted file: ", full_path, " Error: ", error)
			reader.close()
			return false

		file.store_buffer(file_data)
		file.close()
		extracted_count += 1
		print("SaveArchiver: ✓ Extracted ", file_path)

	reader.close()
	
	print("SaveArchiver: Extracted ", extracted_count, " files successfully")

	# Reload world from restored save
	print("SaveArchiver: Attempting to reload world data...")
	var wm = get_node_or_null("/root/WorldManager")
	if wm and wm.has_method("load_world"):
		print("SaveArchiver: Calling WorldManager.load_world()...")
		wm.load_world()
		print("SaveArchiver: WorldManager.load_world() completed")
	else:
		print("SaveArchiver: WARNING - WorldManager not found or load_world() method missing")

	print("SaveArchiver: === RESTORE ARCHIVE COMPLETE ===")
	return true


# Delete an archive
func delete_archive(archive_path: String) -> bool:
	if not FileAccess.file_exists(archive_path):
		push_error("SaveArchiver: Archive file not found: ", archive_path)
		return false

	var err = DirAccess.remove_absolute(archive_path)
	if err != OK:
		push_error("SaveArchiver: Failed to delete archive: ", archive_path)
		return false

	print("SaveArchiver: Archive deleted: ", archive_path)
	return true


# Take screenshot for archive thumbnail
func capture_screenshot_for_archive() -> bool:
	# Capture screenshot at native resolution
	var image = get_viewport().get_texture().get_image()
	if image == null:
		push_error("SaveArchiver: Failed to capture screenshot")
		return false

	# Save to temporary location
	var err = image.save_png(TEMP_SCREENSHOT)
	if err != OK:
		push_error("SaveArchiver: Failed to save screenshot: ", err)
		return false

	print("SaveArchiver: Screenshot captured to temporary location")
	return true


# Delete temporary screenshot
func delete_temp_screenshot() -> void:
	if FileAccess.file_exists(TEMP_SCREENSHOT):
		DirAccess.remove_absolute(TEMP_SCREENSHOT)
		print("SaveArchiver: Temporary screenshot deleted")


# Recursively delete a directory (utility function)
func _delete_directory_recursive(dir_path: String) -> bool:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		push_error("SaveArchiver: Failed to open directory for deletion: ", dir_path)
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
				push_error("SaveArchiver: Failed to delete file: ", file_path)
				return false

		file_name = dir.get_next()

	dir.list_dir_end()

	# Delete the directory itself
	var err = DirAccess.remove_absolute(dir_path)
	if err != OK:
		push_error("SaveArchiver: Failed to delete directory: ", dir_path)
		return false

	return true


# Get friendly date-time string for an archive
func get_archive_friendly_datetime(archive_filename: String) -> String:
	# Parse filename format: charname_YYYY-MM-DD_HH-MM-SS.zip
	var parts = archive_filename.trim_suffix(".zip").split("_")
	if parts.size() >= 4:
		var date_part = parts[-2]  # YYYY-MM-DD
		var time_part = parts[-1]  # HH-MM-SS

		# Parse into readable format
		var date_parts = date_part.split("-")
		var time_parts = time_part.split("-")

		if date_parts.size() == 3 and time_parts.size() == 3:
			var year = int(date_parts[0])
			var month = int(date_parts[1])
			var day = int(date_parts[2])
			var hour = int(time_parts[0])
			var minute = int(time_parts[1])
			var second = int(time_parts[2])

			var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
			var month_name = months[month - 1]

			var hour_12 = hour % 12
			if hour_12 == 0:
				hour_12 = 12
			var am_pm = "AM" if hour < 12 else "PM"

			return "%s %d, %d at %02d:%02d:%02d %s" % [month_name, day, year, hour_12, minute, second, am_pm]

	return "Unknown"
