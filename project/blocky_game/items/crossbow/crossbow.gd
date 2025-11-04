extends "../item.gd"
## Crossbow - Ranged weapon that fires arrows
## Used by elf companions

const SERVER_PEER_ID = 1
const Arrow = preload("../../projectiles/arrow.gd")
const Meteor = preload("../../projectiles/meteor.gd")
const EntityBase = preload("../../entities/entity_base.gd")

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")
@onready var _projectiles_container : Node = get_node("/root/Main/Game")

const MAX_TARGET_DISTANCE = 80.0  # Ranged weapon
const ARROW_DAMAGE = 15


func use(trans: Transform3D, inv_item_or_count = 1):
	var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_use", trans, stack_count)
	else:
		_use(trans, stack_count, inv_item_or_count)


func _use(trans: Transform3D, stack_count: int = 1, inv_item_or_count = 1):
	var origin = trans.origin
	var direction = -trans.basis.z.normalized()

	# Raycast to find target position
	var terrain_tool = _terrain.get_voxel_tool()
	terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE
	var hit = terrain_tool.raycast(origin, direction, MAX_TARGET_DISTANCE)

	var target_pos : Vector3
	if hit != null:
		# Target the block that was hit
		target_pos = Vector3(hit.position) + Vector3(0.5, 0.5, 0.5)
	else:
		# No block hit, target far away in that direction
		target_pos = origin + direction * MAX_TARGET_DISTANCE

	# Spawn arrow projectile with stack bonus
	_spawn_arrow(origin, target_pos, direction, stack_count, inv_item_or_count)


func _spawn_arrow(start_pos: Vector3, target_pos: Vector3, initial_dir: Vector3, stack_count: int, inv_item_or_count = 1):
	var arrow = Node3D.new()
	arrow.set_script(Arrow)

	# Add to game scene so it persists
	_projectiles_container.add_child(arrow)

	# Initialize after adding to tree (pass self as owner for damage tracking)
	arrow.initialize(start_pos, target_pos, initial_dir, get_parent(), stack_count, inv_item_or_count)

	print("Crossbow fired! Stack bonus: +", stack_count, " damage")


func spawn_meteor_for_arrow(entity_position: Vector3, stack_count: int):
	"""Called by arrow when it hits an entity with meteor_strike power"""
	var target_pos = entity_position
	var sky_pos = Vector3(target_pos.x, target_pos.y + 50.0, target_pos.z)
	_spawn_meteor(sky_pos, target_pos, stack_count)


func _spawn_meteor(sky_pos: Vector3, target_pos: Vector3, stack_count: int):
	"""Spawn meteor projectile from sky to target"""
	var meteor = Node3D.new()
	meteor.set_script(Meteor)
	_projectiles_container.add_child(meteor)
	
	if meteor.has_method("initialize"):
		meteor.initialize(sky_pos, target_pos, stack_count)
		print("☄️ Meteor Strike! Meteor spawned for crossbow bolt")
	else:
		print("ERROR: Meteor has no initialize method!")


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, stack_count: int = 1):
	_use(trans, stack_count)
