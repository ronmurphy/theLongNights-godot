extends Node3D

## Boomerang - Curved throwing weapon that returns to player
## Flies in an arc toward target, then curves back to player
## Deals continuous damage while passing through enemies

const EntityBase = preload("../entities/entity_base.gd")

enum State {
	OUTBOUND,   # Flying toward target
	RETURNING   # Flying back to player
}

var state: State = State.OUTBOUND
var owner_entity = null  # Player who threw the boomerang

# Flight parameters
var _flight_progress := 0.0  # 0.0 to 1.0 along current curve
var _outbound_curve_points: Array  # Bezier control points [start, ctrl1, ctrl2, end]
var _return_curve_points: Array
const CURVE_SPEED = 0.8  # How fast to traverse curve (higher = faster)
const MAX_RANGE = 35.0  # Maximum distance to fly

# Damage parameters
const DAMAGE_PER_FRAME = 1  # 1 damage per frame = 60 DPS at 60 FPS
const HIT_RADIUS = 0.8  # Distance to enemy for damage
var _entities_damaged_this_frame: Array = []  # Track what we hit this frame

# Terrain collision
var _terrain: VoxelTerrain = null
const CATCH_RADIUS = 1.2  # Auto-catch when this close to player

# Visual
var _spin_speed := 15.0  # Radians per second for horizontal spin


func _ready():
	# Get terrain reference
	_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")

	# Note: Rotation is set dynamically in _physics_process to face direction of travel
	# and stay flat (parallel to ground)

	# Create 3D boomerang mesh - V-shaped design
	var boom_mat = StandardMaterial3D.new()
	boom_mat.albedo_color = Color(0.7, 0.5, 0.3)  # Wood brown
	boom_mat.metallic = 0.1
	boom_mat.roughness = 0.6
	boom_mat.emission_enabled = true
	boom_mat.emission = Color(0.3, 0.6, 1.0)  # Magical blue glow
	boom_mat.emission_energy_multiplier = 2.0

	# Left arm
	var left_arm = MeshInstance3D.new()
	var left_mesh = BoxMesh.new()
	left_mesh.size = Vector3(0.6, 0.1, 0.15)  # Long, thin arm
	left_arm.mesh = left_mesh
	left_arm.position = Vector3(-0.3, 0, 0)
	left_arm.rotation_degrees = Vector3(0, 0, 25)  # Angle upward
	left_arm.material_override = boom_mat
	add_child(left_arm)

	# Right arm
	var right_arm = MeshInstance3D.new()
	var right_mesh = BoxMesh.new()
	right_mesh.size = Vector3(0.6, 0.1, 0.15)
	right_arm.mesh = right_mesh
	right_arm.position = Vector3(0.3, 0, 0)
	right_arm.rotation_degrees = Vector3(0, 0, -25)  # Angle upward
	right_arm.material_override = boom_mat
	add_child(right_arm)

	# Central hub
	var hub = MeshInstance3D.new()
	var hub_mesh = CylinderMesh.new()
	hub_mesh.top_radius = 0.08
	hub_mesh.bottom_radius = 0.08
	hub_mesh.height = 0.15
	hub.mesh = hub_mesh
	hub.rotation_degrees = Vector3(0, 0, 90)  # Rotate to align with arms
	hub.material_override = boom_mat
	add_child(hub)

	# Magical glow
	var light = OmniLight3D.new()
	light.light_color = Color(0.3, 0.6, 1.0)
	light.light_energy = 2.0
	light.omni_range = 3.0
	light.shadow_enabled = false
	add_child(light)

	print("🪃 Boomerang created")


func initialize(start_pos: Vector3, target_pos: Vector3, player: Node3D):
	"""Initialize boomerang with start position, target, and player reference"""
	owner_entity = player
	global_position = start_pos

	# Clamp target to max range
	var to_target = target_pos - start_pos
	var distance = to_target.length()
	if distance > MAX_RANGE:
		to_target = to_target.normalized() * MAX_RANGE
		target_pos = start_pos + to_target
		distance = MAX_RANGE

	# Create outbound curve (player -> target with arc)
	var to_target_dir = to_target.normalized()

	# Perpendicular vector for curve offset (makes it arc to the side)
	var perp = Vector3(-to_target_dir.z, 0, to_target_dir.x).normalized()

	# Bezier control points for smooth curved arc
	var control_offset = perp * (distance * 0.4)  # Arc sideways
	_outbound_curve_points = [
		start_pos,
		start_pos + to_target_dir * (distance * 0.33) + control_offset,
		start_pos + to_target_dir * (distance * 0.66) + control_offset,
		target_pos
	]

	print("🪃 Boomerang launched toward target at distance: ", distance)


var _last_position := Vector3.ZERO  # Track last frame position for push direction

func _physics_process(delta: float):
	# Store old position before moving
	var old_position = global_position
	_last_position = old_position

	# Advance along curve
	_flight_progress += CURVE_SPEED * delta

	match state:
		State.OUTBOUND:
			_process_outbound(delta)
		State.RETURNING:
			_process_returning(delta)

	# Face the direction of travel
	var travel_direction = (global_position - old_position).normalized()
	if travel_direction.length_squared() > 0.001:  # Only update if we moved significantly
		# Calculate the Y rotation to face travel direction while staying flat
		var angle_to_direction = atan2(travel_direction.x, travel_direction.z)
		rotation.y = angle_to_direction
		# Keep X rotation at 90 degrees to stay flat
		rotation.x = deg_to_rad(90)

	# Spin horizontally (like a frisbee) - rotate around local Z axis since we're tilted
	rotate_object_local(Vector3(0, 0, 1), _spin_speed * delta)

	# Check for enemy collisions and deal per-frame damage
	_check_enemy_collisions()

	# Check for push block collisions
	_check_push_block_collisions()

	# Clear frame tracking
	_entities_damaged_this_frame.clear()


func _process_outbound(delta: float):
	"""Fly toward target along curved path"""
	if _flight_progress >= 1.0:
		# Reached end of outbound path, start returning
		_start_return()
		return

	# Evaluate cubic bezier curve
	var new_pos = _evaluate_bezier(_outbound_curve_points, _flight_progress)

	# Check for terrain collision before moving
	var terrain_hit = _check_terrain_collision_point(global_position, new_pos)
	if terrain_hit:
		# Check if we hit a push_block
		if _is_push_block_voxel(terrain_hit):
			_on_hit_push_block_voxel(terrain_hit)
			_start_return()  # Bounce back after pushing
			return

		# Hit normal terrain! Bounce back immediately
		_start_return()
		return

	global_position = new_pos


func _process_returning(delta: float):
	"""Fly back to player along curved path"""
	if not is_instance_valid(owner_entity):
		queue_free()
		return

	# Check for auto-catch
	var player_pos = owner_entity.global_position + Vector3(0, 1, 0)
	var distance_to_player = global_position.distance_to(player_pos)
	if distance_to_player < CATCH_RADIUS:
		print("🪃 Boomerang caught!")
		queue_free()
		return

	if _flight_progress >= 1.0:
		# Reached end of curve but not caught yet - recalculate return curve
		# (player may have moved)
		_start_return()
		return

	# Evaluate return curve
	var new_pos = _evaluate_bezier(_return_curve_points, _flight_progress)

	# Check for terrain collision
	var terrain_hit = _check_terrain_collision_point(global_position, new_pos)
	if terrain_hit:
		# Check if we hit a push_block
		if _is_push_block_voxel(terrain_hit):
			_on_hit_push_block_voxel(terrain_hit)

		# Hit terrain while returning - just go directly to player
		var to_player = (player_pos - global_position).normalized()
		global_position += to_player * 25.0 * delta
		return

	global_position = new_pos


func _start_return():
	"""Switch to returning state and calculate return curve"""
	if not is_instance_valid(owner_entity):
		queue_free()
		return

	state = State.RETURNING
	_flight_progress = 0.0

	# Create return curve from current position to player
	var player_pos = owner_entity.global_position + Vector3(0, 1, 0)
	var to_player = (player_pos - global_position).normalized()
	var distance = global_position.distance_to(player_pos)

	# Use opposite perpendicular for return arc (mirror the outbound path)
	var perp = Vector3(to_player.z, 0, -to_player.x).normalized()
	var control_offset = perp * (distance * 0.4)

	_return_curve_points = [
		global_position,
		global_position + to_player * (distance * 0.33) + control_offset,
		global_position + to_player * (distance * 0.66) + control_offset,
		player_pos
	]

	print("🪃 Boomerang returning to player")


func _evaluate_bezier(points: Array, t: float) -> Vector3:
	"""Evaluate cubic Bezier curve at parameter t (0.0 to 1.0)"""
	var t2 = t * t
	var t3 = t2 * t
	var mt = 1.0 - t
	var mt2 = mt * mt
	var mt3 = mt2 * mt

	return (mt3 * points[0]) + \
		   (3.0 * mt2 * t * points[1]) + \
		   (3.0 * mt * t2 * points[2]) + \
		   (t3 * points[3])


func _check_terrain_collision(from_pos: Vector3, to_pos: Vector3) -> bool:
	"""Check if movement from from_pos to to_pos hits terrain"""
	return _check_terrain_collision_point(from_pos, to_pos) != null


func _check_terrain_collision_point(from_pos: Vector3, to_pos: Vector3):
	"""Check if movement from from_pos to to_pos hits terrain, return hit position"""
	if _terrain == null:
		return null

	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	var direction = (to_pos - from_pos).normalized()
	var distance = from_pos.distance_to(to_pos)

	# Raycast along movement path
	var hit = vt.raycast(from_pos, direction, distance + 0.5)
	if hit != null:
		print("🪃 Boomerang hit terrain!")
		return Vector3(hit.position)

	return null


func _is_push_block_voxel(voxel_pos: Vector3) -> bool:
	"""Check if the voxel at this position is a push_block"""
	if not _terrain:
		return false

	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	var voxel_id = vt.get_voxel(voxel_pos)
	if voxel_id == 0:
		return false

	# Get block type
	var blocks_node = get_node_or_null("/root/Main/Game/Blocks")
	if not blocks_node:
		return false

	var block = blocks_node.get_block(voxel_id)
	return block and block.base_info.name == "push_block"


func _on_hit_push_block_voxel(voxel_pos: Vector3):
	"""Hit a push_block voxel - find or create entity and push it"""
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
			# Entity will be pushed next time boomerang passes through

	# Push the block if we found it
	if block_entity and block_entity.has_method("apply_impulse"):
		# Calculate push direction
		var travel_direction = (_last_position - global_position).normalized()
		if travel_direction.length_squared() < 0.001:
			travel_direction = Vector3.FORWARD
		var impulse = travel_direction * 2.0  # Stronger push on direct hit

		block_entity.apply_impulse(impulse)
		print("🪃 Boomerang pushed block!")


func _check_enemy_collisions():
	"""Check for enemies within hit radius and deal per-frame damage"""
	var entities = get_tree().get_nodes_in_group("entities")

	for entity in entities:
		if not is_instance_valid(entity):
			continue

		# Skip non-EntityBase nodes
		if not entity is EntityBase:
			continue

		# Skip friendly entities (don't damage player team)
		if entity.team == EntityBase.Team.PLAYER:
			continue

		# Skip dead entities
		if not entity.is_alive:
			continue

		# Check distance
		var distance = global_position.distance_to(entity.global_position)
		if distance <= HIT_RADIUS:
			# Inside hitbox - deal damage this frame!
			if entity.has_method("take_damage"):
				entity.take_damage(DAMAGE_PER_FRAME, owner_entity)
				_entities_damaged_this_frame.append(entity)


func _check_push_block_collisions():
	"""Check for push blocks within hit radius and apply per-frame pushing force"""
	var push_blocks = get_tree().get_nodes_in_group("push_blocks")

	for block in push_blocks:
		if not is_instance_valid(block):
			continue

		# Check distance
		var distance = global_position.distance_to(block.global_position)
		if distance <= HIT_RADIUS:
			# Inside hitbox - push the block!
			# Calculate push direction based on boomerang's movement
			var travel_direction = (global_position - _last_position).normalized()
			if travel_direction.length_squared() < 0.001:
				travel_direction = Vector3.FORWARD  # Fallback if not moving
			var impulse = travel_direction * 0.5  # Gentle continuous push per frame

			if block.has_method("apply_impulse"):
				block.apply_impulse(impulse)
				# Only print once per block to avoid spam
				if not block in _entities_damaged_this_frame:
					print("🎯 Boomerang pushing block")
					_entities_damaged_this_frame.append(block)  # Reuse entity tracking for blocks too
