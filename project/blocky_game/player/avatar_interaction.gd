extends Node

const Util = preload("res://common/util.gd")
const Blocks = preload("../blocks/blocks.gd")
const ItemDB = preload("../items/item_db.gd")
const InventoryItem = preload("./inventory_item.gd")
const Hotbar = preload("../gui/hotbar/hotbar.gd")
const WaterUpdater = preload("./../water.gd")
const InteractionCommon = preload("./interaction_common.gd")

const COLLISION_LAYER_AVATAR = 2
const SERVER_PEER_ID = 1

const _hotbar_keys = {
	KEY_1: 0,
	KEY_2: 1,
	KEY_3: 2,
	KEY_4: 3,
	KEY_5: 4,
	KEY_6: 5,
	KEY_7: 6,
	KEY_8: 7,
	KEY_9: 8
}

@export var terrain_path : NodePath
@export var cursor_material : Material

# TODO Eventually invert these dependencies
@onready var _head : Camera3D = get_parent().get_node("Camera")
@onready var _hotbar : Hotbar = get_node("../HotBar")
@onready var _block_types : Blocks = get_node("/root/Main/Game/Blocks")
@onready var _item_db : ItemDB = get_node("/root/Main/Game/Items")
@onready var _water_updater : WaterUpdater
@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")
@onready var _inventory = get_node("../Inventory")

var _terrain_tool : VoxelTool = null
var _cursor : MeshInstance3D = null
var _action_place := false
var _action_use := false
var _action_use_held := false  # Track if use button is being held down
var _action_pick := false
var _torch_light : OmniLight3D = null
var _current_held_item_id := -1
var _portal_compass_modal_open := false  # Track if Portal Compass modal is open
var _cooking_modal_open := false  # Track if Cooking modal is open

# Block breaking system
const BASE_BLOCK_HARDNESS = 100.0  # Base time to break a block
const BARE_HAND_MINING_POWER = 10   # Mining power when no tool equipped
var _breaking_block_pos : Vector3 = Vector3.ZERO
var _break_progress : float = 0.0
var _is_breaking := false

# Creative mode toggle
var _creative_mode := false

# Bento auto-eat system
var _recently_ate := false  # Prevent eating entire bento instantly
const AUTO_EAT_HP_THRESHOLD = 0.25  # Auto-eat at 25% HP

# Food system
const FOOD_HEALING = {
	# Raw food (lower healing)
	13: 1,  # egg
	14: 2,  # rabbit
	15: 1,  # berries
	16: 2,  # honey
	22: 1,  # wheat_seeds
	24: 2,  # pumpkin
	25: 1,  # mushroom
	26: 1,  # fish
	# Cooked food (higher healing)
	27: 4,  # grilled_fish
	28: 3,  # berry_honey_snack
}


func _ready():
	var mesh := Util.create_wirecube_mesh(Color(0,0,0))
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	if cursor_material != null:
		mesh_instance.material_override = cursor_material
	mesh_instance.set_scale(Vector3(1,1,1)*1.01)
	_cursor = mesh_instance

	_terrain.add_child(_cursor)
	_terrain_tool = _terrain.get_voxel_tool()
	_terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE

	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() == false or mp.is_server():
		_water_updater = get_node("/root/Main/Game/Water")

	# Create torch light (initially disabled)
	_torch_light = OmniLight3D.new()
	_torch_light.light_color = Color(1.0, 0.5, 0.2)  # Orange torch light
	_torch_light.light_energy = 2.0
	_torch_light.omni_range = 12.0
	_torch_light.omni_attenuation = 0.6
	_torch_light.shadow_enabled = true
	_torch_light.visible = false
	_head.add_child(_torch_light)


func _process(_delta):
	"""Check HP and auto-eat from bento if needed"""
	if not _inventory or _recently_ate:
		return

	var player = get_parent()
	if not player:
		return

	# Check if HP is below threshold (25%)
	var hp_percent = float(player.current_hp) / float(player.max_hp)
	if hp_percent <= AUTO_EAT_HP_THRESHOLD:
		# Try to auto-eat weakest food from bento
		var food = _inventory.consume_bento_food_smart()
		if food != null:
			# Food healing values for cooked food
			const BENTO_FOOD_HEALING = {
				27: 15, 28: 10, 29: 10, 30: 20, 31: 15, 32: 10,
				33: 25, 34: 20, 35: 20, 36: 25, 37: 20, 38: 28, 39: 30
			}

			var heal_amount = BENTO_FOOD_HEALING.get(food.id, 10)

			# Apply healing
			var old_hp = player.current_hp
			player.current_hp = min(player.current_hp + heal_amount, player.max_hp)
			var actual_heal = player.current_hp - old_hp

			# Emit HP changed signal
			if player.has_signal("hp_changed"):
				player.hp_changed.emit(player.current_hp, player.max_hp)

			# Get food name
			var item = _item_db.get_item(food.id)
			var food_name = item.base_info.name.replace("_", " ").capitalize()

			# Show message
			print("🍱 AUTO-ATE %s from bento! +%d HP (now %d/%d)" % [food_name, actual_heal, player.current_hp, player.max_hp])

			# Set cooldown to prevent eating entire bento instantly
			_recently_ate = true
			await get_tree().create_timer(2.0).timeout
			_recently_ate = false


func _get_pointed_voxel() -> VoxelRaycastResult:
	var origin := _head.get_global_transform().origin
	assert(not Util.vec3_has_nan(origin))
	var forward := -_head.get_transform().basis.z.normalized()
	var hit := _terrain_tool.raycast(origin, forward, 10)
	return hit


func _physics_process(_delta):
	if _terrain == null:
		return

	var hit := _get_pointed_voxel()
	if hit != null:
		_cursor.show()
		_cursor.set_position(hit.position)
		# DDD.set_text("Pointed voxel", str(hit.position))  # Hidden - coords shown in TimeDisplay
	else:
		_cursor.hide()
		# DDD.set_text("Pointed voxel", "---")  # Hidden - coords shown in TimeDisplay

	# Use hotbar selection (equipped weapons interfere with block placement)
	var inv_item: InventoryItem = _hotbar.get_selected_item()

	# Update torch light based on held item
	var new_item_id = -1
	if inv_item != null and inv_item.type == InventoryItem.TYPE_ITEM:
		new_item_id = inv_item.id

	if new_item_id != _current_held_item_id:
		_current_held_item_id = new_item_id
		# Torch has item ID 6
		if _torch_light:
			_torch_light.visible = (_current_held_item_id == 6)
	
	# Check for teleport stone and chest interaction (before other block interactions)
	# Trigger on single click (not hold-to-mine)
	if hit != null and _action_use:
		var hit_raw_id := _terrain_tool.get_voxel(hit.position)
		if hit_raw_id != 0:
			var rm := _block_types.get_raw_mapping(hit_raw_id)
			# Teleport stone is block ID 20
			if rm.block_id == 20:
				_handle_teleport_stone_interaction(hit.position)
				_action_use = false
				_action_use_held = false  # Prevent mining the block
				return  # Don't process other interactions
			# Chest is block ID 28
			elif rm.block_id == 28:
				_handle_chest_interaction(hit.position)
				_action_use = false
				_action_use_held = false  # Prevent mining the block
				return  # Don't process other interactions

	# Block placement and breaking
	if inv_item == null or inv_item.type == InventoryItem.TYPE_BLOCK:
		if hit != null:
			var hit_raw_id := _terrain_tool.get_voxel(hit.position)
			var has_cube := hit_raw_id != 0

			# Handle block breaking with hold-to-break mechanic
			if _action_use_held and has_cube:
				var pos = hit.position
				# Check if block is bedrock (block ID 13)
				var rm := _block_types.get_raw_mapping(hit_raw_id)
				if rm.block_id != 13:  # Not bedrock
					_process_block_breaking(pos, rm.block_id, _delta, inv_item)
				else:
					print("Cannot destroy bedrock!")
					_reset_breaking_progress()
			else:
				# Not holding use button or no cube - reset progress
				if _is_breaking:
					_reset_breaking_progress()

			# Handle block placement
			if _action_place:
				var pos = hit.previous_position
				if has_cube == false:
					pos = hit.position
				if _can_place_voxel_at(pos):
					if inv_item != null and inv_item.count > 0:
						_place_single_block(pos, inv_item.id)
						print("Place voxel at ", pos)
						# Decrement block count in hotbar (but NOT in creative mode)
						if not _creative_mode:
							_inventory.decrement_hotbar_slot(_hotbar.get_selected_slot_index())
					elif inv_item != null:
						print("No more blocks to place!")
				else:
					print("Can't place here!")

	# Handle weapon/item usage
	elif inv_item.type == InventoryItem.TYPE_ITEM:
		var item = _item_db.get_item(inv_item.id)
		var mining_power = item.get_mining_power()

		# Check if aiming at an entity (prioritize combat over mining)
		var target_entity = _find_nearest_entity_in_crosshair()
		var aiming_at_entity = target_entity != null

		# Check if this is a mining tool being held on a block (but NOT aiming at entity)
		if mining_power > 0 and hit != null and _action_use_held and not aiming_at_entity:
			# This is a mining tool being used on a block
			var hit_raw_id := _terrain_tool.get_voxel(hit.position)
			var has_cube := hit_raw_id != 0
			if has_cube:
				var pos = hit.position
				var rm := _block_types.get_raw_mapping(hit_raw_id)
				if rm.block_id != 13:  # Not bedrock
					_process_block_breaking(pos, rm.block_id, _delta, inv_item)
				else:
					print("Cannot destroy bedrock!")
					_reset_breaking_progress()
			else:
				# No block - reset progress
				_reset_breaking_progress()
		elif _action_use:
			# Single click with non-mining tool or mining tool in air - use item normally
			# OR if aiming at entity (prioritize combat!)
			if mining_power == 0 or hit == null or not _action_use_held or aiming_at_entity:
				# Check if this is food - consume it instead of "using" it
				if FOOD_HEALING.has(inv_item.id):
					_try_consume_food()
					_reset_breaking_progress()
				elif inv_item.count > 0:
					# Pass full inv_item so weapons can access skyshard_power
					item.use(_head.global_transform, inv_item)
					# Only decrement consumables (torches = item ID 6)
					# Weapons and tools have infinite uses
					if inv_item.id == 6:  # torch
						_inventory.decrement_hotbar_slot(_hotbar.get_selected_slot_index())
					_reset_breaking_progress()
				else:
					print("No more items to use!")
		elif _is_breaking:
			# Was mining but stopped holding - reset
			_reset_breaking_progress()
	
	if _action_pick and hit != null:
		var hit_raw_id = _terrain_tool.get_voxel(hit.position)
		var rm := _block_types.get_raw_mapping(hit_raw_id)
		_hotbar.try_select_slot_by_block_id(rm.block_id)

	_action_place = false
	_action_use = false
	_action_pick = false


func _process_block_breaking(pos: Vector3, block_id: int, delta: float, inv_item):
	# Check if we're breaking a new block
	if not _is_breaking or _breaking_block_pos != pos:
		_breaking_block_pos = pos
		_break_progress = 0.0
		_is_breaking = true
		print("Started breaking block at ", pos)

	# In creative mode, break instantly
	if _creative_mode:
		_break_block(pos, block_id, false, -1)
		_reset_breaking_progress()
		return

	# Get mining power from equipped item or bare hands
	var mining_power = BARE_HAND_MINING_POWER
	var tool_id = -1  # -1 = bare hands, otherwise item ID
	if inv_item != null and inv_item.type == InventoryItem.TYPE_ITEM:
		var item = _item_db.get_item(inv_item.id)
		var item_mining_power = item.get_mining_power()
		if item_mining_power > 0:
			mining_power = item_mining_power
			tool_id = inv_item.id  # Store the tool ID

	# Calculate break time based on mining power
	var break_time_required = BASE_BLOCK_HARDNESS / float(mining_power)

	# Accumulate progress
	_break_progress += delta

	# Calculate and show progress
	var progress_percent = (_break_progress / break_time_required) * 100.0
	_hotbar.set_mining_progress(progress_percent)

	# Spawn particles occasionally
	if fmod(_break_progress, 0.1) < delta:  # Every 0.1 seconds
		_spawn_mining_particles(pos)

	# Check if block is broken
	if _break_progress >= break_time_required:
		# Break the block!
		_break_block(pos, block_id, mining_power > 0, tool_id)
		_reset_breaking_progress()


func _break_block(pos: Vector3, block_id: int, add_to_inventory: bool, tool_id: int = -1):
	# Check if breaking ice - replace with water instead of air
	var block = _block_types.get_block(block_id)
	var is_ice = (block.base_info.name == "ice")
	
	if is_ice:
		# Breaking ice reveals water underneath
		var water_block = _block_types.get_block_by_name("water")
		var water_block_id = water_block.base_info.id
		_place_single_block(pos, water_block_id)
	else:
		# Normal blocks become air
		_place_single_block(pos, 0)

	# In creative mode, never add to inventory
	if _creative_mode:
		print("Broke block %d at %s (creative mode - not added)" % [block_id, pos])
	# Add to inventory if using proper mining tool and not in creative mode
	elif add_to_inventory:
		# Check for special harvestable blocks
		if block_id == 12:  # pumpkin
			_handle_pumpkin_drop(pos)
		elif block_id == 2:  # grass
			_handle_grass_block_drop(pos)
		else:
			# Normal block - add to inventory
			_add_block_to_inventory(block_id)
		print("Broke block %d at %s (added to inventory)" % [block_id, pos])

		# Check adjacent faces for thrown torches and remove them
		# Returns the number of torches removed
		var torches_removed = _remove_adjacent_torches(pos)

		# Only recover torches if we actually found and removed any
		if torches_removed > 0:
			_recover_torches_to_inventory(torches_removed)

		# Spawn block-specific particles (leaves, etc.)
		_spawn_block_particles(block_id, pos, tool_id)
	else:
		print("Destroyed block %d at %s (not added to inventory)" % [block_id, pos])


func _spawn_mining_particles(pos: Vector3):
	# Create small particle burst at block being mined
	var particles = GPUParticles3D.new()
	particles.position = pos + Vector3(0.5, 0.5, 0.5)  # Center of block
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 5
	particles.lifetime = 0.3
	particles.explosiveness = 1.0

	# Particle material
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(0.3, 0.3, 0.3)
	material.direction = Vector3(0, 1, 0)
	material.spread = 30.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 2.0
	material.gravity = Vector3(0, -5.0, 0)
	material.scale_min = 0.05
	material.scale_max = 0.1
	material.color = Color(0.7, 0.7, 0.7)  # Gray dust particles

	particles.process_material = material

	# Add to scene
	_terrain.add_child(particles)

	# Auto-delete using timer instead of await
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(func(): particles.queue_free())


func _add_item_to_inventory(item_id: int, count: int = 1) -> void:
	"""Add item(s) to player's inventory (prioritizes hotbar in survival mode)"""
	if _creative_mode:
		return  # Don't add items in creative mode

	var slots = _inventory._slots
	var BAG_WIDTH = _inventory.BAG_WIDTH
	var BAG_HEIGHT = _inventory.BAG_HEIGHT
	var hotbar_begin_index = BAG_WIDTH * BAG_HEIGHT
	var hotbar_end_index = hotbar_begin_index + BAG_WIDTH

	# Find existing stack of this item type
	var existing_stack_slot = -1
	for i in range(slots.size()):
		if slots[i] != null and slots[i].type == InventoryItem.TYPE_ITEM and slots[i].id == item_id:
			existing_stack_slot = i
			break

	# If item type already exists, add to that stack
	if existing_stack_slot != -1:
		slots[existing_stack_slot].count += count
		_inventory.emit_signal("changed")
		var item_name = _item_db.get_item(item_id).base_info.name
		print("Added %dx %s to existing stack (count: %d)" % [count, item_name, slots[existing_stack_slot].count])
		return

	# Item doesn't exist - prioritize hotbar for new items
	var empty_hotbar_slot = -1
	var empty_bag_slot = -1

	# Search hotbar first for empty slots
	for i in range(hotbar_begin_index, hotbar_end_index):
		if slots[i] == null:
			empty_hotbar_slot = i
			break

	# If hotbar is full, search bag for empty slots
	if empty_hotbar_slot == -1:
		for i in range(hotbar_begin_index):
			if slots[i] == null:
				empty_bag_slot = i
				break

	# Add to hotbar if available, otherwise bag, otherwise drop
	var new_item = InventoryItem.new()
	new_item.id = item_id
	new_item.type = InventoryItem.TYPE_ITEM
	new_item.count = count

	var item_name = _item_db.get_item(item_id).base_info.name
	if empty_hotbar_slot != -1:
		slots[empty_hotbar_slot] = new_item
		_inventory.emit_signal("changed")
		print("Added %dx %s to hotbar slot %d" % [count, item_name, empty_hotbar_slot - hotbar_begin_index])
	elif empty_bag_slot != -1:
		slots[empty_bag_slot] = new_item
		_inventory.emit_signal("changed")
		print("Added %dx %s to bag slot %d (hotbar full)" % [count, item_name, empty_bag_slot])
	else:
		print("Inventory full! %dx %s dropped" % [count, item_name])


func _add_block_to_inventory(block_id: int):
	# Only apply special hotbar priority in survival mode (not creative)
	if _creative_mode:
		_add_block_to_inventory_standard(block_id)
		return

	# Find first existing stack of this block type
	var slots = _inventory._slots
	var BAG_WIDTH = _inventory.BAG_WIDTH
	var BAG_HEIGHT = _inventory.BAG_HEIGHT
	var hotbar_begin_index = BAG_WIDTH * BAG_HEIGHT
	var hotbar_end_index = hotbar_begin_index + BAG_WIDTH

	var existing_stack_slot = -1
	for i in range(slots.size()):
		if slots[i] != null and slots[i].type == InventoryItem.TYPE_BLOCK and slots[i].id == block_id:
			# Found existing stack of this block
			existing_stack_slot = i
			break

	# If block type already exists, add to that stack
	if existing_stack_slot != -1:
		slots[existing_stack_slot].count += 1
		_inventory.emit_signal("changed")
		print("Added block %d to existing stack (count: %d)" % [block_id, slots[existing_stack_slot].count])
		return

	# Block type doesn't exist - prioritize hotbar for new block types (but skip items)
	var empty_hotbar_slot = -1
	var empty_bag_slot = -1

	# Search hotbar first for empty slots (skip slots with items)
	for i in range(hotbar_begin_index, hotbar_end_index):
		if slots[i] == null:
			empty_hotbar_slot = i
			break

	# If hotbar is full, search bag for empty slots (skip slots with items)
	if empty_hotbar_slot == -1:
		for i in range(hotbar_begin_index):
			if slots[i] == null:
				empty_bag_slot = i
				break

	# Add to hotbar if available, otherwise bag, otherwise drop
	var new_item = InventoryItem.new()
	new_item.id = block_id
	new_item.type = InventoryItem.TYPE_BLOCK
	new_item.count = 1

	if empty_hotbar_slot != -1:
		slots[empty_hotbar_slot] = new_item
		_inventory.emit_signal("changed")
		print("Added NEW block %d to hotbar slot %d" % [block_id, empty_hotbar_slot - hotbar_begin_index])
	elif empty_bag_slot != -1:
		slots[empty_bag_slot] = new_item
		_inventory.emit_signal("changed")
		print("Added NEW block %d to bag slot %d (hotbar full)" % [block_id, empty_bag_slot])
	else:
		print("Inventory full! Block %d dropped" % block_id)


func _handle_tall_grass_drop(pos: Vector3) -> void:
	"""Handle tall grass drops: 30% chance for wheat_seeds (22) or berries (15)"""
	if randf() > 0.30:
		print("Tall grass at %s - no drop (70%% chance)" % pos)
		return

	# 50/50 split between wheat_seeds and berries
	var drop_item_id = 22 if randf() < 0.5 else 15  # wheat_seeds (22) or berries (15)
	_add_item_to_inventory(drop_item_id, 1)


func _handle_dead_shrub_drop(pos: Vector3) -> void:
	"""Handle dead shrub drops: 30% chance for egg (13), mushroom (25), or honey (16)"""
	if randf() > 0.30:
		print("Dead shrub at %s - no drop (70%% chance)" % pos)
		return

	# 33/33/33 split between egg, mushroom, and honey
	var roll = randf()
	var drop_item_id = 13  # egg (13)
	if roll > 0.66:
		drop_item_id = 16  # honey (16)
	elif roll > 0.33:
		drop_item_id = 25  # mushroom (25)

	_add_item_to_inventory(drop_item_id, 1)


func _handle_pumpkin_drop(pos: Vector3) -> void:
	"""Handle pumpkin drops: 50% pumpkin (24) or 50% pumpkin_seeds (23)"""
	var drop_item_id = 24 if randf() < 0.5 else 23  # pumpkin (24) or pumpkin_seeds (23)
	_add_item_to_inventory(drop_item_id, 1)


func _handle_grass_block_drop(pos: Vector3) -> void:
	"""Handle grass block drops: 85% normal, 15% special food drops"""
	# 85% chance to get normal grass block
	if randf() > 0.15:
		_add_block_to_inventory(2)  # grass block
		return
	
	# 15% chance for special drop - roll on loot table
	var special_roll = randf()
	
	if special_roll < 0.50:  # 50% of 15% = 7.5% overall
		# Wheat seeds (common rare): 1-4
		var count = randi_range(1, 4)
		_add_item_to_inventory(22, count)  # wheat_seeds
		print("Grass special drop: %d wheat seeds!" % count)
	
	elif special_roll < 0.80:  # 30% of 15% = 4.5% overall
		# Berries (uncommon): 1-3
		var count = randi_range(1, 3)
		_add_item_to_inventory(15, count)  # berries
		print("Grass special drop: %d berries!" % count)
	
	elif special_roll < 0.95:  # 15% of 15% = 2.25% overall
		# Eggs (rare): 1-3
		var count = randi_range(1, 3)
		_add_item_to_inventory(13, count)  # eggs
		print("Grass special drop: %d eggs!" % count)
	
	else:  # 5% of 15% = 0.75% overall
		# Rabbit (very rare jackpot!): 1
		_add_item_to_inventory(14, 1)  # rabbit
		print("Grass special drop: RABBIT! (jackpot!)")


func _add_block_to_inventory_standard(block_id: int):
	"""Standard inventory addition (used in creative mode or fallback)"""
	var slots = _inventory._slots
	var existing_stack_slot = -1
	var empty_slot = -1

	for i in range(slots.size()):
		if slots[i] != null and slots[i].type == InventoryItem.TYPE_BLOCK and slots[i].id == block_id:
			# Found existing stack of this block
			existing_stack_slot = i
			break
		elif slots[i] == null and empty_slot == -1:
			# Found first empty slot
			empty_slot = i

	# Add to existing stack or create new stack
	if existing_stack_slot != -1:
		# Add to existing stack
		slots[existing_stack_slot].count += 1
		_inventory.emit_signal("changed")
		print("Added block %d to existing stack (count: %d)" % [block_id, slots[existing_stack_slot].count])
	elif empty_slot != -1:
		# Create new stack in empty slot
		var item = InventoryItem.new()
		item.id = block_id
		item.type = InventoryItem.TYPE_BLOCK
		item.count = 1
		slots[empty_slot] = item
		_inventory.emit_signal("changed")
		print("Added block %d to new stack in slot %d" % [block_id, empty_slot])
	else:
		print("Inventory full! Block %d dropped" % block_id)


func _remove_adjacent_torches(block_pos: Vector3) -> int:
	"""Check all 6 adjacent block faces for thrown torches and remove them from the scene.
	Returns the number of torches removed."""
	# Get the game node where torches are spawned
	var game_node = get_node_or_null("/root/Main/Game")
	if game_node == null:
		return 0

	var torches_removed = 0

	# Define the 6 adjacent positions (up, down, left, right, forward, back)
	var adjacent_offsets = [
		Vector3(0, 1, 0),   # Up
		Vector3(0, -1, 0),  # Down
		Vector3(1, 0, 0),   # Right
		Vector3(-1, 0, 0),  # Left
		Vector3(0, 0, 1),   # Back
		Vector3(0, 0, -1)   # Forward
	]

	# Check each adjacent position
	for offset in adjacent_offsets:
		var check_pos = block_pos + offset

		# Look for thrown torches at or near this position
		for child in game_node.get_children():
			# Check if this is a thrown torch (scene name contains "ThrownTorch" or similar)
			if "thrown_torch" in child.name.to_lower() or child.get_script() != null and "thrown_torch" in child.get_script().resource_path.to_lower():
				var distance = child.global_position.distance_to(check_pos + Vector3(0.5, 0.5, 0.5))

				# If torch is at this block face (within 1 unit), remove it
				if distance < 1.0:
					print("Removed thrown torch at %s" % check_pos)
					child.queue_free()
					torches_removed += 1

	return torches_removed


func _recover_torches_to_inventory(count: int):
	"""Recover thrown torches and add them back to inventory when mining in survival mode"""
	if count <= 0:
		return

	# Torch item ID is 6
	const TORCH_ITEM_ID = 6

	var slots = _inventory._slots
	var BAG_WIDTH = _inventory.BAG_WIDTH
	var BAG_HEIGHT = _inventory.BAG_HEIGHT
	var hotbar_begin_index = BAG_WIDTH * BAG_HEIGHT

	# Look for existing torch stack in inventory
	var existing_torch_slot = -1
	for i in range(slots.size()):
		if slots[i] != null and slots[i].type == InventoryItem.TYPE_ITEM and slots[i].id == TORCH_ITEM_ID:
			existing_torch_slot = i
			break

	# If torch stack exists, add to it
	if existing_torch_slot != -1:
		slots[existing_torch_slot].count += count
		_inventory.emit_signal("changed")
		print("Recovered %d torch(es) from mining! (total count: %d)" % [count, slots[existing_torch_slot].count])
		return

	# No torch stack exists - need to find a slot for it
	# Look for empty hotbar slot first (but not slot 8 where we keep torches in survival mode)
	var empty_slot = -1
	for i in range(hotbar_begin_index, hotbar_begin_index + BAG_WIDTH):
		if i != hotbar_begin_index + 8 and slots[i] == null:  # Skip slot 8 (reserved for torches)
			empty_slot = i
			break

	# If no empty hotbar slot, look in bag
	if empty_slot == -1:
		for i in range(hotbar_begin_index):
			if slots[i] == null:
				empty_slot = i
				break

	# If we found an empty slot, add the torches there
	if empty_slot != -1:
		var torch_item = InventoryItem.new()
		torch_item.id = TORCH_ITEM_ID
		torch_item.type = InventoryItem.TYPE_ITEM
		torch_item.count = count
		slots[empty_slot] = torch_item
		_inventory.emit_signal("changed")
		print("Recovered %d torch(es) from mining and placed in new stack!" % count)
	else:
		print("Could not recover %d torch(es) - inventory full!" % count)


func _spawn_block_particles(block_id: int, block_pos: Vector3, tool_id: int):
	"""Spawn falling particles when a block is broken (leaves, etc.)
	Only spawns if graphics quality is not 'low' and tool is appropriate"""

	# Check graphics quality - skip particles on low settings
	if GraphicsSettings.get_current_profile() == "low":
		return

	# Define which tools allow particle spawning
	var particle_tools = [8, 11]  # 8=machete, 11=tree_feller

	# Define which blocks should spawn particles (by name)
	var particle_block_names = ["leaves"]

	# Get block name
	var block = _block_types.get_block(block_id)
	if block == null:
		return

	var block_name = block.base_info.name

	# Check if this block should spawn particles
	if not (block_name in particle_block_names):
		return

	# Check if the tool is appropriate for particles
	if not (tool_id in particle_tools):
		return

	# Get the block color
	var block_color = _block_types.get_block_color(block_id)
	print("Spawning particles for %s (block_id=%d) with color %s" % [block_name, block_id, block_color])

	# Spawn falling particles
	_spawn_falling_particles(block_pos, block_color)


func _spawn_falling_particles(origin_pos: Vector3, color: Color):
	"""Create falling particles that descend 2 blocks and fade out"""
	# Number of particles to spawn
	var particle_count = 8
	var fall_distance = 2.0
	var fall_time = 1.0

	for i in range(particle_count):
		# Create a simple particle node
		var particle = Node3D.new()
		particle.name = "FallingBlockParticle_%d" % i

		# Create a small mesh for the particle
		var mesh_instance = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(0.1, 0.1, 0.1)  # Small cube
		mesh_instance.mesh = mesh

		# Create material with the block color
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_instance.material_override = material

		particle.add_child(mesh_instance)

		# Add to terrain first (required before setting global_position)
		_terrain.add_child(particle)

		# Randomize spawn position around the block center
		var spread = 0.3
		var offset = Vector3(
			randf_range(-spread, spread),
			randf_range(-0.1, 0.2),
			randf_range(-spread, spread)
		)
		particle.global_position = origin_pos + Vector3(0.5, 0.5, 0.5) + offset

		# Animate falling
		var tween = particle.create_tween()
		tween.set_parallel(true)  # Run animations in parallel

		# Fall down 2 blocks
		tween.tween_property(particle, "global_position",
			particle.global_position + Vector3(0, -fall_distance, 0),
			fall_time)

		# Fade out alpha
		tween.tween_property(material, "albedo_color:a", 0.0, fall_time)

		# Auto-destroy after animation completes (callback, no await in loop)
		tween.finished.connect(particle.queue_free)


func _reset_breaking_progress():
	if _is_breaking:
		_is_breaking = false
		_break_progress = 0.0
		_hotbar.set_mining_progress(0.0)
		# DDD.set_text("Mining", "")


func _unhandled_input(event: InputEvent):
	# Check if console or terrain mapper is open - if so, don't process game inputs
	var console = get_node_or_null("/root/Main/Game/GameConsole")
	var console_open = console != null and console.is_visible

	var terrain_mapper = get_node_or_null("/root/Main/Game/TerrainMapper")
	var terrain_mapper_open = terrain_mapper != null and terrain_mapper.is_visible

	var ui_open = console_open or terrain_mapper_open or _portal_compass_modal_open or _cooking_modal_open

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if not ui_open:
					if event.pressed:
						_action_use = true
						_action_use_held = true
					else:
						_action_use_held = false
						# Reset breaking progress when button released
						_reset_breaking_progress()
			MOUSE_BUTTON_RIGHT:
				if not ui_open and event.pressed:
					_action_place = true
			MOUSE_BUTTON_MIDDLE:
				if not ui_open and event.pressed:
					_action_pick = true
			MOUSE_BUTTON_WHEEL_DOWN:
				if not ui_open and event.pressed:
					_hotbar.select_next_slot()
			MOUSE_BUTTON_WHEEL_UP:
				if not ui_open and event.pressed:
					_hotbar.select_previous_slot()

	elif event is InputEventKey:
		if event.pressed and not ui_open:
			# Check for CTRL+(1-6) - Eat food from bento box
			if event.ctrl_pressed and _hotbar_keys.has(event.keycode):
				var key_num = _hotbar_keys[event.keycode]
				if key_num >= 0 and key_num <= 5:  # Only 1-6 keys
					_try_eat_from_bento(key_num)
					get_viewport().set_input_as_handled()  # Prevent hotbar switch
			# Check for C key - Emergency Teleport with Portal Compass
			elif event.keycode == KEY_C:
				_try_emergency_teleport()
			elif _hotbar_keys.has(event.keycode):
				var slot_index = _hotbar_keys[event.keycode]
				_hotbar.select_slot(slot_index)


func set_creative_mode(enabled: bool) -> void:
	"""Toggle creative mode on/off"""
	_creative_mode = enabled
	if _creative_mode:
		print("Creative mode ENABLED - blocks break instantly and are not collected")
		# Backup current inventory and switch to creative loadout
		_inventory._backup_current_inventory()
		_inventory._create_creative_loadout()
	else:
		print("Creative mode DISABLED - normal mining mode active")
		# Restore backed up inventory or apply survival loadout
		if _inventory._backed_up_inventory.size() > 0:
			_inventory._restore_backed_up_inventory()
		else:
			_inventory._create_survival_loadout()


func _can_place_voxel_at(pos: Vector3):
	# TODO Is it really relevant anymore? This demo doesn't use physics
	var space_state := get_viewport().get_world_3d().get_direct_space_state()
	var params := PhysicsShapeQueryParameters3D.new()
	params.collision_mask = COLLISION_LAYER_AVATAR
	params.transform = Transform3D(Basis(), pos + Vector3(1,1,1)*0.5)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 1, 1)
	params.set_shape(shape)
	var hits := space_state.intersect_shape(params)
	return hits.size() == 0


func _place_single_block(pos: Vector3, block_id: int):
	var look_dir := -_head.get_transform().basis.z
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_place_single_block", pos, look_dir, block_id)
	else:
		InteractionCommon.place_single_block(_terrain_tool, pos, look_dir,
			block_id, _block_types, _water_updater)


# TODO Maybe use `rpc_config` so this would be less awkward?
@rpc("any_peer", "call_remote", "reliable", 0)
func receive_place_single_block(_pos: Vector3, _look_dir: Vector3, _block_id: int):
	# The server has a different script for remote players
	push_error("Didn't expect this method to be called")


func _try_eat_from_bento(slot_idx: int) -> void:
	"""Try to eat food from bento box slot (CTRL+1-6)"""
	if not _inventory:
		return

	var food = _inventory.consume_bento_food(slot_idx)
	if food == null:
		print("No food in bento slot %d!" % (slot_idx + 1))
		return

	# Food healing values for cooked food (matching recipes_database.json)
	const BENTO_FOOD_HEALING = {
		27: 15, 28: 10, 29: 10, 30: 20, 31: 15, 32: 10,
		33: 25, 34: 20, 35: 20, 36: 25, 37: 20, 38: 28, 39: 30
	}

	var heal_amount = BENTO_FOOD_HEALING.get(food.id, 10)

	# Apply healing to player
	var player = get_parent()
	if player.current_hp >= player.max_hp:
		print("Already at full HP!")
		# Return food to bento (undo consume)
		# Note: Inventory already decremented, so we need to manually restore
		return

	var old_hp = player.current_hp
	player.current_hp = min(player.current_hp + heal_amount, player.max_hp)
	var actual_heal = player.current_hp - old_hp

	# Emit HP changed signal
	if player.has_signal("hp_changed"):
		player.hp_changed.emit(player.current_hp, player.max_hp)

	# Get food name
	var item = _item_db.get_item(food.id)
	var food_name = item.base_info.name.replace("_", " ").capitalize()

	# Show message
	print("🍱 Ate %s from bento! +%d HP (now %d/%d)" % [food_name, actual_heal, player.current_hp, player.max_hp])


func _try_consume_food() -> void:
	"""Try to consume food from hotbar slot"""
	var inv_item = _hotbar.get_selected_item()
	
	# Check if holding food
	if inv_item == null or inv_item.type != InventoryItem.TYPE_ITEM:
		return
	
	if not FOOD_HEALING.has(inv_item.id):
		print("Not a food item")
		return
	
	# Check if at full HP
	var player = get_parent()
	if player.current_hp >= player.max_hp:
		print("Already at full HP!")
		return
	
	# Get healing amount
	var heal_amount = FOOD_HEALING[inv_item.id]
	
	# Apply healing
	var old_hp = player.current_hp
	player.current_hp = min(player.current_hp + heal_amount, player.max_hp)
	var actual_heal = player.current_hp - old_hp
	
	# Emit HP changed signal
	if player.has_signal("hp_changed"):
		player.hp_changed.emit(player.current_hp, player.max_hp)
	
	# Get food name
	var item = _item_db.get_item(inv_item.id)
	var food_name = item.base_info.name.replace("_", " ").capitalize()
	
	# Show message
	print("Ate %s! +%d HP (now %d/%d)" % [food_name, actual_heal, player.current_hp, player.max_hp])
	
	# Consume 1 food
	_inventory.decrement_hotbar_slot(_hotbar.get_selected_slot_index())


func _try_emergency_teleport() -> void:
	"""Try to use Portal Compass for emergency teleport from anywhere (costs 3)"""
	# Check if player has Portal Compass equipped
	var inv_item = _hotbar.get_selected_item()
	if inv_item == null or inv_item.type != InventoryItem.TYPE_ITEM or inv_item.id != 7:
		# Not holding Portal Compass
		return

	# Check if player has at least 3 compasses
	if inv_item.count < 3:
		_show_chest_message("Need 3 Portal Compasses for Emergency Teleport! (Have " + str(inv_item.count) + ")")
		return

	# Open portal compass modal in emergency mode
	print("Emergency Teleport activated! Opening navigation modal...")
	_show_portal_compass_modal(Vector3.ZERO, true)  # true = emergency mode


func _handle_teleport_stone_interaction(teleport_stone_pos: Vector3) -> void:
	"""Called when player right-clicks on a teleport stone"""
	print("Player interacted with teleport stone at: ", teleport_stone_pos)

	# Check if player is holding Portal Compass
	var inv_item = _hotbar.get_selected_item()
	if inv_item != null and inv_item.type == InventoryItem.TYPE_ITEM and inv_item.id == 7:  # Portal Compass
		# Player has Portal Compass equipped!
		print("Portal Compass detected! Opening navigation modal...")
		_show_portal_compass_modal(teleport_stone_pos, false)  # false = normal mode
		return

	# Normal teleport behavior (show confirmation dialog)
	_show_teleport_confirmation_dialog()


func set_cooking_modal_open(is_open: bool) -> void:
	"""Set cooking modal open state (called by GameConsole)"""
	_cooking_modal_open = is_open


func _show_portal_compass_modal(teleport_stone_pos: Vector3, is_emergency: bool = false) -> void:
	"""Show Portal Compass navigation modal (Phase 4a - List View)"""
	# Mark modal as open (disables hotbar scroll wheel)
	_portal_compass_modal_open = true

	# Disable character input while modal is open
	var player_controller = get_parent()
	if player_controller.has_method("set_input_enabled"):
		player_controller.set_input_enabled(false)

	# Load and create the modal
	var PortalCompassModal = load("res://blocky_game/gui/PortalCompassModal.gd")
	var modal = PortalCompassModal.new()

	# Set emergency mode if applicable
	if is_emergency:
		modal.set_meta("is_emergency", true)

	# Connect signals - pass emergency mode info
	modal.destination_selected.connect(func(ruin_data):
		_on_compass_destination_selected(ruin_data, is_emergency)
	)
	modal.modal_closed.connect(func():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Re-enable character input
		if player_controller.has_method("set_input_enabled"):
			player_controller.set_input_enabled(true)
		# Mark modal as closed
		_portal_compass_modal_open = false
	)

	# Add to scene tree and show
	get_tree().root.add_child(modal)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_compass_destination_selected(ruin_data: RuinRegistry.RuinData, is_emergency: bool = false) -> void:
	"""Called when player selects a destination in the Portal Compass modal"""
	print("Player wants to travel to: ", ruin_data.ruin_name)

	# Restore mouse capture
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Get player controller reference for input re-enabling
	var player_controller = get_parent()

	# Show confirmation dialog with different messaging for emergency mode
	var dialog = ConfirmationDialog.new()
	var cost = 3 if is_emergency else 1
	var mode_text = "🚨 Emergency Teleport" if is_emergency else "Portal Compass Travel"

	dialog.title = mode_text
	dialog.dialog_text = "Travel to " + ruin_data.ruin_name + "?\n\nThis will consume " + str(cost) + " Portal Compass" + ("es" if cost > 1 else "") + "."
	dialog.ok_button_text = "Yes, Travel"
	dialog.cancel_button_text = "Cancel"

	# Connect confirmation
	dialog.confirmed.connect(func():
		_execute_compass_teleport(ruin_data, cost)
		dialog.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Re-enable character input
		if player_controller.has_method("set_input_enabled"):
			player_controller.set_input_enabled(true)
		# Mark modal as closed
		_portal_compass_modal_open = false
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Re-enable character input on cancel
		if player_controller.has_method("set_input_enabled"):
			player_controller.set_input_enabled(true)
		# Mark modal as closed
		_portal_compass_modal_open = false
	)
	dialog.close_requested.connect(func():
		dialog.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Re-enable character input on close
		if player_controller.has_method("set_input_enabled"):
			player_controller.set_input_enabled(true)
		# Mark modal as closed
		_portal_compass_modal_open = false
	)

	# Show confirmation
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _execute_compass_teleport(ruin_data: RuinRegistry.RuinData, cost: int = 1) -> void:
	"""Teleport player to selected ruin using Portal Compass"""
	print("Executing compass teleport to: ", ruin_data.ruin_name, " (cost: ", cost, ")")

	# Check if player still has Portal Compass
	var inv_item = _hotbar.get_selected_item()
	if inv_item == null or inv_item.type != InventoryItem.TYPE_ITEM or inv_item.id != 7:
		print("Error: Portal Compass no longer equipped!")
		_show_chest_message("Portal Compass is not equipped!")
		return

	# Check if player has enough compasses
	if inv_item.count < cost:
		print("Error: Not enough Portal Compass charges! Need ", cost, ", have ", inv_item.count)
		_show_chest_message("Not enough Portal Compass charges!")
		return

	# Decrement compass count by cost (1 for normal, 3 for emergency)
	inv_item.count -= cost
	if inv_item.count <= 0:
		# Remove item from inventory if count reaches 0
		var slot_index = _hotbar.get_selected_slot_index()
		_inventory._slots[slot_index] = null
		print("Portal Compass consumed (no charges remaining)")
	else:
		print("Portal Compass used - ", cost, " consumed (", inv_item.count, " remaining)")

	_inventory._update_views()

	# Get player controller
	var player_controller = get_parent()

	# Disable gravity before teleporting
	if player_controller.has_method("disable_gravity"):
		player_controller.disable_gravity()

	# Calculate teleport destination (first teleport stone in the ruin)
	var destination = ruin_data.position
	if ruin_data.teleport_stones.size() > 0:
		destination = ruin_data.position + Vector3(ruin_data.teleport_stones[0].local_pos)

	# Add slight offset so player lands on top of the teleport stone
	destination += Vector3(0.5, 1.5, 0.5)

	# Teleport player
	player_controller.global_position = destination
	print("Player teleported to ", ruin_data.ruin_name, " at ", destination)

	# Mark ruin as visited again (increment visit count)
	var current_time = 0
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_method("get_total_hours"):
		current_time = time_manager.get_total_hours()
	RuinRegistry.mark_ruin_visited(ruin_data, current_time)

	# Spawn enemies if this is a combat ruin that hasn't been cleared
	_spawn_combat_enemies_if_needed(ruin_data)

	# Re-enable gravity after a short delay
	await get_tree().create_timer(0.5).timeout
	if player_controller.has_method("enable_gravity"):
		player_controller.enable_gravity()

	print("Compass teleport complete!")


func _show_teleport_confirmation_dialog() -> void:
	"""Show a confirmation dialog before teleporting"""
	# Create confirmation dialog (has OK and Cancel buttons built-in)
	var dialog = ConfirmationDialog.new()
	dialog.title = "Teleport Stone"
	dialog.dialog_text = "This teleport stone will take you to another ruin.\nThis is a one-way journey.\n\nAre you ready to teleport?"
	dialog.ok_button_text = "Yes, Teleport"
	dialog.cancel_button_text = "No, Cancel"

	# Connect signals
	dialog.confirmed.connect(_execute_teleport)
	dialog.canceled.connect(_on_teleport_canceled)
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

	# Auto-free when closed
	dialog.close_requested.connect(func(): dialog.queue_free())

	# Add to scene and show
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

	# Release mouse for dialog interaction
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_teleport_canceled() -> void:
	"""Called when player cancels teleport"""
	print("Teleport canceled")
	# Restore mouse capture
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _execute_teleport() -> void:
	"""Actually perform the teleportation to a new ruin"""
	print("Teleporting player to new ruin...")

	# Restore mouse capture immediately
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Get player controller
	var player_controller = get_parent()

	# Disable gravity before teleporting
	if player_controller.has_method("disable_gravity"):
		player_controller.disable_gravity()

	# Get RuinSpawner from game
	var ruin_spawner = get_node_or_null("/root/Main/Game/RuinSpawner")
	if not ruin_spawner:
		push_error("RuinSpawner not found!")
		if player_controller.has_method("enable_gravity"):
			player_controller.enable_gravity()
		return

	# Generate random position for new ruin (can be anywhere - ground or sky!)
	var player_pos = player_controller.global_position
	var random_offset = Vector3(
		randf_range(-200, 200),
		randf_range(50, 150),  # Random Y height - flying ruins in the sky!
		randf_range(-200, 200)
	)
	var target_pos = player_pos + random_offset

	# CINEMATIC APPROACH: Teleport player FIRST, then materialize ruin around them
	# Calculate where player will stand on the ruin floor
	var teleport_target = target_pos + Vector3(3, 3, 3)
	player_controller.global_position = teleport_target
	print("Player teleported to: ", teleport_target)
	print("Ruin materializing...")

	# Create magical particle effect at ruin center
	var particles = _create_materialization_particles(target_pos + Vector3(4, 4, 4))

	# Spawn the new ruin at the target position
	# Player will watch it materialize around them!
	# This takes ~2 seconds due to chunk generation
	var ruin_pos = await ruin_spawner.spawn_ruin_at(target_pos)

	# Remove particle effect
	if particles:
		particles.emitting = false
		await get_tree().create_timer(1.0).timeout  # Let particles fade out
		particles.queue_free()

	if ruin_pos != Vector3.ZERO:
		print("Ruin materialized successfully!")

		# Mark this ruin as visited in the registry
		var ruin_data = RuinRegistry.get_ruin_at_position(ruin_pos, 10.0)
		if ruin_data:
			# Get current game time (hours since start) from TimeManager if available
			var current_time = 0
			var time_manager = get_node_or_null("/root/TimeManager")
			if time_manager and time_manager.has_method("get_total_hours"):
				current_time = time_manager.get_total_hours()

			RuinRegistry.mark_ruin_visited(ruin_data, current_time)

			# Spawn enemies if this is a combat ruin
			_spawn_combat_enemies_if_needed(ruin_data)

		# Re-enable gravity (blocks are guaranteed to exist now)
		if player_controller.has_method("enable_gravity"):
			player_controller.enable_gravity()
	else:
		push_error("Failed to spawn new ruin!")
		# Re-enable gravity on failure
		if player_controller.has_method("enable_gravity"):
			player_controller.enable_gravity()


func _create_materialization_particles(center_pos: Vector3) -> CPUParticles3D:
	"""Create magical particle effect for ruin materialization"""
	var particles = CPUParticles3D.new()
	particles.position = center_pos

	# Particle appearance
	particles.emitting = true
	particles.amount = 100
	particles.lifetime = 3.0
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 0.3
	particles.local_coords = false

	# Emission shape - sphere around ruin
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 8.0

	# Particle movement - swirl upward
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 180.0
	particles.gravity = Vector3(0, 2, 0)  # Float upward
	particles.initial_velocity_min = 0.5
	particles.initial_velocity_max = 2.0

	# Particle size - make them MUCH bigger
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 5.0

	# Color gradient - bright glowing cyan
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.4, 0.8, 1.0, 0.8))
	gradient.add_point(0.5, Color(0.5, 0.9, 1.0, 0.6))
	gradient.add_point(1.0, Color(0.3, 0.6, 0.9, 0.0))
	particles.color_ramp = gradient

	# Use QuadMesh instead of SphereMesh (simpler, works better with particles)
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.3, 0.3)  # Bigger base size
	particles.mesh = mesh

	# Create bright emissive material
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = Color(0.7, 1.0, 1.0, 1.0)  # Bright cyan
	particles.material_override = material

	# Add to scene
	_terrain.add_child(particles)

	# Add a pulsing light for guaranteed visibility
	var light = OmniLight3D.new()
	light.light_color = Color(0.4, 0.8, 1.0)  # Cyan
	light.light_energy = 0.0  # Start at 0
	light.omni_range = 20.0
	light.omni_attenuation = 1.5
	particles.add_child(light)

	# Animate light pulsing
	var tween = light.create_tween()
	tween.set_loops(0)  # Infinite loop
	tween.tween_property(light, "light_energy", 8.0, 0.5)
	tween.tween_property(light, "light_energy", 3.0, 0.5)

	print("Materialization particles + pulsing light created at: ", center_pos)
	return particles


# Chest tracking - keep track of opened chests so they can't be looted twice
var _opened_chests: Array[Vector3i] = []
var _first_chest_opened := false  # Track if the special first chest has been opened


func _handle_chest_interaction(chest_pos: Vector3) -> void:
	"""Called when player right-clicks on a chest"""
	var chest_pos_i = Vector3i(chest_pos)

	# Check if this chest has already been opened
	if chest_pos_i in _opened_chests:
		_show_chest_message("This chest has already been looted!")
		return

	# Mark chest as opened
	_opened_chests.append(chest_pos_i)

	# Determine what loot to give
	var loot_items: Array = []  # Can contain multiple items
	var loot_messages: Array = []

	# First chest always gives grappling hook
	if not _first_chest_opened:
		_first_chest_opened = true
		loot_items.append({"id": 1, "count": 1})  # grappling_hook
		loot_messages.append("Grappling Hook")
		print("Player found the first chest - giving grappling hook!")
	else:
		# 15% chance to find Portal Compass (2-3 compasses)
		if randf() < 0.15:
			var compass_count = randi() % 2 + 2  # 2 or 3
			loot_items.append({"id": 7, "count": compass_count})  # portal_compass
			loot_messages.append(str(compass_count) + "x Portal Compass")
			print("Rare drop: Found ", compass_count, " Portal Compasses!")

		# Always give a weapon/tool
		var loot_table = [
			{"id": 0, "name": "Rocket Launcher"},
			{"id": 2, "name": "Climbing Claws"},
			{"id": 3, "name": "Ice Bow"},
			{"id": 4, "name": "Fire Staff"},
			{"id": 5, "name": "Throwing Knives"},
			{"id": 6, "name": "Torch"},
			{"id": 8, "name": "Stone Hammer"},     # ID shifted from 7 to 8
			{"id": 9, "name": "Machete"},          # ID shifted from 8 to 9
			{"id": 10, "name": "Crossbow"},        # ID shifted from 9 to 10
			{"id": 11, "name": "Sword"},           # ID shifted from 10 to 11
			{"id": 12, "name": "Tree Feller"}      # ID shifted from 11 to 12
		]

		var random_loot = loot_table[randi() % loot_table.size()]
		loot_items.append({"id": random_loot["id"], "count": 1})
		loot_messages.append(random_loot["name"])

	# Give all items to the player
	for loot in loot_items:
		_give_item_to_player(loot["id"], loot["count"])

	# Show particles and message
	_create_chest_open_particles(chest_pos)
	var message = "You found: " + ", ".join(loot_messages) + "!"
	_show_chest_message(message)

	print("Chest looted at ", chest_pos, " - gave ", ", ".join(loot_messages))


func _give_item_to_player(item_id: int, count: int = 1) -> void:
	"""Add item to player's inventory with optional stack count"""
	# Find first empty slot in inventory
	var slots = _inventory._slots
	var empty_slot = -1
	for i in range(slots.size()):
		if slots[i] == null:
			empty_slot = i
			break

	if empty_slot == -1:
		print("Inventory is full! Item not given.")
		_show_chest_message("Inventory is full! Item not given.")
		return

	# Create inventory item
	var inv_item = InventoryItem.new()
	inv_item.type = InventoryItem.TYPE_ITEM
	inv_item.id = item_id
	inv_item.count = count  # Use provided count (default 1)

	# Add to inventory
	slots[empty_slot] = inv_item
	_inventory._update_views()

	print("Added item ID ", item_id, " (count: ", count, ") to inventory slot ", empty_slot)


func _create_chest_open_particles(chest_pos: Vector3) -> void:
	"""Create yellow particle effect when chest is opened"""
	var particles = CPUParticles3D.new()
	particles.position = chest_pos + Vector3(0.5, 1.0, 0.5)  # Center above chest

	# Particle appearance
	particles.emitting = true
	particles.amount = 30
	particles.lifetime = 1.5
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.local_coords = false

	# Emission shape - burst from chest
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.3

	# Particle movement - burst upward
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 45.0
	particles.gravity = Vector3(0, -2, 0)  # Fall down after burst
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 4.0

	# Particle size
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.6

	# Color - bright yellow/gold
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 0.3, 1.0))  # Bright yellow
	gradient.add_point(1.0, Color(1.0, 0.8, 0.0, 0.0))  # Gold to transparent

	var color_ramp = GradientTexture1D.new()
	color_ramp.gradient = gradient
	particles.color_ramp = color_ramp

	# Create bright emissive material
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = Color(1.0, 1.0, 0.5, 1.0)  # Bright yellow
	particles.material_override = material

	# Add to scene
	_terrain.add_child(particles)

	# Auto-cleanup
	await get_tree().create_timer(2.0).timeout
	particles.queue_free()


func _show_chest_message(message: String) -> void:
	"""Show a message dialog for chest loot"""
	var dialog = AcceptDialog.new()
	dialog.title = "Chest"
	dialog.dialog_text = message
	dialog.ok_button_text = "OK"

	# Connect close signal
	dialog.confirmed.connect(func():
		dialog.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)
	dialog.close_requested.connect(func():
		dialog.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)

	# Add to scene and show
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

	# Release mouse for dialog interaction
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _spawn_combat_enemies_if_needed(ruin_data: RuinRegistry.RuinData) -> void:
	"""Check if ruin is a combat ruin and spawn enemies if not cleared"""
	# Only spawn if this is a combat ruin
	if not ruin_data.has_enemies:
		return

	# Only spawn if enemies haven't been defeated yet
	if ruin_data.enemies_defeated:
		print("Combat ruin already cleared - no enemies spawned")
		return

	# Spawn enemies scaled to ruin size (EnemySpawner is an autoload singleton)
	print("⚔️ Combat ruin detected! Spawning size-scaled enemies...")
	EnemySpawner.spawn_enemies_at_combat_ruin(ruin_data.position, ruin_data.ruin_size)


func _find_nearest_entity_in_crosshair() -> Node:
	"""Find closest entity in player's crosshair (for combat prioritization)"""
	const MAX_ENTITY_DISTANCE = 5.0  # Max distance to detect entities
	const CROSSHAIR_CONE_ANGLE = 30.0  # Degrees (30 deg = 60 deg cone total)

	var origin = _head.global_position
	var direction = -_head.global_transform.basis.z.normalized()

	var entities = get_tree().get_nodes_in_group("entities")
	var closest_entity = null
	var closest_distance = MAX_ENTITY_DISTANCE

	for entity in entities:
		if not entity.get("is_alive") or not entity.is_alive:
			continue

		# Check distance
		var to_entity = entity.global_position - origin
		var distance = to_entity.length()
		if distance > MAX_ENTITY_DISTANCE:
			continue

		# Check if in crosshair cone
		var angle = rad_to_deg(direction.angle_to(to_entity.normalized()))
		if angle > CROSSHAIR_CONE_ANGLE:
			continue

		# Closer entity found
		if distance < closest_distance:
			closest_distance = distance
			closest_entity = entity

	return closest_entity
