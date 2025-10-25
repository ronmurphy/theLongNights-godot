extends Node3D
## Main entry point for The Long Nights game
## Handles scene initialization and game state management

@onready var game_manager = GameManager
@onready var world_generator = $WorldGenerator as WorldGenerator
@onready var player = $Player as Player

func _ready() -> void:
	print("🌙 The Long Nights - Godot Edition initializing...")
	print("✅ Main scene loaded successfully")
