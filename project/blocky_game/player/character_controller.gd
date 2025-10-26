extends Node3D

@export var speed := 5.0
@export var gravity := 9.8
@export var jump_force := 5.0
@export var head : NodePath

@export var terrain : NodePath

var _velocity := Vector3()
var _grounded := false
var _head : Node3D = null
var _box_mover := VoxelBoxMover.new()
var _grappling := false  # Grappling hook active
var _grapple_time := 0.0  # Time remaining for grapple
var _climbing := false  # Currently climbing a wall
var _climb_speed := 3.0  # Speed when climbing


func _ready():
	_box_mover.set_collision_mask(1) # Excludes rails
	_box_mover.set_step_climbing_enabled(true)
	_box_mover.set_max_step_height(0.5)

	_head = get_node(head)


func _has_climbing_claws() -> bool:
	# Check if player has climbing claws equipped in hotbar
	var hotbar = get_node_or_null("../HotBar")
	if hotbar == null:
		return false
	var item = hotbar.get_selected_item()
	if item == null:
		return false
	# Climbing claws is item ID 2 (0=rocket_launcher, 1=grappling_hook, 2=climbing_claws)
	return item.type == 1 and item.id == 2  # TYPE_ITEM = 1


func _check_wall_ahead() -> bool:
	# Raycast forward to see if there's a wall
	if not has_node(terrain):
		return false

	var terrain_node : VoxelTerrain = get_node(terrain)
	var vt := terrain_node.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	var forward = _head.get_transform().basis.z.normalized()
	forward = Plane(Vector3(0, 1, 0), 0).project(forward).normalized()

	# Cast forward from player position to check for wall
	var hit = vt.raycast(position, -forward, 1.5)
	return hit != null


func _physics_process(delta: float):
	# Handle grappling state
	if _grappling:
		_grapple_time -= delta
		if _grapple_time <= 0:
			_grappling = false

	# Check for climbing
	var has_claws = _has_climbing_claws()
	var wall_ahead = has_claws and _check_wall_ahead()
	var trying_to_climb = wall_ahead and (Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W))

	# Update climbing state
	_climbing = trying_to_climb

	# Only process keyboard input if not grappling
	if not _grappling:
		if _climbing:
			# Climbing mode - move upward
			_velocity.x = 0
			_velocity.z = 0
			_velocity.y = _climb_speed
			_grounded = false
		else:
			# Normal movement
			var forward = _head.get_transform().basis.z.normalized()
			forward = Plane(Vector3(0, 1, 0), 0).project(forward)
			var right = _head.get_transform().basis.x.normalized()
			var motor = Vector3()

			if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W):
				motor -= forward
			if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
				motor += forward
			if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
				motor -= right
			if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
				motor += right

			motor = motor.normalized() * speed

			_velocity.x = motor.x
			_velocity.z = motor.z

	# Apply gravity (unless climbing)
	if not _climbing:
		_velocity.y -= gravity * delta
	
	if _grounded and Input.is_key_pressed(KEY_SPACE):
		_velocity.y = jump_force
		_grounded = false
	
	var motion := _velocity * delta
	
	if has_node(terrain):
		var aabb := AABB(Vector3(-0.4, -0.9, -0.4), Vector3(0.8, 1.8, 0.8))
		var terrain_node : VoxelTerrain = get_node(terrain)
		
		var vt := terrain_node.get_voxel_tool()
		if vt.is_area_editable(AABB(aabb.position + position, aabb.size)):
			var prev_motion := motion

			# Modify motion taking collisions into account
			motion = _box_mover.get_motion(position, motion, aabb, terrain_node)

			# Apply motion with a raw translation.
			global_translate(motion)

			# If new motion doesnt move vertically and we were falling before, we just landed
			if absf(motion.y) < 0.001 and prev_motion.y < -0.001:
				_grounded = true

			if _box_mover.has_stepped_up():
				# When we step up, the motion vector will have vertical movement,
				# however it is not caused by falling or jumping, but by snapping the body on
				# top of the step. So after we applied motion, we consider it grounded,
				# and we reset motion.y so we don't induce a "jump" velocity later.
				motion.y = 0
				_grounded = true
			
			# Otherwise, if new motion is moving vertically, we may not be grounded anymore
			elif absf(motion.y) > 0.001:
				_grounded = false

			# TODO Stepping up stairs is quite janky. Minecraft seems to smooth it out a little.
			# That would be a visual-only trick to apply it seems.
		
		else:
			# Don't fall to infinity, wait until terrain loads
			motion = Vector3()

	assert(delta > 0)
	# Re-inject velocity from resulting motion
	_velocity = motion / delta

	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer():
		# Broadcast our position to other peers.
		# Note, for other peers, this is a different script (remote_character.gd).
		# Each peer is authoritative of its own position for now.
		# TODO Make sure this RPC is not sent when we are not connected
		rpc(&"receive_position", position)


@rpc("authority", "call_remote", "unreliable")
func receive_position(pos: Vector3):
	# We currently don't expect this to be called. The actual targetted script is different.
	# I had to define it otherwise Godot throws a lot of errors everytime I call the RPC...
	push_error("Didn't expect to receive RPC position")


func start_grapple(pull_velocity: Vector3, duration: float):
	"""Called by grappling hook to initiate a grapple pull"""
	_velocity = pull_velocity
	_grappling = true
	_grapple_time = duration
	_grounded = false


