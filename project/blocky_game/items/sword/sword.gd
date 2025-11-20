extends "../item.gd"
## Sword - Balanced melee weapon with powerful slash attack
## Higher damage than machete, slightly slower
## Deals single-target damage with medium attack speed

const SERVER_PEER_ID = 1
const Meteor = preload("../../projectiles/meteor.gd")
const EntityBase = preload("../../entities/entity_base.gd")

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")

const MAX_TARGET_DISTANCE = 4.5  # Slightly longer reach than machete
const DAMAGE = 30  # Higher damage than machete
const ATTACK_SPEED = 0.75  # Slower than machete


func get_mining_power() -> int:
	return DAMAGE  # Good for mining


func use(trans: Transform3D, inv_item_or_count = 1):
	var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_use", trans, stack_count)
	else:
		_use(trans, inv_item_or_count)


func _use(trans: Transform3D, inv_item_or_count):
	var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count
	var origin = trans.origin
	var direction = -trans.basis.z.normalized()

	# Find target entity with raycast
	var target_entity = _find_target_entity(origin, direction)

	if target_entity:
		# Direct hit on entity
		_slash_attack(target_entity, origin, inv_item_or_count)
	else:
		# Slash at air (show slash effect) - very close to player for narrower appearance
		var slash_pos = origin + direction * 0.6
		_spawn_slash_effect(slash_pos, direction)

	print("Sword slash! Stack bonus: +", stack_count, " damage")


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


func _slash_attack(entity: Node, attacker_pos: Vector3, inv_item_or_count):
	var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count

	# Deal damage with stack bonus
	var total_damage = DAMAGE + stack_count
	entity.take_damage(total_damage, self)

	# Spawn slash effect at entity position
	_spawn_slash_effect(entity.global_position, (entity.global_position - attacker_pos).normalized())

	print("Sword hit %s for %d damage! (base: %d + stack: %d)" % [entity.entity_name, total_damage, DAMAGE, stack_count])

	# ⚡ SKYSHARD POWERS - Use centralized Powers system
	if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.skyshard_power != "":
		var power_context = {
			"entity": entity,
			"position": entity.global_position,
			"stack_count": stack_count,
			"damage_dealt": total_damage,
			"attacker": get_tree().get_first_node_in_group("player")
		}
		Powers.execute_hotbar_power(inv_item_or_count.skyshard_power, power_context)
	# ⚡ SKYSHARD POWER: Wind Dash
	if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.has_power("wind_dash"):
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("activate_wind_dash"):
			player.activate_wind_dash()


func _spawn_slash_effect(pos: Vector3, direction: Vector3):
	# Spawn spatial slash effect using the new system (replaces old canvas-warped effect)
	SlashEffectSpawner.spawn_slash(
		get_node("/root/Main/Game"),
		pos,  # Already at correct height from camera/entity position
		direction,
		Color(1.0, 0.9, 0.7, 1.0),  # Golden slash
		0.28,  # Duration
		8.0,   # Intensity (slightly brighter than default)
		4.0,   # Speed (controls animation rate)
		3.0,   # Scale (much larger for visibility)
		"res://assets/art/textures/slash_01.png"  # Sword uses slash_01
	)


func _lightning_chain(origin: Vector3, chain_damage: int, primary_target: Node):
	"""Chain lightning damage to nearby enemies"""
	const CHAIN_RADIUS = 5.0
	const MAX_CHAINS = 3

	print("DEBUG: Lightning Chain - origin:", origin, " damage:", chain_damage, " primary:", primary_target.entity_name if primary_target.has("entity_name") else "unknown")
	
	var entities = get_tree().get_nodes_in_group("entities")
	print("DEBUG: Found", entities.size(), "entities in scene")
	
	var chained = 0

	for entity in entities:
		if chained >= MAX_CHAINS:
			break

		# Skip if not alive, not enemy, or is the primary target
		if not entity.is_alive or entity.team != EntityBase.Team.ENEMY or entity == primary_target:
			continue

		# Check if within chain radius
		var distance = entity.global_position.distance_to(origin)
		if distance <= CHAIN_RADIUS:
			entity.take_damage(chain_damage, self)
			chained += 1
			print("⚡ Lightning chained to %s for %d damage (distance: %.1f)!" % [entity.entity_name, chain_damage, distance])

	if chained > 0:
		print("⚡ Lightning Chain! Hit %d additional enemies" % chained)
	else:
		print("DEBUG: Lightning Chain found no valid targets within %.1fm" % CHAIN_RADIUS)


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, stack_count: int = 1):
	_use(trans, stack_count)  # RPC always uses int for backward compat
