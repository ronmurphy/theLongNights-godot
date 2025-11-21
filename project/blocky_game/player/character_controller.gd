extends Node3D

const CharacterQuiz = preload("res://long_nights/CharacterQuiz.gd")
const PlayerAvatar = preload("res://blocky_game/player/player_avatar.gd")

@export var speed := 5.0
@export var gravity := 9.8  # Base gravity at surface
@export var jump_force := 5.0
@export var head : NodePath

# Depth-based gravity system (story: they broke gravity by mining too deep)
const GRAVITY_REDUCTION_PER_100_BLOCKS := 0.1  # Reduce gravity by this much every 100 blocks down
const MIN_GRAVITY := 5.0  # Minimum gravity (don't go below this)

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

# Low health warning system
var _low_health_sound: AudioStreamPlayer = null
var _low_health_15_played: bool = false
var _low_health_10_played: bool = false
var _low_health_5_played: bool = false

var _velocity := Vector3()
var _grounded := false
var _head : Node3D = null
var _box_mover := VoxelBoxMover.new()
var _grappling := false  # Grappling hook active
var _grapple_time := 0.0  # Time remaining for grapple
var _grapple_chain_line: Node3D = null  # Visual chain line for grappling hook
var _grapple_target_pos: Vector3 = Vector3.ZERO  # Target position for chain line
var _climbing := false  # Currently climbing a wall
var _climb_speed := 3.0  # Speed when climbing
var _jump_grace_period := 0.0  # Time after jump to prevent climbing interference
var _gravity_disabled := false  # Temporary gravity suspension (for teleporting)
var _wind_dash_active := false  # Wind Dash power active
var _wind_dash_time := 0.0  # Time remaining for Wind Dash
var _flame_aura_timer := 0.0  # Timer for Flame Aura damage ticks
var _void_fog_damage_timer := 0.0  # Timer for void_fog damage (5 damage per move)
var _last_void_fog_position := Vector3i(999999, 999999, 999999)  # Track last fog position
var _flame_aura_visual: MeshInstance3D = null  # Visual effect for flame aura

## Ring of Thorns system
var _thorn_orbs: Array[Node3D] = []  # The 3 orbiting thorns
var _thorn_attack_timer := 0.0  # Timer for auto-attack (every 2 seconds)
const THORN_ATTACK_INTERVAL = 2.0  # Seconds between auto-attacks
const THORN_ATTACK_RANGE = 15.0  # Blocks to search for enemies

## Player avatar billboard
var _player_avatar: PlayerAvatar = null
var _show_avatar: bool = true # Toggle for testing (set to true to see billboard)

## Camera orbit for character viewing
var _camera_orbiting: bool = false
var _orbit_angle: float = 0.0
var _orbit_distance: float = 3.0
var _orbit_height: float = 1.0
var _original_camera_position: Vector3 = Vector3.ZERO
var _original_camera_rotation: Vector3 = Vector3.ZERO

## Photo mode for manual camera control
var _photo_mode: bool = false
var _photo_camera_yaw: float = 0.0
var _photo_camera_pitch: float = 0.0
var _photo_camera_distance: float = 3.0
const PHOTO_CAMERA_MOVE_SPEED = 5.0
const PHOTO_CAMERA_ROTATE_SPEED = 2.0
const PHOTO_CAMERA_ZOOM_SPEED = 2.0
var _p_key_was_pressed: bool = false  # Track P key state to detect single press
var _i_key_was_pressed: bool = false  # Track I key state for pose cycling
var _hidden_ui_elements: Array = []  # Track which UI elements we hide for photo mode

## Photo mode pose cycling (interactive mode)
var _photo_front_poses: Array = []  # Available front-facing poses
var _photo_back_poses: Array = []  # Available back-facing poses
var _photo_current_front_index: int = 0  # Current front pose index
var _photo_current_back_index: int = 0  # Current back pose index

## Signals
signal hp_changed(current: int, maximum: int)
signal player_died()

## Input control
var input_enabled: bool = true
var _screenshot_taken: bool = false  # Prevent multiple screenshots from one key press

## Performance optimization - Entity caching to avoid expensive get_nodes_in_group() calls every frame
var _cached_entities: Array = []
var _entity_cache_timer: float = 0.0
const ENTITY_CACHE_REFRESH_INTERVAL: float = 0.5  # Refresh every 0.5 seconds instead of every frame

## Performance optimization - Cached node references
@onready var _hotbar: Node = get_node_or_null("../HotBar")


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

	# Apply race-based speed multiplier
	var speed_multiplier = CharacterQuiz.get_race_speed_multiplier(PlayerData.race)
	speed *= speed_multiplier
	_climb_speed *= speed_multiplier

	# Initialize HP
	current_hp = max_hp
	add_to_group("player")

	print("Player initialized as %s %s [%s]" % [PlayerData.get_race_name(), PlayerData.get_role_name(), PlayerData.gender])
	print("  HP: %d, Defense: %d%%, Attack: +%d" % [max_hp, defense, attack_bonus])
	print("  Speed multiplier: %.2fx (Race: %s)" % [speed_multiplier, PlayerData.race])

	# Disable shadow casting on any box mesh (we use billboard shadow instead)
	_disable_box_shadow()
	
	# Create player avatar billboard (hidden by default for testing)
	_create_player_avatar()

	# Setup low health warning sound
	_low_health_sound = AudioStreamPlayer.new()
	_low_health_sound.stream = load("res://assets/sfx/Low health.ogg")
	_low_health_sound.volume_db = -5.0
	add_child(_low_health_sound)

	# Apply graphics settings to voxel viewer and rendering
	_apply_graphics_settings()


func _has_wind_walker_boots() -> bool:
	# Check if player OR companion has Wind Walker Boots equipped in the equipment slot
	var inventory = get_node_or_null("Inventory")
	if inventory == null:
		return false
	
	# Check player's equipped item
	var player_equipped = inventory.get_player_equipped_weapon()
	if player_equipped != null and player_equipped.type == 1 and player_equipped.id == 2:
		return true
	
	# Check companion's equipped item
	var companion_equipped = inventory.get_companion_equipped_weapon()
	if companion_equipped != null and companion_equipped.type == 1 and companion_equipped.id == 2:
		return true
	
	return false


func _check_wall_ahead() -> bool:
	# Check if there's a climbable wall ahead (at least 2 blocks tall)
	if not has_node(terrain):
		return false

	var terrain_node : VoxelTerrain = get_node(terrain)
	var vt := terrain_node.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	var forward = _head.get_transform().basis.z.normalized()
	forward = Plane(Vector3(0, 1, 0), 0).project(forward).normalized()

	# Cast forward from player position to check for wall
	# Short distance (0.6) so climbing only activates when touching the wall
	var hit = vt.raycast(position, -forward, 0.6)
	if hit == null:
		return false  # No wall ahead

	# Found a wall - now check if it's at least 2 blocks tall
	# Check the block at player height and one block above
	var wall_pos = hit.position
	var block_at_feet = vt.get_voxel(Vector3i(wall_pos))
	var block_above = vt.get_voxel(Vector3i(wall_pos.x, wall_pos.y + 1, wall_pos.z))

	# Only allow climbing if there are at least 2 solid blocks vertically
	# (0 = air, so both must be non-zero)
	return block_at_feet != 0 and block_above != 0


func _check_air_above() -> bool:
	# Check if there's air above the player (reached top of climb)
	if not has_node(terrain):
		return false

	var terrain_node : VoxelTerrain = get_node(terrain)
	var vt := terrain_node.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	var forward = _head.get_transform().basis.z.normalized()
	forward = Plane(Vector3(0, 1, 0), 0).project(forward).normalized()

	# Check the block ahead at head height (where we're trying to climb to)
	var check_pos = position + (-forward * 0.8) + Vector3(0, 1.8, 0)
	var block_at_top = vt.get_voxel(Vector3i(check_pos))

	# If it's air (0), we've reached the top
	return block_at_top == 0


func _physics_process(delta: float):
	# Performance optimization: Refresh entity cache periodically instead of every frame
	_entity_cache_timer += delta
	if _entity_cache_timer >= ENTITY_CACHE_REFRESH_INTERVAL:
		_entity_cache_timer = 0.0
		_refresh_entity_cache()

	# Check for proximity-based dialogue triggers (e.g., crashed ruin)
	if Engine.has_singleton("DialogueManager"):
		var dm = Engine.get_singleton("DialogueManager")
		if dm:
			dm.check_event_triggers(global_position)

	# Handle auto-regeneration (1 HP every 3 minutes)
	if is_alive and current_hp < max_hp:
		_regen_timer += delta
		if _regen_timer >= REGEN_INTERVAL:
			_regen_timer = 0.0
			heal(1)

	# Handle grappling state
	if _grappling:
		_grapple_time -= delta

		# Update chain line position to follow player
		if _grapple_chain_line:
			_update_grapple_chain_position()

		if _grapple_time <= 0 or _grounded:
			_grappling = false
			# Remove grapple chain line when landing or time expires
			if _grapple_chain_line:
				_grapple_chain_line.queue_free()
				_grapple_chain_line = null
				print("🔗 Grapple chain removed - landed")

	# Handle Wind Dash state
	if _wind_dash_active:
		_wind_dash_time -= delta
		if _wind_dash_time <= 0:
			_wind_dash_active = false
			print("💨 Wind Dash ended")

	# Count down jump grace period
	if _jump_grace_period > 0.0:
		_jump_grace_period -= delta

	# Handle Flame Aura passive power (burns nearby enemies every second)
	_flame_aura_timer += delta
	if _flame_aura_timer >= 1.0:
		_flame_aura_timer = 0.0
		var equipped_weapon = _get_equipped_weapon()
		if equipped_weapon and equipped_weapon.has_power("flame_aura"):
			_apply_flame_aura()

	# Update flame aura visual effect
	_update_flame_aura_visual()

	# Handle Ring of Thorns (orbiting projectiles that auto-attack)
	_update_ring_of_thorns(delta)

	# Handle void_fog damage (5 damage when moving to a new fog block)
	if has_node(terrain):
		var terrain_node : VoxelTerrain = get_node(terrain)
		var vt := terrain_node.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE

		# Check block at player's feet
		var player_block_pos = Vector3i(floor(position.x), floor(position.y - 0.5), floor(position.z))
		var block_id = vt.get_voxel(player_block_pos)

		# VOID_FOG = 55 (from generator.gd)
		const VOID_FOG = 55
		if block_id == VOID_FOG:
			# Check if we moved to a new fog block
			if player_block_pos != _last_void_fog_position:
				_last_void_fog_position = player_block_pos
				# Deal 5 damage (bypasses dodge roll for environmental damage)
				var actual_damage = max(1, 5 - int(5 * defense / 100.0))
				current_hp -= actual_damage
				current_hp = max(0, current_hp)
				hp_changed.emit(current_hp, max_hp)
				print("💀 Void fog damage! -%d HP (now %d/%d)" % [actual_damage, current_hp, max_hp])

				if current_hp <= 0 and is_alive:
					is_alive = false
					player_died.emit()
					print("☠️ Player died from void fog!")
		else:
			# Not in fog anymore, reset position
			_last_void_fog_position = Vector3i(999999, 999999, 999999)

	# Only process keyboard input if enabled (not using console)
	if input_enabled:
		# Check for climbing (legacy functionality - will be replaced with glide)
		var has_boots = _has_wind_walker_boots()
		var wall_ahead = has_boots and _check_wall_ahead()
		# Only allow climbing if grace period has expired (prevents interference with jumps)
		var trying_to_climb = _jump_grace_period <= 0.0 and wall_ahead and (Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W))

		# Update climbing state
		_climbing = trying_to_climb

		# Only process keyboard input if not grappling
		if not _grappling:
			if _climbing:
				# Check if reached the top (air above player)
				if _check_air_above():
					# Auto-jump to get over the ledge
					_velocity.y = jump_force
					_grounded = false
					_climbing = false
					_jump_grace_period = 0.3
					print("🧗 Reached top of climb - jumping over ledge!")
				else:
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

				# Apply Wind Dash speed multiplier
				var effective_speed = speed
				if _wind_dash_active:
					effective_speed *= 2.0  # Double speed during Wind Dash

				motor = motor.normalized() * effective_speed

				# Aerial control: reduce air movement if not gliding
				# Check glide status early for aerial control
				var equipped_weapon = _get_equipped_weapon()
				var has_glide_power = equipped_weapon and equipped_weapon.has_power("glide")
				var boots_equipped = _has_wind_walker_boots()
				var turn_speed_multiplier = 1.0

				if not _grounded and (has_glide_power or boots_equipped):
					# Calculate turn speed based on boots + power synergy
					if has_glide_power and boots_equipped:
						turn_speed_multiplier = 1.0  # 100% control (full synergy)
					else:
						turn_speed_multiplier = 0.3  # 30% control (base glide)

					# Apply reduced air control
					motor.x *= turn_speed_multiplier
					motor.z *= turn_speed_multiplier

				_velocity.x = motor.x
				_velocity.z = motor.z

		# Apply gravity (unless climbing or gravity disabled)
		if not _climbing and not _gravity_disabled:
			var depth_adjusted_gravity = _get_depth_adjusted_gravity()
			_velocity.y -= depth_adjusted_gravity * delta

		# Wind Walker Boots and [Glide] Power: slow-fall cap (already checked above for aerial control)
		var equipped_weapon = _get_equipped_weapon()
		var has_glide_power = equipped_weapon and equipped_weapon.has_power("glide")
		var boots_equipped = _has_wind_walker_boots()
		var fall_speed_cap = -4.0

		if has_glide_power and boots_equipped:
			# Synergy: slower fall speed cap (better gliding)
			fall_speed_cap = -3.0
		elif has_glide_power or boots_equipped:
			# Either boots or power: base fall speed cap
			fall_speed_cap = -4.0

		# Apply slow-fall cap ONLY if falling fast enough (not right after jump)
		# This prevents glide from activating immediately on jump
		# DON'T apply during grapple - let grapple have full speed
		if not _grappling and (has_glide_power or boots_equipped) and _velocity.y < fall_speed_cap:
			_velocity.y = max(_velocity.y, fall_speed_cap)

		if _grounded and Input.is_key_pressed(KEY_SPACE):
			# ⚡ SKYSHARD POWER: Moon Jump (triple jump height when equipped)
			var jump_multiplier = 1.0
			# equipped_weapon already declared above
			if equipped_weapon and equipped_weapon.has_power("moon_jump"):
				jump_multiplier = 3.0
				print("🌙 Moon Jump active! Tripled jump height!")

			_velocity.y = jump_force * jump_multiplier
			_grounded = false
			_jump_grace_period = 0.3  # Prevent climbing interference for 0.3 seconds
	else:
		# Input disabled (console open) - stop movement and still apply gravity
		_velocity.x = 0
		_velocity.z = 0
		if not _gravity_disabled:
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
	
	# Handle camera orbit mode
	if _camera_orbiting:
		_update_camera_orbit(delta)
	
	# Handle photo mode
	if _photo_mode:
		_update_photo_mode(delta)
		return  # Skip normal movement processing in photo mode
	
	# Update player avatar sprite direction and jumping state based on movement or camera orbit
	if _player_avatar and _show_avatar:
		var is_facing_back = false

		if _camera_orbiting:
			# During orbit, switch sprite based on where camera is relative to player's facing
			var player_forward = -global_transform.basis.z  # Player's forward direction
			player_forward.y = 0

			var cam_direction = (_head.global_position - global_position).normalized()
			cam_direction.y = 0

			# Calculate dot product: if camera is in front of player, show front sprite
			# If camera is behind player, show back sprite
			var dot = player_forward.normalized().dot(cam_direction.normalized())

			# dot > 0 = camera in front of where player is facing = show back of player
			# dot < 0 = camera behind where player is facing = show front of player
			is_facing_back = dot > 0
			_player_avatar.force_sprite_direction(is_facing_back)
		else:
			# Normal first-person: avatar is in shadow-only mode (invisible sprite, visible shadow)
			# Still update sprite direction for when we switch to charview
			var cam_forward = -_head.global_transform.basis.z
			_player_avatar.update_sprite_direction(_velocity, cam_forward)

			# Determine facing direction based on movement
			var horizontal_velocity = Vector3(_velocity.x, 0, _velocity.z)
			if horizontal_velocity.length() >= 0.5:
				var dot_product = horizontal_velocity.normalized().dot(cam_forward)
				is_facing_back = dot_product > 0

		# Update jumping state
		var is_jumping = not _grounded
		_player_avatar.update_jumping_state(is_jumping, is_facing_back)

		# Update running state (only when not jumping - jumping takes priority)
		# NOTE: Running sprites currently only available for human_male and elf_female
		if not is_jumping:
			_player_avatar.update_running_state(_velocity, _grounded, is_facing_back, global_position)

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


func start_grapple(pull_velocity: Vector3, duration: float, chain_line: Node3D = null, target_pos: Vector3 = Vector3.ZERO):
	"""Called by grappling hook to initiate a grapple pull"""
	# Clean up previous chain if it exists (in case player rapidly fires multiple grapples)
	if _grapple_chain_line and is_instance_valid(_grapple_chain_line):
		_grapple_chain_line.queue_free()
		_grapple_chain_line = null
		print("🔗 Removed previous grapple chain for new grapple")

	_velocity = pull_velocity
	_grappling = true
	_grapple_time = duration
	_grounded = false

	# Store chain line reference for tracking
	_grapple_chain_line = chain_line
	_grapple_target_pos = target_pos


func _update_grapple_chain_position():
	"""Update the grapple chain line to stretch from player to target block"""
	if not _grapple_chain_line:
		return

	# Get the mesh instance (child of the chain container)
	var mesh_instance = _grapple_chain_line.get_child(0) as MeshInstance3D
	if not mesh_instance:
		return

	var player_pos = global_position + Vector3(0, 1.0, 0)  # From player center height
	var target_pos = _grapple_target_pos

	# Calculate new distance and direction
	var distance = player_pos.distance_to(target_pos)
	var midpoint = (player_pos + target_pos) / 2.0

	# Update cylinder height
	var cylinder = mesh_instance.mesh as CylinderMesh
	if cylinder:
		cylinder.height = distance

	# Update position and orientation
	mesh_instance.global_position = midpoint
	mesh_instance.look_at(target_pos, Vector3.UP)
	mesh_instance.rotate_object_local(Vector3(1, 0, 0), PI / 2)


## Disable shadow on box mesh (use billboard shadow instead)
func _disable_box_shadow():
	"""Find and disable shadow casting on any child MeshInstance3D nodes"""
	for child in get_children():
		if child is MeshInstance3D:
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			print("🚫 Disabled shadow on player box mesh")


## Hide/show collision box mesh (for character viewing)
func _hide_collision_box_mesh(hide: bool):
	"""Hide or show the collision box mesh during camera orbit"""
	for child in get_children():
		if child is MeshInstance3D:
			child.visible = !hide


## Create player avatar billboard (Phase 1 - hidden by default for testing)
func _create_player_avatar():
	"""Create player billboard avatar"""
	_player_avatar = PlayerAvatar.new()
	
	# Get player's actual race/gender from PlayerData
	var race = PlayerData.race
	var gender = PlayerData.gender
	var color = Color.WHITE  # TODO: Add clothing color system if needed
	
	_player_avatar.initialize(race, gender, color, true)  # true = is_local
	_player_avatar.position = Vector3(0, 0, 0)  # At player's center
	
	add_child(_player_avatar)
	
	# Enable shadow-only mode for first-person (invisible sprite, visible shadow)
	_player_avatar.set_shadow_only_mode(true)
	
	print("🎭 Player avatar created (%s %s) - shadow-only mode for first-person" % [race, gender])


## Start orbiting camera around player for character viewing
func start_camera_orbit():
	"""Begin camera orbit - called by console command 'charview'"""
	if _camera_orbiting:
		return  # Already orbiting
	
	_camera_orbiting = true
	_orbit_angle = 0.0
	
	# Store original camera transform
	_original_camera_position = _head.position
	_original_camera_rotation = _head.rotation
	
	# Hide collision box mesh during orbit
	_hide_collision_box_mesh(true)
	
	# Make avatar visible during orbit (disable shadow-only mode)
	if _player_avatar:
		_player_avatar.set_shadow_only_mode(false)
	
	# Disable player input during orbit
	input_enabled = false
	
	print("📷 Camera orbit started - showing character")


## Stop camera orbit and return to normal
func stop_camera_orbit():
	"""End camera orbit and return camera to player"""
	if not _camera_orbiting:
		return
	
	_camera_orbiting = false
	
	# Restore original camera transform
	_head.position = _original_camera_position
	_head.rotation = _original_camera_rotation
	
	# Show collision box mesh again
	_hide_collision_box_mesh(false)
	
	# Return to shadow-only mode for first-person
	if _player_avatar:
		_player_avatar.set_shadow_only_mode(true)
	
	# Re-enable player input
	input_enabled = true
	
	print("📷 Camera orbit ended - returned to first-person")


## Update camera position during orbit
func _update_camera_orbit(delta: float):
	"""Update camera position to orbit around player"""
	# Rotate camera around player at constant speed (360 degrees in 8 seconds)
	_orbit_angle += delta * (TAU / 8.0)
	
	# Calculate camera position in local space
	var orbit_x = cos(_orbit_angle) * _orbit_distance
	var orbit_z = sin(_orbit_angle) * _orbit_distance
	
	var orbit_pos = Vector3(orbit_x, _orbit_height, orbit_z)
	_head.position = orbit_pos
	
	# Look at player center (convert to global coordinates for look_at)
	var player_center_global = global_position + Vector3(0, 1.0, 0)
	_head.look_at(player_center_global, Vector3.UP)
	
	# Complete orbit after one full rotation
	if _orbit_angle >= TAU:
		stop_camera_orbit()


## ============================================================================
## PHOTO MODE - Manual camera control with arrow keys
## ============================================================================

func start_photo_mode():
	"""Enter photo mode - manual camera control with arrow keys"""
	if _photo_mode:
		return  # Already in photo mode
	
	_photo_mode = true
	
	# Store original camera transform
	_original_camera_position = _head.position
	_original_camera_rotation = _head.rotation
	
	# Initialize photo camera position
	_photo_camera_yaw = 0.0
	_photo_camera_pitch = -20.0 * (PI / 180.0)  # Start looking down slightly
	_photo_camera_distance = 3.0
	
	# Hide collision box mesh
	_hide_collision_box_mesh(true)
	
	# Make avatar visible
	if _player_avatar:
		_player_avatar.set_shadow_only_mode(false)
	
	# Disable player input
	input_enabled = false
	
	# Hide UI
	_set_ui_visible(false)

	# Build list of available poses for interactive mode
	_build_pose_lists()

	print("📷 Photo mode enabled!")
	print("  Arrow Keys: Rotate camera")
	print("  Q/R: Zoom in/out")
	print("  C: Take screenshot")
	print("  I: Cycle poses (interactive mode)")
	print("  P: Exit photo mode")


func stop_photo_mode():
	"""Exit photo mode and return to first-person"""
	if not _photo_mode:
		return
	
	_photo_mode = false
	
	# Restore original camera transform
	_head.position = _original_camera_position
	_head.rotation = _original_camera_rotation
	
	# Show collision box mesh again
	_hide_collision_box_mesh(false)
	
	# Return to shadow-only mode
	if _player_avatar:
		_player_avatar.set_shadow_only_mode(true)
	
	# Re-enable player input
	input_enabled = true
	
	# Show UI again
	_set_ui_visible(true)
	
	print("📷 Photo mode ended")


func _update_photo_mode(delta: float):
	"""Update camera position in photo mode based on arrow key input"""
	# Rotate with arrow keys
	if Input.is_key_pressed(KEY_LEFT):
		_photo_camera_yaw += PHOTO_CAMERA_ROTATE_SPEED * delta
	if Input.is_key_pressed(KEY_RIGHT):
		_photo_camera_yaw -= PHOTO_CAMERA_ROTATE_SPEED * delta
	if Input.is_key_pressed(KEY_UP):
		_photo_camera_pitch -= PHOTO_CAMERA_ROTATE_SPEED * delta
		_photo_camera_pitch = clamp(_photo_camera_pitch, -PI / 2 + 0.1, PI / 2 - 0.1)
	if Input.is_key_pressed(KEY_DOWN):
		_photo_camera_pitch += PHOTO_CAMERA_ROTATE_SPEED * delta
		_photo_camera_pitch = clamp(_photo_camera_pitch, -PI / 2 + 0.1, PI / 2 - 0.1)
	
	# Zoom with Q/R
	if Input.is_key_pressed(KEY_Q):
		_photo_camera_distance -= PHOTO_CAMERA_ZOOM_SPEED * delta
		_photo_camera_distance = max(1.0, _photo_camera_distance)
	if Input.is_key_pressed(KEY_R):
		_photo_camera_distance += PHOTO_CAMERA_ZOOM_SPEED * delta
		_photo_camera_distance = min(10.0, _photo_camera_distance)
	
	# Take screenshot with C key
	if Input.is_key_pressed(KEY_C):
		if not _screenshot_taken:  # Prevent multiple screenshots from one press
			_take_screenshot()
			_screenshot_taken = true
	else:
		_screenshot_taken = false

	# Cycle poses with I key (Interactive mode - detect single press, not hold)
	var i_pressed = Input.is_key_pressed(KEY_I)
	if i_pressed and not _i_key_was_pressed:
		_cycle_pose()
	_i_key_was_pressed = i_pressed

	# Exit photo mode with P key (detect single press, not hold)
	var p_pressed = Input.is_key_pressed(KEY_P)
	if p_pressed and not _p_key_was_pressed:
		stop_photo_mode()
		return
	_p_key_was_pressed = p_pressed
	
	# Also exit with Escape key
	if Input.is_key_pressed(KEY_ESCAPE):
		stop_photo_mode()
		return
	
	# Calculate camera position based on yaw, pitch, and distance
	var cam_x = cos(_photo_camera_yaw) * cos(_photo_camera_pitch) * _photo_camera_distance
	var cam_y = sin(_photo_camera_pitch) * _photo_camera_distance + 1.0  # +1.0 for player center height
	var cam_z = sin(_photo_camera_yaw) * cos(_photo_camera_pitch) * _photo_camera_distance
	
	_head.position = Vector3(cam_x, cam_y, cam_z)
	
	# Look at player center
	var player_center_global = global_position + Vector3(0, 1.0, 0)
	_head.look_at(player_center_global, Vector3.UP)
	
	# Update avatar sprite direction based on camera position
	if _player_avatar:
		var player_forward = -global_transform.basis.z
		player_forward.y = 0
		
		var cam_direction = (_head.global_position - global_position).normalized()
		cam_direction.y = 0
		
		var dot = player_forward.normalized().dot(cam_direction.normalized())
		_player_avatar.force_sprite_direction(dot > 0)


func _take_screenshot():
	"""Take a screenshot and save to user directory"""
	# Get viewport
	var viewport = get_viewport()
	
	# Capture image
	var img = viewport.get_texture().get_image()
	
	# Generate filename with timestamp
	var datetime = Time.get_datetime_dict_from_system()
	var filename = "camera_%04d%02d%02d_%02d%02d%02d.png" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]
	
	# Save to user directory
	var path = "user://camera/" + filename
	
	# Create screenshots directory if it doesn't exist
	DirAccess.make_dir_absolute("user://camera")
	
	# Save image
	img.save_png(path)
	
	print("📸 Screenshot saved: %s" % path)
	print("   Location: %s" % ProjectSettings.globalize_path(path))


func _build_pose_lists():
	"""
	Dynamically scan player_avatars folder for all available poses
	Separates front-facing and back-facing (_back) poses
	"""
	_photo_front_poses.clear()
	_photo_back_poses.clear()
	_photo_current_front_index = 0
	_photo_current_back_index = 0

	var race = PlayerData.race
	var gender = PlayerData.gender
	var avatar_dir = "res://assets/art/player_avatars/"

	# Build pattern to match: race_gender_*.png
	var prefix = "%s_%s_" % [race, gender]

	# Scan directory for matching files
	var dir = DirAccess.open(avatar_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			# Check if this file matches our race/gender
			if file_name.begins_with(prefix) and file_name.ends_with(".png"):
				# Extract the pose name (everything between prefix and .png)
				var pose_part = file_name.substr(prefix.length(), file_name.length() - prefix.length() - 4)

				# Skip if it's just the base sprite (no pose suffix)
				if pose_part == "":
					file_name = dir.get_next()
					continue

				# Separate front and back poses
				if pose_part.ends_with("_back"):
					# Back-facing pose
					_photo_back_poses.append(file_name)
				else:
					# Front-facing pose (includes _run, _jumping, _thumbs_up, etc.)
					_photo_front_poses.append(file_name)

			file_name = dir.get_next()

		dir.list_dir_end()

	# Sort for consistent ordering
	_photo_front_poses.sort()
	_photo_back_poses.sort()

	print("📷 Photo poses found:")
	print("  Front poses: %d" % _photo_front_poses.size())
	for pose in _photo_front_poses:
		print("    - %s" % pose)
	print("  Back poses: %d" % _photo_back_poses.size())
	for pose in _photo_back_poses:
		print("    - %s" % pose)


func _cycle_pose():
	"""Cycle to next pose in photo mode (press I key)"""
	if not _player_avatar:
		return

	# Determine if we're currently showing back sprite
	var is_showing_back = not _player_avatar._current_sprite_is_front

	var race = PlayerData.race
	var gender = PlayerData.gender
	var avatar_dir = "res://assets/art/player_avatars/"

	if is_showing_back:
		# Cycle through back poses
		if _photo_back_poses.size() == 0:
			print("📷 No back poses available")
			return

		_photo_current_back_index = (_photo_current_back_index + 1) % _photo_back_poses.size()
		var pose_file = _photo_back_poses[_photo_current_back_index]
		var pose_path = avatar_dir + pose_file

		print("📷 Cycling to back pose: %s (%d/%d)" % [pose_file, _photo_current_back_index + 1, _photo_back_poses.size()])

		# Load and apply texture
		if ResourceLoader.exists(pose_path):
			var texture = load(pose_path)
			if texture and _player_avatar._sprite:
				_player_avatar._sprite.texture = texture

				# Update shader if present
				if _player_avatar._sprite.material_override:
					_player_avatar._sprite.material_override.set_shader_parameter("texture_albedo", texture)
	else:
		# Cycle through front poses
		if _photo_front_poses.size() == 0:
			print("📷 No front poses available")
			return

		_photo_current_front_index = (_photo_current_front_index + 1) % _photo_front_poses.size()
		var pose_file = _photo_front_poses[_photo_current_front_index]
		var pose_path = avatar_dir + pose_file

		print("📷 Cycling to front pose: %s (%d/%d)" % [pose_file, _photo_current_front_index + 1, _photo_front_poses.size()])

		# Load and apply texture
		if ResourceLoader.exists(pose_path):
			var texture = load(pose_path)
			if texture and _player_avatar._sprite:
				_player_avatar._sprite.texture = texture

				# Update shader if present
				if _player_avatar._sprite.material_override:
					_player_avatar._sprite.material_override.set_shader_parameter("texture_albedo", texture)


func _set_ui_visible(visible: bool):
	"""Show/hide UI during photo mode"""
	if visible:
		# Restoring - only show the elements we specifically hid
		for element in _hidden_ui_elements:
			if is_instance_valid(element):
				element.visible = true
		_hidden_ui_elements.clear()
	else:
		# Hiding - track what we hide so we can restore only those
		_hidden_ui_elements.clear()
		
		# Hide hotbar (it's a child of CharacterAvatar, not a sibling)
		var hotbar = get_node_or_null("HotBar")
		if hotbar and hotbar.visible:
			hotbar.visible = false
			_hidden_ui_elements.append(hotbar)
		
		# Hide inventory UI (includes bento box)
		var inventory = get_node_or_null("Inventory")
		if inventory and inventory.visible:
			inventory.visible = false
			_hidden_ui_elements.append(inventory)
		
		# Hide UI elements in Game node (TimeDisplay, PartyUI, etc.)
		var game = get_tree().root.get_node_or_null("Main/Game")
		if game:
			for child in game.get_children():
				if child is Control or child is CanvasLayer:
					# Don't hide the console if it's open (user might need it)
					if child.has_method("is_open") and child.is_open():
						continue
					# Only hide if currently visible
					if child.visible:
						child.visible = false
						_hidden_ui_elements.append(child)


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


## Teleport/Gravity Control Functions

func disable_gravity() -> void:
	"""Temporarily disable gravity (used during teleportation)"""
	_gravity_disabled = true
	_velocity.y = 0  # Stop vertical movement
	print("Gravity disabled for teleport")


func enable_gravity() -> void:
	"""Re-enable gravity after teleportation"""
	_gravity_disabled = false
	print("Gravity re-enabled")


## Player HP and Combat Functions

## Get currently equipped weapon from inventory
func _get_equipped_weapon():
	"""Get the player's equipped weapon item data"""
	var inventory = get_node_or_null("Inventory")
	if not inventory:
		return null

	if inventory.has_method("get_player_equipped_weapon"):
		return inventory.get_player_equipped_weapon()

	return null


func _get_depth_adjusted_gravity() -> float:
	"""
	Calculate gravity based on player depth.

	STORY: The Undervoid civilizations dug so deep they damaged gravity itself.
	The deeper you go, the weaker gravity becomes (opposite of normal physics).

	- Surface (Y=0): Normal gravity (9.8)
	- Every 100 blocks down: Reduce by 0.1
	- Y=-500: Gravity = 9.3 (noticeably lighter)

	This explains why Sky Ruins existed: they were gravity generators keeping the planet stable.
	Now they're failing, and the world is slowly breaking apart.
	"""
	var depth = abs(min(global_position.y, 0.0))  # Only count negative Y (underground)
	var depth_in_hundreds = depth / 100.0
	var gravity_reduction = depth_in_hundreds * GRAVITY_REDUCTION_PER_100_BLOCKS

	var adjusted_gravity = gravity - gravity_reduction
	return max(adjusted_gravity, MIN_GRAVITY)  # Don't go below minimum


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

	# Calculate effective defense (base defense + Stone Skin bonus if equipped)
	var effective_defense = defense

	# ⚡ SKYSHARD POWER: Stone Skin (+50% defense when equipped)
	var equipped_weapon = _get_equipped_weapon()
	if equipped_weapon and equipped_weapon.has_power("stone_skin"):
		effective_defense = int(defense * 1.5)  # +50% defense
		print("🛡️ Stone Skin active! Defense boosted: %d → %d" % [defense, effective_defense])

	# Apply defense (same formula as entities)
	var actual_damage = max(1, amount - int(amount * (effective_defense / 100.0)))

	current_hp -= actual_damage
	current_hp = max(0, current_hp)

	hp_changed.emit(current_hp, max_hp)

	print("Player took %d damage (HP: %d/%d)" % [actual_damage, current_hp, max_hp])

	# Check for low health warnings (play once each at 15%, 10%, 5%)
	var health_percent = (float(current_hp) / float(max_hp)) * 100.0
	if health_percent <= 5.0 and not _low_health_5_played and _low_health_sound:
		_low_health_sound.play()
		_low_health_5_played = true
		print("⚠️ CRITICAL HEALTH: 5%!")
	elif health_percent <= 10.0 and not _low_health_10_played and _low_health_sound:
		_low_health_sound.play()
		_low_health_10_played = true
		print("⚠️ LOW HEALTH: 10%!")
	elif health_percent <= 15.0 and not _low_health_15_played and _low_health_sound:
		_low_health_sound.play()
		_low_health_15_played = true
		print("⚠️ LOW HEALTH: 15%!")

	# Check for death
	if current_hp <= 0:
		die()


## Heal the player
func heal(amount: int) -> void:
	if not is_alive:
		return

	current_hp += amount
	current_hp = min(max_hp, current_hp)

	# Reset low health warnings when healed above thresholds
	var health_percent = (float(current_hp) / float(max_hp)) * 100.0
	if health_percent > 15.0:
		_low_health_15_played = false
	if health_percent > 10.0:
		_low_health_10_played = false
	if health_percent > 5.0:
		_low_health_5_played = false

	hp_changed.emit(current_hp, max_hp)
	print("Player healed %d HP (HP: %d/%d)" % [amount, current_hp, max_hp])


## Activate Wind Dash power (called by weapons)
func activate_wind_dash() -> void:
	"""Start a 3-second speed boost"""
	_wind_dash_active = true
	_wind_dash_time = 3.0
	print("💨 Wind Dash activated! Speed doubled for 3 seconds!")


## Performance optimization: Refresh entity cache
func _refresh_entity_cache() -> void:
	"""Refresh the cached entity list (called every 0.5s instead of every frame)"""
	_cached_entities = get_tree().get_nodes_in_group("entities")


## Apply Flame Aura damage to nearby enemies (passive power)
func _apply_flame_aura() -> void:
	"""Burn all nearby enemies within 4 blocks"""
	const FLAME_RADIUS = 4.0
	const FLAME_DAMAGE = 5

	# Use cached entities instead of querying every time (60x performance improvement!)
	var burned_count = 0

	for entity in _cached_entities:
		# Skip freed/invalid entities
		if not is_instance_valid(entity):
			continue
		
		# Skip if not alive or not enemy
		if not entity.is_alive or entity.team != EntityBase.Team.ENEMY:
			continue

		# Check if within flame aura radius
		var distance = entity.global_position.distance_to(global_position)
		if distance <= FLAME_RADIUS:
			entity.take_damage(FLAME_DAMAGE, self)
			burned_count += 1

	if burned_count > 0:
		print("🔥 Flame Aura! Burned %d nearby enemies for %d damage each" % [burned_count, FLAME_DAMAGE])


## Create flame aura visual effect
func _create_flame_aura_visual() -> void:
	"""Create a glowing orange/fire sphere around the player"""
	if _flame_aura_visual:
		return  # Already exists
	
	_flame_aura_visual = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 1.5  # 3-block diameter (1.5 radius = 3 blocks wide)
	sphere_mesh.height = 3.0
	sphere_mesh.radial_segments = 24
	sphere_mesh.rings = 16
	_flame_aura_visual.mesh = sphere_mesh
	
	# Create fiery orange material with transparency and emission
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.5, 0.1, 0.005)  # Orange/red, very see-through
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.4, 0.0)  # Bright fire orange
	material.emission_energy_multiplier = 2.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible from inside
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # Additive blending for glow effect
	_flame_aura_visual.material_override = material
	
	add_child(_flame_aura_visual)
	
	# Animate pulsing effect
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(_flame_aura_visual, "scale", Vector3(1.1, 1.1, 1.1), 0.8)
	tween.tween_property(_flame_aura_visual, "scale", Vector3(0.9, 0.9, 0.9), 0.8)


## Remove flame aura visual effect
func _remove_flame_aura_visual() -> void:
	"""Remove the flame aura visual when power is unequipped"""
	if _flame_aura_visual:
		_flame_aura_visual.queue_free()
		_flame_aura_visual = null


## Update flame aura visual (check if should be visible)
func _update_flame_aura_visual() -> void:
	"""Show/hide flame aura based on equipped items"""
	var equipped_weapon = _get_equipped_weapon()
	var has_flame_aura = equipped_weapon and equipped_weapon.has_power("flame_aura")

	if has_flame_aura and not _flame_aura_visual:
		_create_flame_aura_visual()
	elif not has_flame_aura and _flame_aura_visual:
		_remove_flame_aura_visual()


## Ring of Thorns system - Orbiting projectiles that auto-attack
func _update_ring_of_thorns(delta: float) -> void:
	"""Manage orbiting thorns when Ring of Thorns is equipped"""
	var has_ring = _has_ring_of_thorns()

	# Create thorns if ring is equipped and thorns don't exist
	if has_ring and _thorn_orbs.is_empty():
		_create_thorn_orbs()
	# Remove thorns if ring is not equipped
	elif not has_ring and not _thorn_orbs.is_empty():
		_remove_thorn_orbs()

	# Update attack timer and launch thorns at enemies
	if has_ring and not _thorn_orbs.is_empty():
		_thorn_attack_timer += delta
		if _thorn_attack_timer >= THORN_ATTACK_INTERVAL:
			_thorn_attack_timer = 0.0
			_launch_thorn_at_nearest_enemy()


func _has_ring_of_thorns() -> bool:
	"""Check if player has Ring of Thorns as active item"""
	if not _hotbar:
		return false

	var selected_item = _hotbar.get_selected_item()
	if not selected_item:
		return false

	# Ring of Thorns is item ID 46, TYPE_ITEM = 1
	var has_ring = (selected_item.id == 46 and selected_item.type == 1)
	if selected_item.id == 46:
		print("[Ring DEBUG] Item 46 detected! Type: %d (0=BLOCK, 1=ITEM), Has ring: %s" % [selected_item.type, has_ring])
	return has_ring


func _create_thorn_orbs() -> void:
	"""Create 3 orbiting thorn projectiles"""
	const Thorn = preload("res://blocky_game/projectiles/thorn.gd")

	print("🌿 Creating Ring of Thorns - spawning 3 thorns...")

	for i in range(3):
		var thorn = Node3D.new()
		thorn.set_script(Thorn)

		# Set orbit parameters (after adding to scene so script is active)
		add_child(thorn)
		thorn.owner_entity = self
		thorn.orbit_center = global_position
		thorn.orbit_angle = (i * TAU / 3.0)  # Evenly space 3 thorns around circle
		thorn.orbit_radius = 1.5

		_thorn_orbs.append(thorn)

		print("  - Thorn %d created at position: %v" % [i + 1, thorn.global_position])

	print("🌿 Ring of Thorns activated - 3 thorns orbiting!")
	print("  - Total thorn count: %d" % _thorn_orbs.size())
	print("  - Player position: %v" % global_position)


func _remove_thorn_orbs() -> void:
	"""Remove all thorn orbs"""
	for thorn in _thorn_orbs:
		if is_instance_valid(thorn):
			thorn.queue_free()
	_thorn_orbs.clear()
	print("🌿 Ring of Thorns deactivated")


func _launch_thorn_at_nearest_enemy() -> void:
	"""Find nearest enemy and launch a thorn at it"""
	# Refresh entity cache if needed
	if _cached_entities.is_empty():
		_refresh_entity_cache()

	# Find nearest enemy within range
	var nearest_enemy = null
	var nearest_distance = THORN_ATTACK_RANGE

	for entity in _cached_entities:
		if not is_instance_valid(entity):
			continue

		# Skip if not an enemy
		if "team" not in entity or entity.team != 2:  # 2 = ENEMY
			continue

		var distance = global_position.distance_to(entity.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = entity

	# Launch a thorn if we found an enemy
	if nearest_enemy and not _thorn_orbs.is_empty():
		# Find first thorn in ORBITING mode
		for thorn in _thorn_orbs:
			if is_instance_valid(thorn) and thorn.mode == 0:  # 0 = ORBITING
				thorn.launch_at_enemy(nearest_enemy)
				print("🌿 Thorn launched at %s" % nearest_enemy.entity_name)
				break


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


# --- Fish interaction stubs for AnimalSpawner compatibility ---
func set_nearby_fish(fish: Node3D) -> void:
	var avatar_interaction = get_node_or_null("avatar_interaction")
	if avatar_interaction and avatar_interaction.has_method("set_nearby_fish"):
		avatar_interaction.set_nearby_fish(fish)
	else:
		print("[WARN] set_nearby_fish: avatar_interaction node or method missing")

func clear_nearby_fish() -> void:
	var avatar_interaction = get_node_or_null("avatar_interaction")
	if avatar_interaction and avatar_interaction.has_method("clear_nearby_fish"):
		avatar_interaction.clear_nearby_fish()
	else:
		print("[WARN] clear_nearby_fish: avatar_interaction node or method missing")
