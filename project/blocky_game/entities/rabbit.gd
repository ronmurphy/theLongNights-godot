extends GroundEntity

const SimplePathfinding = preload("res://blocky_game/utils/simple_pathfinding.gd")

## Rabbit - Passive animal that can be hunted
## Wanders, rests, flees when damaged
## Drops rabbit meat (item ID 14) on death
## Now includes edge detection to avoid falling off sky islands!

enum State {
	WANDERING,
	RESTING,
	FLEEING
}

var _state: State = State.WANDERING
var _wander_direction := Vector3.ZERO
var _wander_timer := 0.0
var _rest_timer := 0.0
var _flee_timer := 0.0
var _attacker: Node = null  # Who damaged us (flee away from them)
var _hop_anim_timer := 0.0  # Animation timer for hop frames
var _current_hop_frame := 1  # 1 or 2

const WANDER_INTERVAL_MIN = 2.0
const WANDER_INTERVAL_MAX = 5.0
const REST_DURATION_MIN = 2.0
const REST_DURATION_MAX = 4.0
const REST_CHANCE = 0.3  # 30% chance to rest after wandering
const FLEE_DURATION = 5.0
const FLEE_SPEED_MULTIPLIER = 2.0
const HOP_ANIM_SPEED = 0.2  # Switch hop frame every 0.2 seconds


func _ready():
	# Set entity properties
	entity_id = "rabbit"
	entity_name = "Rabbit"
	team = Team.NEUTRAL  # Passive, but can be attacked
	max_hp = 20
	attack_damage = 0  # Doesn't attack
	defense = 0  # No defense
	movement_speed = 3.0
	current_hp = max_hp

	# Call parent ready
	super._ready()

	# Get terrain reference for edge detection
	_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")

	# Create sprite (start with rest pose)
	_sprite = _create_sprite("res://assets/art/animals/rabbit_rest.png", 0.003)


	# Set collision box size for rabbit (small)
	set_collision_box(Vector3(0.3, 0.3, 0.3))

	# Start wandering
	_start_new_wander()

	# Connect to damage signal to trigger flee behavior
	took_damage.connect(_on_took_damage)


func _process(delta: float):
	if not is_alive:
		return

	match _state:
		State.WANDERING:
			_handle_wandering(delta)
		State.RESTING:
			_handle_resting(delta)
		State.FLEEING:
			_handle_fleeing(delta)


func _handle_wandering(delta: float):
	# Update hop animation
	_hop_anim_timer += delta
	if _hop_anim_timer >= HOP_ANIM_SPEED:
		_hop_anim_timer = 0.0
		_current_hop_frame = 2 if _current_hop_frame == 1 else 1

		# Update sprite
		if _sprite:
			var sprite_path = "res://assets/art/animals/rabbit_move_%d.png" % _current_hop_frame
			var texture = load(sprite_path)
			if texture:
				_sprite.texture = texture

	# Count down wander timer
	_wander_timer -= delta

	if _wander_timer <= 0:
		# Decide: rest or start new wander?
		if randf() < REST_CHANCE:
			_start_resting()
		else:
			_start_new_wander()
	else:
		# Continue moving in current direction
		var movement_input = _wander_direction * movement_speed
		apply_ground_movement(delta, movement_input)


func _handle_resting(delta: float):
	# Show rest sprite
	if _sprite and _rest_timer == REST_DURATION_MIN:  # First frame of rest
		var texture = load("res://assets/art/animals/rabbit_rest.png")
		if texture:
			_sprite.texture = texture

	# Count down rest timer
	_rest_timer -= delta

	if _rest_timer <= 0:
		# Done resting, start wandering
		_state = State.WANDERING
		_start_new_wander()
	else:
		# Stay still while resting
		apply_ground_movement(delta, Vector3.ZERO)


func _handle_fleeing(delta: float):
	# Flee away from attacker
	if _attacker and is_instance_valid(_attacker):
		var away_from_attacker = (global_position - _attacker.global_position).normalized()
		away_from_attacker.y = 0  # Only horizontal movement

		var movement_input = away_from_attacker * movement_speed * FLEE_SPEED_MULTIPLIER
		apply_ground_movement(delta, movement_input)

		# Update hop animation while fleeing (faster)
		_hop_anim_timer += delta * 2.0  # 2x faster animation while fleeing
		if _hop_anim_timer >= HOP_ANIM_SPEED:
			_hop_anim_timer = 0.0
			_current_hop_frame = 2 if _current_hop_frame == 1 else 1

			if _sprite:
				var sprite_path = "res://assets/art/animals/rabbit_move_%d.png" % _current_hop_frame
				var texture = load(sprite_path)
				if texture:
					_sprite.texture = texture
	else:
		# Attacker is gone, just flee in random direction
		if _wander_direction == Vector3.ZERO:
			_wander_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()

		var movement_input = _wander_direction * movement_speed * FLEE_SPEED_MULTIPLIER
		apply_ground_movement(delta, movement_input)

	# Count down flee timer
	_flee_timer -= delta
	if _flee_timer <= 0:
		# Done fleeing, return to wandering
		_state = State.WANDERING
		_start_new_wander()


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


func _start_resting():
	_state = State.RESTING
	_rest_timer = randf_range(REST_DURATION_MIN, REST_DURATION_MAX)


func _on_took_damage(amount: int, from: Node):
	"""Enter flee state when damaged"""
	if _state == State.FLEEING:
		return  # Already fleeing

	_state = State.FLEEING
	_flee_timer = FLEE_DURATION
	_attacker = from

	print("🐰 %s is fleeing from %s!" % [entity_name, from.get("entity_name") if from else "unknown"])


func _on_death() -> void:
	# Show hunted (dead) sprite
	if _sprite:
		var texture = load("res://assets/art/animals/rabbit_hunted.png")
		if texture:
			_sprite.texture = texture
			_sprite.visible = true  # Keep visible as corpse

	# Drop rabbit meat (item ID 14)
	_drop_loot()

	# Call parent death (handles particles, etc.)
	super._on_death()

	# Don't queue_free immediately - let corpse sprite show for a bit
	await get_tree().create_timer(2.0).timeout
	queue_free()


func _drop_loot():
	"""Drop rabbit meat into player inventory"""
	const RABBIT_MEAT_ID = 14
	const InventoryItem = preload("res://blocky_game/player/inventory_item.gd")

	# Find player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("Rabbit: Could not find player to drop loot")
		return

	# Get inventory
	var inventory = player.get_node_or_null("Inventory")
	if not inventory:
		print("Rabbit: Could not find inventory")
		return

	# Try to add to existing stack first
	var slots = inventory._slots
	var added = false

	for i in range(slots.size()):
		if slots[i] != null and slots[i].type == InventoryItem.TYPE_ITEM and slots[i].id == RABBIT_MEAT_ID:
			# Found existing rabbit meat, add to stack
			slots[i].count += 1
			added = true
			print("🐰 +1 Rabbit Meat (stacked)")
			inventory.emit_signal("changed")
			break

	if not added:
		# Find empty slot
		for i in range(slots.size()):
			if slots[i] == null:
				# Create new rabbit meat item
				var item = InventoryItem.new()
				item.type = InventoryItem.TYPE_ITEM
				item.id = RABBIT_MEAT_ID
				item.count = 1
				slots[i] = item
				print("🐰 +1 Rabbit Meat (new)")
				inventory.emit_signal("changed")
				break
