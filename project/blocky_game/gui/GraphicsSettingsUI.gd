extends Control

## GraphicsSettingsUI - UI Controller for graphics settings modal
## Can be instantiated in main menu or pause menu

var _modal_panel: Panel
var _close_button: Button
var _profile_buttons: Dictionary = {}
var _profile_label: Label
var _resolution_buttons: Dictionary = {}
var _polish_checkbox: CheckBox
var _fullscreen_checkbox: CheckBox
var _vsync_checkbox: CheckBox

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
	_modal_panel.custom_minimum_size = Vector2(600, 550)
	add_child(_modal_panel)

	# Center the panel
	_modal_panel.anchor_left = 0.5
	_modal_panel.anchor_top = 0.5
	_modal_panel.offset_left = -300
	_modal_panel.offset_top = -275

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

	# === Quality Profile Section ===
	var quality_label = Label.new()
	quality_label.text = "Quality Profile"
	quality_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(quality_label)

	# Profile buttons container
	var button_hbox = HBoxContainer.new()
	button_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(button_hbox)

	# Create profile buttons with tooltips
	var profile_tooltips = {
		"low": "Best for potato PCs\nMinimal graphics features",
		"medium": "Balanced performance\nModerate graphics quality",
		"high": "Maximum quality\nRequires good hardware",
		"cinematic": "Ultimate visuals\nRequires powerful GPU"
	}
	
	for profile_name in ["low", "medium", "high", "cinematic"]:
		var button = Button.new()
		button.text = profile_name.to_upper()
		button.custom_minimum_size = Vector2(120, 50)
		button.tooltip_text = profile_tooltips[profile_name]
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
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Visual Polish Checkbox
	_polish_checkbox = CheckBox.new()
	_polish_checkbox.text = "Visual Polish (Vignette + Color Grading)"
	_polish_checkbox.tooltip_text = "Enable cheap visual effects\nGreat for Low/Medium profiles"
	_polish_checkbox.button_pressed = GraphicsSettings.get_visual_polish_enabled()
	_polish_checkbox.toggled.connect(_on_polish_toggled)
	vbox.add_child(_polish_checkbox)

	# Spacer
	spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(spacer)

	# === Resolution Section ===
	var res_label = Label.new()
	res_label.text = "Resolution"
	res_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(res_label)

	# Resolution buttons
	var res_hbox = HBoxContainer.new()
	res_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(res_hbox)

	var presets = GraphicsSettings.get_resolution_presets()
	for preset_name in ["1280x720", "1920x1080", "2560x1440", "3840x2160"]:
		var res_button = Button.new()
		res_button.text = preset_name
		res_button.custom_minimum_size = Vector2(110, 40)
		res_button.pressed.connect(_on_resolution_selected.bind(preset_name))
		res_hbox.add_child(res_button)
		_resolution_buttons[preset_name] = res_button

	# Fullscreen checkbox
	_fullscreen_checkbox = CheckBox.new()
	_fullscreen_checkbox.text = "Fullscreen"
	_fullscreen_checkbox.button_pressed = GraphicsSettings.is_fullscreen()
	_fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	vbox.add_child(_fullscreen_checkbox)

	# VSync checkbox
	_vsync_checkbox = CheckBox.new()
	_vsync_checkbox.text = "VSync (Vertical Synchronization)"
	_vsync_checkbox.button_pressed = GraphicsSettings.is_vsync_enabled()
	_vsync_checkbox.toggled.connect(_on_vsync_toggled)
	vbox.add_child(_vsync_checkbox)

	# Spacer
	spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 15)
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

func _on_resolution_selected(preset_name: String) -> void:
	var presets = GraphicsSettings.get_resolution_presets()
	if presets.has(preset_name):
		var resolution = presets[preset_name]
		print("[GraphicsSettingsUI] Selected resolution: ", preset_name)
		GraphicsSettings.set_resolution(resolution)
		_update_resolution_button_states()

func _on_fullscreen_toggled(pressed: bool) -> void:
	print("[GraphicsSettingsUI] Fullscreen: ", pressed)
	GraphicsSettings.set_fullscreen(pressed)

func _on_vsync_toggled(pressed: bool) -> void:
	print("[GraphicsSettingsUI] VSync: ", pressed)
	GraphicsSettings.set_vsync(pressed)

func _on_polish_toggled(pressed: bool) -> void:
	print("[GraphicsSettingsUI] Visual Polish: ", pressed)
	GraphicsSettings.set_visual_polish_enabled(pressed)

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
	
	if _polish_checkbox:
		_polish_checkbox.set_pressed_no_signal(GraphicsSettings.get_visual_polish_enabled())
	
	_update_resolution_button_states()

func _update_resolution_button_states() -> void:
	var current_res = GraphicsSettings.get_resolution()
	var presets = GraphicsSettings.get_resolution_presets()
	
	for preset_name in _resolution_buttons.keys():
		var button = _resolution_buttons[preset_name]
		var preset_res = presets[preset_name]
		
		if preset_res == current_res:
			button.add_theme_color_override("font_color", Color.GREEN)
			button.modulate = Color(0.8, 1.0, 0.8)
		else:
			button.remove_theme_color_override("font_color")
			button.modulate = Color.WHITE

func toggle_visibility() -> void:
	visible = not visible

func show_modal() -> void:
	visible = true

func hide_modal() -> void:
	visible = true
