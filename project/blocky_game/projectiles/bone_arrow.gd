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

	# Check terrain collision
	if _terrain != null:
		var vt = _terrain.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE

		var hit = vt.raycast(global_position, _velocity.normalized(), motion.length() + 0.5)
		if hit != null:
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
