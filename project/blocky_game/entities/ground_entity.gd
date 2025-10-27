extends EntityBase
class_name GroundEntity

## GroundEntity - Base class for ground-based entities
## Handles gravity, terrain collision, and ground movement
## Used by: rats, goblins, zombies, etc.

@export var gravity := 20.0

var _velocity := Vector3.ZERO
var _grounded := false
var _box_mover := VoxelBoxMover.new()
var _terrain: VoxelTerrain = null
var _collision_size := Vector3(0.6, 0.6, 0.6)  # Default collision box size
var _collision_offset := Vector3(-0.3, -0.3, -0.3)  # Centered collision box


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

		# Get motion with collision detection
		motion = _box_mover.get_motion(global_position, motion, aabb, _terrain)

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
