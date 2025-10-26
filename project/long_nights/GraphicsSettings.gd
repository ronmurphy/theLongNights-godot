extends Node

## GraphicsSettings - Central graphics quality management
## Handles loading/saving graphics profiles and applying them globally
## Accessible as autoload singleton: GraphicsSettings

const CONFIG_PATH = "user://graphics_settings.json"

# Profile definitions with all tunable parameters
var profiles := {
	"low": {
		"directional_light_shadows": false,
		"torch_light_enabled": false,
		"torch_light_range": 0.0,
		"particle_count": 8,
		"meteor_trail_spawn_interval": 0.15,  # milliseconds as float (150ms)
		"debris_count": 0,
		"debris_physics_enabled": false,
		"voxel_viewer_distance": 50,
		"camera_far_clip": 49.0,  # 50 * 0.98, just before voxel boundary
		"foliage_cull_mode": 2,  # 2 = two-sided (foliage)
		"transparent_cull_mode": 2,
		"voxel_viewer_requires_collisions": true,  # Still need collisions for player
		"voxel_viewer_requires_visuals": true,
		# Fog settings - fog starts 5 chunks before camera cutoff, fully opaque at cutoff
		"day_fog_start": 44.0,      # 5 chunks before cutoff (49 - 5)
		"day_fog_end": 49.0,        # Full opacity at camera edge
		"night_fog_start": 44.0,    # Same for night
		"night_fog_end": 49.0,
		"bloodmoon_fog_start": 44.0,  # Same for bloodmoon
		"bloodmoon_fog_end": 49.0,
	},
	"medium": {
		"directional_light_shadows": true,
		"torch_light_enabled": true,
		"torch_light_range": 8.0,
		"particle_count": 15,
		"meteor_trail_spawn_interval": 0.10,  # 100ms
		"debris_count": 15,
		"debris_physics_enabled": true,
		"voxel_viewer_distance": 112,
		"camera_far_clip": 109.8,  # 112 * 0.98
		"foliage_cull_mode": 2,
		"transparent_cull_mode": 2,
		"voxel_viewer_requires_collisions": true,
		"voxel_viewer_requires_visuals": true,
		# Fog settings - fog starts 5 chunks before camera cutoff
		"day_fog_start": 104.8,     # 5 chunks before cutoff (109.8 - 5)
		"day_fog_end": 109.8,
		"night_fog_start": 104.8,
		"night_fog_end": 109.8,
		"bloodmoon_fog_start": 104.8,
		"bloodmoon_fog_end": 109.8,
	},
	"high": {
		"directional_light_shadows": true,
		"torch_light_enabled": true,
		"torch_light_range": 12.0,
		"particle_count": 20,
		"meteor_trail_spawn_interval": 0.05,  # 50ms
		"debris_count": 30,
		"debris_physics_enabled": true,
		"voxel_viewer_distance": 128,
		"camera_far_clip": 125.4,  # 128 * 0.98
		"foliage_cull_mode": 2,
		"transparent_cull_mode": 2,
		"voxel_viewer_requires_collisions": true,
		"voxel_viewer_requires_visuals": true,
		# Fog settings - fog starts 5 chunks before camera cutoff
		"day_fog_start": 120.4,     # 5 chunks before cutoff (125.4 - 5)
		"day_fog_end": 125.4,
		"night_fog_start": 120.4,
		"night_fog_end": 125.4,
		"bloodmoon_fog_start": 120.4,
		"bloodmoon_fog_end": 125.4,
	}
}

# Global fog setting (applies to all profiles)
var fog_enabled: bool = true

# Current active profile
var current_profile: String = "medium"
var current_settings: Dictionary = {}

signal settings_changed(profile_name: String)
signal settings_applied(settings: Dictionary)

func _ready() -> void:
	load_settings()
	apply_profile(current_profile)

## Load settings from disk or initialize with defaults
func load_settings() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		var json = JSON.new()
		var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
		var error = json.parse(file.get_as_text())

		if error == OK:
			var data = json.get_data()
			if data.has("profile"):
				current_profile = data["profile"]
				print("[GraphicsSettings] Loaded profile: ", current_profile)
			else:
				print("[GraphicsSettings] No profile in config, using default: medium")

			if data.has("fog_enabled"):
				fog_enabled = data["fog_enabled"]
				print("[GraphicsSettings] Loaded fog_enabled: ", fog_enabled)
		else:
			print("[GraphicsSettings] Error parsing JSON: ", error)
	else:
		print("[GraphicsSettings] No config file found, using defaults")

	# Validate that profile exists
	if not profiles.has(current_profile):
		current_profile = "medium"
		print("[GraphicsSettings] Invalid profile, reset to: medium")

## Save current profile to disk
func save_settings() -> void:
	var config_data = {
		"profile": current_profile,
		"fog_enabled": fog_enabled,
		"timestamp": Time.get_ticks_msec()
	}

	var json_string = JSON.stringify(config_data)
	var file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)

	if file:
		file.store_string(json_string)
		print("[GraphicsSettings] Saved profile: ", current_profile)
	else:
		print("[GraphicsSettings] Failed to save settings")

## Apply a graphics profile by name
func apply_profile(profile_name: String) -> void:
	if not profiles.has(profile_name):
		print("[GraphicsSettings] Invalid profile: ", profile_name)
		return

	current_profile = profile_name
	current_settings = profiles[profile_name].duplicate()

	print("[GraphicsSettings] Applying profile: ", profile_name)
	print("  - Shadows: ", current_settings["directional_light_shadows"])
	print("  - Torch light: ", current_settings["torch_light_enabled"], " (range: ", current_settings["torch_light_range"], ")")
	print("  - Particles: ", current_settings["particle_count"])
	print("  - Debris: ", current_settings["debris_count"])
	print("  - Camera far: ", current_settings["camera_far_clip"])
	print("  - Voxel distance: ", current_settings["voxel_viewer_distance"])

	_apply_directional_light_shadows()
	_apply_camera_settings()
	_apply_voxel_viewer_distance()

	settings_changed.emit(profile_name)
	settings_applied.emit(current_settings)
	save_settings()

## Get current profile name
func get_current_profile() -> String:
	return current_profile

## Get a specific setting value
func get_setting(setting_name: String):
	return current_settings.get(setting_name)

## Check if a feature is enabled
func is_enabled(feature_name: String) -> bool:
	return current_settings.get(feature_name, false)

## Get setting with fallback
func get_setting_or(setting_name: String, default_value):
	return current_settings.get(setting_name, default_value)

# ============================================================================
# Internal: Apply settings to scene tree
# ============================================================================

func _apply_directional_light_shadows() -> void:
	var sun_light = get_tree().root.find_child("DirectionalLight3D", true, false)
	if sun_light and sun_light is DirectionalLight3D:
		sun_light.shadow_enabled = current_settings["directional_light_shadows"]
		print("[GraphicsSettings] DirectionalLight shadows: ", sun_light.shadow_enabled)
	else:
		print("[GraphicsSettings] Warning: DirectionalLight3D not found in scene tree")

func _apply_camera_settings() -> void:
	# Search for camera in multiple ways
	var camera = get_tree().root.find_child("Camera", true, false)
	if camera == null:
		camera = get_tree().root.find_child("Camera3D", true, false)

	if camera and camera is Camera3D:
		camera.far = current_settings["camera_far_clip"]
		print("[GraphicsSettings] Camera far clip: ", camera.far)
	else:
		print("[GraphicsSettings] Warning: Camera3D not found in scene tree")

func _apply_voxel_viewer_distance() -> void:
	var voxel_viewer = get_tree().root.find_child("VoxelViewer", true, false)
	if voxel_viewer:
		voxel_viewer.view_distance = current_settings["voxel_viewer_distance"]
		print("[GraphicsSettings] VoxelViewer distance: ", voxel_viewer.view_distance)
	else:
		print("[GraphicsSettings] Warning: VoxelViewer not found in scene tree")

## Call this from effect scripts to check if they should create lights
func should_create_torch_light() -> bool:
	return current_settings.get("torch_light_enabled", false)

func get_torch_light_range() -> float:
	return current_settings.get("torch_light_range", 0.0)

func get_particle_count() -> int:
	return current_settings.get("particle_count", 8)

func get_debris_count() -> int:
	return current_settings.get("debris_count", 0)

func should_enable_debris_physics() -> bool:
	return current_settings.get("debris_physics_enabled", false)

func get_meteor_trail_interval() -> float:
	return current_settings.get("meteor_trail_spawn_interval", 0.15)

## Voxel viewer settings
func should_require_voxel_collisions() -> bool:
	return current_settings.get("voxel_viewer_requires_collisions", true)

func should_require_voxel_visuals() -> bool:
	return current_settings.get("voxel_viewer_requires_visuals", true)

## Fog control
func set_fog_enabled(enabled: bool) -> void:
	fog_enabled = enabled
	save_settings()
	print("[GraphicsSettings] Fog: ", "ENABLED" if fog_enabled else "DISABLED")

func get_fog_enabled() -> bool:
	return fog_enabled

func toggle_fog() -> bool:
	fog_enabled = !fog_enabled
	save_settings()
	print("[GraphicsSettings] Fog toggled: ", "ON" if fog_enabled else "OFF")
	return fog_enabled

## Get fog settings for current time of day
func get_day_fog_start() -> float:
	return current_settings.get("day_fog_start", 250.0)

func get_day_fog_end() -> float:
	return current_settings.get("day_fog_end", 450.0)

func get_night_fog_start() -> float:
	return current_settings.get("night_fog_start", 150.0)

func get_night_fog_end() -> float:
	return current_settings.get("night_fog_end", 300.0)

func get_bloodmoon_fog_start() -> float:
	return current_settings.get("bloodmoon_fog_start", 120.0)

func get_bloodmoon_fog_end() -> float:
	return current_settings.get("bloodmoon_fog_end", 280.0)
