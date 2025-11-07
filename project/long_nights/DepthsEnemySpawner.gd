extends Node

## DepthsEnemySpawner - Spawns underground enemies in The Depths
## Spawns different enemies based on depth layer

const RustGolem = preload("res://blocky_game/entities/rust_golem.gd")

## Spawn settings
const SPAWN_CHECK_INTERVAL = 45.0  # Check every 45 seconds
const SPAWN_DISTANCE_MIN = 20.0
const SPAWN_DISTANCE_MAX = 40.0
const MAX_RUST_GOLEMS = 2  # Max in Mechanical Warrens at once

var _spawn_timer := 0.0
var _active_rust_golems := 0
var _spawned_golems: Array[Node] = []


func _ready():
	print("🦾 DepthsEnemySpawner initialized")


func _process(delta: float):
	_spawn_timer += delta

	if _spawn_timer >= SPAWN_CHECK_INTERVAL:
		_spawn_timer = 0.0
		_try_spawn_depths_enemy()


func _try_spawn_depths_enemy():
	"""Try to spawn an enemy based on player's depth"""
	# Find player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var player_y = player.global_position.y

	# MECHANICAL WARRENS (Y=-300 to -400) - Rust Golems
	if player_y < -300 and player_y > -400:
		_try_spawn_rust_golem(player.global_position)


func _try_spawn_rust_golem(player_pos: Vector3):
	"""Try to spawn a Rust Golem in the Mechanical Warrens"""
	# Check if at max capacity
	if _active_rust_golems >= MAX_RUST_GOLEMS:
		return

	# Random position in the air around player
	var angle = randf() * TAU
	var distance = randf_range(SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)

	var spawn_pos = player_pos + Vector3(
		cos(angle) * distance,
		randf_range(-10.0, 10.0),  # Vertical variation
		sin(angle) * distance
	)

	# Don't spawn if too close to player vertically
	if abs(spawn_pos.y - player_pos.y) < 5.0:
		return

	# Create Rust Golem
	var golem = Node3D.new()
	golem.set_script(RustGolem)

	# Add to game scene
	var game = get_node_or_null("/root/Main/Game")
	if not game:
		golem.queue_free()
		return

	game.add_child(golem)
	golem.global_position = spawn_pos

	# Track the golem
	_active_rust_golems += 1
	_spawned_golems.append(golem)

	# Connect to death signal
	if golem.has_signal("died"):
		golem.died.connect(_on_rust_golem_died)

	print("🦾 Spawned Rust Golem at %s (Y=%.1f)" % [spawn_pos, spawn_pos.y])


func _on_rust_golem_died(entity):
	"""Track when Rust Golems die"""
	_active_rust_golems = max(0, _active_rust_golems - 1)

	# Remove from tracking array
	var index = _spawned_golems.find(entity)
	if index >= 0:
		_spawned_golems.remove_at(index)

	print("🦾 Rust Golem defeated (remaining: %d)" % _active_rust_golems)
