extends Node

## EnemySpawner - Spawns enemies based on time of day with tier-based week progression
##
## SPAWN RATES:
## - Day: 15% chance every 2 minutes
## - Night: Every 30-60 seconds
## - Blood Moon: Every 10-20 seconds (extra intense)
## - Undervoid Areas: 2x spawn rate multiplier
##
## TIER UNLOCKING (Week Progression):
## - Week 1: Tier 1 only
## - Week 2: Tiers 1-2 (mixed)
## - Week 3: Tiers 1-3 (mixed)
## - Week 4: Tiers 1-4 (mixed)
## - Week 5+: Tiers 1-5 (mixed)
##
## Enemies spawn at any Y height based on unlocked tiers!

const GroundEntity = preload("res://blocky_game/entities/ground_entity.gd")

## Spawn settings
const DAY_SPAWN_CHANCE = 0.15  # 15% chance
const DAY_SPAWN_INTERVAL = 120.0  # Check every 2 minutes

const NIGHT_SPAWN_MIN = 30.0  # Min 30 seconds
const NIGHT_SPAWN_MAX = 60.0  # Max 60 seconds

const BLOODMOON_SPAWN_MIN = 10.0  # Min 10 seconds
const BLOODMOON_SPAWN_MAX = 20.0  # Max 20 seconds

const CAVE_SPAWN_MIN = 45.0  # Min 45 seconds in caves
const CAVE_SPAWN_MAX = 90.0  # Max 90 seconds in caves

const SPAWN_DISTANCE_MIN = 20.0  # Don't spawn too close
const SPAWN_DISTANCE_MAX = 40.0  # Don't spawn too far

## Undervoid spawn multiplier
const UNDERVOID_PROXIMITY_RADIUS = 50.0  # Within 50 blocks of structure
const UNDERVOID_SPAWN_MULTIPLIER = 2.0  # 2x spawn rate

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

## Depth-based cave biome definitions
## Matches the biome layers from generator.gd
const BIOME_GOBLIN_TUNNELS_MIN = -150  # Y=-10 to -150
const BIOME_UNDEAD_CRYPTS_MIN = -300   # Y=-150 to -300
const BIOME_MECHANICAL_MIN = -400       # Y=-300 to -400
const BIOME_ABYSS_MIN = -512           # Y=-400 to -512

## Preferred enemies for each depth biome (by enemy key)
## These are suggestions - if scene doesn't exist, falls back to tier-based
var goblin_biome_enemies := ["goblin_grunt", "goblin_bomb_bard", "goblin_shaman", "troglodyte"]
var undead_biome_enemies := ["zombie_crawler", "zombie_brute", "skeleton_archer", "skeleton_mage", "wraith"]
var mechanical_biome_enemies := ["mechanical_spider", "hunting_construct", "iron_golem", "rust_golem"]
var abyss_biome_enemies := ["abyss_golem", "water_elemental", "kraken_spawn", "bubble_fish", "alien_hunter"]

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
	TimeManager.week_completed.connect(_on_week_completed)

	# Set initial tier based on current week
	_update_tier_from_week()

	# Set initial interval
	_update_spawn_interval()

	print("🎯 EnemySpawner initialized with %d enemies across %d tiers (Week %d)" % [_count_total_enemies(), max_unlocked_tier, TimeManager.current_week])


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
	# Check if in undervoid area for spawn rate multiplier
	var player = get_tree().get_first_node_in_group("player")
	var spawn_multiplier = 1.0
	if player:
		spawn_multiplier = _get_spawn_multiplier(player.global_position)

	spawn_timer += delta * spawn_multiplier

	if spawn_timer >= current_spawn_interval:
		spawn_timer = 0.0
		_try_spawn_enemy()


func _try_spawn_enemy():
	"""Attempt to spawn an enemy based on current conditions"""
	# Find player first to check if in caves
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Check if player is in a cave (underground, Y < -10)
	var player_y = player.global_position.y
	var is_in_cave = player_y < -10.0

	# Cave spawning overrides time-of-day spawning
	# Caves spawn less frequently than surface (every 45-90 seconds)
	if is_in_cave:
		_try_spawn_cave_enemy(player, player_y)
		# Reset timer with cave interval for next spawn
		current_spawn_interval = randf_range(CAVE_SPAWN_MIN, CAVE_SPAWN_MAX)
		return

	# Surface spawning (original logic)
	# Day spawning has a chance check
	if not is_night and not is_bloodmoon:
		if randf() > DAY_SPAWN_CHANCE:
			return  # 85% of the time, don't spawn during day

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
	"""Pick an enemy from all unlocked tiers (week-based progression)"""
	# Build pool of enemies from all available tiers (no time-of-day restrictions)
	var available_enemies := []

	for tier in range(1, max_unlocked_tier + 1):
		if tier in enemies_by_tier:
			available_enemies.append_array(enemies_by_tier[tier])

	# If no enemies available (shouldn't happen), return empty
	if available_enemies.is_empty():
		push_warning("EnemySpawner: No enemies available for tiers 1-%d" % max_unlocked_tier)
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
		var ground_pos = entity.find_ground_position(spawn_pos, 15.0)
		ground_pos.y += 3.0  # Raise by 3 blocks to prevent spawning underground
		entity.global_position = ground_pos
	else:
		# Flying entities spawn in air
		entity.global_position = spawn_pos

	# Apply blood moon stat buffs if active
	if is_bloodmoon:
		_apply_bloodmoon_buffs(entity, enemy_key)

	var time_desc = "day"
	if is_bloodmoon:
		time_desc = "BLOOD MOON (Tier %d)" % max_unlocked_tier
	elif is_night:
		time_desc = "night"

	print("🎯 Spawned %s during %s at %s" % [enemy_key, time_desc, entity.global_position])


func _update_spawn_interval():
	"""Update spawn interval based on time of day
	Note: Cave spawning uses its own interval (CAVE_SPAWN_MIN/MAX)
	which is applied dynamically in _try_spawn_enemy()"""
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
			print("🌙 Night falls - enemies become more active (tiers 1-%d)" % max_unlocked_tier)
		else:
			print("☀️ Day breaks - spawn rate slows (tiers 1-%d)" % max_unlocked_tier)


func _on_bloodmoon_started():
	"""Called when blood moon starts"""
	is_bloodmoon = true

	# Increment blood moon count in WorldManager (for tracking/achievements)
	WorldManager.increment_blood_moon_count()
	var blood_moon_count = WorldManager.get_blood_moon_count()

	_update_spawn_interval()

	print("🩸 BLOOD MOON #%d! Enemy spawning intensifies! (Tier %d unlocked from Week %d)" % [blood_moon_count, max_unlocked_tier, TimeManager.current_week])

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


func _on_week_completed():
	"""Called when a new week begins - unlock next tier"""
	_update_tier_from_week()

	var available_count = 0
	for tier in range(1, max_unlocked_tier + 1):
		available_count += enemies_by_tier[tier].size()

	print("📅 Week %d begins - Tier %d UNLOCKED! %d enemies now available" % [TimeManager.current_week, max_unlocked_tier, available_count])


func _update_tier_from_week():
	"""Update max unlocked tier based on current week"""
	# Week 1: Tier 1, Week 2: Tier 2, etc. (capped at tier 5)
	max_unlocked_tier = min(TimeManager.current_week, 5)


func _get_spawn_multiplier(position: Vector3) -> float:
	"""Get spawn rate multiplier based on location (2x in undervoid areas)"""
	# Check if near any undervoid structure
	var undervoid_registry = get_node_or_null("/root/UndervoidRegistry")
	if not undervoid_registry:
		return 1.0

	var nearest_structure = undervoid_registry.get_nearest_structure(position)
	if nearest_structure:
		var distance = position.distance_to(nearest_structure.position)
		if distance < UNDERVOID_PROXIMITY_RADIUS:
			return UNDERVOID_SPAWN_MULTIPLIER

	return 1.0


## ============================================================================
## COMBAT RUIN SPAWNING (Public API)
## ============================================================================

func spawn_enemies_at_combat_ruin(ruin_position: Vector3, ruin_size: Vector3i):
	"""Spawn enemies at a combat ruin - scaled by ruin size with tiered distribution

	Args:
	    ruin_position: Base position of the ruin
	    ruin_size: Dimensions of the ruin (x, y, z)

	Scaling:
	    - Small ruins (100 sq blocks): 3-5 enemies (mostly tier 1)
	    - Medium ruins (400 sq blocks): 8-12 enemies (tier 1-2, maybe 1 tier 3)
	    - Large ruins (900+ sq blocks): 15-25 enemies (fortress layout with tiered defense)

	Distribution:
	    - Tier 3: Center/tower areas (1 per 400 sq blocks)
	    - Tier 2: Mid-range positions (1 per 150 sq blocks)
	    - Tier 1: Perimeter/outer defenses (fill remaining count)
	"""
	# Calculate ruin area (horizontal footprint)
	var area = ruin_size.x * ruin_size.z

	# Calculate enemy count based on area
	# Base: 3-5 for ~100 sq blocks, scale up from there
	var base_count = 4  # Average starting point
	var area_multiplier = area / 100.0
	var total_count = int(base_count + (area_multiplier * 1.5))  # +1.5 enemies per 100 sq blocks
	total_count = clamp(total_count, 3, 30)  # Min 3, max 30 enemies

	# Calculate tier distribution based on area
	var tier3_count = int(area / 400.0)  # 1 tier 3 per 400 sq blocks
	var tier2_count = int(area / 150.0)  # 1 tier 2 per 150 sq blocks
	var tier1_count = total_count - tier3_count - tier2_count

	# Make sure we don't exceed total and have at least some tier 1s
	tier3_count = min(tier3_count, int(total_count * 0.2))  # Max 20% tier 3
	tier2_count = min(tier2_count, int(total_count * 0.4))  # Max 40% tier 2
	tier1_count = total_count - tier3_count - tier2_count  # Rest are tier 1

	# Cap tiers by what's unlocked
	var max_available_tier = min(3, max_unlocked_tier)
	if max_available_tier < 3:
		tier1_count += tier3_count
		tier3_count = 0
	if max_available_tier < 2:
		tier1_count += tier2_count
		tier2_count = 0

	# Check if this is a sky ruin (Y > 3000 = sky level)
	var is_sky_ruin = ruin_position.y > 3000.0
	var sky_golem_count = 0

	# If sky ruin, replace tier 3 enemies with sky golems
	if is_sky_ruin and tier3_count > 0 and max_unlocked_tier >= 3:
		sky_golem_count = tier3_count
		tier3_count = 0  # Replace all tier 3 with sky golems
		print("☁️ SKY RUIN detected at Y=%.0f! Spawning %d Sky Golems (FLYING)!" % [ruin_position.y, sky_golem_count])

	print("⚔️ Combat Ruin! Size: %dx%d (%d sq blocks) - Spawning %d enemies (SkyGolems:%d, T3:%d, T2:%d, T1:%d)" %
		[ruin_size.x, ruin_size.z, area, total_count, sky_golem_count, tier3_count, tier2_count, tier1_count])

	# Calculate ruin center for positioning
	var ruin_center = ruin_position + Vector3(ruin_size) / 2.0
	var horizontal_radius = max(ruin_size.x, ruin_size.z) / 2.0

	var spawn_index = 0

	# Spawn Sky Golems first (if sky ruin) - they patrol the center
	if sky_golem_count > 0:
		for i in range(sky_golem_count):
			var spawn_pos = _get_tiered_spawn_position(ruin_center, horizontal_radius, spawn_index, total_count, 0.3)
			spawn_pos.y += 5.0  # Start flying above the ruin
			_spawn_sky_golem(spawn_pos)
			spawn_index += 1

	# Spawn Tier 3 enemies (center/tower - innermost positions) - if not sky ruin
	for i in range(tier3_count):
		var spawn_pos = _get_tiered_spawn_position(ruin_center, horizontal_radius, spawn_index, total_count, 0.3)
		var enemy_key = _pick_enemy_by_tier(3)
		if enemy_key != "":
			_spawn_enemy(enemy_key, spawn_pos)
		spawn_index += 1

	# Spawn Tier 2 enemies (mid-range positions)
	for i in range(tier2_count):
		var spawn_pos = _get_tiered_spawn_position(ruin_center, horizontal_radius, spawn_index, total_count, 0.6)
		var enemy_key = _pick_enemy_by_tier(2)
		if enemy_key != "":
			_spawn_enemy(enemy_key, spawn_pos)
		spawn_index += 1

	# Spawn Tier 1 enemies (perimeter - outermost positions)
	for i in range(tier1_count):
		var spawn_pos = _get_tiered_spawn_position(ruin_center, horizontal_radius, spawn_index, total_count, 0.9)
		var enemy_key = _pick_enemy_by_tier(1)
		if enemy_key != "":
			_spawn_enemy(enemy_key, spawn_pos)
		spawn_index += 1


func _get_tiered_spawn_position(ruin_center: Vector3, ruin_radius: float, index: int, total: int, distance_factor: float) -> Vector3:
	"""Get spawn position based on tier (distance_factor: 0.3=center, 0.6=mid, 0.9=perimeter)"""
	# Distribute evenly around circle
	var angle = (TAU / float(total)) * float(index) + randf_range(-0.3, 0.3)  # Add slight randomness
	var distance = ruin_radius * distance_factor + randf_range(-3.0, 3.0)  # Slight variation

	var offset = Vector3(
		cos(angle) * distance,
		5.0,  # Start above ruin floor
		sin(angle) * distance
	)

	return ruin_center + offset


func _pick_enemy_by_tier(desired_tier: int) -> String:
	"""Pick a random enemy from a specific tier (excludes sky_golem - that's special!)"""
	# Cap by unlocked tiers
	var tier = min(desired_tier, max_unlocked_tier)

	# Get enemies from this tier
	if not tier in enemies_by_tier or enemies_by_tier[tier].is_empty():
		# Fall back to tier 1 if requested tier not available
		if tier == 1:
			push_warning("EnemySpawner: No tier 1 enemies available!")
			return ""
		return _pick_enemy_by_tier(1)

	var tier_enemies = enemies_by_tier[tier]

	# Filter out sky_golem (it only spawns via special logic in sky ruins)
	var available_enemies = []
	for enemy_key in tier_enemies:
		if enemy_key != "sky_golem":
			available_enemies.append(enemy_key)

	# If no enemies after filtering, fall back
	if available_enemies.is_empty():
		if tier == 1:
			push_warning("EnemySpawner: No tier 1 enemies available after filtering!")
			return ""
		return _pick_enemy_by_tier(1)

	return available_enemies[randi() % available_enemies.size()]


func _spawn_sky_golem(spawn_pos: Vector3):
	"""Spawn a sky golem (flying enemy, sky-ruin exclusive)"""
	var scene_path = "res://blocky_game/entities/sky_golem.tscn"

	if not ResourceLoader.exists(scene_path):
		push_warning("EnemySpawner: Sky Golem scene not found at %s" % scene_path)
		return

	var entity_scene = load(scene_path)
	if not entity_scene:
		push_error("EnemySpawner: Failed to load Sky Golem scene")
		return

	var entity = entity_scene.instantiate()

	# Add to game world
	var game = get_node_or_null("/root/Main/Game")
	if not game:
		push_error("EnemySpawner: Could not find game node")
		entity.queue_free()
		return

	game.add_child(entity)
	entity.global_position = spawn_pos  # Flying enemy, no ground finding needed!

	# Apply blood moon buffs if active
	if is_bloodmoon:
		_apply_bloodmoon_buffs(entity, "sky_golem")

	print("☁️ Spawned Sky Golem (FLYING) at %s" % spawn_pos)


## ============================================================================
## CAVE/DEPTH-BASED SPAWNING
## ============================================================================

func _try_spawn_cave_enemy(player: Node3D, player_y: float):
	"""Spawn enemies in caves based on depth biome"""
	# Determine which depth biome the player is in
	var biome_name = _get_depth_biome_name(player_y)
	var max_tier_for_depth = _get_max_tier_for_depth(player_y)

	# Cap by unlocked tiers
	max_tier_for_depth = min(max_tier_for_depth, max_unlocked_tier)

	# Pick an enemy appropriate for this biome
	var enemy_key = _pick_enemy_for_depth_biome(player_y, max_tier_for_depth)
	if enemy_key == "":
		return  # No suitable enemy found

	# Get spawn position (caves can be anywhere around player)
	var spawn_pos = _get_random_spawn_position(player.global_position)
	# Keep spawn at similar depth to player (within 10 blocks vertically)
	spawn_pos.y = player_y + randf_range(-10.0, 10.0)

	# Spawn the enemy
	_spawn_enemy(enemy_key, spawn_pos)

	print("🕳️ Cave spawn in %s biome (Y=%.0f, Tier≤%d): %s" % [biome_name, player_y, max_tier_for_depth, enemy_key])


func _get_depth_biome_name(y: float) -> String:
	"""Get the name of the biome based on Y depth"""
	if y > BIOME_GOBLIN_TUNNELS_MIN:
		return "Goblin Tunnels"
	elif y > BIOME_UNDEAD_CRYPTS_MIN:
		return "Undead Crypts"
	elif y > BIOME_MECHANICAL_MIN:
		return "Mechanical Warrens"
	else:
		return "The Abyss"


func _get_max_tier_for_depth(y: float) -> int:
	"""Determine max enemy tier based on depth"""
	if y > BIOME_GOBLIN_TUNNELS_MIN:
		return 2  # Goblin Tunnels: Tiers 1-2
	elif y > BIOME_UNDEAD_CRYPTS_MIN:
		return 3  # Undead Crypts: Tiers 1-3
	elif y > BIOME_MECHANICAL_MIN:
		return 4  # Mechanical Warrens: Tiers 1-4
	else:
		return 5  # The Abyss: All tiers


func _pick_enemy_for_depth_biome(y: float, max_tier: int) -> String:
	"""Pick an enemy appropriate for the depth biome"""
	var preferred_enemies := []

	# Get biome-specific enemy list
	if y > BIOME_GOBLIN_TUNNELS_MIN:
		preferred_enemies = goblin_biome_enemies
	elif y > BIOME_UNDEAD_CRYPTS_MIN:
		preferred_enemies = undead_biome_enemies
	elif y > BIOME_MECHANICAL_MIN:
		preferred_enemies = mechanical_biome_enemies
	else:
		preferred_enemies = abyss_biome_enemies

	# Try to pick a themed enemy that exists and is within tier limits
	var available_themed := []
	for enemy_key in preferred_enemies:
		# Check if scene exists
		var scene_path = "res://blocky_game/entities/%s.tscn" % enemy_key
		if ResourceLoader.exists(scene_path):
			# Check if within tier limit
			var tier = _get_enemy_tier(enemy_key)
			if tier > 0 and tier <= max_tier:
				available_themed.append(enemy_key)

	# If we have themed enemies available, use them (70% chance)
	if not available_themed.is_empty() and randf() < 0.7:
		return available_themed[randi() % available_themed.size()]

	# Otherwise, fall back to any enemy within tier range (30% chance for variety)
	var fallback_enemies := []
	for tier in range(1, max_tier + 1):
		if tier in enemies_by_tier:
			for enemy_key in enemies_by_tier[tier]:
				var scene_path = "res://blocky_game/entities/%s.tscn" % enemy_key
				if ResourceLoader.exists(scene_path):
					fallback_enemies.append(enemy_key)

	if fallback_enemies.is_empty():
		push_warning("EnemySpawner: No enemies available for depth Y=%.0f, tier≤%d" % [y, max_tier])
		return ""

	return fallback_enemies[randi() % fallback_enemies.size()]


## ============================================================================
## BLOOD MOON BUFFS
## ============================================================================

func _apply_bloodmoon_buffs(entity, enemy_key: String):
	"""Apply stat buffs to enemies during blood moon based on their tier
	Tier 1: +10% HP/Attack/Defense
	Tier 2: +20% HP/Attack/Defense
	Tier 3: +30% HP/Attack/Defense
	Tier 4: +40% HP/Attack/Defense
	Tier 5: +50% HP/Attack/Defense
	"""
	# Determine enemy tier
	var tier = _get_enemy_tier(enemy_key)
	if tier == 0:
		return  # Unknown enemy, no buff

	# Calculate buff percentage (10% per tier)
	var buff_percent = tier * 0.10

	# Apply buffs
	entity.max_hp = int(entity.max_hp * (1.0 + buff_percent))
	entity.current_hp = entity.max_hp  # Start at full HP
	entity.attack_damage = int(entity.attack_damage * (1.0 + buff_percent))
	entity.defense = int(entity.defense * (1.0 + buff_percent))

	# Mark entity as blood moon spawn for loot drops
	entity.set_meta("is_bloodmoon_spawn", true)
	entity.set_meta("spawn_y_position", entity.global_position.y)

	print("🩸 Blood Moon Buff Applied! Tier %d: +%d%% stats (%s HP:%d Atk:%d Def:%d)" %
		[tier, int(buff_percent * 100), enemy_key, entity.max_hp, entity.attack_damage, entity.defense])


func _get_enemy_tier(enemy_key: String) -> int:
	"""Get the tier of an enemy by searching through enemies_by_tier"""
	for tier in range(1, 6):
		if enemy_key in enemies_by_tier[tier]:
			return tier
	return 0  # Unknown
