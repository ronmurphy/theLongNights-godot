extends CanvasLayer

## PauseMenu - Displays when game is paused (ESC key)

var _pause_panel: Panel
var _graphics_ui: Control
var _is_paused := false
var _click_sound: AudioStreamPlayer

func _ready() -> void:
	# Setup click sound
	_click_sound = AudioStreamPlayer.new()
	_click_sound.stream = load("res://assets/sfx/Select.ogg")
	_click_sound.volume_db = -8.0
	add_child(_click_sound)

	_setup_ui()
	process_mode = Node.PROCESS_MODE_ALWAYS  # Allow input when paused

func _setup_ui() -> void:
	# Root container
	var root = Control.new()
	root.anchor_left = 0.0
	root.anchor_top = 0.0
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	# Dark overlay
	var overlay = ColorRect.new()
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(overlay)

	# Pause panel (centered)
	_pause_panel = Panel.new()
	_pause_panel.custom_minimum_size = Vector2(400, 300)
	root.add_child(_pause_panel)

	# Center the panel
	_pause_panel.anchor_left = 0.5
	_pause_panel.anchor_top = 0.5
	_pause_panel.offset_left = -200
	_pause_panel.offset_top = -150

	# Main vertical layout
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 15)
	_pause_panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# Resume Button
	var resume_button = Button.new()
	resume_button.text = "Resume (ESC)"
	resume_button.custom_minimum_size = Vector2(0, 50)
	resume_button.pressed.connect(_play_click_sound)
	resume_button.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_button)

	# Save Button
	var save_button = Button.new()
	save_button.text = "Save Game"
	save_button.custom_minimum_size = Vector2(0, 50)
	save_button.pressed.connect(_play_click_sound)
	save_button.pressed.connect(_on_save_pressed)
	vbox.add_child(save_button)

	# Graphics Settings Button
	var settings_button = Button.new()
	settings_button.text = "Graphics Settings"
	settings_button.custom_minimum_size = Vector2(0, 50)
	settings_button.pressed.connect(_play_click_sound)
	settings_button.pressed.connect(_on_graphics_settings_pressed)
	vbox.add_child(settings_button)

	# Save and Quit Button
	var quit_button = Button.new()
	quit_button.text = "Save and Quit"
	quit_button.custom_minimum_size = Vector2(0, 50)
	quit_button.pressed.connect(_play_click_sound)
	quit_button.pressed.connect(_on_save_and_quit_pressed)
	vbox.add_child(quit_button)

	# Initially hidden
	visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		toggle_pause()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	_is_paused = !_is_paused
	visible = _is_paused
	get_tree().paused = _is_paused

	# Control mouse mode
	if _is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		# Check if inventory is open before restoring captured mode
		var inventory = get_node_or_null("/root/Main/Game/Inventory")
		if inventory and inventory.visible:
			# Inventory is open, let it manage the mouse mode
			pass
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_graphics_settings_pressed() -> void:
	# Show graphics settings modal
	var graphics_ui = load("res://blocky_game/gui/GraphicsSettingsUI.gd").new()
	add_child(graphics_ui)
	graphics_ui.show_modal()

func _play_click_sound() -> void:
	"""Play UI click sound"""
	if _click_sound:
		_click_sound.play()


func _on_resume_pressed() -> void:
	toggle_pause()


func _on_save_pressed() -> void:
	_save_game()
	print("Game saved!")


func _on_save_and_quit_pressed() -> void:
	_save_game()
	get_tree().quit()


func _save_game() -> void:
	# Get player position
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		# Try to find player by path
		player = get_node_or_null("/root/Main/Game/Players/1")

	if player != null:
		WorldManager.set_player_position(player.global_position)
		print("💾 Saving player position: %s" % player.global_position)
	else:
		print("⚠️ WARNING: Could not find player node for saving position!")

	# Sync live companion's equipment to roster before saving
	var companions = get_tree().get_nodes_in_group("companions")
	if companions.size() > 0 and CompanionManager.using_roster_system:
		var companion = companions[0]
		CompanionManager.update_active_companion_from_scene(companion)
		print("💾 Synced companion equipment to roster before save")

	# Save world config
	WorldManager.save_world()

	# Save terrain modifications
	var terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")
	if terrain != null:
		terrain.save_modified_blocks()
