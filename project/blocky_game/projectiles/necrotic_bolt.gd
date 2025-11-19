extends Node3D

## Necrotic Bolt - Death magic cast by Skeleton Mages
## Green/black necromantic energy

const EntityBase = preload("../entities/entity_base.gd")

var speed := 20.0
var lifetime := 5.0
var damage := 8
var _shooter = null

var _velocity := Vector3()
var _terrain : VoxelTerrain = null


func _ready():
	_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")

	# Necrotic energy core (sickly green)
	var core = MeshInstance3D.new()
	var core_mesh = SphereMesh.new()
	core_mesh.radius = 0.22
	core_mesh.height = 0.44
	core.mesh = core_mesh

	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.2, 0.6, 0.2)  # Sickly green
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.3, 1.0, 0.3)  # Bright green glow
	core_mat.emission_energy_multiplier = 6.0
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.albedo_color.a = 0.85
	core.material_override = core_mat
	add_child(core)

	# Dark outer shell
	var shell = MeshInstance3D.new()
	var shell_mesh = SphereMesh.new()
	shell_mesh.radius = 0.32
	shell_mesh.height = 0.64
	shell.mesh = shell_mesh

	var shell_mat = StandardMaterial3D.new()
	shell_mat.albedo_color = Color(0.1, 0.2, 0.1, 0.4)  # Dark green
	shell_mat.emission_enabled = true
	shell_mat.emission = Color(0.2, 0.5, 0.2)
	shell_mat.emission_energy_multiplier = 3.0
	shell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell.material_override = shell_mat
	add_child(shell)

	# Eerie green light
	var light = OmniLight3D.new()
	light.light_color = Color(0.3, 1.0, 0.3)  # Necro green
	light.light_energy = 3.5
	light.omni_range = 7.0
	light.shadow_enabled = false
	add_child(light)

	# Writhing animation
	var tween = core.create_tween()
	tween.set_loops()
	tween.tween_property(core, "scale", Vector3(1.2, 1.4, 1.2), 0.3)
	tween.tween_property(core, "scale", Vector3(0.8, 0.6, 0.8), 0.3)


func initialize(start_pos: Vector3, target_pos: Vector3, shooter = null):
	global_position = start_pos
	_shooter = shooter

	if shooter and "attack_damage" in shooter:
		damage = shooter.attack_damage

	var direction = (target_pos - start_pos).normalized()
	_velocity = direction * speed
	look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float):
	lifetime -= delta

	if lifetime <= 0:
		_fade()
		return

	var motion = _velocity * delta

	# Check terrain
	if _terrain:
		var vt = _terrain.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE
		var hit = vt.raycast(global_position, _velocity.normalized(), motion.length() + 0.5)
		if hit:
			_fade()
			return

	# Check entities
	var entities = get_tree().get_nodes_in_group("entities")
	for entity in entities:
		if not is_instance_valid(entity) or not entity.is_alive:
			continue

		if entity.team == EntityBase.Team.ENEMY or entity == _shooter:
			continue

		var distance = global_position.distance_to(entity.global_position)
		if distance < 1.0:
			if entity.has_method("take_damage"):
				entity.take_damage(damage, _shooter)
				print("💀 Necrotic bolt hits %s for %d damage!" % [entity.get("entity_name"), damage])
			_fade()
			return

	global_position += motion


func _fade():
	queue_free()
