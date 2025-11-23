extends Node3D

# Thrown torch projectile with parabolic arc and lighting

var initial_velocity : Vector3
var lifetime := 10.0
var _velocity := Vector3()
var _terrain : VoxelTerrain = null
var _light : OmniLight3D = null
var _rotation_speed := 10.0  # Radians per second for spinning

const GRAVITY = 9.8


func _ready():
	_terrain = get_node("/root/Main/Game/VoxelTerrain")

	# Create gothic twisted torch handle (black/dark)
	var handle = MeshInstance3D.new()
	var handle_mesh = CylinderMesh.new()
	handle_mesh.top_radius = 0.025
	handle_mesh.bottom_radius = 0.035
	handle_mesh.height = 0.6
	handle.mesh = handle_mesh

	var handle_mat = StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.15, 0.15, 0.15)  # Dark gray/black
	handle_mat.metallic = 0.3
	handle_mat.roughness = 0.7
	handle.material_override = handle_mat
	add_child(handle)

	# Create metal band/cage at top
	var cage = MeshInstance3D.new()
	var cage_mesh = CylinderMesh.new()
	cage_mesh.top_radius = 0.08
	cage_mesh.bottom_radius = 0.06
	cage_mesh.height = 0.12
	cage.mesh = cage_mesh
	cage.position = Vector3(0, 0.35, 0)

	var cage_mat = StandardMaterial3D.new()
	cage_mat.albedo_color = Color(0.2, 0.2, 0.2)  # Dark metal
	cage_mat.metallic = 0.8
	cage_mat.roughness = 0.4
	cage.material_override = cage_mat
	handle.add_child(cage)

	# Create larger flame (orange/red gradient)
	var flame = MeshInstance3D.new()
	var flame_mesh = SphereMesh.new()
	flame_mesh.radial_segments = 8
	flame_mesh.rings = 6
	flame_mesh.radius = 0.12
	flame_mesh.height = 0.35
	flame.mesh = flame_mesh
	flame.position = Vector3(0, 0.4, 0)

	var flame_mat = StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.45, 0.0)  # Bright orange
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.35, 0.0)
	flame_mat.emission_energy_multiplier = 4.0
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.albedo_color.a = 0.9
	flame.material_override = flame_mat
	handle.add_child(flame)

	# Add flame tips (brighter, more yellow)
	var flame_tip = MeshInstance3D.new()
	var tip_mesh = SphereMesh.new()
	tip_mesh.radius = 0.08
	tip_mesh.height = 0.2
	flame_tip.mesh = tip_mesh
	flame_tip.position = Vector3(0, 0.55, 0)

	var tip_mat = StandardMaterial3D.new()
	tip_mat.albedo_color = Color(1.0, 0.8, 0.2)  # Yellow-orange
	tip_mat.emission_enabled = true
	tip_mat.emission = Color(1.0, 0.7, 0.1)
	tip_mat.emission_energy_multiplier = 5.0
	tip_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tip_mat.albedo_color.a = 0.85
	flame_tip.material_override = tip_mat
	handle.add_child(flame_tip)

	# Add dynamic light only if enabled by graphics settings
	if GraphicsSettings.should_create_torch_light():
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.5, 0.2)  # Orange torch light
		_light.light_energy = 2.5
		_light.omni_range = GraphicsSettings.get_torch_light_range()
		_light.omni_attenuation = 0.6
		_light.shadow_enabled = GraphicsSettings.should_enable_torch_shadows()  # Only on high quality
		add_child(_light)

	# Animate flame flickering (both flames)
	var tween = flame.create_tween()
	tween.set_loops()
	tween.tween_property(flame, "scale", Vector3(1.15, 1.25, 1.15), 0.12)
	tween.tween_property(flame, "scale", Vector3(0.85, 0.75, 0.85), 0.12)

	var tween_tip = flame_tip.create_tween()
	tween_tip.set_loops()
	tween_tip.tween_property(flame_tip, "scale", Vector3(1.2, 1.3, 1.2), 0.1)
	tween_tip.tween_property(flame_tip, "scale", Vector3(0.8, 0.7, 0.8), 0.1)


func initialize(start_pos: Vector3, target_pos: Vector3, throw_power: float = 15.0):
	global_position = start_pos

	# Calculate parabolic arc trajectory
	var to_target = target_pos - start_pos
	var horizontal_dist = Vector2(to_target.x, to_target.z).length()
	var vertical_dist = to_target.y

	# Time to reach target (estimate)
	var flight_time = horizontal_dist / throw_power

	# Calculate initial velocities
	var horizontal_dir = Vector3(to_target.x, 0, to_target.z).normalized()
	var horizontal_vel = horizontal_dir * throw_power

	# Vertical velocity for parabolic arc (adds extra height)
	var arc_height = 3.0  # Extra height for nice arc
	var vertical_vel = (vertical_dist + arc_height + 0.5 * GRAVITY * flight_time * flight_time) / flight_time

	initial_velocity = Vector3(horizontal_vel.x, vertical_vel, horizontal_vel.z)
	_velocity = initial_velocity


func _physics_process(delta: float):
	lifetime -= delta

	if lifetime <= 0:
		_land_torch()
		return

	# Apply gravity
	_velocity.y -= GRAVITY * delta

	# Move torch
	var motion = _velocity * delta

	# Rotate torch end-over-end
	rotate(Vector3.RIGHT, _rotation_speed * delta)

	# Check for push block collision
	_check_push_block_collision()

	# Check for collision
	if _terrain != null:
		var vt = _terrain.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE

		var hit = vt.raycast(global_position, _velocity.normalized(), motion.length() + 0.5)
		if hit != null:
			# Check if we hit a push_block voxel
			if _is_push_block_voxel(Vector3(hit.position)):
				_on_hit_push_block_voxel(Vector3(hit.position))
				return

			# Hit normal terrain!
			global_position = Vector3(hit.previous_position) + Vector3(0.5, 0.5, 0.5)
			_land_torch()
			return

	global_position += motion


func _land_torch():
	"""Torch has landed - become a static light source"""
	print("Torch landed at ", global_position)

	# Stop moving
	_velocity = Vector3.ZERO
	rotation = Vector3.ZERO  # Stand upright

	# Keep the light but remove physics
	set_physics_process(false)

	# Torch is now retrievable with Return power
	# Auto-cleanup after 5 minutes
	await get_tree().create_timer(300.0).timeout
	queue_free()


func is_retrievable() -> bool:
	"""Check if torch can be retrieved (after landing)"""
	return _velocity == Vector3.ZERO  # Can retrieve when stationary


func get_item_id() -> int:
	"""Get the item ID of this torch for inventory recovery"""
	return 6  # Torch item ID


func get_skyshard_power() -> String:
	"""Get the skyshard power of this torch (for smart stacking on retrieval)"""
	return ""  # Torches don't have skyshard powers


func get_skyshard_count() -> int:
	"""Get the skyshard count of this torch (for smart stacking on retrieval)"""
	return 0  # Torches don't have skyshard counts


func _check_push_block_collision():
	"""Check if torch hit a push block and apply momentum"""
	var push_blocks = get_tree().get_nodes_in_group("push_blocks")

	for block in push_blocks:
		if not is_instance_valid(block):
			continue

		# Check distance
		var distance = global_position.distance_to(block.global_position)
		if distance < 1.0:  # Hit radius
			_on_hit_push_block(block)
			return


func _is_push_block_voxel(voxel_pos: Vector3) -> bool:
	"""Check if the voxel at this position is a push_block"""
	if not _terrain:
		return false

	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	var voxel_id = vt.get_voxel(voxel_pos)
	if voxel_id == 0:
		return false

	# Get block type - need to convert voxel ID to block ID first
	var blocks_node = get_node_or_null("/root/Main/Game/Blocks")
	if not blocks_node:
		return false

	# Convert voxel ID to block ID using raw mapping
	var raw_mapping = blocks_node.get_raw_mapping(voxel_id)
	if not raw_mapping:
		return false

	var block = blocks_node.get_block(raw_mapping.block_id)
	if block:
		return block.base_info.name == "push_block"
	else:
		return false


func _on_hit_push_block_voxel(voxel_pos: Vector3):
	"""Hit a push_block voxel - find or create entity and push it"""
	# Find existing push block entity at this position
	var push_blocks = get_tree().get_nodes_in_group("push_blocks")
	var block_entity = null

	for block in push_blocks:
		if not is_instance_valid(block):
			continue

		# Check if entity is at this voxel position
		var entity_voxel_pos = Vector3i(
			int(floor(block.global_position.x)),
			int(floor(block.global_position.y)),
			int(floor(block.global_position.z))
		)

		if entity_voxel_pos == Vector3i(voxel_pos):
			block_entity = block
			break

	# If no entity exists, spawn one (will remove voxel and create entity)
	if not block_entity:
		var manager = get_node_or_null("/root/Main/Game/PushBlockManager")
		if manager and manager.has_method("create_push_block_at"):
			manager.create_push_block_at(Vector3i(voxel_pos))

			# Wait a frame for entity to spawn
			await get_tree().process_frame

			# Try to find it again
			push_blocks = get_tree().get_nodes_in_group("push_blocks")
			for block in push_blocks:
				if not is_instance_valid(block):
					continue

				var entity_voxel_pos = Vector3i(
					int(floor(block.global_position.x)),
					int(floor(block.global_position.y)),
					int(floor(block.global_position.z))
				)

				if entity_voxel_pos == Vector3i(voxel_pos):
					block_entity = block
					break

	# Push the block if we found/created it
	if block_entity:
		_on_hit_push_block(block_entity)
	else:
		# Fallback: land the torch
		_land_torch()


func _on_hit_push_block(block: Node):
	"""Transfer momentum to push block"""
	# Calculate impulse based on torch's velocity
	var impulse = _velocity.normalized() * 2.8  # Moderate push (burning wood + momentum)

	if block.has_method("apply_impulse"):
		block.apply_impulse(impulse)
		print("🔥 Torch bonked the push block!")

	# Torch lands after hitting the block
	_land_torch()
