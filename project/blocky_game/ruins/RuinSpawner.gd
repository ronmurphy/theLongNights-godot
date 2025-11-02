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


func spawn_ruin_at(world_position: Vector3, ruin_name: String = "") -> Vector3:
	"""
	Spawn a ruin at the specified world position (can be in the sky!)
	If ruin_name is empty, a random ruin will be selected
	Returns the spawn position, or Vector3.ZERO if failed
	"""
	if _ruin_library == null:
		push_error("RuinSpawner not initialized - RuinLibrary is null")
		return Vector3.ZERO

	if _terrain == null:
		push_error("RuinSpawner not initialized - Terrain is null")
		return Vector3.ZERO

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

		# Place the block
		voxel_tool.set_voxel(world_block_pos, voxel_id)
		blocks_placed += 1

	# Clean up temporary VoxelViewer
	temp_viewer.queue_free()

	# Register this ruin with the RuinRegistry
	var ruin_data = RuinRegistry.register_ruin(world_position, template.name, template.teleport_stone_positions)

	# Add glowing lights at all teleport stone positions with correct colors
	for i in range(ruin_data.teleport_stones.size()):
		var stone = ruin_data.teleport_stones[i]
		var stone_world_pos = world_position + Vector3(stone.local_pos)
		_add_teleport_stone_light(stone_world_pos, stone.glow_color)

	print("Placed ", blocks_placed, " blocks for ruin '", template.name, "' (", ruin_data.ruin_name, ") with ", template.teleport_stone_positions.size(), " teleport stone(s)")
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

	var ruin_pos = await spawn_ruin_at(spawn_position, "crashed_tower_small")
	if ruin_pos != Vector3.ZERO:
		print("Successfully spawned initial ruin at: ", spawn_position)
		return spawn_position
	else:
		push_error("Failed to spawn initial ruin")
		return Vector3.ZERO


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
