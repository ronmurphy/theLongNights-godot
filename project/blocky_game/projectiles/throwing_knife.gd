extends Node3D

# Magical throwing knife that circles around target before striking
const EntityBase = preload("../entities/entity_base.gd")

var target_position : Vector3
var speed := 20.0
var circle_radius := 3.0  # How far from target to circle
var circles_before_impact := 3  # Number of full circles before hitting
var lifetime := 10.0
var base_damage := 12
var stack_bonus := 0
var direct_shot := false  # If true, goes straight to target (for power volley)

var _angle := 0.0  # Current angle around target
var _circles_completed := 0.0
var _terrain : VoxelTerrain = null
var _trail_timer := 0.0

var _mesh : MeshInstance3D = null
var _owner_node : Node = null
var _inv_item = null


func _ready():
	_terrain = get_node("/root/Main/Game/VoxelTerrain")

	# Create a magical knife visual
	var mesh_node = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.05, 0.3, 0.1)  # Thin knife shape
	mesh_node.mesh = box_mesh

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.9, 1.0)  # Silver-white
	material.metallic = 0.9
	material.roughness = 0.1
	material.emission_enabled = true
	material.emission = Color(0.9, 0.95, 1.0)  # Slight white glow
	material.emission_energy_multiplier = 2.0
	mesh_node.material_override = material

	add_child(mesh_node)
	_mesh = mesh_node

	# Add magical purple aura
	var aura = MeshInstance3D.new()
	var aura_mesh = BoxMesh.new()
	aura_mesh.size = Vector3(0.12, 0.4, 0.15)
	aura.mesh = aura_mesh
	var aura_mat = StandardMaterial3D.new()
	aura_mat.albedo_color = Color(0.7, 0.3, 1.0, 0.4)  # Purple magic
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.emission_enabled = true
	aura_mat.emission = Color(0.8, 0.4, 1.0)
	aura_mat.emission_energy_multiplier = 3.0
	aura_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	aura.material_override = aura_mat
	mesh_node.add_child(aura)


func initialize(start_pos: Vector3, target_pos: Vector3, stack_count: int = 1, owner_node: Node = null, inv_item = null, is_direct_shot: bool = false):
	global_position = start_pos
	target_position = target_pos
	stack_bonus = stack_count
	_owner_node = owner_node
	_inv_item = inv_item
	direct_shot = is_direct_shot

	# Start at a random angle (only used for spiral mode)
	_angle = randf() * TAU
	
	# Direct shot mode: faster and shorter lifetime
	if direct_shot:
		speed = 25.0  # Faster than spiral, but not TOO fast (was 35)
		lifetime = 3.0  # Shorter lifetime
		circles_before_impact = 0  # No circling
		
		# Enhance visual for direct shot - brighter glow
		if _mesh:
			var mat = _mesh.material_override as StandardMaterial3D
			if mat:
				mat.emission_energy_multiplier = 5.0  # Brighter (was 2.0)
			# Make aura brighter too
			for child in _mesh.get_children():
				if child is MeshInstance3D:
					var aura_mat = child.material_override as StandardMaterial3D
					if aura_mat:
						aura_mat.emission_energy_multiplier = 6.0  # Brighter purple trail


func _physics_process(delta: float):
	lifetime -= delta
	_trail_timer += delta

	if lifetime <= 0:
		queue_free()
		return

	# Spawn magic trail
	if _trail_timer > 0.04:
		_spawn_magic_trail()
		_trail_timer = 0.0

	# Direct shot mode: fly straight to target
	if direct_shot:
		var direction = (target_position - global_position).normalized()
		var motion = direction * speed * delta
		
		# Point knife forward
		if direction.length() > 0.1:
			look_at(global_position + direction, Vector3.UP)
			_mesh.rotate_z(delta * 30.0)  # Fast spin
		
		# Check for entity collision
		_check_entity_collision()
		
		# Move toward target
		global_position += motion
		
		# If we reached target, explode
		if global_position.distance_to(target_position) < 1.0:
			queue_free()
		
		return  # Skip spiral behavior
	
	# === SPIRAL MODE (original throwing knife behavior) ===
	# Calculate how many radians to move this frame
	# We want to complete circles_before_impact circles total
	var radians_per_second = (TAU * speed) / (circle_radius * TAU)  # Angular speed
	_angle += radians_per_second * delta

	# Track how many circles we've done
	_circles_completed = _angle / TAU

	# Gradually decrease radius as we spiral inward
	var progress = min(_circles_completed / circles_before_impact, 1.0)
	var current_radius = circle_radius * (1.0 - progress)

	# Calculate position circling around target
	var offset = Vector3(
		cos(_angle) * current_radius,
		sin(_angle * 2.0) * 0.5,  # Slight vertical wave
		sin(_angle) * current_radius
	)

	var new_pos = target_position + offset

	# Point knife in direction of movement
	var direction = (new_pos - global_position).normalized()
	if direction.length() > 0.1:
		look_at(new_pos, Vector3.UP)
		# Spin the knife as it flies
		_mesh.rotate_z(delta * 20.0)

	# Move to new position
	global_position = new_pos

	# Check for entity collision
	_check_entity_collision()

	# Check if we've completed enough circles and are close enough
	if _circles_completed >= circles_before_impact or current_radius < 0.2:
		_on_impact(target_position)
		return

	# Check for collision with terrain during flight
	if _terrain != null:
		var vt = _terrain.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE
		var block_pos = Vector3i(floor(global_position.x), floor(global_position.y), floor(global_position.z))
		var voxel = vt.get_voxel(block_pos)
		if voxel != 0:
			# Hit a block!
			_on_impact(Vector3(block_pos))
			return


func _spawn_magic_trail():
	"""Spawn purple magic particles as trail"""
	var particle = MeshInstance3D.new()
	var star = BoxMesh.new()
	star.size = Vector3(0.06, 0.06, 0.06)
	particle.mesh = star

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.5, 1.0, 0.6)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(0.9, 0.6, 1.0)
	material.emission_energy_multiplier = 2.5
	particle.material_override = material

	get_parent().add_child(particle)
	particle.global_position = global_position

	# Fade out
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(particle, "scale", Vector3.ZERO, 0.3)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.3)
	tween.tween_callback(particle.queue_free)


func _check_entity_collision():
	"""Check if knife hit any entities during its spiral"""
	var entities = get_tree().get_nodes_in_group("entities")

	for entity in entities:
		# Safety check: make sure entity is still valid
		if not is_instance_valid(entity):
			continue
			
		if not entity.is_alive:
			continue

		# Don't hit friendly entities
		if entity.team == EntityBase.Team.PLAYER:
			continue

		# Check distance
		var distance = global_position.distance_to(entity.global_position)
		if distance < 0.7:  # Hit radius
			_on_hit_entity(entity)
			return


func _on_hit_entity(entity: Node):
	"""Hit an entity with knife damage"""
	var total_damage = base_damage + stack_bonus
	entity.take_damage(total_damage, _owner_node if _owner_node else self)
	print("Throwing knife hit %s for %d damage! (base: %d + stack: %d)" % [entity.entity_name, total_damage, base_damage, stack_bonus])

	# ⚡ SKYSHARD POWERS via Powers.gd
	if typeof(_inv_item) == TYPE_OBJECT and _inv_item != null and _inv_item.skyshard_power != "":
		Powers.execute_hotbar_power(_inv_item.skyshard_power, {
			"entity": entity,
			"position": entity.global_position,
			"damage": total_damage,
			"stack_count": stack_bonus,
			"attacker": _owner_node if _owner_node else self
		})

	# Spawn impact sparkles
	_spawn_impact_sparkles(entity.global_position)

	queue_free()


func _spawn_impact_sparkles(pos: Vector3):
	"""Create magical sparkle effect on hit"""
	for i in range(8):
		var particle = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.08, 0.08, 0.08)
		particle.mesh = box

		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.9, 0.7, 1.0, 0.9)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.emission_enabled = true
		material.emission = Color(1.0, 0.8, 1.0)
		material.emission_energy_multiplier = 4.0
		particle.material_override = material

		get_parent().add_child(particle)
		particle.global_position = pos

		# Random direction
		var direction = Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)).normalized()

		# Animate sparkle
		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", pos + direction * 1.5, 0.4)
		tween.tween_property(particle, "scale", Vector3.ZERO, 0.4)
		tween.tween_callback(particle.queue_free)


func _on_impact(hit_pos: Vector3):
	"""Handle impact with target or block"""
	print("Throwing knife impact at ", hit_pos)

	if _terrain != null:
		var vt = _terrain.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE

		var block_pos = Vector3i(floor(hit_pos.x), floor(hit_pos.y), floor(hit_pos.z))
		var voxel_id = vt.get_voxel(block_pos)

		# Destroy block if it's not bedrock (bedrock is typically ID 0 or a specific ID)
		# Assuming bedrock is voxel ID 0, we check if it's anything else
		if voxel_id != 0:
			vt.set_voxel(block_pos, 0)
			print("Knife destroyed block at ", block_pos)

	queue_free()
