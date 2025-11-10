extends Node
## WinterIceSystem - Freezes water to ice in winter, thaws in other seasons
## Replaces all water blocks with ice blocks during winter

var _is_frozen: bool = false
var _initialized: bool = false
var _terrain: VoxelTerrain = null
var _blocks = null
var _water_system = null

# Block IDs (from generator.gd)
const WATER_TOP = 13
const WATER_FULL = 14
const ICE = 47

# Track water positions for thawing
var _frozen_water_positions: Array[Dictionary] = []  # [{pos: Vector3i, was_top: bool}]

func _ready() -> void:
	print("[WinterIceSystem] Autoload ready - will initialize on first season change")
	# Connect to TimeManager immediately (it's always available)
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.season_changed.connect(_on_season_changed)
		print("[WinterIceSystem] ✓ Connected to TimeManager")


func _try_initialize() -> bool:
	"""Try to find game nodes. Returns true if successful."""
	if _initialized:
		return true
	
	print("[WinterIceSystem] Attempting initialization...")
	
	# Find the blocky_game node (it's under /root/Main/Game in the scene tree)
	var game = get_node_or_null("/root/Main/Game")
	if not game:
		print("[WinterIceSystem] /root/Main/Game not found")
		return false
	
	print("[WinterIceSystem] Found game node: ", game.name)
	_terrain = game.get_node_or_null("VoxelTerrain")
	_blocks = game.get_node_or_null("Blocks")
	_water_system = game.get_node_or_null("Water")
	
	if not _terrain or not _blocks:
		print("[WinterIceSystem] Terrain or Blocks not found")
		print("[WinterIceSystem] _terrain: ", _terrain)
		print("[WinterIceSystem] _blocks: ", _blocks)
		return false
	
	print("[WinterIceSystem] ✓ Initialized successfully")
	_initialized = true
	
	# Apply current season state
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		var current_season = time_manager.current_season
		print("[WinterIceSystem] Current season: ", current_season)
		if current_season == "winter":
			freeze_water()
	
	return true


func _on_season_changed(new_season: String) -> void:
	"""Handle season transitions - initializes on first call"""
	print("[WinterIceSystem] Season changed to: ", new_season)
	
	# Initialize on first season change (game must be loaded at this point)
	if not _initialized:
		if not _try_initialize():
			push_error("[WinterIceSystem] Failed to initialize - game nodes not found!")
			return
	
	if new_season == "winter":
		freeze_water()
	else:
		thaw_water()


func freeze_water() -> void:
	"""Convert all water blocks to ice blocks"""
	if not _initialized:
		print("[WinterIceSystem] Can't freeze - not initialized")
		return
	
	print("❄️ Freezing water...")
	_is_frozen = true
	
	# Disable water flow system (stops water spreading)
	if _water_system:
		_water_system.set_process(false)
	
	# Replace all water blocks with ice in loaded chunks
	_replace_water_with_ice()


func thaw_water() -> void:
	"""Convert all ice blocks back to water"""
	if not _initialized:
		return  # Can't thaw if never initialized
	
	print("💧 Thawing ice...")
	_is_frozen = false
	
	# Replace all ice blocks back to water (scans for actual ice blocks)
	_replace_ice_with_water()
	
	# Re-enable water flow system
	if _water_system:
		_water_system.set_process(true)


func _replace_water_with_ice() -> void:
	"""Find all water blocks in loaded chunks and replace with ice"""
	if not _terrain:
		print("[WinterIceSystem] No terrain found!")
		return
	
	_frozen_water_positions.clear()
	
	var voxel_tool = _terrain.get_voxel_tool()
	voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE
	
	# Get player position to determine loaded chunks
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("[WinterIceSystem] No player found!")
		return
	
	var player_pos = player.global_position
	var search_radius = 128  # Search within 128 blocks of player
	
	# Search in a box around player
	var min_pos = Vector3i(player_pos) - Vector3i(search_radius, 32, search_radius)
	var max_pos = Vector3i(player_pos) + Vector3i(search_radius, 32, search_radius)
	
	print("[WinterIceSystem] Scanning from ", min_pos, " to ", max_pos)
	print("[WinterIceSystem] Looking for block IDs: WATER_TOP=", WATER_TOP, " WATER_FULL=", WATER_FULL, " ICE=", ICE)
	
	var blocks_scanned = 0
	var unique_block_ids = {}
	
	# Check all blocks for water
	for x in range(min_pos.x, max_pos.x):
		for y in range(min_pos.y, max_pos.y):
			# Skip underground/caves (Y < -9) - never freeze water there
			# Bedrock barrier is at Y=-10, so water below Y=-9 is underground
			if y < -9:
				continue

			for z in range(min_pos.z, max_pos.z):
				var pos = Vector3i(x, y, z)
				var voxel_id = voxel_tool.get_voxel(pos)
				blocks_scanned += 1

				# Track what block types we're seeing
				if voxel_id != 0:  # Not air
					if not unique_block_ids.has(voxel_id):
						unique_block_ids[voxel_id] = 0
					unique_block_ids[voxel_id] += 1

				if voxel_id == WATER_TOP or voxel_id == WATER_FULL:
					# Replace with ice
					voxel_tool.set_voxel(pos, ICE)

					# Remember this position for thawing
					_frozen_water_positions.append({
						"pos": pos,
						"was_top": voxel_id == WATER_TOP
					})
	
	print("[WinterIceSystem] Scanned ", blocks_scanned, " blocks")
	print("[WinterIceSystem] Found block types (non-air): ", unique_block_ids)


func _replace_ice_with_water() -> void:
	"""Scan for all ice blocks and replace with water"""
	if not _terrain:
		print("[WinterIceSystem] No terrain found!")
		return
	
	var voxel_tool = _terrain.get_voxel_tool()
	voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE
	
	# Get player position to determine loaded chunks
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("[WinterIceSystem] No player found!")
		return
	
	var player_pos = player.global_position
	var search_radius = 128  # Search within 128 blocks of player
	
	# Search in a box around player
	var min_pos = Vector3i(player_pos) - Vector3i(search_radius, 32, search_radius)
	var max_pos = Vector3i(player_pos) + Vector3i(search_radius, 32, search_radius)
	
	print("[WinterIceSystem] Scanning for ice from ", min_pos, " to ", max_pos)
	
	var ice_blocks_found = 0
	
	# Check all blocks for ice
	for x in range(min_pos.x, max_pos.x):
		for y in range(min_pos.y, max_pos.y):
			# Skip underground/caves (Y < -9) - never thaw ice there
			# Bedrock barrier is at Y=-10, so ice below Y=-9 is underground
			if y < -9:
				continue

			for z in range(min_pos.z, max_pos.z):
				var pos = Vector3i(x, y, z)
				var voxel_id = voxel_tool.get_voxel(pos)

				if voxel_id == ICE:
					# Check if there's air above (surface water) or not (full water)
					var above_pos = Vector3i(x, y + 1, z)
					var above_id = voxel_tool.get_voxel(above_pos)

					# If air above, make water_top, otherwise water_full
					if above_id == 0:  # Air
						voxel_tool.set_voxel(pos, WATER_TOP)
					else:
						voxel_tool.set_voxel(pos, WATER_FULL)

					ice_blocks_found += 1
	
	print("[WinterIceSystem] Thawed ", ice_blocks_found, " ice blocks back to water")


func is_water_frozen() -> bool:
	"""Check if water is currently frozen"""
	return _is_frozen
