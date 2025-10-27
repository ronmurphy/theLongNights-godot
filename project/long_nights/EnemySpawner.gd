extends Node

## EnemySpawner - Spawns enemies based on time of day with tier-based blood moon progression
##
## SPAWN RATES:
## - Day: 15% chance every 2 minutes (Tiers 1-2 only)
## - Night: Every 30-60 seconds (Tiers 1-3 only)
## - Blood Moon: Every 10-20 seconds (ALL unlocked tiers)
##
## TIER UNLOCKING (Blood Moon Progression):
## - 1st blood moon: Tier 1 unlocked
## - 2nd blood moon: Tier 2 unlocked
## - 3rd blood moon: Tier 3 unlocked
## - 4th blood moon: Tier 4 unlocked (Blood Moon ONLY)
## - 5th blood moon: Tier 5 unlocked (Blood Moon ONLY)
##
## Tiers 4-5 are BLOOD MOON EXCLUSIVE - only spawn during blood moons!

const GroundEntity = preload("res://blocky_game/entities/ground_entity.gd")

## Spawn settings
const DAY_SPAWN_CHANCE = 0.15  # 15% chance
const DAY_SPAWN_INTERVAL = 120.0  # Check every 2 minutes

const NIGHT_SPAWN_MIN = 30.0  # Min 30 seconds
const NIGHT_SPAWN_MAX = 60.0  # Max 60 seconds

const BLOODMOON_SPAWN_MIN = 10.0  # Min 10 seconds
const BLOODMOON_SPAWN_MAX = 20.0  # Max 20 seconds

const SPAWN_DISTANCE_MIN = 20.0  # Don't spawn too close
const SPAWN_DISTANCE_MAX = 40.0  # Don't spawn too far

## Entity data path
const ENTITIES_JSON_PATH = "res://assets/art/entities/entities.json"

## Enemy storage organized by tier
var enemies_by_tier := {
	1: [],
	2: [],
	3: [],
	4: [],
	5: []
}

## State
var spawn_timer: float = 0.0
var current_spawn_interval: float = DAY_SPAWN_INTERVAL
var is_night: bool = false
var is_bloodmoon: bool = false
var max_unlocked_tier: int = 1  # Start at tier 1


func _ready():
	# Load enemies from entities.json
	_load_enemies_from_json()

	# Connect to time signals
	TimeManager.hour_changed.connect(_on_hour_changed)
	TimeManager.bloodmoon_started.connect(_on_bloodmoon_started)
	TimeManager.bloodmoon_ended.connect(_on_bloodmoon_ended)

	# Set initial interval
	_update_spawn_interval()

	print("🎯 EnemySpawner initialized with %d enemies across %d tiers" % [_count_total_enemies(), max_unlocked_tier])


func _load_enemies_from_json():
	"""Load all enemy entities from entities.json and organize by tier"""
	var file = FileAccess.open(ENTITIES_JSON_PATH, FileAccess.READ)
	if not file:
		push_error("EnemySpawner: Failed to load entities.json")
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("EnemySpawner: Failed to parse entities.json")
		return

	var data = json.data
	if not data or not "monsters" in data:
		push_error("EnemySpawner: No 'monsters' section in entities.json")
		return

	var monsters = data["monsters"]

	# Filter enemies by type:"enemy" and organize by tier
	for enemy_key in monsters.keys():
		var enemy_data = monsters[enemy_key]

		# Only include enemies (not companions, bosses, or friendly entities)
		if enemy_data.get("type") == "enemy":
			var tier = int(enemy_data.get("tier", 1))  # Convert to int

			# Store enemy key for spawning
			if tier >= 1 and tier <= 5:
				enemies_by_tier[tier].append(enemy_key)

	# Log what we loaded
	for tier in range(1, 6):
		print("EnemySpawner: Tier %d - %d enemies: %s" % [tier, enemies_by_tier[tier].size(), enemies_by_tier[tier]])


func _count_total_enemies() -> int:
	var total = 0
	for tier in enemies_by_tier.values():
		total += tier.size()
	return total


func _process(delta: float):
	spawn_timer += delta

	if spawn_timer >= current_spawn_interval:
		spawn_timer = 0.0
		_try_spawn_enemy()


func _try_spawn_enemy():
	"""Attempt to spawn an enemy based on current conditions"""
	# Day spawning has a chance check
	if not is_night and not is_bloodmoon:
		if randf() > DAY_SPAWN_CHANCE:
			return  # 85% of the time, don't spawn during day

	# Find player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Pick random spawn position around player
	var spawn_pos = _get_random_spawn_position(player.global_position)
	if spawn_pos == Vector3.ZERO:
		return  # Failed to find valid position

	# Pick enemy type based on unlocked tiers
	var enemy_key = _pick_enemy_from_unlocked_tiers()
	if enemy_key == "":
		return

	# Spawn the enemy
	_spawn_enemy(enemy_key, spawn_pos)


func _get_random_spawn_position(player_pos: Vector3) -> Vector3:
	"""Get a random position around the player on the ground"""
	var angle = randf() * TAU
	var distance = randf_range(SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)

	var offset = Vector3(
		cos(angle) * distance,
		5.0,  # Start above ground
		sin(angle) * distance
	)

	return player_pos + offset


func _pick_enemy_from_unlocked_tiers() -> String:
	"""Pick an enemy from unlocked tiers based on time of day"""
	# Determine max tier based on time of day
	var max_tier_for_time: int

	if is_bloodmoon:
		# Blood moon: All unlocked tiers (1 to max_unlocked_tier)
		max_tier_for_time = max_unlocked_tier
	elif is_night:
		# Night: Up to tier 3 (but capped by unlocked tiers)
		max_tier_for_time = min(3, max_unlocked_tier)
	else:
		# Day: Only tiers 1-2 (but capped by unlocked tiers)
		max_tier_for_time = min(2, max_unlocked_tier)

	# Build pool of enemies from available tiers
	var available_enemies := []

	for tier in range(1, max_tier_for_time + 1):
		if tier in enemies_by_tier:
			available_enemies.append_array(enemies_by_tier[tier])

	# If no enemies available (shouldn't happen), return empty
	if available_enemies.is_empty():
		push_warning("EnemySpawner: No enemies available for tiers 1-%d" % max_tier_for_time)
		return ""

	# Pick random enemy from pool
	return available_enemies[randi() % available_enemies.size()]


func _spawn_enemy(enemy_key: String, spawn_pos: Vector3):
	"""Spawn an enemy at the given position"""
	# Generate scene path from enemy key
	var scene_path = "res://blocky_game/entities/%s.tscn" % enemy_key

	# Check if scene exists, if not warn and skip
	if not ResourceLoader.exists(scene_path):
		push_warning("EnemySpawner: Scene not found for %s at %s" % [enemy_key, scene_path])
		return

	var entity_scene = load(scene_path)
	if not entity_scene:
		push_error("EnemySpawner: Failed to load scene: " + scene_path)
		return

	var entity = entity_scene.instantiate()

	# Add to game world
	var game = get_node_or_null("/root/Main/Game")
	if not game:
		push_error("EnemySpawner: Could not find game node")
		entity.queue_free()
		return

	game.add_child(entity)

	# Find ground position for ground entities
	if entity is GroundEntity:
		entity.global_position = entity.find_ground_position(spawn_pos, 15.0)
	else:
		# Flying entities spawn in air
		entity.global_position = spawn_pos

	var time_desc = "day"
	if is_bloodmoon:
		time_desc = "BLOOD MOON (Tier %d)" % max_unlocked_tier
	elif is_night:
		time_desc = "night"

	print("🎯 Spawned %s during %s at %s" % [enemy_key, time_desc, entity.global_position])


func _update_spawn_interval():
	"""Update spawn interval based on time of day"""
	if is_bloodmoon:
		current_spawn_interval = randf_range(BLOODMOON_SPAWN_MIN, BLOODMOON_SPAWN_MAX)
	elif is_night:
		current_spawn_interval = randf_range(NIGHT_SPAWN_MIN, NIGHT_SPAWN_MAX)
	else:
		current_spawn_interval = DAY_SPAWN_INTERVAL


func _on_hour_changed(hour: int):
	"""Called when the hour changes"""
	# Night is 18:00 (6pm) to 06:00 (6am)
	var was_night = is_night
	is_night = (hour >= 18 or hour < 6)

	if is_night != was_night:
		_update_spawn_interval()
		if is_night:
			var night_max_tier = min(3, max_unlocked_tier)
			print("🌙 Night falls - enemies become more active (spawning from tiers 1-%d)" % night_max_tier)
		else:
			var day_max_tier = min(2, max_unlocked_tier)
			print("☀️ Day breaks - weaker enemies spawn (tiers 1-%d only)" % day_max_tier)


func _on_bloodmoon_started():
	"""Called when blood moon starts"""
	is_bloodmoon = true

	# Increment blood moon count in WorldManager
	WorldManager.increment_blood_moon_count()
	var blood_moon_count = WorldManager.get_blood_moon_count()

	# Unlock next tier (capped at tier 5)
	max_unlocked_tier = min(blood_moon_count, 5)

	_update_spawn_interval()

	print("🩸 BLOOD MOON #%d - Tier %d UNLOCKED! Enemy spawning intensifies!" % [blood_moon_count, max_unlocked_tier])

	# Show which enemies are now available
	var available_count = 0
	for tier in range(1, max_unlocked_tier + 1):
		available_count += enemies_by_tier[tier].size()
	print("   Available enemies: %d across tiers 1-%d" % [available_count, max_unlocked_tier])


func _on_bloodmoon_ended():
	"""Called when blood moon ends"""
	is_bloodmoon = false
	_update_spawn_interval()
	print("✅ Blood moon ended - Spawn rate returns to normal (Tier %d still unlocked)" % max_unlocked_tier)
