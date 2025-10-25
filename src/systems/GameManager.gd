extends Node
## GameManager - Central hub for game state and systems management
## Handles initialization, signals, and game flow

class_name GameManager

# Signals
signal game_started
signal game_paused(paused: bool)
signal player_died

# Singleton reference
static var instance: GameManager

# Systems
var time_manager: TimeManager
var world_manager: Node  # Will add this
var player: Node3D

# State
var is_running: bool = false
var is_paused: bool = false

func _ready() -> void:
	# Singleton pattern
	if instance == null:
		instance = self
	else:
		queue_free()
		return

	print("🎮 GameManager initializing...")
	_initialize_systems()
	is_running = true
	game_started.emit()

func _initialize_systems() -> void:
	# Create or find TimeManager
	time_manager = TimeManager.new()
	add_child(time_manager)

	# Connect to time events
	time_manager.bloodmoon_started.connect(_on_bloodmoon_started)
	time_manager.bloodmoon_ended.connect(_on_bloodmoon_ended)

	print("✅ Systems initialized")

func _input(event: InputEvent) -> void:
	# Handle pause
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_tree().root.set_input_as_handled()

func toggle_pause() -> void:
	is_paused = !is_paused
	time_manager.set_paused(is_paused)
	game_paused.emit(is_paused)
	get_tree().paused = is_paused
	print("⏸️ Game %s" % ("paused" if is_paused else "resumed"))

func _on_bloodmoon_started() -> void:
	print("🩸 Bloodmoon event triggered - spawn waves of enemies")
	# TODO: Tell enemy manager to start spawning

func _on_bloodmoon_ended() -> void:
	print("✅ Bloodmoon ended - reset enemy waves")
	# TODO: Tell enemy manager to stop spawning

## Get current game difficulty
func get_difficulty() -> float:
	return time_manager.get_difficulty_multiplier()

## Called when player dies
func on_player_died() -> void:
	is_running = false
	player_died.emit()
	print("💀 Player died!")
	# TODO: Show game over screen
