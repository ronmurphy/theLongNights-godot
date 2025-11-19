extends EntityBase

## Fish - Ambient water creature
## Swims randomly in water, despawns if out of water
## Single sprite (no animation frames)

enum State {
	SWIMMING,
	IDLE
}

var _state: State = State.SWIMMING
var _swim_direction := Vector3.ZERO
var _swim_timer := 0.0
var _idle_timer := 0.0
var _water_check_timer := 0.0

const SWIM_INTERVAL_MIN = 2.0
const SWIM_INTERVAL_MAX = 5.0
const IDLE_DURATION_MIN = 1.0
const IDLE_DURATION_MAX = 3.0
const IDLE_CHANCE = 0.3  # 30% chance to idle after swimming
const SWIM_SPEED = 2.0
const WATER_CHECK_INTERVAL = 1.0  # Check if in water every second


func _ready():
	# Set entity properties
	entity_id = "fish"
	entity_name = "Fish"
	team = Team.NEUTRAL  # Peaceful animal
	max_hp = 5  # Huntable with low HP
	attack_damage = 0  # Doesn't attack
	defense = 0  # No defense
	movement_speed = SWIM_SPEED
	current_hp = max_hp

	# Call parent ready
	super._ready()

	# Create sprite
	_sprite = _create_sprite("res://assets/art/animals/fish.png", 0.002)

	# No health bar for small fish

	# Start swimming
	_start_swimming()


func _process(delta: float):
	if not is_alive:
		return

	# Check if still in water periodically
	_water_check_timer += delta
	if _water_check_timer >= WATER_CHECK_INTERVAL:
		_water_check_timer = 0.0
		if not _is_in_water():
			# Out of water - despawn quietly (unless marked for fishing)
			if not has_meta("fishing_available"):
				queue_free()
				return

	match _state:
		State.SWIMMING:
			_handle_swimming(delta)
		State.IDLE:
			_handle_idle(delta)


func _handle_swimming(delta: float):
	# Count down swim timer
	_swim_timer -= delta

	if _swim_timer <= 0:
		# Decide: idle or start new swim?
		if randf() < IDLE_CHANCE:
			_start_idle()
		else:
			_start_swimming()
	else:
		# Check if next move would leave water - if so, pick new direction
		var next_pos = global_position + _swim_direction * movement_speed * delta
		if not _is_position_in_water(next_pos):
			# Would leave water - pick new direction that stays in water
			_start_swimming()
		else:
			# Continue moving in current direction
			global_position += _swim_direction * movement_speed * delta


func _handle_idle(delta: float):
	# Count down idle timer
	_idle_timer -= delta

	if _idle_timer <= 0:
		# Done idling, start swimming
		_start_swimming()
	# Stay still while idle


func _start_swimming():
	_state = State.SWIMMING

	# Try to find a direction that stays in water (max 10 attempts)
	var attempts = 0
	var valid_direction = false

	while attempts < 10 and not valid_direction:
		# Random 3D direction (horizontal + vertical movement)
		var test_direction = Vector3(
			randf_range(-1, 1),
			randf_range(-0.3, 0.3),  # Less vertical movement
			randf_range(-1, 1)
		).normalized()

		# Test if this direction keeps us in water
		var test_pos = global_position + test_direction * movement_speed * 0.5
		if _is_position_in_water(test_pos):
			_swim_direction = test_direction
			valid_direction = true

		attempts += 1

	# If no valid direction found after 10 tries, just stay still
	if not valid_direction:
		_swim_direction = Vector3.ZERO

	_swim_timer = randf_range(SWIM_INTERVAL_MIN, SWIM_INTERVAL_MAX)


func _start_idle():
	_state = State.IDLE
	_idle_timer = randf_range(IDLE_DURATION_MIN, IDLE_DURATION_MAX)


func _is_in_water() -> bool:
	"""Check if fish is currently in water"""
	return _is_position_in_water(global_position)


func _is_position_in_water(pos: Vector3) -> bool:
	"""Check if a specific position is in water"""
	var terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")
	if not terrain:
		return false

	var vt = terrain.get_voxel_tool()
	vt.set_channel(VoxelBuffer.CHANNEL_TYPE)

	# Check voxel at position
	var voxel_pos = pos.floor()
	var voxel_id = vt.get_voxel(voxel_pos)

	# Get water block info
	var blocks = get_node_or_null("/root/Main/Game/Blocks")
	if not blocks:
		return false

	var water_block = blocks.get_block_by_name("water")
	if not water_block:
		return false

	var water_id = water_block.base_info.id
	var water_voxels = water_block.base_info.voxels

	# Check if current voxel is water (either full or top)
	return voxel_id in water_voxels


func _drop_loot():
	"""Drop fish item into player inventory when killed"""
	const FISH_ITEM_ID = 26

	# Find player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Get player's inventory
	var inventory = player.get_node_or_null("Inventory")
	if not inventory:
		return

	# Try to add fish to existing stack or empty slot
	var added = false
	for i in range(inventory._slots.size()):
		var slot = inventory._slots[i]

		# Add to existing fish stack
		if slot != null and slot.type == 1 and slot.id == FISH_ITEM_ID:
			if slot.quantity < 99:  # Max stack size
				slot.quantity += 1
				added = true
				inventory.inventory_changed.emit()
				print("Added fish to stack (slot %d, total: %d)" % [i, slot.quantity])
				break

		# Add to empty slot
		if slot == null:
			inventory._slots[i] = {
				"type": 1,  # Type.ITEM
				"id": FISH_ITEM_ID,
				"quantity": 1
			}
			added = true
			inventory.inventory_changed.emit()
			print("Added fish to inventory (slot %d)" % i)
			break

	if not added:
		print("Inventory full - fish not added")


func _on_death() -> void:
	"""Override death to drop fish loot"""
	# Drop fish loot
	_drop_loot()

	# Call parent death (handles effects and cleanup)
	super._on_death()

	# Remove fish
	queue_free()
