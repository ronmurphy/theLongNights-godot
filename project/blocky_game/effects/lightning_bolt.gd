extends Node3D

## Lightning Bolt Effect
## Can spawn from sky or from caster position
## Damages target and shows electric visual effect

var target_position: Vector3
var damage: int = 25
var from_sky: bool = true
var caster_position: Vector3

var _lifetime := 0.5
var _hit_applied := false


func _ready():
	# Create lightning bolt visual
	if from_sky:
		_create_sky_lightning()
	else:
		_create_caster_lightning()

	# Auto-delete after effect
	await get_tree().create_timer(_lifetime).timeout
	queue_free()


func initialize(target: Vector3, dmg: int, from_above: bool, caster_pos: Vector3 = Vector3.ZERO):
	target_position = target
	damage = dmg
	from_sky = from_above
	caster_position = caster_pos


func _create_sky_lightning():
	"""Create lightning bolt from sky to target"""
	var start_pos = target_position + Vector3(0, 20, 0)  # High in sky
	var end_pos = target_position

	_create_bolt_beam(start_pos, end_pos)
	_create_impact_flash(end_pos)


func _create_caster_lightning():
	"""Create lightning bolt from caster to target"""
	var start_pos = caster_position + Vector3(0, 1.5, 0)  # From companion's hand
	var end_pos = target_position + Vector3(0, 1.0, 0)  # At target's chest

	_create_bolt_beam(start_pos, end_pos)
	_create_impact_flash(end_pos)


func _create_bolt_beam(start: Vector3, end: Vector3):
	"""Create the lightning bolt beam visual"""
	# Main bolt
	var bolt = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()

	var distance = start.distance_to(end)
	cylinder.height = distance
	cylinder.top_radius = 0.08
	cylinder.bottom_radius = 0.08

	bolt.mesh = cylinder

	# Electric blue glowing material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.8, 1.0)  # Light blue
	material.emission_enabled = true
	material.emission = Color(0.7, 0.9, 1.0)
	material.emission_energy_multiplier = 10.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bolt.material_override = material

	add_child(bolt)

	# Position bolt between start and end
	bolt.global_position = (start + end) / 2.0
	bolt.look_at(end, Vector3.UP)
	bolt.rotate_object_local(Vector3.RIGHT, PI / 2)  # Align with direction

	# Add outer glow
	var glow = MeshInstance3D.new()
	var glow_cyl = CylinderMesh.new()
	glow_cyl.height = distance
	glow_cyl.top_radius = 0.15
	glow_cyl.bottom_radius = 0.15
	glow.mesh = glow_cyl

	var glow_mat = StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.6, 0.9, 1.0, 0.5)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.8, 0.95, 1.0)
	glow_mat.emission_energy_multiplier = 8.0
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.material_override = glow_mat

	bolt.add_child(glow)

	# Animate bolt flickering
	var tween = create_tween()
	tween.set_loops(5)
	tween.tween_property(material, "emission_energy_multiplier", 15.0, 0.05)
	tween.tween_property(material, "emission_energy_multiplier", 5.0, 0.05)


func _create_impact_flash(pos: Vector3):
	"""Create electric flash at impact point"""
	# Electric sparks
	for i in range(12):
		var spark = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.1, 0.3, 0.1)
		spark.mesh = box

		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.7, 0.95, 1.0)
		material.emission_enabled = true
		material.emission = Color(0.8, 1.0, 1.0)
		material.emission_energy_multiplier = 12.0
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark.material_override = material

		add_child(spark)
		spark.global_position = pos

		# Random direction
		var direction = Vector3(
			randf_range(-1, 1),
			randf_range(-0.5, 1),
			randf_range(-1, 1)
		).normalized()

		# Animate spark flying outward
		var tween = spark.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", pos + direction * 2.0, 0.3)
		tween.tween_property(spark, "scale", Vector3.ZERO, 0.3)


func _physics_process(delta: float):
	_lifetime -= delta

	# Apply damage once
	if not _hit_applied:
		_hit_applied = true
		_damage_at_target()


func _damage_at_target():
	"""Damage entities at target position"""
	var entities = get_tree().get_nodes_in_group("entities")

	for entity in entities:
		if not entity.is_alive:
			continue

		# Don't hit friendly entities
		if entity.team == EntityBase.Team.PLAYER:
			continue

		# Check if entity is near target position
		var distance = entity.global_position.distance_to(target_position)
		if distance <= 1.5:  # Small AOE
			entity.take_damage(damage, self)
			print("⚡ Lightning struck %s for %d damage!" % [entity.entity_name, damage])
