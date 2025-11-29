extends "../item.gd"
## Gauntlet of Strength - Tool for picking up and carrying push_blocks
## Left-click to pickup/putdown blocks
## Displays carried block on left side of screen

const SERVER_PEER_ID = 1

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")
@onready var _head : Camera3D = null  # Will be set when used

const MAX_PICKUP_DISTANCE = 3.0  # Range to pick up blocks
const CARRIED_BLOCK_SCALE = 0.5  # Visual scale when carrying

# Carrying state
var _carrying_block: Node3D = null  # Reference to picked-up entity
var _carried_block_mesh: MeshInstance3D = null  # Visual mesh in hand
var _carried_block_data: Dictionary = {}  # Preserved properties


func get_mining_power() -> int:
	return 0  # Not a mining tool


func use(trans: Transform3D, inv_item_or_count = 1):
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_use", trans)
	else:
		_use(trans, inv_item_or_count)


func _use(trans: Transform3D, inv_item_or_count):
	var origin = trans.origin
	var direction = -trans.basis.z.normalized()
	
	# Get head reference if not set
	if _head == null:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			_head = player.get_node_or_null("Camera")
	
	if not _carrying_block:
		# PICKUP MODE
		_try_pickup_block(origin, direction)
	else:
		# PUTDOWN MODE
		_try_putdown_block(origin, direction)


func _try_pickup_block(origin: Vector3, direction: Vector3):
	"""Try to pick up a push_block in range"""
	# Find push_block entity
	var target_block = _find_target_push_block(origin, direction)
	
	# If no entity found, check for voxel push_block
	if not target_block:
		var voxel_pos = _find_push_block_voxel(origin, direction)
		if voxel_pos != Vector3.ZERO:
			# Spawn entity from voxel
			var manager = get_node_or_null("/root/Main/Game/PushBlockManager")
			if manager and manager.has_method("create_push_block_at"):
				manager.create_push_block_at(Vector3i(voxel_pos))
				
				# Wait a frame for entity to spawn
				await get_tree().process_frame
				
				# Find the spawned entity
				target_block = _find_spawned_block_at(Vector3i(voxel_pos))
	
	if target_block:
		_pickup_block(target_block)
	else:
		print("🧤 No push_block in range to pick up")


func _try_putdown_block(origin: Vector3, direction: Vector3):
	"""Try to place the carried block in front of player"""
	if not _carrying_block:
		return
	
	# Calculate placement position (1 block in front of player's feet)
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var player_pos = player.global_position
	var forward_xz = Vector3(direction.x, 0, direction.z).normalized()
	var placement_pos = player_pos + forward_xz * 1.5
	
	# Snap to voxel grid
	var voxel_pos = Vector3i(
		int(floor(placement_pos.x)),
		int(floor(placement_pos.y)),
		int(floor(placement_pos.z))
	)
	
	# Check if placement location is valid (air)
	if _is_valid_placement(voxel_pos):
		_putdown_block(voxel_pos)
	else:
		print("🧤 Cannot place block here - location blocked")


func _pickup_block(block: Node3D):
	"""Pick up a push_block entity"""
	_carrying_block = block
	
	# Preserve block properties
	_carried_block_data = {
		"puzzle_room_id": block.get("puzzle_room_id") if "puzzle_room_id" in block else "",
		"spawn_position": block.get("spawn_position") if "spawn_position" in block else Vector3.ZERO,
		"gravity": block.get("gravity") if "gravity" in block else 20.0,
		"is_island_puzzle": block.get("is_island_puzzle") if "is_island_puzzle" in block else false,
		"island_base_y": block.get("island_base_y") if "island_base_y" in block else 0.0,
		"teleport_stone_pos": block.get("teleport_stone_pos") if "teleport_stone_pos" in block else Vector3i.ZERO,
	}
	
	# Hide the actual entity
	block.visible = false
	block.set_process(false)
	block.set_physics_process(false)
	
	# Create visual mesh in hand
	_create_carried_block_visual()
	
	print("🧤 Picked up push_block!")


func _putdown_block(voxel_pos: Vector3i):
	"""Place the carried block at the specified position"""
	if not _carrying_block:
		return
	
	# Move entity to placement position
	_carrying_block.global_position = Vector3(
		voxel_pos.x + 0.5,
		voxel_pos.y + 0.5,
		voxel_pos.z + 0.5
	)
	
	# Restore block properties
	if _carried_block_data.has("puzzle_room_id"):
		_carrying_block.set("puzzle_room_id", _carried_block_data["puzzle_room_id"])
	if _carried_block_data.has("spawn_position"):
		_carrying_block.set("spawn_position", _carried_block_data["spawn_position"])
	if _carried_block_data.has("gravity"):
		_carrying_block.set("gravity", _carried_block_data["gravity"])
	if _carried_block_data.has("is_island_puzzle"):
		_carrying_block.set("is_island_puzzle", _carried_block_data["is_island_puzzle"])
	if _carried_block_data.has("island_base_y"):
		_carrying_block.set("island_base_y", _carried_block_data["island_base_y"])
	if _carried_block_data.has("teleport_stone_pos"):
		_carrying_block.set("teleport_stone_pos", _carried_block_data["teleport_stone_pos"])
	
	# Show entity again
	_carrying_block.visible = true
	_carrying_block.set_process(true)
	_carrying_block.set_physics_process(true)
	
	# Convert entity back to voxel
	var terrain_tool = _terrain.get_voxel_tool()
	terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE
	
	var blocks_node = get_node_or_null("/root/Main/Game/Blocks")
	if blocks_node:
		var push_block_def = blocks_node.get_block_by_name("push_block")
		if push_block_def and push_block_def.base_info.voxels.size() > 0:
			var voxel_id = push_block_def.base_info.voxels[0]
			terrain_tool.set_voxel(voxel_pos, voxel_id)
			
			# Remove the entity
			_carrying_block.queue_free()
	
	# Clear carrying state
	_carrying_block = null
	_carried_block_data.clear()
	
	# Remove visual mesh
	_remove_carried_block_visual()
	
	print("🧤 Placed push_block at ", voxel_pos)


func _create_carried_block_visual():
	"""Create visual mesh for carried block (left side of screen)"""
	if not _head:
		return
	
	if _carried_block_mesh:
		_remove_carried_block_visual()
	
	# Create mesh instance
	_carried_block_mesh = MeshInstance3D.new()
	
	# Load terrain material
	var terrain_mat = load("res://blocky_game/blocks/terrain_material.tres")
	
	# Create textured cube (same as push_block uses)
	var mesh = _create_textured_cube(Vector2i(12, 15), 0.95)
	_carried_block_mesh.mesh = mesh
	_carried_block_mesh.material_override = terrain_mat
	
	# Position on left side of screen
	_carried_block_mesh.position = Vector3(-0.4, -0.3, -0.5)
	_carried_block_mesh.scale = Vector3(CARRIED_BLOCK_SCALE, CARRIED_BLOCK_SCALE, CARRIED_BLOCK_SCALE)
	
	# Add to head (camera)
	_head.add_child(_carried_block_mesh)
	
	print("🧤 Created visual mesh for carried block")


func _remove_carried_block_visual():
	"""Remove the visual mesh from hand"""
	if _carried_block_mesh and is_instance_valid(_carried_block_mesh):
		_carried_block_mesh.queue_free()
		_carried_block_mesh = null


func _create_textured_cube(tile_pos: Vector2i, size: float) -> ArrayMesh:
	"""Create a cube mesh with UVs for a specific tile in the 16x16 atlas"""
	var atlas_size = 16.0
	var uv_min = Vector2(tile_pos.x / atlas_size, tile_pos.y / atlas_size)
	var uv_max = Vector2((tile_pos.x + 1) / atlas_size, (tile_pos.y + 1) / atlas_size)
	
	var half = size / 2.0
	var vertices = PackedVector3Array()
	var uvs = PackedVector2Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	
	# Front face (+Z)
	vertices.append(Vector3(-half, -half, half))
	vertices.append(Vector3(half, -half, half))
	vertices.append(Vector3(half, half, half))
	vertices.append(Vector3(-half, half, half))
	for i in 4:
		normals.append(Vector3(0, 0, 1))
	uvs.append(Vector2(uv_min.x, uv_max.y))
	uvs.append(Vector2(uv_max.x, uv_max.y))
	uvs.append(Vector2(uv_max.x, uv_min.y))
	uvs.append(Vector2(uv_min.x, uv_min.y))
	indices.append_array([0, 2, 1, 0, 3, 2])
	
	# Back face (-Z)
	var v_offset = vertices.size()
	vertices.append(Vector3(half, -half, -half))
	vertices.append(Vector3(-half, -half, -half))
	vertices.append(Vector3(-half, half, -half))
	vertices.append(Vector3(half, half, -half))
	for i in 4:
		normals.append(Vector3(0, 0, -1))
	uvs.append(Vector2(uv_min.x, uv_max.y))
	uvs.append(Vector2(uv_max.x, uv_max.y))
	uvs.append(Vector2(uv_max.x, uv_min.y))
	uvs.append(Vector2(uv_min.x, uv_min.y))
	indices.append_array([v_offset, v_offset+2, v_offset+1, v_offset, v_offset+3, v_offset+2])
	
	# Right face (+X)
	v_offset = vertices.size()
	vertices.append(Vector3(half, -half, half))
	vertices.append(Vector3(half, -half, -half))
	vertices.append(Vector3(half, half, -half))
	vertices.append(Vector3(half, half, half))
	for i in 4:
		normals.append(Vector3(1, 0, 0))
	uvs.append(Vector2(uv_min.x, uv_max.y))
	uvs.append(Vector2(uv_max.x, uv_max.y))
	uvs.append(Vector2(uv_max.x, uv_min.y))
	uvs.append(Vector2(uv_min.x, uv_min.y))
	indices.append_array([v_offset, v_offset+2, v_offset+1, v_offset, v_offset+3, v_offset+2])
	
	# Left face (-X)
	v_offset = vertices.size()
	vertices.append(Vector3(-half, -half, -half))
	vertices.append(Vector3(-half, -half, half))
	vertices.append(Vector3(-half, half, half))
	vertices.append(Vector3(-half, half, -half))
	for i in 4:
		normals.append(Vector3(-1, 0, 0))
	uvs.append(Vector2(uv_min.x, uv_max.y))
	uvs.append(Vector2(uv_max.x, uv_max.y))
	uvs.append(Vector2(uv_max.x, uv_min.y))
	uvs.append(Vector2(uv_min.x, uv_min.y))
	indices.append_array([v_offset, v_offset+2, v_offset+1, v_offset, v_offset+3, v_offset+2])
	
	# Top face (+Y)
	v_offset = vertices.size()
	vertices.append(Vector3(-half, half, half))
	vertices.append(Vector3(half, half, half))
	vertices.append(Vector3(half, half, -half))
	vertices.append(Vector3(-half, half, -half))
	for i in 4:
		normals.append(Vector3(0, 1, 0))
	uvs.append(Vector2(uv_min.x, uv_max.y))
	uvs.append(Vector2(uv_max.x, uv_max.y))
	uvs.append(Vector2(uv_max.x, uv_min.y))
	uvs.append(Vector2(uv_min.x, uv_min.y))
	indices.append_array([v_offset, v_offset+2, v_offset+1, v_offset, v_offset+3, v_offset+2])
	
	# Bottom face (-Y)
	v_offset = vertices.size()
	vertices.append(Vector3(-half, -half, -half))
	vertices.append(Vector3(half, -half, -half))
	vertices.append(Vector3(half, -half, half))
	vertices.append(Vector3(-half, -half, half))
	for i in 4:
		normals.append(Vector3(0, -1, 0))
	uvs.append(Vector2(uv_min.x, uv_max.y))
	uvs.append(Vector2(uv_max.x, uv_max.y))
	uvs.append(Vector2(uv_max.x, uv_min.y))
	uvs.append(Vector2(uv_min.x, uv_min.y))
	indices.append_array([v_offset, v_offset+2, v_offset+1, v_offset, v_offset+3, v_offset+2])
	
	# Create ArrayMesh
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var array_mesh = ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh


func _find_target_push_block(origin: Vector3, direction: Vector3) -> Node:
	"""Find push_blocks in pickup range"""
	var push_blocks = get_tree().get_nodes_in_group("push_blocks")
	var closest_block = null
	var closest_distance = MAX_PICKUP_DISTANCE
	
	for block in push_blocks:
		if not is_instance_valid(block):
			continue
		
		# Skip if already carrying this block
		if block == _carrying_block:
			continue
		
		# Check if block is roughly in front of player
		var to_block = block.global_position - origin
		var distance = to_block.length()
		
		if distance > MAX_PICKUP_DISTANCE:
			continue
		
		# Check if block is in pickup cone (60 degree arc)
		var angle = direction.angle_to(to_block.normalized())
		if angle > deg_to_rad(30):  # 30 degrees each side = 60 degree cone
			continue
		
		if distance < closest_distance:
			closest_distance = distance
			closest_block = block
	
	return closest_block


func _find_push_block_voxel(origin: Vector3, direction: Vector3) -> Vector3:
	"""Check if we're looking at a push_block voxel"""
	var terrain_tool = _terrain.get_voxel_tool()
	terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE
	
	# Raycast in pickup direction
	var hit = terrain_tool.raycast(origin, direction, MAX_PICKUP_DISTANCE)
	if hit == null:
		return Vector3.ZERO
	
	var hit_pos = Vector3(hit.position)
	
	# Convert to voxel coordinates
	var voxel_coord = Vector3i(
		int(floor(hit_pos.x)),
		int(floor(hit_pos.y)),
		int(floor(hit_pos.z))
	)
	
	var voxel_id = terrain_tool.get_voxel(voxel_coord)
	if voxel_id == 0:
		return Vector3.ZERO
	
	# Check if it's a push_block
	var blocks_node = get_node_or_null("/root/Main/Game/Blocks")
	if not blocks_node:
		return Vector3.ZERO
	
	# Convert voxel ID to block ID using raw mapping
	var raw_mapping = blocks_node.get_raw_mapping(voxel_id)
	if not raw_mapping:
		return Vector3.ZERO
	
	var block = blocks_node.get_block(raw_mapping.block_id)
	if block and block.base_info.name == "push_block":
		return Vector3(voxel_coord)
	
	return Vector3.ZERO


func _find_spawned_block_at(voxel_pos: Vector3i) -> Node:
	"""Find a push_block entity at the specified voxel position"""
	var push_blocks = get_tree().get_nodes_in_group("push_blocks")
	for block in push_blocks:
		if not is_instance_valid(block):
			continue
		
		var entity_voxel_pos = Vector3i(
			int(floor(block.global_position.x)),
			int(floor(block.global_position.y)),
			int(floor(block.global_position.z))
		)
		
		if entity_voxel_pos == voxel_pos:
			return block
	
	return null


func _is_valid_placement(voxel_pos: Vector3i) -> bool:
	"""Check if the placement location is valid (air)"""
	var terrain_tool = _terrain.get_voxel_tool()
	terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE
	
	var voxel_id = terrain_tool.get_voxel(voxel_pos)
	return voxel_id == 0  # 0 = air


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D):
	_use(trans, 1)
