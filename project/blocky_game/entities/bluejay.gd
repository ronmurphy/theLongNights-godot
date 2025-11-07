extends FlyingEntity

## Bluejay (BirdB) - Ambient peaceful flying bird
## Flies in wider circles at higher altitude than swallow
## Has 2 flight animation frames

enum State {
	FLYING,
	PERCHED
}

var _state: State = State.FLYING
var _flight_timer := 0.0
var _perch_timer := 0.0
var _flight_anim_timer := 0.0
var _current_flight_frame := 1  # 1 or 2
var _flight_center: Vector3 = Vector3.ZERO
var _circle_angle := 0.0
var _flight_radius := 12.0  # Wider circles than swallow
var _flight_height := 25.0  # Fly higher than swallow

const FLIGHT_DURATION_MIN = 15.0  # Flies longer than swallow
const FLIGHT_DURATION_MAX = 30.0
const PERCH_DURATION_MIN = 2.0  # Perches for shorter time
const PERCH_DURATION_MAX = 5.0
const PERCH_CHANCE = 0.15  # 15% chance to perch (less than swallow)
const FLIGHT_ANIM_SPEED = 0.2  # Slightly slower wing flaps than swallow
const CIRCLE_SPEED = 0.4  # Slower, more graceful circles
const FLIGHT_SPEED = 3.5  # Slightly slower than swallow


func _ready():
	# Set entity properties
	entity_id = "bluejay"
	entity_name = "Bluejay"
	team = Team.NEUTRAL  # Peaceful ambient animal
	max_hp = 1000  # Effectively invincible
	attack_damage = 0  # Doesn't attack
	defense = 100  # Takes no damage
	movement_speed = FLIGHT_SPEED
	current_hp = max_hp

	# Flying entity properties
	float_height = 0.0  # We'll manage height ourselves
	bob_amplitude = 0.15  # Gentler bobbing than swallow
	bob_frequency = 2.0  # Slower, more graceful

	# Call parent ready
	super._ready()

	# Create sprite (start with flight frame 1)
	_sprite = _create_sprite("res://assets/art/animals/birdB_1.png", 0.002)

	# No health bar for peaceful animals
	# _create_health_bar()

	# Start flying
	_start_flying()


func _process(delta: float):
	if not is_alive:
		return

	match _state:
		State.FLYING:
			_handle_flying(delta)
		State.PERCHED:
			_handle_perched(delta)


func _handle_flying(delta: float):
	# Update flight animation
	_flight_anim_timer += delta
	if _flight_anim_timer >= FLIGHT_ANIM_SPEED:
		_flight_anim_timer = 0.0
		_current_flight_frame = 2 if _current_flight_frame == 1 else 1

		# Update sprite
		if _sprite:
			var sprite_path = "res://assets/art/animals/birdB_%d.png" % _current_flight_frame
			var texture = load(sprite_path)
			if texture:
				_sprite.texture = texture

	# Apply bobbing
	apply_bob_movement(delta)

	# Circle around flight center
	_circle_angle += CIRCLE_SPEED * delta
	if _circle_angle > TAU:
		_circle_angle -= TAU

	var target_x = _flight_center.x + cos(_circle_angle) * _flight_radius
	var target_z = _flight_center.z + sin(_circle_angle) * _flight_radius
	var target_y = _flight_center.y + _flight_height + get_bob_offset()

	var target_pos = Vector3(target_x, target_y, target_z)

	# Smoothly move toward target
	global_position = global_position.lerp(target_pos, delta * 1.5)  # Smoother movement

	# Count down flight timer
	_flight_timer -= delta

	if _flight_timer <= 0:
		# Decide: perch or start new flight?
		if randf() < PERCH_CHANCE:
			_start_perching()
		else:
			_start_flying()


func _handle_perched(delta: float):
	# Show first frame while perched (bird sitting still)
	if _sprite:
		var texture = load("res://assets/art/animals/birdB_1.png")
		if texture and _sprite.texture != texture:
			_sprite.texture = texture

	# Count down perch timer
	_perch_timer -= delta

	if _perch_timer <= 0:
		# Done perching, take off
		_start_flying()


func _start_flying():
	_state = State.FLYING
	_flight_timer = randf_range(FLIGHT_DURATION_MIN, FLIGHT_DURATION_MAX)

	# Set new flight center near current position
	_flight_center = global_position
	_flight_center.y = randf_range(20.0, 50.0)  # Flies higher than swallow (10-30)

	# Random starting angle
	_circle_angle = randf() * TAU

	# Vary circle radius (larger than swallow)
	_flight_radius = randf_range(10.0, 18.0)


func _start_perching():
	_state = State.PERCHED
	_perch_timer = randf_range(PERCH_DURATION_MIN, PERCH_DURATION_MAX)

	# Find ground to perch on
	var terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")
	if terrain:
		var vt = terrain.get_voxel_tool()

		# Raycast down to find ground
		var ray_start = global_position
		var ray_end = global_position - Vector3(0, 100, 0)  # Longer ray since we fly higher
		var hit = vt.raycast(ray_start, (ray_end - ray_start).normalized(), 100.0)

		if hit:
			# Perch slightly above ground
			global_position.y = Vector3(hit.position).y + 0.5
		else:
			# No ground found, skip perching
			_start_flying()


func _on_death() -> void:
	# Birds are peaceful and shouldn't die, but just in case
	super._on_death()
	queue_free()
