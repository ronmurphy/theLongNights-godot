extends Node

const BlockyGame = preload("./blocky_game.gd")
const BlockyGameScene = preload("./blocky_game.tscn")
const MainMenu = preload("./main_menu.gd")
const UPNPHelper = preload("./upnp_helper.gd")
const CharacterQuiz = preload("res://long_nights/CharacterQuiz.gd")

@onready var _main_menu : MainMenu = $MainMenu

var _game : BlockyGame
var _upnp_helper : UPNPHelper
var _pending_seed: int = -1


func _on_main_menu_continue_game_requested():
	# Load existing world
	if not WorldManager.load_world():
		push_error("Failed to load world!")
		return

	# Load saved character data
	if not PlayerData.load_from_file():
		push_warning("No saved character data, using defaults")
	
	# Load saved companion data (equipment, etc.)
	if not CompanionManager.load_from_file():
		print("No saved companion data, will use defaults")

	_start_game()


func _on_main_menu_new_game_requested(seed: int):
	# Store seed for after quiz
	_pending_seed = seed

	# Show character creation quiz
	var quiz = CharacterQuiz.new()
	quiz.quiz_completed.connect(_on_quiz_completed)
	add_child(quiz)

	# Hide main menu
	_main_menu.hide()


func _on_quiz_completed(role: String, race: String, gender: String):
	# Save character data
	PlayerData.set_character(role, race, gender)
	PlayerData.save_to_file()

	# Determine companion based on player choices
	CompanionManager.set_companion_from_player()

	# Create new world with specified seed
	if not WorldManager.create_new_world(_pending_seed):
		push_error("Failed to create new world!")
		_main_menu.show()  # Show menu again on error
		return

	_start_game()


func _on_main_menu_backup_world_requested():
	if WorldManager.backup_world():
		print("World backup created successfully!")
		# Could show a confirmation dialog here
	else:
		push_error("Failed to backup world!")


func _start_game():
	# Force reload the generator GDScript so it picks up the current seed from world.config
	# This is necessary because the generator's _init() only runs once when first loaded
	var generator_script_path = "res://blocky_game/generator/generator.gd"
	if ResourceLoader.has_cached(generator_script_path):
		# Clear the cached script so _init() runs again with new seed
		var script = load(generator_script_path)
		script.reload()

	_game = BlockyGameScene.instantiate()
	_game.set_network_mode(BlockyGame.NETWORK_MODE_SINGLEPLAYER)
	add_child(_game)

	_main_menu.hide()

	# Start music when entering game
	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").start_music()


func _on_main_menu_connect_to_server_requested(ip: String, port: int):
	_game = BlockyGameScene.instantiate()
	_game.set_ip(ip)
	_game.set_port(port)
	_game.set_network_mode(BlockyGame.NETWORK_MODE_CLIENT)
	add_child(_game)

	_main_menu.hide()

	get_viewport().get_window().title = "Client"

	# Start music when entering game
	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").start_music()


func _on_main_menu_host_server_requested(port: int):
	if _upnp_helper != null and not _upnp_helper.is_setup():
		_upnp_helper.setup(port, PackedStringArray(["UDP"]), "VoxelBlockyGame", 20 * 60)

	_game = BlockyGameScene.instantiate()
	_game.set_port(port)
	_game.set_network_mode(BlockyGame.NETWORK_MODE_HOST)
	add_child(_game)

	_main_menu.hide()

	get_viewport().get_window().title = "Server"

	# Start music when entering game
	if has_node("/root/MusicManager"):
		get_node("/root/MusicManager").start_music()


func _on_main_menu_upnp_toggled(pressed: bool):
	if pressed:
		if _upnp_helper == null:
			_upnp_helper = UPNPHelper.new()
			add_child(_upnp_helper)
	else:
		if _upnp_helper != null:
			_upnp_helper.queue_free()
			_upnp_helper = null
