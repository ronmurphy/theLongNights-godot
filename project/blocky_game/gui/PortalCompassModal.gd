extends Control

# Portal Compass Navigation Modal (Phase 4a+4b - List View & 3D Map View)
# Shows all visited ruins in a scrollable list OR 3D wireframe map
# Player can select a destination and teleport there

signal destination_selected(ruin_data: RuinRegistry.RuinData)
signal modal_closed

enum ViewMode { LIST, MAP_3D }

var _selected_ruin: RuinRegistry.RuinData = null
var _ruin_buttons: Array[Button] = []
var _current_view: ViewMode = ViewMode.LIST

# List view references
@onready var _title_label: Label
@onready var _scroll_container: ScrollContainer
@onready var _ruin_list_container: VBoxContainer
@onready var _travel_button: Button
@onready var _cancel_button: Button

# 3D map view references
var _map_container: Control
var _sub_viewport: SubViewport
var _map_camera: Camera3D
var _map_scene: Node3D
var _ruin_spheres: Dictionary = {}  # ruin_name -> MeshInstance3D
var _camera_distance: float = 50.0
var _camera_rotation: Vector2 = Vector2(45, 45)  # pitch, yaw in degrees
var _is_dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

# Toggle buttons
var _list_view_button: Button
var _map_view_button: Button


func _ready():
	# Create UI structure dynamically
	_build_ui()

	# Populate with visited ruins
	_populate_ruin_list()

	# Show the modal centered
	popup_centered()


func _build_ui():
	# Main panel background
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(700, 600)
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
	_title_label.text = "🧭 Portal Compass - Select Destination"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	main_vbox.add_child(_title_label)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(spacer1)

	# View toggle buttons
	var toggle_hbox = HBoxContainer.new()
	toggle_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(toggle_hbox)

	_list_view_button = Button.new()
	_list_view_button.text = "📋 List View"
	_list_view_button.custom_minimum_size = Vector2(140, 35)
	_list_view_button.toggle_mode = true
	_list_view_button.button_pressed = true  # Start in list view
	_list_view_button.pressed.connect(_on_view_toggle.bind(ViewMode.LIST))
	toggle_hbox.add_child(_list_view_button)

	var toggle_spacer = Control.new()
	toggle_spacer.custom_minimum_size = Vector2(20, 0)
	toggle_hbox.add_child(toggle_spacer)

	_map_view_button = Button.new()
	_map_view_button.text = "🗺️ Map View"
	_map_view_button.custom_minimum_size = Vector2(140, 35)
	_map_view_button.toggle_mode = true
	_map_view_button.pressed.connect(_on_view_toggle.bind(ViewMode.MAP_3D))
	toggle_hbox.add_child(_map_view_button)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(spacer2)

	# Instructions label
	var instructions = Label.new()
	instructions.name = "Instructions"
	instructions.text = "Click a ruin to select your destination"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(instructions)

	# Spacer
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(spacer3)

	# LIST VIEW: Scroll container for ruin list
	_scroll_container = ScrollContainer.new()
	_scroll_container.name = "ListViewContainer"
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.custom_minimum_size = Vector2(0, 400)
	main_vbox.add_child(_scroll_container)

	# VBox inside scroll for ruin buttons
	_ruin_list_container = VBoxContainer.new()
	_ruin_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(_ruin_list_container)

	# MAP VIEW: 3D map container (hidden by default)
	_map_container = Control.new()
	_map_container.name = "MapViewContainer"
	_map_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_container.custom_minimum_size = Vector2(0, 400)
	_map_container.visible = false
	main_vbox.add_child(_map_container)

	_build_3d_map()

	# Spacer
	var spacer4 = Control.new()
	spacer4.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(spacer4)

	# Bottom buttons
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(button_hbox)

	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.custom_minimum_size = Vector2(120, 40)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	button_hbox.add_child(_cancel_button)

	# Spacer between buttons
	var button_spacer = Control.new()
	button_spacer.custom_minimum_size = Vector2(20, 0)
	button_hbox.add_child(button_spacer)

	_travel_button = Button.new()
	_travel_button.text = "Travel"
	_travel_button.custom_minimum_size = Vector2(120, 40)
	_travel_button.disabled = true  # Disabled until a ruin is selected
	_travel_button.pressed.connect(_on_travel_pressed)
	button_hbox.add_child(_travel_button)


func _populate_ruin_list():
	var visited_ruins = RuinRegistry.get_visited_ruins()

	if visited_ruins.is_empty():
		var no_ruins_label = Label.new()
		no_ruins_label.text = "No ruins visited yet.\nExplore more to unlock destinations!"
		no_ruins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_ruins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_ruin_list_container.add_child(no_ruins_label)
		return

	# Create a button for each visited ruin
	for ruin in visited_ruins:
		var ruin_button = Button.new()
		ruin_button.custom_minimum_size = Vector2(0, 50)
		ruin_button.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Build button text with portal type indicators
		var portal_icons = []
		for stone in ruin.teleport_stones:
			match stone.stone_type:
				RuinRegistry.StoneType.NORMAL:
					portal_icons.append("🔵")
				RuinRegistry.StoneType.RETURN:
					portal_icons.append("💚")
				RuinRegistry.StoneType.HOME:
					portal_icons.append("🟣")
				RuinRegistry.StoneType.COMBAT:
					portal_icons.append("🔴")

		var button_text = ruin.ruin_name + "  " + " ".join(portal_icons)

		# Add visit count info
		if ruin.visit_count > 1:
			button_text += "  (visited " + str(ruin.visit_count) + "x)"

		ruin_button.text = button_text

		# Store ruin data reference
		ruin_button.set_meta("ruin_data", ruin)

		# Connect button press
		ruin_button.pressed.connect(_on_ruin_selected.bind(ruin, ruin_button))

		_ruin_list_container.add_child(ruin_button)
		_ruin_buttons.append(ruin_button)


func _on_ruin_selected(ruin: RuinRegistry.RuinData, button: Button):
	"""Called when player clicks a ruin in the list"""
	_selected_ruin = ruin

	# Highlight selected button, unhighlight others
	for btn in _ruin_buttons:
		if btn == button:
			btn.modulate = Color(0.7, 1.0, 0.7)  # Green tint for selected
		else:
			btn.modulate = Color(1.0, 1.0, 1.0)  # Normal

	# Enable travel button
	_travel_button.disabled = false

	print("Selected destination: ", ruin.ruin_name)


func _on_travel_pressed():
	"""Called when player clicks Travel button"""
	if _selected_ruin == null:
		return

	# Emit signal with selected ruin
	destination_selected.emit(_selected_ruin)

	# Close modal
	queue_free()


func _on_cancel_pressed():
	"""Called when player clicks Cancel button"""
	modal_closed.emit()
	queue_free()


func _build_3d_map():
	"""Create the 3D map view with SubViewport"""
	# Create SubViewport for 3D rendering
	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(660, 400)
	_sub_viewport.transparent_bg = false
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_map_container.add_child(_sub_viewport)

	# Create 3D scene root
	_map_scene = Node3D.new()
	_sub_viewport.add_child(_map_scene)

	# Create camera
	_map_camera = Camera3D.new()
	_map_camera.position = Vector3(0, 0, _camera_distance)
	_map_scene.add_child(_map_camera)

	# Add ambient light
	var env = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.05, 0.1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.4, 0.5)
	env.environment = environment
	_map_scene.add_child(env)

	# Create TextureRect to display the viewport
	var texture_rect = TextureRect.new()
	texture_rect.texture = _sub_viewport.get_texture()
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.custom_minimum_size = Vector2(660, 400)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	_map_container.add_child(texture_rect)

	# Populate 3D map with ruin spheres
	_populate_3d_map()


func _populate_3d_map():
	"""Create glowing spheres for each visited ruin"""
	var visited_ruins = RuinRegistry.get_visited_ruins()

	if visited_ruins.is_empty():
		return

	# Find center position of all ruins (for centering the view)
	var center = Vector3.ZERO
	for ruin in visited_ruins:
		center += ruin.position
	center /= visited_ruins.size()

	# Create sphere for each ruin
	for ruin in visited_ruins:
		# Create sphere mesh
		var sphere = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 2.0
		sphere_mesh.height = 4.0
		sphere.mesh = sphere_mesh

		# Position relative to center
		var relative_pos = ruin.position - center
		# Scale down the positions to fit nicely in view (divide by 10)
		sphere.position = relative_pos / 10.0

		# Create glowing material based on portal stone types
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true

		# Determine color based on primary portal stone type
		var primary_color = _get_ruin_color(ruin)
		material.albedo_color = primary_color
		material.emission = primary_color
		material.emission_energy_multiplier = 2.0

		sphere.material_override = material

		# Store reference (use ruin_name as key since it's unique)
		_ruin_spheres[ruin.ruin_name] = sphere
		sphere.set_meta("ruin_data", ruin)

		# Add to scene
		_map_scene.add_child(sphere)

		# Add text label above sphere
		var label_3d = Label3D.new()
		label_3d.text = ruin.ruin_name
		label_3d.pixel_size = 0.02
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_3d.position = sphere.position + Vector3(0, 3, 0)
		label_3d.modulate = Color(1, 1, 1, 0.8)
		_map_scene.add_child(label_3d)

	# Update camera to look at center
	_update_camera_transform()


func _get_ruin_color(ruin: RuinRegistry.RuinData) -> Color:
	"""Get color for ruin based on portal stone type"""
	if ruin.teleport_stones.is_empty():
		return Color(0.5, 0.5, 0.5)  # Gray for no portals

	# Use the first portal's color
	var stone_type = ruin.teleport_stones[0].stone_type
	match stone_type:
		RuinRegistry.StoneType.NORMAL:
			return Color(0.4, 0.7, 1.0)  # Blue
		RuinRegistry.StoneType.RETURN:
			return Color(0.2, 1.0, 0.4)  # Green
		RuinRegistry.StoneType.HOME:
			return Color(0.8, 0.4, 1.0)  # Purple
		RuinRegistry.StoneType.COMBAT:
			return Color(1.0, 0.2, 0.2)  # Red
		_:
			return Color(0.5, 0.5, 0.5)  # Gray fallback


func _on_view_toggle(mode: ViewMode):
	"""Toggle between list and map view"""
	_current_view = mode

	# Update button states
	_list_view_button.button_pressed = (mode == ViewMode.LIST)
	_map_view_button.button_pressed = (mode == ViewMode.MAP_3D)

	# Show/hide appropriate containers
	_scroll_container.visible = (mode == ViewMode.LIST)
	_map_container.visible = (mode == ViewMode.MAP_3D)

	# Update instructions
	var instructions = get_node_or_null("Panel/VBoxContainer/Instructions")
	if instructions:
		if mode == ViewMode.LIST:
			instructions.text = "Click a ruin to select your destination"
		else:
			instructions.text = "Drag to rotate • Scroll to zoom • Click sphere to select"

	print("Switched to ", "LIST" if mode == ViewMode.LIST else "MAP" , " view")


func _update_camera_transform():
	"""Update camera position based on rotation and distance"""
	# Convert rotation to radians
	var pitch_rad = deg_to_rad(_camera_rotation.x)
	var yaw_rad = deg_to_rad(_camera_rotation.y)

	# Calculate camera position on a sphere
	var x = _camera_distance * cos(pitch_rad) * sin(yaw_rad)
	var y = _camera_distance * sin(pitch_rad)
	var z = _camera_distance * cos(pitch_rad) * cos(yaw_rad)

	_map_camera.position = Vector3(x, y, z)
	_map_camera.look_at(Vector3.ZERO, Vector3.UP)


func _input(event: InputEvent):
	"""Handle input for 3D map view"""
	if _current_view != ViewMode.MAP_3D:
		return

	# Mouse drag to rotate camera
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed
			if event.pressed:
				_last_mouse_pos = event.position

		# Scroll wheel to zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = max(20.0, _camera_distance - 5.0)
			_update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = min(100.0, _camera_distance + 5.0)
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


func popup_centered():
	"""Show the modal in the center of the screen"""
	# Center the control
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -350  # Half of width (700 / 2)
	offset_top = -300   # Half of height (600 / 2)
	offset_right = 350
	offset_bottom = 300

	# Make visible
	visible = true
