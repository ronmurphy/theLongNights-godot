extends Node3D

@export var speed := 5.0
@export var gravity := 9.8
@export var jump_force := 5.0
@export var head : NodePath

@export var terrain : NodePath

## Player HP and combat
@export var max_hp: int = 100
@export var defense: int = 10  # % damage reduction
@export var attack_bonus: int = 0  # Bonus damage from role
@export var max_mana: int = 0  # For wizard/healer
@export var current_mana: int = 0

var current_hp: int = 100
var is_alive: bool = true
var _regen_timer: float = 0.0  # For 1 HP per 3 minutes
const REGEN_INTERVAL: float = 180.0  # 3 minutes in seconds

var _velocity := Vector3()
var _grounded := false
var _head : Node3D = null
var _box_mover := VoxelBoxMover.new()
var _grappling := false  # Grappling hook active
var _grapple_time := 0.0  # Time remaining for grapple
var _climbing := false  # Currently climbing a wall
var _climb_speed := 3.0  # Speed when climbing

## Signals
signal hp_changed(current: int, maximum: int)
signal player_died()

## Input control
var input_enabled: bool = true


func _ready():
	_box_mover.set_collision_mask(1) # Excludes rails
	_box_mover.set_step_climbing_enabled(true)
	_box_mover.set_max_step_height(0.5)

	_head = get_node(head)

	# Apply stats from PlayerData (set by quiz)
	max_hp = PlayerData.max_hp
	defense = PlayerData.defense
	attack_bonus = PlayerData.attack_bonus
	max_mana = PlayerData.max_mana
	current_mana = PlayerData.current_mana

	# Initialize HP
	current_hp = max_hp
	add_to_group("player")

	print("Player initialized as %s %s [%s]" % [PlayerData.get_race_name(), PlayerData.get_role_name(), PlayerData.gender])
	print("  HP: %d, Defense: %d%%, Attack: +%d" % [max_hp, defense, attack_bonus])

	# Apply graphics settings to voxel viewer and rendering
	_apply_graphics_settings()


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
	# Handle auto-regeneration (1 HP every 3 minutes)
	if is_alive and current_hp < max_hp:
		_regen_timer += delta
		if _regen_timer >= REGEN_INTERVAL:
			_regen_timer = 0.0
			heal(1)

	# Handle grappling state
	if _grappling:
		_grapple_time -= delta
		if _grapple_time <= 0:
			_grappling = false

	# Only process keyboard input if enabled (not using console)
	if input_enabled:
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
	else:
		# Input disabled (console open) - stop movement and still apply gravity
		_velocity.x = 0
		_velocity.z = 0
		_velocity.y -= gravity * delta
		_climbing = false
	
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
func receive_position(_pos: Vector3):
	# We currently don't expect this to be called. The actual targetted script is different.
	# I had to define it otherwise Godot throws a lot of errors everytime I call the RPC...
	push_error("Didn't expect to receive RPC position")


func start_grapple(pull_velocity: Vector3, duration: float):
	"""Called by grappling hook to initiate a grapple pull"""
	_velocity = pull_velocity
	_grappling = true
	_grapple_time = duration
	_grounded = false


## Apply all graphics settings to this character and terrain
func _apply_graphics_settings() -> void:
	"""
	Apply graphics settings based on current profile (Low/Medium/High)
	This is the KEY optimization spot for rendering performance!

	LOW PROFILE (Potato PC):
	- Voxel View Distance: 50 chunks
	- Camera Far Clip: 49.0 units
	- No shadows, no torch light, 8 particles, 0 debris

	MEDIUM PROFILE (Balanced):
	- Voxel View Distance: 112 chunks
	- Camera Far Clip: 109.8 units
	- Shadows on, torch light 8 range, 15 particles, 15 debris

	HIGH PROFILE (Gaming PC):
	- Voxel View Distance: 128 chunks
	- Camera Far Clip: 125.4 units
	- Shadows on, torch light 12 range, 20 particles, 30 debris
	"""

	# Apply voxel viewer distance and settings
	var voxel_viewer = get_node_or_null("VoxelViewer")
	if voxel_viewer:
		var view_distance = GraphicsSettings.get_setting("voxel_viewer_distance")
		voxel_viewer.view_distance = view_distance
		voxel_viewer.requires_collisions = GraphicsSettings.should_require_voxel_collisions()
		voxel_viewer.requires_visuals = GraphicsSettings.should_require_voxel_visuals()
		print("[CharacterController] VoxelViewer distance: ", view_distance, " chunks")
		print("[CharacterController] VoxelViewer collisions: ", voxel_viewer.requires_collisions)
		print("[CharacterController] VoxelViewer visuals: ", voxel_viewer.requires_visuals)

	# Apply camera far clip
	var camera = get_node_or_null("Camera")
	if camera:
		var camera_far = GraphicsSettings.get_setting("camera_far_clip")
		camera.far = camera_far
		print("[CharacterController] Camera far clip: ", camera_far, " units")

	# Log current profile
	var profile = GraphicsSettings.get_current_profile()
	print("[CharacterController] Graphics profile: ", profile.to_upper())


## Player HP and Combat Functions

## d20-style roll to hit
static func roll_to_hit() -> bool:
	# Roll a d20, if 10 or higher the attack hits
	var roll = randi() % 20 + 1
	return roll >= 10


## Take damage from an attack
func take_damage(amount: int, from: Node = null) -> void:
	if not is_alive:
		return

	# Roll to hit - if failed, no damage
	if not roll_to_hit():
		print("Player dodged attack! (Roll failed)")
		return

	# Apply defense (same formula as entities)
	var actual_damage = max(1, amount - int(amount * (defense / 100.0)))

	current_hp -= actual_damage
	current_hp = max(0, current_hp)

	hp_changed.emit(current_hp, max_hp)

	print("Player took %d damage (HP: %d/%d)" % [actual_damage, current_hp, max_hp])

	# Check for death
	if current_hp <= 0:
		die()


## Heal the player
func heal(amount: int) -> void:
	if not is_alive:
		return

	current_hp += amount
	current_hp = min(max_hp, current_hp)

	hp_changed.emit(current_hp, max_hp)
	print("Player healed %d HP (HP: %d/%d)" % [amount, current_hp, max_hp])


## Player death
func die() -> void:
	if not is_alive:
		return

	is_alive = false
	player_died.emit()

	print("Player died!")

	# Disable player controls
	set_physics_process(false)
	set_process_input(false)


## Enable or disable player input (for console, menus, etc.)
func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if enabled:
		print("[CharacterController] Input enabled")
	else:
		print("[CharacterController] Input disabled")


