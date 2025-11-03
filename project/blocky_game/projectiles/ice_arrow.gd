extends Node3D

# Ice arrow projectile with zigzag homing behavior

var target_position : Vector3
var speed := 25.0
var lifetime := 10.0
var zigzag_frequency := 8.0  # How fast it zigzags
var zigzag_amplitude := 0.5  # How wide the zigzag is
var homing_strength := 3.0  # How strongly it homes toward target
var base_damage := 20  # Base ice arrow damage
var stack_bonus := 0  # Bonus damage from stacked weapons

var _time := 0.0
var _velocity := Vector3()
var _initial_direction := Vector3()
var _terrain : VoxelTerrain = null
var _trail_timer := 0.0

var _mesh : MeshInstance3D = null

func _ready():
	_terrain = get_node("/root/Main/Game/VoxelTerrain")

	# Create a fancy ice arrow visual with glow
	var mesh_node = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.15, 0.15, 0.6)  # Arrow shape
	mesh_node.mesh = box_mesh

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.4, 0.85, 1.0)  # Ice blue
	material.metallic = 0.6
	material.roughness = 0.2
	material.emission_enabled = true
	material.emission = Color(0.6, 0.95, 1.0)  # Bright ice glow
	material.emission_energy_multiplier = 4.0
	# Add rim lighting for magical effect
	material.rim_enabled = true
	material.rim = 0.8
	material.rim_tint = 0.5
	mesh_node.material_override = material

	add_child(mesh_node)
	_mesh = mesh_node

	# Add a glowing outer aura
	var aura = MeshInstance3D.new()
	var aura_mesh = BoxMesh.new()
	aura_mesh.size = Vector3(0.25, 0.25, 0.7)
	aura.mesh = aura_mesh
	var aura_mat = StandardMaterial3D.new()
	aura_mat.albedo_color = Color(0.5, 0.9, 1.0, 0.3)
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.emission_enabled = true
	aura_mat.emission = Color(0.7, 1.0, 1.0)
	aura_mat.emission_energy_multiplier = 3.0
	aura_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	aura.material_override = aura_mat
	mesh_node.add_child(aura)


func initialize(start_pos: Vector3, target_pos: Vector3, initial_dir: Vector3, stack_count: int = 1):
	global_position = start_pos
	target_position = target_pos
	_initial_direction = initial_dir.normalized()
	_velocity = _initial_direction * speed
	stack_bonus = stack_count  # Store stack bonus for damage calculation


func _physics_process(delta: float):
	_time += delta
	lifetime -= delta
	_trail_timer += delta

	if lifetime <= 0:
		queue_free()
		return

	# Spawn ice trail particles
	if _trail_timer > 0.03:  # Every 30ms
		_spawn_ice_trail_particle()
		_trail_timer = 0.0

	# Calculate direction to target (homing)
	var to_target = (target_position - global_position).normalized()

	# Blend between initial direction and homing direction over time
	var homing_factor = min(_time * 0.5, 1.0)  # Gradually increase homing
	var desired_direction = _initial_direction.lerp(to_target, homing_factor).normalized()

	# Add zigzag offset perpendicular to movement direction
	var zigzag_offset_amount = sin(_time * zigzag_frequency) * zigzag_amplitude

	# Get perpendicular vector for zigzag (cross product with up vector)
	var right = desired_direction.cross(Vector3.UP).normalized()
	if right.length() < 0.1:  # Handle edge case where direction is straight up/down
		right = desired_direction.cross(Vector3.RIGHT).normalized()

	var zigzag_offset = right * zigzag_offset_amount

	# Smoothly adjust velocity toward desired direction with zigzag
	var target_velocity = (desired_direction + zigzag_offset).normalized() * speed
	_velocity = _velocity.lerp(target_velocity, homing_strength * delta)

	# Move the projectile
	var motion = _velocity * delta

	# Point the arrow in the direction of movement
	if _velocity.length() > 0.1:
		look_at(global_position + _velocity, Vector3.UP)

	# Check for entity collision first
	_check_entity_collision()

	# Check for collision with terrain
	if _terrain != null:
		var vt = _terrain.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE

		var hit = vt.raycast(global_position, _velocity.normalized(), motion.length() + 0.5)
		if hit != null:
			# Hit something!
			_on_hit(Vector3(hit.position))
			return

	global_position += motion


func _check_entity_collision():
	"""Check if arrow hit any entities"""
	var entities = get_tree().get_nodes_in_group("entities")

	for entity in entities:
		if not entity.is_alive:
			continue

		# Don't hit friendly entities
		if entity.team == EntityBase.Team.PLAYER:
			continue

		# Check distance
		var distance = global_position.distance_to(entity.global_position)
		if distance < 0.8:  # Hit radius
			_on_hit_entity(entity)
			return


func _on_hit_entity(entity: Node):
	"""Hit an entity with ice damage"""
	var total_damage = base_damage + stack_bonus
	entity.take_damage(total_damage, self)
	print("Ice arrow hit %s for %d damage! (base: %d + stack: %d)" % [entity.entity_name, total_damage, base_damage, stack_bonus])

	# Create ice explosion at entity position
	_spawn_ice_explosion(entity.global_position)
	_damage_nearby_entities(entity.global_position, 2.0, 10)  # Small AOE freeze damage

	queue_free()


func _on_hit(hit_pos: Vector3):
	# Create ice explosion effect
	print("ICE EXPLOSION at ", hit_pos)

	# Spawn ice explosion particles
	_spawn_ice_explosion(hit_pos)

	# Damage nearby entities with ice
	_damage_nearby_entities(hit_pos, 2.0, 15)

	# Freeze/destroy blocks in a small radius
	if _terrain != null:
		var vt = _terrain.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE

		# Small explosion radius
		var explosion_radius = 2.0
		var radius_int = int(explosion_radius)
		for x in range(-radius_int, radius_int + 1):
			for y in range(-radius_int, radius_int + 1):
				for z in range(-radius_int, radius_int + 1):
					var offset = Vector3(x, y, z)
					if offset.length() <= explosion_radius:
						var block_pos = hit_pos + offset
						# Destroy blocks in small explosion
						vt.set_voxel(block_pos, 0)

	queue_free()


func _damage_nearby_entities(center: Vector3, radius: float, damage: int):
	"""Damage entities caught in ice explosion"""
	var entities = get_tree().get_nodes_in_group("entities")

	for entity in entities:
		if not entity.is_alive:
			continue

		# Don't hit friendly entities
		if entity.team == EntityBase.Team.PLAYER:
			continue

		var distance = entity.global_position.distance_to(center)
		if distance <= radius:
			var scaled_damage = int(damage * (1.0 - (distance / radius)))
			entity.take_damage(scaled_damage, self)
			print("Ice explosion hit %s for %d damage" % [entity.entity_name, scaled_damage])


func _spawn_ice_trail_particle():
	"""Spawn ice crystals as trail"""
	var particle = MeshInstance3D.new()
	var crystal = BoxMesh.new()
	crystal.size = Vector3(0.08, 0.12, 0.08)
	particle.mesh = crystal

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.95, 1.0, 0.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.8, 1.0, 1.0)
	material.emission_energy_multiplier = 2.0
	particle.material_override = material

	get_parent().add_child(particle)
	particle.global_position = global_position
	particle.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)

	# Fade out particle
	var tween = particle.create_tween()
	tween.set_parallel(true)
	tween.tween_property(particle, "scale", Vector3.ZERO, 0.4)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.4)
	tween.chain().tween_callback(particle.queue_free)


func _spawn_ice_explosion(pos: Vector3):
	"""Create visual ice explosion effect"""
	# Spawn multiple ice shards that fly outward
	for i in range(12):
		var shard = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.2, 0.4, 0.1)
		shard.mesh = box

		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.6, 0.9, 1.0, 0.8)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.emission_enabled = true
		material.emission = Color(0.7, 0.95, 1.0)
		material.emission_energy_multiplier = 3.0
		shard.material_override = material

		get_parent().add_child(shard)
		shard.global_position = pos

		# Random direction for each shard
		var direction = Vector3(
			randf_range(-1, 1),
			randf_range(0, 1),
			randf_range(-1, 1)
		).normalized()

		# Animate shard flying outward and fading
		var tween = shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", pos + direction * 3.0, 0.6)
		tween.tween_property(shard, "scale", Vector3.ZERO, 0.6)
		tween.chain().tween_callback(shard.queue_free)
