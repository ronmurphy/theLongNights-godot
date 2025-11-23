extends Node3D

## PushBlock - Movable puzzle block that can be pushed by projectiles
## Uses VoxelBoxMover physics for terrain collision
## Slides in the direction of impact with friction

@export var friction := 0.92  # How quickly the block slows down (0.0 = instant stop, 1.0 = no friction)
@export var mass := 1.0  # Mass affects how much momentum is transferred from projectiles
@export var min_velocity := 0.05  # Stop moving when velocity drops below this

var _velocity := Vector3.ZERO
var _box_mover := VoxelBoxMover.new()
var _terrain: VoxelTerrain = null
var _collision_size := Vector3(1.0, 1.0, 1.0)  # 1x1x1 block size
var _collision_offset := Vector3(-0.5, -0.5, -0.5)  # Centered

# Visual
var _mesh: MeshInstance3D = null
var _goal_reached := false

# Goal detection
const GOAL_BLOCK_NAME = "test"  # Goal block for puzzles


func _ready():
	# Setup collision
	_box_mover.set_collision_mask(1)
	_box_mover.set_step_climbing_enabled(false)  # Can't climb stairs

	# Find terrain
	_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")
	if _terrain == null:
		push_warning("PushBlock: Could not find VoxelTerrain")

	# Create visual mesh (simple cube for now)
	_create_visual_mesh()

	# Add to group for projectile detection
	add_to_group("push_blocks")

	print("🎯 PushBlock created at %s" % global_position)


func _create_visual_mesh():
	"""Create a visual cube mesh for the push block with proper texture"""
	_mesh = MeshInstance3D.new()

	# Load the terrain atlas material (same as voxels use)
	var terrain_mat = load("res://blocky_game/blocks/terrain_material.tres")

	# Create a cube with correct UVs for push_block tile (12, 15) in 16x16 atlas
	var mesh = _create_textured_cube(Vector2i(12, 15), 0.95)
	_mesh.mesh = mesh
	_mesh.material_override = terrain_mat

	add_child(_mesh)


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

	# Front face (+Z) - facing toward +Z
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
	# Counter-clockwise winding when viewed from outside
	indices.append_array([0, 2, 1, 0, 3, 2])

	# Back face (-Z) - facing toward -Z
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

	# Right face (+X) - facing toward +X
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

	# Left face (-X) - facing toward -X
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

	# Top face (+Y) - facing toward +Y
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

	# Bottom face (-Y) - facing toward -Y
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


func _physics_process(delta: float):
	if _terrain == null:
		print("❌ PushBlock: No terrain reference!")
		return
	if _goal_reached:
		return

	# Apply friction
	_velocity *= friction

	# Stop if velocity is very small
	if _velocity.length() < min_velocity:
		_velocity = Vector3.ZERO
		return

	# Calculate motion for this frame
	var motion := _velocity * delta
	var aabb := AABB(_collision_offset, _collision_size)

	# Check if area is loaded
	var vt := _terrain.get_voxel_tool()
	if vt.is_area_editable(AABB(aabb.position + global_position, aabb.size)):
		# Get motion with collision detection
		motion = _box_mover.get_motion(global_position, motion, aabb, _terrain)

		# Apply motion
		global_position += motion

		# Check if we've reached a goal block
		_check_goal_reached()

		# If motion was blocked (didn't move as expected), reduce velocity
		if motion.length_squared() < (_velocity * delta).length_squared() * 0.5:
			_velocity *= 0.5  # Hit something, slow down significantly


func apply_impulse(impulse: Vector3):
	"""Apply an impulse force to the block (called by projectiles)
	Impulse is affected by mass - heavier blocks move less"""
	var force = impulse / mass
	_velocity += force

	print("🎯 PushBlock received impulse: %s (velocity now: %s)" % [impulse, _velocity])


func _check_goal_reached():
	"""Check if the block is touching a goal block (test block)"""
	if _goal_reached:
		return

	# Check the block position below us
	var block_pos = Vector3i(
		int(floor(global_position.x)),
		int(floor(global_position.y - 1.0)),  # Check block below
		int(floor(global_position.z))
	)

	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE
	var voxel_id = vt.get_voxel(block_pos)

	if voxel_id != 0:
		# Get block type - convert voxel ID to block ID first!
		var blocks_node = get_node_or_null("/root/Main/Game/Blocks")
		if blocks_node:
			# Convert voxel ID to block ID using raw mapping
			var raw_mapping = blocks_node.get_raw_mapping(voxel_id)
			if raw_mapping:
				var block = blocks_node.get_block(raw_mapping.block_id)
				if block and block.base_info.name == GOAL_BLOCK_NAME:
					_on_goal_reached()


func _on_goal_reached():
	"""Called when the block reaches a goal"""
	_goal_reached = true
	_velocity = Vector3.ZERO

	print("🎉 PushBlock reached goal!")

	# Visual feedback - turn green
	if _mesh and _mesh.material_override:
		_mesh.material_override.albedo_color = Color(0.2, 1.0, 0.2)  # Green

	# TODO: Emit signal for puzzle manager
	# emit_signal("goal_reached")
