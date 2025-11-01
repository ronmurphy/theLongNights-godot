extends Node
## WinterIceSystem - Freezes water to ice in winter, thaws in other seasons
## Makes water solid and walkable during winter season

var _is_frozen: bool = false
var _terrain: VoxelTerrain = null
var _blocks = null
var _water_system = null

# Block IDs (will be set at runtime)
var _water_full_id: int = -1
var _water_top_id: int = -1

func _ready() -> void:
	# Wait for scene to load
	await get_tree().process_frame
	
	# Find terrain and blocks (correct paths for blocky_game scene)
	var game = get_tree().get_first_node_in_group("game")
	if game:
		_terrain = game.get_node_or_null("VoxelTerrain")
		_blocks = game.get_node_or_null("Blocks")
		_water_system = game.get_node_or_null("Water")
	else:
		# Fallback: try direct paths
		_terrain = get_node_or_null("/root/Main/VoxelTerrain")
		_blocks = get_node_or_null("/root/Main/Blocks")
		_water_system = get_node_or_null("/root/Main/Water")
	
	if not _terrain or not _blocks:
		push_error("WinterIceSystem: Could not find VoxelTerrain or Blocks")
		return
	
	# Get water block IDs
	var water_block = _blocks.get_block_by_name("water")
	if water_block:
		_water_full_id = water_block.base_info.voxels[0]  # water_full
		_water_top_id = water_block.base_info.voxels[1]   # water_top
	
	# Connect to season changes
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.season_changed.connect(_on_season_changed)
		
		# Apply current season state
		var current_season = time_manager.current_season
		if current_season == "winter":
			freeze_water()
		else:
			thaw_water()


func _on_season_changed(new_season: String) -> void:
	"""Handle season transitions"""
	if new_season == "winter":
		freeze_water()
	else:
		thaw_water()


func freeze_water() -> void:
	"""Convert all water to ice (make solid and stop flow)"""
	if _is_frozen:
		return  # Already frozen
	
	_is_frozen = true
	
	# Disable water flow system (stops water spreading)
	if _water_system:
		_water_system.set_process(false)
	
	# Enable collision on water voxels in voxel library
	_set_water_collision(true)
	
	# Texture change happens automatically via SeasonalTextureSystem


func thaw_water() -> void:
	"""Convert all ice back to water (make non-solid and resume flow)"""
	if not _is_frozen:
		return  # Already thawed
	
	_is_frozen = false
	
	# Re-enable water flow system
	if _water_system:
		_water_system.set_process(true)
	
	# Disable collision on water voxels in voxel library
	_set_water_collision(false)


func _set_water_collision(enabled: bool) -> void:
	"""Toggle collision on water voxel models in the voxel library"""
	if not _blocks:
		return
	
	var voxel_library = _blocks._voxel_library
	if not voxel_library:
		return
	
	# Water uses voxel IDs from generator.gd
	# WATER_TOP = 13, WATER_FULL = 14
	var water_top_voxel_id = 13
	var water_full_voxel_id = 14
	
	# Get the voxel models from library
	var water_top_model = voxel_library.get_voxel(water_top_voxel_id)
	var water_full_model = voxel_library.get_voxel(water_full_voxel_id)
	
	if water_top_model:
		if enabled:
			# Add collision box (full cube)
			water_top_model.collision_aabbs = [AABB(Vector3.ZERO, Vector3.ONE)]
			water_top_model.collision_enabled = true
		else:
			# Remove collision
			water_top_model.collision_aabbs = []
			water_top_model.collision_enabled = false
	
	if water_full_model:
		if enabled:
			# Add collision box (full cube)
			water_full_model.collision_aabbs = [AABB(Vector3.ZERO, Vector3.ONE)]
			water_full_model.collision_enabled = true
		else:
			# Remove collision
			water_full_model.collision_aabbs = []
			water_full_model.collision_enabled = false


func is_water_frozen() -> bool:
	"""Check if water is currently frozen"""
	return _is_frozen
