extends Node3D

## Acid Spit - Corrosive projectile from Corrupted Citizens
## Green acid glob with damage over time potential

const EntityBase = preload("../entities/entity_base.gd")

var speed := 15.0
var lifetime := 4.0
var damage := 6
var _shooter = null
var _velocity := Vector3()
var _terrain : VoxelTerrain = null


func _ready():
	_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")

	# Acid glob (green slimy sphere)
	var mesh_node = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	mesh_node.mesh = sphere

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.8, 0.2, 0.8)  # Sickly green
	material.emission_enabled = true
	material.emission = Color(0.4, 1.0, 0.3)
	material.emission_energy_multiplier = 3.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_node.material_override = material
	add_child(mesh_node)

	# Bubbling animation
	var tween = mesh_node.create_tween()
	tween.set_loops()
	tween.tween_property(mesh_node, "scale:y", 1.2, 0.2)
	tween.tween_property(mesh_node, "scale:y", 0.8, 0.2)


func initialize(start_pos: Vector3, target_pos: Vector3, shooter = null):
	global_position = start_pos
	_shooter = shooter
	if shooter and "attack_damage" in shooter:
		damage = shooter.attack_damage
	var direction = (target_pos - start_pos).normalized()
	_velocity = direction * speed


func _physics_process(delta: float):
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return

	# Heavy arc (acid is heavy)
	_velocity.y -= 12.0 * delta

	var motion = _velocity * delta

	# Check entities
	var entities = get_tree().get_nodes_in_group("entities")
	for entity in entities:
		if not is_instance_valid(entity) or not entity.is_alive:
			continue
		if entity.team == EntityBase.Team.ENEMY or entity == _shooter:
			continue
		if global_position.distance_to(entity.global_position) < 0.7:
			if entity.has_method("take_damage"):
				entity.take_damage(damage, _shooter)
				print("🧪 Acid hits %s!" % entity.get("entity_name"))
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
