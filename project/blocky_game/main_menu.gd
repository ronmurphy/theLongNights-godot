extends Control

@onready var _ip_line_edit : LineEdit = \
	$CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/IP
@onready var _port_spinbox : SpinBox = \
	$CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/Port
@onready var _continue_button : Button = \
	$CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ContinueGameButton
@onready var _backup_button : Button = \
	$CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BackupWorldButton

signal continue_game_requested()
signal new_game_requested(seed)
signal backup_world_requested()
signal connect_to_server_requested(ip, port)
signal host_server_requested(port)
signal upnp_toggled(pressed)
signal graphics_settings_requested()

var _background_shader: ColorRect = null


func _ready():
	# Check if world save exists to enable/disable buttons
	_update_button_states()
	
	# Add animated shader background behind the menu
	_add_shader_background()


func _update_button_states():
	var world_exists = WorldManager.world_exists()
	_continue_button.disabled = not world_exists
	_backup_button.disabled = not world_exists


func _on_continue_game_button_pressed():
	continue_game_requested.emit()


func _on_new_game_button_pressed():
	_show_new_game_dialog()


func _on_backup_world_button_pressed():
	backup_world_requested.emit()


func _on_settings_button_pressed():
	graphics_settings_requested.emit()
	_show_graphics_settings()


func _on_connect_to_server_button_pressed():
	var ip := _ip_line_edit.text.strip_edges()
	if ip == "":
		return
	# TODO Do more validation on the syntax of IP address
	var port : int = _port_spinbox.value
	connect_to_server_requested.emit(ip, port)


func _on_host_server_button_pressed():
	var port : int = _port_spinbox.value
	host_server_requested.emit(port)


func _on_upnp_checkbox_toggled(button_pressed: bool):
	upnp_toggled.emit(button_pressed)


func _show_graphics_settings() -> void:
	# Create and show graphics settings UI
	var graphics_ui = load("res://blocky_game/gui/GraphicsSettingsUI.gd").new()
	add_child(graphics_ui)
	graphics_ui.show_modal()


func _show_new_game_dialog() -> void:
	# Create confirmation dialog
	var dialog = AcceptDialog.new()
	dialog.title = "New Game"
	dialog.dialog_autowrap = true

	# Create content container
	var vbox = VBoxContainer.new()

	# Warning if world exists
	if WorldManager.world_exists():
		var warning = Label.new()
		warning.text = "WARNING: This will delete your existing world!\nMake sure to backup first if needed."
		warning.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		vbox.add_child(warning)

		var separator = HSeparator.new()
		vbox.add_child(separator)

	# Seed input
	var seed_container = HBoxContainer.new()
	var seed_label = Label.new()
	seed_label.text = "World Seed:"
	seed_container.add_child(seed_label)

	var seed_input = LineEdit.new()
	seed_input.custom_minimum_size = Vector2(200, 0)
	seed_input.text = str(WorldManager.get_seed())  # Default to current/default seed
	seed_input.placeholder_text = "Enter seed (number)"
	seed_container.add_child(seed_input)

	var random_button = Button.new()
	random_button.text = "Random"
	random_button.pressed.connect(func():
		seed_input.text = str(randi() % 1000000)
	)
	seed_container.add_child(random_button)

	vbox.add_child(seed_container)

	dialog.add_child(vbox)

	# Add Cancel button
	dialog.add_cancel_button("Cancel")

	# Handle confirmation
	dialog.confirmed.connect(func():
		var seed_text = seed_input.text.strip_edges()
		var seed = 131183  # Default

		if seed_text != "":
			if seed_text.is_valid_int():
				seed = seed_text.to_int()
			else:
				push_error("Invalid seed, using default")

		new_game_requested.emit(seed)
		dialog.queue_free()
	)

	dialog.close_requested.connect(func():
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered()


func _add_shader_background() -> void:
	# Create a ColorRect with the animated shader background
	# Note: Shader changed from network_background to starfield on Nov 3, 2025
	# Original network shader archived as: ARCHIVED_network_background.gdshader
	_background_shader = ColorRect.new()
	_background_shader.name = "ShaderBackground"
	
	# Set anchors to fill entire screen
	_background_shader.anchor_left = 0.0
	_background_shader.anchor_top = 0.0
	_background_shader.anchor_right = 1.0
	_background_shader.anchor_bottom = 1.0
	
	# Set position and size to fill
	_background_shader.offset_left = 0
	_background_shader.offset_top = 0
	_background_shader.offset_right = 0
	_background_shader.offset_bottom = 0
	
	# Create and apply the shader material
	var shader = load("res://blocky_game/shaders/network_background.gdshader")
	if shader == null:
		push_error("Failed to load network_background.gdshader")
		return
	
	var material = ShaderMaterial.new()
	material.shader = shader
	_background_shader.material = material
	
	# Add to the MainMenu (parent of CenterContainer) at z-index 0 (behind)
	add_child(_background_shader)
	move_child(_background_shader, 0)
	
	print("Main menu shader background created")


func dispose_shader_background() -> void:
	# Called when game starts - remove the animated background
	if _background_shader:
		_background_shader.queue_free()
		_background_shader = null
		print("Main menu shader background disposed")
