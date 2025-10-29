extends Node

## GrassShaderController - Updates grass material based on graphics settings
## This is an autoload singleton that monitors graphics settings changes

var _wind_material: Material
var _static_material: Material

func _ready():
	# Load both materials
	_wind_material = load("res://blocky_game/blocks/terrain_material_foliage_wind.tres")
	_static_material = load("res://blocky_game/blocks/terrain_material_foliage.tres")
	
	# Connect to graphics settings changes
	if GraphicsSettings:
		GraphicsSettings.settings_applied.connect(_on_graphics_settings_applied)
		# Apply initial setting
		_update_grass_material()


func _on_graphics_settings_applied(settings: Dictionary) -> void:
	# Update grass material when settings change
	_update_grass_material()


func _update_grass_material() -> void:
	var enable_sway = GraphicsSettings.is_grass_sway_enabled()
	var voxel_library = load("res://blocky_game/blocks/voxel_library.tres")
	
	if not voxel_library:
		print("[GrassShaderController] Warning: Could not load voxel_library")
		return
	
	# Get the tall_grass model index by name
	var tall_grass_index = voxel_library.get_model_index_from_resource_name("tall_grass")
	
	if tall_grass_index >= 0:
		# Get the model at that index
		var tall_grass_model = voxel_library.get_model(tall_grass_index)
		
		if tall_grass_model:
			if enable_sway:
				# Use wind shader for medium/high quality
				tall_grass_model.material_override_0 = _wind_material
				print("[GrassShaderController] Using wind shader for tall_grass (quality: medium/high)")
			else:
				# Use static material for low quality
				tall_grass_model.material_override_0 = _static_material
				print("[GrassShaderController] Using static material for tall_grass (quality: low)")
		else:
			print("[GrassShaderController] Warning: Could not get tall_grass model at index ", tall_grass_index)
	else:
		print("[GrassShaderController] Warning: Could not find tall_grass model index (returned -1)")
