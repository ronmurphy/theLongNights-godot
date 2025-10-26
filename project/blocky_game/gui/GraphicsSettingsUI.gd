extends Control

## GraphicsSettingsUI - UI Controller for graphics settings modal
## Can be instantiated in main menu or pause menu

var _modal_panel: Panel
var _close_button: Button
var _profile_buttons: Dictionary = {}
var _profile_label: Label

signal closed

func _ready() -> void:
	_setup_ui()
	_connect_signals()
	_update_profile_display()

func _setup_ui() -> void:
	# Root container (full screen overlay)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Dark overlay
	var overlay = ColorRect.new()
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(overlay)

	# Modal panel (centered)
	_modal_panel = Panel.new()
	_modal_panel.custom_minimum_size = Vector2(500, 400)
	add_child(_modal_panel)

	# Center the panel
	_modal_panel.anchor_left = 0.5
	_modal_panel.anchor_top = 0.5
	_modal_panel.offset_left = -250
	_modal_panel.offset_top = -200

	# Main vertical layout
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.theme = _create_theme()
	vbox.add_theme_constant_override("separation", 15)
	_modal_panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Graphics Settings"
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	# Profile buttons container
	var button_hbox = HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(button_hbox)

	# Create profile buttons
	for profile_name in ["low", "medium", "high"]:
		var button = Button.new()
		button.text = profile_name.to_upper()
		button.custom_minimum_size = Vector2(120, 50)
		button.pressed.connect(_on_profile_selected.bindv([profile_name]))
		button_hbox.add_child(button)
		_profile_buttons[profile_name] = button

	# Current profile display
	_profile_label = Label.new()
	_profile_label.text = "Current Profile: MEDIUM"
	_profile_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_profile_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# Info label
	var info_label = Label.new()
	info_label.text = "[Low] Best for potato PCs\n[Medium] Balanced performance\n[High] Maximum quality"
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(info_label)

	# Spacer
	spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Close button
	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(0, 40)
	_close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(_close_button)

	_update_button_states()

func _create_theme() -> Theme:
	var theme = Theme.new()
	# You can customize colors, fonts, etc. here
	return theme

func _connect_signals() -> void:
	GraphicsSettings.settings_changed.connect(_on_settings_changed)

func _on_profile_selected(profile_name: String) -> void:
	print("[GraphicsSettingsUI] Selected profile: ", profile_name)
	GraphicsSettings.apply_profile(profile_name)
	_update_profile_display()
	_update_button_states()

func _on_settings_changed(profile_name: String) -> void:
	_update_profile_display()
	_update_button_states()

func _on_close_pressed() -> void:
	queue_free()
	closed.emit()

func _update_profile_display() -> void:
	var current = GraphicsSettings.get_current_profile()
	_profile_label.text = "Current Profile: " + current.to_upper()

func _update_button_states() -> void:
	var current = GraphicsSettings.get_current_profile()
	for profile_name in _profile_buttons.keys():
		var button = _profile_buttons[profile_name]
		if profile_name == current:
			button.add_theme_color_override("font_color", Color.GREEN)
			button.modulate = Color(0.8, 1.0, 0.8)  # Light green tint
		else:
			button.remove_theme_color_override("font_color")
			button.modulate = Color.WHITE

func toggle_visibility() -> void:
	visible = not visible

func show_modal() -> void:
	visible = true

func hide_modal() -> void:
	visible = true
