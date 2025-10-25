extends Node
## Main entry point for The Long Nights game
## Handles scene initialization and game state management
## This is a CODE-ONLY scene (no .tscn file)
## All nodes are created programmatically for easy testing
## Runs as an AutoLoad singleton

var root: Node3D  # The 3D scene root
var game_manager: GameManager
var world_generator: WorldGenerator
var player: Player

func _ready() -> void:
	print("🌙 The Long Nights - Godot Edition initializing...")
	_setup_scene()
	print("✅ Main scene loaded successfully")

## Build the entire scene in code
func _setup_scene() -> void:
	# Create a 3D root node for the scene
	root = Node3D.new()
	root.name = "GameRoot"
	add_child(root)

	# Create GameManager first (singleton)
	game_manager = GameManager.new()
	root.add_child(game_manager)

	# Create WorldGenerator
	world_generator = WorldGenerator.new()
	root.add_child(world_generator)

	# Create Player (CharacterBody3D)
	player = Player.new()
	player.position = Vector3(0, 2, 0)
	root.add_child(player)

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
	root.add_child(light)

	print("📦 Scene hierarchy created:")
	print("  - GameManager")
	print("  - WorldGenerator")
	print("  - Player")
	print("    - Camera3D")
	print("    - CollisionShape3D")
