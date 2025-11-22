extends Node

# Generates large sky platforms for base expansion
# Uses RuinSpawner's proven code instead of custom generation

const PLATFORM_SIZE_BLOCKS = 120  # 120x120 blocks (safe for 8GB RAM)
const PLATFORM_THICKNESS = 5  # Layers thick

# Block IDs
const GRASS_ID = 2
const DIRT_ID = 1
const STONE_ID = 29
const RUIN_STONE_ID = 33
const AIR_ID = 0

var _terrain = null
var _blocks = null


func initialize(terrain_node: Node, blocks_node: Node):
	"""Initialize with terrain and blocks references"""
	_terrain = terrain_node
	_blocks = blocks_node
	print("PlatformExpansion initialized")


func generate_flat_platform(placement_pos: Vector3) -> bool:
	"""Generate a 120x120 flat construction platform using RuinSpawner"""
	print("🏗️ Generating 120x120 Flat Construction Platform at: %s" % placement_pos)

	# Create a simple flat platform "ruin" (just blocks, no structures)
	var platform_blocks = _create_flat_platform_blocks()

	# Use RuinSpawner to handle all the complexity
	var ruin_spawner = get_node("/root/Main/Game/RuinSpawner")
	if not ruin_spawner:
		push_error("RuinSpawner not found!")
		return false

	# Spawn at player's current height
	var spawn_pos = placement_pos

	# Create temporary RuinTemplate
	var RuinLibrary = preload("res://blocky_game/ruins/RuinLibrary.gd")
	var temp_template = RuinLibrary.RuinTemplate.new()
	temp_template.name = "flat_construction_platform"
	temp_template.size = Vector3i(PLATFORM_SIZE_BLOCKS, PLATFORM_THICKNESS, PLATFORM_SIZE_BLOCKS)
	temp_template.blocks = platform_blocks
	temp_template.teleport_stone_positions = []  # No teleport stones

	# Use RuinSpawner's proven spawn_ruin_at logic
	var result = await _spawn_platform_as_ruin(spawn_pos, temp_template)

	if result != Vector3.ZERO:
		print("✅ Flat construction platform generated successfully!")
		return true
	else:
		print("❌ Failed to generate construction platform")
		return false


func generate_wilderness_platform(placement_pos: Vector3) -> bool:
	"""Generate a 120x120 wilderness platform (flat for now, can add terrain later)"""
	print("🌿 Generating 120x120 Wilderness Platform at: %s" % placement_pos)

	# For now, just create flat platform (can add terrain noise later)
	var platform_blocks = _create_flat_platform_blocks()

	var ruin_spawner = get_node("/root/Main/Game/RuinSpawner")
	if not ruin_spawner:
		push_error("RuinSpawner not found!")
		return false

	var spawn_pos = placement_pos

	var RuinLibrary = preload("res://blocky_game/ruins/RuinLibrary.gd")
	var temp_template = RuinLibrary.RuinTemplate.new()
	temp_template.name = "wilderness_expansion"
	temp_template.size = Vector3i(PLATFORM_SIZE_BLOCKS, PLATFORM_THICKNESS, PLATFORM_SIZE_BLOCKS)
	temp_template.blocks = platform_blocks
	temp_template.teleport_stone_positions = []

	var result = await _spawn_platform_as_ruin(spawn_pos, temp_template)

	if result != Vector3.ZERO:
		print("✅ Wilderness platform generated successfully!")
		return true
	else:
		print("❌ Failed to generate wilderness platform")
		return false


func generate_terrain_extraction(placement_pos: Vector3) -> bool:
	"""Generate a terrain extraction platform - copies ground terrain to sky"""
	print("🌍 Generating Terrain Extraction Platform at: %s" % placement_pos)

	# TODO: Scan ground below and copy voxels
	# For now, just create flat platform
	var platform_blocks = _create_flat_platform_blocks()

	var ruin_spawner = get_node("/root/Main/Game/RuinSpawner")
	if not ruin_spawner:
		push_error("RuinSpawner not found!")
		return false

	var spawn_pos = placement_pos

	var RuinLibrary = preload("res://blocky_game/ruins/RuinLibrary.gd")
	var temp_template = RuinLibrary.RuinTemplate.new()
	temp_template.name = "terrain_extraction"
	temp_template.size = Vector3i(PLATFORM_SIZE_BLOCKS, PLATFORM_THICKNESS, PLATFORM_SIZE_BLOCKS)
	temp_template.blocks = platform_blocks
	temp_template.teleport_stone_positions = []

	var result = await _spawn_platform_as_ruin(spawn_pos, temp_template)

	if result != Vector3.ZERO:
		print("✅ Terrain extraction platform generated successfully!")
		return true
	else:
		print("❌ Failed to generate extraction platform")
		return false


func _create_flat_platform_blocks() -> Array:
	"""Create block array for flat 120x120 platform (5 layers thick)"""
	var blocks = []

	for y in range(PLATFORM_THICKNESS):
		# Determine block type based on layer
		var block_id: int
		if y == PLATFORM_THICKNESS - 1:
			block_id = GRASS_ID  # Top layer
		elif y >= PLATFORM_THICKNESS - 4:
			block_id = DIRT_ID  # Upper layers
		elif y >= 2:
			block_id = STONE_ID  # Middle layers
		else:
			block_id = RUIN_STONE_ID  # Bottom layers

		# Place entire layer
		for x in range(PLATFORM_SIZE_BLOCKS):
			for z in range(PLATFORM_SIZE_BLOCKS):
				blocks.append({
					"pos": Vector3i(x, y, z),
					"block_id": block_id,
					"variant": 0
				})

	print("Created flat platform template with %d blocks" % blocks.size())
	return blocks


func _spawn_platform_as_ruin(spawn_pos: Vector3, template) -> Vector3:
	"""Use RuinSpawner's proven code to spawn the platform"""
	if not _terrain:
		push_error("Terrain not initialized")
		return Vector3.ZERO

	# FORCE CHUNK GENERATION: Create temporary VoxelViewer
	print("Creating VoxelViewer for chunk generation...")
	var temp_viewer = VoxelViewer.new()
	temp_viewer.position = spawn_pos + Vector3(PLATFORM_SIZE_BLOCKS / 2, 0, PLATFORM_SIZE_BLOCKS / 2)
	temp_viewer.view_distance = 128  # Cover 120x120 + pyramid
	temp_viewer.requires_visuals = true
	temp_viewer.requires_collisions = true
	_terrain.add_child(temp_viewer)

	# Wait for chunks to generate
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
	for block_data in template.blocks:
		var block_pos: Vector3i = block_data.pos
		var block_id: int = block_data.block_id
		var variant: int = block_data.get("variant", 0)

		# Calculate world position
		var world_block_pos = Vector3i(spawn_pos) + block_pos

		# Get the block and its voxel ID
		var block = _blocks.get_block(block_id)
		if block == null:
			push_warning("Block ID ", block_id, " not found, skipping")
			continue

		# Get the voxel value to place
		var voxel_id = block.base_info.voxels[variant] if variant < block.base_info.voxels.size() else block.base_info.voxels[0]

		# Place the block
		voxel_tool.set_voxel(world_block_pos, voxel_id)
		blocks_placed += 1

	# Generate inverted pyramid beneath the platform (using RuinSpawner's code)
	var pyramid_blocks_placed = _generate_inverted_pyramid(voxel_tool, spawn_pos, template.size)

	# Clean up temporary VoxelViewer
	temp_viewer.queue_free()

	# Register this platform with RuinRegistry
	RuinRegistry.register_ruin(
		spawn_pos,
		template.name,
		[],  # No teleport stones
		template.size
	)

	print("Placed ", blocks_placed, " platform blocks + ", pyramid_blocks_placed, " pyramid blocks")
	return spawn_pos


func _generate_inverted_pyramid(voxel_tool, world_position: Vector3, ruin_size: Vector3i) -> int:
	"""
	Generate an inverted pyramid beneath a flying platform.
	EXACT COPY from RuinSpawner.gd - proven to work!
	"""
	var blocks_placed = 0

	# Get block IDs (using voxel IDs directly, not block IDs)
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
