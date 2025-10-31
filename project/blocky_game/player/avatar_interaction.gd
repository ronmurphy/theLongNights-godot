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

# Block breaking system
const BASE_BLOCK_HARDNESS = 100.0  # Base time to break a block
const BARE_HAND_MINING_POWER = 10   # Mining power when no tool equipped
var _breaking_block_pos : Vector3 = Vector3.ZERO
var _break_progress : float = 0.0
var _is_breaking := false

# Creative mode toggle
var _creative_mode := false


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

		# Check if this is a mining tool being held on a block
		if mining_power > 0 and hit != null and _action_use_held:
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
			if mining_power == 0 or hit == null or not _action_use_held:
				if inv_item.count > 0:
					item.use(_head.global_transform)
					# Decrement item count in hotbar
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
		_break_block(pos, block_id, false)
		_reset_breaking_progress()
		return

	# Get mining power from equipped item or bare hands
	var mining_power = BARE_HAND_MINING_POWER
	if inv_item != null and inv_item.type == InventoryItem.TYPE_ITEM:
		var item = _item_db.get_item(inv_item.id)
		var item_mining_power = item.get_mining_power()
		if item_mining_power > 0:
			mining_power = item_mining_power

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
		_break_block(pos, block_id, mining_power > 0)
		_reset_breaking_progress()


func _break_block(pos: Vector3, block_id: int, add_to_inventory: bool):
	# Remove the block from terrain
	_place_single_block(pos, 0)

	# In creative mode, never add to inventory
	if _creative_mode:
		print("Broke block %d at %s (creative mode - not added)" % [block_id, pos])
	# Add to inventory if using proper mining tool and not in creative mode
	elif add_to_inventory:
		_add_block_to_inventory(block_id)
		print("Broke block %d at %s (added to inventory)" % [block_id, pos])

		# In survival mode, recover a torch when mining blocks
		_recover_torch_on_mining()

		# Check adjacent faces for thrown torches and remove them
		_remove_adjacent_torches(pos)
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


func _remove_adjacent_torches(block_pos: Vector3):
	"""Check all 6 adjacent block faces for thrown torches and remove them from the scene"""
	# Get the game node where torches are spawned
	var game_node = get_node_or_null("/root/Main/Game")
	if game_node == null:
		return

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


func _recover_torch_on_mining():
	"""Recover a thrown torch and add it back to inventory when mining in survival mode"""
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
		slots[existing_torch_slot].count += 1
		_inventory.emit_signal("changed")
		print("Recovered torch from mining! (count: %d)" % slots[existing_torch_slot].count)
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

	# If we found an empty slot, add the torch there
	if empty_slot != -1:
		var torch_item = InventoryItem.new()
		torch_item.id = TORCH_ITEM_ID
		torch_item.type = InventoryItem.TYPE_ITEM
		torch_item.count = 1
		slots[empty_slot] = torch_item
		_inventory.emit_signal("changed")
		print("Recovered torch from mining and placed in new stack!")
	else:
		print("Could not recover torch - inventory full!")


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
	
	var ui_open = console_open or terrain_mapper_open

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
			if _hotbar_keys.has(event.keycode):
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
