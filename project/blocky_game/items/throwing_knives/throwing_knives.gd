extends "../item.gd"

const SERVER_PEER_ID = 1
const ThrowingKnife = preload("../../projectiles/throwing_knife.gd")

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")
@onready var _projectiles_container : Node = get_node("/root/Main/Game")

const MAX_TARGET_DISTANCE = 100.0


func use(trans: Transform3D):
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_use", trans)
	else:
		_use(trans)


func _use(trans: Transform3D):
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

	# Spawn throwing knife projectile
	_spawn_throwing_knife(origin, target_pos)


func _spawn_throwing_knife(start_pos: Vector3, target_pos: Vector3):
	var knife = Node3D.new()
	knife.set_script(ThrowingKnife)

	# Add to game scene
	_projectiles_container.add_child(knife)

	# Initialize after adding to tree
	knife.initialize(start_pos, target_pos)

	print("Throwing knife launched! Target: ", target_pos)


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D):
	_use(trans)
