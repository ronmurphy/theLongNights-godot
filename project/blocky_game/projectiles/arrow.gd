extends Node3D

## Regular arrow projectile - straight shot with damage
## Used by crossbow

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


func initialize(start_pos: Vector3, target_pos: Vector3, initial_dir: Vector3, owner_node: Node = null, stack_count: int = 1):
	global_position = start_pos
	target_position = target_pos
	_initial_direction = initial_dir.normalized()
	_velocity = _initial_direction * speed
	_owner_node = owner_node
	stack_bonus = stack_count


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

	# Check for collision with terrain
	if _terrain != null:
		var vt = _terrain.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE

		var hit = vt.raycast(global_position, _velocity.normalized(), motion.length() + 0.5)
		if hit != null:
			# Hit terrain
			_on_hit_terrain(Vector3(hit.position))
			return

	global_position += motion


func _check_entity_collision():
	# Check if we hit any entities
	var entities = get_tree().get_nodes_in_group("entities")

	for entity in entities:
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


func _on_hit_entity(entity: Node):
	# Deal damage to entity
	var total_damage = base_damage + stack_bonus
	entity.take_damage(total_damage, _owner_node)
	print("Arrow hit %s for %d damage! (base: %d + stack: %d)" % [entity.entity_name, total_damage, base_damage, stack_bonus])

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
