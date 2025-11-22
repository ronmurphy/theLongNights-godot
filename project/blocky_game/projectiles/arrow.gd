extends Node3D

## Regular arrow projectile - straight shot with damage
## Used by crossbow

const EntityBase = preload("../entities/entity_base.gd")
const Meteor = preload("meteor.gd")

var target_position : Vector3
var speed := 30.0
var lifetime := 8.0
var base_damage := 15
var stack_bonus := 0

var _time := 0.0
var _velocity := Vector3()
var _initial_direction := Vector3()
var _terrain : VoxelTerrain = null
var _owner_node : Node = null  # Who shot this arrow
var _inv_item = null  # Inventory item with skyshard power

var _mesh : MeshInstance3D = null


func _ready():
	_terrain = get_node("/root/Main/Game/VoxelTerrain")

	# Create arrow visual
	var mesh_node = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.1, 0.1, 0.5)  # Arrow shape
	mesh_node.mesh = box_mesh

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.6, 0.4, 0.2)  # Wood color
	material.metallic = 0.0
	material.roughness = 0.8
	mesh_node.material_override = material

	add_child(mesh_node)
	_mesh = mesh_node


func initialize(start_pos: Vector3, target_pos: Vector3, initial_dir: Vector3, owner_node: Node = null, stack_count: int = 1, inv_item = null):
	global_position = start_pos
	target_position = target_pos
	_initial_direction = initial_dir.normalized()
	_velocity = _initial_direction * speed
	_owner_node = owner_node
	stack_bonus = stack_count
	_inv_item = inv_item


func _physics_process(delta: float):
	_time += delta
	lifetime -= delta

	if lifetime <= 0:
		queue_free()
		return

	# Simple gravity
	_velocity.y -= 9.8 * delta

	# Move the projectile
	var motion = _velocity * delta

	# Point the arrow in the direction of movement
	if _velocity.length() > 0.1:
		look_at(global_position + _velocity, Vector3.UP)

	# Check for collision with entities
	_check_entity_collision()

	# Check for collision with push blocks
	_check_push_block_collision()

	# Check for collision with terrain
	if _terrain != null:
		var vt = _terrain.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE

		var hit = vt.raycast(global_position, _velocity.normalized(), motion.length() + 0.5)
		if hit != null:
			# Check if we hit a push_block voxel (first hit on a placed block)
			if _is_push_block_voxel(Vector3(hit.position)):
				_on_hit_push_block_voxel(Vector3(hit.position))
				return

			# Hit normal terrain
			_on_hit_terrain(Vector3(hit.position))
			return

	global_position += motion


func _check_entity_collision():
	# Check if we hit any entities
	var entities = get_tree().get_nodes_in_group("entities")

	for entity in entities:
		# Safety check: make sure entity is still valid
		if not is_instance_valid(entity):
			continue
			
		if not entity.is_alive:
			continue

		# Don't hit friendly entities if shot by player/companion
		if _owner_node and entity.team == EntityBase.Team.PLAYER:
			continue

		# Check distance
		var distance = global_position.distance_to(entity.global_position)
		if distance < 0.8:  # Hit radius
			_on_hit_entity(entity)
			return


func _check_push_block_collision():
	"""Check if arrow hit a push block and apply momentum"""
	var push_blocks = get_tree().get_nodes_in_group("push_blocks")

	for block in push_blocks:
		if not is_instance_valid(block):
			continue

		# Check distance
		var distance = global_position.distance_to(block.global_position)
		if distance < 1.0:  # Hit radius slightly larger than entity radius
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
		# Fallback: couldn't spawn entity for some reason
		_on_hit_terrain(voxel_pos)


func _on_hit_push_block(block: Node):
	"""Transfer momentum to push block"""
	# Calculate impulse based on arrow velocity and mass
	var impulse = _velocity.normalized() * 3.0  # Arrows push with moderate force

	if block.has_method("apply_impulse"):
		block.apply_impulse(impulse)
		print("🎯 Arrow pushed block!")

	# Spawn hit particles
	_spawn_hit_particles(global_position)

	# Arrow is destroyed on impact
	queue_free()


func _on_hit_entity(entity: Node):
	# Deal damage to entity
	var total_damage = base_damage + stack_bonus
	entity.take_damage(total_damage, _owner_node)
	print("Arrow hit %s for %d damage! (base: %d + stack: %d)" % [entity.entity_name, total_damage, base_damage, stack_bonus])

	# ⚡ SKYSHARD POWERS - Use centralized Powers system
	if typeof(_inv_item) == TYPE_OBJECT and _inv_item != null and _inv_item.skyshard_power != "":
		var power_context = {
			"entity": entity,
			"position": entity.global_position,
			"stack_count": stack_bonus,
			"damage_dealt": total_damage,
			"attacker": _owner_node
		}
		Powers.execute_hotbar_power(_inv_item.skyshard_power, power_context)

	# Spawn hit particles
	_spawn_hit_particles(global_position)

	queue_free()


func _on_hit_terrain(hit_pos: Vector3):
	# Just stick in the ground
	print("Arrow stuck at ", hit_pos)

	# Spawn dust particles
	_spawn_hit_particles(hit_pos)

	queue_free()


func _spawn_hit_particles(pos: Vector3):
	# Create simple impact effect
	var particles = GPUParticles3D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 8
	particles.lifetime = 0.3
	particles.explosiveness = 1.0

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.3
	material.direction = Vector3(0, 1, 0)
	material.spread = 45.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 3.0
	material.gravity = Vector3(0, -9.8, 0)
	material.scale_min = 0.05
	material.scale_max = 0.15
	material.color = Color(0.5, 0.4, 0.3)  # Dirt/dust color

	particles.process_material = material

	# Add to scene
	get_parent().add_child(particles)

	# Auto-delete after lifetime
	await get_tree().create_timer(0.5).timeout
	particles.queue_free()
