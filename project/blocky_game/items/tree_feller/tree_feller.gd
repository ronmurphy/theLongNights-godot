extends "../item.gd"
## Tree Feller - Heavy axe weapon with cleaving slash
## Slower than sword but deals massive damage
## Can hit multiple targets in arc

const SERVER_PEER_ID = 1
const Meteor = preload("../../projectiles/meteor.gd")

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")

const MAX_TARGET_DISTANCE = 4.0  # Medium range
const DAMAGE = 35  # Highest melee damage
const ATTACK_SPEED = 1.0  # Slowest attack speed
const CLEAVE_ANGLE = 45.0  # Wide attack arc


func get_mining_power() -> int:
	return DAMAGE  # Best for mining (especially wood)


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

	# FIRST: Check for push_block ENTITIES in arc (already spawned blocks)
	var target_blocks = _find_push_blocks_in_arc(origin, direction)
	if target_blocks.size() > 0:
		# Found push_block entities - push them all!
		for block in target_blocks:
			_cleave_push_block(block, origin, direction)
		print("Tree Feller cleaved %d push_blocks!" % target_blocks.size())
		return

	# SECOND: Check for push_block VOXELS in direct line (not yet spawned)
	if await _check_and_push_voxel(origin, direction):
		return  # Hit a push_block voxel, spawned and pushed it, done!

	# THIRD: Find enemy entities in cleave arc
	var target_entities = _find_targets_in_arc(origin, direction)

	if target_entities.size() > 0:
		# Hit all entities in arc
		for entity in target_entities:
			_cleave_attack(entity, origin, inv_item_or_count)

		# ⚡ SKYSHARD POWER: Wind Dash (activate once if any enemy hit)
		if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.has_power("wind_dash"):
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_method("activate_wind_dash"):
				player.activate_wind_dash()
	else:
		# Slash at air (show slash effect) - very close to player for narrower appearance
		var slash_pos = origin + direction * 0.6
		_spawn_slash_effect(slash_pos, direction)

	print("Tree Feller cleave! Hit %d targets | Stack bonus: +%d damage" % [target_entities.size(), stack_count])


func _find_targets_in_arc(origin: Vector3, direction: Vector3) -> Array:
	var targets = []
	var entities = get_tree().get_nodes_in_group("entities")

	for entity in entities:
		if not entity.is_alive:
			continue

		# Only attack enemies
		if entity.team != EntityBase.Team.ENEMY:
			continue

		# Check if entity is in range
		var to_entity = entity.global_position - origin
		var distance = to_entity.length()

		if distance > MAX_TARGET_DISTANCE:
			continue

		# Check if entity is in wide cleave arc
		var angle = direction.angle_to(to_entity.normalized())
		if angle <= deg_to_rad(CLEAVE_ANGLE / 2.0):  # Half angle on each side
			targets.append(entity)

	return targets


func _find_push_blocks_in_arc(origin: Vector3, direction: Vector3) -> Array:
	"""Find all push_blocks in the cleave arc"""
	var targets = []
	var push_blocks = get_tree().get_nodes_in_group("push_blocks")

	for block in push_blocks:
		if not is_instance_valid(block):
			continue

		# Check if block is in range
		var to_block = block.global_position - origin
		var distance = to_block.length()

		if distance > MAX_TARGET_DISTANCE:
			continue

		# Check if block is in wide cleave arc
		var angle = direction.angle_to(to_block.normalized())
		if angle <= deg_to_rad(CLEAVE_ANGLE / 2.0):  # Half angle on each side
			targets.append(block)

	return targets


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
			_cleave_push_block(push_block, origin, direction)
			return true

	return false


func _cleave_push_block(block: Node, attacker_pos: Vector3, direction: Vector3):
	"""Push a block with the tree feller's heavy chopping force"""
	# Calculate push direction (slightly upward arc from the chop)
	var push_dir = (block.global_position - attacker_pos).normalized()
	push_dir.y = 0.3  # Moderate upward arc from chopping motion

	# Tree Feller is 2nd strongest melee weapon (7.5 force)
	var impulse = push_dir * 7.5

	if block.has_method("apply_impulse"):
		block.apply_impulse(impulse)
		print("🪓 Tree Feller CHOPPED push_block! (7.5 force)")

	# Spawn slash effect at block
	_spawn_slash_effect(block.global_position, push_dir)


func _cleave_attack(entity: Node, attacker_pos: Vector3, inv_item_or_count):
	var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count

	# Deal damage with stack bonus
	var total_damage = DAMAGE + stack_count
	entity.take_damage(total_damage, self)

	# Spawn slash effect at entity position
	_spawn_slash_effect(entity.global_position, (entity.global_position - attacker_pos).normalized())

	print("Tree Feller hit %s for %d damage! (base: %d + stack: %d)" % [entity.entity_name, total_damage, DAMAGE, stack_count])

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


func _spawn_slash_effect(pos: Vector3, direction: Vector3):
	# Spawn spatial slash effect using the new system (replaces old canvas-warped effect)
	SlashEffectSpawner.spawn_slash(
		get_node("/root/Main/Game"),
		pos,  # Already at correct height from camera/entity position
		direction,
		Color(0.6, 0.8, 0.4, 1.0),  # Green/woodsy slash
		0.33,  # Duration (longest, heavy weapon)
		9.0,   # Intensity (brightest)
		3.5,   # Speed (slower for heavy feel)
		3.5,   # Scale (largest slash for heavy weapon)
		"res://assets/art/textures/slash_04.png"  # Tree Feller uses slash_04
	)

@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, stack_count: int = 1):
	_use(trans, stack_count)
