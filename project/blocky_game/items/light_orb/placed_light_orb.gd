extends Node3D

# Placed light orb - static light source with no shadows
# Provides large radius illumination for functional area lighting

var _light : OmniLight3D = null


func _ready():
	# Create outer crystal shell (blue/cyan)
	var crystal_outer = MeshInstance3D.new()
	var outer_mesh = SphereMesh.new()
	outer_mesh.radial_segments = 12
	outer_mesh.rings = 12
	outer_mesh.radius = 0.25
	outer_mesh.height = 0.5
	crystal_outer.mesh = outer_mesh

	var outer_mat = StandardMaterial3D.new()
	outer_mat.albedo_color = Color(0.4, 0.8, 1.0, 0.7)  # Light blue, semi-transparent
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_mat.emission_enabled = true
	outer_mat.emission = Color(0.6, 0.9, 1.0)  # Bright cyan glow
	outer_mat.emission_energy_multiplier = 3.0
	outer_mat.metallic = 0.3
	outer_mat.roughness = 0.2
	crystal_outer.material_override = outer_mat
	add_child(crystal_outer)

	# Create inner core (bright white/cyan)
	var crystal_core = MeshInstance3D.new()
	var core_mesh = SphereMesh.new()
	core_mesh.radial_segments = 8
	core_mesh.rings = 8
	core_mesh.radius = 0.15
	core_mesh.height = 0.3
	crystal_core.mesh = core_mesh

	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.9, 1.0, 1.0)  # Near white with cyan tint
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.8, 1.0, 1.0)
	core_mat.emission_energy_multiplier = 6.0
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.albedo_color.a = 0.9
	crystal_core.material_override = core_mat
	add_child(crystal_core)

	# Add floating particles/sparkles around the crystal
	_create_sparkle_effect()

	# Create large area light with NO SHADOWS (performance!)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.7, 0.9, 1.0)  # Cool blue-white light
	_light.light_energy = 4.0  # Brighter than torches
	_light.omni_range = 30.0  # Much larger radius than torches (8-12)
	_light.omni_attenuation = 0.5  # Gentler falloff for wider coverage
	_light.shadow_enabled = false  # NO SHADOWS = massive performance boost!
	add_child(_light)

	# Gentle pulsing animation
	var tween = crystal_core.create_tween()
	tween.set_loops()
	tween.tween_property(crystal_core, "scale", Vector3(1.1, 1.1, 1.1), 1.5)
	tween.tween_property(crystal_core, "scale", Vector3(0.9, 0.9, 0.9), 1.5)

	# Slower outer crystal pulse
	var tween_outer = crystal_outer.create_tween()
	tween_outer.set_loops()
	tween_outer.tween_property(crystal_outer, "scale", Vector3(1.05, 1.05, 1.05), 2.0)
	tween_outer.tween_property(crystal_outer, "scale", Vector3(0.95, 0.95, 0.95), 2.0)

	# Rotate slowly for magical effect
	var rotation_tween = create_tween()
	rotation_tween.set_loops()
	rotation_tween.tween_property(self, "rotation:y", TAU, 8.0)


func _create_sparkle_effect():
	"""Add small floating particles around the crystal"""
	for i in range(4):
		var sparkle = MeshInstance3D.new()
		var sparkle_mesh = SphereMesh.new()
		sparkle_mesh.radius = 0.03
		sparkle_mesh.height = 0.06
		sparkle.mesh = sparkle_mesh

		var sparkle_mat = StandardMaterial3D.new()
		sparkle_mat.albedo_color = Color(0.9, 1.0, 1.0, 0.8)
		sparkle_mat.emission_enabled = true
		sparkle_mat.emission = Color(1.0, 1.0, 1.0)
		sparkle_mat.emission_energy_multiplier = 4.0
		sparkle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sparkle.material_override = sparkle_mat

		# Random position around crystal
		var angle = (TAU / 4.0) * i
		var radius = 0.4
		sparkle.position = Vector3(
			cos(angle) * radius,
			sin(angle * 2) * 0.2,  # Vertical variation
			sin(angle) * radius
		)

		add_child(sparkle)

		# Animate sparkles orbiting
		var orbit_tween = sparkle.create_tween()
		orbit_tween.set_loops()
		var new_angle = angle + TAU
		orbit_tween.tween_property(sparkle, "position", Vector3(
			cos(new_angle) * radius,
			sin(new_angle * 2) * 0.2,
			sin(new_angle) * radius
		), 4.0 + i * 0.5)  # Stagger timing


func set_light_range(range_value: float):
	"""Allow customization of light range if needed"""
	if _light:
		_light.omni_range = range_value
