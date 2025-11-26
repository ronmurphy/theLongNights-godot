extends Node3D

## Thorn projectile - Used by Ring of Thorns
## Can orbit around player or fly toward enemies

const EntityBase = preload("../entities/entity_base.gd")

enum Mode {
	ORBITING,  # Orbiting the player
	ATTACKING  # Flying toward an enemy
}

var mode: Mode = Mode.ORBITING
var speed := 15.0
var damage := 8
var direction := Vector3.FORWARD
var owner_entity = null  # Player who owns this thorn
var max_distance := 30.0
var _distance_traveled := 0.0

# Orbiting parameters
var orbit_center: Vector3 = Vector3.ZERO
var orbit_radius := 1.5
var orbit_angle := 0.0
var orbit_speed := 2.0  # Radians per second
var target_enemy = null

func _ready():
	# Create visual representation - green glowing sphere
	var thorn_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3  # Diameter (2 * radius)
	sphere.rings = 8
	sphere.radial_segments = 8
	thorn_mesh.mesh = sphere

	# Green emissive material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 0.2, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 1.0, 0.3)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	thorn_mesh.material_override = mat
	add_child(thorn_mesh)

	# Add green point light for glow effect
	var light = OmniLight3D.new()
	light.light_color = Color(0.3, 1.0, 0.3)
	light.light_energy = 0.5
	light.omni_range = 2.0
	add_child(light)

func _process(delta: float):
	match mode:
		Mode.ORBITING:
			_process_orbiting(delta)
		Mode.ATTACKING:
			_process_attacking(delta)

func _process_orbiting(delta: float):
	if not is_instance_valid(owner_entity):
		queue_free()
		return

	# Update orbit angle
	orbit_angle += orbit_speed * delta

	# Calculate position on orbit circle
	var offset = Vector3(
		cos(orbit_angle) * orbit_radius,
		0.5 + sin(orbit_angle * 2.0) * 0.3,  # Bob up and down
		sin(orbit_angle) * orbit_radius
	)

	# Position around owner
	global_position = owner_entity.global_position + offset

	# Rotate to face outward from orbit center
	look_at(global_position + offset.normalized(), Vector3.UP)

func _process_attacking(delta: float):
	if not is_instance_valid(target_enemy):
		# Target lost, return to orbiting
		mode = Mode.ORBITING
		return

	# Move toward enemy
	direction = (target_enemy.global_position - global_position).normalized()
	global_position += direction * speed * delta
	look_at(target_enemy.global_position, Vector3.UP)

	_distance_traveled += speed * delta

	# Check for push block collision
	_check_push_block_collision()

	# Check for hit (simple distance check)
	var distance_to_target = global_position.distance_to(target_enemy.global_position)
	if distance_to_target < 0.5:  # Hit!
		_hit_enemy()
		return

	# Despawn if traveled too far
	if _distance_traveled > max_distance:
		_return_to_orbit()

func launch_at_enemy(enemy: Node3D):
	"""Launch this thorn at an enemy"""
	target_enemy = enemy
	mode = Mode.ATTACKING
	_distance_traveled = 0.0
	direction = (enemy.global_position - global_position).normalized()

func _hit_enemy():
	"""Called when thorn hits an enemy"""
	if not is_instance_valid(target_enemy):
		_return_to_orbit()
		return

	# Deal damage if target can take damage
	if target_enemy.has_method("take_damage"):
		# Check if owner has weapon powers to apply
		var power_effects = _get_owner_power_effects()

		# Calculate damage with blood moon modifier
		var total_damage = damage

		# Apply blood moon damage modifier (from blood pendant, etc.)
		if is_instance_valid(owner_entity) and "blood_moon_damage_modifier" in owner_entity:
			total_damage = int(total_damage * (1.0 + owner_entity.blood_moon_damage_modifier))

		# Apply base damage
		target_enemy.take_damage(total_damage, owner_entity)

		# Apply power effects (poison, life steal, etc.)
		if power_effects.has("poison") and target_enemy.has_method("apply_poison"):
			target_enemy.apply_poison(5, 5.0)  # 5 damage over 5 seconds

		if power_effects.has("life_steal") and owner_entity.has_method("heal"):
			var heal_amount = int(total_damage * 0.1)  # 10% life steal
			owner_entity.heal(heal_amount)

		var damage_info = "🌿 Thorn hit %s for %d damage!" % [target_enemy.entity_name if "entity_name" in target_enemy else "enemy", total_damage]
		if is_instance_valid(owner_entity) and "blood_moon_damage_modifier" in owner_entity and owner_entity.blood_moon_damage_modifier > 0.0:
			damage_info += " [🩸 +%d%%]" % int(owner_entity.blood_moon_damage_modifier * 100)
		print(damage_info)

	# Return to orbit after hit
	_return_to_orbit()

func _return_to_orbit():
	"""Return thorn to orbiting mode"""
	mode = Mode.ORBITING
	target_enemy = null
	_distance_traveled = 0.0

func _get_owner_power_effects() -> Dictionary:
	"""Check if owner's equipped weapon has powers that should apply to thorn hits"""
	var effects = {}

	if not is_instance_valid(owner_entity):
		return effects

	# Try to get owner's equipped weapon
	var hotbar = owner_entity.get_node_or_null("../HotBar")
	if not hotbar:
		return effects

	var equipped_item = hotbar.get_selected_item()
	if not equipped_item:
		return effects

	# Get the actual item instance
	var items_db = owner_entity.get_node_or_null("/root/Main/Game/Items")
	if not items_db:
		return effects

	var item = items_db.get_item(equipped_item.id)
	if not item:
		return effects

	# Check for powers
	if "power" in equipped_item and equipped_item.power != "":
		var power_name = equipped_item.power
		effects[power_name] = true

	return effects


func _check_push_block_collision():
	"""Check if thorn hit a push block and apply light momentum"""
	var push_blocks = get_tree().get_nodes_in_group("push_blocks")

	for block in push_blocks:
		if not is_instance_valid(block):
			continue

		# Check distance
		var distance = global_position.distance_to(block.global_position)
		if distance < 0.8:  # Hit radius (smaller than arrow)
			# Light push from plant matter projectile
			var impulse = direction * 2.0  # Lightest push (plant matter)

			if block.has_method("apply_impulse"):
				block.apply_impulse(impulse)
				print("🌿 Thorn tapped the push block lightly!")

			# Return to orbit after hitting block
			_return_to_orbit()
			return
