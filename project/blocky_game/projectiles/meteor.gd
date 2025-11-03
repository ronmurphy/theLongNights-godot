extends Node3D

# Meteor projectile that falls from the sky with fire trail

var target_position : Vector3
var speed := 40.0  # Fast falling speed
var explosion_radius := 3.0  # How big the explosion is
var lifetime := 10.0
var base_damage := 30
var stack_bonus := 0

var _velocity := Vector3()
var _terrain : VoxelTerrain = null
var _trail_timer := 0.0

@onready var _mesh : MeshInstance3D = $MeshInstance3D


func _ready():
	_terrain = get_node("/root/Main/Game/VoxelTerrain")

	# Create a spectacular fiery meteor visual
	var mesh_node = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.5
	sphere_mesh.height = 1.0
	mesh_node.mesh = sphere_mesh

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.4, 0.1)  # Fiery orange
	material.metallic = 0.3
	material.roughness = 0.4
	material.emission_enabled = true
	material.emission = Color(1.0, 0.6, 0.0)  # Bright fire glow
	material.emission_energy_multiplier = 8.0
	# Add rim for fire edge effect
	material.rim_enabled = true
	material.rim = 1.0
	material.rim_tint = 0.8
	mesh_node.material_override = material

	add_child(mesh_node)
	_mesh = mesh_node

	# Add outer flame aura
	var aura = MeshInstance3D.new()
	var aura_mesh = SphereMesh.new()
	aura_mesh.radius = 0.8
	aura_mesh.height = 1.6
	aura.mesh = aura_mesh
	var aura_mat = StandardMaterial3D.new()
	aura_mat.albedo_color = Color(1.0, 0.5, 0.0, 0.4)
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.emission_enabled = true
	aura_mat.emission = Color(1.0, 0.3, 0.0)
	aura_mat.emission_energy_multiplier = 6.0
	aura_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	aura.material_override = aura_mat
	mesh_node.add_child(aura)

	# Animate the aura pulsing
	var tween = aura.create_tween()
	tween.set_loops()
	tween.tween_property(aura, "scale", Vector3(1.2, 1.2, 1.2), 0.3)
	tween.tween_property(aura, "scale", Vector3(0.9, 0.9, 0.9), 0.3)


func initialize(sky_pos: Vector3, target_pos: Vector3, stack_count: int = 1):
	"""Initialize meteor high in the sky above target"""
	global_position = sky_pos
	target_position = target_pos
	stack_bonus = stack_count

	# Calculate velocity to fall toward target
	var direction = (target_pos - sky_pos).normalized()
	_velocity = direction * speed

	# Point meteor downward
	look_at(target_pos, Vector3.UP)


func _physics_process(delta: float):
	lifetime -= delta
	_trail_timer += delta

	if lifetime <= 0:
		queue_free()
		return

	# Add slight gravity for realistic fall
	_velocity.y -= 5.0 * delta

	# Accelerate slightly as it falls (terminal velocity)
	var current_speed = _velocity.length()
	if current_speed < speed * 1.5:
		_velocity = _velocity.normalized() * (current_speed + 10.0 * delta)

	# Move the meteor
	var motion = _velocity * delta

	# Create fire trail particles periodically (respecting graphics settings)
	var trail_interval = GraphicsSettings.get_meteor_trail_interval()
	if _trail_timer > trail_interval:
		_spawn_fire_particle()
		_trail_timer = 0.0

	# Point in direction of movement
	if _velocity.length() > 0.1:
		look_at(global_position + _velocity, Vector3.UP)

	# Check for collision with terrain
	if _terrain != null:
		var vt = _terrain.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE

		var hit = vt.raycast(global_position, _velocity.normalized(), motion.length() + 1.0)
		if hit != null:
			# Hit the ground!
			_on_impact(Vector3(hit.position))
			return

	global_position += motion


func _spawn_fire_particle():
	"""Spawn a small fire particle as trail effect"""
	var particle = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	particle.mesh = sphere

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.4, 0.1, 0.7)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.3, 0.0)
	material.emission_energy_multiplier = 3.0
	particle.material_override = material

	get_parent().add_child(particle)
	particle.global_position = global_position

	# Fade out and remove particle after a short time
	var tween = particle.create_tween()
	tween.tween_property(particle, "scale", Vector3.ZERO, 0.5)
	tween.tween_callback(particle.queue_free)


func _on_impact(hit_pos: Vector3):
	"""Create explosion when meteor hits"""
	print("METEOR IMPACT at ", hit_pos)

	if _terrain != null:
		var vt = _terrain.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE

		# Create spherical explosion
		var radius_int = int(explosion_radius)
		for x in range(-radius_int, radius_int + 1):
			for y in range(-radius_int, radius_int + 1):
				for z in range(-radius_int, radius_int + 1):
					var offset = Vector3(x, y, z)
					if offset.length() <= explosion_radius:
						var block_pos = hit_pos + offset
						# Destroy blocks in explosion radius
						vt.set_voxel(block_pos, 0)

		# Commit the changes
		# vt doesn't need explicit commit in newer Godot Voxel versions

	# Damage nearby entities with stack bonus
	var total_damage = base_damage + stack_bonus
	_damage_nearby_entities(hit_pos, explosion_radius, total_damage)

	# Create fire explosion effects
	_spawn_fire_explosion(hit_pos)

	queue_free()


func _damage_nearby_entities(center: Vector3, radius: float, damage: int):
	"""Damage all entities in explosion radius"""
	var entities = get_tree().get_nodes_in_group("entities")

	for entity in entities:
		if not entity.is_alive:
			continue

		# Check if entity is in explosion radius
		var distance = entity.global_position.distance_to(center)
		if distance > radius:
			continue

		# Don't hit friendly entities
		if entity.team == EntityBase.Team.PLAYER:
			continue

		# Scale damage with distance (full damage at center, reduced at edge)
		var scaled_damage = int(damage * (1.0 - (distance / radius)))
		entity.take_damage(scaled_damage, self)

		print("Meteor hit %s for %d damage (distance: %.1f)" % [entity.entity_name, scaled_damage, distance])


func _spawn_fire_explosion(pos: Vector3):
	"""Create fire explosion visual effect"""
	# Spawn fire particles that fly outward
	for i in range(20):
		var particle = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.3
		sphere.height = 0.6
		particle.mesh = sphere

		var material = StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.5, 0.1, 0.8)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.emission_enabled = true
		material.emission = Color(1.0, 0.4, 0.0)
		material.emission_energy_multiplier = 5.0
		particle.material_override = material

		get_parent().add_child(particle)
		particle.global_position = pos

		# Random direction for each fire ball
		var direction = Vector3(
			randf_range(-1, 1),
			randf_range(0, 1),
			randf_range(-1, 1)
		).normalized()

		# Animate fire ball flying outward and fading
		var tween = particle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", pos + direction * 4.0, 0.8)
		tween.tween_property(particle, "scale", Vector3.ZERO, 0.8)
		tween.chain().tween_callback(particle.queue_free)
