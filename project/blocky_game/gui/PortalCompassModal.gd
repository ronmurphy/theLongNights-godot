extends Control

# Portal Compass Navigation Modal (Phase 4a+4b - Side-by-side List & 3D Map)
# Shows all visited ruins in a scrollable list AND 3D wireframe map simultaneously
# Player can select a destination from either view and teleport there

signal destination_selected(ruin_data: RuinRegistry.RuinData)
signal modal_closed

var _selected_ruin: RuinRegistry.RuinData = null
var _ruin_buttons: Array[Button] = []

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

# Camera animation
var _is_animating_camera: bool = false
var _anim_start_rotation: Vector2 = Vector2.ZERO
var _anim_start_distance: float = 50.0
var _anim_target_rotation: Vector2 = Vector2.ZERO
var _anim_target_distance: float = 50.0
var _anim_progress: float = 0.0
var _anim_duration: float = 0.8  # seconds
var _map_center: Vector3 = Vector3.ZERO  # Center point of all ruins


func _ready():
	# Create UI structure dynamically
	_build_ui()

	# Populate with visited ruins
	_populate_ruin_list()

	# IMPORTANT: Force mouse to be visible when modal opens
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Show the modal centered
	popup_centered()


func _process(delta):
	"""Continuously enforce mouse visibility and handle camera animation"""
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Handle camera animation
	if _is_animating_camera:
		_anim_progress += delta / _anim_duration
		if _anim_progress >= 1.0:
			_anim_progress = 1.0
			_is_animating_camera = false

		# Smooth easing function (ease-in-out)
		var t = _anim_progress
		t = t * t * (3.0 - 2.0 * t)  # Smoothstep

		# Interpolate rotation and distance
		_camera_rotation = _anim_start_rotation.lerp(_anim_target_rotation, t)
		_camera_distance = lerp(_anim_start_distance, _anim_target_distance, t)

		_update_camera_transform()


func _input(event: InputEvent):
	"""Handle input for 3D map camera controls"""
	# Mouse drag to rotate camera (when over the map area)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = event.pressed
			if event.pressed:
				_last_mouse_pos = event.position
				# Stop camera animation if user starts dragging
				_is_animating_camera = false

		# Scroll wheel to zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_distance = max(20.0, _camera_distance - 5.0)
			_update_camera_transform()
			# Stop camera animation if user zooms
			_is_animating_camera = false
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_distance = min(100.0, _camera_distance + 5.0)
			_update_camera_transform()
			# Stop camera animation if user zooms
			_is_animating_camera = false

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


func _gui_input(event):
	"""Ensure mouse stays visible during GUI interactions"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# FORCE mouse to stay visible when modal is open
			if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_ui():
	# Main panel background
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(1000, 600)
	panel.focus_mode = Control.FOCUS_NONE  # Don't steal focus
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

	# Instructions label
	var instructions = Label.new()
	instructions.name = "Instructions"
	instructions.text = "Click a ruin in the list or sphere on the map to select"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(instructions)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(spacer2)

	# Side-by-side container for list and map
	var split_hbox = HBoxContainer.new()
	split_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(split_hbox)

	# LEFT: List view with label
	var list_vbox = VBoxContainer.new()
	list_vbox.custom_minimum_size = Vector2(380, 400)
	split_hbox.add_child(list_vbox)

	var list_label = Label.new()
	list_label.text = "📋 Ruin List"
	list_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_label.add_theme_font_size_override("font_size", 16)
	list_vbox.add_child(list_label)

	var list_spacer = Control.new()
	list_spacer.custom_minimum_size = Vector2(0, 5)
	list_vbox.add_child(list_spacer)

	var list_panel = PanelContainer.new()
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_vbox.add_child(list_panel)

	_scroll_container = ScrollContainer.new()
	_scroll_container.name = "ListViewContainer"
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.focus_mode = Control.FOCUS_NONE
	list_panel.add_child(_scroll_container)

	_ruin_list_container = VBoxContainer.new()
	_ruin_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(_ruin_list_container)

	# RIGHT: 3D Map view with label
	var map_vbox = VBoxContainer.new()
	map_vbox.custom_minimum_size = Vector2(540, 400)
	map_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split_hbox.add_child(map_vbox)

	var map_label = Label.new()
	map_label.text = "🗺️ 3D Map (Drag to rotate • Scroll to zoom)"
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_label.add_theme_font_size_override("font_size", 16)
	map_vbox.add_child(map_label)

	var map_spacer = Control.new()
	map_spacer.custom_minimum_size = Vector2(0, 5)
	map_vbox.add_child(map_spacer)

	var map_panel = PanelContainer.new()
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_vbox.add_child(map_panel)

	_map_container = Control.new()
	_map_container.name = "MapViewContainer"
	_map_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_container.focus_mode = Control.FOCUS_NONE
	map_panel.add_child(_map_container)

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

	# Also highlight the sphere on the 3D map
	_highlight_sphere_on_map(ruin)

	# Animate camera to look at the selected ruin
	_animate_camera_to_ruin(ruin)

	# Enable travel button
	_travel_button.disabled = false


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
	_sub_viewport.size = Vector2i(540, 400)  # Match the map container size
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

	# Get current sky color from time system
	var sky_color = _get_current_sky_color()

	# Add environment with simple gradient background
	var env = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = sky_color.darkened(0.4)  # Darker shade for depth
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = sky_color.lightened(0.2)
	environment.ambient_light_energy = 0.6
	env.environment = environment
	_map_scene.add_child(env)

	# Create TextureRect to display the viewport - fills the container
	var texture_rect = TextureRect.new()
	texture_rect.texture = _sub_viewport.get_texture()
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture_rect.anchor_right = 1.0
	texture_rect.anchor_bottom = 1.0
	texture_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	texture_rect.focus_mode = Control.FOCUS_NONE  # Don't steal focus on scroll
	_map_container.add_child(texture_rect)

	# Populate 3D map with ruin spheres
	_populate_3d_map()


func _populate_3d_map():
	"""Create glowing spheres for each visited ruin"""
	var visited_ruins = RuinRegistry.get_visited_ruins()

	if visited_ruins.is_empty():
		return

	# Find center position of all ruins (for centering the view)
	_map_center = Vector3.ZERO
	for ruin in visited_ruins:
		_map_center += ruin.position
	_map_center /= visited_ruins.size()

	# Create sphere for each ruin
	for ruin in visited_ruins:
		# Position relative to center
		var relative_pos = ruin.position - _map_center
		# Scale down the positions to fit nicely in view (divide by 10)
		var sphere_pos = relative_pos / 10.0

		# Create clickable container (StaticBody3D for mouse detection)
		var clickable = StaticBody3D.new()
		clickable.position = sphere_pos
		clickable.set_meta("ruin_data", ruin)

		# Create sphere mesh
		var sphere = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 2.0
		sphere_mesh.height = 4.0
		sphere.mesh = sphere_mesh

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

		# Add collision shape for mouse picking
		var collision_shape = CollisionShape3D.new()
		var shape = SphereShape3D.new()
		shape.radius = 2.0
		collision_shape.shape = shape

		# Assemble hierarchy: StaticBody3D -> [MeshInstance3D, CollisionShape3D]
		clickable.add_child(sphere)
		clickable.add_child(collision_shape)

		# Connect click event
		clickable.input_event.connect(_on_sphere_clicked.bind(ruin))

		# Store reference (use ruin_name as key since it's unique)
		_ruin_spheres[ruin.ruin_name] = sphere

		# Add to scene
		_map_scene.add_child(clickable)

		# Add text label above sphere
		var label_3d = Label3D.new()
		label_3d.text = ruin.ruin_name
		label_3d.pixel_size = 0.02
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_3d.position = sphere_pos + Vector3(0, 3, 0)
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


func _on_sphere_clicked(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int, ruin: RuinRegistry.RuinData):
	"""Called when player clicks a sphere in the 3D map"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selected_ruin = ruin

		# Highlight the sphere
		_highlight_sphere_on_map(ruin)

		# Also highlight the list button and scroll to it
		_highlight_list_button(ruin)

		# Enable travel button
		_travel_button.disabled = false


func _highlight_sphere_on_map(ruin: RuinRegistry.RuinData):
	"""Highlight a specific sphere on the map"""
	for ruin_name in _ruin_spheres:
		var sphere = _ruin_spheres[ruin_name]
		var ruin_data = sphere.get_parent().get_meta("ruin_data")

		if ruin_data == ruin:
			# Highlight selected sphere (brighten emission)
			var mat = sphere.material_override as StandardMaterial3D
			if mat:
				mat.emission_energy_multiplier = 4.0
		else:
			# Normal emission
			var mat = sphere.material_override as StandardMaterial3D
			if mat:
				mat.emission_energy_multiplier = 2.0


func _highlight_list_button(ruin: RuinRegistry.RuinData):
	"""Highlight a specific button in the list"""
	for btn in _ruin_buttons:
		var btn_ruin = btn.get_meta("ruin_data")
		if btn_ruin == ruin:
			btn.modulate = Color(0.7, 1.0, 0.7)  # Green tint for selected
			# Scroll to make button visible
			_scroll_container.ensure_control_visible(btn)
		else:
			btn.modulate = Color(1.0, 1.0, 1.0)  # Normal


func _animate_camera_to_ruin(ruin: RuinRegistry.RuinData):
	"""Smoothly animate camera to focus on a specific ruin"""
	# Calculate the sphere position in the 3D map
	var relative_pos = ruin.position - _map_center
	var sphere_pos = relative_pos / 10.0

	# Calculate ideal camera angle to look at this sphere
	# We want to position the camera so it's looking at the sphere from a nice angle
	var target_yaw = rad_to_deg(atan2(sphere_pos.x, sphere_pos.z))
	var horizontal_dist = sqrt(sphere_pos.x * sphere_pos.x + sphere_pos.z * sphere_pos.z)
	var target_pitch = rad_to_deg(atan2(sphere_pos.y, horizontal_dist))

	# Set up animation
	_anim_start_rotation = _camera_rotation
	_anim_start_distance = _camera_distance
	_anim_target_rotation = Vector2(target_pitch, target_yaw)
	_anim_target_distance = 30.0  # Zoom in a bit
	_anim_progress = 0.0
	_is_animating_camera = true


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


func popup_centered():
	"""Show the modal in the center of the screen"""
	# Center the control
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -500  # Half of width (1000 / 2)
	offset_top = -300   # Half of height (600 / 2)
	offset_right = 500
	offset_bottom = 300

	# Make visible
	visible = true


func _get_current_sky_color() -> Color:
	"""Get the current sky color from the time system"""
	# Try to get time from TimeManager
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_method("get_current_hour"):
		var hour = time_manager.get_current_hour()

		# Match the time-based colors from DayNightCycle.gd
		if hour >= 5 and hour < 7:  # Dawn (5am-7am)
			return Color(0.8, 0.5, 0.4)  # Orange/pink
		elif hour >= 7 and hour < 17:  # Day (7am-5pm)
			return Color(0.53, 0.81, 0.92)  # Sky blue
		elif hour >= 17 and hour < 19:  # Dusk (5pm-7pm)
			return Color(0.9, 0.6, 0.3)  # Orange
		else:  # Night (7pm-5am)
			return Color(0.05, 0.05, 0.15)  # Dark blue

	# Default to day sky if TimeManager not available
	return Color(0.53, 0.81, 0.92)  # Sky blue
