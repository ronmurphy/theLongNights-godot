extends Node3D

## Spear projectile with parabolic arc
## Sticks into ground, blocks, and entities on impact
## Deals damage to entities

var initial_velocity : Vector3
var lifetime := 15.0
var _velocity := Vector3()
var _terrain : VoxelTerrain = null
var _inv_item_or_count  # Store inv_item for damage and skyshard power
var _spear_owner  # Reference to spear weapon
var _throw_origin := Vector3.ZERO  # Starting position for orientation calculation
var _can_be_retrieved := false  # Flag set after hitting entity with Return power
var _retrieval_cooldown := 0.0  # Prevents instant re-retrieval

const GRAVITY = 9.8
const SPEAR_DAMAGE = 20


func _ready():
	_terrain = get_node("/root/Main/Game/VoxelTerrain")

	# Create spear shaft (wooden pole)
	var shaft = MeshInstance3D.new()
	var shaft_mesh = CylinderMesh.new()
	shaft_mesh.top_radius = 0.02
	shaft_mesh.bottom_radius = 0.02
	shaft_mesh.height = 1.5
	shaft.mesh = shaft_mesh

	var shaft_mat = StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(0.6, 0.4, 0.2)  # Brown wood
	shaft_mat.metallic = 0.1
	shaft_mat.roughness = 0.8
	shaft.material_override = shaft_mat
	add_child(shaft)

	# Create spear head (metal point)
	var head = MeshInstance3D.new()
	var head_mesh = CylinderMesh.new()
	head_mesh.top_radius = 0.04
	head_mesh.bottom_radius = 0.02
	head_mesh.height = 0.4
	head.mesh = head_mesh
	head.position = Vector3(0, 0.95, 0)  # At top of shaft

	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.8, 0.8, 0.9)  # Light metallic
	head_mat.metallic = 0.9
	head_mat.roughness = 0.2
	head.material_override = head_mat
	add_child(head)

	# Create base of spear (butt end)
	var base = MeshInstance3D.new()
	var base_mesh = CylinderMesh.new()
	base_mesh.top_radius = 0.03
	base_mesh.bottom_radius = 0.025
	base_mesh.height = 0.2
	base.mesh = base_mesh
	base.position = Vector3(0, -0.85, 0)  # At bottom of shaft

	var base_mat = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.3, 0.3, 0.3)  # Dark metal
	base_mat.metallic = 0.7
	base_mat.roughness = 0.4
	base.material_override = base_mat
	add_child(base)


func initialize(start_pos: Vector3, target_pos: Vector3, inv_item_or_count, spear_owner):
	"""Initialize spear projectile with target and owner"""
	global_position = start_pos
	_throw_origin = start_pos  # Store for orientation calculation
	_inv_item_or_count = inv_item_or_count
	_spear_owner = spear_owner

	# Calculate parabolic arc trajectory (less extreme than torch)
	var to_target = target_pos - start_pos
	var horizontal_dist = Vector2(to_target.x, to_target.z).length()
	var vertical_dist = to_target.y

	# Time to reach target (estimate)
	var throw_power = 25.0  # Moderate throw power
	var flight_time = horizontal_dist / throw_power if horizontal_dist > 0 else 0.1

	# Calculate initial velocities
	var horizontal_dir = Vector3(to_target.x, 0, to_target.z).normalized()
	var horizontal_vel = horizontal_dir * throw_power

	# Vertical velocity for parabolic arc (subtle arc, not extreme)
	var arc_height = 1.5  # Subtle arc height
	var vertical_vel = (vertical_dist + arc_height + 0.5 * GRAVITY * flight_time * flight_time) / flight_time

	initial_velocity = Vector3(horizontal_vel.x, vertical_vel, horizontal_vel.z)
	_velocity = initial_velocity

	# Orient spear along its velocity direction (parallel to flight path)
	var velocity_dir = _velocity.normalized()
	look_at(global_position + velocity_dir, Vector3.UP)


func _physics_process(delta: float):
	lifetime -= delta

	# Update retrieval cooldown
	if _retrieval_cooldown > 0:
		_retrieval_cooldown -= delta

	if lifetime <= 0:
		_stick_spear()
		return

	# Apply gravity
	_velocity.y -= GRAVITY * delta

	# Move spear
	var motion = _velocity * delta

	# Orient spear along its velocity direction (straight trajectory, no tumbling)
	var velocity_dir = _velocity.normalized()
	if velocity_dir.length() > 0.1:
		look_at(global_position + velocity_dir, Vector3.UP)

	# Check for push block collision first (entities)
	_check_push_block_collision()

	# Check for collision with terrain
	if _terrain != null:
		var vt = _terrain.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE

		var hit = vt.raycast(global_position, _velocity.normalized(), motion.length() + 0.5)
		if hit != null:
			# Check if we hit a push_block voxel
			if _is_push_block_voxel(Vector3(hit.position)):
				_on_hit_push_block_voxel(Vector3(hit.position))
				return

			# Hit normal terrain! Orient spear based on hit normal and throw direction
			global_position = Vector3(hit.position) + Vector3(0.5, 0.5, 0.5)
			_orient_spear_on_impact(hit.normal)
			_stick_spear()
			return

	# Check for collision with entities
	var hit_entity = _find_entity_hit()
	if hit_entity != null:
		# Hit an entity!
		_hit_entity(hit_entity)
		return

	global_position += motion


func _find_entity_hit() -> Node:
	"""Check if spear collides with any entities"""
	var space_state = get_tree().root.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = 0.15  # Small collision radius for spear tip
	query.transform = Transform3D(Basis(), global_position)

	var results = space_state.intersect_shape(query)
	if results.size() > 0:
		return results[0].collider

	return null


func _hit_entity(entity: Node):
	"""Spear hits an entity - deal damage and stick"""
	if not entity.has_method("take_damage"):
		_stick_spear()
		return

	# Calculate damage with stack bonus
	var stack_count = _inv_item_or_count.count if typeof(_inv_item_or_count) == TYPE_OBJECT else 1
	var total_damage = SPEAR_DAMAGE + stack_count

	# Deal damage
	entity.take_damage(total_damage, _spear_owner)

	print("Spear hit entity for %d damage! (base: %d + stack: %d)" % [total_damage, SPEAR_DAMAGE, stack_count])

	# ⚡ SKYSHARD POWERS
	if typeof(_inv_item_or_count) == TYPE_OBJECT and _inv_item_or_count.skyshard_power != "":
		var power_context = {
			"entity": entity,
			"position": entity.global_position,
			"stack_count": stack_count,
			"damage_dealt": total_damage,
			"attacker": get_tree().get_first_node_in_group("player")
		}
		Powers.execute_hotbar_power(_inv_item_or_count.skyshard_power, power_context)

		# If Return power was used, mark for retrieval
		if _inv_item_or_count.has_power("return"):
			mark_for_retrieval()

	# Stick to entity or ground
	_stick_spear()


func _orient_spear_on_impact(hit_normal: Vector3):
	"""Orient spear perpendicular to the surface it hit, pointing back toward thrower"""
	# The spear should stick out from the surface, pointing back toward the player
	# hit_normal points outward from the surface

	# Point the spear back toward where it was thrown from (opposite of throw direction)
	var back_to_thrower = (_throw_origin - global_position).normalized()

	# If back_to_thrower is roughly aligned with the surface normal, use that
	# Otherwise, orient perpendicular to the surface
	var desired_forward = back_to_thrower if back_to_thrower.dot(hit_normal) > 0.3 else hit_normal

	# Orient the spear along the desired direction
	look_at(global_position + desired_forward, Vector3.UP)


func _stick_spear():
	"""Spear has stuck into something - stop moving"""
	print("Spear stuck at ", global_position)

	# Stop moving
	_velocity = Vector3.ZERO
	set_physics_process(false)

	# Keep spear in scene for a while, then remove
	await get_tree().create_timer(30.0).timeout
	queue_free()


func mark_for_retrieval() -> void:
	"""Mark this spear as retrievable after entity hit with Return power"""
	_can_be_retrieved = true
	_retrieval_cooldown = 1.0  # 1 second cooldown before it can be retrieved
	print("Spear marked for retrieval!")


func is_retrievable() -> bool:
	"""Check if spear can currently be retrieved"""
	return _can_be_retrieved and _retrieval_cooldown <= 0.0


func get_item_id() -> int:
	"""Get the item ID of this spear for inventory recovery"""
	return 41  # Spear item ID


func get_skyshard_power() -> String:
	"""Get the skyshard power of this spear (for smart stacking on retrieval)"""
	if typeof(_inv_item_or_count) == TYPE_OBJECT and _inv_item_or_count.skyshard_power != null:
		return _inv_item_or_count.skyshard_power
	return ""


func get_skyshard_count() -> int:
	"""Get the skyshard count of this spear (for smart stacking on retrieval)"""
	if typeof(_inv_item_or_count) == TYPE_OBJECT and _inv_item_or_count.skyshard_count != null:
		return _inv_item_or_count.skyshard_count
	return 0


func _check_push_block_collision():
	"""Check if spear hit a push block and apply momentum"""
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
		# Fallback: stick spear
		_stick_spear()


func _on_hit_push_block(block: Node):
	"""Transfer momentum to push block - STRONGEST PUSH from heaviest weapon!"""
	# Calculate impulse based on spear's velocity and weight
	# Spears are heavy and fast = maximum force
	var impulse = _velocity.normalized() * 5.0  # STRONGEST push (heaviest projectile)

	if block.has_method("apply_impulse"):
		block.apply_impulse(impulse)
		print("🗡️ Spear SMASHED into push block with maximum force!")

	# Spear sticks/disappears after hitting the block
	_stick_spear()
