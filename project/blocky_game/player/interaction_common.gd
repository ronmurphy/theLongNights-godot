
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
	if block:
		print("🔨 Placing block: ", block.base_info.name, " (ID: ", block_id, ")")
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
	
	# Special handling: ruin_void_lamp needs a light attached
	if block and block.base_info.name == "ruin_void_lamp":
		print("🔦 Placing ruin_void_lamp, spawning light...")
		_spawn_ruin_void_lamp_light(pos)


static func _spawn_ruin_void_lamp_light(block_pos: Vector3):
	"""Spawn a PlacedLightOrb on top of a ruin_void_lamp block"""
	# Get the world container where lights are spawned (same as light_orb.gd uses)
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		return
	
	var world_container = tree.root.get_node_or_null("Main/Game")
	if not world_container:
		print("⚠️ Could not find Game container for ruin_void_lamp light")
		return
	
	# Load the PlacedLightOrb script
	const PlacedLightOrb = preload("../items/light_orb/placed_light_orb.gd")
	
	# Create the light orb
	var orb = Node3D.new()
	orb.set_script(PlacedLightOrb)
	
	# IMPORTANT: Set custom range BEFORE adding to tree (so _ready() uses it)
	orb.set("_custom_range", 15.0)
	
	# Add to world FIRST (this calls _ready())
	world_container.add_child(orb)
	
	# THEN set position after _ready() has created the visuals
	orb.global_position = Vector3(block_pos) + Vector3(0.5, 1.0, 0.5)
	
	print("✨ Spawned ruin_void_lamp light at ", orb.global_position)
	
	# Register with LampManager for persistence
	var lamp_manager = tree.root.get_node_or_null("/root/LampManager")
	if lamp_manager:
		lamp_manager.register_lamp(block_pos, "cyan")


