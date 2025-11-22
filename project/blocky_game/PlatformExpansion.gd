extends Node

# Expands existing sky ruins from their center point
# Preserves all structures, only adds blocks in air

const EXPANSION_AMOUNT = 80  # Blocks to expand in each direction
const GROUND_LAYERS = 3  # Number of ground layers (typically dirt+dirt+grass)

var _terrain = null
var _blocks = null


func initialize(terrain_node: Node, blocks_node: Node):
	"""Initialize with terrain and blocks references"""
	_terrain = terrain_node
	_blocks = blocks_node
	print("PlatformExpansion initialized")


func expand_ruin(player_pos: Vector3) -> bool:
	"""Expand the ruin that the player is currently standing on"""
	print("🏗️ Attempting to expand ruin from player position: %s" % player_pos)

	# Find the ruin the player is standing on
	var current_ruin = _find_ruin_at_position(player_pos)
	if current_ruin == null:
		push_error("❌ Player is not standing on a registered ruin!")
		return false

	print("📍 Found ruin: %s at %s (size: %s)" % [current_ruin.ruin_name, current_ruin.position, current_ruin.ruin_size])

	# Check if already expanded
	if current_ruin.has_meta("has_been_expanded"):
		push_error("❌ This ruin has already been expanded!")
		return false

	# Detect the ACTUAL current platform size (not just registered structure size)
	# This accounts for homebase fences and any existing expansions
	print("🔍 Scanning terrain to detect actual platform size...")
	var actual_platform = _detect_actual_platform_size(current_ruin)

	print("📏 Registered size: %s, Actual platform detected: %s" % [current_ruin.ruin_size, actual_platform.size])

	# Calculate new bounds (expand from current platform, not just structure)
	var original_pos = actual_platform.position
	var original_size = actual_platform.size
	var new_pos = original_pos - Vector3(EXPANSION_AMOUNT, 0, EXPANSION_AMOUNT)
	var new_size = original_size + Vector3i(EXPANSION_AMOUNT * 2, 0, EXPANSION_AMOUNT * 2)

	print("📐 Expansion: %s → %s (new size: %s)" % [original_pos, new_pos, new_size])

	# Perform the expansion
	var success = await _expand_ruin_platform(original_pos, original_size, new_pos, new_size)

	if success:
		# Mark as expanded in RuinRegistry
		current_ruin.set_meta("has_been_expanded", true)
		# Update size in registry
		current_ruin.ruin_size = new_size
		current_ruin.position = new_pos
		print("✅ Ruin expansion complete!")
		return true
	else:
		print("❌ Ruin expansion failed!")
		return false


func _detect_actual_platform_size(ruin: RuinRegistry.RuinData) -> Dictionary:
	"""
	Scan the terrain to detect the actual current platform size
	This accounts for homebase fences and any existing expansions
	Returns: {position: Vector3, size: Vector3i}
	"""
	var voxel_tool = _terrain.get_voxel_tool()
	if not voxel_tool:
		push_warning("Could not get voxel tool, using registered size")
		return {"position": ruin.position, "size": ruin.ruin_size}

	const GRASS_ID = 2
	const DIRT_ID = 1
	const MAX_SCAN_DISTANCE = 150  # Don't scan more than 150 blocks in each direction

	# Start from ruin center
	var ruin_center = ruin.position + Vector3(ruin.ruin_size) / 2.0
	var scan_y = int(ruin.position.y)  # Scan at the bottom Y level of the ruin

	# Scan in all 4 directions to find platform edges
	var min_x = ruin_center.x
	var max_x = ruin_center.x
	var min_z = ruin_center.z
	var max_z = ruin_center.z

	# Scan East (+X)
	for x_offset in range(1, MAX_SCAN_DISTANCE):
		var check_pos = Vector3i(int(ruin_center.x) + x_offset, scan_y, int(ruin_center.z))
		var voxel = voxel_tool.get_voxel(check_pos)
		if voxel == GRASS_ID or voxel == DIRT_ID:
			max_x = check_pos.x
		else:
			break

	# Scan West (-X)
	for x_offset in range(1, MAX_SCAN_DISTANCE):
		var check_pos = Vector3i(int(ruin_center.x) - x_offset, scan_y, int(ruin_center.z))
		var voxel = voxel_tool.get_voxel(check_pos)
		if voxel == GRASS_ID or voxel == DIRT_ID:
			min_x = check_pos.x
		else:
			break

	# Scan South (+Z)
	for z_offset in range(1, MAX_SCAN_DISTANCE):
		var check_pos = Vector3i(int(ruin_center.x), scan_y, int(ruin_center.z) + z_offset)
		var voxel = voxel_tool.get_voxel(check_pos)
		if voxel == GRASS_ID or voxel == DIRT_ID:
			max_z = check_pos.z
		else:
			break

	# Scan North (-Z)
	for z_offset in range(1, MAX_SCAN_DISTANCE):
		var check_pos = Vector3i(int(ruin_center.x), scan_y, int(ruin_center.z) - z_offset)
		var voxel = voxel_tool.get_voxel(check_pos)
		if voxel == GRASS_ID or voxel == DIRT_ID:
			min_z = check_pos.z
		else:
			break

	# Calculate actual platform bounds
	var actual_pos = Vector3(min_x, ruin.position.y, min_z)
	var actual_size = Vector3i(int(max_x - min_x + 1), ruin.ruin_size.y, int(max_z - min_z + 1))

	print("  Platform edges: X[%d to %d], Z[%d to %d]" % [min_x, max_x, min_z, max_z])

	return {"position": actual_pos, "size": actual_size}


func _find_ruin_at_position(pos: Vector3) -> RuinRegistry.RuinData:
	"""Find the nearest ruin to the given position (within reasonable distance)"""
	var ruins = RuinRegistry.get_all_ruins()

	print("🔍 Looking for ruin at player position: %s" % pos)
	print("🔍 Total ruins registered: %d" % ruins.size())

	var nearest_ruin = null
	var nearest_distance = INF
	const MAX_SEARCH_DISTANCE = 100.0  # Player must be within 100 blocks horizontally

	for ruin in ruins:
		var ruin_pos = ruin.position
		var ruin_size = ruin.ruin_size

		# Calculate ruin center (more accurate than corner)
		var ruin_center = ruin_pos + Vector3(ruin_size) / 2.0

		# Calculate horizontal distance (ignore Y for now)
		var horizontal_offset = Vector2(pos.x - ruin_center.x, pos.z - ruin_center.z)
		var horizontal_distance = horizontal_offset.length()

		# Check if player is roughly at the same Y level (within ruin height + some tolerance)
		var y_min = ruin_pos.y - 10  # Allow standing below ruin (on pyramid)
		var y_max = ruin_pos.y + ruin_size.y + 50  # Allow standing well above ruin
		var is_at_correct_height = pos.y >= y_min and pos.y <= y_max

		print("  📦 Checking ruin '%s':" % ruin.ruin_name)
		print("     Center: %s, Horizontal distance: %.1f blocks, Y check: %s" % [ruin_center, horizontal_distance, is_at_correct_height])

		# If player is at the right height and closer than previous best match
		if is_at_correct_height and horizontal_distance < nearest_distance and horizontal_distance <= MAX_SEARCH_DISTANCE:
			nearest_ruin = ruin
			nearest_distance = horizontal_distance
			print("  ✅ New closest ruin! (distance: %.1f)" % horizontal_distance)

	if nearest_ruin:
		print("✅ Found nearest ruin: '%s' at distance %.1f blocks" % [nearest_ruin.ruin_name, nearest_distance])
		return nearest_ruin
	else:
		print("❌ No ruin found within %d blocks" % MAX_SEARCH_DISTANCE)
		return null


func _expand_ruin_platform(original_pos: Vector3, original_size: Vector3i, new_pos: Vector3, new_size: Vector3i) -> bool:
	"""Expand the ruin platform by adding blocks around the edges"""
	if not _terrain:
		push_error("Terrain not initialized")
		return false

	# Create VoxelViewer to load chunks in expanded area
	print("Creating VoxelViewer for expanded area...")
	var temp_viewer = VoxelViewer.new()
	var center = new_pos + Vector3(new_size) / 2.0
	temp_viewer.position = center
	temp_viewer.view_distance = max(new_size.x, new_size.z) / 2 + 20  # Cover entire area
	temp_viewer.requires_visuals = true
	temp_viewer.requires_collisions = true
	_terrain.add_child(temp_viewer)

	# Wait for chunks to generate
	print("Waiting for chunks to load...")
	await get_tree().create_timer(3.0).timeout
	print("Chunks loaded, expanding platform...")

	# Get voxel tool
	var voxel_tool = _terrain.get_voxel_tool()
	if not voxel_tool:
		temp_viewer.queue_free()
		push_error("Failed to get voxel tool")
		return false

	# Place expansion blocks (only in AIR, only outside original bounds)
	var blocks_placed = _place_expansion_blocks(voxel_tool, original_pos, original_size, new_pos, new_size)

	# Regenerate inverted pyramid with new size
	print("Regenerating inverted pyramid for expanded ruin...")
	var pyramid_blocks = _regenerate_pyramid(voxel_tool, new_pos, new_size)

	# Clean up VoxelViewer
	temp_viewer.queue_free()

	print("Expansion complete! Placed %d blocks + %d pyramid blocks" % [blocks_placed, pyramid_blocks])
	return true


func _place_expansion_blocks(voxel_tool: VoxelTool, original_pos: Vector3, original_size: Vector3i, new_pos: Vector3, new_size: Vector3i) -> int:
	"""Place blocks in the expansion area (only in air, only outside original bounds)"""
	var blocks_placed = 0
	var base_pos = Vector3i(new_pos)

	# Block IDs (using voxel IDs directly)
	const GRASS_ID = 2
	const DIRT_ID = 1
	const AIR_ID = 0

	# Determine ground layer structure from original ruin
	var ground_y = int(original_pos.y)

	# Place blocks layer by layer
	for y in range(GROUND_LAYERS):
		var current_y = ground_y + y
		var block_id = DIRT_ID
		if y == GROUND_LAYERS - 1:  # Top layer is grass
			block_id = GRASS_ID

		# Loop through entire new area
		for x in range(new_size.x):
			for z in range(new_size.z):
				var world_x = base_pos.x + x
				var world_z = base_pos.z + z
				var block_pos = Vector3i(world_x, current_y, world_z)

				# Skip if this position is within the ORIGINAL bounds (preserve existing)
				var is_in_original = \
					world_x >= original_pos.x and world_x < original_pos.x + original_size.x and \
					world_z >= original_pos.z and world_z < original_pos.z + original_size.z

				if not is_in_original:
					# Only place if it's air (don't overwrite anything)
					var existing = voxel_tool.get_voxel(block_pos)
					if existing == AIR_ID:
						voxel_tool.set_voxel(block_pos, block_id)
						blocks_placed += 1

	return blocks_placed


func _regenerate_pyramid(voxel_tool: VoxelTool, world_position: Vector3, ruin_size: Vector3i) -> int:
	"""
	Regenerate inverted pyramid for the expanded ruin
	EXACT COPY from RuinSpawner.gd - proven to work!
	"""
	var blocks_placed = 0

	# Block IDs (using voxel IDs directly)
	const GRASS_VOXEL_ID = 2
	const DIRT_VOXEL_ID = 1
	const STONE_VOXEL_ID = 29
	const RUIN_STONE_VOXEL_ID = 33
	const AIR_VOXEL_ID = 0

	# Calculate pyramid dimensions based on ruin size
	var base_width = max(ruin_size.x, ruin_size.z)
	var pyramid_height = int(base_width * 1.5)

	# Get the bottom Y of the ruin (this is where the flat top of pyramid should be)
	var ruin_bottom_y = int(world_position.y)
	var pyramid_start_y = ruin_bottom_y - 1  # Start one block below the ruin bottom

	# Ruin center
	var ruin_center_x = int(world_position.x) + ruin_size.x / 2
	var ruin_center_z = int(world_position.z) + ruin_size.z / 2

	# Generate pyramid layer by layer from top to bottom
	for layer in range(pyramid_height):
		var current_y = pyramid_start_y - layer

		# Calculate the scaling factor for this layer (1.0 at top, 0.0 at bottom for proper taper)
		var layer_progress = float(pyramid_height - layer - 1) / float(pyramid_height)

		# Current layer size (tapers as we go down)
		var current_width = int(float(base_width) * layer_progress)
		if current_width < 1:
			current_width = 1

		# Determine block type based on depth
		var block_voxel_id: int
		if layer == 0:  # Only the very first (top) layer is grass
			block_voxel_id = GRASS_VOXEL_ID
		else:  # Remaining layers: Dirt → Stone → Ruin Stone gradient
			if layer_progress > 0.67:  # Top 33% - Dirt
				block_voxel_id = DIRT_VOXEL_ID
			elif layer_progress > 0.33:  # Middle 33% - Stone
				block_voxel_id = STONE_VOXEL_ID
			else:  # Bottom 33% - Ruin Stone
				block_voxel_id = RUIN_STONE_VOXEL_ID

		# Place blocks in a square pattern, with slight jaggedness
		for x in range(-current_width, current_width + 1):
			for z in range(-current_width, current_width + 1):
				# Add slight randomness for jagged edges
				var jag_threshold = randf() * 0.3  # 30% randomness
				var distance_from_center = max(abs(x), abs(z))

				# Create diamond/square pattern (slightly jagged)
				if distance_from_center <= current_width + jag_threshold:
					var world_x = ruin_center_x + x
					var world_z = ruin_center_z + z
					var block_pos = Vector3i(world_x, current_y, world_z)

					# Don't overwrite existing blocks (the ruin itself)
					var existing_voxel = voxel_tool.get_voxel(block_pos)
					if existing_voxel == AIR_VOXEL_ID:
						voxel_tool.set_voxel(block_pos, block_voxel_id)
						blocks_placed += 1

	if blocks_placed > 0:
		print("Generated inverted pyramid with ", blocks_placed, " blocks (height: ", pyramid_height, ", base: ", base_width, ")")

	return blocks_placed
