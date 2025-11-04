extends "../item.gd"

const SERVER_PEER_ID = 1
const ThrowingKnife = preload("../../projectiles/throwing_knife.gd")

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")
@onready var _projectiles_container : Node = get_node("/root/Main/Game")

const MAX_TARGET_DISTANCE = 100.0


func use(trans: Transform3D, inv_item_or_count = 1):
	var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_use", trans, stack_count)
	else:
		_use(trans, stack_count)


func _use(trans: Transform3D, stack_count: int = 1):
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

	# Spawn throwing knife projectile with stack bonus
	_spawn_throwing_knife(origin, target_pos, stack_count)


func _spawn_throwing_knife(start_pos: Vector3, target_pos: Vector3, stack_count: int):
	var knife = Node3D.new()
	knife.set_script(ThrowingKnife)

	# Add to game scene
	_projectiles_container.add_child(knife)

	# Initialize after adding to tree
	knife.initialize(start_pos, target_pos, stack_count)

	print("Throwing knife launched! Target: ", target_pos, " | Stack bonus: +", stack_count, " damage")


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, stack_count: int = 1):
	_use(trans, stack_count)
