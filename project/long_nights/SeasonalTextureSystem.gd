extends Node
## SeasonalTextureSystem - Manages dynamic seasonal texture swapping
## Modifies terrain.png texture in memory and updates terrain chunks
## Simple approach: blit seasonal tiles into terrain.png, then update terrain

# Paths
const SEASONAL_CONFIG_PATH = "res://blocky_game/blocks/seasonal_textures.json"
const TERRAIN_TEXTURE_PATH = "res://blocky_game/blocks/terrain.png"
const SEASONAL_ATLAS_PATH = "res://blocky_game/blocks/%s.png"  # spring/summer/autumn/winter

# Season names (must match TimeManager)
const SEASONS = ["spring", "summer", "autumn", "winter"]
const TILE_SIZE = 16  # Each tile is 16x16 pixels

# State
var _seasonal_mapping: Dictionary = {}  # Block name -> {terrain: [x,y], spring: [x,y], ...}
var _seasonal_atlases: Dictionary = {}  # {spring: Image, summer: Image, ...}
var _current_season: String = ""
var _terrain_image: Image = null  # The actual terrain.png image we modify
var _terrain_material: StandardMaterial3D = null  # Reference to terrain material
var _foliage_material: StandardMaterial3D = null  # Reference to foliage material
var _foliage_wind_material: Material = null  # Reference to foliage_wind material (can be ShaderMaterial or StandardMaterial3D)
var _current_terrain_texture: ImageTexture = null  # Keep reference to current texture

func _ready() -> void:
	# Load the seasonal mapping JSON
	_load_seasonal_mapping()

	# Pre-load all 4 seasonal atlases and convert to match terrain format
	_preload_seasonal_atlases()

	# Load the terrain.png image that we'll modify
	_load_terrain_image()

	# Connect to TimeManager for season changes
	_connect_to_time_manager()

	# Material finding and season application happens immediately now (companion already loaded)
	_find_terrain_material()

	# Create the ImageTexture ONCE at startup (reuse throughout game lifetime)
	_current_terrain_texture = ImageTexture.create_from_image(_terrain_image)

	# Defer season application to next frame to avoid blocking main thread
	# This allows game UI and other systems to finish initializing while we do texture work
	call_deferred("_apply_season_based_on_time")

func _process(_delta: float) -> void:
	# Connect to TimeManager on first process (after it's initialized)
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and _seasonal_atlases.size() > 0:
		_connect_to_time_manager()
		set_process(false)  # Only need to do this once

func _connect_to_time_manager() -> void:
	"""Connect to TimeManager's season_changed signal"""
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and not time_manager.season_changed.is_connected(_on_season_changed):
		time_manager.season_changed.connect(_on_season_changed)


func _load_seasonal_mapping() -> void:
	"""Load the JSON mapping file that defines seasonal texture swaps"""
	var file = FileAccess.open(SEASONAL_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to load seasonal mapping from %s" % SEASONAL_CONFIG_PATH)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		push_error("Failed to parse seasonal mapping JSON: %s" % json.get_error_message())
		return

	_seasonal_mapping = json.data


func _preload_seasonal_atlases() -> void:
	"""Pre-load all 4 seasonal atlases and decompress them for editing"""
	for season in SEASONS:
		var atlas_path = SEASONAL_ATLAS_PATH % season
		var texture = load(atlas_path)

		if not texture or not (texture is Texture2D):
			push_error("SeasonalTextureSystem: Failed to load seasonal atlas: %s" % atlas_path)
			continue

		# Convert texture to image
		var image = texture.get_image()
		if image == null:
			push_error("SeasonalTextureSystem: Failed to get image from seasonal atlas: %s" % season)
			continue

		# Decompress the image if it's compressed
		if image.is_compressed():
			image.decompress()

		_seasonal_atlases[season] = image


func _load_terrain_image() -> void:
	"""Load the terrain.png texture that we'll modify in memory"""
	var texture = load(TERRAIN_TEXTURE_PATH)
	if not texture or not (texture is Texture2D):
		push_error("Failed to load terrain texture: %s" % TERRAIN_TEXTURE_PATH)
		return

	# Get the image from the texture
	_terrain_image = texture.get_image()
	if _terrain_image == null:
		push_error("Failed to get image from terrain texture")
		return

	# Decompress the image if it's compressed
	if _terrain_image.is_compressed():
		_terrain_image.decompress()


func _find_terrain_material() -> void:
	"""Find all terrain materials that use terrain.png - keep original references to update in-place"""
	# Load all three materials (do NOT duplicate - we need to modify the originals that voxel library uses)
	var mat = load("res://blocky_game/blocks/terrain_material.tres")
	if mat and mat is StandardMaterial3D:
		_terrain_material = mat

	var foliage_mat = load("res://blocky_game/blocks/terrain_material_foliage.tres")
	if foliage_mat and foliage_mat is StandardMaterial3D:
		_foliage_material = foliage_mat

	var foliage_wind_mat = load("res://blocky_game/blocks/terrain_material_foliage_wind.tres")
	if foliage_wind_mat and foliage_wind_mat is ShaderMaterial:
		_foliage_wind_material = foliage_wind_mat
	elif foliage_wind_mat and foliage_wind_mat is StandardMaterial3D:
		# Fallback in case it was changed
		_foliage_wind_material = foliage_wind_mat


func _get_season_from_time() -> String:
	"""Determine the current season based on TimeManager"""
	var time_manager = get_node_or_null("/root/TimeManager")
	if not time_manager:
		return "spring"  # Default fallback

	var current_day = time_manager.current_day

	# Seasons: 3 months (90 days) per season = 360 days per year
	# Days 1-90 = Spring, Days 91-180 = Summer, Days 181-270 = Autumn, Days 271-360 = Winter
	var season_cycle_days = 90
	var season_index = ((current_day - 1) / season_cycle_days) % 4

	return SEASONS[season_index]


func _apply_season_based_on_time() -> void:
	"""Apply the appropriate season based on current in-game time"""
	var season = _get_season_from_time()
	if season != _current_season:
		apply_season(season)


func apply_season(season: String) -> void:
	"""Swap seasonal tiles in terrain.png and update terrain (ONE TIME per season)"""
	if not SEASONS.has(season):
		push_error("Invalid season: %s" % season)
		return

	if season == _current_season:
		return

	if season not in _seasonal_atlases:
		push_error("Seasonal atlas not loaded for %s" % season)
		return

	if _terrain_image == null:
		push_error("SeasonalTextureSystem: Terrain image not loaded")
		return

	# Blit seasonal tiles into terrain.png (one-time operation)
	_swap_textures_for_season(season)

	# Update the terrain to use the new texture and regenerate chunks
	_update_terrain_chunks(season)

	_current_season = season


func _swap_textures_for_season(season: String) -> void:
	"""Copy seasonal tiles from seasonal atlas to terrain.png (one-time operation)"""
	var seasonal_image = _seasonal_atlases[season]

	for block_name in _seasonal_mapping:
		var coords = _seasonal_mapping[block_name]

		# Parse coordinates [x, y]
		var x = int(coords[0])
		var y = int(coords[1])

		# Convert to pixel positions (same coordinates in both images)
		var pixel_x = x * TILE_SIZE
		var pixel_y = y * TILE_SIZE

		# Create rect for tile
		var tile_rect = Rect2i(pixel_x, pixel_y, TILE_SIZE, TILE_SIZE)

		# Validate bounds in seasonal image
		if pixel_x + TILE_SIZE > seasonal_image.get_width() or pixel_y + TILE_SIZE > seasonal_image.get_height():
			push_warning("SeasonalTextureSystem: Tile out of bounds for %s in %s" % [block_name, season])
			continue

		# Validate bounds in terrain image
		if pixel_x + TILE_SIZE > _terrain_image.get_width() or pixel_y + TILE_SIZE > _terrain_image.get_height():
			push_warning("SeasonalTextureSystem: Tile out of bounds for %s in terrain" % block_name)
			continue

		# Copy the seasonal tile to terrain using blit_rect (full replacement, not blending)
		_terrain_image.blit_rect(seasonal_image, tile_rect, Vector2i(pixel_x, pixel_y))


func _update_terrain_chunks(season: String) -> void:
	"""Force the terrain to reload and regenerate chunks with new texture"""
	var terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")
	if not terrain:
		push_error("SeasonalTextureSystem: VoxelTerrain not found")
		return

	# Update the reusable ImageTexture with the modified image data
	# This is MUCH faster than creating a new texture (no GPU memory allocation)
	_current_terrain_texture.set_image(_terrain_image)

	# Update all terrain materials with the reusable texture reference
	if _terrain_material:
		_terrain_material.albedo_texture = _current_terrain_texture

	if _foliage_material:
		_foliage_material.albedo_texture = _current_terrain_texture

	# Update ShaderMaterial (foliage_wind uses shader parameter for animated grass)
	# Only update the shader for spring/summer when animated grass is visible
	if _foliage_wind_material:
		if _foliage_wind_material is ShaderMaterial and (season == "spring" or season == "summer"):
			_foliage_wind_material.set_shader_parameter("albedo_texture", _current_terrain_texture)
		elif _foliage_wind_material is StandardMaterial3D:
			_foliage_wind_material.albedo_texture = _current_terrain_texture

	# Regenerate terrain chunks using the most efficient method
	# Only try methods that actually exist to avoid overhead
	if terrain.has_method("remesh_all"):
		# Best method: explicitly remesh everything
		terrain.remesh_all()
	elif terrain.has_method("remesh_chunks"):
		# Good fallback: remesh chunks
		terrain.remesh_chunks()
	elif terrain.has_method("update_meshes"):
		# Acceptable: update meshes
		terrain.update_meshes()
	else:
		# Last resort: material updates should trigger automatic remeshing
		pass


func _get_format_name(format: Image.Format) -> String:
	"""Convert Image.Format enum to readable name"""
	match format:
		Image.FORMAT_L8: return "L8"
		Image.FORMAT_LA8: return "LA8"
		Image.FORMAT_R8: return "R8"
		Image.FORMAT_RG8: return "RG8"
		Image.FORMAT_RGB8: return "RGB8"
		Image.FORMAT_RGBA8: return "RGBA8"
		_: return "Unknown"


func _on_season_changed(new_season: String) -> void:
	"""Signal handler for when TimeManager emits season_changed signal"""
	apply_season(new_season)


## Console command support
func apply_season_cmd(args: PackedStringArray) -> void:
	"""Console command: season <spring|summer|autumn|winter>"""
	if args.size() < 1:
		print("Usage: season <spring|summer|autumn|winter>")
		return

	var season = args[0].to_lower()
	apply_season(season)
