extends EntityBase
class_name GroundEntity

## GroundEntity - Base class for ground-based entities
## Handles gravity, terrain collision, and ground movement
## Used by: rats, goblins, zombies, etc.

@export var gravity := 20.0
@export var can_break_blocks := true  # Enemies can break blocks by default
@export var block_break_cooldown := 2.0  # 2 seconds between block hits

var _velocity := Vector3.ZERO
var _grounded := false
var _box_mover := VoxelBoxMover.new()
var _terrain: VoxelTerrain = null
var _collision_size := Vector3(0.6, 0.6, 0.6)  # Default collision box size
var _collision_offset := Vector3(-0.3, -0.3, -0.3)  # Centered collision box

# Block breaking system
var _block_damage: Dictionary = {}  # {Vector3i: int} - tracks hits per block
var _block_break_timer := 0.0
var _last_blocked_position := Vector3.ZERO
var _blocked_frame_count := 0
const HITS_TO_BREAK := 4  # Blocks need 4 hits to break
const BLOCKED_FRAMES_THRESHOLD := 3  # Must be blocked for 3 frames before trying to break


func _ready():
	super._ready()

	# Setup collision
	_box_mover.set_collision_mask(1)
	_box_mover.set_step_climbing_enabled(true)
	_box_mover.set_max_step_height(2.0)  # Can climb up to 2 blocks

	# Find terrain
	_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")
	if _terrain == null:
		push_warning("%s: Could not find VoxelTerrain" % entity_name)


## Call this in _process to apply gravity and movement
## velocity_input should be the desired horizontal movement (x, z only)
func apply_ground_movement(delta: float, velocity_input: Vector3) -> void:
	if not is_alive or _terrain == null:
		return

	# Handle auto-regeneration (1 HP every 3 minutes)
	if current_hp < max_hp:
		_regen_timer += delta
		if _regen_timer >= REGEN_INTERVAL:
			_regen_timer = 0.0
			heal(1)

	# Update block break timer
	if _block_break_timer > 0:
		_block_break_timer -= delta

	# Set horizontal velocity from input
	_velocity.x = velocity_input.x
	_velocity.z = velocity_input.z

	# Apply gravity
	_velocity.y -= gravity * delta

	# Calculate motion for this frame
	var motion := _velocity * delta
	var aabb := AABB(_collision_offset, _collision_size)

	# Check if area is loaded
	var vt := _terrain.get_voxel_tool()
	if vt.is_area_editable(AABB(aabb.position + global_position, aabb.size)):
		var prev_motion := motion
		var desired_horizontal_motion := Vector3(prev_motion.x, 0, prev_motion.z)

		# Get motion with collision detection
		motion = _box_mover.get_motion(global_position, motion, aabb, _terrain)
		var actual_horizontal_motion := Vector3(motion.x, 0, motion.z)

		# Apply motion
		global_translate(motion)

		# Check if grounded (just landed)
		if absf(motion.y) < 0.001 and prev_motion.y < -0.001:
			_grounded = true
			_velocity.y = 0  # Stop falling

		# Stepped up a block
		if _box_mover.has_stepped_up():
			motion.y = 0
			_grounded = true

		# Started moving vertically (jumped or fell)
		elif absf(motion.y) > 0.001:
			_grounded = false

		# BLOCK BREAKING LOGIC
		# Check if enemy is blocked (wanted to move but couldn't)
		if can_break_blocks and team == Team.ENEMY and desired_horizontal_motion.length() > 0.1:
			var blocked = actual_horizontal_motion.length() < desired_horizontal_motion.length() * 0.3

			if blocked:
				_blocked_frame_count += 1

				# After being blocked for several frames, try to break through
				if _blocked_frame_count >= BLOCKED_FRAMES_THRESHOLD and _block_break_timer <= 0:
					_try_break_blocking_block(desired_horizontal_motion.normalized())
			else:
				_blocked_frame_count = 0


## Check if entity is on the ground
func is_grounded() -> bool:
	return _grounded


## Get current velocity
func get_velocity() -> Vector3:
	return _velocity


## Set collision box size (for different sized enemies)
func set_collision_box(size: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	_collision_size = size
	if offset == Vector3.ZERO:
		# Auto-center if no offset provided
		_collision_offset = -size * 0.5
	else:
		_collision_offset = offset


## Find ground level below a position (for spawning)
func find_ground_position(start_pos: Vector3, max_distance: float = 10.0) -> Vector3:
	if _terrain == null:
		return start_pos

	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	# Raycast downward to find ground
	var hit = vt.raycast(start_pos, Vector3.DOWN, max_distance)
	if hit != null:
		# Place entity on top of the block
		return Vector3(hit.position) + Vector3(0.5, 1.0, 0.5)

	return start_pos


func create_billboard_shadow(texture_path: String, shadow_scale: Vector3 = Vector3(1.2, 1.2, 1.2)) -> void:
	var shadow_mesh = QuadMesh.new()
	shadow_mesh.size = Vector2(1, 1)
	var shadow_instance = MeshInstance3D.new()
	shadow_instance.mesh = shadow_mesh
	shadow_instance.scale = shadow_scale
	shadow_instance.position = Vector3(0, 0.01, 0) # Slightly above ground
	var shadow_material = StandardMaterial3D.new()
	shadow_material.albedo_texture = load(texture_path)
	shadow_material.albedo_color = Color(0, 0, 0, 0.5) # Black, semi-transparent
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow_instance.material_override = shadow_material
	shadow_instance.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(shadow_instance)


## Try to break the block that's blocking this entity
func _try_break_blocking_block(direction: Vector3) -> void:
	if _terrain == null:
		return

	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	# Raycast forward from entity position at multiple heights to find blocking blocks
	var start_pos = global_position
	var blocking_blocks: Array[Vector3i] = []

	# Check at feet, waist, and head height
	for y_offset in [0.0, 0.5, 1.0]:
		var ray_start = start_pos + Vector3(0, y_offset, 0)
		var hit = vt.raycast(ray_start, direction, 2.0)

		if hit != null:
			var block_pos = Vector3i(hit.position)
			if not blocking_blocks.has(block_pos):
				blocking_blocks.append(block_pos)

	if blocking_blocks.is_empty():
		return

	# Hit all blocking blocks
	for block_pos in blocking_blocks:
		var voxel_id = vt.get_voxel(block_pos)

		# Don't break air or already broken blocks
		if voxel_id == 0:
			continue

		# Track damage to this block
		if not _block_damage.has(block_pos):
			_block_damage[block_pos] = 0

		_block_damage[block_pos] += 1

		print("🔨 %s damages block at %s (Hit %d/%d)" % [
			entity_name, block_pos, _block_damage[block_pos], HITS_TO_BREAK
		])

		# Break block after enough hits
		if _block_damage[block_pos] >= HITS_TO_BREAK:
			vt.set_voxel(block_pos, 0)
			_block_damage.erase(block_pos)
			print("💥 %s BROKE THROUGH block at %s!" % [entity_name, block_pos])

	# Reset cooldown
	_block_break_timer = block_break_cooldown
	_blocked_frame_count = 0


## Instantly break blocks between enemy and target (used during attacks)
## Much more aggressive than the gradual block-breaking system
func break_blocks_to_target(target: Node, max_distance: float = 3.0) -> void:
	if not can_break_blocks or team != Team.ENEMY or _terrain == null:
		return

	if target == null or not is_instance_valid(target):
		return

	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	# Raycast from enemy to target
	var direction = (target.global_position - global_position).normalized()
	var distance = global_position.distance_to(target.global_position)
	var raycast_dist = min(distance, max_distance)

	# Check at multiple heights
	var blocks_broken = 0
	for y_offset in [0.0, 0.5, 1.0]:
		var ray_start = global_position + Vector3(0, y_offset, 0)
		var hit = vt.raycast(ray_start, direction, raycast_dist)

		if hit != null:
			var block_pos = Vector3i(hit.position)
			var voxel_id = vt.get_voxel(block_pos)

			# Destroy block if it's not air
			if voxel_id != 0:
				vt.set_voxel(block_pos, 0)
				blocks_broken += 1
				print("💥 %s SMASHED block at %s!" % [entity_name, block_pos])

	if blocks_broken > 0:
		print("  🔨 %s destroyed %d blocks attacking through terrain!" % [entity_name, blocks_broken])
