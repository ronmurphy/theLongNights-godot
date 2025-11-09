extends Node

# UndervoidEntryDetector - Monitors player depth and triggers structure generation
# When player first enters Y <= -150, spawn Undervoid structures throughout the depths

@onready var _registry = null  # Will be set to UndervoidRegistry
@onready var _spawner = null  # Will be set to UndervoidSpawner

var _check_timer := 0.0
const CHECK_INTERVAL := 1.0  # Check player depth every second


func _ready():
	print("🟣 UndervoidEntryDetector ready")


func initialize(registry, spawner):
	"""Initialize with required dependencies"""
	_registry = registry
	_spawner = spawner
	print("🟣 UndervoidEntryDetector initialized")


func _process(delta: float):
	_check_timer += delta

	if _check_timer >= CHECK_INTERVAL:
		_check_timer = 0.0
		_check_player_depth()


func _check_player_depth():
	"""Check if player has entered the Undervoid for the first time"""
	# Skip if structures already generated
	if _registry and _registry.are_structures_generated():
		return

	# Find player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Check if player is in Undervoid (Y <= -150)
	if player.global_position.y <= -150.0:
		# First time entry!
		if _registry and not _registry.has_entered_undervoid():
			_registry.set_entered_undervoid(true)
			_trigger_structure_generation(player.global_position)


func _trigger_structure_generation(player_position: Vector3):
	"""Generate 3-5 Undervoid structures when player first enters"""
	if _registry == null or _spawner == null:
		push_error("UndervoidEntryDetector: Cannot generate structures - missing dependencies")
		return

	print("🟣 ========================================")
	print("🟣 FIRST UNDERVOID ENTRY DETECTED!")
	print("🟣 Generating structures throughout the depths...")
	print("🟣 ========================================")

	# Mark as generated to prevent duplicate spawning
	_registry.set_structures_generated(true)

	# Generate 3-5 structures at various depths
	var num_structures = randi_range(3, 5)

	# Define depth zones
	var depth_zones = [
		-175,  # Shallow Undervoid
		-225,  # Mid Undead Crypts
		-275,  # Deep Undead Crypts
		-325,  # Mechanical Warrens
		-475   # Deep near rust hills
	]

	# Shuffle zones for variety
	depth_zones.shuffle()

	# Generate structures
	for i in range(num_structures):
		var target_depth = depth_zones[i]

		# Random horizontal position (spread out around player)
		var angle = randf() * TAU
		var distance = randf_range(50.0, 150.0)  # 50-150 blocks away

		var spawn_x = player_position.x + cos(angle) * distance
		var spawn_z = player_position.z + sin(angle) * distance
		var spawn_pos = Vector3(spawn_x, target_depth, spawn_z)

		# Spawn structure at this position
		print("🟣 Spawning structure #", i + 1, " at depth Y ", target_depth)
		await _spawner.spawn_structure_at(spawn_pos, target_depth)

		# Small delay between spawns to avoid lag spike
		await get_tree().create_timer(0.5).timeout

	print("🟣 ========================================")
	print("🟣 Generated ", num_structures, " Undervoid structures!")
	print("🟣 Follow the purple beacons to find them...")
	print("🟣 ========================================")
