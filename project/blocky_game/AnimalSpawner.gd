extends Node

## AnimalSpawner - Spawns passive animals around the player
## Spawns rabbits, cats, and birds periodically

const Rabbit = preload("res://blocky_game/entities/rabbit.gd")
const Cat = preload("res://blocky_game/entities/cat.gd")
const CatGrey = preload("res://blocky_game/entities/cat_grey.gd")
const Swallow = preload("res://blocky_game/entities/swallow.gd")
const Bluejay = preload("res://blocky_game/entities/bluejay.gd")
const Fish = preload("res://blocky_game/entities/fish.gd")

## Spawn settings
const SPAWN_INTERVAL_MIN = 30.0  # Spawn every 30-60 seconds
const SPAWN_INTERVAL_MAX = 60.0
const SPAWN_DISTANCE_MIN = 15.0  # Don't spawn too close
const SPAWN_DISTANCE_MAX = 35.0  # Don't spawn too far
const MAX_ANIMALS = 15  # Max animals in world at once

## Spawn weights (chance to spawn each type)
const RABBIT_WEIGHT = 0.35  # 35% rabbits
const CAT_BLACK_WEIGHT = 0.13  # 13% black cats
const CAT_GREY_WEIGHT = 0.12  # 12% grey cats
const SWALLOW_WEIGHT = 0.13  # 13% swallows
const BLUEJAY_WEIGHT = 0.12  # 12% bluejays
const FISH_WEIGHT = 0.15  # 15% fish

var _spawn_timer: float = 0.0
var _current_spawn_interval: float = 30.0
var _active_animals := 0
var _spawned_animals: Array[Node] = []  # Track all spawned animals


func _ready():
	# Set initial random interval
	_current_spawn_interval = randf_range(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)
	print("🐰🐱🐦🐟 AnimalSpawner initialized (spawns animals every %.1f-%.1fs)" % [SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX])


func _process(delta: float):
	_spawn_timer += delta

	if _spawn_timer >= _current_spawn_interval:
		_spawn_timer = 0.0
		_current_spawn_interval = randf_range(SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)

		# Try to spawn a random animal
		_try_spawn_animal()


func _try_spawn_animal():
	"""Attempt to spawn a random animal near the player"""
	# Check if we've hit the animal limit - despawn all and start fresh
	if _active_animals >= MAX_ANIMALS:
		_despawn_all_animals()
		print("🔄 Animal limit reached - despawning all and starting fresh")

	# Find player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Randomly choose which animal to spawn based on weights
	var roll = randf()
	var animal_script = null
	var animal_name = ""
	var habitat_type = "ground"  # "ground", "flying", or "water"
	var emoji = ""

	if roll < RABBIT_WEIGHT:
		animal_script = Rabbit
		animal_name = "rabbit"
		emoji = "🐰"
		habitat_type = "ground"
	elif roll < RABBIT_WEIGHT + CAT_BLACK_WEIGHT:
		animal_script = Cat
		animal_name = "black cat"
		emoji = "🐱"
		habitat_type = "ground"
	elif roll < RABBIT_WEIGHT + CAT_BLACK_WEIGHT + CAT_GREY_WEIGHT:
		animal_script = CatGrey
		animal_name = "grey cat"
		emoji = "🐱"
		habitat_type = "ground"
	elif roll < RABBIT_WEIGHT + CAT_BLACK_WEIGHT + CAT_GREY_WEIGHT + SWALLOW_WEIGHT:
		animal_script = Swallow
		animal_name = "swallow"
		emoji = "🐦"
		habitat_type = "flying"
	elif roll < RABBIT_WEIGHT + CAT_BLACK_WEIGHT + CAT_GREY_WEIGHT + SWALLOW_WEIGHT + BLUEJAY_WEIGHT:
		animal_script = Bluejay
		animal_name = "bluejay"
		emoji = "🐦"
		habitat_type = "flying"
	else:
		animal_script = Fish
		animal_name = "fish"
		emoji = "🐟"
		habitat_type = "water"

	# Get spawn position based on animal habitat type
	var spawn_pos: Vector3
	match habitat_type:
		"flying":
			spawn_pos = _get_flying_spawn_position(player.global_position)
		"water":
			spawn_pos = _get_water_spawn_position(player.global_position)
		_:  # "ground" or default
			spawn_pos = _get_ground_spawn_position(player.global_position)

	if spawn_pos == Vector3.ZERO:
		return

	# Spawn animal
	var animal = Node3D.new()
	animal.set_script(animal_script)

	# Add to scene FIRST (so global_position works)
	var game = get_node_or_null("/root/Main/Game")
	if game:
		game.add_child(animal)
		animal.global_position = spawn_pos  # Set position AFTER adding to tree
		_active_animals += 1
		_spawned_animals.append(animal)  # Track for despawning

		# Connect to death signal to track active count
		if animal.has_signal("died"):
			animal.died.connect(_on_animal_died)

		print("%s Spawned %s at %s (total: %d)" % [emoji, animal_name, spawn_pos, _active_animals])


func _get_ground_spawn_position(player_pos: Vector3) -> Vector3:
	"""Get a valid ground spawn position around the player"""
	# Try up to 10 times to find a good spawn position
	for i in range(10):
		# Random angle around player
		var angle = randf() * TAU
		var distance = randf_range(SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)

		# Calculate position
		var offset = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var spawn_pos = player_pos + offset

		# Find ground level
		var terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")
		if terrain:
			var vt = terrain.get_voxel_tool()

			# Raycast down to find ground
			var ray_start = spawn_pos + Vector3(0, 20, 0)
			var ray_end = spawn_pos - Vector3(0, 20, 0)
			var hit = vt.raycast(ray_start, (ray_end - ray_start).normalized(), 40.0)

			if hit:
				var ground_y = Vector3(hit.position).y
				# Don't spawn ground animals in sky ruins (too high altitude)
				if ground_y > 100:
					continue
				# Found ground, spawn slightly above it
				return Vector3(hit.position) + Vector3(0, 1, 0)

	# Failed to find valid position
	return Vector3.ZERO


func _get_flying_spawn_position(player_pos: Vector3) -> Vector3:
	"""Get a flying spawn position in the air around the player"""
	# Random angle around player
	var angle = randf() * TAU
	var distance = randf_range(SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)

	# Calculate horizontal position
	var offset = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
	var spawn_pos = player_pos + offset

	# Set height in the air (15-40 blocks up for variety)
	spawn_pos.y = player_pos.y + randf_range(15.0, 40.0)

	return spawn_pos


func _get_water_spawn_position(player_pos: Vector3) -> Vector3:
	"""Get a spawn position in water around the player"""
	var terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")
	if not terrain:
		return Vector3.ZERO

	var vt = terrain.get_voxel_tool()
	vt.set_channel(VoxelBuffer.CHANNEL_TYPE)

	# Get water block info
	var blocks = get_node_or_null("/root/Main/Game/Blocks")
	if not blocks:
		return Vector3.ZERO

	var water_block = blocks.get_block_by_name("water")
	if not water_block:
		return Vector3.ZERO

	var water_voxels = water_block.base_info.voxels

	# Try up to 20 times to find a water position
	for i in range(20):
		# Random angle around player
		var angle = randf() * TAU
		var distance = randf_range(SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)

		# Calculate horizontal position
		var offset = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var test_pos = player_pos + offset

		# Search up and down for water (check 20 blocks above and below)
		for y_offset in range(-20, 20):
			var check_pos = test_pos + Vector3(0, y_offset, 0)
			var voxel_pos = check_pos.floor()
			var voxel_id = vt.get_voxel(voxel_pos)

			# Found water!
			if voxel_id in water_voxels:
				# Spawn in middle of water block
				return Vector3(voxel_pos) + Vector3(0.5, 0.5, 0.5)

	# Failed to find water
	return Vector3.ZERO


func _despawn_all_animals():
	"""Despawn all existing animals and reset the spawn cycle"""
	for animal in _spawned_animals:
		if is_instance_valid(animal):
			# Disconnect signal before freeing to avoid callback
			if animal.has_signal("died"):
				animal.died.disconnect(_on_animal_died)
			animal.queue_free()

	_spawned_animals.clear()
	_active_animals = 0


func _on_animal_died(entity):
	"""Track when animals die"""
	_active_animals = max(0, _active_animals - 1)

	# Remove from tracking array
	var index = _spawned_animals.find(entity)
	if index >= 0:
		_spawned_animals.remove_at(index)

	print("🐾 Animal died (remaining: %d)" % _active_animals)
