extends "../item.gd"

const SERVER_PEER_ID = 1
const FlyingOrbProjectile = preload("flying_orb_projectile.gd")
const InventoryItem = preload("../../player/inventory_item.gd")

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")
@onready var _world_container : Node = get_node("/root/Main/Game")

const MAX_TARGET_DISTANCE = 50.0


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

	if hit != null:
		# Launch flying orb to the block surface
		var placement_pos = Vector3(hit.position) + Vector3(0.5, 0.5, 0.5)
		_launch_orb(origin, placement_pos)
		print("Light orb launched to: ", placement_pos)
	else:
		print("No valid placement location found")


func _launch_orb(start_pos: Vector3, target_pos: Vector3):
	"""Launch a flying orb projectile with visual effects"""
	var projectile = Node3D.new()
	projectile.set_script(FlyingOrbProjectile)

	# Add to game scene
	_world_container.add_child(projectile)

	# Initialize after adding to tree
	projectile.initialize(start_pos, target_pos, _world_container)

	print("Flying Light Orb launched!")


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, stack_count: int = 1):
	_use(trans, stack_count)
