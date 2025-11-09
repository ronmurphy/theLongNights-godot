
const Blocks = preload("../blocks/blocks.gd")
const Util = preload("res://common/util.gd")
const WaterUpdater = preload("./../water.gd")

# Bedrock voxel ID (from generator.gd)
const BEDROCK_VOXEL_ID = 28


static func safe_set_voxel(voxel_tool: VoxelTool, pos: Vector3, voxel_id: int) -> bool:
	"""
	Safely set a voxel with bedrock protection.
	Returns true if voxel was set, false if blocked (bedrock protection).

	Use this instead of voxel_tool.set_voxel() for all destructive operations
	(mining, explosions, cleararea, etc.)
	"""
	# Check if current voxel at this position is bedrock
	var current_voxel = voxel_tool.get_voxel(pos)
	if current_voxel == BEDROCK_VOXEL_ID:
		# Bedrock is indestructible - refuse to change it
		return false

	# Safe to modify - not bedrock
	voxel_tool.set_voxel(pos, voxel_id)
	return true


static func place_single_block(terrain_tool: VoxelTool, pos: Vector3, look_dir: Vector3,
	block_id: int, block_types: Blocks, water_updater: WaterUpdater):
	
	var block := block_types.get_block(block_id)
	var voxel_id := 0

	match block.base_info.rotation_type:
		Blocks.ROTATION_TYPE_NONE:
			voxel_id = block.base_info.voxels[0]
		
		Blocks.ROTATION_TYPE_AXIAL:
			var axis := Util.get_longest_axis(look_dir)
			voxel_id = block.base_info.voxels[axis]
		
		Blocks.ROTATION_TYPE_Y:
			var rot := Blocks.get_y_rotation_from_look_dir(look_dir)
			voxel_id = block.base_info.voxels[rot]

		Blocks.ROTATION_TYPE_CUSTOM_BEHAVIOR:
			block.place(terrain_tool, pos, look_dir)
		_:
			# Unknown value
			assert(false)
	
	if block.base_info.rotation_type != Blocks.ROTATION_TYPE_CUSTOM_BEHAVIOR:
		# Use safe_set_voxel for bedrock protection
		safe_set_voxel(terrain_tool, pos, voxel_id)

	water_updater.schedule(pos)

