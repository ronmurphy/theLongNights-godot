extends CanvasLayer

## PauseMenu - Displays when game is paused
## Listens to GameManager pause signal

var _pause_panel: Panel
var _graphics_ui: Control

func _ready() -> void:
	_setup_ui()
	# Connect to GameManager pause signal if it exists
	if GameManager.instance:
		GameManager.instance.game_paused.connect(_on_game_paused)

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

	# Graphics Settings Button
	var settings_button = Button.new()
	settings_button.text = "Graphics Settings"
	settings_button.custom_minimum_size = Vector2(0, 50)
	settings_button.pressed.connect(_on_graphics_settings_pressed)
	vbox.add_child(settings_button)

	# Spacer
	spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Resume Button
	var resume_button = Button.new()
	resume_button.text = "Resume (ESC)"
	resume_button.custom_minimum_size = Vector2(0, 50)
	resume_button.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_button)

	# Initially hidden
	visible = false

func _on_game_paused(paused: bool) -> void:
	visible = paused

func _on_graphics_settings_pressed() -> void:
	# Show graphics settings modal
	var graphics_ui = load("res://blocky_game/gui/GraphicsSettingsUI.gd").new()
	add_child(graphics_ui)
	graphics_ui.show_modal()

func _on_resume_pressed() -> void:
	if GameManager.instance:
		GameManager.instance.toggle_pause()
