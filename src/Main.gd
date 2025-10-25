extends Node3D
## Main entry point for The Long Nights game
## CODE-ONLY scene setup - all nodes created programmatically

var game_manager: GameManager
var world_generator: WorldGenerator
var player: Player

func _ready() -> void:
	print("The Long Nights - Godot Edition initializing...")
	_setup_scene()
	print("Main scene loaded successfully")

func _setup_scene() -> void:
	# Create GameManager
	game_manager = GameManager.new()
	add_child(game_manager)

	# Create WorldGenerator
	world_generator = WorldGenerator.new()
	add_child(world_generator)

	# Create Player
	player = Player.new()
	player.position = Vector3(0, 40, 0)  # Spawn above terrain
	add_child(player)

	# Add Camera to Player
	var camera = Camera3D.new()
	camera.current = true
	camera.h_offset = 0.3
	camera.v_offset = 1.5
	player.add_child(camera)
	player.camera = camera

	# Add CollisionShape to Player
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	player.add_child(collision)

	# Add Lighting
	var light = DirectionalLight3D.new()
	light.rotation = Vector3(-0.5, 0, 0)
	add_child(light)

	# Connect player to world generator for infinite terrain
	world_generator.set_player(player)

	print("Scene created:")
	print("  GameManager")
	print("  WorldGenerator")
	print("  Player + Camera + Collision")
	print("  DirectionalLight")
	print("  Infinite terrain system connected")
