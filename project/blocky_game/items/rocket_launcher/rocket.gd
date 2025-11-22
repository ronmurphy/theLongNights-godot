extends Node3D

const LIFETIME = 10.0

const DebrisScene = preload("./debris.tscn")
const ExplosionScene = preload("./rocket_explosion.tscn")
const InteractionCommon = preload("res://blocky_game/player/interaction_common.gd")

@onready var _terrain : VoxelTerrain = get_node("../VoxelTerrain")
@onready var _terrain_tool := _terrain.get_voxel_tool()

var _direction := Vector3(0, 0, 1)
var _speed := 20.0
var _remaining_time := LIFETIME
var stack_bonus := 0  # Damage bonus from stacked rocket launchers


func set_direction(direction: Vector3):
	assert(is_inside_tree())
	direction += Vector3(0.0001, 0.0001, 0.001) # Haaaaak
	_direction = direction.normalized()
	look_at(global_transform.origin + _direction, Vector3(0, 1, 0))


func _physics_process(delta: float):
	_remaining_time -= delta
	if _remaining_time <= 0:
		# Spent too long not hitting anything
		queue_free()
		return
	
	var trans = global_transform
	var crossed_distance := _speed * delta
	var motion := crossed_distance * _direction
	
	var hit = _terrain_tool.raycast(trans.origin, _direction, crossed_distance)
	if hit != null:
		# Check if we hit a push_block - push it WITHOUT exploding
		if _is_push_block_voxel(Vector3(hit.position)):
			_push_block_without_exploding(Vector3(hit.position))
		else:
			# Normal explosion
			_explode(hit.position, trans.origin)
	else:
		trans.origin += motion
		global_transform = trans


func _explode(voxel_hit_pos: Vector3, explosion_pos: Vector3):
	var mp := get_tree().get_multiplayer()
	var total_damage = 25 + stack_bonus  # Base rocket damage + stack bonus
	if mp.has_multiplayer_peer():
		if mp.is_server():
			_do_sphere_safe(voxel_hit_pos, 4.0)
			_damage_nearby_entities(explosion_pos, 6.0, total_damage)  # 6 block radius, damage with stack bonus
			_push_nearby_blocks(explosion_pos, 6.0)  # Push blocks in 6 block radius
			rpc(&"receive_explode", explosion_pos)
			_create_explosion_vfx(explosion_pos)
			queue_free()
		# Else, clients don't do anything. Clients could rely on their local copy of the terrain
		# to find when the collision occurs, but it can lead to false positives if terrain is synced
		# out of order, so it's more reliable to explicitely be told when to play the explosion
	else:
		_do_sphere_safe(voxel_hit_pos, 4.0)
		_damage_nearby_entities(explosion_pos, 6.0, total_damage)  # 6 block radius, damage with stack bonus
		_push_nearby_blocks(explosion_pos, 6.0)  # Push blocks in 6 block radius
		_create_explosion_vfx(explosion_pos)
		queue_free()


func _do_sphere_safe(center: Vector3, radius: float):
	"""Destroy blocks in sphere with universal bedrock protection"""
	var r_int = int(ceil(radius))

	# Iterate through all positions in bounding box
	for y in range(-r_int, r_int + 1):
		for z in range(-r_int, r_int + 1):
			for x in range(-r_int, r_int + 1):
				var pos = center + Vector3(x, y, z)
				var dist = pos.distance_to(center)

				# If position is within sphere radius
				if dist <= radius:
					# Check what block is there
					var voxel_id = _terrain_tool.get_voxel(pos)

					# Only destroy if it's not air
					if voxel_id != 0:
						# Use safe_set_voxel - automatically protects bedrock
						InteractionCommon.safe_set_voxel(_terrain_tool, pos, 0)  # 0 = air


@rpc("authority", "call_remote", "reliable", 0)
func receive_explode(pos: Vector3):
	_create_explosion_vfx(pos)
	queue_free()


func _create_explosion_vfx(explosion_pos: Vector3):
	# VFX are not created as children of the rocket because it gets destroyed shortly after.

	var explosion = ExplosionScene.instantiate()
	explosion.position = explosion_pos
	# Note: Damage is already handled in _explode() with stack bonus
	get_parent().add_child(explosion)
	
	# Create debris (respecting graphics settings)
	var debris_count = GraphicsSettings.get_debris_count()
	for i in debris_count:
		var debris = DebrisScene.instantiate()
		var debris_velocity := \
			Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		debris_velocity *= randf_range(5.0, 30.0)
		debris.set_velocity(debris_velocity)
		debris.position = explosion_pos
		get_parent().add_child(debris)


## Damage all entities within radius of explosion
func _damage_nearby_entities(center: Vector3, radius: float, damage: int) -> void:
	# Get all entities in the scene
	var entities = get_tree().get_nodes_in_group("entities")

	for entity in entities:
		if not entity is EntityBase:
			continue

		# Skip friendly entities (don't damage player's companions)
		if entity.team == EntityBase.Team.PLAYER:
			continue

		# Check distance
		var distance = entity.global_position.distance_to(center)
		if distance <= radius:
			# Apply damage (could scale with distance)
			var scaled_damage = int(damage * (1.0 - (distance / radius)))
			entity.take_damage(scaled_damage, self)


func _is_push_block_voxel(voxel_pos: Vector3) -> bool:
	"""Check if the voxel at this position is a push_block"""
	var voxel_id = _terrain_tool.get_voxel(voxel_pos)
	if voxel_id == 0:
		return false

	# Get block type
	var blocks_node = get_node_or_null("/root/Main/Game/Blocks")
	if not blocks_node:
		return false

	var block = blocks_node.get_block(voxel_id)
	return block and block.base_info.name == "push_block"


func _push_block_without_exploding(voxel_pos: Vector3):
	"""Push a push_block without exploding (preserve puzzle room)"""
	# Find existing push block entity at this position
	var push_blocks = get_tree().get_nodes_in_group("push_blocks")
	var block_entity = null

	for block in push_blocks:
		if not is_instance_valid(block):
			continue

		# Check if entity is at this voxel position
		var entity_voxel_pos = Vector3i(
			int(floor(block.global_position.x + 0.5)),
			int(floor(block.global_position.y + 0.5)),
			int(floor(block.global_position.z + 0.5))
		)

		if entity_voxel_pos == Vector3i(voxel_pos):
			block_entity = block
			break

	# If no entity exists, try to spawn one
	if not block_entity:
		var manager = get_node_or_null("/root/PushBlockManager")
		if manager and manager.has_method("create_push_block_at"):
			manager.create_push_block_at(Vector3i(voxel_pos))

	# Push the block if we found it (or wait for next rocket)
	if block_entity and block_entity.has_method("apply_impulse"):
		# Strong push from rocket impact (no explosion)
		var impulse = _direction * 8.0  # Very strong push
		block_entity.apply_impulse(impulse)
		print("🚀 Rocket pushed block without exploding!")

	# Destroy rocket without explosion
	queue_free()


## Push all push blocks within radius away from explosion
func _push_nearby_blocks(center: Vector3, radius: float) -> void:
	var push_blocks = get_tree().get_nodes_in_group("push_blocks")

	for block in push_blocks:
		if not is_instance_valid(block):
			continue

		# Check distance
		var distance = block.global_position.distance_to(center)
		if distance <= radius:
			# Calculate push direction (away from explosion center)
			var push_direction = (block.global_position - center).normalized()

			# Scale force by distance (closer = stronger push)
			var force_multiplier = (1.0 - (distance / radius)) * 10.0  # Strong explosive force
			var impulse = push_direction * force_multiplier

			if block.has_method("apply_impulse"):
				block.apply_impulse(impulse)
				print("💥 Rocket explosion pushed block!")

