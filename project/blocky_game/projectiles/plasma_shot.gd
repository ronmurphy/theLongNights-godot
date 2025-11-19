extends Node3D

## Plasma Shot - Advanced energy weapon from Alien Hunters
## Fast, bright, high-tech projectile

const EntityBase = preload("../entities/entity_base.gd")

var speed := 30.0  # Very fast
var lifetime := 6.0
var damage := 13
var _shooter = null
var _velocity := Vector3()
var _terrain : VoxelTerrain = null


func _ready():
	_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")

	# Plasma core (bright cyan/blue)
	var core = MeshInstance3D.new()
	var core_mesh = SphereMesh.new()
	core_mesh.radius = 0.18
	core_mesh.height = 0.36
	core.mesh = core_mesh

	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.3, 0.8, 1.0)  # Bright cyan
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.5, 1.0, 1.0)  # Electric blue
	core_mat.emission_energy_multiplier = 8.0
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.albedo_color.a = 0.9
	core.material_override = core_mat
	add_child(core)

	# Energy trail
	var trail = MeshInstance3D.new()
	var trail_mesh = BoxMesh.new()
	trail_mesh.size = Vector3(0.1, 0.1, 0.5)
	trail.mesh = trail_mesh

	var trail_mat = StandardMaterial3D.new()
	trail_mat.albedo_color = Color(0.2, 0.6, 0.9, 0.5)
	trail_mat.emission_enabled = true
	trail_mat.emission = Color(0.3, 0.7, 1.0)
	trail_mat.emission_energy_multiplier = 4.0
	trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail.material_override = trail_mat
	trail.position = Vector3(0, 0, -0.3)
	add_child(trail)

	# Bright light
	var light = OmniLight3D.new()
	light.light_color = Color(0.5, 0.9, 1.0)
	light.light_energy = 4.0
	light.omni_range = 5.0
	light.shadow_enabled = false
	add_child(light)


func initialize(start_pos: Vector3, target_pos: Vector3, shooter = null):
	global_position = start_pos
	_shooter = shooter
	if shooter and shooter.has("attack_damage"):
		damage = shooter.attack_damage
	var direction = (target_pos - start_pos).normalized()
	_velocity = direction * speed
	look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float):
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return

	var motion = _velocity * delta

	# Check entities
	var entities = get_tree().get_nodes_in_group("entities")
	for entity in entities:
		if not is_instance_valid(entity) or not entity.is_alive:
			continue
		if entity.team == EntityBase.Team.ENEMY or entity == _shooter:
			continue
		if global_position.distance_to(entity.global_position) < 0.8:
			if entity.has_method("take_damage"):
				entity.take_damage(damage, _shooter)
				print("⚡ Plasma shot hits %s!" % entity.get("entity_name"))
			queue_free()
			return

	# Check terrain
	if _terrain:
		var vt = _terrain.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE
		var hit = vt.raycast(global_position, _velocity.normalized(), motion.length() + 0.5)
		if hit:
			queue_free()
			return

	global_position += motion
