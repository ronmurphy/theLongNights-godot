extends Node3D

## Scatter Shot - One projectile from a 3-shot spread attack
## Used by Scatterers

const EntityBase = preload("../entities/entity_base.gd")

var speed := 22.0
var lifetime := 4.0
var damage := 6
var _shooter = null

var _velocity := Vector3()
var _terrain : VoxelTerrain = null


func _ready():
	_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")

	# Create scatter shot visual (small metal shard)
	var mesh_node = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.08, 0.08, 0.25)
	mesh_node.mesh = box_mesh

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.7, 0.8)  # Metal grey
	material.metallic = 0.8
	material.roughness = 0.3
	material.emission_enabled = true
	material.emission = Color(0.5, 0.5, 0.6)
	material.emission_energy_multiplier = 2.0
	mesh_node.material_override = material

	add_child(mesh_node)


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
		queue_free()
		return

	# Slight gravity
	_velocity.y -= 3.0 * delta

	var motion = _velocity * delta

	# Point in direction of movement
	if _velocity.length() > 0.1:
		look_at(global_position + _velocity, Vector3.UP)

	# Check entity collision
	var entities = get_tree().get_nodes_in_group("entities")
	for entity in entities:
		if not is_instance_valid(entity) or not entity.is_alive:
			continue

		if entity.team == EntityBase.Team.ENEMY or entity == _shooter:
			continue

		var distance = global_position.distance_to(entity.global_position)
		if distance < 0.6:
			if entity.has_method("take_damage"):
				entity.take_damage(damage, _shooter)
				print("🎯 Scatter shot hit %s!" % entity.get("entity_name"))
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
