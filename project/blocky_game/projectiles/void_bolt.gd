extends Node3D

# Void Bolt - Purple energy projectile shot by Abyss Golems
# First ranged enemy attack in the game!

var initial_velocity : Vector3
var lifetime := 5.0
var damage := 15  # High damage ranged attack
var _velocity := Vector3()
var _terrain : VoxelTerrain = null
var _shooter = null  # The entity that shot this bolt (to avoid self-damage)

const SPEED = 20.0  # Fast projectile


func _ready():
	_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")

	# Create void energy core (purple sphere)
	var core = MeshInstance3D.new()
	var core_mesh = SphereMesh.new()
	core_mesh.radial_segments = 12
	core_mesh.rings = 12
	core_mesh.radius = 0.2
	core_mesh.height = 0.4
	core.mesh = core_mesh

	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.8, 0.3, 1.0)  # Bright purple
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.4, 1.0)  # Magenta glow
	core_mat.emission_energy_multiplier = 6.0
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.albedo_color.a = 0.85
	core.material_override = core_mat
	add_child(core)

	# Add outer energy shell (darker purple, larger)
	var shell = MeshInstance3D.new()
	var shell_mesh = SphereMesh.new()
	shell_mesh.radial_segments = 8
	shell_mesh.rings = 8
	shell_mesh.radius = 0.3
	shell_mesh.height = 0.6
	shell.mesh = shell_mesh

	var shell_mat = StandardMaterial3D.new()
	shell_mat.albedo_color = Color(0.5, 0.2, 0.7, 0.4)  # Dark purple, very transparent
	shell_mat.emission_enabled = true
	shell_mat.emission = Color(0.6, 0.3, 0.8)
	shell_mat.emission_energy_multiplier = 3.0
	shell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shell.material_override = shell_mat
	add_child(shell)

	# Add purple light (no shadows for performance)
	var light = OmniLight3D.new()
	light.light_color = Color(0.8, 0.4, 1.0)  # Purple light
	light.light_energy = 3.0
	light.omni_range = 8.0
	light.shadow_enabled = false
	add_child(light)

	# Pulsing animation
	var tween = core.create_tween()
	tween.set_loops()
	tween.tween_property(core, "scale", Vector3(1.2, 1.2, 1.2), 0.2)
	tween.tween_property(core, "scale", Vector3(0.8, 0.8, 0.8), 0.2)

	# Rotating shell
	var tween_shell = shell.create_tween()
	tween_shell.set_loops()
	tween_shell.tween_property(shell, "rotation:y", TAU, 1.0)


func initialize(start_pos: Vector3, target_pos: Vector3, shooter = null):
	"""Initialize the void bolt with direction and speed"""
	global_position = start_pos
	_shooter = shooter

	# Calculate direction to target
	var direction = (target_pos - start_pos).normalized()

	# Set velocity (straight line, no arc)
	_velocity = direction * SPEED
	initial_velocity = _velocity

	# Face the direction of travel
	look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float):
	lifetime -= delta

	if lifetime <= 0:
		_explode()
		return

	# Move bolt
	var motion = _velocity * delta

	# Check for terrain collision
	if _terrain != null:
		var vt = _terrain.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE

		var hit = vt.raycast(global_position, _velocity.normalized(), motion.length() + 0.5)
		if hit != null:
			# Hit terrain!
			_explode()
			return

	# Check for player collision
	var player = get_tree().get_first_node_in_group("player")
	if player and player != _shooter:
		if global_position.distance_to(player.global_position) < 1.0:
			_hit_target(player)
			return

	# Check for companion collision
	var companions = get_tree().get_nodes_in_group("companions")
	for companion in companions:
		if companion != _shooter:
			if global_position.distance_to(companion.global_position) < 1.0:
				_hit_target(companion)
				return

	global_position += motion


func _hit_target(target):
	"""Hit a player or companion"""
	print("🟣 Void bolt hit ", target.name, " for ", damage, " damage!")

	# Deal damage if target has health
	if target.has_method("take_damage"):
		target.take_damage(damage)
	elif target.has_method("hit"):
		target.hit(damage)

	_explode()


func _explode():
	"""Void bolt explodes on impact"""
	# TODO: Add purple explosion particle effect
	print("🟣 Void bolt exploded at ", global_position)
	queue_free()
