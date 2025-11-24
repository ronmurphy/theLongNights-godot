extends "../item.gd"

const SERVER_PEER_ID = 1

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")
@onready var _player_container : Node = get_node("/root/Main/Game/Players")

# Grappling hook settings
const GRAPPLE_MAX_DISTANCE = 50.0
const PULL_SPEED = 20.0
const CHAIN_COLOR = Color(0.7, 0.7, 0.8)  # Metallic silver chain
const CHAIN_SHOOT_SPEED = 80.0  # How fast the chain shoots out


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

	# Raycast to find hit point
	var terrain_tool = _terrain.get_voxel_tool()
	terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE
	var hit = terrain_tool.raycast(origin, direction, GRAPPLE_MAX_DISTANCE)

	if hit != null:
		# Found a voxel to grapple to!
		var target_pos = Vector3(hit.position) + Vector3(0.5, 0.5, 0.5)  # Center of block
		# Create visual grapple chain line
		var chain_line = _create_grapple_chain(origin, target_pos)
		_grapple_to_position(origin, target_pos, chain_line)


func _grapple_to_position(start_pos: Vector3, target_pos: Vector3, chain_line: Node3D):
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
		# Clean up chain line if player not found
		if chain_line:
			chain_line.queue_free()
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

	# Call the character controller's start_grapple method with chain line reference
	if player.has_method("start_grapple"):
		player.start_grapple(launch_velocity, flight_time, chain_line, target_pos)
		print("Grappling to ", target_pos, " from ", start_pos)
		print("  Flight time: ", flight_time, "s, Launch velocity: ", launch_velocity)
	else:
		print("Grappling hook: Player does not have start_grapple method")
		# Clean up chain line if method not found
		if chain_line:
			chain_line.queue_free()


func _create_grapple_chain(start_pos: Vector3, end_pos: Vector3) -> Node3D:
	"""
	Create a metallic chain line from start to end position
	Returns a Node3D that animates the chain shooting out
	"""
	var chain_container = Node3D.new()
	chain_container.name = "GrappleChain"

	# Calculate distance and direction
	var distance = start_pos.distance_to(end_pos)
	var direction = (end_pos - start_pos).normalized()

	# Create cylinder mesh for the chain
	var mesh_instance = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.03  # Thin chain (3cm diameter)
	cylinder.bottom_radius = 0.03
	cylinder.height = distance
	mesh_instance.mesh = cylinder

	# Create metallic material with chain-like appearance
	var material = StandardMaterial3D.new()
	material.albedo_color = CHAIN_COLOR
	material.metallic = 0.9  # Very metallic
	material.roughness = 0.3  # Slightly rough for realism
	material.emission_enabled = true
	material.emission = CHAIN_COLOR * 0.2  # Subtle glow
	material.emission_energy_multiplier = 0.5
	mesh_instance.material_override = material

	# Add nodes to tree FIRST before setting global properties
	chain_container.add_child(mesh_instance)

	# Add to scene (Game node)
	var game = get_node_or_null("/root/Main/Game")
	if game:
		game.add_child(chain_container)

	# NOW position and orient the cylinder (after it's in the tree)
	var midpoint = (start_pos + end_pos) / 2.0
	mesh_instance.global_position = midpoint

	# Point the cylinder from start to end
	mesh_instance.look_at(end_pos, Vector3.UP)
	mesh_instance.rotate_object_local(Vector3(1, 0, 0), PI / 2)  # Align cylinder along line

	# Animate chain shooting out
	_animate_chain_shoot(mesh_instance, distance)

	print("🔗 Created grapple chain from ", start_pos, " to ", end_pos)
	return chain_container


func _animate_chain_shoot(mesh_instance: MeshInstance3D, final_distance: float):
	"""Animate the chain shooting out from 0 length to full length"""
	var cylinder: CylinderMesh = mesh_instance.mesh as CylinderMesh

	# Start with zero height
	cylinder.height = 0.0

	# Animate to full height
	var tween = create_tween()
	tween.tween_property(cylinder, "height", final_distance, final_distance / CHAIN_SHOOT_SPEED)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)


func use_pull(trans: Transform3D, inv_item_or_count = 1):
	"""Right-click: Pull push_blocks (always) or enemies (with 'pull' power) toward player"""
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_use_pull", trans, inv_item_or_count)
	else:
		_use_pull(trans, inv_item_or_count)


func _use_pull(trans: Transform3D, inv_item_or_count = 1):
	"""Pull a push_block (always) or enemy (with 'pull' power) toward the player"""
	var origin = trans.origin
	var direction = -trans.basis.z.normalized()

	# Check if player has "pull" power
	var has_pull_power = false
	if typeof(inv_item_or_count) == TYPE_OBJECT:
		if "skyshard_power" in inv_item_or_count and inv_item_or_count.skyshard_power == "pull":
			has_pull_power = true

	# Raycast to find entities
	var space_state = get_viewport().world_3d.direct_space_state
	var query = PhysicsRayQueryParameters3D.create(origin, origin + direction * GRAPPLE_MAX_DISTANCE)
	query.collision_mask = 1  # Default collision layer

	var result = space_state.intersect_ray(query)

	if result.is_empty():
		print("Grapple pull: No entity hit")
		return

	var collider = result.get("collider")
	if collider == null:
		print("Grapple pull: No collider")
		return

	# Priority 1: Try to find a push_block (always works, no power needed)
	var push_block = _find_push_block_parent(collider)
	if push_block != null:
		_pull_push_block(push_block, origin)
		return

	# Priority 2: If "pull" power is equipped, try to pull enemies
	if has_pull_power:
		var enemy = _find_enemy_parent(collider)
		if enemy != null:
			_pull_enemy(enemy, origin)
			return

	print("Grapple pull: Not aiming at a valid target (push_block or enemy)")


func _pull_push_block(push_block: Node, player_origin: Vector3):
	"""Pull a push_block toward the player"""
	var pull_direction = (player_origin - push_block.global_position).normalized()
	var pull_force = pull_direction * PULL_SPEED * 2.0  # Stronger pull than player grapple

	if push_block.has_method("apply_impulse"):
		push_block.apply_impulse(pull_force)
		print("🪝 Grapple PULL! Pulling push_block from ", push_block.global_position, " toward player")

		# Create visual chain
		var chain_line = _create_grapple_chain(player_origin, push_block.global_position)

		# Auto-remove chain after 0.5s
		if chain_line:
			var timer = get_tree().create_timer(0.5)
			timer.timeout.connect(func(): chain_line.queue_free())


func _pull_enemy(enemy: Node, player_origin: Vector3):
	"""Pull an enemy toward the player with STRONG force (yeet mechanic!)"""
	var pull_direction = (player_origin - enemy.global_position).normalized()
	var pull_force = pull_direction * PULL_SPEED * 5.0  # VERY STRONG - enemies fly PAST player

	# Add small upward boost for a nice arc
	pull_force.y += 2.0

	print("🪝💥 Grapple YEET! Pulling enemy from %s toward player at %s" % [enemy.global_position, player_origin])

	# Apply velocity to enemy (use set_velocity if available, or direct position change)
	if enemy.has_method("apply_external_force"):
		enemy.apply_external_force(pull_force)
	elif enemy.has_method("set_velocity"):
		enemy.set_velocity(pull_force)
	elif "velocity" in enemy:
		enemy.velocity = pull_force
	else:
		print("⚠️ Enemy has no velocity/force method - cannot pull")
		return

	# Create visual chain
	var chain_line = _create_grapple_chain(player_origin, enemy.global_position)

	# Auto-remove chain after 0.5s
	if chain_line:
		var timer = get_tree().create_timer(0.5)
		timer.timeout.connect(func(): chain_line.queue_free())


func _find_push_block_parent(node: Node) -> Node:
	"""Walk up node tree to find a push_block entity"""
	var current = node
	while current != null:
		if current.is_in_group("push_blocks"):
			return current
		current = current.get_parent()
	return null


func _find_enemy_parent(node: Node) -> Node:
	"""Walk up node tree to find an enemy entity"""
	var current = node
	while current != null:
		# Check if node is in the enemy_entities group (set by EntityBase._ready)
		if current.is_in_group("enemy_entities"):
			return current
		current = current.get_parent()
	return null


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, stack_count: int = 1):
	_use(trans, stack_count)


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use_pull(trans: Transform3D, inv_item_or_count = 1):
	_use_pull(trans, inv_item_or_count)
