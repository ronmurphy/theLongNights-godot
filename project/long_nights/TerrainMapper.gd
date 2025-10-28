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
var sprite_preview: TextureRect
var sprite_preview_panel: Panel

# 3D rendering components for isometric sprite generation
var viewport_3d: SubViewport
var camera_3d: Camera3D
var cube_mesh_instance: MeshInstance3D
var cube_material: StandardMaterial3D
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
	
	# Add sprite preview panel - positioned to the right of OBJ template
	sprite_preview_panel = Panel.new()
	sprite_preview_panel.position = Vector2(975, 340)  # Moved right and aligned with OBJ section
	sprite_preview_panel.size = Vector2(140, 180)
	add_child(sprite_preview_panel)
	
	var preview_label = Label.new()
	preview_label.text = "(Click to Save)"
	preview_label.position = Vector2(10, 5)
	sprite_preview_panel.add_child(preview_label)
	
	sprite_preview = TextureRect.new()
	sprite_preview.position = Vector2(10, 30)
	sprite_preview.custom_minimum_size = Vector2(128, 128)
	sprite_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_preview.gui_input.connect(_on_sprite_preview_clicked)
	sprite_preview_panel.add_child(sprite_preview)
	
	# Set up 3D rendering viewport for isometric sprites (deferred until in tree)
	call_deferred("_setup_3d_viewport")
	
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
	
	# Generate isometric sprite preview
	_generate_sprite_preview()

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
	if selected_cell.x < 0 or selected_cell.y < 0:
		return
	
	# Get the source texture as an Image
	var source_image = terrain_texture.get_image()
	if source_image == null:
		return
	
	# Decompress if needed
	if source_image.is_compressed():
		source_image.decompress()
	
	# Calculate the pixel region for this tile (16x16 pixels per tile)
	var tile_pixel_size = 16
	var tile_x = selected_cell.x * tile_pixel_size
	var tile_y = selected_cell.y * tile_pixel_size
	
	print("[TerrainMapper] Extracting tile at grid (%d, %d) -> pixels (%d, %d) to (%d, %d)" % [
		selected_cell.x, selected_cell.y, 
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
