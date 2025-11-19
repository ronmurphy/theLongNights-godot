extends Node3D

## Energy Beam - Advanced targeting laser from Hunting Constructs
## Fast, precise, high damage

const EntityBase = preload("../entities/entity_base.gd")

var speed := 35.0  # Extremely fast
var lifetime := 6.0
var damage := 15
var _shooter = null
var _velocity := Vector3()
var _terrain : VoxelTerrain = null


func _ready():
	_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")

	# Beam core (bright yellow-white)
	var core = MeshInstance3D.new()
	var core_mesh = BoxMesh.new()
	core_mesh.size = Vector3(0.12, 0.12, 0.8)
	core.mesh = core_mesh

	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 1.0, 0.8)  # Bright white-yellow
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 1.0, 1.0)  # Pure white
	core_mat.emission_energy_multiplier = 10.0
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.albedo_color.a = 0.95
	core.material_override = core_mat
	add_child(core)

	# Intense white light
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 1.0, 0.9)
	light.light_energy = 5.0
	light.omni_range = 4.0
	light.shadow_enabled = false
	add_child(light)


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
				print("🤖 Energy beam hits %s!" % entity.get("entity_name"))
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
