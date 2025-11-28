extends Node

# Spawns ruin structures into the world
# Handles placement and block generation

const RuinLibrary = preload("res://blocky_game/ruins/RuinLibrary.gd")

@onready var _ruin_library: RuinLibrary = null
@onready var _blocks = null  # Will be set to the Blocks node
@onready var _terrain = null  # Will be set to the VoxelTerrain node


func _ready():
	print("RuinSpawner ready")


func initialize(ruin_library: RuinLibrary, blocks_node: Node, terrain_node: Node):
	"""Initialize the spawner with required dependencies"""
	_ruin_library = ruin_library
	_blocks = blocks_node
	_terrain = terrain_node
	print("RuinSpawner initialized")


func spawn_simple_sky_island(world_position: Vector3) -> Vector3:
	"""
	Spawn a simple natural sky island with just a teleport_stone.
	NO structures, NO templates - just natural circular terrain.

	Returns the spawn position, or Vector3.ZERO if failed
	"""
	print("🏝️ Spawning simple sky island at position: ", world_position)

	# FORCE CHUNK GENERATION: Create temporary VoxelViewer
	var temp_viewer = VoxelViewer.new()
	temp_viewer.position = world_position
	temp_viewer.view_distance = 32
	temp_viewer.requires_visuals = true
	temp_viewer.requires_collisions = true
	_terrain.add_child(temp_viewer)

	# Wait for chunks to generate
	await get_tree().create_timer(2.0).timeout
	print("Chunks generated, creating island...")

	# Get voxel tool
	var voxel_tool = _terrain.get_voxel_tool()
	if voxel_tool == null:
		temp_viewer.queue_free()
		push_error("Failed to get voxel tool from terrain")
		return Vector3.ZERO

	# Generate the natural circular island (increased minimum radius for safety)
	var island_radius = randf_range(25.0, 40.0)  # Larger islands: was 25-40 blocks radius
	var island_result = _generate_natural_circular_island(voxel_tool, world_position, island_radius)
	var blocks_placed = island_result.blocks_placed
	var surface_positions = island_result.surface_positions  # Grass block positions for chest

	# Add inverted cone support structure underneath island
	_generate_island_cone_support(voxel_tool, world_position, island_radius)

	# Fill natural holes with water
	_fill_island_holes_with_water(voxel_tool, world_position, island_radius)

	# Decide if this is a puzzle island (30% chance)
	var is_puzzle_island = randf() < 0.3

	# Calculate island center (most reliable position with solid ground)
	var island_center_x = int(world_position.x + island_radius)
	var island_center_z = int(world_position.z + island_radius)

	# Place teleport_stone AT CENTER of island (safest position)
	# Add small random offset to make it feel more natural (within 3 blocks of center)
	var teleport_x = island_center_x + randi_range(-3, 3)
	var teleport_z = island_center_z + randi_range(-3, 3)

	# Find the HIGHEST surface height near center (scan upward from base)
	const GRASS = 2
	const DIRT = 1
	var teleport_y = int(world_position.y)
	for y_scan in range(25):  # Scan up to 25 blocks (islands can be tall)
		var check_pos = Vector3i(teleport_x, int(world_position.y) + y_scan, teleport_z)
		var block = voxel_tool.get_voxel(check_pos)
		if block == GRASS or block == DIRT:
			teleport_y = check_pos.y + 1  # Place on top of surface
			# Continue scanning to find the HIGHEST point
		elif block != 0 and teleport_y > int(world_position.y):
			# Hit non-grass/dirt after finding surface, use last grass position
			break

	var teleport_stone_pos = Vector3i(teleport_x, teleport_y, teleport_z)
	var island_center_pos = Vector3(island_center_x, teleport_y, island_center_z)  # For player rotation

	# Teleport_stone block ID from generator.gd
	var teleport_stone_def = _blocks.get_block_by_name("teleport_stone")
	var TELEPORT_STONE = 20 # Fallback
	if teleport_stone_def:
		TELEPORT_STONE = teleport_stone_def.base_info.voxels[0]

	# Ensure safe platform around stone
	_ensure_safe_teleport_platform(voxel_tool, teleport_stone_pos)

	# If puzzle island, set up push_block puzzle instead of placing teleport_stone
	if is_puzzle_island:
		_setup_push_block_puzzle(voxel_tool, world_position, island_radius, teleport_stone_pos, surface_positions)
		print("🧩 Created PUZZLE island (teleport_stone hidden until solved)")
	else:
		# Place the teleport_stone using block ID directly (non-puzzle island)
		voxel_tool.set_voxel(teleport_stone_pos, TELEPORT_STONE)
		print("✅ Placed teleport_stone at %s" % teleport_stone_pos)

		# Place a chest with loot on the island (away from teleport stone)
		_place_island_chest(voxel_tool, surface_positions, teleport_stone_pos)

	# Register this island with RuinRegistry for tracking
	# Create minimal island size based on radius
	var island_size = Vector3i(int(island_radius * 2), 10, int(island_radius * 2))
	var teleport_stone_local_pos = teleport_stone_pos - Vector3i(world_position)
	var ruin_data = RuinRegistry.register_ruin(
		world_position,
		"sky_island_natural",
		[teleport_stone_local_pos],  # One teleport stone at center
		island_size
	)

	# Store island center for player orientation when teleporting
	if ruin_data and ruin_data.teleport_stones.size() > 0:
		ruin_data.teleport_stones[0].island_center = island_center_pos

	# Register with LampManager for visualization and persistence
	var stone_positions_and_colors = [{
		"pos": Vector3(teleport_stone_pos),
		"color": ruin_data.teleport_stones[0].glow_color
	}]

	var sphere_data = {
		"center": world_position + Vector3(island_size) / 2.0,
		"radius": island_radius + 10.0,
		"color": ruin_data.teleport_stones[0].glow_color.darkened(0.6),
		"opacity": 0.15,
		"has_enemies": false,
		"ruin_size": island_size
	}

	var lamp_manager = get_tree().root.get_node_or_null("/root/LampManager")
	if lamp_manager:
		lamp_manager.register_ruin(world_position, stone_positions_and_colors, sphere_data)

	print("🏝️ Created natural sky island with %d blocks (radius: %.1f)" % [blocks_placed, island_radius])

	# Clean up temporary viewer
	temp_viewer.queue_free()

	return world_position


func spawn_ruin_at(world_position: Vector3, ruin_name: String = "") -> Vector3:
	"""
	Spawn a ruin at the specified world position (can be in the sky!)
	If ruin_name is empty, a random ruin will be selected
	Returns the spawn position, or Vector3.ZERO if failed

	For SKY RUINS (y >= 100): Spawns simple natural island with teleport_stone
	For GROUND RUINS (y < 100): Uses template system with structures
	"""
	if _ruin_library == null:
		push_error("RuinSpawner not initialized - RuinLibrary is null")
		return Vector3.ZERO

	if _terrain == null:
		push_error("RuinSpawner not initialized - Terrain is null")
		return Vector3.ZERO

	# SKY RUINS: Use simple natural island generation (no structures)
	if world_position.y >= 100:
		return await spawn_simple_sky_island(world_position)

	# GROUND RUINS: Use template system
	# Get the ruin template
	var template: RuinLibrary.RuinTemplate = null
	if ruin_name.is_empty():
		template = _ruin_library.get_random_ruin()
	else:
		template = _ruin_library.get_ruin_by_name(ruin_name)

	if template == null:
		push_error("Failed to get ruin template")
		return Vector3.ZERO

	print("Spawning ruin '", template.name, "' at position: ", world_position)

	# FORCE CHUNK GENERATION: Create temporary VoxelViewer
	print("Creating temporary VoxelViewer to generate chunks...")
	var temp_viewer = VoxelViewer.new()
	temp_viewer.position = world_position
	temp_viewer.view_distance = 32  # Just enough to cover the ruin
	temp_viewer.requires_visuals = true
	temp_viewer.requires_collisions = true
	_terrain.add_child(temp_viewer)

	# Wait for chunks to generate (VoxelTerrain generates asynchronously)
	await get_tree().create_timer(2.0).timeout
	print("Chunks generated, placing blocks...")

	# Get the voxel tool for editing terrain
	var voxel_tool = _terrain.get_voxel_tool()
	if voxel_tool == null:
		temp_viewer.queue_free()
		push_error("Failed to get voxel tool from terrain")
		return Vector3.ZERO

	# Place each block in the template
	var blocks_placed = 0
	var template_positions = {}  # Track all template block positions
	var teleport_stone_data = []  # Store teleport_stone positions and voxel IDs for later placement
	var teleport_stone_def = _blocks.get_block_by_name("teleport_stone")
	var TELEPORT_STONE_BLOCK_ID = 20 # Fallback
	if teleport_stone_def:
		TELEPORT_STONE_BLOCK_ID = teleport_stone_def.base_info.id

	for block_data in template.blocks:
		var block_pos: Vector3i = block_data.pos
		var block_id: int = block_data.block_id
		var variant: int = block_data.get("variant", 0)

		# Calculate world position
		var world_block_pos = Vector3i(world_position) + block_pos

		# Get the block and its voxel ID
		var block = _blocks.get_block(block_id)
		if block == null:
			push_warning("Block ID ", block_id, " not found, skipping")
			continue

		# Get the voxel value to place
		var voxel_id = block.base_info.voxels[variant] if variant < block.base_info.voxels.size() else block.base_info.voxels[0]

		# Track template position for pyramid generation to avoid
		template_positions[world_block_pos] = true

		# If this is a teleport_stone, save it for placement AFTER terrain generation
		if block_id == TELEPORT_STONE_BLOCK_ID:
			teleport_stone_data.append({
				"pos": world_block_pos,
				"voxel_id": voxel_id
			})
			# Don't place it yet - skip to next block
			continue

		# Place the block (but not teleport_stones yet)
		voxel_tool.set_voxel(world_block_pos, voxel_id)
		blocks_placed += 1

	# PUZZLE ROOM SPECIAL HANDLING: Convert push_block voxels to entities with correct settings
	var is_puzzle_room = template.name.begins_with("puzzle_room_")
	if is_puzzle_room:
		_setup_puzzle_room(template, world_position)

	# Generate inverted pyramid beneath the ruin (for flying ruins)
	# Skip pyramid for puzzle rooms (they're enclosed chambers)
	var pyramid_blocks_placed = 0
	if not is_puzzle_room:
		pyramid_blocks_placed = _generate_inverted_pyramid(voxel_tool, world_position, template.size, template_positions)

	# NOW place teleport_stones AFTER terrain generation (ensures they're never overwritten)
	for stone_data in teleport_stone_data:
		var stone_pos: Vector3i = stone_data.pos
		var stone_voxel_id: int = stone_data.voxel_id

		# Ensure safe landing platform around teleport_stone (3x3 grass platform)
		_ensure_safe_teleport_platform(voxel_tool, stone_pos)

		# Place the teleport_stone
		voxel_tool.set_voxel(stone_pos, stone_voxel_id)
		blocks_placed += 1
		print("✅ Placed teleport_stone at %s (AFTER terrain generation)" % stone_pos)

	# Clean up temporary VoxelViewer
	temp_viewer.queue_free()

	# Register this ruin with the RuinRegistry (including size for enemy scaling)
	var ruin_data = RuinRegistry.register_ruin(world_position, template.name, template.teleport_stone_positions, template.size)

	# Prepare stone data for LampManager
	var stone_positions_and_colors = []
	for i in range(ruin_data.teleport_stones.size()):
		var stone = ruin_data.teleport_stones[i]
		var stone_world_pos = world_position + Vector3(stone.local_pos)
		stone_positions_and_colors.append({
			"pos": stone_world_pos,
			"color": stone.glow_color
		})
	
	# Prepare sphere data for LampManager
	var horizontal_size = max(template.size.x, template.size.z)
	var vertical_size = template.size.y
	var radius = sqrt(pow(horizontal_size / 2.0, 2) + pow(horizontal_size / 2.0, 2)) + 5.0
	var vertical_radius = (vertical_size / 2.0) + 5.0
	if vertical_radius > radius:
		radius = vertical_radius
	
	var center_offset = Vector3(template.size) / 2.0
	var sphere_center = world_position + center_offset
	
	# Determine sphere color and opacity
	var sphere_color: Color
	var opacity: float
	if ruin_data.has_enemies:
		sphere_color = Color(0.3, 0.0, 0.0)
		opacity = 0.45
	else:
		if ruin_data.teleport_stones.size() > 0:
			sphere_color = ruin_data.teleport_stones[0].glow_color.darkened(0.6)
			opacity = 0.15
		else:
			sphere_color = Color(0.2, 0.3, 0.5)
			opacity = 0.15
	
	var sphere_data = {
		"center": sphere_center,
		"radius": radius,
		"color": sphere_color,
		"opacity": opacity,
		"has_enemies": ruin_data.has_enemies,
		"ruin_size": template.size  # Store size for proper scaling on reload
	}
	
	# Register with LampManager for persistence
	var lamp_manager = get_tree().root.get_node_or_null("/root/LampManager")
	if lamp_manager:
		lamp_manager.register_ruin(world_position, stone_positions_and_colors, sphere_data)
	
	# Old functions no longer needed - LampManager handles spawning
	# _add_teleport_stone_light() and _add_ruin_sphere() are deprecated

	print("Placed ", blocks_placed, " blocks for ruin '", template.name, "' (", ruin_data.ruin_name, ") with ", template.teleport_stone_positions.size(), " teleport stone(s) and ", pyramid_blocks_placed, " pyramid blocks")
	return world_position


func spawn_ruin_near_spawn(offset_chunks: Vector3i = Vector3i(3, 0, 3)) -> Vector3:
	"""
	Spawn a ruin a few chunks away from world spawn (0,0,0)
	Returns the world position where the ruin was spawned
	"""
	# Calculate position in world coordinates
	# Assuming chunk size is 16x16x16 (common voxel chunk size)
	var chunk_size = 16
	var spawn_offset = Vector3(offset_chunks) * chunk_size

	# Find ground level at spawn position
	var spawn_x = spawn_offset.x
	var spawn_z = spawn_offset.z
	var ground_y = _find_ground_level(Vector3(spawn_x, 0, spawn_z))

	# Spawn the ruin at ground level
	var spawn_position = Vector3(spawn_x, ground_y, spawn_z)

	# FORCE CHUNK GENERATION before checking for existing ruin
	print("Checking for existing crashed ruin at: ", spawn_position)
	var temp_viewer = VoxelViewer.new()
	temp_viewer.position = spawn_position
	temp_viewer.view_distance = 32
	temp_viewer.requires_visuals = true
	temp_viewer.requires_collisions = true
	_terrain.add_child(temp_viewer)

	# Wait for chunks to generate
	await get_tree().create_timer(2.0).timeout

	# CHECK FOR EXISTING TELEPORT_STONE - Don't spawn if ruin already exists
	if _check_for_existing_ruin(spawn_position):
		print("Crashed ruin already exists at: ", spawn_position, " - skipping spawn")
		temp_viewer.queue_free()
		return spawn_position

	# Clean up temporary viewer
	temp_viewer.queue_free()

	var ruin_pos = await spawn_ruin_at(spawn_position, "crashed_tower_small")
	if ruin_pos != Vector3.ZERO:
		print("Successfully spawned initial ruin at: ", spawn_position)

		# Register dialogue event trigger for crashed ruin teleport stone
		var teleport_stone_pos = get_teleport_stone_position(ruin_pos, "crashed_tower_small")
		print("[DEBUG] Registering event trigger for teleport stone at:", teleport_stone_pos)
		if Engine.has_singleton("DialogueManager"):
			var dm = Engine.get_singleton("DialogueManager")
			if dm:
				dm.register_event_trigger(teleport_stone_pos, "ruin_discovered")

		return spawn_position
	else:
		push_error("Failed to spawn initial ruin")
		return Vector3.ZERO


func _check_for_existing_ruin(spawn_position: Vector3) -> bool:
	"""
	Check if a ruin already exists at this position by scanning for teleport_stone blocks
	Scans a 20x20x20 area centered on the spawn position
	Returns true if teleport_stone is found (ruin exists), false otherwise
	"""
	if _terrain == null:
		return false

	var voxel_tool = _terrain.get_voxel_tool()
	if voxel_tool == null:
		return false

	var blocks_node = get_node_or_null("/root/Main/Game/Blocks")
	var TELEPORT_STONE_ID = 20 # Fallback
	if blocks_node:
		var teleport_stone_def = blocks_node.get_block_by_name("teleport_stone")
		if teleport_stone_def:
			TELEPORT_STONE_ID = teleport_stone_def.base_info.voxels[0]
	const SCAN_RADIUS = 20  # Check 20 blocks in each direction

	# Scan the area where the ruin should be
	var center = Vector3i(spawn_position)
	for x in range(center.x - SCAN_RADIUS, center.x + SCAN_RADIUS):
		for y in range(center.y - SCAN_RADIUS, center.y + SCAN_RADIUS):
			for z in range(center.z - SCAN_RADIUS, center.z + SCAN_RADIUS):
				var voxel_id = voxel_tool.get_voxel(Vector3i(x, y, z))
				if voxel_id == TELEPORT_STONE_ID:
					print("Found existing teleport_stone at: ", Vector3i(x, y, z))
					return true  # Ruin already exists!

	return false  # No teleport_stone found, safe to spawn


func _find_ground_level(position: Vector3) -> float:
	"""
	Find the ground level (top solid block) at the given XZ position
	Searches from y=100 down to y=-50
	Returns the Y coordinate of the ground surface
	"""
	if _terrain == null:
		return 0.0

	var voxel_tool = _terrain.get_voxel_tool()
	if voxel_tool == null:
		return 0.0

	# Search downward from a high point
	for y in range(100, -50, -1):
		var voxel_id = voxel_tool.get_voxel(Vector3i(position.x, y, position.z))

		# Check if this is a solid block (non-air)
		if voxel_id != 0:  # 0 is air
			return float(y + 1)  # Return the position above the solid block

	# Default to y=0 if no ground found
	return 0.0


func get_teleport_stone_position(ruin_position: Vector3, ruin_name: String) -> Vector3:
	"""
	Get the world position of the teleport stone within a spawned ruin
	"""
	if _ruin_library == null:
		return Vector3.ZERO

	var template = _ruin_library.get_ruin_by_name(ruin_name)
	if template == null:
		return Vector3.ZERO

	return ruin_position + Vector3(template.teleport_stone_pos)


func _add_teleport_stone_light(position: Vector3, color: Color = Color(0.4, 0.7, 1.0)) -> void:
	"""
	Add a glowing light at the teleport stone position to make it visible
	Color is determined by portal type (blue=unvisited, white=visited, red=combat, green=return, purple=home)
	"""
	var light = OmniLight3D.new()
	light.name = "TeleportStoneLight"
	light.position = position + Vector3(0.5, 0.5, 0.5)  # Center of block

	# Use the provided color (color-coded by portal type)
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 8.0
	light.omni_attenuation = 2.0

	# Add the light to the terrain node (so it's part of the scene)
	_terrain.add_child(light)

	print("Added teleport stone light at: ", position, " with color: ", color)


func _add_ruin_sphere(ruin_position: Vector3, ruin_data: RuinRegistry.RuinData, ruin_size: Vector3i) -> void:
	"""
	Add a magical colored sphere around the ruin for visual atmosphere
	- Combat ruins: Dark red, more opaque (ominous)
	- Normal ruins: Portal stone color, subtle and transparent
	- Sphere is properly sized and centered based on ruin dimensions
	"""
	var sphere_mesh_instance = MeshInstance3D.new()
	sphere_mesh_instance.name = "RuinSphere"

	# Calculate proper sphere radius from ruin size
	# Use the largest horizontal dimension (x or z) and add padding
	var horizontal_size = max(ruin_size.x, ruin_size.z)
	var vertical_size = ruin_size.y

	# Radius should encompass the entire ruin with some padding
	# Use diagonal distance from center to corner, plus 5 blocks padding
	var radius = sqrt(pow(horizontal_size / 2.0, 2) + pow(horizontal_size / 2.0, 2)) + 5.0

	# Make sure sphere is tall enough vertically too
	var vertical_radius = (vertical_size / 2.0) + 5.0
	if vertical_radius > radius:
		radius = vertical_radius

	# Create sphere mesh with calculated size
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0  # Diameter
	sphere_mesh.radial_segments = 32  # Smooth sphere
	sphere_mesh.rings = 16
	sphere_mesh_instance.mesh = sphere_mesh

	# Create material
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # No lighting affects it
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_BACK  # Only visible from outside - prevents color tinting when inside
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED  # Don't block other objects

	# Determine color and opacity based on ruin type
	var sphere_color: Color
	var opacity: float

	if ruin_data.has_enemies:
		# Combat ruin - very dark red, ominous and threatening
		sphere_color = Color(0.3, 0.0, 0.0)  # Much darker red
		opacity = 0.45  # 45% opacity - more visible and foreboding
	else:
		# Normal ruin - use portal stone color but darkened, subtle
		if ruin_data.teleport_stones.size() > 0:
			var stone_color = ruin_data.teleport_stones[0].glow_color
			# Darken the stone color significantly
			sphere_color = stone_color.darkened(0.6)  # 60% darker
			opacity = 0.15  # 15% opacity - slightly more visible
		else:
			# Fallback to dark blue
			sphere_color = Color(0.2, 0.3, 0.5)  # Darker blue
			opacity = 0.15

	material.albedo_color = Color(sphere_color.r, sphere_color.g, sphere_color.b, opacity)

	# Optional: Add slight emission for magical glow effect
	if ruin_data.has_enemies:
		material.emission_enabled = true
		material.emission = Color(0.5, 0.0, 0.0)  # Faint red glow
		material.emission_energy_multiplier = 0.3

	sphere_mesh_instance.material_override = material

	# Position sphere at TRUE CENTER of ruin (using actual size)
	var center_offset = Vector3(ruin_size) / 2.0
	sphere_mesh_instance.position = ruin_position + center_offset

	# Add to terrain node (part of the world)
	_terrain.add_child(sphere_mesh_instance)

	var sphere_type = "COMBAT (red)" if ruin_data.has_enemies else "normal (" + str(sphere_color) + ")"
	print("Added ", sphere_type, " sphere (radius: %.1f) around %dx%dx%d ruin at: %s" % [radius, ruin_size.x, ruin_size.y, ruin_size.z, ruin_position])


func _ensure_safe_teleport_platform(voxel_tool, teleport_stone_pos: Vector3i):
	"""
	Ensure there's a safe landing platform around a teleport_stone.
	- Creates a 5x5 grass platform beneath the stone
	- Ensures player won't fall through on arrival
	- Clears vertical space above for player spawning
	"""
	# Block IDs from generator.gd
	const AIR = 0
	const DIRT = 1
	const GRASS = 2
	const PLATFORM_RADIUS = 2  # 5x5 platform (2 blocks in each direction)

	# Create platform beneath teleport_stone
	for x_offset in range(-PLATFORM_RADIUS, PLATFORM_RADIUS + 1):
		for z_offset in range(-PLATFORM_RADIUS, PLATFORM_RADIUS + 1):
			var platform_x = teleport_stone_pos.x + x_offset
			var platform_z = teleport_stone_pos.z + z_offset

			# Place grass on surface (directly beneath teleport_stone level)
			var surface_pos = Vector3i(platform_x, teleport_stone_pos.y - 1, platform_z)
			var current_block = voxel_tool.get_voxel(surface_pos)
			if current_block == AIR:
				voxel_tool.set_voxel(surface_pos, GRASS)

			# Place dirt layer beneath grass for stability
			var dirt_pos = Vector3i(platform_x, teleport_stone_pos.y - 2, platform_z)
			var dirt_block = voxel_tool.get_voxel(dirt_pos)
			if dirt_block == AIR:
				voxel_tool.set_voxel(dirt_pos, DIRT)

	# Clear vertical space above teleport_stone (3 blocks high for player)
	for y_offset in range(1, 4):  # 1, 2, 3 blocks above
		var clear_pos = Vector3i(teleport_stone_pos.x, teleport_stone_pos.y + y_offset, teleport_stone_pos.z)
		voxel_tool.set_voxel(clear_pos, AIR)

	print("🛬 Created safe landing platform at teleport_stone: %s" % teleport_stone_pos)


func _generate_inverted_pyramid(voxel_tool, world_position: Vector3, ruin_size: Vector3i, template_positions: Dictionary = {}) -> int:
	"""
	Generate a natural floating island platform with inverted pyramid support.

	For SKY RUINS (y >= 100):
	- Creates ROUND/CIRCULAR platform with organic shape
	- Adds terrain variation on top (small hills, bumps)
	- Places vegetation (trees, grass, shrubs)
	- Pyramid follows the circular shape

	For GROUND RUINS (y < 100):
	- Uses simple square pyramid (original behavior)

	Features:
	- Gradient: GRASS (top) → DIRT → STONE → RUIN_STONE (bottom)
	- Natural jagged edges
	- Capped height for sky islands
	- Skips template block positions (structures, teleport_stones, etc.)
	"""
	var blocks_placed = 0
	var is_sky_ruin = world_position.y >= 100

	# Block IDs (these are VOXEL IDs, not block IDs!)
	var GRASS_ID = _blocks.get_block(2).base_info.voxels[0]        # Grass
	var DIRT_ID = _blocks.get_block(1).base_info.voxels[0]         # Dirt
	var STONE_ID = _blocks.get_block(29).base_info.voxels[0]       # Stone
	var RUIN_STONE_ID = _blocks.get_block(33).base_info.voxels[0]  # Ruin stone
	var TALL_GRASS_ID = _blocks.get_block(8).base_info.voxels[0]   # Tall grass
	var WATER_TOP_ID = _blocks.get_block(13).base_info.voxels[0]   # Water top
	var WATER_FULL_ID = _blocks.get_block(14).base_info.voxels[0]  # Water full
	const AIR_ID = 0

	# Calculate dimensions
	var base_radius = max(ruin_size.x, ruin_size.z) / 2.0
	var platform_radius = base_radius + 8  # Extend platform beyond structure

	# Pyramid height - cap at 30 for sky islands
	var pyramid_height = int(base_radius * 1.5)
	if is_sky_ruin:
		pyramid_height = min(30, pyramid_height)

	var ruin_bottom_y = int(world_position.y)
	var ruin_center_x = int(world_position.x) + ruin_size.x / 2
	var ruin_center_z = int(world_position.z) + ruin_size.z / 2

	# Noise for terrain variation (only for sky ruins)
	var terrain_noise: FastNoiseLite = null
	if is_sky_ruin:
		terrain_noise = FastNoiseLite.new()
		terrain_noise.seed = hash(world_position)
		terrain_noise.frequency = 0.15
		terrain_noise.fractal_octaves = 2

	# Generate platform + pyramid
	var scan_range = int(platform_radius) + 5
	for x in range(-scan_range, scan_range + 1):
		for z in range(-scan_range, scan_range + 1):
			var distance = sqrt(float(x * x + z * z))

			# Add organic edge variation
			var edge_noise = randf() * 2.0 - 1.0  # -1 to +1
			var effective_distance = distance + edge_noise

			# Skip if outside platform radius
			if effective_distance > platform_radius:
				continue

			# Calculate edge falloff (smoother at edges)
			var edge_factor = 1.0 - clamp((effective_distance - platform_radius + 5.0) / 5.0, 0.0, 1.0)

			# Terrain height variation on top (only for sky ruins)
			var terrain_height_offset = 0
			if is_sky_ruin and terrain_noise:
				var noise_val = terrain_noise.get_noise_2d(ruin_center_x + x, ruin_center_z + z)
				# Small bumps and dips (-2 to +3 blocks)
				terrain_height_offset = int(noise_val * 2.5 + 0.5)

			# Build from bottom (pyramid) to top (platform)
			for layer in range(pyramid_height):
				var current_y_offset = -layer
				var layer_progress = float(pyramid_height - layer - 1) / float(pyramid_height)

				# Pyramid taper
				var layer_radius = platform_radius * layer_progress

				# Determine if this position is inside the pyramid at this layer
				if effective_distance > layer_radius:
					continue

				# Determine block type based on depth
				var block_voxel_id: int
				if layer_progress > 0.67:  # Top 33%
					block_voxel_id = DIRT_ID
				elif layer_progress > 0.33:  # Middle 33%
					block_voxel_id = STONE_ID
				else:  # Bottom 33%
					block_voxel_id = RUIN_STONE_ID

				var world_x = ruin_center_x + x
				var world_z = ruin_center_z + z
				var world_y = ruin_bottom_y + current_y_offset
				var block_pos = Vector3i(world_x, world_y, world_z)

				# Skip template block positions (structures, teleport_stones, etc.)
				if template_positions.has(block_pos):
					continue

				# Don't overwrite existing blocks
				var existing_voxel = voxel_tool.get_voxel(block_pos)
				if existing_voxel == AIR_ID:
					voxel_tool.set_voxel(block_pos, block_voxel_id)
					blocks_placed += 1

			# Top layer with terrain variation
			for height_offset in range(max(0, terrain_height_offset), max(1, terrain_height_offset + 3)):
				var world_x = ruin_center_x + x
				var world_z = ruin_center_z + z
				var world_y = ruin_bottom_y + height_offset
				var block_pos = Vector3i(world_x, world_y, world_z)

				# Skip template block positions (structures, teleport_stones, etc.)
				if template_positions.has(block_pos):
					continue

				var existing_voxel = voxel_tool.get_voxel(block_pos)
				if existing_voxel != AIR_ID:
					continue  # Don't overwrite

				var block_voxel_id: int
				if height_offset == max(0, terrain_height_offset + 2):  # Top surface
					block_voxel_id = GRASS_ID
				else:  # Below surface
					block_voxel_id = DIRT_ID

				voxel_tool.set_voxel(block_pos, block_voxel_id)
				blocks_placed += 1

				# Add vegetation on top surface (sky ruins only)
				if is_sky_ruin and height_offset == max(0, terrain_height_offset + 2):
					var veg_roll = randf()
					if veg_roll < 0.12:  # 12% chance for vegetation
						var veg_y = world_y + 1
						var veg_pos = Vector3i(world_x, veg_y, world_z)

						# Only place if there's grass below and air above
						if voxel_tool.get_voxel(Vector3i(world_x, world_y, world_z)) == GRASS_ID:
							if voxel_tool.get_voxel(veg_pos) == AIR_ID:
								if veg_roll < 0.05:  # Tall grass
									voxel_tool.set_voxel(veg_pos, TALL_GRASS_ID)
								# Note: Removed shrub/tree for now to keep it simple

	# Add water lakes to sky islands
	var lakes_placed = 0
	if is_sky_ruin:
		lakes_placed = _add_water_lakes(voxel_tool, ruin_center_x, ruin_center_z, ruin_bottom_y, platform_radius, GRASS_ID, DIRT_ID, WATER_TOP_ID, WATER_FULL_ID)

	var shape_type = "circular island" if is_sky_ruin else "square pyramid"
	print("Generated %s with %d blocks (height: %d, radius: %.1f, lakes: %d)" % [shape_type, blocks_placed, pyramid_height, platform_radius, lakes_placed])

	return blocks_placed


func _generate_natural_circular_island(voxel_tool, world_position: Vector3, radius: float) -> Dictionary:
	"""
	Generate a natural-looking circular island with organic terrain.
	Uses same noise settings as world generator for natural hills and valleys.

	Features:
	- Smooth rolling hills (like ground-level terrain)
	- Natural material gradient: grass -> dirt -> stone (NO bedrock!)
	- Trees generated using TreeGenerator
	- Organic circular shape with irregular edges

	Returns: {blocks_placed: int, surface_positions: Array[Vector3i]}
	"""
	var blocks_placed = 0
	var surface_positions = []  # Track grass surface positions for chest placement
	var center_x = int(world_position.x + radius)
	var center_z = int(world_position.z + radius)
	var base_y = int(world_position.y)

	# Block IDs from generator.gd - use these directly, NOT voxel IDs!
	const AIR = 0
	const DIRT = 1
	const GRASS = 2
	const LOG_Y = 4
	const LEAVES = 25
	const STONE = 29

	# Use SAME noise settings as world generator for natural terrain
	var terrain_noise = FastNoiseLite.new()
	terrain_noise.seed = hash(world_position)
	terrain_noise.frequency = 1.0 / 128.0  # Same as world generator
	terrain_noise.fractal_octaves = 4  # Same as world generator
	terrain_noise.noise_type = FastNoiseLite.TYPE_PERLIN

	# Edge noise for organic island shape
	var edge_noise = FastNoiseLite.new()
	edge_noise.seed = hash(world_position) + 1000
	edge_noise.frequency = 0.1
	edge_noise.fractal_octaves = 2

	# Generate trees using TreeGenerator
	const TreeGenerator = preload("res://blocky_game/generator/tree_generator.gd")
	var tree_gen = TreeGenerator.new()
	tree_gen.log_type = LOG_Y  # Use block ID directly
	tree_gen.leaves_type = LEAVES  # Use block ID directly
	tree_gen.trunk_len_min = 6
	tree_gen.trunk_len_max = 12
	var tree_structures = []
	for i in 8:  # Generate 8 different tree variations
		tree_structures.append(tree_gen.generate())

	# Track tree positions for placement after terrain
	var tree_positions = []

	var scan_range = int(radius) + 5
	for x in range(-scan_range, scan_range + 1):
		for z in range(-scan_range, scan_range + 1):
			var distance = sqrt(float(x * x + z * z))

			# Organic edge variation (±8 blocks)
			var edge_variation = edge_noise.get_noise_2d(center_x + x, center_z + z) * 8.0
			var effective_radius = radius + edge_variation

			# Skip if outside island bounds
			if distance > effective_radius:
				continue

			var world_x = center_x + x
			var world_z = center_z + z

			# Get terrain height using world generator style noise
			# Map noise [-1, 1] to height range [5, 20] blocks
			var noise_val = terrain_noise.get_noise_2d(world_x, world_z)
			var terrain_height = int((noise_val + 1.0) * 7.5 + 5.0)  # 5 to 20 blocks

			# Edge falloff - terrain gets lower near edges for natural slope
			var edge_factor = 1.0 - (distance / effective_radius)
			edge_factor = clamp(edge_factor, 0.0, 1.0)
			terrain_height = int(terrain_height * edge_factor)
			terrain_height = max(2, terrain_height)  # At least 2 blocks tall

			# Build terrain column
			for y_offset in range(terrain_height + 8):  # Extra depth for subsurface
				var world_y = base_y + y_offset
				var block_pos = Vector3i(world_x, world_y, world_z)

				# Don't overwrite existing blocks
				var existing_voxel = voxel_tool.get_voxel(block_pos)
				if existing_voxel != AIR:
					continue

				# Determine block type based on depth from surface
				var depth_from_surface = terrain_height - y_offset
				var block_id: int

				if depth_from_surface < 0:
					# Above surface - skip (air)
					continue
				elif depth_from_surface == 0:
					# Surface - grass
					block_id = GRASS
					# Track surface position for chest placement
					surface_positions.append(block_pos)
				elif depth_from_surface <= 4:
					# Shallow (1-4 blocks deep) - dirt
					block_id = DIRT
				else:
					# Deep (5+ blocks) - stone (NO BEDROCK!)
					block_id = STONE

				voxel_tool.set_voxel(block_pos, block_id)
				blocks_placed += 1

			# Randomly mark positions for tree placement (5% chance)
			if randf() < 0.05 and terrain_height >= 8:
				var surface_y = base_y + terrain_height
				# Make sure there's grass at surface
				var surface_check = voxel_tool.get_voxel(Vector3i(world_x, surface_y, world_z))
				if surface_check == GRASS:
					tree_positions.append(Vector3i(world_x, surface_y + 1, world_z))

	# Place trees after terrain generation using paste_masked
	var trees_placed = 0
	for tree_pos in tree_positions:
		if trees_placed >= tree_structures.size() * 3:  # Limit total trees
			break

		var tree_structure = tree_structures[trees_placed % tree_structures.size()]

		# Calculate lower corner position for paste (tree has an offset)
		var lower_corner_pos = Vector3(tree_pos) - tree_structure.offset

		# Use paste_masked to place the tree (only replaces air blocks)
		voxel_tool.paste_masked(
			lower_corner_pos,
			tree_structure.voxels,
			1 << VoxelBuffer.CHANNEL_TYPE,  # Channel mask
			VoxelBuffer.CHANNEL_TYPE,       # Mask channel
			AIR                             # Only replace air
		)

		trees_placed += 1

	print("Generated natural circular island: %d blocks (radius: %.1f, trees: %d, surface positions: %d)" % [blocks_placed, radius, trees_placed, surface_positions.size()])
	return {
		"blocks_placed": blocks_placed,
		"surface_positions": surface_positions
	}


func _generate_island_cone_support(voxel_tool, world_position: Vector3, radius: float):
	"""
	Generate an inverted cone/tapered support structure under the floating island.
	Like the island was ripped from the ground with dirt/stone hanging beneath.

	Features:
	- Gradually reduces radius as it goes down (not perfect cone, organic)
	- 5-10 layers deep
	- Mix of dirt and stone
	- Each layer is smaller than the one above
	"""
	const DIRT = 1
	const STONE = 29
	const AIR = 0

	var center_x = int(world_position.x + radius)
	var center_z = int(world_position.z + radius)
	var base_y = int(world_position.y)

	# Random depth between 5-10 layers
	var cone_depth = randi_range(5, 10)

	# Noise for organic irregularity
	var cone_noise = FastNoiseLite.new()
	cone_noise.seed = hash(world_position) + 5000
	cone_noise.frequency = 0.2
	cone_noise.fractal_octaves = 2

	for layer in range(cone_depth):
		var layer_y = base_y - layer - 1  # Go down from base

		# Calculate radius for this layer (tapers down)
		var layer_progress = float(layer) / float(cone_depth)
		var layer_radius = radius * (1.0 - layer_progress * 0.9)  # Reduces to 10% of original

		# Add variation to radius
		var radius_variation = randf_range(-2.0, 2.0)
		layer_radius += radius_variation

		var scan_range = int(layer_radius) + 2

		for x in range(-scan_range, scan_range + 1):
			for z in range(-scan_range, scan_range + 1):
				var distance = sqrt(float(x * x + z * z))

				# Organic edge variation
				var edge_variation = cone_noise.get_noise_2d(center_x + x, center_z + z) * 3.0
				var effective_distance = distance + edge_variation

				if effective_distance > layer_radius:
					continue

				var world_x = center_x + x
				var world_z = center_z + z
				var block_pos = Vector3i(world_x, layer_y, world_z)

				# Don't overwrite existing blocks
				if voxel_tool.get_voxel(block_pos) != AIR:
					continue

				# Mix of dirt and stone (more stone as we go deeper)
				var stone_chance = 0.3 + (layer_progress * 0.4)  # 30% to 70% stone
				var block_id = STONE if randf() < stone_chance else DIRT

				voxel_tool.set_voxel(block_pos, block_id)

	print("Generated cone support: %d layers (depth: %d)" % [cone_depth, cone_depth])


func _fill_island_holes_with_water(voxel_tool, world_position: Vector3, radius: float):
	"""
	Fill natural holes/depressions in the island with water.
	A hole is: air blocks surrounded by grass/dirt at similar or higher elevation.
	"""
	const AIR = 0
	const GRASS = 2
	const DIRT = 1
	const WATER_TOP = 13
	const WATER_FULL = 14

	var center_x = int(world_position.x + radius)
	var center_z = int(world_position.z + radius)
	var base_y = int(world_position.y)

	var scan_range = int(radius) + 5
	var holes_filled = 0

	# Scan the island surface for depressions
	for x in range(-scan_range, scan_range + 1, 2):  # Step by 2 for performance
		for z in range(-scan_range, scan_range + 1, 2):
			var world_x = center_x + x
			var world_z = center_z + z

			# Find surface height at this position
			var found_surface = false
			for y_scan in range(20):
				var check_y = base_y + y_scan
				var check_pos = Vector3i(world_x, check_y, world_z)
				var block = voxel_tool.get_voxel(check_pos)

				if block == GRASS or block == DIRT:
					found_surface = true
					# Check if there's a depression (air below surface)
					var below_pos = Vector3i(world_x, check_y - 1, world_z)
					if voxel_tool.get_voxel(below_pos) == AIR:
						# Found a hole! Fill with water
						var water_depth = 0
						for depth in range(1, 5):  # Fill up to 4 blocks deep
							var water_pos = Vector3i(world_x, check_y - depth, world_z)
							if voxel_tool.get_voxel(water_pos) == AIR:
								# Check if surrounded by terrain (not edge of island)
								if _is_surrounded_by_terrain(voxel_tool, water_pos):
									if depth == 1:
										voxel_tool.set_voxel(water_pos, WATER_TOP)
									else:
										voxel_tool.set_voxel(water_pos, WATER_FULL)
									water_depth = depth
								else:
									break
							else:
								break
						if water_depth > 0:
							holes_filled += 1
					break

				if block != AIR:
					break

	if holes_filled > 0:
		print("💧 Filled %d natural depressions with water" % holes_filled)


func _is_surrounded_by_terrain(voxel_tool, pos: Vector3i) -> bool:
	"""Check if position is surrounded by solid blocks (not on island edge)"""
	const AIR = 0
	var solid_neighbors = 0

	for x_off in [-1, 0, 1]:
		for z_off in [-1, 0, 1]:
			if x_off == 0 and z_off == 0:
				continue
			var check_pos = Vector3i(pos.x + x_off, pos.y, pos.z + z_off)
			if voxel_tool.get_voxel(check_pos) != AIR:
				solid_neighbors += 1

	return solid_neighbors >= 5  # At least 5 of 8 neighbors are solid


func _setup_push_block_puzzle(voxel_tool, world_position: Vector3, radius: float, teleport_pos: Vector3i, surface_positions: Array):
	"""
	Set up a push_block puzzle on the island.
	- Place test block (goal)
	- Place push_block (movable)
	- Store teleport_stone position for later reveal
	- Push_block must be pushed to/beside test block to reveal teleport_stone
	"""
	# Get block IDs dynamically to ensure correctness
	var blocks_node = get_node_or_null("/root/Main/Game/Blocks")
	if blocks_node == null:
		push_error("RuinSpawner: Could not find Blocks node")
		return

	# Get voxel IDs (not block IDs!)
	var push_block_def = blocks_node.get_block_by_name("push_block")
	var test_block_def = blocks_node.get_block_by_name("test")
	
	if push_block_def == null or test_block_def == null:
		push_error("RuinSpawner: Could not find push_block or test block definitions")
		return
		
	var PUSH_BLOCK = push_block_def.base_info.voxels[0]
	var TEST = test_block_def.base_info.voxels[0]
	
	const GRASS = 2
	const AIR = 0

	if surface_positions.is_empty():
		print("⚠️ Cannot create puzzle - no surface positions")
		return

	# Find two positions far apart on the island for test block and push_block
	var valid_positions = []
	for pos in surface_positions:
		var above_pos = Vector3i(pos.x, pos.y + 1, pos.z)
		if voxel_tool.get_voxel(above_pos) == AIR:
			# Far enough from teleport position
			if pos.distance_to(teleport_pos) > 8.0:
				valid_positions.append(pos)

	if valid_positions.size() < 2:
		print("⚠️ Not enough positions for puzzle blocks")
		return

	# Shuffle and pick positions
	valid_positions.shuffle()
	var test_pos = Vector3i(valid_positions[0].x, valid_positions[0].y + 1, valid_positions[0].z)
	var push_block_start_pos = Vector3i(valid_positions[1].x, valid_positions[1].y + 1, valid_positions[1].z)

	# Ensure they're not too close together (puzzle should require some pushing)
	if test_pos.distance_to(push_block_start_pos) < 5.0:
		# Try to find a better push_block position
		for i in range(2, min(10, valid_positions.size())):
			var alt_pos = Vector3i(valid_positions[i].x, valid_positions[i].y + 1, valid_positions[i].z)
			if test_pos.distance_to(alt_pos) >= 5.0:
				push_block_start_pos = alt_pos
				break

	# Place test block (goal)
	voxel_tool.set_voxel(test_pos, TEST)

	# Store puzzle data for completion tracking BEFORE placing push_block voxel
	# This ensures PushBlockManager can find the data when it spawns the entity
	var puzzle_data = {
		"island_pos": world_position,
		"teleport_pos": teleport_pos,
		"test_pos": test_pos,
		"push_block_spawn": push_block_start_pos,
		"solved": false
	}

	# Register with puzzle manager FIRST (before placing voxel)
	_register_island_puzzle(puzzle_data)

	# NOW place push_block as a voxel (will be converted to entity by PushBlockManager)
	# The puzzle data is already registered, so the entity will have the correct flags
	voxel_tool.set_voxel(push_block_start_pos, PUSH_BLOCK)

	print("🧩 Puzzle set up: push_block at %s, test block at %s, teleport hidden at %s" % [push_block_start_pos, test_pos, teleport_pos])


func _register_island_puzzle(puzzle_data: Dictionary):
	"""Register puzzle data for tracking and completion detection"""
	# Store in RuinRegistry metadata for this island
	# This will be checked when push_blocks emit goal_reached signal
	var ruin_registry = get_node_or_null("/root/Main/Game/RuinRegistry")
	if ruin_registry and ruin_registry.has_method("register_island_puzzle"):
		ruin_registry.register_island_puzzle(puzzle_data)


func _place_island_chest(voxel_tool, surface_positions: Array, teleport_pos: Vector3i):
	"""
	Place a chest with loot on the island surface.
	- Away from teleport stone
	- On grass blocks
	- Contains 1-3 random items
	"""
	var blocks_node = get_node_or_null("/root/Main/Game/Blocks")
	var CHEST = 28 # Fallback
	if blocks_node:
		var chest_def = blocks_node.get_block_by_name("chest")
		if chest_def:
			CHEST = chest_def.base_info.voxels[0]
	const AIR = 0

	if surface_positions.is_empty():
		print("⚠️ No surface positions found for chest placement")
		return

	# Find a good position away from teleport stone
	var valid_positions = []
	for pos in surface_positions:
		var distance_to_teleport = pos.distance_to(teleport_pos)
		# At least 8 blocks away from teleport stone
		if distance_to_teleport > 8.0:
			# Make sure there's air above for the chest
			var above_pos = Vector3i(pos.x, pos.y + 1, pos.z)
			if voxel_tool.get_voxel(above_pos) == AIR:
				valid_positions.append(above_pos)

	if valid_positions.is_empty():
		print("⚠️ No valid positions for chest (too close to teleport or blocked)")
		return

	# Pick a random valid position
	var chest_pos = valid_positions[randi() % valid_positions.size()]

	# Place the chest
	voxel_tool.set_voxel(chest_pos, CHEST)

	print("📦 Placed chest at %s (with loot)" % chest_pos)


func _add_water_lakes(voxel_tool, center_x: int, center_z: int, base_y: int, platform_radius: float, GRASS_ID: int, DIRT_ID: int, WATER_TOP_ID: int, WATER_FULL_ID: int) -> int:
	"""
	Add small water lakes to the island platform.

	Requirements:
	- 3x3 empty area (air)
	- 5x5 grass/dirt surround around the 3x3
	- Dig into the grass layer to create depression
	- Fill with water blocks
	"""
	var lakes_created = 0
	const AIR_ID = 0
	const MAX_LAKES = 3  # Limit number of lakes per island

	# Scan the platform for suitable lake locations
	var scan_range = int(platform_radius)
	var potential_locations = []

	for x in range(-scan_range, scan_range, 4):  # Step by 4 to avoid overlapping
		for z in range(-scan_range, scan_range, 4):
			var world_x = center_x + x
			var world_z = center_z + z

			# Check if this location is suitable for a lake
			if _is_valid_lake_location(voxel_tool, world_x, world_z, base_y, GRASS_ID, DIRT_ID):
				potential_locations.append(Vector2i(world_x, world_z))

	# Shuffle and pick a few locations
	potential_locations.shuffle()
	var num_lakes = min(MAX_LAKES, potential_locations.size())

	for i in range(num_lakes):
		var loc = potential_locations[i]
		_create_water_lake(voxel_tool, loc.x, loc.y, base_y, GRASS_ID, DIRT_ID, WATER_TOP_ID, WATER_FULL_ID)
		lakes_created += 1

	return lakes_created


func _is_valid_lake_location(voxel_tool, center_x: int, center_z: int, base_y: int, GRASS_ID: int, DIRT_ID: int) -> bool:
	"""Check if a location is suitable for a water lake (3x3 air with 5x5 grass/dirt surround)"""
	const AIR_ID = 0

	# First, check the 5x5 surround has grass/dirt
	for x in range(-2, 3):
		for z in range(-2, 3):
			var check_x = center_x + x
			var check_z = center_z + z

			# Find the surface height at this position
			var surface_y = base_y
			for y_offset in range(10):  # Search up to 10 blocks up
				var check_pos = Vector3i(check_x, base_y + y_offset, check_z)
				var voxel_id = voxel_tool.get_voxel(check_pos)

				if voxel_id == GRASS_ID or voxel_id == DIRT_ID:
					surface_y = base_y + y_offset
				elif voxel_id == AIR_ID:
					break  # Found air above

			# Check if surface block is grass or dirt
			var surface_block = voxel_tool.get_voxel(Vector3i(check_x, surface_y, check_z))
			if surface_block != GRASS_ID and surface_block != DIRT_ID:
				return false  # Not grass/dirt surround

	# Second, check the center 3x3 can have air above it (for the lake)
	for x in range(-1, 2):
		for z in range(-1, 2):
			var check_x = center_x + x
			var check_z = center_z + z

			# Find surface
			var surface_y = base_y
			for y_offset in range(10):
				var check_pos = Vector3i(check_x, base_y + y_offset, check_z)
				var voxel_id = voxel_tool.get_voxel(check_pos)

				if voxel_id == AIR_ID:
					break
				surface_y = base_y + y_offset

			# Check if there's space above for air/water
			var above_block = voxel_tool.get_voxel(Vector3i(check_x, surface_y + 1, check_z))
			if above_block != AIR_ID:
				return false  # No space for lake

	return true


func _create_water_lake(voxel_tool, center_x: int, center_z: int, base_y: int, GRASS_ID: int, DIRT_ID: int, WATER_TOP_ID: int, WATER_FULL_ID: int):
	"""Create a 3x3 water lake by digging a hole and filling with water"""
	const AIR_ID = 0

	# Random depth (2-3 blocks)
	var lake_depth = randi_range(2, 3)

	# Dig out the 3x3 hole and fill with water
	for x in range(-1, 2):
		for z in range(-1, 2):
			var world_x = center_x + x
			var world_z = center_z + z

			# Find the surface height
			var surface_y = base_y
			for y_offset in range(10):
				var check_pos = Vector3i(world_x, base_y + y_offset, world_z)
				var voxel_id = voxel_tool.get_voxel(check_pos)

				if voxel_id == AIR_ID:
					break
				surface_y = base_y + y_offset

			# Dig down from surface
			for depth in range(lake_depth):
				var dig_y = surface_y - depth
				var dig_pos = Vector3i(world_x, dig_y, world_z)

				# Remove the block (create air pocket)
				voxel_tool.set_voxel(dig_pos, AIR_ID)

			# Fill with water
			for depth in range(lake_depth):
				var water_y = surface_y - depth
				var water_pos = Vector3i(world_x, water_y, world_z)

				# Top layer gets WATER_TOP, rest get WATER_FULL
				if depth == 0:
					voxel_tool.set_voxel(water_pos, WATER_TOP_ID)
				else:
					voxel_tool.set_voxel(water_pos, WATER_FULL_ID)


func _setup_puzzle_room(template: RuinLibrary.RuinTemplate, world_position: Vector3):
	"""
	Set up a puzzle room by converting push_block voxels to entities
	with the correct gravity and metadata settings
	"""
	# Determine gravity setting based on room name
	var has_gravity = not template.name.contains("zerog")  # "puzzle_room_zerog" has no gravity

	# Find push_block positions in the template
	var blocks_node = get_node_or_null("/root/Main/Game/Blocks")
	var PUSH_BLOCK_ID = 26 # Fallback
	if blocks_node:
		var push_block_def = blocks_node.get_block_by_name("push_block")
		if push_block_def:
			PUSH_BLOCK_ID = push_block_def.base_info.id
	var push_block_positions = []

	for block_data in template.blocks:
		if block_data.block_id == PUSH_BLOCK_ID:
			var world_pos = Vector3i(world_position) + block_data.pos
			push_block_positions.append(world_pos)

	# Convert each push_block voxel to an entity with correct settings
	var push_block_manager = get_node_or_null("/root/Main/Game/PushBlockManager")
	if push_block_manager:
		for pos in push_block_positions:
			push_block_manager.spawn_puzzle_block(pos, has_gravity, template.name)

	var gravity_str = "WITH gravity" if has_gravity else "ZERO-G"
	print("🎮 Puzzle room '%s' setup complete! %d push_block(s) spawned (%s)" % [template.name, push_block_positions.size(), gravity_str])
