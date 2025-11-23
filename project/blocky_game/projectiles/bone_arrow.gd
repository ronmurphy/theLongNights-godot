extends Node3D

## Bone Arrow - Skeletal projectile shot by Skeleton Archers
## Similar to regular arrows but with bone appearance

const EntityBase = preload("../entities/entity_base.gd")

var target_position : Vector3
var speed := 25.0  # Fast arrow
var lifetime := 8.0
var damage := 6  # Will use entity's attack_damage
var _shooter = null

var _time := 0.0
var _velocity := Vector3()
var _terrain : VoxelTerrain = null


func _ready():
	_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")

	# Create bone arrow visual
	var mesh_node = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.08, 0.08, 0.6)  # Slightly thinner than wood arrow
	mesh_node.mesh = box_mesh

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.9, 0.85)  # Bone white
	material.metallic = 0.0
	material.roughness = 0.6
	mesh_node.material_override = material

	add_child(mesh_node)


func initialize(start_pos: Vector3, target_pos: Vector3, shooter = null):
	global_position = start_pos
	target_position = target_pos
	_shooter = shooter

	# Use shooter's damage if available
	if shooter and "attack_damage" in shooter:
		damage = shooter.attack_damage

	var direction = (target_pos - start_pos).normalized()
	_velocity = direction * speed

	# Face the direction of travel
	look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float):
	_time += delta
	lifetime -= delta

	if lifetime <= 0:
		queue_free()
		return

	# Gravity (bones are light)
	_velocity.y -= 8.0 * delta

	var motion = _velocity * delta

	# Point arrow in direction of movement
	if _velocity.length() > 0.1:
		look_at(global_position + _velocity, Vector3.UP)

	# Check for collision with entities
	_check_entity_collision()

	# Check for push block collision
	_check_push_block_collision()

	# Check terrain collision
	if _terrain != null:
		var vt = _terrain.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE

		var hit = vt.raycast(global_position, _velocity.normalized(), motion.length() + 0.5)
		if hit != null:
			# Check if we hit a push_block voxel
			if _is_push_block_voxel(Vector3(hit.position)):
				_on_hit_push_block_voxel(Vector3(hit.position))
				return

			queue_free()
			return

	global_position += motion


func _check_entity_collision():
	var entities = get_tree().get_nodes_in_group("entities")

	for entity in entities:
		if not is_instance_valid(entity) or not entity.is_alive:
			continue

		# Don't hit other enemies
		if entity.team == EntityBase.Team.ENEMY:
			continue

		# Don't hit self
		if entity == _shooter:
			continue

		var distance = global_position.distance_to(entity.global_position)
		if distance < 0.8:
			_on_hit_entity(entity)
			return


func _on_hit_entity(entity: Node):
	if entity.has_method("take_damage"):
		entity.take_damage(damage, _shooter)
		print("💀 Bone arrow hit %s for %d damage!" % [entity.get("entity_name"), damage])

	queue_free()


func _check_push_block_collision():
	"""Check if bone arrow hit a push block and apply momentum"""
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
		# Fallback
		queue_free()


func _on_hit_push_block(block: Node):
	"""Transfer momentum to push block with NECROMANTIC EFFECT - haunted drift!"""
	# Initial impulse from arrow hit
	var impulse = _velocity.normalized() * 3.0

	if block.has_method("apply_impulse"):
		block.apply_impulse(impulse)
		print("💀 Bone arrow cursed the push block!")

	# NECROMANTIC EFFECT: Block continues drifting on its own!
	# Apply small continuous force in the same direction for 2.5 seconds
	if is_instance_valid(block):
		var drift_direction = _velocity.normalized()
		var drift_time = 0.0
		var max_drift_time = 2.5

		# Store original color
		var original_color = Color.WHITE
		if block.has("_mesh") and block._mesh and block._mesh.material_override:
			original_color = block._mesh.material_override.albedo_color

		while drift_time < max_drift_time and is_instance_valid(block):
			await get_tree().create_timer(0.1).timeout
			drift_time += 0.1

			if is_instance_valid(block) and block.has_method("apply_impulse"):
				# Gentle haunted drift
				var drift_impulse = drift_direction * 0.3
				block.apply_impulse(drift_impulse)

				# Purple necromantic glow
				if block.has("_mesh") and block._mesh and block._mesh.material_override:
					var glow_intensity = 1.0 - (drift_time / max_drift_time)
					block._mesh.material_override.albedo_color = Color(0.6, 0.3, 0.8) * glow_intensity + original_color * (1.0 - glow_intensity)

		# Restore original color
		if is_instance_valid(block) and block.has("_mesh") and block._mesh and block._mesh.material_override:
			block._mesh.material_override.albedo_color = original_color
			print("💀 Necromantic curse faded...")

	# Arrow is destroyed on impact
	queue_free()
