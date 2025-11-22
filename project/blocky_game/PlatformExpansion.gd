extends Node

## PlatformExpansion - Generates large sky platforms for base expansion
## Creates two types: Wilderness (with hills/trees) and Construction (flat)

# Block IDs (must match generator.gd)
const GRASS_ID = 2
const DIRT_ID = 1
const STONE_ID = 29
const RUIN_STONE_ID = 33
const AIR_ID = 0
const LOG_Y_ID = 5  # Pine log (voxel ID)
const LEAVES_ID = 8  # Pine leaves (voxel ID)

# Platform constants
const PLATFORM_SIZE_CHUNKS = 10  # 10x10 chunks (was 20x20, too large for 8GB RAM)
const CHUNK_SIZE = 16
const PLATFORM_SIZE_BLOCKS = PLATFORM_SIZE_CHUNKS * CHUNK_SIZE  # 160 blocks
const PLATFORM_THICKNESS = 10  # How thick the platform is
const SPAWN_DISTANCE = 10  # Blocks away from placement point

# Hill generation (for wilderness)
const HILL_HEIGHT_MIN = 0
const HILL_HEIGHT_MAX = 8  # Max 8 block variation
const HILL_FREQUENCY = 1.0 / 24.0  # Rolling hills (matches rust hills)

# Tree placement
const TREE_DENSITY = 0.015  # 1.5% of surface gets trees
const PINE_TREE_CHANCE = 0.6  # 60% pine, 40% birch

var _terrain = null
var _blocks = null
var _noise: FastNoiseLite = null
var _birch_log_voxel_id: int = -1  # Runtime voxel ID for birch_log_y
var _birch_leaves_voxel_id: int = -1  # Runtime voxel ID for birch leaves (if exists)


func initialize(terrain_node: Node, blocks_node: Node):
	"""Initialize with terrain and blocks references"""
	_terrain = terrain_node
	_blocks = blocks_node

	# Initialize noise for hill generation
	_noise = FastNoiseLite.new()
	_noise.seed = randi()  # Random seed each time
	_noise.frequency = HILL_FREQUENCY
	_noise.fractal_octaves = 3
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN

	# Get voxel library and check for birch blocks
	var voxel_library = load("res://blocky_game/blocks/voxel_library.tres")
	if voxel_library:
		_birch_log_voxel_id = voxel_library.get_model_index_from_resource_name("birch_log_y")
		# Note: birch leaves don't exist as a separate block yet, will use pine leaves
		# _birch_leaves_voxel_id = voxel_library.get_model_index_from_resource_name("birch_leaves")

	if _birch_log_voxel_id != -1:
		print("PlatformExpansion: Birch trees available (voxel ID: %d)" % _birch_log_voxel_id)
	else:
		print("PlatformExpansion: Birch trees not found, using pine only")

	print("PlatformExpansion: Initialized")


func generate_wilderness_platform(placement_pos: Vector3) -> bool:
	"""Generate a wilderness platform with hills and trees"""
	print("🌿 Generating Wilderness Expansion at: %s" % placement_pos)

	# Calculate spawn position (10 blocks away from placement)
	var spawn_pos = _calculate_spawn_position(placement_pos)

	# Generate platform with VoxelViewer trick
	var success = await _generate_platform_base(spawn_pos, true)

	if success:
		print("✅ Wilderness platform generated successfully!")
	else:
		print("❌ Failed to generate wilderness platform")

	return success


func generate_flat_platform(placement_pos: Vector3) -> bool:
	"""Generate a flat construction platform"""
	print("🏗️ Generating Construction Platform at: %s" % placement_pos)

	# Calculate spawn position (10 blocks away from placement)
	var spawn_pos = _calculate_spawn_position(placement_pos)

	# Generate platform with VoxelViewer trick
	var success = await _generate_platform_base(spawn_pos, false)

	if success:
		print("✅ Construction platform generated successfully!")
	else:
		print("❌ Failed to generate construction platform")

	return success


func generate_terrain_extraction(placement_pos: Vector3) -> bool:
	"""Generate a terrain extraction platform - rips terrain from ground and places in sky"""
	print("🌍 Generating Terrain Extraction (ripping earth from ground)...")

	# Calculate spawn position (10 blocks away from placement)
	var spawn_pos = _calculate_spawn_position(placement_pos)

	# Generate platform by copying ground terrain
	var success = await _generate_extracted_terrain(placement_pos, spawn_pos)

	if success:
		print("✅ Terrain extraction complete! Earth ripped from ground!")
	else:
		print("❌ Failed to extract terrain")

	return success


func _calculate_spawn_position(placement_pos: Vector3) -> Vector3:
	"""Calculate where the platform should spawn (10 blocks away)"""
	# For now, spawn 10 blocks to the north (negative Z)
	# TODO: Could detect which edge of ruin player is on and spawn accordingly
	return Vector3(
		placement_pos.x,
		placement_pos.y,  # Same Y level as placement
		placement_pos.z - SPAWN_DISTANCE
	)


func _generate_extracted_terrain(placement_pos: Vector3, spawn_pos: Vector3) -> bool:
	"""Extract terrain from ground beneath placement and copy to sky platform"""
	if not _terrain:
		push_error("PlatformExpansion: Terrain not initialized")
		return false

	print("📍 Scanning ground beneath placement position...")
	print("Building extracted terrain directly (chunks will load as needed)...")

	# Get voxel tool
	var voxel_tool = _terrain.get_voxel_tool()
	if not voxel_tool:
		push_error("PlatformExpansion: Failed to get voxel tool")
		return false

	voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE

	# STEP 1: Scan down to find lowest ground point in 160x160 area
	print("🔍 Scanning 160x160 area to find lowest ground point...")
	var scan_base = Vector3i(placement_pos.x, placement_pos.y, placement_pos.z)
	var lowest_ground_y = _find_lowest_ground_in_area(scan_base, voxel_tool)

	if lowest_ground_y == -999:
		push_error("PlatformExpansion: Could not find ground")
		return false

	print("✓ Lowest ground point found at Y=%d" % lowest_ground_y)

	# STEP 2: Copy 160x160x20 volume from ground
	print("📋 Copying terrain... (this may take a few seconds)")
	var blocks_copied = _copy_terrain_volume(
		Vector3i(scan_base.x, lowest_ground_y, scan_base.z),  # Source
		Vector3i(spawn_pos),  # Destination
		voxel_tool
	)

	# STEP 3: Generate inverted pyramid support
	var pyramid_blocks = _generate_inverted_pyramid(spawn_pos, voxel_tool)

	print("🎉 Terrain extraction complete! Copied %d blocks + %d pyramid blocks" % [blocks_copied, pyramid_blocks])

	# Register as ruin
	var platform_size = Vector3i(PLATFORM_SIZE_BLOCKS, 20, PLATFORM_SIZE_BLOCKS)
	RuinRegistry.register_ruin(
		spawn_pos,
		"terrain_extraction",
		[],
		platform_size
	)

	return true


func _find_lowest_ground_in_area(base_pos: Vector3i, voxel_tool: VoxelTool) -> int:
	"""Scan 320x320 area to find the lowest non-air block"""
	var lowest_y = 999999
	var scan_step = 8  # Check every 8th block for performance (40x40 samples instead of 320x320)

	for x in range(0, PLATFORM_SIZE_BLOCKS, scan_step):
		for z in range(0, PLATFORM_SIZE_BLOCKS, scan_step):
			var world_x = base_pos.x + x
			var world_z = base_pos.z + z

			# Scan downward from placement Y to find ground
			for y in range(base_pos.y, base_pos.y - 200, -1):  # Scan up to 200 blocks down
				var voxel_id = voxel_tool.get_voxel(Vector3i(world_x, y, world_z))
				if voxel_id != AIR_ID:
					# Found solid ground
					if y < lowest_y:
						lowest_y = y
					break

	if lowest_y == 999999:
		return -999  # Error: no ground found

	return lowest_y


func _copy_terrain_volume(source_base: Vector3i, dest_base: Vector3i, voxel_tool: VoxelTool) -> int:
	"""Copy a 320x320x20 volume from source to destination"""
	var blocks_copied = 0
	var copy_depth = 20  # Copy 20 blocks deep from lowest point

	# Progress tracking
	var total_blocks = PLATFORM_SIZE_BLOCKS * PLATFORM_SIZE_BLOCKS * copy_depth
	var progress_step = total_blocks / 20  # Update every 5%
	var blocks_processed = 0

	for y in range(copy_depth):
		for x in range(PLATFORM_SIZE_BLOCKS):
			for z in range(PLATFORM_SIZE_BLOCKS):
				# Source position
				var source_pos = Vector3i(
					source_base.x + x,
					source_base.y + y,
					source_base.z + z
				)

				# Destination position
				var dest_pos = Vector3i(
					dest_base.x + x,
					dest_base.y + y,
					dest_base.z + z
				)

				# Copy the voxel
				var voxel_id = voxel_tool.get_voxel(source_pos)
				voxel_tool.set_voxel(dest_pos, voxel_id)
				blocks_copied += 1
				blocks_processed += 1

				# Progress update
				if blocks_processed % progress_step == 0:
					var percent = int((float(blocks_processed) / float(total_blocks)) * 100.0)
					print("Ripping terrain from earth... %d%%" % percent)

	return blocks_copied


func _generate_platform_base(spawn_pos: Vector3, is_wilderness: bool) -> bool:
	"""Generate the platform base by placing blocks directly (no VoxelViewer needed)"""
	if not _terrain:
		push_error("PlatformExpansion: Terrain not initialized")
		return false

	print("Building platform directly (chunks will load as blocks are placed)...")

	# Get voxel tool
	var voxel_tool = _terrain.get_voxel_tool()
	if not voxel_tool:
		push_error("PlatformExpansion: Failed to get voxel tool")
		return false

	voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE

	# Generate the platform
	var blocks_placed = 0
	if is_wilderness:
		blocks_placed = _generate_wilderness_terrain(spawn_pos, voxel_tool)
	else:
		blocks_placed = _generate_flat_terrain(spawn_pos, voxel_tool)

	# Generate inverted pyramid support
	var pyramid_blocks = _generate_inverted_pyramid(spawn_pos, voxel_tool)

	print("Platform complete! Placed %d surface blocks + %d pyramid blocks" % [blocks_placed, pyramid_blocks])

	# Register as ruin (so homebase system recognizes it)
	var platform_size = Vector3i(PLATFORM_SIZE_BLOCKS, PLATFORM_THICKNESS, PLATFORM_SIZE_BLOCKS)
	RuinRegistry.register_ruin(
		spawn_pos,
		"expansion_platform" if is_wilderness else "construction_platform",
		[],  # No teleport stones
		platform_size
	)

	return true


func _generate_flat_terrain(spawn_pos: Vector3, voxel_tool: VoxelTool) -> int:
	"""Generate flat construction platform"""
	var blocks_placed = 0
	var base_pos = Vector3i(spawn_pos)

	# Generate flat layers
	for y in range(PLATFORM_THICKNESS):
		var current_y = base_pos.y + y

		# Determine block type based on depth
		var block_id: int
		if y == PLATFORM_THICKNESS - 1:
			block_id = GRASS_ID  # Top layer is grass
		elif y >= PLATFORM_THICKNESS - 4:
			block_id = DIRT_ID  # Upper layers are dirt
		elif y >= 2:
			block_id = STONE_ID  # Middle layers are stone
		else:
			block_id = RUIN_STONE_ID  # Bottom layers are ruin stone

		# Place entire layer
		for x in range(PLATFORM_SIZE_BLOCKS):
			for z in range(PLATFORM_SIZE_BLOCKS):
				var world_pos = Vector3i(
					base_pos.x + x,
					current_y,
					base_pos.z + z
				)
				voxel_tool.set_voxel(world_pos, block_id)
				blocks_placed += 1

	return blocks_placed


func _generate_wilderness_terrain(spawn_pos: Vector3, voxel_tool: VoxelTool) -> int:
	"""Generate wilderness platform with rolling hills and trees"""
	var blocks_placed = 0
	var base_pos = Vector3i(spawn_pos)
	var tree_positions = []  # Store positions for tree placement

	# Generate base platform with hills
	for x in range(PLATFORM_SIZE_BLOCKS):
		for z in range(PLATFORM_SIZE_BLOCKS):
			var world_x = base_pos.x + x
			var world_z = base_pos.z + z

			# Get hill height at this position (0-8 blocks)
			var hill_height = _get_hill_height(world_x, world_z)

			# Calculate top Y for this column
			var surface_y = base_pos.y + PLATFORM_THICKNESS - 1 + hill_height

			# Generate column from bottom to surface
			for y in range(PLATFORM_THICKNESS + HILL_HEIGHT_MAX):
				var current_y = base_pos.y + y

				if current_y > surface_y:
					continue  # Above surface, leave as air

				# Determine block type
				var block_id: int
				var depth_from_surface = surface_y - current_y

				if depth_from_surface == 0:
					block_id = GRASS_ID  # Surface is grass
				elif depth_from_surface <= 3:
					block_id = DIRT_ID  # Upper layers are dirt
				elif depth_from_surface <= 6:
					block_id = STONE_ID  # Middle layers are stone
				else:
					block_id = RUIN_STONE_ID  # Deep layers are ruin stone

				var world_pos = Vector3i(world_x, current_y, world_z)
				voxel_tool.set_voxel(world_pos, block_id)
				blocks_placed += 1

			# Randomly mark for tree placement (only on surface)
			if randf() < TREE_DENSITY:
				tree_positions.append(Vector3i(world_x, surface_y + 1, world_z))

	# Place trees
	var trees_placed = _place_trees(tree_positions, voxel_tool)
	print("Placed %d trees on wilderness platform" % trees_placed)

	return blocks_placed


func _get_hill_height(x: int, z: int) -> int:
	"""Get hill height at position using Perlin noise (0-8 blocks)"""
	var noise_value = _noise.get_noise_2d(x, z)
	# Map noise from [-1, 1] to [0, 8]
	var height = int((noise_value + 1.0) * 4.0)
	return clamp(height, HILL_HEIGHT_MIN, HILL_HEIGHT_MAX)


func _place_trees(positions: Array, voxel_tool: VoxelTool) -> int:
	"""Place trees at specified positions"""
	var trees_placed = 0

	for pos in positions:
		# Randomly choose pine or birch
		var is_pine = randf() < PINE_TREE_CHANCE

		if is_pine:
			_place_pine_tree(pos, voxel_tool)
		else:
			_place_birch_tree(pos, voxel_tool)

		trees_placed += 1

	return trees_placed


func _place_pine_tree(pos: Vector3i, voxel_tool: VoxelTool):
	"""Place a simple pine tree (5-7 blocks tall)"""
	var height = randi() % 3 + 5  # 5-7 blocks tall

	# Trunk
	for y in range(height):
		voxel_tool.set_voxel(Vector3i(pos.x, pos.y + y, pos.z), LOG_Y_ID)

	# Leaves (simple cone shape)
	var top = pos.y + height

	# Top leaf
	voxel_tool.set_voxel(Vector3i(pos.x, top, pos.z), LEAVES_ID)

	# Layer below top (3x3)
	for x in range(-1, 2):
		for z in range(-1, 2):
			voxel_tool.set_voxel(Vector3i(pos.x + x, top - 1, pos.z + z), LEAVES_ID)

	# Two layers below (5x5)
	for y in [top - 2, top - 3]:
		for x in range(-2, 3):
			for z in range(-2, 3):
				if abs(x) + abs(z) <= 3:  # Diamond pattern
					voxel_tool.set_voxel(Vector3i(pos.x + x, y, pos.z + z), LEAVES_ID)


func _place_birch_tree(pos: Vector3i, voxel_tool: VoxelTool):
	"""Place a simple birch tree (4-6 blocks tall) - falls back to pine if birch doesn't exist"""
	var height = randi() % 3 + 4  # 4-6 blocks tall

	# Use birch if available (detected at initialization), otherwise pine
	var log_id = _birch_log_voxel_id if _birch_log_voxel_id != -1 else LOG_Y_ID
	var leaves_id = LEAVES_ID  # Always use pine leaves (birch leaves don't exist yet)

	for y in range(height):
		voxel_tool.set_voxel(Vector3i(pos.x, pos.y + y, pos.z), log_id)

	# Leaves (rounder shape than pine)
	var top = pos.y + height

	# Top layer (3x3)
	for x in range(-1, 2):
		for z in range(-1, 2):
			voxel_tool.set_voxel(Vector3i(pos.x + x, top, pos.z + z), leaves_id)

	# Middle layer (5x5 sphere)
	for x in range(-2, 3):
		for z in range(-2, 3):
			if abs(x) <= 1 or abs(z) <= 1:  # More rounded
				voxel_tool.set_voxel(Vector3i(pos.x + x, top - 1, pos.z + z), leaves_id)


func _generate_inverted_pyramid(spawn_pos: Vector3, voxel_tool: VoxelTool) -> int:
	"""Generate inverted pyramid support beneath platform (copied from RuinSpawner)"""
	var blocks_placed = 0

	# Platform size for pyramid calculation
	var platform_size = Vector3i(PLATFORM_SIZE_BLOCKS, PLATFORM_THICKNESS, PLATFORM_SIZE_BLOCKS)

	# Calculate pyramid dimensions
	var base_width = max(platform_size.x, platform_size.z)
	var pyramid_height = int(base_width * 1.5)

	# Get the bottom Y of the platform
	var platform_bottom_y = int(spawn_pos.y)
	var pyramid_start_y = platform_bottom_y - 1

	# Platform center
	var platform_center_x = int(spawn_pos.x) + platform_size.x / 2
	var platform_center_z = int(spawn_pos.z) + platform_size.z / 2

	# Generate pyramid layer by layer
	for layer in range(pyramid_height):
		var current_y = pyramid_start_y - layer

		# Scaling factor (1.0 at top, 0.0 at bottom)
		var layer_progress = float(pyramid_height - layer - 1) / float(pyramid_height)

		# Current layer width
		var current_width = int(float(base_width) * layer_progress)
		if current_width < 1:
			current_width = 1

		# Determine block type based on depth
		var block_id: int
		if layer == 0:
			block_id = GRASS_ID  # Top layer grass
		else:
			if layer_progress > 0.67:
				block_id = DIRT_ID  # Top 33%
			elif layer_progress > 0.33:
				block_id = STONE_ID  # Middle 33%
			else:
				block_id = RUIN_STONE_ID  # Bottom 33%

		# Place blocks in square pattern with jaggedness
		for x in range(-current_width, current_width + 1):
			for z in range(-current_width, current_width + 1):
				var jag_threshold = randf() * 0.3
				var distance_from_center = max(abs(x), abs(z))

				if distance_from_center <= current_width + jag_threshold:
					var world_x = platform_center_x + x
					var world_z = platform_center_z + z
					var block_pos = Vector3i(world_x, current_y, world_z)

					# Don't overwrite existing platform blocks
					var existing = voxel_tool.get_voxel(block_pos)
					if existing == AIR_ID:
						voxel_tool.set_voxel(block_pos, block_id)
						blocks_placed += 1

	return blocks_placed
