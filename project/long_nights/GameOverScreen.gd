extends CanvasLayer
## GameOverScreen - Shows when player dies
## Offers respawn or quit options

var panel: PanelContainer
var respawn_button: Button
var quit_button: Button

signal respawn_requested()
signal quit_requested()


func _ready() -> void:
	# Start hidden
	visible = false

	# Create UI
	_create_ui()

	# Connect to player death
	call_deferred("_connect_to_player")


func _create_ui() -> void:
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Panel
	panel = PanelContainer.new()
	center.add_child(panel)

	# Margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)

	# VBox for layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "YOU DIED"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.0, 0.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# Respawn button
	respawn_button = Button.new()
	respawn_button.text = "Respawn"
	respawn_button.custom_minimum_size = Vector2(200, 40)
	respawn_button.pressed.connect(_on_respawn_pressed)
	vbox.add_child(respawn_button)

	# Quit button
	quit_button = Button.new()
	quit_button.text = "Quit to Main Menu"
	quit_button.custom_minimum_size = Vector2(200, 40)
	quit_button.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_button)


func _connect_to_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)
		print("GameOverScreen: Connected to player death signal")
	else:
		push_warning("GameOverScreen: Could not find player or player_died signal")


func _on_player_died() -> void:
	# Show game over screen
	visible = true

	# Pause the game
	get_tree().paused = true

	# Release mouse for menu interaction
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_respawn_pressed() -> void:
	# Hide screen
	visible = false

	# Unpause
	get_tree().paused = false

	# Re-capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Find player and respawn
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Reset HP
		player.current_hp = player.max_hp
		player.is_alive = true

		# Re-enable controls
		player.set_physics_process(true)
		player.set_process_input(true)

		# Emit HP change to update UI
		player.hp_changed.emit(player.current_hp, player.max_hp)

		# TODO: Move player to spawn point
		# For now they just respawn where they died

		print("Player respawned!")


func _on_quit_pressed() -> void:
	# Unpause
	get_tree().paused = false

	# Quit to main menu
	get_tree().change_scene_to_file("res://blocky_game/main.tscn")
