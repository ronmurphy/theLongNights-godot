extends Node3D

## Goblin Bomb - Explosive projectile thrown by Goblin Bomb Bards
## Arcing trajectory with AOE explosion

const EntityBase = preload("../entities/entity_base.gd")

var speed := 12.0
var lifetime := 5.0
var damage := 6  # Per-target damage
var explosion_radius := 3.0
var _shooter = null

var _velocity := Vector3()
var _terrain : VoxelTerrain = null


func _ready():
	_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")

	# Create bomb visual (round black sphere with fuse)
	var bomb_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	bomb_mesh.mesh = sphere

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.2, 0.2)  # Dark bomb
	material.metallic = 0.1
	material.roughness = 0.9
	bomb_mesh.material_override = material

	add_child(bomb_mesh)

	# Fuse spark (small red light)
	var fuse = OmniLight3D.new()
	fuse.light_color = Color(1.0, 0.3, 0.0)  # Orange spark
	fuse.light_energy = 2.0
	fuse.omni_range = 2.0
	fuse.shadow_enabled = false
	bomb_mesh.add_child(fuse)

	# Pulsing fuse animation
	var tween = fuse.create_tween()
	tween.set_loops()
	tween.tween_property(fuse, "light_energy", 4.0, 0.3)
	tween.tween_property(fuse, "light_energy", 1.0, 0.3)


func initialize(start_pos: Vector3, target_pos: Vector3, shooter = null):
	global_position = start_pos
	_shooter = shooter

	if shooter and shooter.has("attack_damage"):
		damage = shooter.attack_damage

	# Calculate arcing trajectory
	var direction = (target_pos - start_pos).normalized()
	var horizontal_dist = Vector2(target_pos.x - start_pos.x, target_pos.z - start_pos.z).length()

	# Add upward arc based on distance
	var arc_height = min(horizontal_dist * 0.3, 8.0)
	direction.y += arc_height / horizontal_dist if horizontal_dist > 0 else 0.5

	_velocity = direction.normalized() * speed


func _physics_process(delta: float):
	lifetime -= delta

	if lifetime <= 0:
		_explode()
		return

	# Gravity
	_velocity.y -= 15.0 * delta

	var motion = _velocity * delta

	# Check terrain collision
	if _terrain != null:
		var vt = _terrain.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE

		var hit = vt.raycast(global_position, _velocity.normalized(), motion.length() + 0.5)
		if hit != null:
			_explode()
			return

	# Check if hit ground
	if global_position.y < -5.0:
		_explode()
		return

	global_position += motion


func _explode():
	print("💣 Goblin bomb explodes at %s!" % global_position)

	# Damage all nearby entities
	var entities = get_tree().get_nodes_in_group("entities")

	for entity in entities:
		if not is_instance_valid(entity) or not entity.is_alive:
			continue

		# Don't hit other enemies
		if entity.team == EntityBase.Team.ENEMY:
			continue

		var distance = global_position.distance_to(entity.global_position)
		if distance < explosion_radius:
			if entity.has_method("take_damage"):
				entity.take_damage(damage, _shooter)
				print("  💥 Explosion hit %s for %d damage!" % [entity.get("entity_name"), damage])

	# TODO: Spawn explosion particle effect

	queue_free()
