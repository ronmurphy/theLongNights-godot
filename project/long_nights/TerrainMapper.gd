extends Control
## Terrain Mapper - Visual tool for creating new block textures
## Open with Ctrl+T, click grid cells to get coordinates and templates

var terrain_texture: Texture2D = null
var grid_size: int = 16
var cell_size: Vector2 = Vector2.ZERO  # Will be calculated based on actual image size
var selected_cell: Vector2i = Vector2i(-1, -1)
var is_visible_mapper: bool = false

# Texture mode: single (all faces same) or multi (top/side/bottom)
enum TextureMode { SINGLE, MULTI }
var current_mode: TextureMode = TextureMode.SINGLE
var selected_cells: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(-1, -1), Vector2i(-1, -1)]  # [top, side, bottom]
var multi_selection_step: int = 0  # 0=top, 1=side, 2=bottom

# UI Elements
var terrain_image: TextureRect = null
var grid_canvas: Control = null
var sprite_preview: TextureRect
var sprite_preview_panel: Panel
var mode_button_single: Button = null
var mode_button_multi: Button = null
var mode_status_label: Label = null
var save_button: Button = null
var auto_edit_checkbox: CheckBox = null
var auto_edit_enabled: bool = false

# 3D rendering components for isometric sprite generation
var viewport_3d: SubViewport
var camera_3d: Camera3D
var cube_mesh_instance: MeshInstance3D
var cube_material: StandardMaterial3D

# OBJ file templates
const SINGLE_TEXTURE_TEMPLATE = """# Blender v2.83.0 OBJ File: 'blocks.blend'
# www.blender.org
o {BLOCK_NAME}_Cube
v 1.000000 1.000000 1.000000
v 1.000000 0.000000 1.000000
v 0.000000 1.000000 1.000000
v 0.000000 0.000000 1.000000
v 1.000000 1.000000 0.000000
v 1.000000 0.000000 0.000000
v 0.000000 1.000000 0.000000
v 0.000000 0.000000 0.000000
{VT_COORDS}
vn 0.0000 1.0000 0.0000
vn -1.0000 0.0000 0.0000
vn 0.0000 0.0000 -1.0000
vn 0.0000 -1.0000 0.0000
vn 0.0000 0.0000 1.0000
vn 1.0000 0.0000 0.0000
s off
f 1/1/1 5/2/1 7/3/1 3/4/1
f 4/5/2 3/6/2 7/7/2 8/8/2
f 8/9/3 7/10/3 5/11/3 6/12/3
f 6/13/4 2/14/4 4/15/4 8/16/4
f 2/17/5 1/18/5 3/19/5 4/20/5
f 6/21/6 5/22/6 1/23/6 2/24/6
"""

const MULTI_TEXTURE_TEMPLATE = """# Blender v2.83.0 OBJ File: 'blocks.blend'
# www.blender.org
# Multi-texture block
# Top: {TOP_GRID} | Sides: {SIDE_GRID} | Bottom: {BOTTOM_GRID}
o {BLOCK_NAME}_Cube
v 1.000000 1.000000 1.000000
v 1.000000 0.000000 1.000000
v 0.000000 1.000000 1.000000
v 0.000000 0.000000 1.000000
v 1.000000 1.000000 0.000000
v 1.000000 0.000000 0.000000
v 0.000000 1.000000 0.000000
v 0.000000 0.000000 0.000000
{VT_COORDS}
vn 0.0000 1.0000 0.0000
vn -1.0000 0.0000 0.0000
vn 0.0000 0.0000 -1.0000
vn 0.0000 -1.0000 0.0000
vn 0.0000 0.0000 1.0000
vn 1.0000 0.0000 0.0000
s off
f 1/1/1 5/2/1 7/3/1 3/4/1
f 4/5/2 3/6/2 7/7/2 8/8/2
f 8/9/3 7/10/3 5/11/3 6/12/3
f 6/13/4 2/14/4 4/15/4 8/16/4
f 2/17/5 1/18/5 3/19/5 4/20/5
f 6/21/6 5/22/6 1/23/6 2/24/6
"""

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
	
	# RIGHT: Streamlined panel - no scrolling needed
	var right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(400, 600)
	right_vbox.add_theme_constant_override("separation", 15)
	h_split.add_child(right_vbox)
	
	# Mode Selection
	var mode_label = Label.new()
	mode_label.text = "TEXTURE MODE"
	mode_label.add_theme_font_size_override("font_size", 14)
	right_vbox.add_child(mode_label)
	
	var mode_hbox = HBoxContainer.new()
	mode_hbox.add_theme_constant_override("separation", 10)
	right_vbox.add_child(mode_hbox)
	
	mode_button_single = Button.new()
	mode_button_single.text = "Single Texture"
	mode_button_single.custom_minimum_size = Vector2(165, 40)
	mode_button_single.pressed.connect(_on_mode_single_pressed)
	mode_hbox.add_child(mode_button_single)
	
	mode_button_multi = Button.new()
	mode_button_multi.text = "Multi-Texture"
	mode_button_multi.custom_minimum_size = Vector2(165, 40)
	mode_button_multi.pressed.connect(_on_mode_multi_pressed)
	mode_hbox.add_child(mode_button_multi)
	
	# Mode status label (shows which texture we're selecting in multi mode)
	mode_status_label = Label.new()
	mode_status_label.text = "Single texture mode - all faces use same texture"
	mode_status_label.add_theme_font_size_override("font_size", 12)
	mode_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_status_label.custom_minimum_size = Vector2(350, 0)
	right_vbox.add_child(mode_status_label)
	
	# Sprite Preview - centered and prominent
	var preview_container = VBoxContainer.new()
	preview_container.add_theme_constant_override("separation", 5)
	right_vbox.add_child(preview_container)
	
	var preview_title = Label.new()
	preview_title.text = "SPRITE PREVIEW"
	preview_title.add_theme_font_size_override("font_size", 14)
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_container.add_child(preview_title)
	
	sprite_preview_panel = Panel.new()
	sprite_preview_panel.custom_minimum_size = Vector2(300, 300)
	preview_container.add_child(sprite_preview_panel)
	
	var preview_label = Label.new()
	preview_label.text = "(Click to Save Sprite)"
	preview_label.position = Vector2(85, 15)
	sprite_preview_panel.add_child(preview_label)
	
	sprite_preview = TextureRect.new()
	sprite_preview.position = Vector2(86, 86)
	sprite_preview.custom_minimum_size = Vector2(128, 128)
	sprite_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_preview.gui_input.connect(_on_sprite_preview_clicked)
	sprite_preview_panel.add_child(sprite_preview)
	
	# Set up 3D rendering viewport for isometric sprites (deferred until in tree)
	call_deferred("_setup_3d_viewport")
	
	# Add flexible spacer to push buttons to bottom
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(spacer)
	
	# Auto-edit checkbox (EXPERIMENTAL)
	auto_edit_checkbox = CheckBox.new()
	auto_edit_checkbox.text = "⚠️ Auto-edit project files (EXPERIMENTAL)"
	auto_edit_checkbox.toggled.connect(_on_auto_edit_toggled)
	right_vbox.add_child(auto_edit_checkbox)
	
	# Close/Save buttons
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 10)
	right_vbox.add_child(button_container)
	
	save_button = Button.new()
	save_button.text = "SAVE BLOCK"
	save_button.custom_minimum_size = Vector2(150, 40)
	save_button.pressed.connect(_on_save_block_pressed)
	button_container.add_child(save_button)
	
	var close_button = Button.new()
	close_button.text = "CLOSE (Ctrl+T)"
	close_button.custom_minimum_size = Vector2(150, 40)
	close_button.pressed.connect(_close_mapper)
	button_container.add_child(close_button)
	
	# Set initial mode button state
	_update_mode_buttons()

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

func _on_auto_edit_toggled(enabled: bool):
	auto_edit_enabled = enabled
	if enabled:
		# Show warning when enabling
		var warning = AcceptDialog.new()
		warning.title = "⚠️ WARNING - Experimental Feature"
		warning.dialog_text = "Auto-editing will modify:\n• generator.gd\n• voxel_library.tres\n\nMAKE SURE YOU HAVE BACKUPS!\n\nIf something goes wrong, you can restore from git or backups."
		warning.size = Vector2i(450, 200)
		add_child(warning)
		warning.popup_centered()
		warning.confirmed.connect(func(): warning.queue_free())
		warning.canceled.connect(func():
			auto_edit_checkbox.button_pressed = false
			auto_edit_enabled = false
			warning.queue_free()
		)
		print("[TerrainMapper] Auto-edit ENABLED - BE CAREFUL!")
	else:
		print("[TerrainMapper] Auto-edit disabled (safe mode)")

func _on_mode_single_pressed():
	current_mode = TextureMode.SINGLE
	multi_selection_step = 0
	_reset_selection()
	_update_mode_buttons()
	_update_mode_status()
	print("[TerrainMapper] Mode: Single Texture")

func _on_mode_multi_pressed():
	current_mode = TextureMode.MULTI
	multi_selection_step = 0
	_reset_selection()
	_update_mode_buttons()
	_update_mode_status()
	print("[TerrainMapper] Mode: Multi-Texture (Top/Side/Bottom)")

func _update_mode_buttons():
	if mode_button_single and mode_button_multi:
		if current_mode == TextureMode.SINGLE:
			mode_button_single.modulate = Color(0.5, 1.0, 0.5)  # Green tint
			mode_button_multi.modulate = Color(1.0, 1.0, 1.0)  # Normal
		else:
			mode_button_single.modulate = Color(1.0, 1.0, 1.0)  # Normal
			mode_button_multi.modulate = Color(0.5, 1.0, 0.5)  # Green tint

func _update_mode_status():
	if mode_status_label:
		if current_mode == TextureMode.SINGLE:
			mode_status_label.text = "Single texture mode - all faces use same texture"
		else:
			match multi_selection_step:
				0: mode_status_label.text = "Select TOP texture (step 1/3)"
				1: mode_status_label.text = "Select SIDE texture (step 2/3)"
				2: mode_status_label.text = "Select BOTTOM texture (step 3/3)"

func _reset_selection():
	selected_cell = Vector2i(-1, -1)
	selected_cells = [Vector2i(-1, -1), Vector2i(-1, -1), Vector2i(-1, -1)]
	if grid_canvas:
		grid_canvas.queue_redraw()

func _on_save_block_pressed():
	# Check if we have valid selection(s)
	if current_mode == TextureMode.SINGLE:
		if selected_cell.x < 0 or selected_cell.y < 0:
			print("[TerrainMapper] No cell selected")
			return
	else:  # MULTI mode
		if selected_cells[0].x < 0 or selected_cells[1].x < 0 or selected_cells[2].x < 0:
			print("[TerrainMapper] Need to select all 3 textures (Top, Side, Bottom)")
			return
	
	# Show input dialog for block name
	_show_block_name_dialog()


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
		
		if current_mode == TextureMode.SINGLE:
			selected_cell = grid_pos
			_update_info_display()
		else:  # MULTI mode
			selected_cells[multi_selection_step] = grid_pos
			multi_selection_step += 1
			if multi_selection_step >= 3:
				multi_selection_step = 2  # Stay on bottom selection
			_update_mode_status()
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
	
	# Highlight selected cells
	if current_mode == TextureMode.SINGLE:
		if selected_cell.x >= 0 and selected_cell.y >= 0:
			var rect = Rect2(Vector2(selected_cell) * cell_size, cell_size)
			grid_canvas.draw_rect(rect, Color(0, 1, 0, 0.3), true)  # Green fill
			grid_canvas.draw_rect(rect, Color(0, 1, 0, 1.0), false, 2.0)  # Green border
	else:  # MULTI mode - draw with different colors
		var colors = [
			Color(1, 0, 0, 0.3),  # Red for TOP
			Color(0, 0, 1, 0.3),  # Blue for SIDE
			Color(0, 1, 0, 0.3)   # Green for BOTTOM
		]
		var border_colors = [
			Color(1, 0, 0, 1.0),  # Red border
			Color(0, 0, 1, 1.0),  # Blue border
			Color(0, 1, 0, 1.0)   # Green border
		]
		var labels = ["T", "S", "B"]
		
		for i in range(3):
			var cell = selected_cells[i]
			if cell.x >= 0 and cell.y >= 0:
				var rect = Rect2(Vector2(cell) * cell_size, cell_size)
				grid_canvas.draw_rect(rect, colors[i], true)
				grid_canvas.draw_rect(rect, border_colors[i], false, 2.0)
				# Draw label
				var label_pos = Vector2(cell) * cell_size + cell_size * 0.5
				grid_canvas.draw_string(ThemeDB.fallback_font, label_pos, labels[i], HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color.WHITE)

func _update_info_display():
	# Update display based on mode
	if current_mode == TextureMode.SINGLE:
		if selected_cell.x < 0 or selected_cell.y < 0:
			return
		_update_info_single(selected_cell)
	else:  # MULTI mode
		# Show info for the last selected cell, or combined info
		if multi_selection_step > 0:
			var last_cell = selected_cells[multi_selection_step - 1]
			if last_cell.x >= 0:
				_update_info_single(last_cell)
		
		# Generate multi-texture preview when all 3 are selected
		if selected_cells[0].x >= 0 and selected_cells[1].x >= 0 and selected_cells[2].x >= 0:
			_generate_sprite_preview()

func _update_info_single(cell: Vector2i):
	if cell.x < 0 or cell.y < 0:
		return
	
	# Generate sprite preview for single mode
	if current_mode == TextureMode.SINGLE:
		_generate_sprite_preview()

func _show_block_name_dialog():
	# Create a simple dialog for block name input
	var dialog = AcceptDialog.new()
	dialog.title = "Save Block"
	dialog.dialog_text = "Enter block name:"
	dialog.size = Vector2i(400, 150)
	add_child(dialog)
	
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)
	
	var line_edit = LineEdit.new()
	line_edit.placeholder_text = "my_block_name"
	line_edit.custom_minimum_size = Vector2(350, 30)
	vbox.add_child(line_edit)
	
	dialog.confirmed.connect(func():
		var block_name = line_edit.text.strip_edges()
		if block_name.is_empty():
			print("[TerrainMapper] Block name cannot be empty")
			return
		# Sanitize the name - remove invalid characters for filenames and const names
		block_name = block_name.to_lower().replace(" ", "_").replace("-", "_")
		# Remove any other non-alphanumeric characters except underscores
		var sanitized = ""
		for c in block_name:
			if c.is_valid_identifier() or c == "_":
				sanitized += c
		block_name = sanitized
		if block_name.is_empty():
			print("[TerrainMapper] Invalid block name after sanitization")
			return
		_save_block_files(block_name)
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	
	dialog.popup_centered()
	line_edit.grab_focus()

func _process(_delta):
	if is_visible_mapper and grid_canvas != null:
		grid_canvas.queue_redraw()


func _create_cube_mesh_with_uvs() -> ArrayMesh:
	"""Create a cube mesh with UV coordinates that map the full texture to each face"""
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Cube vertices (unit cube from 0,0,0 to 1,1,1)
	var vertices = PackedVector3Array([
		# Front face (Z+)
		Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1),
		# Back face (Z-)
		Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0),
		# Top face (Y+)
		Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0),
		# Bottom face (Y-)
		Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1),
		# Right face (X+)
		Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1),
		# Left face (X-)
		Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0),
	])
	
	# UV coordinates - each face gets the full texture (0,0 to 1,1)
	# This works because we're passing a single-tile texture
	var uvs = PackedVector2Array([
		# Front face
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0),
		# Back face
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0),
		# Top face
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0),
		# Bottom face
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0),
		# Right face
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0),
		# Left face
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0),
	])
	
	# Normals for each face
	var normals = PackedVector3Array([
		# Front face
		Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1),
		# Back face
		Vector3(0, 0, -1), Vector3(0, 0, -1), Vector3(0, 0, -1), Vector3(0, 0, -1),
		# Top face
		Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 1, 0),
		# Bottom face
		Vector3(0, -1, 0), Vector3(0, -1, 0), Vector3(0, -1, 0), Vector3(0, -1, 0),
		# Right face
		Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0),
		# Left face
		Vector3(-1, 0, 0), Vector3(-1, 0, 0), Vector3(-1, 0, 0), Vector3(-1, 0, 0),
	])
	
	# Indices for triangles (2 triangles per face, 6 faces)
	var indices = PackedInt32Array([
		0, 1, 2,  2, 3, 0,    # Front
		4, 5, 6,  6, 7, 4,    # Back
		8, 9, 10, 10, 11, 8,  # Top
		12, 13, 14, 14, 15, 12, # Bottom
		16, 17, 18, 18, 19, 16, # Right
		20, 21, 22, 22, 23, 20, # Left
	])
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return mesh


func _create_cube_mesh_with_uvs_multi() -> ArrayMesh:
	"""Create a cube mesh with UVs mapped to a 48x16 texture atlas [top][side][bottom]"""
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Same vertices as single-texture version
	var vertices = PackedVector3Array([
		# Front face (Z+)
		Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1),
		# Back face (Z-)
		Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0),
		# Top face (Y+)
		Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0),
		# Bottom face (Y-)
		Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1),
		# Right face (X+)
		Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1),
		# Left face (X-)
		Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0),
	])
	
	# UV coordinates mapped to atlas: [0-1/3=top][1/3-2/3=side][2/3-1=bottom]
	var uvs = PackedVector2Array([
		# Front face - SIDE (middle third: 1/3 to 2/3)
		Vector2(1.0/3.0, 1), Vector2(2.0/3.0, 1), Vector2(2.0/3.0, 0), Vector2(1.0/3.0, 0),
		# Back face - SIDE
		Vector2(1.0/3.0, 1), Vector2(2.0/3.0, 1), Vector2(2.0/3.0, 0), Vector2(1.0/3.0, 0),
		# Top face - TOP (first third: 0 to 1/3)
		Vector2(0, 1), Vector2(1.0/3.0, 1), Vector2(1.0/3.0, 0), Vector2(0, 0),
		# Bottom face - BOTTOM (last third: 2/3 to 1)
		Vector2(2.0/3.0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(2.0/3.0, 0),
		# Right face - SIDE
		Vector2(1.0/3.0, 1), Vector2(2.0/3.0, 1), Vector2(2.0/3.0, 0), Vector2(1.0/3.0, 0),
		# Left face - SIDE
		Vector2(1.0/3.0, 1), Vector2(2.0/3.0, 1), Vector2(2.0/3.0, 0), Vector2(1.0/3.0, 0),
	])
	
	# Same normals
	var normals = PackedVector3Array([
		Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1),
		Vector3(0, 0, -1), Vector3(0, 0, -1), Vector3(0, 0, -1), Vector3(0, 0, -1),
		Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 1, 0), Vector3(0, 1, 0),
		Vector3(0, -1, 0), Vector3(0, -1, 0), Vector3(0, -1, 0), Vector3(0, -1, 0),
		Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 0),
		Vector3(-1, 0, 0), Vector3(-1, 0, 0), Vector3(-1, 0, 0), Vector3(-1, 0, 0),
	])
	
	# Same indices
	var indices = PackedInt32Array([
		0, 1, 2,  2, 3, 0,
		4, 5, 6,  6, 7, 4,
		8, 9, 10, 10, 11, 8,
		12, 13, 14, 14, 15, 12,
		16, 17, 18, 18, 19, 16,
		20, 21, 22, 22, 23, 20,
	])
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	return mesh


func _setup_3d_viewport():
	"""Set up a 3D viewport for rendering isometric cube sprites"""
	# Create SubViewport for offscreen rendering - high res for detail
	viewport_3d = SubViewport.new()
	viewport_3d.size = Vector2i(256, 256)  # Reasonable resolution for sprite
	viewport_3d.transparent_bg = true
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport_3d.msaa_3d = Viewport.MSAA_DISABLED  # No antialiasing for pixel art
	add_child(viewport_3d)
	
	# Create camera with isometric view
	camera_3d = Camera3D.new()
	camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera_3d.size = 1.8  # Tighter framing around the cube
	viewport_3d.add_child(camera_3d)
	# Position camera for isometric view - AFTER adding to tree
	# Classic isometric angle: camera at 45° horizontal, looking DOWN from above
	camera_3d.position = Vector3(2, -2, 2)  # Negative Y to look down from above
	camera_3d.look_at(Vector3(0, 0, 0), Vector3.UP)
	
	# Create ambient environment for better visibility
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1, 1, 1)
	environment.ambient_light_energy = 1.0
	var world_env = WorldEnvironment.new()
	world_env.environment = environment
	viewport_3d.add_child(world_env)
	
	# Create cube mesh instance (mesh will be created per-preview)
	cube_mesh_instance = MeshInstance3D.new()
	viewport_3d.add_child(cube_mesh_instance)
	
	# Create material for the cube - unshaded for flat color
	cube_material = StandardMaterial3D.new()
	cube_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cube_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # Pixel-perfect
	cube_material.cull_mode = BaseMaterial3D.CULL_BACK
	cube_mesh_instance.material_override = cube_material
	
	print("[TerrainMapper] 3D viewport setup complete")


func _generate_sprite_preview():
	"""Generate an isometric cube sprite from the selected tile using 3D rendering"""
	if current_mode == TextureMode.SINGLE:
		if selected_cell.x < 0 or selected_cell.y < 0:
			return
		_generate_sprite_preview_single(selected_cell)
	else:  # MULTI mode
		if selected_cells[0].x < 0 or selected_cells[1].x < 0 or selected_cells[2].x < 0:
			return
		_generate_sprite_preview_multi(selected_cells[0], selected_cells[1], selected_cells[2])


func _generate_sprite_preview_single(cell: Vector2i):
	"""Generate preview for single-texture block"""
	# Get the source texture as an Image
	var source_image = terrain_texture.get_image()
	if source_image == null:
		return
	
	# Decompress if needed
	if source_image.is_compressed():
		source_image.decompress()
	
	# Calculate the pixel region for this tile (16x16 pixels per tile)
	var tile_pixel_size = 16
	var tile_x = cell.x * tile_pixel_size
	var tile_y = cell.y * tile_pixel_size
	
	print("[TerrainMapper] Extracting tile at grid (%d, %d) -> pixels (%d, %d) to (%d, %d)" % [
		cell.x, cell.y, 
		tile_x, tile_y, 
		tile_x + tile_pixel_size, tile_y + tile_pixel_size
	])
	
	# Extract the tile region (16x16 pixels)
	var tile_image = source_image.get_region(Rect2i(tile_x, tile_y, tile_pixel_size, tile_pixel_size))
	
	# Debug: Check what we extracted
	print("[TerrainMapper] Extracted image size: %dx%d, format: %s" % [
		tile_image.get_width(), 
		tile_image.get_height(),
		tile_image.get_format()
	])
	
	# Create texture from the tile with nearest-neighbor filtering
	var tile_texture = ImageTexture.create_from_image(tile_image)
	
	# Create a custom cube mesh with proper UV mapping
	var cube_mesh = _create_cube_mesh_with_uvs()
	cube_mesh_instance.mesh = cube_mesh
	
	# Center the cube at origin (mesh goes from 0 to 1, we want -0.5 to 0.5)
	cube_mesh_instance.position = Vector3(-0.5, -0.5, -0.5)
	
	# Apply texture to cube material
	cube_material.albedo_texture = tile_texture
	cube_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # Crisp pixels
	
	# Force viewport to render
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	# Wait a frame for rendering to complete
	await get_tree().process_frame
	
	# Get the rendered texture
	var rendered_texture = viewport_3d.get_texture()
	sprite_preview.texture = rendered_texture
	
	print("[TerrainMapper] Sprite preview generated and displayed")


func _generate_sprite_preview_multi(top_cell: Vector2i, side_cell: Vector2i, bottom_cell: Vector2i):
	"""Generate preview for multi-texture block by creating a texture atlas"""
	var source_image = terrain_texture.get_image()
	if source_image == null:
		return
	
	if source_image.is_compressed():
		source_image.decompress()
	
	var tile_pixel_size = 16
	
	print("[TerrainMapper] Creating multi-texture preview: Top(%d,%d) Side(%d,%d) Bottom(%d,%d)" % [
		top_cell.x, top_cell.y, side_cell.x, side_cell.y, bottom_cell.x, bottom_cell.y
	])
	
	# Extract the three tiles
	var top_image = source_image.get_region(Rect2i(
		top_cell.x * tile_pixel_size, top_cell.y * tile_pixel_size, 
		tile_pixel_size, tile_pixel_size))
	var side_image = source_image.get_region(Rect2i(
		side_cell.x * tile_pixel_size, side_cell.y * tile_pixel_size, 
		tile_pixel_size, tile_pixel_size))
	var bottom_image = source_image.get_region(Rect2i(
		bottom_cell.x * tile_pixel_size, bottom_cell.y * tile_pixel_size, 
		tile_pixel_size, tile_pixel_size))
	
	# Create a 48x16 atlas: [top][side][bottom]
	var atlas = Image.create(48, 16, false, source_image.get_format())
	atlas.blit_rect(top_image, Rect2i(0, 0, 16, 16), Vector2i(0, 0))
	atlas.blit_rect(side_image, Rect2i(0, 0, 16, 16), Vector2i(16, 0))
	atlas.blit_rect(bottom_image, Rect2i(0, 0, 16, 16), Vector2i(32, 0))
	
	# Create texture from atlas
	var atlas_texture = ImageTexture.create_from_image(atlas)
	
	# Create custom mesh with UVs mapped to the atlas
	var cube_mesh = _create_cube_mesh_with_uvs_multi()
	cube_mesh_instance.mesh = cube_mesh
	cube_mesh_instance.position = Vector3(-0.5, -0.5, -0.5)
	
	# Apply atlas texture
	cube_material.albedo_texture = atlas_texture
	cube_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	# Force viewport to render
	viewport_3d.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	await get_tree().process_frame
	
	var rendered_texture = viewport_3d.get_texture()
	sprite_preview.texture = rendered_texture
	
	print("[TerrainMapper] Multi-texture sprite preview generated")


func _on_sprite_preview_clicked(event: InputEvent):
	"""Save the sprite when clicked"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_save_sprite()


func _save_sprite():
	"""Save the current sprite preview to user:// folder"""
	if sprite_preview.texture == null:
		return
	
	# Get current datetime for filename
	var datetime = Time.get_datetime_dict_from_system()
	var filename = "block_sprite_%04d-%02d-%02d_%02d-%02d-%02d.png" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]
	
	# Save to user:// folder (like screenshots)
	var save_path = "user://" + filename
	var image = sprite_preview.texture.get_image()
	image.save_png(save_path)
	
	print("[TerrainMapper] Sprite saved to: ", save_path)
	print("[TerrainMapper] Absolute path: ", ProjectSettings.globalize_path(save_path))


func _save_block_files(block_name: String):
	"""Save all block files to user://blocks/blockname/"""
	print("[TerrainMapper] Saving block: ", block_name)
	
	# Create directory
	var dir_path = "user://blocks/" + block_name
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	
	# 1. Save OBJ file
	var obj_content = ""
	if current_mode == TextureMode.SINGLE:
		obj_content = _generate_obj_single(block_name, selected_cell)
	else:
		obj_content = _generate_obj_multi(block_name, selected_cells[0], selected_cells[1], selected_cells[2])
	
	var obj_path = dir_path + "/" + block_name + ".obj"
	var obj_file = FileAccess.open(obj_path, FileAccess.WRITE)
	if obj_file:
		obj_file.store_string(obj_content)
		obj_file.close()
		print("[TerrainMapper] Saved: ", obj_path)
	
	# 2. Save sprite
	if sprite_preview.texture:
		var sprite_path = dir_path + "/" + block_name + "_sprite.png"
		var image = sprite_preview.texture.get_image()
		image.save_png(sprite_path)
		print("[TerrainMapper] Saved: ", sprite_path)
	
	# 3. Save instructions file
	var instructions = _generate_instructions(block_name)
	var inst_path = dir_path + "/" + block_name + "_instructions.txt"
	var inst_file = FileAccess.open(inst_path, FileAccess.WRITE)
	if inst_file:
		inst_file.store_string(instructions)
		inst_file.close()
		print("[TerrainMapper] Saved: ", inst_path)
	
	print("[TerrainMapper] ✓ Block saved successfully to: ", ProjectSettings.globalize_path(dir_path))
	
	# 4. Auto-edit project files if enabled
	if auto_edit_enabled:
		print("[TerrainMapper] Auto-edit enabled - attempting to modify project files...")
		var auto_edit_success = _auto_edit_project_files(block_name)
		if auto_edit_success:
			print("[TerrainMapper] ✓ Auto-edit completed successfully!")
		else:
			print("[TerrainMapper] ⚠️ Auto-edit failed - check instructions.txt for manual steps")
	
	# Show completion dialog (will handle reset/close based on user choice)
	_show_completion_dialog(block_name, dir_path)


func _generate_obj_single(block_name: String, cell: Vector2i) -> String:
	"""Generate OBJ file content for single-texture block"""
	var vt_coords = _generate_vt_coords_single(cell)
	var obj = SINGLE_TEXTURE_TEMPLATE
	obj = obj.replace("{BLOCK_NAME}", block_name)
	obj = obj.replace("{VT_COORDS}", vt_coords)
	return obj


func _generate_obj_multi(block_name: String, top_cell: Vector2i, side_cell: Vector2i, bottom_cell: Vector2i) -> String:
	"""Generate OBJ file content for multi-texture block"""
	var vt_coords = _generate_vt_coords_multi(top_cell, side_cell, bottom_cell)
	var obj = MULTI_TEXTURE_TEMPLATE
	obj = obj.replace("{BLOCK_NAME}", block_name)
	obj = obj.replace("{TOP_GRID}", "(%d,%d)" % [top_cell.x, top_cell.y])
	obj = obj.replace("{SIDE_GRID}", "(%d,%d)" % [side_cell.x, side_cell.y])
	obj = obj.replace("{BOTTOM_GRID}", "(%d,%d)" % [bottom_cell.x, bottom_cell.y])
	obj = obj.replace("{VT_COORDS}", vt_coords)
	return obj


func _generate_vt_coords_single(cell: Vector2i) -> String:
	"""Generate vt coordinates for all 6 faces using the same texture"""
	var u_min = cell.x * (1.0 / grid_size)
	var u_max = (cell.x + 1) * (1.0 / grid_size)
	var v_min = cell.y * (1.0 / grid_size)
	var v_max = (cell.y + 1) * (1.0 / grid_size)
	
	# Flip V for OBJ format
	var v_min_obj = 1.0 - v_max
	var v_max_obj = 1.0 - v_min
	
	var vt = ""
	# Each face needs 4 UV coordinates (24 total for 6 faces)
	for i in range(6):
		vt += "vt %.6f %.6f\n" % [u_min, v_max_obj]
		vt += "vt %.6f %.6f\n" % [u_max, v_max_obj]
		vt += "vt %.6f %.6f\n" % [u_max, v_min_obj]
		vt += "vt %.6f %.6f\n" % [u_min, v_min_obj]
	
	return vt


func _generate_vt_coords_multi(top_cell: Vector2i, side_cell: Vector2i, bottom_cell: Vector2i) -> String:
	"""Generate vt coordinates for multi-texture block (top, 4 sides, bottom)"""
	var vt = ""
	
	# Helper function to get UV for a cell
	var get_uv = func(cell: Vector2i) -> Array:
		var u_min = cell.x * (1.0 / grid_size)
		var u_max = (cell.x + 1) * (1.0 / grid_size)
		var v_min = cell.y * (1.0 / grid_size)
		var v_max = (cell.y + 1) * (1.0 / grid_size)
		var v_min_obj = 1.0 - v_max
		var v_max_obj = 1.0 - v_min
		return [u_min, u_max, v_min_obj, v_max_obj]
	
	# Face 1: TOP
	var top_uv = get_uv.call(top_cell)
	vt += "vt %.6f %.6f\n" % [top_uv[0], top_uv[3]]
	vt += "vt %.6f %.6f\n" % [top_uv[1], top_uv[3]]
	vt += "vt %.6f %.6f\n" % [top_uv[1], top_uv[2]]
	vt += "vt %.6f %.6f\n" % [top_uv[0], top_uv[2]]
	
	# Faces 2-5: SIDES (all use side texture)
	var side_uv = get_uv.call(side_cell)
	for i in range(4):
		vt += "vt %.6f %.6f\n" % [side_uv[0], side_uv[3]]
		vt += "vt %.6f %.6f\n" % [side_uv[1], side_uv[3]]
		vt += "vt %.6f %.6f\n" % [side_uv[1], side_uv[2]]
		vt += "vt %.6f %.6f\n" % [side_uv[0], side_uv[2]]
	
	# Face 6: BOTTOM
	var bottom_uv = get_uv.call(bottom_cell)
	vt += "vt %.6f %.6f\n" % [bottom_uv[0], bottom_uv[3]]
	vt += "vt %.6f %.6f\n" % [bottom_uv[1], bottom_uv[3]]
	vt += "vt %.6f %.6f\n" % [bottom_uv[1], bottom_uv[2]]
	vt += "vt %.6f %.6f\n" % [bottom_uv[0], bottom_uv[2]]
	
	return vt


func _generate_instructions(block_name: String) -> String:
	"""Generate instruction file with code to add to project"""
	var inst = "=== BLOCK CREATION INSTRUCTIONS ===\n"
	inst += "Block Name: %s\n" % block_name
	inst += "Generated: %s\n\n" % Time.get_datetime_string_from_system()
	
	inst += "FILES CREATED:\n"
	inst += "  - %s.obj (place in res://blocky_game/blocks/%s/)\n" % [block_name, block_name]
	inst += "  - %s_sprite.png (for GUI/inventory)\n\n" % block_name
	
	inst += "==================================================\n"
	inst += "STEP 1: Add to generator.gd\n"
	inst += "==================================================\n"
	inst += "File: res://blocky_game/blocks/generator/generator.gd\n\n"
	inst += "Find the block constants (around line 10) and add:\n"
	inst += "const %s = XX  # Replace XX with next available number\n\n" % block_name.to_upper()
	
	inst += "==================================================\n"
	inst += "STEP 2: Add to blocks.gd\n"
	inst += "==================================================\n"
	inst += "File: res://blocky_game/blocks/blocks.gd\n\n"
	inst += "Add this in the _init() function:\n\n"
	
	# Generate proper blocks.gd template with actual block name
	var blocks_template = "_create_block({\n"
	blocks_template += "    \"name\": \"%s\",\n" % block_name
	blocks_template += "    \"gui_model\": \"%s.obj\",\n" % block_name
	blocks_template += "    \"rotation_type\": ROTATION_TYPE_NONE,\n"
	blocks_template += "    \"voxels\": [\"%s\"],\n" % block_name
	blocks_template += "    \"transparent\": false\n"
	blocks_template += "})"
	
	inst += blocks_template + "\n\n"
	
	inst += "==================================================\n"
	inst += "STEP 3: Add to voxel_library.tres (MANUAL)\n"
	inst += "==================================================\n"
	inst += "1. Open res://blocky_game/blocks/voxel_library.tres in Godot\n"
	inst += "2. Add a new VoxelBlockyModelMesh entry\n"
	inst += "3. Set the mesh to your .obj file\n"
	inst += "4. Set material_override_0 to terrain_material.tres\n\n"
	
	if current_mode == TextureMode.SINGLE:
		inst += "==================================================\n"
		inst += "TEXTURE INFO (Single)\n"
		inst += "==================================================\n"
		inst += "Grid: (%d, %d)\n\n" % [selected_cell.x, selected_cell.y]
	else:
		inst += "==================================================\n"
		inst += "TEXTURE INFO (Multi)\n"
		inst += "==================================================\n"
		inst += "TOP:    (%d, %d)\n" % [selected_cells[0].x, selected_cells[0].y]
		inst += "SIDE:   (%d, %d)\n" % [selected_cells[1].x, selected_cells[1].y]
		inst += "BOTTOM: (%d, %d)\n\n" % [selected_cells[2].x, selected_cells[2].y]
	
	inst += "==================================================\n"
	inst += "DONE! Your block is ready to use.\n"
	inst += "==================================================\n"
	
	return inst


func _show_completion_dialog(block_name: String, dir_path: String):
	"""Show completion dialog with options: open folder, add another block, or close"""
	var dialog = ConfirmationDialog.new()
	dialog.title = "Block Saved Successfully!"
	dialog.dialog_text = "Block '%s' has been saved!\n\nFiles are in:\n%s\n\nAdd another block?" % [block_name, ProjectSettings.globalize_path(dir_path)]
	dialog.ok_button_text = "Yes - Add Another"
	dialog.cancel_button_text = "No - Close Mapper"
	dialog.size = Vector2i(500, 220)
	add_child(dialog)

	# Add custom "Open Folder" button
	var open_folder_btn = dialog.add_button("Open Folder", false, "open_folder")

	# Handle custom action
	dialog.custom_action.connect(func(action):
		if action == "open_folder":
			OS.shell_open(ProjectSettings.globalize_path(dir_path))
			# Don't close dialog yet - let them still choose yes/no
	)

	# "Yes - Add Another" clicked
	dialog.confirmed.connect(func():
		print("[TerrainMapper] User chose to add another block")
		dialog.queue_free()
		# Reset for next block but keep mapper open
		_reset_for_next_block()
	)

	# "No - Close Mapper" clicked
	dialog.canceled.connect(func():
		print("[TerrainMapper] User chose to close mapper")
		dialog.queue_free()
		_close_mapper()
	)

	dialog.popup_centered()


func _reset_for_next_block():
	"""Reset mapper state for adding another block"""
	# Reset selection
	_reset_selection()
	multi_selection_step = 0
	_update_mode_status()

	# Clear sprite preview
	if sprite_preview:
		sprite_preview.texture = null

	# Redraw grid
	if grid_canvas:
		grid_canvas.queue_redraw()

	print("[TerrainMapper] Ready for next block - selection cleared")


func _auto_edit_project_files(block_name: String) -> bool:
	"""Automatically edit generator.gd and blocks.gd (EXPERIMENTAL)"""
	var success = true
	
	# 1. Edit generator.gd - add const
	if not _auto_edit_generator(block_name):
		print("[TerrainMapper] Failed to auto-edit generator.gd")
		success = false
	
	# 2. Edit blocks.gd - add _create_block() call
	if not _auto_edit_blocks(block_name):
		print("[TerrainMapper] Failed to auto-edit blocks.gd")
		success = false
	
	# 3. Edit voxel_library.tres - skip (too complex, use Godot UI)
	print("[TerrainMapper] Skipping voxel_library.tres auto-edit (use Godot UI)")
	
	return success


func _auto_edit_generator(block_name: String) -> bool:
	"""Add block constant to generator.gd by finding max existing ID + 1"""
	var generator_path = "res://blocky_game/generator/generator.gd"

	# Read generator.gd to find the maximum existing const ID
	var next_id = _get_next_block_id_from_generator(generator_path)
	if next_id < 0:
		print("[TerrainMapper] ERROR: Could not read generator.gd to find max ID")
		return false
	
	# Read the generator file
	var file = FileAccess.open(generator_path, FileAccess.READ)
	if not file:
		print("[TerrainMapper] ERROR: Could not open generator.gd")
		return false
	
	var content = file.get_as_text()
	file.close()
	
	var const_name = block_name.to_upper()
	var new_const_line = "const %s = %d" % [const_name, next_id]

	print("[TerrainMapper] Adding: %s (from generator.gd max ID + 1)" % new_const_line)

	# Find where to insert - after the LAST const declaration
	var insert_pattern = "const\\s+[A-Z_]+\\s*=\\s*\\d+"
	var regex = RegEx.new()
	regex.compile(insert_pattern)
	var all_matches = regex.search_all(content)

	# Get the last match (insert after the last const)
	var insert_match = all_matches[all_matches.size() - 1] if all_matches.size() > 0 else null
	
	if insert_match:
		var insert_pos = insert_match.get_end()
		# Find the end of the line
		var line_end = content.find("\n", insert_pos)
		if line_end != -1:
			# Insert after this line
			var new_content = content.substr(0, line_end + 1) + new_const_line + "\n" + content.substr(line_end + 1)
			
			# Write back
			file = FileAccess.open(generator_path, FileAccess.WRITE)
			if file:
				file.store_string(new_content)
				file.close()
				print("[TerrainMapper] ✓ Successfully added const to generator.gd at ID %d" % next_id)
				return true
			else:
				print("[TerrainMapper] ERROR: Could not write to generator.gd")
				return false
	
	print("[TerrainMapper] ERROR: Could not find insertion point in generator.gd")
	return false


## Get the next available block ID by finding max const in generator.gd
func _get_next_block_id_from_generator(generator_path: String) -> int:
	"""Find the maximum const ID in generator.gd and return max + 1"""
	var file = FileAccess.open(generator_path, FileAccess.READ)
	if not file:
		print("[TerrainMapper] ERROR: Could not open generator.gd")
		return -1

	var content = file.get_as_text()
	file.close()

	# Find all lines like "const BLOCK_NAME = 42"
	var regex = RegEx.new()
	regex.compile("const\\s+[A-Z_]+\\s*=\\s*(\\d+)")
	var matches = regex.search_all(content)

	var max_id = -1
	for match in matches:
		var id_str = match.get_string(1)  # Get the captured number
		var id = int(id_str)
		if id > max_id:
			max_id = id

	var next_id = max_id + 1
	print("[TerrainMapper] Found max block ID %d in generator.gd, next ID will be %d" % [max_id, next_id])

	return next_id


func _auto_edit_blocks(block_name: String) -> bool:
	"""Add _create_block() call to blocks.gd"""
	var blocks_path = "res://blocky_game/blocks/blocks.gd"
	
	# Read the file
	var file = FileAccess.open(blocks_path, FileAccess.READ)
	if not file:
		print("[TerrainMapper] ERROR: Could not open blocks.gd")
		return false
	
	var content = file.get_as_text()
	file.close()
	
	# Generate the _create_block call
	var create_block_code = "\t_create_block({\n"
	create_block_code += "\t\t\"name\": \"%s\",\n" % block_name
	create_block_code += "\t\t\"gui_model\": \"%s.obj\",\n" % block_name
	create_block_code += "\t\t\"rotation_type\": ROTATION_TYPE_NONE,\n"
	create_block_code += "\t\t\"voxels\": [\"%s\"],\n" % block_name
	create_block_code += "\t\t\"transparent\": false\n"
	create_block_code += "\t})\n"
	
	print("[TerrainMapper] Adding _create_block() for: %s" % block_name)

	# Find where to insert - look for the "})" that comes before "func get_block"
	# This is the end of the last _create_block call in the _init() function
	var regex = RegEx.new()
	regex.compile("\\}\\)\\n+func get_block")
	var insert_match = regex.search(content)

	if insert_match:
		# Insert after the "})" but before the newlines and "func get_block"
		var insert_pos = insert_match.get_start() + 2  # After the "})"

		# Insert new _create_block right after the last "})"
		var new_content = content.substr(0, insert_pos) + "\n" + create_block_code + content.substr(insert_pos)
		
		# Write back
		file = FileAccess.open(blocks_path, FileAccess.WRITE)
		if file:
			file.store_string(new_content)
			file.close()
			print("[TerrainMapper] ✓ Successfully added _create_block() to blocks.gd")
			return true
		else:
			print("[TerrainMapper] ERROR: Could not write to blocks.gd")
			return false
	else:
		print("[TerrainMapper] ERROR: Could not find '})' before 'func get_block' pattern in blocks.gd")
		return false
