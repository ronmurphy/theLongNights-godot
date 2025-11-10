extends Node3D

## Flying orb projectile - visual effect when placing a light orb
## Flies from player to target location with glowing trail

const PlacedLightOrb = preload("placed_light_orb.gd")

var target_position: Vector3
var flight_speed := 25.0  # Fast but visible
var _world_container: Node = null


func _ready():
	# Create glowing orb visual
	var orb_visual = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.2
	sphere_mesh.height = 0.4
	orb_visual.mesh = sphere_mesh

	var orb_mat = StandardMaterial3D.new()
	orb_mat.albedo_color = Color(0.6, 0.9, 1.0, 0.9)
	orb_mat.emission_enabled = true
	orb_mat.emission = Color(0.7, 1.0, 1.0)
	orb_mat.emission_energy_multiplier = 6.0
	orb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orb_visual.material_override = orb_mat
	add_child(orb_visual)

	# Gentle rotation while flying
	var tween = orb_visual.create_tween()
	tween.set_loops()
	tween.tween_property(orb_visual, "rotation:y", TAU, 1.0)

	# Create particle trail
	var particles = CPUParticles3D.new()
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.5
	particles.local_coords = false

	# Trail emission
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.1

	# Particle appearance - cyan/white sparkles
	particles.scale_amount_min = 0.1
	particles.scale_amount_max = 0.2

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.7, 1.0, 1.0, 1.0))  # Bright cyan
	gradient.add_point(1.0, Color(0.4, 0.7, 1.0, 0.0))  # Fade to transparent
	particles.color_ramp = gradient

	# Movement - trail behind
	particles.direction = Vector3(0, 0, 0)
	particles.spread = 20.0
	particles.initial_velocity_min = 0.5
	particles.initial_velocity_max = 1.5
	particles.gravity = Vector3(0, -1, 0)

	add_child(particles)


func initialize(start_pos: Vector3, target_pos: Vector3, world_container: Node):
	global_position = start_pos
	target_position = target_pos
	_world_container = world_container


func _physics_process(delta: float):
	# Move toward target
	var direction = (target_position - global_position).normalized()
	var distance = global_position.distance_to(target_position)

	# If very close, place the actual light orb
	if distance < 0.5:
		_place_light_orb()
		return

	# Move toward target
	global_position += direction * flight_speed * delta


func _place_light_orb():
	"""Reached destination - create the actual light orb with burst effect"""
	# Check if we hit a void_beacon block
	const VOID_BEACON = 57
	const RUIN_VOID_LAMP = 59
	
	var terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")
	if terrain:
		var voxel_tool = terrain.get_voxel_tool()
		voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE
		
		# Check block at target position
		var block_pos = Vector3i(floor(target_position.x), floor(target_position.y), floor(target_position.z))
		var block_id = voxel_tool.get_voxel(block_pos)
		
		if block_id == VOID_BEACON:
			# HIT A VOID BEACON! Convert it!
			print("💥 Light Orb hit void_beacon! Converting to ruin_void_lamp...")
			
			# Replace void_beacon with ruin_void_lamp
			voxel_tool.set_voxel(block_pos, RUIN_VOID_LAMP)
			
			# Find and destroy the purple UndervoidBeacon light
			_destroy_nearby_undervoid_beacon(Vector3(block_pos) + Vector3(0.5, 0.5, 0.5))
			
			# Create explosion effect (bigger burst)
			_create_conversion_explosion()
			
			# Spawn cyan light orb at the beacon position (half range)
			var orb = Node3D.new()
			orb.set_script(PlacedLightOrb)
			
			# Set custom range BEFORE adding to tree (so _ready() uses it)
			orb.set("_custom_range", 15.0)  # Half of normal 30.0 range
			
			_world_container.add_child(orb)  # _ready() is called here
			orb.global_position = Vector3(block_pos) + Vector3(0.5, 1.0, 0.5)  # On top of the block
			
			print("✨ Void beacon converted to friendly light!")
			queue_free()
			return
	
	# Normal placement - create placement burst particles
	_create_placement_burst()

	# Spawn the actual light orb
	var orb = Node3D.new()
	orb.set_script(PlacedLightOrb)
	_world_container.add_child(orb)  # Add to tree FIRST
	orb.global_position = target_position  # THEN set position

	print("Light Orb placed at: ", target_position)

	# Remove this flying projectile
	queue_free()


func _destroy_nearby_undervoid_beacon(position: Vector3):
	"""Find and destroy the purple UndervoidBeacon light near the converted block"""
	# Search for UndervoidBeacon nodes near this position
	var all_nodes = get_tree().get_nodes_in_group("undervoid_beacons")
	for node in all_nodes:
		if node.global_position.distance_to(position) < 2.0:
			print("🟣 Destroying purple UndervoidBeacon at ", node.global_position)
			node.queue_free()
			return
	
	# If not in group, search manually (slower but more reliable)
	var root = get_node("/root/Main/Game")
	if root:
		for child in root.get_children():
			if child is Node3D and child.global_position.distance_to(position) < 2.0:
				# Check if it has the UndervoidBeacon script
				if child.get_script() and "undervoid_beacon" in child.get_script().resource_path.to_lower():
					print("🟣 Destroying purple UndervoidBeacon at ", child.global_position)
					child.queue_free()
					return


func _create_conversion_explosion():
	"""Create dramatic explosion effect when converting void beacon"""
	var burst = CPUParticles3D.new()
	burst.position = target_position
	burst.emitting = true
	burst.one_shot = true
	burst.amount = 60  # Double the normal burst
	burst.lifetime = 1.2
	burst.explosiveness = 1.0
	burst.local_coords = false

	# Burst shape
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 0.5

	# Particle appearance - purple to cyan transition
	burst.scale_amount_min = 0.2
	burst.scale_amount_max = 0.5

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.8, 0.4, 1.0, 1.0))  # Purple (old beacon)
	gradient.add_point(0.3, Color(1.0, 1.0, 1.0, 1.0))  # Flash white
	gradient.add_point(0.6, Color(0.5, 0.9, 1.0, 0.8))  # Cyan (new light)
	gradient.add_point(1.0, Color(0.3, 0.6, 1.0, 0.0))  # Fade out
	burst.color_ramp = gradient

	# Movement - big explosion
	burst.direction = Vector3(0, 1, 0)
	burst.spread = 180.0
	burst.initial_velocity_min = 4.0
	burst.initial_velocity_max = 8.0
	burst.gravity = Vector3(0, -5, 0)

	# Add to world
	_world_container.add_child(burst)

	# Auto-cleanup
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(burst):
		burst.queue_free()


func _create_placement_burst():
	"""Create particle burst when orb materializes"""
	var burst = CPUParticles3D.new()
	burst.position = target_position
	burst.emitting = true
	burst.one_shot = true
	burst.amount = 30
	burst.lifetime = 0.8
	burst.explosiveness = 1.0
	burst.local_coords = false

	# Burst shape
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	burst.emission_sphere_radius = 0.3

	# Particle appearance - bright cyan burst
	burst.scale_amount_min = 0.15
	burst.scale_amount_max = 0.3

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.9, 1.0, 1.0, 1.0))  # Bright white-cyan
	gradient.add_point(0.5, Color(0.5, 0.9, 1.0, 0.8))  # Cyan
	gradient.add_point(1.0, Color(0.3, 0.6, 1.0, 0.0))  # Fade out
	burst.color_ramp = gradient

	# Movement - explode outward then fall
	burst.direction = Vector3(0, 1, 0)
	burst.spread = 180.0
	burst.initial_velocity_min = 2.0
	burst.initial_velocity_max = 4.0
	burst.gravity = Vector3(0, -3, 0)

	# Add to world
	_world_container.add_child(burst)

	# Auto-cleanup
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(burst):
		burst.queue_free()
