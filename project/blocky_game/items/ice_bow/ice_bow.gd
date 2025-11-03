extends "../item.gd"

const SERVER_PEER_ID = 1
const IceArrow = preload("../../projectiles/ice_arrow.gd")

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")
@onready var _projectiles_container : Node = get_node("/root/Main/Game")

const MAX_TARGET_DISTANCE = 100.0  # How far to raycast for target


func use(trans: Transform3D, stack_count: int = 1):
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

	# Spawn ice arrow projectile with stack damage bonus
	_spawn_ice_arrow(origin, target_pos, direction, stack_count)


func _spawn_ice_arrow(start_pos: Vector3, target_pos: Vector3, initial_dir: Vector3, stack_count: int):
	var arrow = Node3D.new()
	arrow.set_script(IceArrow)

	# Add to game scene so it persists
	_projectiles_container.add_child(arrow)

	# Initialize after adding to tree with stack bonus
	arrow.initialize(start_pos, target_pos, initial_dir, stack_count)

	print("Ice bow fired! Target: ", target_pos, " | Stack bonus: +", stack_count, " damage")


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, stack_count: int = 1):
	_use(trans, stack_count)
