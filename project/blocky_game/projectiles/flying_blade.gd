extends Node3D

## Flying Blade - Chain-attacking sword projectile
## Flies from enemy to enemy, dealing damage to each

const EntityBase = preload("../entities/entity_base.gd")

enum State {
	SEEKING,     # Flying toward an enemy
	RETURNING    # Flying back to player
}

var state: State = State.SEEKING
var speed := 25.0
var damage := 35  # Rare drop magical weapon - strong damage per hit
var owner_entity = null  # Player who launched the blade
var max_chain_count := 5  # Maximum enemies to hit
var search_range := 20.0  # Range to search for enemies
var hit_enemies: Array = []  # Track which enemies we've already hit

# Current target
var current_target = null
var return_position := Vector3.ZERO

# Visual
var _blade_mesh: MeshInstance3D = null  # Main blade mesh for rotation
var _rotation_speed := 3.0  # Radians per second for tumbling effect


func _ready():
	# Create visual representation - 3D fantasy sword mesh

	# === BLADE ===
	_blade_mesh = MeshInstance3D.new()
	var blade_mesh = BoxMesh.new()
	blade_mesh.size = Vector3(0.08, 1.0, 0.15)  # Wide, tall, thin
	_blade_mesh.mesh = blade_mesh
	# Position blade forward (along -Z axis) so tip points toward enemies
	# Rotate 90 degrees around X to convert from vertical to horizontal
	_blade_mesh.position = Vector3(0, 0, -0.5)  # Center pivot at hilt, blade points forward
	_blade_mesh.rotation_degrees = Vector3(90, 0, 0)  # Rotate from vertical to horizontal

	var blade_mat = StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.8, 0.85, 1.0)  # Silver-blue
	blade_mat.metallic = 0.95
	blade_mat.roughness = 0.1
	blade_mat.emission_enabled = true
	blade_mat.emission = Color(0.6, 0.7, 1.2)  # Blue magical glow
	blade_mat.emission_energy_multiplier = 3.0
	_blade_mesh.material_override = blade_mat
	add_child(_blade_mesh)

	# === BLADE TIP (tapered point) ===
	var tip = MeshInstance3D.new()
	var tip_mesh = BoxMesh.new()
	tip_mesh.size = Vector3(0.04, 0.2, 0.08)  # Narrower
	tip.mesh = tip_mesh
	tip.position = Vector3(0, 0, -1.1)  # At tip of blade (forward)
	tip.rotation_degrees = Vector3(90, 0, 0)  # Match blade orientation
	tip.scale = Vector3(1.0, 1.0, 0.5)  # Taper effect
	tip.material_override = blade_mat  # Same material as blade
	add_child(tip)

	# === CROSSGUARD ===
	var guard = MeshInstance3D.new()
	var guard_mesh = BoxMesh.new()
	guard_mesh.size = Vector3(0.4, 0.08, 0.08)  # Wide horizontal bar
	guard.mesh = guard_mesh
	guard.position = Vector3(0, 0, 0)  # At hilt (stays horizontal, perpendicular to blade)

	var guard_mat = StandardMaterial3D.new()
	guard_mat.albedo_color = Color(0.3, 0.25, 0.4)  # Dark purple
	guard_mat.metallic = 0.8
	guard_mat.roughness = 0.3
	guard.material_override = guard_mat
	add_child(guard)

	# === HANDLE ===
	var handle = MeshInstance3D.new()
	var handle_mesh = CylinderMesh.new()
	handle_mesh.top_radius = 0.04
	handle_mesh.bottom_radius = 0.05
	handle_mesh.height = 0.3
	handle.mesh = handle_mesh
	handle.position = Vector3(0, 0, 0.15)  # Behind crossguard (positive Z)
	handle.rotation_degrees = Vector3(0, 0, 0)  # Cylinder already along Y, but we need it along Z
	# Actually rotate it to point along Z axis
	handle.rotation_degrees = Vector3(90, 0, 90)  # Orient along Z axis (backward from blade)

	var handle_mat = StandardMaterial3D.new()
	handle_mat.albedo_color = Color(0.2, 0.15, 0.3)  # Darker purple
	handle_mat.roughness = 0.6
	handle.material_override = handle_mat
	add_child(handle)

	# === POMMEL (end of handle) ===
	var pommel = MeshInstance3D.new()
	var pommel_mesh = SphereMesh.new()
	pommel_mesh.radius = 0.06
	pommel.mesh = pommel_mesh
	pommel.position = Vector3(0, 0, 0.3)  # At end of handle (behind blade)
	pommel.material_override = guard_mat  # Same as crossguard
	add_child(pommel)

	# === MAGICAL AURA (transparent overlay on blade) ===
	var aura = MeshInstance3D.new()
	var aura_mesh = BoxMesh.new()
	aura_mesh.size = Vector3(0.15, 1.3, 0.2)  # Slightly larger than blade
	aura.mesh = aura_mesh
	aura.position = Vector3(0, 0, -0.15)  # Offset relative to blade (forward along Z)

	var aura_mat = StandardMaterial3D.new()
	aura_mat.albedo_color = Color(0.5, 0.6, 1.0, 0.3)  # Transparent blue
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.emission_enabled = true
	aura_mat.emission = Color(0.6, 0.7, 1.2)
	aura_mat.emission_energy_multiplier = 4.0
	aura_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	aura.material_override = aura_mat
	_blade_mesh.add_child(aura)  # Child of blade so it inherits rotation and orientation

	# Animate aura pulsing
	var tween = get_tree().create_tween()
	tween.set_loops()
	tween.tween_property(aura, "scale", Vector3(1.2, 1.1, 1.2), 0.3)
	tween.tween_property(aura, "scale", Vector3(0.9, 0.9, 0.9), 0.3)

	# === LIGHT ===
	var light = OmniLight3D.new()
	light.light_color = Color(0.6, 0.7, 1.0)  # Blue-white
	light.light_energy = 2.0
	light.omni_range = 4.0
	light.shadow_enabled = false
	add_child(light)

	print("⚔️ Created 3D blade mesh with magical aura")


func initialize(start_pos: Vector3, player: Node3D):
	"""Initialize the blade with starting position and player reference"""
	global_position = start_pos
	owner_entity = player
	return_position = start_pos

	# Find first target
	_find_next_target()


func _process(delta: float):
	# Tumble the entire blade for dynamic flight effect
	# Rotate on a diagonal axis for realistic sword tumbling
	rotate_object_local(Vector3(1, 0, 1).normalized(), _rotation_speed * delta)

	match state:
		State.SEEKING:
			_process_seeking(delta)
		State.RETURNING:
			_process_returning(delta)


func _process_seeking(delta: float):
	"""Fly toward current target enemy"""
	if not is_instance_valid(current_target):
		# Target lost, find another or return
		_find_next_target()
		return

	# Move toward target
	var direction = (current_target.global_position - global_position).normalized()
	global_position += direction * speed * delta

	# Point blade toward target (this orients the Node3D, sprite follows due to being a child)
	# Use look_at to point the -Z axis toward the target
	var target_position = current_target.global_position
	look_at(target_position, Vector3.UP)

	# Check if close enough to hit
	var distance = global_position.distance_to(current_target.global_position)
	if distance < 0.8:
		_hit_enemy(current_target)


func _process_returning(delta: float):
	"""Fly back to player"""
	if not is_instance_valid(owner_entity):
		_cleanup_and_free()
		return

	# Move toward player
	var target_pos = owner_entity.global_position + Vector3(0, 1, 0)  # Aim for chest height
	var direction = (target_pos - global_position).normalized()
	global_position += direction * speed * delta

	# Point blade toward player while returning
	look_at(target_pos, Vector3.UP)

	# Check if close enough to player
	var distance = global_position.distance_to(target_pos)
	if distance < 1.0:
		_cleanup_and_free()  # Blade returns to player


func _find_next_target():
	"""Find the next nearest enemy that hasn't been hit yet"""
	if hit_enemies.size() >= max_chain_count:
		# Hit maximum enemies, return to player
		_return_to_player()
		return

	if not is_instance_valid(owner_entity):
		_cleanup_and_free()
		return

	# Get all entities in the scene
	var entities = get_tree().get_nodes_in_group("entities")

	var nearest_enemy = null
	var nearest_distance = search_range

	for entity in entities:
		if not is_instance_valid(entity):
			continue

		# Skip if not an enemy
		if "team" not in entity or entity.team != 2:  # 2 = ENEMY
			continue

		# Skip if already hit
		if hit_enemies.has(entity):
			continue

		var distance = global_position.distance_to(entity.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = entity

	if nearest_enemy:
		current_target = nearest_enemy
		print("⚔️ Blade targeting: %s (%d/%d)" % [nearest_enemy.entity_name if "entity_name" in nearest_enemy else "enemy", hit_enemies.size() + 1, max_chain_count])
	else:
		# No more enemies in range, return to player
		_return_to_player()


func _hit_enemy(enemy: Node3D):
	"""Deal damage to enemy and find next target"""
	if not is_instance_valid(enemy):
		_find_next_target()
		return

	# Mark as hit
	hit_enemies.append(enemy)

	# Deal damage
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage, owner_entity)
		print("⚔️ Blade hit %s for %d damage!" % [enemy.entity_name if "entity_name" in enemy else "enemy", damage])

	# Spawn slash effect at impact
	var direction = (enemy.global_position - global_position).normalized()
	SlashEffectSpawner.spawn_slash(
		get_node("/root/Main/Game"),
		enemy.global_position,
		direction,
		Color(0.7, 0.9, 1.2, 1.0),  # Bright blue slash for magical blade
		0.25,  # Duration
		9.0,   # Intensity (very bright)
		6.0,   # Speed (fast animation)
		2.0,   # Scale
		"res://assets/art/textures/slash_01.png"
	)

	# Find next target
	_find_next_target()


func _return_to_player():
	"""Switch to returning state"""
	state = State.RETURNING
	current_target = null
	print("⚔️ Blade returning to player (%d enemies hit)" % hit_enemies.size())


func _cleanup_and_free():
	"""Clean up and free the blade"""
	queue_free()
