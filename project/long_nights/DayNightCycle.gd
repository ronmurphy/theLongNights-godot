extends Node
## DayNightCycle - Manages sun/moon rotation and sky visuals
## Integrates with TimeManager for The Long Nights

@export var sun_light: DirectionalLight3D
@export var environment: WorldEnvironment

# Sky colors for different times
var sky_colors = {
	"night": Color(0.05, 0.05, 0.15),      # Dark blue
	"dawn": Color(0.8, 0.5, 0.4),          # Orange/pink
	"day": Color(0.53, 0.81, 0.92),        # Sky blue
	"dusk": Color(0.9, 0.6, 0.3),          # Orange
	"bloodmoon": Color(0.3, 0.0, 0.0)      # Dark red
}

# Light colors
var light_colors = {
	"night": Color(0.3, 0.3, 0.5),         # Moonlight (blue tint)
	"day": Color(1.0, 0.95, 0.9),          # Sunlight (warm)
	"bloodmoon": Color(1.0, 0.2, 0.2)      # Red light
}

var is_bloodmoon: bool = false
var _is_underground: bool = false
var _player: Node = null
const UNDERGROUND_Y_THRESHOLD = -10.0  # Below this Y = underground
const UNDERGROUND_TIME_HOUR = 20  # Lock to 8pm (dark) when underground

func _ready() -> void:
	if not sun_light:
		push_error("DayNightCycle: No sun_light assigned!")
		return

	if not environment:
		push_warning("DayNightCycle: No environment assigned - fog will not update!")

	# Connect to TimeManager signals
	TimeManager.hour_changed.connect(_on_hour_changed)
	TimeManager.bloodmoon_started.connect(_on_bloodmoon_started)
	TimeManager.bloodmoon_ended.connect(_on_bloodmoon_ended)

	# Set initial time
	_update_sun_position(TimeManager.current_hour)
	_update_lighting(TimeManager.current_hour)
	_update_fog(TimeManager.current_hour)

	print("DayNightCycle: Ready")


func _process(_delta: float) -> void:
	"""Check if player is underground and override time visuals"""
	# Find player if we don't have them
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return

	# Check if player crossed underground threshold
	var was_underground = _is_underground
	_is_underground = _player.global_position.y < UNDERGROUND_Y_THRESHOLD

	# If underground status changed, update visuals immediately
	if _is_underground != was_underground:
		var display_hour = UNDERGROUND_TIME_HOUR if _is_underground else TimeManager.current_hour
		_update_sun_position(display_hour)
		if not is_bloodmoon:
			_update_lighting(display_hour)
		_update_fog(display_hour)

		if _is_underground:
			print("DayNightCycle: Player entered underground - locking to night visuals")
		else:
			print("DayNightCycle: Player exited underground - returning to actual time")


func _on_hour_changed(hour: int) -> void:
	# If underground, use locked time instead of actual time
	var display_hour = UNDERGROUND_TIME_HOUR if _is_underground else hour

	_update_sun_position(display_hour)
	if not is_bloodmoon:
		_update_lighting(display_hour)
	_update_fog(display_hour)

func _update_sun_position(hour: int) -> void:
	# Sun rotates 360 degrees over 24 hours
	# Hour 6 (6am) = sunrise (sun at horizon, east)
	# Hour 12 (noon) = sun overhead
	# Hour 18 (6pm) = sunset (sun at horizon, west)
	# Hour 0 (midnight) = moon overhead

	# Convert hour to rotation (0-24 hours -> 0-360 degrees)
	var hour_fraction = float(hour) / 24.0
	var rotation_radians = hour_fraction * TAU  # TAU = 2π = full circle

	# Offset so that hour 6 (dawn) starts with sun rising
	rotation_radians += PI * 0.75  # Offset to align with 6am = sunrise

	# Rotate sun around X axis (makes it rise and set)
	sun_light.rotation.x = rotation_radians

	# Adjust intensity based on time
	if hour >= 6 and hour < 18:  # Daytime (6am to 6pm)
		sun_light.light_energy = 1.0
	elif hour >= 5 and hour < 6:  # Dawn transition
		sun_light.light_energy = 0.5
	elif hour >= 18 and hour < 19:  # Dusk transition
		sun_light.light_energy = 0.5
	else:  # Nighttime
		sun_light.light_energy = 0.3

func _update_lighting(hour: int) -> void:
	var target_color: Color
	var target_sky: Color

	# Determine time of day
	if hour >= 5 and hour < 7:  # Dawn (5am-7am)
		target_color = light_colors["day"]
		target_sky = sky_colors["dawn"]
	elif hour >= 7 and hour < 17:  # Day (7am-5pm)
		target_color = light_colors["day"]
		target_sky = sky_colors["day"]
	elif hour >= 17 and hour < 19:  # Dusk (5pm-7pm)
		target_color = light_colors["day"]
		target_sky = sky_colors["dusk"]
	else:  # Night (7pm-5am)
		target_color = light_colors["night"]
		target_sky = sky_colors["night"]

	# Apply colors
	sun_light.light_color = target_color

	# Update sky if environment exists
	if environment and environment.environment:
		# Note: Godot 4 sky system is different, would need proper sky shader
		# For now just update ambient light
		environment.environment.ambient_light_color = target_sky
		environment.environment.ambient_light_energy = 0.05  # Much lower for dark caves

func _on_bloodmoon_started() -> void:
	is_bloodmoon = true
	print("DayNightCycle: Bloodmoon visuals active")

	# Red sky and lighting
	sun_light.light_color = light_colors["bloodmoon"]
	sun_light.light_energy = 0.5

	if environment and environment.environment:
		environment.environment.ambient_light_color = sky_colors["bloodmoon"]
		environment.environment.ambient_light_energy = 0.03  # Even darker for bloodmoon caves

	# Update fog for bloodmoon
	_update_fog_bloodmoon()

func _on_bloodmoon_ended() -> void:
	is_bloodmoon = false
	print("DayNightCycle: Bloodmoon visuals ended")

	# Return to normal
	_update_lighting(TimeManager.current_hour)
	_update_sun_position(TimeManager.current_hour)

## Get time of day as string for UI/debugging
func get_time_of_day_name() -> String:
	var hour = TimeManager.current_hour
	if hour >= 5 and hour < 12:
		return "Morning"
	elif hour >= 12 and hour < 17:
		return "Afternoon"
	elif hour >= 17 and hour < 21:
		return "Evening"
	else:
		return "Night"

## Update fog based on time of day
func _update_fog(hour: int) -> void:
	if not GraphicsSettings.get_fog_enabled():
		return

	if not environment or not environment.environment:
		return

	var fog_color: Color

	# Determine fog based on time of day
	if hour >= 6 and hour < 18:  # Daytime (6am-6pm)
		fog_color = Color(0.7, 0.7, 0.7)  # Light gray fog
	else:  # Nighttime
		fog_color = Color(0.1, 0.1, 0.15)  # Dark blue fog

	# Apply fog settings
	environment.environment.fog_enabled = true
	environment.environment.fog_aerial_perspective = 0.5  # Increased for better visibility
	environment.environment.fog_light_color = fog_color

	# Set density based on time of day to obscure view distance edge
	# Higher density = thicker fog that obscures more
	if hour >= 6 and hour < 18:  # Day
		environment.environment.fog_density = 0.01  # Light but visible fog
	else:  # Night
		environment.environment.fog_density = 0.02  # Thicker for night mystery

	print("[DayNightCycle] Fog updated - Hour: ", hour, " Density: ", environment.environment.fog_density)

## Update fog for bloodmoon (special red-tinted horror fog)
func _update_fog_bloodmoon() -> void:
	if not GraphicsSettings.get_fog_enabled():
		return

	if not environment or not environment.environment:
		return

	# Bloodmoon fog: dark crimson/blood red
	var bloodmoon_color = Color(0.5, 0.0, 0.0)  # Deep red

	environment.environment.fog_enabled = true
	environment.environment.fog_aerial_perspective = 0.25  # Extra aerial perspective for horror
	environment.environment.fog_light_color = bloodmoon_color
	environment.environment.fog_density = 0.025  # Significantly thicker for bloodmoon horror

	print("[DayNightCycle] Bloodmoon fog activated - Deep red horror atmosphere")
