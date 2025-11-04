extends "../item.gd"

const SERVER_PEER_ID = 1
const Meteor = preload("../../projectiles/meteor.gd")

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")
@onready var _projectiles_container : Node = get_node("/root/Main/Game")

const MAX_TARGET_DISTANCE = 100.0
const SKY_HEIGHT = 50.0  # How high above target the meteor spawns


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

	# Raycast to find target position on ground
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

	# Spawn meteor high in the sky above the target
	var sky_pos = Vector3(target_pos.x, target_pos.y + SKY_HEIGHT, target_pos.z)
	_spawn_meteor(sky_pos, target_pos, stack_count, inv_item_or_count)


func _spawn_meteor(sky_pos: Vector3, target_pos: Vector3, stack_count: int, inv_item_or_count = null):
	var meteor = Node3D.new()
	meteor.set_script(Meteor)

	# Add to game scene
	_projectiles_container.add_child(meteor)

	# Initialize after adding to tree
	meteor.initialize(sky_pos, target_pos, stack_count, get_parent(), inv_item_or_count)

	print("Fire staff: Meteor strike called down at ", target_pos, " | Stack bonus: +", stack_count, " damage")


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, stack_count: int = 1):
	_use(trans, stack_count)
