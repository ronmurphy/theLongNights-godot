extends "../item.gd"
## Spear - Hybrid melee and ranged weapon
## Left-click/Melee: 3-block melee range thrust attack
## Right-click/Throw: Throw spear with parabolic arc (sticks on impact)
## Deals damage and supports skyshard powers
## Works with both player and companions

const SERVER_PEER_ID = 1
const SpearProjectile = preload("../../projectiles/spear_projectile.gd")
const EntityBase = preload("../../entities/entity_base.gd")

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")
@onready var _projectiles_container : Node = get_node("/root/Main/Game")

const MELEE_RANGE = 3.0  # 3-block melee range
const THROW_RANGE = 50.0  # Maximum throw distance
const MELEE_DAMAGE = 25  # Melee thrust damage
const THROW_DAMAGE = 20  # Projectile damage
const ATTACK_SPEED = 0.6  # Slightly slower than sword


func get_mining_power() -> int:
	return MELEE_DAMAGE  # Can mine with melee


func use(trans: Transform3D, inv_item_or_count = 1):
	# Default to melee for companions and normal use
	var action = "melee"
	var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_use", trans, stack_count, action)
	else:
		_use(trans, inv_item_or_count, action)


func set_throw_action() -> void:
	"""Called by avatar_interaction to indicate this should be a throw attack"""
	# This is used when right-click is pressed
	pass  # The next use() call will handle it


func use_throw(trans: Transform3D, inv_item_or_count = 1):
	"""Called specifically for throw attacks (right-click)"""
	var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_use", trans, stack_count, "throw")
	else:
		_use(trans, inv_item_or_count, "throw")


func _use(trans: Transform3D, inv_item_or_count, action: String = "melee"):
	var origin = trans.origin
	var direction = -trans.basis.z.normalized()
	var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count

	if action == "throw":
		_use_throw(origin, direction, stack_count, inv_item_or_count)
	else:
		_use_melee(origin, direction, stack_count, inv_item_or_count)


func _use_melee(origin: Vector3, direction: Vector3, stack_count: int, inv_item_or_count):
	"""Melee thrust attack with 3-block range"""
	# FIRST: Check for push_block voxels (before mining can happen!)
	if await _check_and_push_voxel(origin, direction):
		return  # Hit a push_block voxel, pushed it, done!

	# Find target entity with raycast
	var target_entity = _find_target_entity(origin, direction)

	# Find push_block with raycast
	var target_block = _find_target_push_block(origin, direction)

	if target_entity:
		# Direct hit on entity
		_thrust_attack(target_entity, origin, inv_item_or_count)
	elif target_block:
		# Direct hit on push_block
		_thrust_push_block(target_block, origin, direction)
	else:
		# Thrust at air (show thrust effect) - very close to player for narrower appearance
		var thrust_pos = origin + direction * 0.6
		_spawn_thrust_effect(thrust_pos, direction)

	print("Spear thrust! Stack bonus: +", stack_count, " damage")


func _use_throw(origin: Vector3, direction: Vector3, stack_count: int, inv_item_or_count):
	"""Throw spear with parabolic arc"""
	# Raycast to find target position
	var terrain_tool = _terrain.get_voxel_tool()
	terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE
	var hit = terrain_tool.raycast(origin, direction, THROW_RANGE)

	var target_pos : Vector3
	if hit != null:
		# Target where we're looking
		target_pos = Vector3(hit.position) + Vector3(0.5, 0.5, 0.5)
	else:
		# No block hit, throw far in that direction
		target_pos = origin + direction * THROW_RANGE

	# Throw spear
	_throw_spear(origin, target_pos, inv_item_or_count)


func _find_target_entity(origin: Vector3, direction: Vector3) -> Node:
	"""Find entities in melee range (3 blocks)"""
	# Raycast to find entities in attack direction
	var space_state = get_tree().root.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * MELEE_RANGE
	)

	var result = space_state.intersect_ray(query)
	if result:
		return result.collider

	# If no physics hit, check entities manually
	var entities = get_tree().get_nodes_in_group("entities")
	var closest_entity = null
	var closest_distance = MELEE_RANGE

	for entity in entities:
		if not entity.is_alive:
			continue

		# Check if entity is roughly in front of player
		var to_entity = entity.global_position - origin
		var distance = to_entity.length()

		if distance > MELEE_RANGE:
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
	"""Find push_blocks in melee range (3 blocks)"""
	var push_blocks = get_tree().get_nodes_in_group("push_blocks")
	var closest_block = null
	var closest_distance = MELEE_RANGE

	for block in push_blocks:
		if not is_instance_valid(block):
			continue

		# Check if block is roughly in front of player
		var to_block = block.global_position - origin
		var distance = to_block.length()

		if distance > MELEE_RANGE:
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
	var hit = vt.raycast(origin, direction, MELEE_RANGE)
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
			_thrust_push_block(push_block, origin, direction)
			return true

	return false


func _thrust_push_block(block: Node, attacker_pos: Vector3, direction: Vector3):
	"""Thrust attack that pushes a block forward"""
	# Spear thrust is mostly horizontal with slight upward force
	var push_dir = direction
	push_dir.y = 0.2  # Slight upward arc from thrust

	# Spear melee is 3rd strongest (6.0 force)
	var impulse = push_dir * 6.0

	if block.has_method("apply_impulse"):
		block.apply_impulse(impulse)
		print("🗡️ Spear THRUST push_block forward! (6.0 force)")

	# Spawn thrust effect at block
	_spawn_thrust_effect(block.global_position, push_dir)


func _thrust_attack(entity: Node, attacker_pos: Vector3, inv_item_or_count):
	"""Melee thrust attack that deals damage"""
	var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count

	# Deal damage with stack bonus
	var total_damage = MELEE_DAMAGE + stack_count
	entity.take_damage(total_damage, self)

	# Spawn thrust effect at entity position
	_spawn_thrust_effect(entity.global_position, (entity.global_position - attacker_pos).normalized())

	print("Spear thrust hit %s for %d damage! (base: %d + stack: %d)" % [entity.entity_name, total_damage, MELEE_DAMAGE, stack_count])

	# ⚡ SKYSHARD POWERS
	if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.skyshard_power != "":
		var power_context = {
			"entity": entity,
			"position": entity.global_position,
			"stack_count": stack_count,
			"damage_dealt": total_damage,
			"attacker": get_tree().get_first_node_in_group("player")
		}
		Powers.execute_hotbar_power(inv_item_or_count.skyshard_power, power_context)


func _spawn_thrust_effect(pos: Vector3, direction: Vector3):
	"""Spawn spatial thrust effect using the new system (replaces old canvas-warped effect)"""
	SlashEffectSpawner.spawn_slash(
		get_node("/root/Main/Game"),
		pos,  # Already at correct height from camera/entity position
		direction,
		Color(0.8, 0.8, 1.0, 1.0),  # Icy blue for spear
		0.2,   # Duration (fastest)
		6.0,   # Intensity (slightly lower)
		6.0,   # Speed (fastest animation)
		2.0,   # Scale (medium size)
		"res://assets/art/textures/slash_03.png"  # Spear uses slash_03
	)


func _throw_spear(start_pos: Vector3, target_pos: Vector3, inv_item_or_count):
	"""Throw spear projectile"""
	var spear = Node3D.new()
	spear.set_script(SpearProjectile)

	# Add to game scene
	_projectiles_container.add_child(spear)

	# Initialize after adding to tree
	spear.initialize(start_pos, target_pos, inv_item_or_count, self)

	print("Spear thrown! Target: ", target_pos)


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, stack_count: int = 1, action: String = "melee"):
	_use(trans, stack_count, action)
