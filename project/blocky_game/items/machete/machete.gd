extends "../item.gd"
## Machete - Fast melee weapon with slash attack
## Used by human companions
## Deals single-target damage with quick attack speed

const SERVER_PEER_ID = 1
const Meteor = preload("../../projectiles/meteor.gd")

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")

const MAX_TARGET_DISTANCE = 4.0  # Medium melee range
const DAMAGE = 20  # Higher single-target damage than hammer
const ATTACK_SPEED = 0.5  # Fast attack (cooldown in seconds)


func get_mining_power() -> int:
	return DAMAGE  # Decent for mining


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

	# FIRST: Check for push_block voxels (before mining can happen!)
	if await _check_and_push_voxel(origin, direction):
		return  # Hit a push_block voxel, pushed it, done!

	# Find target entity with raycast
	var target_entity = _find_target_entity(origin, direction)

	# Find push_block entity with raycast
	var target_block = _find_target_push_block(origin, direction)

	if target_entity:
		# Direct hit on entity
		_slash_attack(target_entity, origin, inv_item_or_count)
	elif target_block:
		# Direct hit on push_block entity
		_slash_push_block(target_block, origin, direction)
	else:
		# Slash at air (show slash effect) - very close to player for narrower appearance
		var slash_pos = origin + direction * 0.6
		_spawn_slash_effect(slash_pos, direction)

	print("Machete slash! Stack bonus: +", stack_count, " damage")


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


func _find_target_push_block(origin: Vector3, direction: Vector3) -> Node:
	"""Find push_blocks in melee range"""
	var push_blocks = get_tree().get_nodes_in_group("push_blocks")
	var closest_block = null
	var closest_distance = MAX_TARGET_DISTANCE

	for block in push_blocks:
		if not is_instance_valid(block):
			continue

		# Check if block is roughly in front of player
		var to_block = block.global_position - origin
		var distance = to_block.length()

		if distance > MAX_TARGET_DISTANCE:
			continue

		# Check if block is in attack cone (60 degree arc)
		var angle = direction.angle_to(to_block.normalized())
		if angle > deg_to_rad(30):  # 30 degrees each side = 60 degree cone
			continue

		if distance < closest_distance:
			closest_distance = distance
			closest_block = block

	return closest_block


func _check_and_push_voxel(origin: Vector3, direction: Vector3) -> bool:
	"""Check if we're hitting a push_block voxel and push it. Returns true if we hit one."""
	if not _terrain:
		return false

	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	# Raycast to find what we're hitting
	var hit = vt.raycast(origin, direction, MAX_TARGET_DISTANCE)
	if not hit:
		return false

	var hit_pos = Vector3(hit.position)

	# Check if it's a push_block voxel
	var voxel_coord = Vector3i(
		int(floor(hit_pos.x)),
		int(floor(hit_pos.y)),
		int(floor(hit_pos.z))
	)
	var voxel_id = vt.get_voxel(voxel_coord)
	if voxel_id == 0:
		return false

	# Check if this voxel is a push_block
	var blocks_node = get_node_or_null("/root/Main/Game/Blocks")
	if not blocks_node:
		return false

	var raw_mapping = blocks_node.get_raw_mapping(voxel_id)
	if not raw_mapping:
		return false

	var block = blocks_node.get_block(raw_mapping.block_id)
	if not block or block.base_info.name != "push_block":
		return false

	# It's a push_block! Spawn entity and push it
	var manager = get_node_or_null("/root/Main/Game/PushBlockManager")
	if not manager or not manager.has_method("create_push_block_at"):
		return false

	manager.create_push_block_at(voxel_coord)

	# Wait a frame for entity to spawn, then push it
	await get_tree().process_frame

	# Find the spawned entity
	var push_blocks = get_tree().get_nodes_in_group("push_blocks")
	for push_block in push_blocks:
		if not is_instance_valid(push_block):
			continue

		var block_voxel_pos = Vector3i(
			int(floor(push_block.global_position.x)),
			int(floor(push_block.global_position.y)),
			int(floor(push_block.global_position.z))
		)

		if block_voxel_pos == voxel_coord:
			# Found it! Push it
			_slash_push_block(push_block, origin, direction)
			return true

	return false


func _slash_push_block(block: Node, attacker_pos: Vector3, direction: Vector3):
	"""Slash attack that pushes a block"""
	# Machete slash with moderate upward force
	var push_dir = direction
	push_dir.y = 0.2  # Moderate upward arc from slash

	# Machete is medium power (4.0 force)
	var impulse = push_dir * 4.0

	if block.has_method("apply_impulse"):
		block.apply_impulse(impulse)
		print("🔪 Machete SLASHED push_block! (4.0 force)")

	# Spawn slash effect at block
	_spawn_slash_effect(block.global_position, push_dir)


func _slash_attack(entity: Node, attacker_pos: Vector3, inv_item_or_count):
	var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count

	# Deal damage with stack bonus
	var total_damage = DAMAGE + stack_count
	entity.take_damage(total_damage, self)

	# Spawn slash effect at entity position
	_spawn_slash_effect(entity.global_position, (entity.global_position - attacker_pos).normalized())

	print("Machete hit %s for %d damage!" % [entity.entity_name, total_damage])

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

	# ⚡ SKYSHARD POWER: Wind Dash
	if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.has_power("wind_dash"):
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("activate_wind_dash"):
			player.activate_wind_dash()

	# ⚡ SKYSHARD POWER: Lightning Chain
	if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.has_power("lightning_chain"):
		_lightning_chain(entity.global_position, int(total_damage * 0.5), entity)


func _spawn_slash_effect(pos: Vector3, direction: Vector3):
	# Spawn spatial slash effect using the new system (replaces old canvas-warped effect)
	SlashEffectSpawner.spawn_slash(
		get_node("/root/Main/Game"),
		pos,  # Already at correct height from camera/entity position
		direction,
		Color(0.8, 0.9, 1.0, 1.0),  # Light blue/white slash
		0.25,  # Duration (faster than sword)
		7.0,   # Intensity
		5.0,   # Speed (fast animation)
		2.5,   # Scale (large for visibility)
		"res://assets/art/textures/slash_02.png"  # Machete uses slash_02
	)


func _lightning_chain(origin: Vector3, chain_damage: int, primary_target: Node):
	"""Chain lightning damage to nearby enemies"""
	const CHAIN_RADIUS = 5.0
	const MAX_CHAINS = 3

	var entities = get_tree().get_nodes_in_group("entities")
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
			print("⚡ Lightning chained to %s for %d damage!" % [entity.entity_name, chain_damage])

	if chained > 0:
		print("⚡ Lightning Chain! Hit %d additional enemies" % chained)


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, stack_count: int = 1):
	_use(trans, stack_count)
