extends "../item.gd"
## Machete - Fast melee weapon with slash attack
## Used by human companions
## Deals single-target damage with quick attack speed

const SERVER_PEER_ID = 1

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")

const MAX_TARGET_DISTANCE = 4.0  # Medium melee range
const DAMAGE = 20  # Higher single-target damage than hammer
const ATTACK_SPEED = 0.5  # Fast attack (cooldown in seconds)


func use(trans: Transform3D):
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_use", trans)
	else:
		_use(trans)


func _use(trans: Transform3D):
	var origin = trans.origin
	var direction = -trans.basis.z.normalized()

	# Find target entity with raycast
	var target_entity = _find_target_entity(origin, direction)

	if target_entity:
		# Direct hit on entity
		_slash_attack(target_entity, origin)
	else:
		# Slash at air (show slash effect)
		var slash_pos = origin + direction * 2.0
		_spawn_slash_effect(slash_pos, direction)

	print("Machete slash!")


func _find_target_entity(origin: Vector3, direction: Vector3) -> Node:
	# Raycast to find entities in attack direction
	var space_state = get_tree().root.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * MAX_TARGET_DISTANCE
	)

	var result = space_state.intersect_ray(query)
	if result:
		return result.collider

	# If no physics hit, check entities manually
	var entities = get_tree().get_nodes_in_group("entities")
	var closest_entity = null
	var closest_distance = MAX_TARGET_DISTANCE

	for entity in entities:
		if not entity.is_alive:
			continue

		# Check if entity is roughly in front of player
		var to_entity = entity.global_position - origin
		var distance = to_entity.length()

		if distance > MAX_TARGET_DISTANCE:
			continue

		# Check if entity is in attack cone (60 degree arc)
		var angle = direction.angle_to(to_entity.normalized())
		if angle > deg_to_rad(30):  # 30 degrees each side = 60 degree cone
			continue

		# Only attack enemies
		if entity.team != EntityBase.Team.ENEMY:
			continue

		if distance < closest_distance:
			closest_distance = distance
			closest_entity = entity

	return closest_entity


func _slash_attack(entity: Node, attacker_pos: Vector3):
	# Deal damage
	entity.take_damage(DAMAGE, self)

	# Spawn slash effect at entity position
	_spawn_slash_effect(entity.global_position, (entity.global_position - attacker_pos).normalized())

	print("Machete hit %s for %d damage!" % [entity.entity_name, DAMAGE])


func _spawn_slash_effect(pos: Vector3, direction: Vector3):
	# Create slash particle effect (white/silver streak)
	var particles = GPUParticles3D.new()
	particles.position = pos + Vector3(0, 1.0, 0)  # At chest height
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 15
	particles.lifetime = 0.3
	particles.explosiveness = 1.0

	# Particle material
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(0.5, 0.5, 0.1)
	material.direction = direction
	material.spread = 25.0
	material.initial_velocity_min = 3.0
	material.initial_velocity_max = 6.0
	material.gravity = Vector3(0, -5.0, 0)
	material.scale_min = 0.1
	material.scale_max = 0.2
	material.color = Color(0.9, 0.9, 1.0)  # Bright silver/white

	particles.process_material = material

	# Add to scene
	get_node("/root/Main/Game").add_child(particles)

	# Auto-delete after lifetime
	await get_tree().create_timer(0.5).timeout
	particles.queue_free()


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D):
	_use(trans)
