extends Control

## TownManagerModal - Michelle's Town Manager Shop
## Two-panel layout:
##   LEFT: Options list (Fence Upgrade + Structure Blueprints)
##   RIGHT: 3D preview of selected structure OR fence upgrade panel
## Purchases use rust blocks as currency

signal modal_closed
signal fence_upgraded(full_price: bool, new_material_block_id: int)
signal structure_purchased(blueprint_name: String)
signal first_blueprint_tutorial_needed  # Emitted when player buys first blueprint ever

# Selection state
enum SelectionType { NONE, FENCE_UPGRADE, STRUCTURE }
var _selection_type: SelectionType = SelectionType.NONE
var _selected_blueprint: StructureBlueprintLibrary.StructureBlueprint = null

# UI references - Left panel
@onready var _title_label: Label
@onready var _scroll_container: ScrollContainer
@onready var _options_container: VBoxContainer

# UI references - Right panel
var _preview_container: Control
var _sub_viewport: SubViewport
var _preview_camera: Camera3D
var _preview_scene: Node3D

# UI references - Bottom panel
var _info_label: Label
var _cost_label: Label
var _purchase_button: Button
var _cancel_button: Button

# Camera controls
var _camera_distance: float = 20.0
var _camera_rotation: Vector2 = Vector2(30, 45)  # pitch, yaw in degrees
var _is_dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

# Rust block balance
var _rust_count: int = 0


func _ready():
	# Build UI structure
	_build_ui()

	# Update rust block count
	_update_rust_balance()

	# Force mouse to be visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Show modal centered
	popup_centered()


func _process(_delta):
	"""Continuously enforce mouse visibility"""
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent):
	"""Handle input for 3D preview camera controls"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed
			if event.pressed:
				_last_mouse_pos = event.position

		# Scroll wheel to zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = max(10.0, _camera_distance - 2.0)
			_update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = min(50.0, _camera_distance + 2.0)
			_update_camera_transform()

	elif event is InputEventMouseMotion:
		if _is_dragging:
			var delta = event.position - _last_mouse_pos
			_last_mouse_pos = event.position

			# Rotate camera
			_camera_rotation.y += delta.x * 0.3
			_camera_rotation.x -= delta.y * 0.3

			# Clamp pitch
			_camera_rotation.x = clamp(_camera_rotation.x, -89, 89)

			_update_camera_transform()


func _build_ui():
	"""Build the entire modal UI"""
	# Main panel background with brown/gold theme
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(1000, 600)
	panel.focus_mode = Control.FOCUS_NONE

	# Apply brown/gold theme
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.15, 0.1, 0.05, 0.95)  # Dark brown
	stylebox.border_color = Color(0.8, 0.6, 0.2, 1.0)  # Gold
	stylebox.border_width_left = 3
	stylebox.border_width_top = 3
	stylebox.border_width_right = 3
	stylebox.border_width_bottom = 3
	stylebox.corner_radius_top_left = 8
	stylebox.corner_radius_top_right = 8
	stylebox.corner_radius_bottom_left = 8
	stylebox.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", stylebox)

	add_child(panel)

	# Main vertical layout
	var main_vbox = VBoxContainer.new()
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_bottom = 1.0
	main_vbox.offset_left = 20
	main_vbox.offset_top = 20
	main_vbox.offset_right = -20
	main_vbox.offset_bottom = -20
	panel.add_child(main_vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "🏘️ Town Manager - Michelle's Shop"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))  # Gold text
	main_vbox.add_child(_title_label)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(spacer1)

	# Rust balance label
	var balance_label = Label.new()
	balance_label.text = "Rust Blocks: 0"
	balance_label.name = "RustBalanceLabel"
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_label.add_theme_font_size_override("font_size", 16)
	balance_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))  # Orange-gold
	main_vbox.add_child(balance_label)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(spacer2)

	# Side-by-side container for list and preview
	var split_hbox = HBoxContainer.new()
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_hbox.custom_minimum_size = Vector2(0, 300)  # Reduced to ensure buttons fit
	split_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(split_hbox)

	# LEFT PANEL: Options list
	_build_left_panel(split_hbox)

	# RIGHT PANEL: 3D preview
	_build_right_panel(split_hbox)

	# Spacer
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(spacer3)

	# Info label (shows description of selected item)
	_info_label = Label.new()
	_info_label.text = "Select an option from the list"
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_font_size_override("font_size", 14)
	_info_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(0, 40)
	main_vbox.add_child(_info_label)

	# Cost label
	_cost_label = Label.new()
	_cost_label.text = ""
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.add_theme_font_size_override("font_size", 16)
	_cost_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	_cost_label.visible = false
	main_vbox.add_child(_cost_label)

	# Spacer
	var spacer4 = Control.new()
	spacer4.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(spacer4)

	# Bottom buttons
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(button_hbox)

	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.custom_minimum_size = Vector2(120, 40)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_apply_button_style(_cancel_button, false)
	button_hbox.add_child(_cancel_button)

	# Spacer between buttons
	var button_spacer = Control.new()
	button_spacer.custom_minimum_size = Vector2(20, 0)
	button_hbox.add_child(button_spacer)

	_purchase_button = Button.new()
	_purchase_button.text = "Purchase"
	_purchase_button.custom_minimum_size = Vector2(120, 40)
	_purchase_button.disabled = true
	_purchase_button.pressed.connect(_on_purchase_pressed)
	_apply_button_style(_purchase_button, true)
	button_hbox.add_child(_purchase_button)


func _build_left_panel(parent: HBoxContainer):
	"""Build the left panel with options list"""
	var list_vbox = VBoxContainer.new()
	list_vbox.custom_minimum_size = Vector2(380, 400)
	parent.add_child(list_vbox)

	var list_label = Label.new()
	list_label.text = "📋 Available Options"
	list_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_label.add_theme_font_size_override("font_size", 16)
	list_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	list_vbox.add_child(list_label)

	var list_spacer = Control.new()
	list_spacer.custom_minimum_size = Vector2(0, 5)
	list_vbox.add_child(list_spacer)

	# Panel container for the list
	var list_panel = PanelContainer.new()
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var list_panel_style = StyleBoxFlat.new()
	list_panel_style.bg_color = Color(0.1, 0.08, 0.05, 0.9)
	list_panel_style.border_color = Color(0.6, 0.5, 0.2)
	list_panel_style.border_width_left = 2
	list_panel_style.border_width_top = 2
	list_panel_style.border_width_right = 2
	list_panel_style.border_width_bottom = 2
	list_panel.add_theme_stylebox_override("panel", list_panel_style)

	list_vbox.add_child(list_panel)

	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.focus_mode = Control.FOCUS_NONE
	list_panel.add_child(_scroll_container)

	_options_container = VBoxContainer.new()
	_options_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(_options_container)

	# Populate options
	_populate_options_list()


func _build_right_panel(parent: HBoxContainer):
	"""Build the right panel with 3D preview"""
	var preview_vbox = VBoxContainer.new()
	preview_vbox.custom_minimum_size = Vector2(540, 400)
	preview_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(preview_vbox)

	var preview_label = Label.new()
	preview_label.text = "🏗️ Preview (Drag to rotate • Scroll to zoom)"
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.add_theme_font_size_override("font_size", 16)
	preview_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	preview_vbox.add_child(preview_label)

	var preview_spacer = Control.new()
	preview_spacer.custom_minimum_size = Vector2(0, 5)
	preview_vbox.add_child(preview_spacer)

	# Panel container for the preview
	var preview_panel = PanelContainer.new()
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var preview_panel_style = StyleBoxFlat.new()
	preview_panel_style.bg_color = Color(0.1, 0.08, 0.05, 0.9)
	preview_panel_style.border_color = Color(0.6, 0.5, 0.2)
	preview_panel_style.border_width_left = 2
	preview_panel_style.border_width_top = 2
	preview_panel_style.border_width_right = 2
	preview_panel_style.border_width_bottom = 2
	preview_panel.add_theme_stylebox_override("panel", preview_panel_style)

	preview_vbox.add_child(preview_panel)

	_preview_container = Control.new()
	_preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_container.focus_mode = Control.FOCUS_NONE
	preview_panel.add_child(_preview_container)

	# Build 3D preview viewport
	_build_3d_preview()


func _populate_options_list():
	"""Populate the options list with Fence Upgrade + Structure Blueprints"""

	# FENCE UPGRADE BUTTON
	var fence_button = Button.new()
	fence_button.text = "🛡️ Upgrade Fence"
	fence_button.custom_minimum_size = Vector2(0, 50)
	fence_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	fence_button.pressed.connect(_on_fence_upgrade_selected)
	_apply_list_button_style(fence_button)
	_options_container.add_child(fence_button)

	# Separator
	var separator1 = HSeparator.new()
	separator1.add_theme_constant_override("separation", 10)
	_options_container.add_child(separator1)

	# HOMEBASE STRUCTURES HEADER
	var homebase_header = Label.new()
	homebase_header.text = "🏠 Homebase Structures"
	homebase_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	homebase_header.add_theme_font_size_override("font_size", 14)
	homebase_header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	_options_container.add_child(homebase_header)

	# Add homebase structure buttons
	var homebase_blueprints = StructureBlueprintLibrary.get_blueprints_by_category("homebase")
	for bp in homebase_blueprints:
		var btn = _create_structure_button(bp)
		_options_container.add_child(btn)

	# Separator
	var separator2 = HSeparator.new()
	separator2.add_theme_constant_override("separation", 10)
	_options_container.add_child(separator2)

	# UTILITY STRUCTURES HEADER
	var utility_header = Label.new()
	utility_header.text = "🔧 Utility Structures"
	utility_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	utility_header.add_theme_font_size_override("font_size", 14)
	utility_header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	_options_container.add_child(utility_header)

	# Add utility structure buttons
	var utility_blueprints = StructureBlueprintLibrary.get_blueprints_by_category("utility")
	for bp in utility_blueprints:
		var btn = _create_structure_button(bp)
		_options_container.add_child(btn)

	# Separator
	var separator3 = HSeparator.new()
	separator3.add_theme_constant_override("separation", 10)
	_options_container.add_child(separator3)

	# DEFENSIVE STRUCTURES HEADER
	var defensive_header = Label.new()
	defensive_header.text = "🛡️ Defensive Structures"
	defensive_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defensive_header.add_theme_font_size_override("font_size", 14)
	defensive_header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	_options_container.add_child(defensive_header)

	# Add defensive structure buttons
	var defensive_blueprints = StructureBlueprintLibrary.get_blueprints_by_category("defensive")
	for bp in defensive_blueprints:
		var btn = _create_structure_button(bp)
		_options_container.add_child(btn)

	# Separator
	var separator4 = HSeparator.new()
	separator4.add_theme_constant_override("separation", 10)
	_options_container.add_child(separator4)

	# PRODUCTION STRUCTURES HEADER
	var production_header = Label.new()
	production_header.text = "⚒️ Production Structures"
	production_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	production_header.add_theme_font_size_override("font_size", 14)
	production_header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	_options_container.add_child(production_header)

	# Add production structure buttons
	var production_blueprints = StructureBlueprintLibrary.get_blueprints_by_category("production")
	for bp in production_blueprints:
		var btn = _create_structure_button(bp)
		_options_container.add_child(btn)

	# Separator
	var separator5 = HSeparator.new()
	separator5.add_theme_constant_override("separation", 10)
	_options_container.add_child(separator5)

	# UNDERGROUND STRUCTURES HEADER
	var underground_header = Label.new()
	underground_header.text = "⛏️ Underground Structures"
	underground_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	underground_header.add_theme_font_size_override("font_size", 14)
	underground_header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	_options_container.add_child(underground_header)

	# Add underground structure buttons
	var underground_blueprints = StructureBlueprintLibrary.get_blueprints_by_category("underground")
	for bp in underground_blueprints:
		var btn = _create_structure_button(bp)
		_options_container.add_child(btn)

	# Separator
	var separator6 = HSeparator.new()
	separator6.add_theme_constant_override("separation", 10)
	_options_container.add_child(separator6)

	# LAND EXPANSIONS HEADER
	var expansion_header = Label.new()
	expansion_header.text = "🌍 Land Expansions"
	expansion_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	expansion_header.add_theme_font_size_override("font_size", 14)
	expansion_header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	_options_container.add_child(expansion_header)

	# Add land expansion buttons
	var expansion_blueprints = StructureBlueprintLibrary.get_blueprints_by_category("land_expansion")
	for bp in expansion_blueprints:
		var btn = _create_expansion_button(bp)
		_options_container.add_child(btn)


func _create_structure_button(blueprint: StructureBlueprintLibrary.StructureBlueprint) -> Button:
	"""Create a button for a structure blueprint"""
	var btn = Button.new()
	var cost_text = "FREE" if blueprint.rust_block_cost == 0 else str(blueprint.rust_block_cost) + " rust"
	btn.text = blueprint.display_name + " (" + cost_text + ")"
	btn.custom_minimum_size = Vector2(0, 40)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_structure_selected.bind(blueprint))
	btn.set_meta("blueprint", blueprint)
	_apply_list_button_style(btn)
	return btn


func _create_expansion_button(blueprint: StructureBlueprintLibrary.StructureBlueprint) -> Button:
	"""Create a button for a land expansion (handles FREE first time logic)"""
	var btn = Button.new()

	# Check if player has claimed this type before
	var player = get_tree().get_first_node_in_group("player")
	var has_claimed_free = false

	if player:
		if blueprint.name == "wilderness_expansion":
			has_claimed_free = player.get_meta("claimed_free_wilderness", false)
		elif blueprint.name == "construction_platform":
			has_claimed_free = player.get_meta("claimed_free_construction", false)
		elif blueprint.name == "terrain_extraction":
			has_claimed_free = player.get_meta("claimed_free_extraction", false)

	# Determine cost text
	var cost_text: String
	if blueprint.name == "terrain_extraction":
		# Terrain extraction is special - FREE but only once ever
		if has_claimed_free:
			cost_text = "CLAIMED (one-time only)"
		else:
			cost_text = "FREE (ONE TIME ONLY!)"
	elif not has_claimed_free:
		cost_text = "FREE (first time!)"
	else:
		cost_text = str(blueprint.rust_block_cost) + " rust"

	btn.text = blueprint.display_name + " (" + cost_text + ")"
	btn.custom_minimum_size = Vector2(0, 50)  # Taller for warning text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_structure_selected.bind(blueprint))
	btn.set_meta("blueprint", blueprint)
	btn.set_meta("is_expansion", true)
	btn.set_meta("has_claimed_free", has_claimed_free)

	# Disable terrain extraction if already claimed (one-time only!)
	if blueprint.name == "terrain_extraction" and has_claimed_free:
		btn.disabled = true

	_apply_list_button_style(btn)
	return btn


func _apply_list_button_style(button: Button):
	"""Apply brown/gold theme to list buttons"""
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.15, 0.1, 0.8)
	normal_style.border_color = Color(0.5, 0.4, 0.2)
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.3, 0.25, 0.15, 0.9)
	hover_style.border_color = Color(0.8, 0.6, 0.2)
	hover_style.border_width_left = 2
	hover_style.border_width_top = 2
	hover_style.border_width_right = 2
	hover_style.border_width_bottom = 2

	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.4, 0.3, 0.2, 1.0)
	pressed_style.border_color = Color(1.0, 0.8, 0.3)
	pressed_style.border_width_left = 2
	pressed_style.border_width_top = 2
	pressed_style.border_width_right = 2
	pressed_style.border_width_bottom = 2

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.6))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 0.8))


func _apply_button_style(button: Button, is_primary: bool):
	"""Apply brown/gold theme to action buttons"""
	var normal_style = StyleBoxFlat.new()
	var hover_style = StyleBoxFlat.new()
	var pressed_style = StyleBoxFlat.new()
	var disabled_style = StyleBoxFlat.new()

	if is_primary:
		# Primary button (Purchase) - gold/orange
		normal_style.bg_color = Color(0.8, 0.6, 0.2, 1.0)
		hover_style.bg_color = Color(1.0, 0.7, 0.3, 1.0)
		pressed_style.bg_color = Color(0.6, 0.5, 0.2, 1.0)
		disabled_style.bg_color = Color(0.3, 0.25, 0.15, 0.5)
	else:
		# Secondary button (Cancel) - brown
		normal_style.bg_color = Color(0.3, 0.25, 0.15, 0.9)
		hover_style.bg_color = Color(0.4, 0.3, 0.2, 1.0)
		pressed_style.bg_color = Color(0.25, 0.2, 0.1, 1.0)
		disabled_style.bg_color = Color(0.2, 0.15, 0.1, 0.5)

	for style in [normal_style, hover_style, pressed_style, disabled_style]:
		style.border_color = Color(0.5, 0.4, 0.2)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	button.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))


func _build_3d_preview():
	"""Create the 3D preview viewport"""
	# Create SubViewport for 3D rendering
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(540, 400)
	_sub_viewport.transparent_bg = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_container.add_child(_sub_viewport)

	# Create 3D scene root
	_preview_scene = Node3D.new()
	_sub_viewport.add_child(_preview_scene)

	# Create camera
	_preview_camera = Camera3D.new()
	_preview_camera.position = Vector3(0, 0, _camera_distance)
	_preview_scene.add_child(_preview_camera)

	# Add environment
	var env = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.53, 0.81, 0.92)  # Sky blue like day time
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.8, 0.9)
	environment.ambient_light_energy = 1.0
	env.environment = environment
	_preview_scene.add_child(env)

	# Add directional light (sun)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_energy = 1.2
	light.light_color = Color(1.0, 0.95, 0.9)
	light.shadow_enabled = true
	_preview_scene.add_child(light)

	# Create TextureRect to display the viewport
	var texture_rect = TextureRect.new()
	texture_rect.texture = _sub_viewport.get_texture()
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture_rect.anchor_right = 1.0
	texture_rect.anchor_bottom = 1.0
	texture_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	texture_rect.focus_mode = Control.FOCUS_NONE
	_preview_container.add_child(texture_rect)


func _on_fence_upgrade_selected():
	"""Handle fence upgrade selection"""
	_selection_type = SelectionType.FENCE_UPGRADE
	_selected_blueprint = null

	# Clear 3D preview
	_clear_preview()

	# Update UI
	_info_label.text = "Upgrade your home base fence. Choose full price (100% refund) or half price (no refund)."
	_cost_label.text = "Full: 400 rust | Half: 200 rust"
	_cost_label.visible = true
	_purchase_button.text = "Choose Option"
	_purchase_button.disabled = false


func _on_structure_selected(blueprint: StructureBlueprintLibrary.StructureBlueprint):
	"""Handle structure blueprint selection"""
	_selection_type = SelectionType.STRUCTURE
	_selected_blueprint = blueprint

	# Update 3D preview
	_show_structure_preview(blueprint)

	# Update UI
	_info_label.text = blueprint.description
	if blueprint.rust_block_cost == 0:
		_cost_label.text = "FREE!"
	else:
		_cost_label.text = "Cost: " + str(blueprint.rust_block_cost) + " Rust Blocks"
	_cost_label.visible = true
	_purchase_button.text = "Purchase Blueprint"

	# Check if player can afford it
	if _rust_count >= blueprint.rust_block_cost:
		_purchase_button.disabled = false
	else:
		_purchase_button.disabled = true


func _show_structure_preview(blueprint: StructureBlueprintLibrary.StructureBlueprint):
	"""Display 3D preview of a structure blueprint by baking voxels to mesh"""
	print("📦 Previewing blueprint: %s (size: %s)" % [blueprint.name, blueprint.size])

	# Clear existing preview
	_clear_preview()

	# Load voxel library
	var voxel_library = load("res://blocky_game/blocks/voxel_library.tres")

	# Find the largest structure dimensions across all blueprints
	var all_blueprints = StructureBlueprintLibrary.get_all_blueprints()
	var max_x = 0
	var max_y = 0
	var max_z = 0
	for bp in all_blueprints:
		if bp.size.x > max_x:
			max_x = bp.size.x
		if bp.size.y > max_y:
			max_y = bp.size.y
		if bp.size.z > max_z:
			max_z = bp.size.z

	# Add padding for mesher and visual space (5 voxels on each side = +10 total)
	var preview_size_x = max_x + 10
	var preview_size_y = max_y + 10
	var preview_size_z = max_z + 10

	# Create fixed-size buffer for all previews (consistent scale)
	var voxels = VoxelBuffer.new()
	voxels.create(preview_size_x, preview_size_y, preview_size_z)

	# Fill buffer with AIR (0) to ensure clean slate
	voxels.fill(0, VoxelBuffer.CHANNEL_TYPE)

	# Calculate offset to center structure in X/Z, place at floor for Y
	var offset_x = (preview_size_x - blueprint.size.x) / 2
	var offset_y = 5  # Place on floor with 5-voxel padding below
	var offset_z = (preview_size_z - blueprint.size.z) / 2

	# Place each voxel in the buffer with centering offset
	var voxels_placed = 0
	for voxel_data in blueprint.blocks:
		var pos: Vector3i = voxel_data.pos
		var voxel_name: String = voxel_data.voxel_name

		# Validate position is within structure bounds
		if pos.x < 0 or pos.x >= blueprint.size.x or \
		   pos.y < 0 or pos.y >= blueprint.size.y or \
		   pos.z < 0 or pos.z >= blueprint.size.z:
			push_warning("TownManagerModal: Invalid voxel position %s in blueprint '%s'" % [pos, blueprint.name])
			continue

		# Get voxel model index from library by name
		var voxel_id = voxel_library.get_model_index_from_resource_name(voxel_name)
		if voxel_id == -1:
			push_warning("TownManagerModal: Voxel model '%s' not found in library!" % voxel_name)
			continue

		# Set voxel in buffer with centering offset
		var final_x = pos.x + offset_x
		var final_y = pos.y + offset_y
		var final_z = pos.z + offset_z
		# IMPORTANT: VoxelBuffer.set_voxel signature is (value, x, y, z, channel)
		voxels.set_voxel(voxel_id, final_x, final_y, final_z, VoxelBuffer.CHANNEL_TYPE)
		voxels_placed += 1

	# Create mesher and generate mesh directly from buffer (no need for extra padding)
	var mesher = VoxelMesherBlocky.new()
	mesher.set_library(voxel_library)

	# Build mesh (returns a Mesh directly, not arrays)
	var materials = []
	var generated_mesh = mesher.build_mesh(voxels, materials)

	if generated_mesh:
		# Create MeshInstance3D to display it
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = generated_mesh
		mesh_instance.name = "StructurePreview"

		# Apply materials returned by build_mesh
		if materials.size() > 0:
			for i in range(materials.size()):
				generated_mesh.surface_set_material(i, materials[i])

		# Center the mesh in the preview (based on preview area size, not structure size)
		var center_offset = Vector3(
			preview_size_x / 2.0,
			preview_size_y / 2.0,
			preview_size_z / 2.0
		)
		mesh_instance.position = -center_offset

		_preview_scene.add_child(mesh_instance)
	else:
		print("⚠️ TownManagerModal: Failed to generate mesh for blueprint '%s'" % blueprint.name)

	# Calculate camera distance based on ACTUAL structure size, not preview area
	# This ensures small structures don't appear tiny due to max-size camera positioning
	var structure_max_dimension = max(blueprint.size.x, max(blueprint.size.y, blueprint.size.z))
	_camera_distance = structure_max_dimension * 1.5  # 1.5x multiplier for good framing
	_camera_distance = max(5.0, _camera_distance)  # Minimum distance to avoid clipping
	_update_camera_transform()


func _clear_preview():
	"""Clear all preview meshes immediately"""
	# Remove all MeshInstance3D children (structure previews)
	for child in _preview_scene.get_children():
		if child is MeshInstance3D:
			child.queue_free()


func _get_block_color(block_name: String) -> Color:
	"""Get a representative color for a block type based on its name"""
	# Common block colors
	if "plank" in block_name or "wood" in block_name:
		return Color(0.6, 0.4, 0.2)  # Brown wood
	elif "stone" in block_name or "cobble" in block_name:
		return Color(0.5, 0.5, 0.5)  # Gray stone
	elif "brick" in block_name:
		return Color(0.7, 0.3, 0.2)  # Red brick
	elif "dirt" in block_name or "soil" in block_name:
		return Color(0.4, 0.3, 0.2)  # Dark brown
	elif "grass" in block_name:
		return Color(0.3, 0.6, 0.2)  # Green
	elif "sand" in block_name:
		return Color(0.9, 0.8, 0.5)  # Tan
	elif "snow" in block_name or "ice" in block_name:
		return Color(0.9, 0.9, 1.0)  # White/blue
	elif "glass" in block_name:
		return Color(0.7, 0.9, 1.0, 0.6)  # Transparent blue
	elif "metal" in block_name or "iron" in block_name or "steel" in block_name:
		return Color(0.6, 0.6, 0.7)  # Metallic gray
	elif "gold" in block_name:
		return Color(1.0, 0.8, 0.2)  # Gold
	elif "concrete" in block_name or "cement" in block_name:
		return Color(0.6, 0.6, 0.6)  # Light gray
	else:
		# Default fallback color
		return Color(0.7, 0.6, 0.5)  # Neutral beige


func _update_camera_transform():
	"""Update camera position based on rotation and distance"""
	var pitch_rad = deg_to_rad(_camera_rotation.x)
	var yaw_rad = deg_to_rad(_camera_rotation.y)

	var x = _camera_distance * cos(pitch_rad) * sin(yaw_rad)
	var y = _camera_distance * sin(pitch_rad)
	var z = _camera_distance * cos(pitch_rad) * cos(yaw_rad)

	_preview_camera.position = Vector3(x, y, z)
	_preview_camera.look_at(Vector3.ZERO, Vector3.UP)


func _update_rust_balance():
	"""Update rust block count from inventory"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var inventory = player.get_node_or_null("Inventory")
	if not inventory or not inventory.has_method("get_rust_block_count"):
		return

	_rust_count = inventory.get_rust_block_count()

	# Update balance label
	var balance_label = get_node_or_null("Panel/VBoxContainer/RustBalanceLabel")
	if balance_label:
		balance_label.text = "Rust Blocks: " + str(_rust_count)


func _on_purchase_pressed():
	"""Handle purchase button press"""
	match _selection_type:
		SelectionType.FENCE_UPGRADE:
			_handle_fence_upgrade_purchase()
		SelectionType.STRUCTURE:
			_handle_structure_purchase()


func _handle_fence_upgrade_purchase():
	"""Show fence upgrade options dialog"""
	# Create choice dialog
	var dialog = ConfirmationDialog.new()
	dialog.title = "Fence Upgrade Options"
	dialog.dialog_text = "Choose your fence upgrade plan:\n\n" + \
		"Full Price (400 rust): Get 100% refund when upgrading again\n" + \
		"Half Price (200 rust): No refund when upgrading\n\n" + \
		"Click OK to choose Full Price, or Cancel to choose Half Price."
	dialog.ok_button_text = "Full Price (400 rust)"
	dialog.cancel_button_text = "Half Price (200 rust)"
	dialog.exclusive = true

	# Store previous mouse mode
	var previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Connect Full Price choice
	dialog.confirmed.connect(func():
		Input.mouse_mode = previous_mouse_mode
		dialog.queue_free()
		_show_block_selector_for_fence(true)  # full_price = true
	)

	# Connect Half Price choice (cancel button)
	dialog.canceled.connect(func():
		Input.mouse_mode = previous_mouse_mode
		dialog.queue_free()
		_show_block_selector_for_fence(false)  # full_price = false
	)

	# Also handle close button (X) - treat as cancel
	dialog.close_requested.connect(func():
		Input.mouse_mode = previous_mouse_mode
		dialog.queue_free()
	)

	# Add to game tree and show
	var game = get_tree().root.get_node("Main/Game")
	if game:
		game.add_child(dialog)
		dialog.popup_centered()


func _show_block_selector_for_fence(full_price: bool):
	"""Show block selector to choose fence material"""
	# Load BlockSelectorModal in FREE mode
	var ShopModal = load("res://blocky_game/gui/BlockSelectorModal.gd")
	var modal = ShopModal.new(ShopModal.ShopType.FREE)

	# Get game node
	var game = get_tree().root.get_node("Main/Game")
	if game:
		game.add_child(modal)

	# Connect selection signal
	if modal.has_signal("block_selected"):
		modal.block_selected.connect(func(block_id: int, _count: int):
			print("✅ Fence material selected: Block ID %d" % block_id)
			# Emit fence upgrade signal
			fence_upgraded.emit(full_price, block_id)
			# Close this modal
			modal_closed.emit()
			queue_free()
		)


func _handle_structure_purchase():
	"""Handle structure blueprint purchase - Give player a blueprint block"""
	if not _selected_blueprint:
		return

	# Get player and inventory
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("❌ Player not found!")
		return

	var inventory = player.get_node_or_null("Inventory")
	if not inventory:
		print("❌ Inventory not found!")
		return

	# Check if this is a land expansion (special handling)
	var is_expansion = _selected_blueprint.category == "land_expansion"
	var actual_cost = _selected_blueprint.rust_block_cost

	if is_expansion:
		# Check if free claim available
		var has_claimed_free = false
		if _selected_blueprint.name == "wilderness_expansion":
			has_claimed_free = player.get_meta("claimed_free_wilderness", false)
		elif _selected_blueprint.name == "construction_platform":
			has_claimed_free = player.get_meta("claimed_free_construction", false)
		elif _selected_blueprint.name == "terrain_extraction":
			has_claimed_free = player.get_meta("claimed_free_extraction", false)
			# Terrain extraction is ALWAYS free, but only once
			if has_claimed_free:
				print("❌ You can only claim ONE Terrain Extraction (already used)!")
				return
			actual_cost = 0  # Always free

		# First time is FREE (for wilderness and construction)
		if not has_claimed_free and _selected_blueprint.name != "terrain_extraction":
			actual_cost = 0
			print("🎁 First %s is FREE!" % _selected_blueprint.display_name)

	# Check if player can afford it
	if _rust_count < actual_cost:
		print("❌ Not enough rust blocks!")
		return

	# Deduct rust blocks
	if actual_cost > 0:
		if inventory.has_method("remove_rust_blocks"):
			inventory.remove_rust_blocks(actual_cost)

	# Mark free claim as used for expansions
	if is_expansion and actual_cost == 0:
		if _selected_blueprint.name == "wilderness_expansion":
			player.set_meta("claimed_free_wilderness", true)
		elif _selected_blueprint.name == "construction_platform":
			player.set_meta("claimed_free_construction", true)
		elif _selected_blueprint.name == "terrain_extraction":
			player.set_meta("claimed_free_extraction", true)

	# Get Blocks reference to find rune_marker
	var game = get_tree().root.get_node_or_null("Main/Game")
	if not game:
		print("❌ Game node not found!")
		return

	var blocks_node = game.get_node_or_null("Blocks")
	if not blocks_node:
		print("❌ Blocks node not found!")
		return

	var rune_marker_block = blocks_node.get_block_by_name("rune_marker")
	if not rune_marker_block:
		print("❌ rune_marker block not found!")
		return

	# Add blueprint block to inventory manually
	var block_id = rune_marker_block.base_info.id
	var added = false

	# Try to find an empty slot
	for i in range(inventory._slots.size()):
		if inventory._slots[i] == null:
			# Load InventoryItem class
			var InventoryItem = load("res://blocky_game/player/inventory_item.gd")
			var item = InventoryItem.new()
			item.type = InventoryItem.TYPE_BLOCK
			item.id = block_id
			item.count = 1
			inventory._slots[i] = item
			added = true
			break

	if not added:
		print("❌ Inventory is full! Cannot give blueprint block.")
		# Refund rust blocks if inventory is full
		if _selected_blueprint.rust_block_cost > 0 and inventory.has_method("add_rust_blocks"):
			inventory.add_rust_blocks(_selected_blueprint.rust_block_cost)
		return

	# Update inventory views
	if inventory.has_method("_update_views"):
		inventory._update_views()

	# Store blueprint name in player metadata
	var is_first_blueprint = false
	if not player.has_meta("blueprint_blocks"):
		player.set_meta("blueprint_blocks", {})
		is_first_blueprint = true  # First blueprint ever!

	var blueprint_data = player.get_meta("blueprint_blocks")

	# If blueprint_data is empty, this is also the first blueprint
	if blueprint_data.is_empty():
		is_first_blueprint = true

	# Track this blueprint purchase
	if not blueprint_data.has(_selected_blueprint.name):
		blueprint_data[_selected_blueprint.name] = {
			"display_name": _selected_blueprint.display_name,
			"blueprint_name": _selected_blueprint.name,
			"owned": true
		}

	print("✅ Purchased %s blueprint! Place the blueprint block and right-click it to build." % _selected_blueprint.display_name)

	# Emit tutorial signal if this is the first blueprint
	if is_first_blueprint:
		first_blueprint_tutorial_needed.emit()

	# Close modal
	modal_closed.emit()
	queue_free()


func _on_cancel_pressed():
	"""Handle cancel button press"""
	modal_closed.emit()
	queue_free()


func popup_centered():
	"""Show the modal in the center of the screen"""
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -500  # Half of width (1000 / 2)
	offset_top = -300   # Half of height (600 / 2)
	offset_right = 500
	offset_bottom = 300

	visible = true
