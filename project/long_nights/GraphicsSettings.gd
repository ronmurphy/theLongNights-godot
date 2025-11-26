extends Node

## GraphicsSettings - Central graphics quality management
## Handles loading/saving graphics profiles and applying them globally
## Accessible as autoload singleton: GraphicsSettings

const CONFIG_PATH = "user://graphics_settings.json"

# Profile definitions with all tunable parameters
var profiles := {
	"low": {
		"directional_light_shadows": false,
		"torch_light_shadows": false,
		"torch_light_enabled": false,
		"torch_light_range": 0.0,
		"particle_count": 8,
		"meteor_trail_spawn_interval": 0.15,
		"debris_count": 0,
		"debris_physics_enabled": false,
		"voxel_viewer_distance": 64,
		"camera_far_clip": 62.72,
		"foliage_cull_mode": 2,
		"transparent_cull_mode": 2,
		"voxel_viewer_requires_collisions": true,
		"voxel_viewer_requires_visuals": true,
		"grass_sway_enabled": false,
		"day_fog_start": 44.0,
		"day_fog_end": 49.0,
		"night_fog_start": 44.0,
		"night_fog_end": 49.0,
		"bloodmoon_fog_start": 44.0,
		"bloodmoon_fog_end": 49.0,
		# Post-processing
		"glow_enabled": false,
		"vignette_enabled": false,
		"adjustment_enabled": false,
	},
	"medium": {
		"directional_light_shadows": true,
		"torch_light_shadows": false,
		"torch_light_enabled": true,
		"torch_light_range": 8.0,
		"particle_count": 15,
		"meteor_trail_spawn_interval": 0.10,
		"debris_count": 15,
		"debris_physics_enabled": true,
		"voxel_viewer_distance": 144,
		"camera_far_clip": 141.12,
		"foliage_cull_mode": 2,
		"transparent_cull_mode": 2,
		"voxel_viewer_requires_collisions": true,
		"voxel_viewer_requires_visuals": true,
		"grass_sway_enabled": true,
		"day_fog_start": 136.12,
		"day_fog_end": 141.12,
		"night_fog_start": 136.12,
		"night_fog_end": 141.12,
		"bloodmoon_fog_start": 136.12,
		"bloodmoon_fog_end": 141.12,
		# Post-processing
		"glow_enabled": false,
		"vignette_enabled": true,
		"adjustment_enabled": true,
	},
	"high": {
		"directional_light_shadows": true,
		"torch_light_shadows": true,
		"torch_light_enabled": true,
		"torch_light_range": 12.0,
		"particle_count": 20,
		"meteor_trail_spawn_interval": 0.05,
		"debris_count": 30,
		"debris_physics_enabled": true,
		"voxel_viewer_distance": 160,
		"camera_far_clip": 156.8,
		"foliage_cull_mode": 2,
		"transparent_cull_mode": 2,
		"voxel_viewer_requires_collisions": true,
		"voxel_viewer_requires_visuals": true,
		"grass_sway_enabled": true,
		"day_fog_start": 151.8,
		"day_fog_end": 156.8,
		"night_fog_start": 151.8,
		"night_fog_end": 156.8,
		"bloodmoon_fog_start": 151.8,
		"bloodmoon_fog_end": 156.8,
		# Post-processing
		"glow_enabled": true,
		"vignette_enabled": true,
		"adjustment_enabled": true,
	},
	"cinematic": {
		"directional_light_shadows": true,
		"torch_light_shadows": true,
		"torch_light_enabled": true,
		"torch_light_range": 16.0,
		"particle_count": 40,
		"meteor_trail_spawn_interval": 0.02,
		"debris_count": 50,
		"debris_physics_enabled": true,
		"voxel_viewer_distance": 192,
		"camera_far_clip": 188.16,
		"foliage_cull_mode": 0, # Disabled culling
		"transparent_cull_mode": 0,
		"voxel_viewer_requires_collisions": true,
		"voxel_viewer_requires_visuals": true,
		"grass_sway_enabled": true,
		"day_fog_start": 183.16,
		"day_fog_end": 188.16,
		"night_fog_start": 183.16,
		"night_fog_end": 188.16,
		"bloodmoon_fog_start": 183.16,
		"bloodmoon_fog_end": 188.16,
		# Post-processing
		"glow_enabled": true,
		"vignette_enabled": true,
		"adjustment_enabled": true,
	}
}

# Global fog setting (applies to all profiles)
var fog_enabled: bool = true

# Global visual polish setting (allows cheap effects on lower profiles)
var visual_polish_enabled: bool = true

# Resolution and window settings
var window_resolution: Vector2i = Vector2i(1920, 1080)
var fullscreen_enabled: bool = false
var vsync_enabled: bool = true

# Common resolution presets
var resolution_presets := {
	"1280x720": Vector2i(1280, 720),
	"1920x1080": Vector2i(1920, 1080),
	"2560x1440": Vector2i(2560, 1440),
	"3840x2160": Vector2i(3840, 2160)
}

# Current active profile
var current_profile: String = "medium"
var current_settings: Dictionary = {}

signal settings_changed(profile_name: String)
signal settings_applied(settings: Dictionary)
signal resolution_changed(resolution: Vector2i)

func _ready() -> void:
	load_settings()
	apply_resolution()  # Apply resolution before profile
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
			
			if data.has("visual_polish_enabled"):
				visual_polish_enabled = data["visual_polish_enabled"]
				print("[GraphicsSettings] Loaded visual_polish_enabled: ", visual_polish_enabled)
			
			# Load resolution settings
			if data.has("resolution"):
				var res = data["resolution"]
				if res is Array and res.size() == 2:
					window_resolution = Vector2i(res[0], res[1])
					print("[GraphicsSettings] Loaded resolution: ", window_resolution)
			
			if data.has("fullscreen"):
				fullscreen_enabled = data["fullscreen"]
				print("[GraphicsSettings] Loaded fullscreen: ", fullscreen_enabled)
			
			if data.has("vsync"):
				vsync_enabled = data["vsync"]
				print("[GraphicsSettings] Loaded vsync: ", vsync_enabled)
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
		"visual_polish_enabled": visual_polish_enabled,
		"resolution": [window_resolution.x, window_resolution.y],
		"fullscreen": fullscreen_enabled,
		"vsync": vsync_enabled,
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
	_apply_environment_quality()
	_apply_post_processing()

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

## Check if grass sway is enabled for current quality
func is_grass_sway_enabled() -> bool:
	return current_settings.get("grass_sway_enabled", false)

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

func _apply_environment_quality() -> void:
	# Enable/disable SDFGI based on profile
	# SDFGI = expensive global illumination (10-20+ fps cost on laptops)
	var world_env = get_tree().root.find_child("WorldEnvironment", true, false)
	if world_env and world_env.environment:
		var enable_sdfgi = current_profile == "high" or current_profile == "cinematic"
		world_env.environment.sdfgi_enabled = enable_sdfgi
		world_env.environment.sdfgi_use_occlusion = enable_sdfgi
		print("[GraphicsSettings] SDFGI: ", "ENABLED" if enable_sdfgi else "DISABLED", " (profile: ", current_profile, ")")
	else:
		print("[GraphicsSettings] Warning: WorldEnvironment not found in scene tree")

## Call this from effect scripts to check if they should create lights
func should_create_torch_light() -> bool:
	return current_settings.get("torch_light_enabled", false)

func get_torch_light_range() -> float:
	return current_settings.get("torch_light_range", 0.0)

func should_enable_torch_shadows() -> bool:
	return current_settings.get("torch_light_shadows", false)

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

## Resolution and window settings
func set_resolution(resolution: Vector2i) -> void:
	window_resolution = resolution
	apply_resolution()
	save_settings()
	resolution_changed.emit(resolution)

func set_fullscreen(enabled: bool) -> void:
	fullscreen_enabled = enabled
	apply_resolution()
	save_settings()

func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	save_settings()
	print("[GraphicsSettings] VSync: ", "ENABLED" if enabled else "DISABLED")

func apply_resolution() -> void:
	# Skip resolution changes when running in editor (embedded window)
	if OS.has_feature("editor"):
		print("[GraphicsSettings] Running in editor - resolution changes disabled")
		print("[GraphicsSettings] Resolution will apply when running exported game")
		# Still apply VSync since that works in editor
		if vsync_enabled:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		else:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		return
	
	# Set window mode first
	if fullscreen_enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(window_resolution)
		# Center window on screen
		var screen_size = DisplayServer.screen_get_size()
		var window_pos = (screen_size - window_resolution) / 2
		DisplayServer.window_set_position(window_pos)
	
	# Apply VSync
	if vsync_enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	print("[GraphicsSettings] Resolution: ", window_resolution, " | Fullscreen: ", fullscreen_enabled, " | VSync: ", vsync_enabled)

func get_resolution() -> Vector2i:
	return window_resolution

func is_fullscreen() -> bool:
	return fullscreen_enabled

func is_vsync_enabled() -> bool:
	return vsync_enabled

func get_resolution_presets() -> Dictionary:
	return resolution_presets

## Visual Polish Control
func set_visual_polish_enabled(enabled: bool) -> void:
	visual_polish_enabled = enabled
	_apply_post_processing()
	save_settings()
	print("[GraphicsSettings] Visual Polish: ", "ENABLED" if enabled else "DISABLED")

func get_visual_polish_enabled() -> bool:
	return visual_polish_enabled

func toggle_visual_polish() -> bool:
	visual_polish_enabled = !visual_polish_enabled
	_apply_post_processing()
	save_settings()
	print("[GraphicsSettings] Visual Polish toggled: ", "ON" if visual_polish_enabled else "OFF")
	return visual_polish_enabled

func _apply_post_processing() -> void:
	var world_env = get_tree().root.find_child("WorldEnvironment", true, false)
	if world_env and world_env.environment:
		var env = world_env.environment
		
		# Glow (Expensive) - Controlled by profile
		var enable_glow = current_settings.get("glow_enabled", false)
		env.glow_enabled = enable_glow
		
		# Visual Polish (Cheap) - Controlled by global toggle
		# This allows low-end machines to have "pop" without expensive lighting
		env.adjustment_enabled = visual_polish_enabled
		if visual_polish_enabled:
			env.adjustment_saturation = 1.15
			env.adjustment_contrast = 1.05
		
		# Vignette
		# Try to set intensity if property exists (Godot 4.x)
		if "vignette_enabled" in env:
			env.vignette_enabled = visual_polish_enabled
		
		if "vignette_intensity" in env:
			env.vignette_intensity = 0.25 if visual_polish_enabled else 0.0
			
		print("[GraphicsSettings] Post-Process: Glow=", enable_glow, " | Polish=", visual_polish_enabled)
	else:
		print("[GraphicsSettings] Warning: WorldEnvironment not found for post-processing")

