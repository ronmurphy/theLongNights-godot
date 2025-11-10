extends Node3D

# Undervoid Beacon - Purple light source for Undervoid structures
# Non-retrievable decorative light that marks dangerous structures
# Players see the purple glow and know: "monsters ahead"

var _light : OmniLight3D = null


func _ready():
	# Add to group so light orbs can find and destroy us
	add_to_group("undervoid_beacons")
	
	# Create outer crystal shell (dark purple)
	var crystal_outer = MeshInstance3D.new()
	var outer_mesh = SphereMesh.new()
	outer_mesh.radial_segments = 12
	outer_mesh.rings = 12
	outer_mesh.radius = 0.25
	outer_mesh.height = 0.5
	crystal_outer.mesh = outer_mesh

	var outer_mat = StandardMaterial3D.new()
	outer_mat.albedo_color = Color(0.6, 0.3, 0.8, 0.7)  # Purple, semi-transparent
	outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer_mat.emission_enabled = true
	outer_mat.emission = Color(0.7, 0.4, 1.0)  # Bright purple glow
	outer_mat.emission_energy_multiplier = 3.0
	outer_mat.metallic = 0.3
	outer_mat.roughness = 0.2
	crystal_outer.material_override = outer_mat
	add_child(crystal_outer)

	# Create inner core (bright magenta/purple)
	var crystal_core = MeshInstance3D.new()
	var core_mesh = SphereMesh.new()
	core_mesh.radial_segments = 8
	core_mesh.rings = 8
	core_mesh.radius = 0.15
	core_mesh.height = 0.3
	crystal_core.mesh = core_mesh

	var core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 0.6, 1.0)  # Bright magenta
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.5, 1.0)
	core_mat.emission_energy_multiplier = 6.0
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.albedo_color.a = 0.9
	crystal_core.material_override = core_mat
	add_child(crystal_core)

	# Add floating particles/sparkles around the crystal
	_create_sparkle_effect()

	# Create large area light with NO SHADOWS (performance!)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.8, 0.4, 1.0)  # Purple light
	_light.light_energy = 4.0  # Same brightness as player light orb
	_light.omni_range = 30.0  # Same range as player light orb
	_light.omni_attenuation = 0.5  # Gentler falloff for wider coverage
	_light.shadow_enabled = false  # NO SHADOWS = massive performance boost!
	add_child(_light)

	# Slower, more ominous pulsing animation
	var tween = crystal_core.create_tween()
	tween.set_loops()
	tween.tween_property(crystal_core, "scale", Vector3(1.15, 1.15, 1.15), 2.0)
	tween.tween_property(crystal_core, "scale", Vector3(0.85, 0.85, 0.85), 2.0)

	# Slower outer crystal pulse
	var tween_outer = crystal_outer.create_tween()
	tween_outer.set_loops()
	tween_outer.tween_property(crystal_outer, "scale", Vector3(1.08, 1.08, 1.08), 2.5)
	tween_outer.tween_property(crystal_outer, "scale", Vector3(0.92, 0.92, 0.92), 2.5)

	# Rotate slowly for ominous effect
	var rotation_tween = create_tween()
	rotation_tween.set_loops()
	rotation_tween.tween_property(self, "rotation:y", TAU, 10.0)  # Slower rotation


func _create_sparkle_effect():
	"""Add small floating particles around the crystal"""
	for i in range(4):
		var sparkle = MeshInstance3D.new()
		var sparkle_mesh = SphereMesh.new()
		sparkle_mesh.radius = 0.03
		sparkle_mesh.height = 0.06
		sparkle.mesh = sparkle_mesh

		var sparkle_mat = StandardMaterial3D.new()
		sparkle_mat.albedo_color = Color(1.0, 0.6, 1.0, 0.8)  # Magenta sparkles
		sparkle_mat.emission_enabled = true
		sparkle_mat.emission = Color(1.0, 0.5, 1.0)
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
		), 5.0 + i * 0.5)  # Slower, more ominous


# NOT retrievable - this is a structure decoration
# Intentionally no is_retrievable() or get_item_id() methods
