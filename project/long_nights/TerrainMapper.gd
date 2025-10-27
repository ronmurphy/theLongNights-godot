extends Control
## Terrain Mapper - Visual tool for creating new block textures
## Open with Ctrl+T, click grid cells to get coordinates and templates

var terrain_texture: Texture2D = null
var grid_size: int = 16
var cell_size: Vector2 = Vector2.ZERO  # Will be calculated based on actual image size
var selected_cell: Vector2i = Vector2i(-1, -1)
var is_visible_mapper: bool = false

# UI Elements
var terrain_image: TextureRect = null
var grid_canvas: Control = null
var grid_coordinates_text: TextEdit = null
var uv_coordinates_text: TextEdit = null
var blocks_gd_text: TextEdit = null
var obj_file_text: TextEdit = null

func _ready():
	terrain_texture = load("res://blocky_game/blocks/terrain.png")
	if terrain_texture == null:
		push_error("[TerrainMapper] Failed to load terrain.png")
		return
	
	_build_ui()
	visible = false
	print("[TerrainMapper] Ready - Press Ctrl+T to open")

func _build_ui():
	var container = VBoxContainer.new()
	container.name = "TerrainMapperContainer"
	add_child(container)
	
	var title = Label.new()
	title.text = "TERRAIN MAPPER - 16x16 Grid"
	title.add_theme_font_size_override("font_size", 24)
	container.add_child(title)
	
	var h_split = HSplitContainer.new()
	h_split.split_offset = 600
	container.add_child(h_split)
	
	# LEFT: Terrain image
	var left_panel = PanelContainer.new()
	h_split.add_child(left_panel)
	
	terrain_image = TextureRect.new()
	terrain_image.texture = terrain_texture
	terrain_image.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
	terrain_image.custom_minimum_size = Vector2(600, 600)
	left_panel.add_child(terrain_image)
	
	# Grid overlay
	grid_canvas = Control.new()
	grid_canvas.custom_minimum_size = Vector2(600, 600)
	grid_canvas.gui_input.connect(_on_grid_gui_input)
	grid_canvas.draw.connect(_on_grid_draw)
	left_panel.add_child(grid_canvas)
	grid_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# RIGHT: Info panels
	var right_scroll = ScrollContainer.new()
	right_scroll.custom_minimum_size = Vector2(400, 600)
	h_split.add_child(right_scroll)
	
	var right_vbox = VBoxContainer.new()
	right_scroll.add_child(right_vbox)
	
	# Grid Coordinates
	var grid_label = Label.new()
	grid_label.text = "GRID COORDINATES (x, y)"
	grid_label.add_theme_font_size_override("font_size", 14)
	right_vbox.add_child(grid_label)
	
	grid_coordinates_text = TextEdit.new()
	grid_coordinates_text.custom_minimum_size = Vector2(350, 40)
	grid_coordinates_text.text = "Click a grid cell"
	right_vbox.add_child(grid_coordinates_text)
	
	# UV Coordinates
	var uv_label = Label.new()
	uv_label.text = "UV COORDINATES"
	uv_label.add_theme_font_size_override("font_size", 14)
	right_vbox.add_child(uv_label)
	
	uv_coordinates_text = TextEdit.new()
	uv_coordinates_text.custom_minimum_size = Vector2(350, 60)
	uv_coordinates_text.text = "U: 0.0 - 0.0625\nV: 0.0 - 0.0625"
	right_vbox.add_child(uv_coordinates_text)
	
	# blocks.gd Template
	var blocks_label = Label.new()
	blocks_label.text = "BLOCKS.GD TEMPLATE"
	blocks_label.add_theme_font_size_override("font_size", 12)
	right_vbox.add_child(blocks_label)
	
	blocks_gd_text = TextEdit.new()
	blocks_gd_text.custom_minimum_size = Vector2(350, 100)
	blocks_gd_text.text = "_create_block({\n    \"name\": \"new_block\",\n    \"gui_model\": \"new_block.obj\"\n})"
	right_vbox.add_child(blocks_gd_text)
	
	# OBJ File Template
	var obj_label = Label.new()
	obj_label.text = "OBJ FILE TEMPLATE"
	obj_label.add_theme_font_size_override("font_size", 12)
	right_vbox.add_child(obj_label)
	
	obj_file_text = TextEdit.new()
	obj_file_text.custom_minimum_size = Vector2(350, 150)
	obj_file_text.text = "Copy from dirt.obj and update vt values"
	right_vbox.add_child(obj_file_text)
	
	# Close/Copy buttons
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 10)
	right_vbox.add_child(button_container)
	
	var copy_button = Button.new()
	copy_button.text = "COPY ALL"
	copy_button.custom_minimum_size = Vector2(150, 40)
	copy_button.pressed.connect(_on_copy_all_pressed)
	button_container.add_child(copy_button)
	
	var close_button = Button.new()
	close_button.text = "CLOSE (Ctrl+T)"
	close_button.custom_minimum_size = Vector2(150, 40)
	close_button.pressed.connect(_close_mapper)
	button_container.add_child(close_button)

func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T and event.ctrl_pressed:
			get_tree().root.set_input_as_handled()
			if is_visible_mapper:
				_close_mapper()
			else:
				_open_mapper()

func _open_mapper():
	is_visible_mapper = true
	visible = true
	
	# Calculate cell size based on grid_canvas actual size
	if grid_canvas:
		cell_size = grid_canvas.size / grid_size
		grid_canvas.queue_redraw()
	
	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Hide PartyUI
	var party_ui = get_node_or_null("/root/Main/Game/PartyUI")
	if party_ui:
		party_ui.visible = false
	
	print("[TerrainMapper] Opened")

func _close_mapper():
	is_visible_mapper = false
	visible = false
	selected_cell = Vector2i(-1, -1)
	if grid_canvas:
		grid_canvas.queue_redraw()
	
	# Release mouse (back to normal)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Show PartyUI
	var party_ui = get_node_or_null("/root/Main/Game/PartyUI")
	if party_ui:
		party_ui.visible = true
	
	print("[TerrainMapper] Closed")

func _on_copy_all_pressed():
	if selected_cell.x < 0 or selected_cell.y < 0:
		print("[TerrainMapper] No cell selected")
		return
	
	# Compile all information into a formatted string
	var all_info = ""
	all_info += "=== TERRAIN MAPPER DATA ===\n"
	all_info += "Grid: (%d, %d)\n" % [selected_cell.x, selected_cell.y]
	all_info += "\n--- UV COORDINATES ---\n"
	all_info += uv_coordinates_text.text
	all_info += "\n\n--- BLOCKS.GD TEMPLATE ---\n"
	all_info += blocks_gd_text.text
	all_info += "\n\n--- OBJ FILE TEMPLATE ---\n"
	all_info += obj_file_text.text
	
	# Copy to clipboard
	DisplayServer.clipboard_set(all_info)
	print("[TerrainMapper] Copied to clipboard!")

func _on_grid_gui_input(event: InputEvent):
	if not is_visible_mapper:
		return
	
	# Consume ALL input events while mapper is visible (including scrollwheel)
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		get_tree().root.set_input_as_handled()
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if grid_canvas == null:
			return
		
		var local_pos = grid_canvas.get_local_mouse_position()
		var grid_pos = Vector2i(
			int(local_pos.x / cell_size.x),
			int(local_pos.y / cell_size.y)
		)
		
		grid_pos.x = clampi(grid_pos.x, 0, grid_size - 1)
		grid_pos.y = clampi(grid_pos.y, 0, grid_size - 1)
		
		selected_cell = grid_pos
		_update_info_display()
		if grid_canvas:
			grid_canvas.queue_redraw()

func _on_grid_draw():
	if not is_visible_mapper or grid_canvas == null:
		return
	
	# Draw grid
	for x in range(grid_size + 1):
		var px = x * cell_size.x
		grid_canvas.draw_line(Vector2(px, 0), Vector2(px, grid_canvas.size.y), Color(0.3, 0.3, 0.3, 0.5), 1.0)
	
	for y in range(grid_size + 1):
		var py = y * cell_size.y
		grid_canvas.draw_line(Vector2(0, py), Vector2(grid_canvas.size.x, py), Color(0.3, 0.3, 0.3, 0.5), 1.0)
	
	# Highlight selected
	if selected_cell.x >= 0 and selected_cell.y >= 0:
		var rect = Rect2(Vector2(selected_cell) * cell_size, cell_size)
		grid_canvas.draw_rect(rect, Color(0, 1, 0, 0.2), false, 2.0)

func _update_info_display():
	if selected_cell.x < 0 or selected_cell.y < 0:
		return
	
	var u_min = (selected_cell.x * (1.0 / grid_size))
	var u_max = ((selected_cell.x + 1) * (1.0 / grid_size))
	var v_min = (selected_cell.y * (1.0 / grid_size))
	var v_max = ((selected_cell.y + 1) * (1.0 / grid_size))
	
	grid_coordinates_text.text = "(%d, %d)" % [selected_cell.x, selected_cell.y]
	
	uv_coordinates_text.text = "U: %.4f - %.4f\nV: %.4f - %.4f" % [u_min, u_max, v_min, v_max]
	
	var block_name = "new_block_%d_%d" % [selected_cell.x, selected_cell.y]
	blocks_gd_text.text = "_create_block({\n    \"name\": \"%s\",\n    \"gui_model\": \"%s.obj\",\n    \"rotation_type\": ROTATION_TYPE_NONE,\n    \"voxels\": [\"%s\"],\n    \"transparent\": false\n})" % [block_name, block_name, block_name]
	
	var v_min_obj = 1.0 - v_max
	var v_max_obj = 1.0 - v_min
	
	var uv_template = ""
	for face in range(6):
		uv_template += "# Face %d:\nvt %.4f %.4f\nvt %.4f %.4f\nvt %.4f %.4f\nvt %.4f %.4f\n\n" % [
			face + 1,
			u_min, v_max_obj,
			u_max, v_max_obj,
			u_max, v_min_obj,
			u_min, v_min_obj
		]
	
	obj_file_text.text = "# Grid: (%d, %d)\n# Copy from dirt.obj and replace vt lines:\n\n%s" % [selected_cell.x, selected_cell.y, uv_template]

func _process(_delta):
	if is_visible_mapper and grid_canvas != null:
		grid_canvas.queue_redraw()
