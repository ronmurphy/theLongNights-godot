extends "../item.gd"

const SERVER_PEER_ID = 1
const ThrownTorch = preload("../../projectiles/thrown_torch.gd")
const InventoryItem = preload("../../player/inventory_item.gd")

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")
@onready var _projectiles_container : Node = get_node("/root/Main/Game")

const MAX_TARGET_DISTANCE = 50.0


func use(trans: Transform3D):
	# Check if we have torches to throw
	var inventory = get_node_or_null("/root/Main/Game/Avatar/Head/Inventory")
	if inventory == null:
		return

	# Find the torch in inventory
	var torch_slot_idx = -1
	for i in range(inventory._slots.size()):
		var slot_item = inventory._slots[i]
		if slot_item != null and slot_item.type == InventoryItem.TYPE_ITEM and slot_item.id == 6:
			torch_slot_idx = i
			break

	if torch_slot_idx == -1:
		print("No torches in inventory!")
		return

	var torch_item = inventory._slots[torch_slot_idx]

	# Throw the torch
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_use", trans)
	else:
		_use(trans)

	# Decrement count (torches are consumable)
	torch_item.count -= 1
	if torch_item.count <= 0:
		# Remove from inventory
		inventory._slots[torch_slot_idx] = null

	# Update display
	inventory._update_views()


func _use(trans: Transform3D):
	var origin = trans.origin
	var direction = -trans.basis.z.normalized()

	# Raycast to find target position
	var terrain_tool = _terrain.get_voxel_tool()
	terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE
	var hit = terrain_tool.raycast(origin, direction, MAX_TARGET_DISTANCE)

	var target_pos : Vector3
	if hit != null:
		# Target where we're looking
		target_pos = Vector3(hit.position) + Vector3(0.5, 0.5, 0.5)
	else:
		# No block hit, throw far in that direction
		target_pos = origin + direction * MAX_TARGET_DISTANCE

	# Throw torch
	_throw_torch(origin, target_pos)


func _throw_torch(start_pos: Vector3, target_pos: Vector3):
	var torch = Node3D.new()
	torch.set_script(ThrownTorch)

	# Add to game scene
	_projectiles_container.add_child(torch)

	# Initialize after adding to tree
	torch.initialize(start_pos, target_pos, 15.0)

	print("Torch thrown! Target: ", target_pos)


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D):
	_use(trans)
