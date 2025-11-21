extends GroundEntity

const SimplePathfinding = preload("res://blocky_game/utils/simple_pathfinding.gd")

## Cat (Black) - Ambient peaceful animal
## Wanders, sits frequently, shows interest when player has fish
## Has 2 walk animation frames + 1 sit frame
## Now includes edge detection to avoid falling off sky islands!

enum State {
	WANDERING,
	SITTING,
	INTERESTED  # Following player with fish
}

var _state: State = State.WANDERING
var _wander_direction := Vector3.ZERO
var _wander_timer := 0.0
var _sit_timer := 0.0
var _walk_anim_timer := 0.0
var _current_walk_frame := 1  # 1 or 2
var _player: Node = null
var _interest_check_timer := 0.0
var _terrain: Node = null  # Reference to voxel terrain for edge detection

const WANDER_INTERVAL_MIN = 2.0
const WANDER_INTERVAL_MAX = 4.0
const SIT_DURATION_MIN = 3.0
const SIT_DURATION_MAX = 6.0
const SIT_CHANCE = 0.5  # 50% chance to sit after wandering
const WALK_ANIM_SPEED = 0.3  # Switch walk frame every 0.3 seconds
const INTEREST_CHECK_INTERVAL = 1.0  # Check for fish every second
const INTEREST_DISTANCE = 10.0  # How close to detect fish
const INTEREST_FOLLOW_DISTANCE = 2.0  # Stop following when this close


func _ready():
	# Set entity properties
	entity_id = "cat"
	entity_name = "Cat"
	team = Team.NEUTRAL  # Peaceful ambient animal
	max_hp = 1000  # Effectively invincible (not huntable)
	attack_damage = 0  # Doesn't attack
	defense = 100  # Takes no damage
	movement_speed = 2.0  # Slower than rabbit
	current_hp = max_hp

	# Call parent ready
	super._ready()

	# Get terrain reference for edge detection
	_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")

	# Create sprite (start with sit pose)
	_sprite = _create_sprite("res://assets/art/animals/cat_sit.png", 0.003)

	# No health bar for peaceful animals

	# Set collision box size for cat (small)
	set_collision_box(Vector3(0.25, 0.4, 0.25))

	# Start sitting
	_start_sitting()

	# Find player
	_find_player()


func _find_player():
	"""Find player in scene"""
	_player = get_tree().get_first_node_in_group("player")


func _process(delta: float):
	if not is_alive:
		return

	# Find player if we don't have one
	if _player == null:
		_find_player()

	# Check for fish interest periodically
	_interest_check_timer += delta
	if _interest_check_timer >= INTEREST_CHECK_INTERVAL:
		_interest_check_timer = 0.0
		_check_fish_interest()

	match _state:
		State.WANDERING:
			_handle_wandering(delta)
		State.SITTING:
			_handle_sitting(delta)
		State.INTERESTED:
			_handle_interested(delta)


func _check_fish_interest():
	"""Check if player is nearby with fish in active hotbar slot"""
	if not _player:
		return

	var distance = global_position.distance_to(_player.global_position)
	if distance > INTEREST_DISTANCE:
		# Player too far, go back to normal behavior
		if _state == State.INTERESTED:
			_state = State.WANDERING
			_start_new_wander()
		return

	# Check if player has fish in active hotbar slot
	var hotbar = _player.get_node_or_null("HotBar")
	if hotbar:
		var selected_item = hotbar.get_selected_item()
		if selected_item != null and selected_item.type == 1 and selected_item.id == 26:  # Fish (ID 26)
			# Player has fish! Show interest
			if _state != State.INTERESTED:
				_state = State.INTERESTED
				print("🐱 %s is interested in the fish!" % entity_name)
		else:
			# No fish, go back to normal
			if _state == State.INTERESTED:
				_state = State.WANDERING
				_start_new_wander()


func _handle_wandering(delta: float):
	# Update walk animation
	_walk_anim_timer += delta
	if _walk_anim_timer >= WALK_ANIM_SPEED:
		_walk_anim_timer = 0.0
		_current_walk_frame = 2 if _current_walk_frame == 1 else 1

		# Update sprite
		if _sprite:
			var sprite_path = "res://assets/art/animals/cat_walk_%d.png" % _current_walk_frame
			var texture = load(sprite_path)
			if texture:
				_sprite.texture = texture

	# Count down wander timer
	_wander_timer -= delta

	if _wander_timer <= 0:
		# Decide: sit or start new wander?
		if randf() < SIT_CHANCE:
			_start_sitting()
		else:
			_start_new_wander()
	else:
		# Continue moving in current direction
		var movement_input = _wander_direction * movement_speed
		apply_ground_movement(delta, movement_input)


func _handle_sitting(delta: float):
	# Show sit sprite (only set once at start of sit)
	if _sit_timer == SIT_DURATION_MIN:
		if _sprite:
			var texture = load("res://assets/art/animals/cat_sit.png")
			if texture:
				_sprite.texture = texture

	# Count down sit timer
	_sit_timer -= delta

	if _sit_timer <= 0:
		# Done sitting, start wandering
		_state = State.WANDERING
		_start_new_wander()
	else:
		# Stay still while sitting
		apply_ground_movement(delta, Vector3.ZERO)


func _handle_interested(delta: float):
	"""Follow player slowly when they have fish"""
	if not _player:
		_state = State.WANDERING
		_start_new_wander()
		return

	var to_player = _player.global_position - global_position
	var distance = to_player.length()

	if distance > INTEREST_FOLLOW_DISTANCE:
		# Move toward player slowly
		var direction = to_player.normalized()
		direction.y = 0  # Only horizontal movement

		var movement_input = direction * movement_speed * 0.7  # 70% speed when interested

		# Update walk animation while following
		_walk_anim_timer += delta
		if _walk_anim_timer >= WALK_ANIM_SPEED:
			_walk_anim_timer = 0.0
			_current_walk_frame = 2 if _current_walk_frame == 1 else 1

			if _sprite:
				var sprite_path = "res://assets/art/animals/cat_walk_%d.png" % _current_walk_frame
				var texture = load(sprite_path)
				if texture:
					_sprite.texture = texture

		apply_ground_movement(delta, movement_input)
	else:
		# Close enough, sit and watch
		if _sprite:
			var texture = load("res://assets/art/animals/cat_sit.png")
			if texture:
				_sprite.texture = texture

		apply_ground_movement(delta, Vector3.ZERO)


func _start_new_wander():
	_state = State.WANDERING
	_wander_timer = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)

	# Pick a safe direction (with edge detection for sky islands)
	var safe_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()

	# Try a few times to find a safe direction
	for attempt in range(3):
		if SimplePathfinding.is_safe_to_walk(global_position, safe_direction, _terrain, 2.0):
			break  # Found a safe direction!

		# Try another random direction
		safe_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()

	_wander_direction = safe_direction


func _start_sitting():
	_state = State.SITTING
	_sit_timer = randf_range(SIT_DURATION_MIN, SIT_DURATION_MAX)


func _on_death() -> void:
	# Cats are peaceful and shouldn't die, but just in case
	super._on_death()
	queue_free()
