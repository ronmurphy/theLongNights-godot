extends Node
## ChunkPersistence - Handles saving/loading chunks to disk
## CRITICAL: Prevents the bedrock corruption bug by maintaining single source of truth
##
## Design:
## 1. Generated chunks are written to disk immediately
## 2. Player modifications are stored in SEPARATE .mod files
## 3. When loading, we ALWAYS read from disk first (never regenerate)
## 4. Modifications are applied ON TOP of saved chunk

class_name ChunkPersistence

const SAVE_DIR = "user://worlds/"
const CHUNK_EXTENSION = ".chunk"
const MOD_EXTENSION = ".mod"

# Chunk file format version (increment if we change format)
const CHUNK_VERSION = 1

# File signatures for validation
const CHUNK_SIGNATURE = 0x454E4843  # "CHNE" in hex

signal chunk_saved(chunk_pos: Vector3i)
signal chunk_loaded(chunk_pos: Vector3i)

func _ready() -> void:
	print("💾 ChunkPersistence initialized")
	_ensure_save_directory()

func _ensure_save_directory() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_absolute(SAVE_DIR, SAVE_DIR)
		print("📁 Created save directory: %s" % SAVE_DIR)

## Get full path for a chunk file
func _get_chunk_path(chunk_pos: Vector3i) -> String:
	return "%s/chunk_%d_%d_%d%s" % [SAVE_DIR, chunk_pos.x, chunk_pos.y, chunk_pos.z, CHUNK_EXTENSION]

## Get full path for a modification file
func _get_mod_path(chunk_pos: Vector3i) -> String:
	return "%s/chunk_%d_%d_%d%s" % [SAVE_DIR, chunk_pos.x, chunk_pos.y, chunk_pos.z, MOD_EXTENSION]

## Save chunk to disk (called after generation)
func save_chunk(chunk_pos: Vector3i, chunk_data: Array, world_seed: int) -> bool:
	var path = _get_chunk_path(chunk_pos)

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("❌ Failed to save chunk %s" % chunk_pos)
		return false

	# Write header
	file.store_32(CHUNK_SIGNATURE)
	file.store_32(CHUNK_VERSION)
	file.store_32(world_seed)
	file.store_32(chunk_pos.x)
	file.store_32(chunk_pos.y)
	file.store_32(chunk_pos.z)
	file.store_32(chunk_data.size())

	# Write block data
	for voxel in chunk_data:
		file.store_32(voxel)

	print("✅ Saved chunk %s" % chunk_pos)
	chunk_saved.emit(chunk_pos)
	return true

## Load chunk from disk (returns null if doesn't exist)
func load_chunk(chunk_pos: Vector3i) -> Array:
	var path = _get_chunk_path(chunk_pos)

	# If file doesn't exist, return null (caller will generate)
	if not FileAccess.file_exists(path):
		return []

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("❌ Failed to load chunk %s" % chunk_pos)
		return []

	# Read and validate header
	var signature = file.get_32()
	if signature != CHUNK_SIGNATURE:
		print("❌ Invalid chunk file signature: %s" % chunk_pos)
		return []

	var version = file.get_32()
	if version != CHUNK_VERSION:
		print("❌ Chunk version mismatch: %s (got %d, expected %d)" % [chunk_pos, version, CHUNK_VERSION])
		return []

	var stored_seed = file.get_32()
	var stored_x = file.get_32()
	var stored_y = file.get_32()
	var stored_z = file.get_32()
	var data_size = file.get_32()

	# Validate coordinates match
	if Vector3i(stored_x, stored_y, stored_z) != chunk_pos:
		print("❌ Chunk coordinates mismatch: expected %s, got %s" % [chunk_pos, Vector3i(stored_x, stored_y, stored_z)])
		return []

	# Read block data
	var chunk_data = []
	chunk_data.resize(data_size)
	for i in range(data_size):
		chunk_data[i] = file.get_32()

	print("✅ Loaded chunk %s" % chunk_pos)
	chunk_loaded.emit(chunk_pos)
	return chunk_data

## Record a block modification (player placed/destroyed a block)
## CRITICAL: This is separate from chunk file to prevent corruption
func record_modification(chunk_pos: Vector3i, local_pos: Vector3i, old_value: int, new_value: int) -> bool:
	var mod_path = _get_mod_path(chunk_pos)

	# Load existing mods or create new
	var mods = []
	if FileAccess.file_exists(mod_path):
		var file = FileAccess.open(mod_path, FileAccess.READ)
		if file != null:
			var json_str = file.get_as_text()
			var json = JSON.new()
			if json.parse(json_str) == OK:
				mods = json.data

	# Add new modification
	var mod = {
		"timestamp": Time.get_ticks_msec(),
		"local_pos": [local_pos.x, local_pos.y, local_pos.z],
		"old_value": old_value,
		"new_value": new_value
	}
	mods.append(mod)

	# Save modifications
	var file = FileAccess.open(mod_path, FileAccess.WRITE)
	if file == null:
		print("❌ Failed to save modifications for chunk %s" % chunk_pos)
		return false

	var json = JSON.stringify(mods)
	file.store_string(json)

	print("📝 Recorded modification at %s in chunk %s" % [local_pos, chunk_pos])
	return true

## Load and apply all modifications to a chunk
func apply_modifications(chunk_pos: Vector3i, chunk_data: Array) -> Array:
	var mod_path = _get_mod_path(chunk_pos)

	if not FileAccess.file_exists(mod_path):
		return chunk_data  # No modifications

	var file = FileAccess.open(mod_path, FileAccess.READ)
	if file == null:
		return chunk_data

	var json_str = file.get_as_text()
	var json = JSON.new()
	if json.parse(json_str) != OK:
		print("⚠️ Failed to parse mods for chunk %s" % chunk_pos)
		return chunk_data

	var mods = json.data
	for mod in mods:
		var local_pos = Vector3i(mod["local_pos"][0], mod["local_pos"][1], mod["local_pos"][2])
		var new_value = mod["new_value"]

		var index = local_pos.y * 16 * 16 + local_pos.z * 16 + local_pos.x
		if index < chunk_data.size():
			chunk_data[index] = new_value

	print("✅ Applied %d modifications to chunk %s" % [mods.size(), chunk_pos])
	return chunk_data

## Delete all data for a chunk (for world reset)
func delete_chunk(chunk_pos: Vector3i) -> bool:
	var chunk_path = _get_chunk_path(chunk_pos)
	var mod_path = _get_mod_path(chunk_pos)

	if FileAccess.file_exists(chunk_path):
		if DirAccess.remove_absolute(chunk_path) != OK:
			return false

	if FileAccess.file_exists(mod_path):
		if DirAccess.remove_absolute(mod_path) != OK:
			return false

	print("🗑️ Deleted chunk %s" % chunk_pos)
	return true
