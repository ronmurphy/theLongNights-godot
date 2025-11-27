extends Node
## TimeManager - Handles day/night cycles and game progression
## Features: 7-day week system, 24-hour day cycle, Bloodmoon events
## Accessible globally as TimeManager autoload singleton

# Signals
signal day_changed(day: int)
signal hour_changed(hour: int)
signal bloodmoon_started
signal bloodmoon_ended
signal bloodmoon_survived  # Emitted when player survives a blood moon
signal bloodmoon_stats_changed  # Emitted when kill count changes (for UI updates)
signal week_completed
signal season_changed(season: String)

# Constants
const SECONDS_PER_IN_GAME_HOUR = 75.0  # 30 min / 24 hours = 75 seconds per hour
const HOURS_PER_DAY = 24
const DAYS_PER_WEEK = 7
const BLOODMOON_START_HOUR = 21  # 9 PM
const BLOODMOON_END_HOUR = 5     # 5 AM (near sunrise)

# State variables
var current_week: int = 1
var current_day: int = 1  # 1-7
var current_hour: int = 6  # Start at dawn
var current_minute: int = 0
var elapsed_time: float = 0.0

var is_bloodmoon: bool = false
var time_paused: bool = false

# Blood moon tracking
var bloodmoon_enemies_spawned: int = 0
var bloodmoon_enemies_killed: int = 0
var bloodmoon_start_hour: int = 0  # Hour when current blood moon started (for survival duration)

# Seasonal tracking
const SEASONS = ["spring", "summer", "autumn", "winter"]
var current_season: String = "spring"  # Start in spring

func _ready() -> void:
	print("⏰ TimeManager initialized")

func _process(delta: float) -> void:
	if time_paused:
		return

	elapsed_time += delta

	# Check if a full in-game hour has passed
	if elapsed_time >= SECONDS_PER_IN_GAME_HOUR:
		advance_hour()
		elapsed_time = 0.0

func advance_hour() -> void:
	current_hour += 1

	# Hour overflow to next day
	if current_hour >= HOURS_PER_DAY:
		current_hour = 0
		advance_day()

	# Check for bloodmoon timing
	_update_bloodmoon_state()
	hour_changed.emit(current_hour)
	print("⏰ Hour changed: %02d:00" % current_hour)

func advance_day() -> void:
	current_day += 1
	current_minute = 0

	# Day overflow to next week
	if current_day > DAYS_PER_WEEK:
		current_day = 1
		advance_week()

	# Check for season changes (every ~90 days = 3 months, rotating through 4 seasons)
	# Only recalculate every 90 days to avoid unnecessary division operations
	if current_day % 90 == 1:  # Day 1, 91, 181, 271 (season transition days)
		var season_cycle_days = 90
		var new_season = SEASONS[((current_day - 1) / season_cycle_days) % 4]
		if new_season != current_season:
			current_season = new_season
			season_changed.emit(current_season)

	day_changed.emit(current_day)

func advance_week() -> void:
	current_week += 1
	week_completed.emit()
	print("🎉 Week completed! Week %d begins" % current_week)

func _update_bloodmoon_state() -> void:
	# Blood moon spans across midnight from day 7 to day 1
	# Day 7: 9pm (hour 21) to 11pm (hour 23)
	# Day 1: midnight (hour 0) to 5am (hour 5, exclusive)
	var should_be_bloodmoon = (current_day == DAYS_PER_WEEK and
							   current_hour >= BLOODMOON_START_HOUR) or \
							  (current_day == 1 and
							   current_hour < BLOODMOON_END_HOUR)

	if should_be_bloodmoon and not is_bloodmoon:
		is_bloodmoon = true
		# Reset tracking counters
		bloodmoon_enemies_spawned = 0
		bloodmoon_enemies_killed = 0
		bloodmoon_start_hour = current_hour
		bloodmoon_started.emit()
		print("🩸 BLOODMOON STARTED!")
	elif not should_be_bloodmoon and is_bloodmoon:
		is_bloodmoon = false
		bloodmoon_ended.emit()
		
		# Check if player survived the blood moon
		var player = get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player):
			# Player is alive - they survived!
			bloodmoon_survived.emit()
			print("🎉 Player survived the blood moon! Rewards granted.")
		
		print("✅ Bloodmoon ended, survivors advance!")

## Returns formatted time string
func get_time_string() -> String:
	return "%02d:%02d" % [current_hour, current_minute]

## Returns day name
func get_day_name() -> String:
	var days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
	return days[current_day - 1] if current_day >= 1 and current_day <= 7 else "Unknown"

## Pause/resume time flow
func set_paused(paused: bool) -> void:
	time_paused = paused
	print("⏸️ Time %s" % ("paused" if paused else "resumed"))

## Get current difficulty multiplier based on week
func get_difficulty_multiplier() -> float:
	return 1.0 + ((current_week - 1) * 0.3)  # 30% harder each week

## Get total hours elapsed since game start (for ruin visit tracking)
func get_total_hours() -> int:
	var weeks_hours = (current_week - 1) * DAYS_PER_WEEK * HOURS_PER_DAY
	var days_hours = (current_day - 1) * HOURS_PER_DAY
	return weeks_hours + days_hours + current_hour


## ============================================================================
## BLOOD MOON TRACKING
## ============================================================================

func increment_bloodmoon_spawn() -> void:
	"""Called by EnemySpawner when an enemy spawns during blood moon"""
	if is_bloodmoon:
		bloodmoon_enemies_spawned += 1
		bloodmoon_stats_changed.emit()


func increment_bloodmoon_kill() -> void:
	"""Called by entity_base when a blood moon enemy dies"""
	if is_bloodmoon:
		bloodmoon_enemies_killed += 1
		bloodmoon_stats_changed.emit()


func get_bloodmoon_kill_percentage() -> float:
	"""Returns kill percentage (0.0 to 1.0) for current blood moon"""
	if bloodmoon_enemies_spawned == 0:
		return 0.0
	return float(bloodmoon_enemies_killed) / float(bloodmoon_enemies_spawned)


func get_bloodmoon_survival_hours() -> int:
	"""Returns how many hours the player has survived current blood moon"""
	if not is_bloodmoon:
		return 0

	# Calculate hours since blood moon started
	var hours_survived = current_hour - bloodmoon_start_hour

	# Handle day transition (blood moon crosses midnight)
	if hours_survived < 0:
		hours_survived += HOURS_PER_DAY

	return hours_survived


## ============================================================================
## SAVE/LOAD SYSTEM
## ============================================================================

func save_to_dict() -> Dictionary:
	"""Save time state to dictionary"""
	return {
		"current_week": current_week,
		"current_day": current_day,
		"current_hour": current_hour,
		"current_minute": current_minute,
		"current_season": current_season,
		"elapsed_time": elapsed_time
	}


func load_from_dict(data: Dictionary) -> void:
	"""Load time state from dictionary"""
	if data.has("current_week"):
		current_week = data.current_week
	if data.has("current_day"):
		current_day = data.current_day
	if data.has("current_hour"):
		current_hour = data.current_hour
	if data.has("current_minute"):
		current_minute = data.current_minute
	if data.has("current_season"):
		current_season = data.current_season
	if data.has("elapsed_time"):
		elapsed_time = data.elapsed_time

	# Update bloodmoon state based on loaded time
	_update_bloodmoon_state()

	print("⏰ TimeManager: Restored time to Week %d, Day %d (%s), %02d:%02d" % [
		current_week,
		current_day,
		get_day_name(),
		current_hour,
		current_minute
	])
