extends "../item.gd"

const SERVER_PEER_ID = 1

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")
@onready var _player_container : Node = get_node("/root/Main/Game/Players")

# Grappling hook settings
const GRAPPLE_MAX_DISTANCE = 50.0
const PULL_SPEED = 20.0
const ROPE_COLOR = Color(0.6, 0.4, 0.2)  # Brown rope


func use(trans: Transform3D, stack_count: int = 1):
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_use", trans, stack_count)
	else:
		_use(trans, stack_count)


func _use(trans: Transform3D, stack_count: int = 1):
	var origin = trans.origin
	var direction = -trans.basis.z.normalized()

	# Raycast to find hit point
	var terrain_tool = _terrain.get_voxel_tool()
	terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE
	var hit = terrain_tool.raycast(origin, direction, GRAPPLE_MAX_DISTANCE)

	if hit != null:
		# Found a voxel to grapple to!
		var target_pos = Vector3(hit.position) + Vector3(0.5, 0.5, 0.5)  # Center of block
		_grapple_to_position(origin, target_pos)


func _grapple_to_position(start_pos: Vector3, target_pos: Vector3):
	# Find the local player
	var mp := get_tree().get_multiplayer()
	var peer_id = 1  # Default for singleplayer

	if mp.has_multiplayer_peer():
		if mp.is_server():
			peer_id = 1
		else:
			peer_id = mp.get_unique_id()

	var player = _player_container.get_node_or_null(str(peer_id))
	if player == null:
		print("Grappling hook: Could not find player")
		return

	# Calculate arc trajectory
	# We need to solve for initial velocity to create a parabolic arc
	var horizontal_distance = Vector3(target_pos.x - start_pos.x, 0, target_pos.z - start_pos.z).length()
	var vertical_distance = target_pos.y - start_pos.y

	# Time to reach target (based on horizontal speed)
	var flight_time = horizontal_distance / PULL_SPEED

	# Calculate required upward velocity to create an arc
	# Using physics: vertical_distance = v_y * t - 0.5 * g * t^2
	# Solve for v_y: v_y = (vertical_distance + 0.5 * g * t^2) / t
	var gravity = 9.8  # Match character controller gravity
	var arc_height_bonus = 3.0  # Extra height for the arc
	var required_y_velocity = (vertical_distance + arc_height_bonus + 0.5 * gravity * flight_time * flight_time) / flight_time

	# Horizontal velocity (towards target)
	var horizontal_direction = Vector3(target_pos.x - start_pos.x, 0, target_pos.z - start_pos.z).normalized()
	var horizontal_velocity = horizontal_direction * PULL_SPEED

	# Combine horizontal and vertical velocity
	var launch_velocity = Vector3(horizontal_velocity.x, required_y_velocity, horizontal_velocity.z)

	# Call the character controller's start_grapple method
	if player.has_method("start_grapple"):
		player.start_grapple(launch_velocity, flight_time)
		print("Grappling to ", target_pos, " from ", start_pos)
		print("  Flight time: ", flight_time, "s, Launch velocity: ", launch_velocity)
	else:
		print("Grappling hook: Player does not have start_grapple method")


func _draw_grapple_rope(start_pos: Vector3, end_pos: Vector3):
	# Create a temporary line to show the rope
	# This will be a simple visual effect using ImmediateMesh
	# For now, just print - we can add visuals later if needed
	print("Rope from ", start_pos, " to ", end_pos)


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, stack_count: int = 1):
	_use(trans, stack_count)
