extends Node3D

## Fireball - Fire projectile cast by Nightmare Golden
## Orange/yellow flames with heat distortion

const EntityBase = preload("../entities/entity_base.gd")

var speed := 18.0
var max_distance := 50.0
var damage := 7
var direction := Vector3.FORWARD
var owner_entity = null

var _distance_traveled := 0.0
var _terrain : VoxelTerrain = null


func _ready():
	_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")

	# Fire core (bright orange/yellow)
	var core = MeshInstance3D.new()
	var core_mesh = SphereMesh.new()
	core_mesh.radius = 0.3
	core_mesh.height = 0.6
	core.mesh = core_mesh

	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 0.6, 0.1)  # Orange fire
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.8, 0.0)  # Yellow glow
	core_mat.emission_energy_multiplier = 6.0
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.albedo_color.a = 0.9
	core.material_override = core_mat
	add_child(core)

	# Outer flame
	var flame = MeshInstance3D.new()
	var flame_mesh = SphereMesh.new()
	flame_mesh.radius = 0.4
	flame_mesh.height = 0.8
	flame.mesh = flame_mesh

	var flame_mat = StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.3, 0.0, 0.4)  # Red-orange flame
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.4, 0.0)
	flame_mat.emission_energy_multiplier = 3.0
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame.material_override = flame_mat
	add_child(flame)

	# Orange fire light
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.1)  # Orange glow
	light.light_energy = 4.0
	light.omni_range = 7.0
	light.shadow_enabled = false
	add_child(light)

	# Flickering flame animation
	var tween = core.create_tween()
	tween.set_loops()
	tween.tween_property(core, "scale", Vector3(1.2, 1.4, 1.2), 0.15)
	tween.tween_property(core, "scale", Vector3(0.9, 0.8, 0.9), 0.15)

	# Look in direction of travel
	if direction.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float):
	var motion = direction * speed * delta
	_distance_traveled += motion.length()

	# Check max distance
	if _distance_traveled >= max_distance:
		_explode()
		return

	# Check terrain collision
	if _terrain:
		var vt = _terrain.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE
		var hit = vt.raycast(global_position, direction, motion.length() + 0.5)
		if hit:
			_explode()
			return

	# Check entity collision
	var entities = get_tree().get_nodes_in_group("entities")
	for entity in entities:
		if not is_instance_valid(entity) or not entity.is_alive:
			continue

		# Don't hit other enemies or the shooter
		if entity.team == EntityBase.Team.ENEMY or entity == owner_entity:
			continue

		var distance = global_position.distance_to(entity.global_position)
		if distance < 1.2:
			if entity.has_method("take_damage"):
				var total_damage = damage

				# Apply blood moon damage modifier (from blood pendant, etc.)
				if is_instance_valid(owner_entity) and "blood_moon_damage_modifier" in owner_entity:
					total_damage = int(total_damage * (1.0 + owner_entity.blood_moon_damage_modifier))

				entity.take_damage(total_damage, owner_entity)

				var damage_info = "🔥 Fireball hits %s for %d damage!" % [entity.get("entity_name"), total_damage]
				if is_instance_valid(owner_entity) and "blood_moon_damage_modifier" in owner_entity and owner_entity.blood_moon_damage_modifier > 0.0:
					damage_info += " [🩸 +%d%%]" % int(owner_entity.blood_moon_damage_modifier * 100)
				print(damage_info)
			_explode()
			return

	global_position += motion


func _explode():
	# Spawn flame particles
	for i in range(6):
		var particle = MeshInstance3D.new()
		var particle_mesh = SphereMesh.new()
		particle_mesh.radius = 0.15
		particle.mesh = particle_mesh

		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, randf_range(0.3, 0.7), 0.0, 0.8)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.6, 0.0)
		mat.emission_energy_multiplier = 4.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		particle.material_override = mat

		get_parent().add_child(particle)
		particle.global_position = global_position

		var rand_dir = Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1)).normalized()

		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", global_position + rand_dir * 1.5, 0.4)
		tween.tween_property(particle, "scale", Vector3.ZERO, 0.4)
		tween.tween_callback(particle.queue_free)

	queue_free()
