extends Control

signal changed
signal equipment_changed

const BAG_WIDTH = 9
const BAG_HEIGHT = 3
const HOTBAR_HEIGHT = 1
const BENTO_SLOTS = 6

const InventoryItem = preload("../../player/inventory_item.gd")
const CharacterQuiz = preload("res://long_nights/CharacterQuiz.gd")

@onready var _bag_container = $CC/PC/VB/Bag
@onready var _hotbar_container = $CC/PC/VB/Hotbar
@onready var _bento_container = $CC/PC/VB/BentoBox
@onready var _dragged_item_view = $DraggedItem
@onready var _panel_container = $CC/PC
@onready var _item_db = get_node("/root/Main/Game/Items")

# TODO Is it worth having the hotbar in the first indexes instead of the last ones?
var _slots := []
var _slot_views := []
var _bento_slots := []  # Array of 6 food items for bento box
var _bento_slot_views := []
var _previous_mouse_mode := 0
var _dragged_slot := -1

# Equipment slots (separate from inventory)
var _player_weapon_slot: InventoryItem = null
var _companion_weapon_slot: InventoryItem = null
var _companion_accessory_slot: InventoryItem = null  # Second equip slot for companion
var _player_weapon_slot_view = null
var _companion_weapon_slot_view = null
var _companion_accessory_slot_view = null  # UI view for accessory slot
var _player_equipment_panel = null
var _companion_equipment_panel = null
# Robust companion panel update flag
## This flag used earlier in an experimental flow; keep for backward compatibility
var _pending_companion_update := false

# Loadout management for creative/survival mode switching
var _backed_up_inventory: Array = []  # Backup of survival mode inventory
var _backed_up_player_weapon: InventoryItem = null  # Backup of survival mode player weapon


func _ready():
	# Create equipment panels first
	_create_equipment_panels()

	_slots.resize(BAG_WIDTH * (BAG_HEIGHT + HOTBAR_HEIGHT))
	assert(_bag_container.get_child_count() == BAG_WIDTH * BAG_HEIGHT)
	assert(_hotbar_container.get_child_count() == BAG_WIDTH * HOTBAR_HEIGHT)

	# Initial contents - Survival mode loadout: machete + 10 torches
	# ONLY apply this for NEW games, not when loading a saved game
	var has_saved_inventory = WorldManager._world_data.has("inventory")
	if not has_saved_inventory:
		var hotbar_begin_index := BAG_WIDTH * BAG_HEIGHT
		_slots[hotbar_begin_index + 0] = _make_item(InventoryItem.TYPE_ITEM, 9)  # Machete in hotbar slot 0 (ID 9, shifted by portal_compass insertion)
		_slots[hotbar_begin_index + 8] = _make_item_with_count(InventoryItem.TYPE_ITEM, 6, 10)  # 10x torches in last hotbar slot (slot 8)
		print("Inventory: Applied starting loadout (new game)")
	else:
		print("Inventory: Skipping starting loadout (loading saved game)")

	# Init views
	var slot_idx := 0
	_slot_views.resize(len(_slots))
	for container in [_bag_container, _hotbar_container]:
		for i in container.get_child_count():
			var slot = container.get_child(i)
			slot.get_display().set_item(_slots[slot_idx])
			slot.pressed.connect(_on_slot_pressed.bind(slot_idx))
			slot.right_clicked.connect(_on_slot_right_clicked.bind(slot_idx))
			_slot_views[slot_idx] = slot
			slot_idx += 1

	# Update player and companion info panels (name, role, HP, stats)
	_update_player_panel()
	_update_companion_panel()

	# Init bento box slots
	_bento_slots.resize(BENTO_SLOTS)
	_bento_slot_views.resize(BENTO_SLOTS)
	for i in _bento_container.get_child_count():
		var slot = _bento_container.get_child(i)
		slot.get_display().set_item(_bento_slots[i])
		slot.pressed.connect(_on_bento_slot_pressed.bind(i))
		_bento_slot_views[i] = slot

	# Add Power Harmonization button below bento box
	# NOTE: Power Harmonization now only available through Armorer NPC
	# _create_power_harmonization_button()

	# Initialize companion weapon slot with their default weapon
	call_deferred("_initialize_companion_default_weapon")

	# Connect to roster swaps so the UI updates when companion swaps (PartyUI uses the same signal)
	if CompanionManager and not CompanionManager.companion_swapped.is_connected(_on_companion_roster_swapped):
		CompanionManager.companion_swapped.connect(_on_companion_roster_swapped)

	# Also listen for actual Companion spawn to refresh UI exactly when companion is present
	# (Deprecated: companion_spawned signal removed in this patch)

	# Ensure initial player and companion panels are populated
	_update_player_panel()
	_update_companion_panel()

	# Re-run a short deferred panel refresh to ensure roster-loaded values
	# are reflected (covers cases where companion data is loaded after UI creation)
	await get_tree().create_timer(0.2).timeout
	_update_player_panel()
	_update_companion_panel()


static func _make_item(type, id):
	var i = InventoryItem.new()
	i.id = id
	i.type = type
	return i


static func _make_item_with_count(type, id, count):
	var i = InventoryItem.new()
	i.id = id
	i.type = type
	i.count = count
	return i


## LOADOUT MANAGEMENT FOR CREATIVE/SURVIVAL MODES

func _backup_current_inventory() -> void:
	"""Backup current inventory before switching to creative mode"""
	_backed_up_inventory.clear()
	_backed_up_inventory.resize(_slots.size())

	# Deep copy all slots
	for i in range(_slots.size()):
		if _slots[i] != null:
			var backup_item = InventoryItem.new()
			backup_item.id = _slots[i].id
			backup_item.type = _slots[i].type
			backup_item.count = _slots[i].count
			_backed_up_inventory[i] = backup_item

	# Backup player weapon
	if _player_weapon_slot != null:
		_backed_up_player_weapon = InventoryItem.new()
		_backed_up_player_weapon.id = _player_weapon_slot.id
		_backed_up_player_weapon.type = _player_weapon_slot.type
		_backed_up_player_weapon.count = _player_weapon_slot.count
	else:
		_backed_up_player_weapon = null

	print("Inventory backed up for creative mode switch")


func _restore_backed_up_inventory() -> void:
	"""Restore backed up inventory when exiting creative mode"""
	_slots.clear()
	_slots.resize(BAG_WIDTH * (BAG_HEIGHT + HOTBAR_HEIGHT))

	# Restore all slots from backup
	for i in range(_backed_up_inventory.size()):
		if _backed_up_inventory[i] != null:
			var restore_item = InventoryItem.new()
			restore_item.id = _backed_up_inventory[i].id
			restore_item.type = _backed_up_inventory[i].type
			restore_item.count = _backed_up_inventory[i].count
			_slots[i] = restore_item

	# Restore player weapon
	if _backed_up_player_weapon != null:
		_player_weapon_slot = InventoryItem.new()
		_player_weapon_slot.id = _backed_up_player_weapon.id
		_player_weapon_slot.type = _backed_up_player_weapon.type
		_player_weapon_slot.count = _backed_up_player_weapon.count
	else:
		_player_weapon_slot = null

	_backed_up_inventory.clear()
	_backed_up_player_weapon = null

	print("Inventory restored from creative mode")
	_update_views()
	_refresh_hotbar_display()
	emit_signal("equipment_changed")
	emit_signal("changed")


func _create_survival_loadout() -> void:
	"""Set inventory to survival mode loadout: machete + 10 torches"""
	# Clear inventory completely
	_slots.clear()
	_slots.resize(BAG_WIDTH * (BAG_HEIGHT + HOTBAR_HEIGHT))

	# Clear player weapon
	_player_weapon_slot = null

	# Hotbar: machete in slot 0, torches in slot 8 (last hotbar slot)
	var hotbar_begin_index := BAG_WIDTH * BAG_HEIGHT
	_slots[hotbar_begin_index + 0] = _make_item(InventoryItem.TYPE_ITEM, 9)  # Machete (ID 9, shifted by portal_compass insertion)
	_slots[hotbar_begin_index + 8] = _make_item_with_count(InventoryItem.TYPE_ITEM, 6, 10)  # 10x torches (ID 6)

	print("Survival loadout applied: machete + 10 torches")
	_update_views()
	_refresh_hotbar_display()
	emit_signal("equipment_changed")
	emit_signal("changed")


func _create_creative_loadout() -> void:
	"""Set inventory to creative mode loadout: all common building blocks"""
	# Clear inventory completely
	_slots.clear()
	_slots.resize(BAG_WIDTH * (BAG_HEIGHT + HOTBAR_HEIGHT))

	# Clear player weapon
	_player_weapon_slot = null

	# Block IDs to include (common building blocks)
	# Valid IDs: 0-26 (see blocks.gd for full list)
	var block_ids = [1, 2, 3, 4, 5, 7, 10, 12, 13, 14, 15, 16, 17, 18, 19, 21, 23, 24, 25, 26]  # Common block IDs

	# Fill hotbar first with block ID 1-5 for quick access
	var hotbar_begin_index := BAG_WIDTH * BAG_HEIGHT
	for i in range(min(5, block_ids.size())):
		_slots[hotbar_begin_index + i] = _make_item(InventoryItem.TYPE_BLOCK, block_ids[i])

	# Fill bag slots with remaining blocks
	var bag_slot = 0
	for block_id in block_ids:
		if bag_slot >= BAG_WIDTH * BAG_HEIGHT:
			break
		# Skip if already in hotbar
		if block_id > 5:
			_slots[bag_slot] = _make_item(InventoryItem.TYPE_BLOCK, block_id)
			bag_slot += 1

	print("Creative loadout applied: common building blocks")
	_update_views()
	_refresh_hotbar_display()
	emit_signal("equipment_changed")
	emit_signal("changed")


func _refresh_hotbar_display() -> void:
	"""Refresh the hotbar UI to display current inventory"""
	var hotbar = get_node_or_null("../HotBar")
	if hotbar and hotbar.has_method("refresh_display"):
		# Use call_deferred to ensure UI is updated after inventory changes
		hotbar.call_deferred("refresh_display")


func _update_views():
	var slot_idx := 0
	for container in [_bag_container, _hotbar_container]:
		for i in container.get_child_count():
			var slot = container.get_child(i)
			slot.get_display().set_item(_slots[slot_idx])
			slot_idx += 1

	# Refresh player and companion panels after basic views update
	_update_player_panel()
	_update_companion_panel()


func get_hotbar_slot_count() -> int:
	return BAG_WIDTH


func get_hotbar_slot_data(i) -> InventoryItem:
	var hotbar_begin_index := BAG_WIDTH * BAG_HEIGHT
	return _slots[hotbar_begin_index + i]


func decrement_hotbar_slot(i: int) -> bool:
	"""Decrement count of item in hotbar slot i. Returns true if successful, false if slot is empty or count is 0."""
	var hotbar_begin_index := BAG_WIDTH * BAG_HEIGHT
	var slot_index = hotbar_begin_index + i
	var item = _slots[slot_index]

	if item == null:
		return false

	# Decrement count
	item.count -= 1

	# If count reaches 0 or below, remove the item
	if item.count <= 0:
		_slots[slot_index] = null
		print("Removed item from hotbar slot %d (count reached 0)" % i)

	# Update UI
	emit_signal("changed")
	return true


func get_player_equipped_weapon() -> InventoryItem:
	"""Get the player's currently equipped weapon"""
	return _player_weapon_slot


func get_companion_equipped_weapon() -> InventoryItem:
	"""Get the companion's currently equipped weapon"""
	return _companion_weapon_slot


func _initialize_companion_default_weapon():
	"""Initialize companion weapon slot with their default starting weapon or saved weapon"""
	var weapon_id = -1
	var weapon_count = 1

	# Check if using roster system
	var active = null
	if CompanionManager and CompanionManager.using_roster_system:
		active = CompanionManager.get_active_companion()

	# Try to load saved equipment first
	if active != null and active.equipped_weapon_id >= 0:
		weapon_id = active.equipped_weapon_id
		weapon_count = active.equipped_weapon_count if active.equipped_weapon_count > 0 else 1
	elif CompanionManager.equipped_weapon_id >= 0:
		weapon_id = CompanionManager.equipped_weapon_id
		weapon_count = 1  # Legacy system doesn't have count
	else:
		# Get the companion's default weapon ID based on their race
		weapon_id = _get_companion_default_weapon_id()
		weapon_count = 1

	if weapon_id >= 0:
		# Create an inventory item for the weapon with saved count
		_companion_weapon_slot = _make_item_with_count(InventoryItem.TYPE_ITEM, weapon_id, weapon_count)

		# Restore weapon power if using roster system
		if active != null and active.equipped_weapon_power != "":
			_companion_weapon_slot.skyshard_power = active.equipped_weapon_power

		# Update the visual display
		if _companion_weapon_slot_view:
			_companion_weapon_slot_view.get_display().set_item(_companion_weapon_slot)


func _get_companion_default_weapon_id() -> int:
	"""Get the default weapon ID for companion's race"""
	match CompanionManager.companion_race:
		"dwarf":
			return 8  # stone_hammer (ID shifted by portal_compass insertion)
		"elf":
			return 10  # crossbow (ID shifted by portal_compass insertion)
		"goblin":
			if CompanionManager.companion_gender == "female":
				return 5  # throwing_knives
			else:
				return 0  # rocket_launcher
		"human":
			return 9  # machete (ID shifted by portal_compass insertion)
	return -1


func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_E:
				visible = not visible
			elif visible and event.keycode == KEY_ESCAPE:
				visible = false
				get_viewport().set_input_as_handled()


func _notification(what: int):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_inside_tree():
			print("Visibility changed while not in tree? Eh?")
			return

		if visible:
			_update_views()
			# Ensure companion panel is in sync when inventory becomes visible
			call_deferred("_update_companion_panel")

			_previous_mouse_mode = Input.get_mouse_mode()
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

			# Hide PartyUI when inventory opens
			var game_node = get_node_or_null("/root/Main/Game")
			if game_node:
				# Search for PartyUI in game's children
				for child in game_node.get_children():
					if child.has_method("add_companion"):  # PartyUI has this method
						print("Inventory: Hiding PartyUI")
						child.visible = false
						break

		else:
			if _dragged_slot != -1:
				# Cancel drag
				_slot_views[_dragged_slot].get_display().set_item(_slots[_dragged_slot])
				_dragged_item_view.stop()
			_dragged_slot = -1
			_dragged_item_view.stop()

			Input.set_mouse_mode(_previous_mouse_mode)

			# Show PartyUI when inventory closes
			var game_node = get_node_or_null("/root/Main/Game")
			if game_node:
				# Search for PartyUI in game's children
				for child in game_node.get_children():
					if child.has_method("add_companion"):  # PartyUI has this method
						print("Inventory: Showing PartyUI")
						child.visible = true
						break


func _on_slot_pressed(idx: int):
	if _dragged_slot == -1:
		if _slots[idx] == null:
			return
		# Start drag
		_dragged_slot = idx
		_slot_views[_dragged_slot].get_display().set_item(null)
		_dragged_item_view.start(_slots[idx])

	else:
		# Get the dragged item (could be from equipment slot, accessory slot, OR bento box)
		var dragged_item = null
		if _dragged_slot >= 0:
			dragged_item = _slots[_dragged_slot]
		elif _dragged_slot == -999:
			dragged_item = _player_weapon_slot
		elif _dragged_slot == -998:
			dragged_item = _companion_weapon_slot
		elif _dragged_slot == -997:
			dragged_item = _companion_accessory_slot
		elif _dragged_slot <= -100:
			# From bento box
			var source_bento_idx = -100 - _dragged_slot
			dragged_item = _bento_slots[source_bento_idx]
		
		if _slots[idx] == null:
			# Move to empty slot
			_slots[idx] = dragged_item

			# Clear source
			if _dragged_slot >= 0:
				_slots[_dragged_slot] = null
			elif _dragged_slot == -999:
				_player_weapon_slot = null
				_player_weapon_slot_view.get_display().set_item(null)
			elif _dragged_slot == -998:
				_companion_weapon_slot = null
				_companion_weapon_slot_view.get_display().set_item(null)
				# Clear saved weapon
				CompanionManager.equipped_weapon_id = -1
				CompanionManager.save_to_file()
			elif _dragged_slot == -997:
				_companion_accessory_slot = null
				_companion_accessory_slot_view.get_display().set_item(null)
				_update_companion_accessory()
			elif _dragged_slot <= -100:
				# Clear from bento box
				var source_bento_idx = -100 - _dragged_slot
				_bento_slots[source_bento_idx] = null
				_bento_slot_views[source_bento_idx].get_display().set_item(null)
			
			_slot_views[idx].get_display().set_item(_slots[idx])
			_dragged_item_view.stop()
			_dragged_slot = -1
			emit_signal("changed")
			emit_signal("equipment_changed")
		
		else:
			# Occupied slot - check if we can stack or swap
			if _dragged_slot >= 0 and _dragged_slot != idx:
				var target_item = _slots[idx]

				# Check if dragging skyshard onto weapon/tool for enhancement
				const SKYSHARD_ITEM_ID = 21  # skyshard ID from item_db
				if (dragged_item.type == InventoryItem.TYPE_ITEM and
					dragged_item.id == SKYSHARD_ITEM_ID and
					target_item.type == InventoryItem.TYPE_ITEM and
					target_item.id != SKYSHARD_ITEM_ID):

					# IMPORTANT: One power per weapon limit!
					# Once a weapon has a power, it cannot be enhanced further
					if target_item.skyshard_power != "":
						print("⚠️ This weapon already has a power! (%s is locked in)" % target_item.skyshard_power)
						print("   Choose a different weapon if you want another enhancement.")
						# Cancel drag - return item to original slot
						_slot_views[_dragged_slot].get_display().set_item(_slots[_dragged_slot])
						_dragged_item_view.stop()
						_dragged_slot = -1
					else:
						# Calculate how many skyshards we can/need to add (max 5 total)
						var current_count = target_item.skyshard_count
						var skyshards_needed = 5 - current_count
						var skyshards_to_add = min(dragged_item.count, skyshards_needed)

						# Infuse skyshards into weapon/tool
						target_item.skyshard_count += skyshards_to_add
						print("💎 Infused %d skyshard(s)! %s now has %d/5 skyshards" %
							[skyshards_to_add, _item_db.get_item(target_item.id).base_info.name, target_item.skyshard_count])

						# Decrement skyshard count
						dragged_item.count -= skyshards_to_add
						if dragged_item.count <= 0:
							_slots[_dragged_slot] = null
							_slot_views[_dragged_slot].get_display().set_item(null)
						else:
							_slot_views[_dragged_slot].get_display().set_item(dragged_item)

						# Update target display to show skyshard counter
						_slot_views[idx].get_display().set_item(target_item)
						_dragged_item_view.stop()
						_dragged_slot = -1
						emit_signal("changed")

						# Check if we reached 5 skyshards - show power selection modal
						if target_item.skyshard_count == 5:
							print("✨ 5 Skyshards reached! Opening power selection modal...")
							_show_power_selection_modal(idx)

				# Check if items are the same type and id (stackable)
				elif target_item.type == dragged_item.type and target_item.id == dragged_item.id:
					# Combine stacks
					target_item.count += dragged_item.count
					_slots[_dragged_slot] = null
					_slot_views[_dragged_slot].get_display().set_item(null)
					_slot_views[idx].get_display().set_item(target_item)
					_dragged_item_view.stop()
					_dragged_slot = -1
					emit_signal("changed")
				else:
					# Different items - swap them
					var tmp = _slots[idx]
					_slots[idx] = _slots[_dragged_slot]
					_slots[_dragged_slot] = tmp
					_dragged_item_view.start(tmp)
					_slot_views[idx].get_display().set_item(_slots[idx])
					emit_signal("changed")
			else:
				# Can't swap equipment/accessory slots with inventory - cancel drag
				if _dragged_slot == -999:
					_player_weapon_slot_view.get_display().set_item(_player_weapon_slot)
				elif _dragged_slot == -998:
					_companion_weapon_slot_view.get_display().set_item(_companion_weapon_slot)
				elif _dragged_slot == -997:
					_companion_accessory_slot_view.get_display().set_item(_companion_accessory_slot)
				elif _dragged_slot >= 0:
					_slot_views[_dragged_slot].get_display().set_item(_slots[_dragged_slot])
				_dragged_slot = -1
				_dragged_item_view.stop()


func _on_bento_slot_pressed(bento_idx: int):
	"""Handle clicking on bento box slots (food only)"""
	if _dragged_slot == -1:
		# Not dragging - try to pick up food from bento
		if _bento_slots[bento_idx] != null:
			# Special ID for bento slots: -100 to -105
			_dragged_slot = -100 - bento_idx
			_bento_slot_views[bento_idx].get_display().set_item(null)
			_dragged_item_view.start(_bento_slots[bento_idx])
	else:
		# Dragging something - try to place in bento
		var dragged_item = null

		# Get the dragged item
		if _dragged_slot >= 0:
			# From regular inventory
			dragged_item = _slots[_dragged_slot]
		elif _dragged_slot == -999 or _dragged_slot == -998 or _dragged_slot == -997:
			# From equipment slot - cancel (can't put equipment in bento)
			print("Cannot place equipment in bento box!")
			if _dragged_slot == -999:
				_player_weapon_slot_view.get_display().set_item(_player_weapon_slot)
			elif _dragged_slot == -998:
				_companion_weapon_slot_view.get_display().set_item(_companion_weapon_slot)
			elif _dragged_slot == -997:
				_companion_accessory_slot_view.get_display().set_item(_companion_accessory_slot)
			_dragged_item_view.stop()
			_dragged_slot = -1
			return
		elif _dragged_slot <= -100:
			# From another bento slot
			var source_bento_idx = -100 - _dragged_slot
			dragged_item = _bento_slots[source_bento_idx]

		# Check if it's a food item
		if dragged_item != null and _is_food_item(dragged_item):
			# Valid food item - place in bento
			var old_bento_item = _bento_slots[bento_idx]
			_bento_slots[bento_idx] = dragged_item

			# Clear source
			if _dragged_slot >= 0:
				_slots[_dragged_slot] = old_bento_item  # Swap
				_slot_views[_dragged_slot].get_display().set_item(old_bento_item)
			elif _dragged_slot <= -100:
				var source_bento_idx = -100 - _dragged_slot
				_bento_slots[source_bento_idx] = old_bento_item  # Swap
				_bento_slot_views[source_bento_idx].get_display().set_item(old_bento_item)

			# Update bento view
			_bento_slot_views[bento_idx].get_display().set_item(_bento_slots[bento_idx])
			_dragged_item_view.stop()
			_dragged_slot = -1
			emit_signal("changed")
		else:
			# Not a food item
			print("Only cooked food can go in the bento box!")
			# Return item to source
			if _dragged_slot >= 0:
				_slot_views[_dragged_slot].get_display().set_item(_slots[_dragged_slot])
			elif _dragged_slot == -999:
				_player_weapon_slot_view.get_display().set_item(_player_weapon_slot)
			elif _dragged_slot == -998:
				_companion_weapon_slot_view.get_display().set_item(_companion_weapon_slot)
			elif _dragged_slot == -997:
				_companion_accessory_slot_view.get_display().set_item(_companion_accessory_slot)
			elif _dragged_slot <= -100:
				var source_bento_idx = -100 - _dragged_slot
				_bento_slot_views[source_bento_idx].get_display().set_item(_bento_slots[source_bento_idx])
			_dragged_item_view.stop()
			_dragged_slot = -1


func _on_slot_right_clicked(idx: int):
	"""Handle right-click on inventory slot - use pouches and potions"""
	# Ignore if dragging
	if _dragged_slot != -1:
		return

	var item = _slots[idx]
	if item == null:
		return

	# Check if this is a usable item (pouches or potions)
	var items_node = get_node_or_null("/root/Main/Game/Items")
	if not items_node:
		return

	# Find usable item IDs (pouches and stat potions)
	const USABLE_ITEM_NAMES = ["pouch_1", "pouch_2", "pouch_3", "pouch_4", "pouch_5", "hppotion", "defpotion", "atkpotion", "luckpotion"]
	for i in range(100):
		var check_item = items_node.get_item(i)
		if check_item and check_item.base_info.name in USABLE_ITEM_NAMES:
			# Found a usable item (pouch or potion)!
			if item.type == InventoryItem.TYPE_ITEM and item.id == i:
				# Use the item
				var player = get_tree().get_first_node_in_group("player")
				if player:
					var camera = player.get_node_or_null("Camera")
					if camera:
						check_item.use(camera.global_transform, item)
						# Update slot display
						if item.count <= 0:
							_slots[idx] = null
						_slot_views[idx].get_display().set_item(_slots[idx])
						emit_signal("changed")
				break


func _on_avatar_clicked(is_player: bool):
	"""Handle clicking on avatar/paper doll - consume food if dragging food item"""
	if _dragged_slot == -1:
		return  # Not dragging anything

	# Get the dragged item
	var dragged_item = null
	if _dragged_slot >= 0:
		dragged_item = _slots[_dragged_slot]
	elif _dragged_slot == -999 or _dragged_slot == -998 or _dragged_slot == -997:
		# Equipment slot - can't consume weapons/accessories
		print("Cannot consume equipment!")
		_cancel_drag()
		return
	elif _dragged_slot <= -100:
		var source_bento_idx = -100 - _dragged_slot
		dragged_item = _bento_slots[source_bento_idx]

	# Check if it's a food item
	if not _is_food_item(dragged_item):
		print("Only food items can be consumed!")
		_cancel_drag()
		return

	# Consume the food for the target character
	_consume_food_for_character(dragged_item, is_player)

	# Remove one from the stack
	dragged_item.count -= 1

	# Clear from source if count reaches 0
	if dragged_item.count <= 0:
		if _dragged_slot >= 0:
			_slots[_dragged_slot] = null
			_slot_views[_dragged_slot].get_display().set_item(null)
		elif _dragged_slot <= -100:
			var source_bento_idx = -100 - _dragged_slot
			_bento_slots[source_bento_idx] = null
			_bento_slot_views[source_bento_idx].get_display().set_item(null)
	else:
		# Update the stack count
		if _dragged_slot >= 0:
			_slot_views[_dragged_slot].get_display().set_item(dragged_item)
		elif _dragged_slot <= -100:
			var source_bento_idx = -100 - _dragged_slot
			_bento_slot_views[source_bento_idx].get_display().set_item(dragged_item)

	# Stop dragging
	_dragged_item_view.stop()
	_dragged_slot = -1
	emit_signal("changed")


func _cancel_drag():
	"""Cancel current drag operation and return item to source"""
	if _dragged_slot >= 0:
		_slot_views[_dragged_slot].get_display().set_item(_slots[_dragged_slot])
	elif _dragged_slot == -999:
		_player_weapon_slot_view.get_display().set_item(_player_weapon_slot)
	elif _dragged_slot == -998:
		_companion_weapon_slot_view.get_display().set_item(_companion_weapon_slot)
	elif _dragged_slot == -997:
		_companion_accessory_slot_view.get_display().set_item(_companion_accessory_slot)
	elif _dragged_slot <= -100:
		var source_bento_idx = -100 - _dragged_slot
		_bento_slot_views[source_bento_idx].get_display().set_item(_bento_slots[source_bento_idx])
	_dragged_item_view.stop()
	_dragged_slot = -1


func _consume_food_for_character(food: InventoryItem, is_player: bool):
	"""Apply food healing/buffs to player or companion"""
	# Food healing values for cooked food
	const BENTO_FOOD_HEALING = {
		27: 15, 28: 10, 29: 10, 30: 20, 31: 15, 32: 10,
		33: 25, 34: 20, 35: 20, 36: 25, 37: 20, 38: 28, 39: 30,
		40: 5  # light_orb if it somehow got here (shouldn't happen)
	}

	var heal_amount = BENTO_FOOD_HEALING.get(food.id, 10)

	# Get target character
	var target = null
	var target_name = ""

	if is_player:
		target = get_tree().get_first_node_in_group("player")
		target_name = "Player"
	else:
		# Get companion
		var companions = get_tree().get_nodes_in_group("friendly_entities")
		if companions.size() > 0:
			target = companions[0]
			target_name = target.entity_name if target.has_method("get") else "Companion"

	if target == null or not target.has_method("get"):
		print("Cannot find target to feed!")
		return

	# Apply healing
	var old_hp = target.current_hp
	target.current_hp = min(target.current_hp + heal_amount, target.max_hp)
	var actual_heal = target.current_hp - old_hp

	# Emit HP changed signal
	if target.has_signal("hp_changed"):
		target.hp_changed.emit(target.current_hp, target.max_hp)

	# Get food name
	var item = _item_db.get_item(food.id)
	var food_name = item.base_info.name.replace("_", " ").capitalize()

	# Show message
	print("🍽️ %s consumed %s! +%d HP (now %d/%d)" % [target_name, food_name, actual_heal, target.current_hp, target.max_hp])


func _is_food_item(item: InventoryItem) -> bool:
	"""Check if an item is a cooked food item (for bento box)"""
	if item == null or item.type != InventoryItem.TYPE_ITEM:
		return false
	# Cooked food item IDs: 27-39 (from item_db.gd)
	return item.id >= 27 and item.id <= 39


# ============================================================================
# BENTO BOX ACCESSORS
# ============================================================================

func get_bento_slot_data(slot_idx: int) -> InventoryItem:
	"""Get food item in bento slot (0-5)"""
	if slot_idx < 0 or slot_idx >= BENTO_SLOTS:
		return null
	return _bento_slots[slot_idx]


func consume_bento_food(slot_idx: int) -> InventoryItem:
	"""Consume food from bento slot and return it (removes from bento)"""
	if slot_idx < 0 or slot_idx >= BENTO_SLOTS:
		return null

	var food = _bento_slots[slot_idx]
	if food == null:
		return null

	# Decrement count
	food.count -= 1

	# If count reaches 0, remove from bento
	if food.count <= 0:
		_bento_slots[slot_idx] = null
		_bento_slot_views[slot_idx].get_display().set_item(null)
	else:
		# Update view to show new count
		_bento_slot_views[slot_idx].get_display().set_item(food)

	emit_signal("changed")
	return food


func consume_bento_food_smart() -> InventoryItem:
	"""Consume weakest food from bento (smart priority)"""
	# Food healing values (from recipes_database.json)
	var food_healing = {
		27: 15, 28: 10, 29: 10, 30: 20, 31: 15, 32: 10,
		33: 25, 34: 20, 35: 20, 36: 25, 37: 20, 38: 28, 39: 30
	}

	# Find weakest food in bento
	var weakest_idx = -1
	var weakest_healing = 9999

	for i in range(BENTO_SLOTS):
		if _bento_slots[i] != null:
			var healing = food_healing.get(_bento_slots[i].id, 10)
			if healing < weakest_healing:
				weakest_healing = healing
				weakest_idx = i

	# Consume weakest food
	if weakest_idx >= 0:
		return consume_bento_food(weakest_idx)

	return null


func _create_power_harmonization_button():
	"""Add Power Harmonization button below bento box"""
	var vbox = _panel_container.get_node("MainHBox/VB")

	# Add separator
	var separator = HSeparator.new()
	vbox.add_child(separator)

	# Create centered container for button
	var button_center = CenterContainer.new()
	vbox.add_child(button_center)

	# Create the harmonization button
	var harmonize_btn = Button.new()
	harmonize_btn.text = "✨ Power Harmonization ✨"
	harmonize_btn.custom_minimum_size = Vector2(250, 40)
	harmonize_btn.add_theme_font_size_override("font_size", 14)

	# Style with purple theme to match skyshard aesthetic
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.2, 0.6, 0.8)  # Purple
	style.border_color = Color(0.6, 0.4, 0.8)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	harmonize_btn.add_theme_stylebox_override("normal", style)

	var style_hover = style.duplicate()
	style_hover.bg_color = Color(0.5, 0.3, 0.7, 0.9)
	harmonize_btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = style.duplicate()
	style_pressed.bg_color = Color(0.3, 0.15, 0.5, 0.9)
	harmonize_btn.add_theme_stylebox_override("pressed", style_pressed)

	harmonize_btn.pressed.connect(_show_power_harmonization_modal)
	button_center.add_child(harmonize_btn)


func _create_equipment_panels():
	"""Create player and companion equipment panels with paper dolls"""
	# Get the VBoxContainer that currently holds inventory
	var vbox = _panel_container.get_node("VB")
	var parent = vbox.get_parent()

	# Remove VBox from parent temporarily
	parent.remove_child(vbox)

	# Create horizontal container to hold: [Player Equipment] [Inventory] [Companion Equipment]
	var hbox = HBoxContainer.new()
	hbox.name = "MainHBox"
	hbox.add_theme_constant_override("separation", 20)  # Increased spacing for breathing room
	parent.add_child(hbox)

	# Create player equipment panel (left side)
	_player_equipment_panel = _create_paper_doll_panel("Player", true)
	hbox.add_child(_player_equipment_panel)

	# Add inventory back to center
	hbox.add_child(vbox)

	# Create companion equipment panel (right side)
	_companion_equipment_panel = _create_paper_doll_panel("Companion", false)
	hbox.add_child(_companion_equipment_panel)

	print("Equipment panels created")


func _create_paper_doll_panel(character_name: String, is_player: bool) -> VBoxContainer:
	"""Create a paper doll panel with avatar and weapon slot"""
	var panel = VBoxContainer.new()
	panel.name = character_name + "Equipment"
	panel.add_theme_constant_override("separation", 8)
	panel.custom_minimum_size = Vector2(180, 250)  # Increased size for better visibility

	# Title label
	var title = Label.new()
	title.text = character_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)  # Slightly larger font
	panel.add_child(title)

	# For companion: Create horizontal layout with behavior buttons on left
	var content_container: Control
	var behavior_buttons_vbox: VBoxContainer = null
	
	if not is_player:
		# Companion: Use HBoxContainer for [Buttons] [Avatar+Equipment]
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 4)
		
		# Left side: Behavior buttons (vertical stack)
		behavior_buttons_vbox = VBoxContainer.new()
		behavior_buttons_vbox.add_theme_constant_override("separation", 4)
		
		# Create 4 behavior buttons with emojis
		var behaviors = ["normal", "aggressive", "defensive", "guard"]
		var emojis = ["⚖️", "⚔️", "🛡️", "🏰"]
		var colors = [
			Color(0.7, 0.7, 0.7),   # Normal - gray
			Color(1.0, 0.3, 0.3),   # Aggressive - red
			Color(0.3, 0.5, 1.0),   # Defensive - blue
			Color(0.8, 0.6, 0.3)    # Guard - orange/brown
		]
		var tooltips = ["Normal: Balanced behavior", "Aggressive: Attack more enemies from farther away", "Defensive: Stay close and protect", "Guard: Stay at current position and defend"]
		
		for i in range(4):
			var btn = Button.new()
			btn.name = behaviors[i].capitalize() + "Button"
			btn.text = emojis[i]
			btn.custom_minimum_size = Vector2(32, 32)
			btn.add_theme_font_size_override("font_size", 18)
			btn.modulate = colors[i]
			btn.tooltip_text = tooltips[i]
			btn.pressed.connect(_on_behavior_button_pressed.bind(behaviors[i]))
			behavior_buttons_vbox.add_child(btn)
		
		hbox.add_child(behavior_buttons_vbox)
		
		# Right side: Avatar and equipment (in a VBoxContainer)
		content_container = VBoxContainer.new()
		content_container.add_theme_constant_override("separation", 8)
		hbox.add_child(content_container)
		
		panel.add_child(hbox)
	else:
		# Player: Just use the panel directly (no behavior buttons)
		content_container = panel

	# Avatar (reuse party UI avatar) - made clickable for food consumption
	var avatar_bg = Panel.new()
	avatar_bg.name = "AvatarBG"
	avatar_bg.custom_minimum_size = Vector2(128, 128)  # Bigger avatar, less squished

	var avatar_style = StyleBoxFlat.new()
	avatar_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	avatar_style.border_color = Color(0.6, 0.5, 0.3)
	avatar_style.set_border_width_all(2)
	avatar_bg.add_theme_stylebox_override("panel", avatar_style)

	# Make avatar clickable for drag-to-consume food
	var avatar_button = Button.new()
	avatar_button.name = "AvatarButton"
	avatar_button.custom_minimum_size = Vector2(128, 128)
	avatar_button.flat = true  # Invisible button
	avatar_button.mouse_filter = Control.MOUSE_FILTER_PASS
	avatar_button.pressed.connect(_on_avatar_clicked.bind(is_player))
	avatar_bg.add_child(avatar_button)

	var avatar_texture = TextureRect.new()
	avatar_texture.name = "AvatarTexture"
	avatar_texture.custom_minimum_size = Vector2(124, 124)  # Match larger avatar size
	avatar_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	avatar_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_texture.position = Vector2(2, 2)
	avatar_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let button handle clicks
	avatar_bg.add_child(avatar_texture)

	# Load avatar based on player data
	_load_avatar_for_panel(avatar_texture, is_player)

	# Center avatar in panel
	var avatar_center = CenterContainer.new()
	avatar_center.add_child(avatar_bg)
	content_container.add_child(avatar_center)

	# Equipment section - different layout for player vs companion
	if is_player:
		# Player: Single weapon slot (vertical layout) - matching companion flow
		var equip_label = Label.new()
		equip_label.text = "Equipment"
		equip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equip_label.add_theme_font_size_override("font_size", 12)
		content_container.add_child(equip_label)

		# Player info area (name, role, stats) - BEFORE the weapon slot
		var info_vbox = VBoxContainer.new()
		info_vbox.name = "InfoVBox"
		info_vbox.add_theme_constant_override("separation", 4)

		var name_label = Label.new()
		name_label.name = "NameLabel"
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_vbox.add_child(name_label)

		var role_label = Label.new()
		role_label.name = "RoleLabel"
		role_label.add_theme_font_size_override("font_size", 10)
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_vbox.add_child(role_label)

		# First stats row: HP and ATK
		var stat_hbox1 = HBoxContainer.new()
		stat_hbox1.name = "StatsHBox1"
		stat_hbox1.add_theme_constant_override("separation", 6)

		var hp_label = Label.new()
		hp_label.name = "HPLabel"
		hp_label.add_theme_font_size_override("font_size", 10)
		stat_hbox1.add_child(hp_label)

		var atk_label = Label.new()
		atk_label.name = "ATKLabel"
		atk_label.add_theme_font_size_override("font_size", 10)
		stat_hbox1.add_child(atk_label)

		info_vbox.add_child(stat_hbox1)

		# Second stats row: DEF and LUCK
		var stat_hbox2 = HBoxContainer.new()
		stat_hbox2.name = "StatsHBox2"
		stat_hbox2.add_theme_constant_override("separation", 6)

		var def_label = Label.new()
		def_label.name = "DEFLabel"
		def_label.add_theme_font_size_override("font_size", 10)
		stat_hbox2.add_child(def_label)

		var luck_label = Label.new()
		luck_label.name = "LUCKLabel"
		luck_label.add_theme_font_size_override("font_size", 10)
		stat_hbox2.add_child(luck_label)

		info_vbox.add_child(stat_hbox2)

		content_container.add_child(info_vbox)

		# Weapon label
		var weapon_label = Label.new()
		weapon_label.text = "Accessory"
		weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_label.add_theme_font_size_override("font_size", 10)
		content_container.add_child(weapon_label)

		# Weapon slot (below stats, matching companion layout)
		const InventorySlot = preload("res://blocky_game/gui/inventory/inventory_slot.tscn")
		var weapon_slot = InventorySlot.instantiate()
		weapon_slot.custom_minimum_size = Vector2(64, 64)
		weapon_slot.pressed.connect(_on_equipment_slot_pressed.bind(is_player))
		_player_weapon_slot_view = weapon_slot

		var weapon_center = CenterContainer.new()
		weapon_center.add_child(weapon_slot)
		content_container.add_child(weapon_center)
	else:
		# Companion: Weapon + Accessory side-by-side (horizontal layout)
		var equip_label = Label.new()
		equip_label.text = "Equipment"
		equip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equip_label.add_theme_font_size_override("font_size", 12)
		content_container.add_child(equip_label)
		
		# Container for both slots (horizontal)
		var slots_hbox = HBoxContainer.new()
		slots_hbox.add_theme_constant_override("separation", 8)
		
		# Left side: Weapon slot with label
		var weapon_vbox = VBoxContainer.new()
		weapon_vbox.add_theme_constant_override("separation", 2)
		
		var weapon_label = Label.new()
		weapon_label.text = "Weapon"
		weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_label.add_theme_font_size_override("font_size", 10)
		weapon_vbox.add_child(weapon_label)
		
		const InventorySlot = preload("res://blocky_game/gui/inventory/inventory_slot.tscn")
		var weapon_slot = InventorySlot.instantiate()
		weapon_slot.custom_minimum_size = Vector2(64, 64)
		weapon_slot.pressed.connect(_on_equipment_slot_pressed.bind(is_player))
		_companion_weapon_slot_view = weapon_slot
		weapon_vbox.add_child(weapon_slot)
		
		slots_hbox.add_child(weapon_vbox)
		
		# Right side: Accessory slot with label
		var accessory_vbox = VBoxContainer.new()
		accessory_vbox.add_theme_constant_override("separation", 2)
		
		var accessory_label = Label.new()
		accessory_label.text = "Accessory"
		accessory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		accessory_label.add_theme_font_size_override("font_size", 10)
		accessory_vbox.add_child(accessory_label)
		
		var accessory_slot = InventorySlot.instantiate()
		accessory_slot.custom_minimum_size = Vector2(64, 64)
		accessory_slot.pressed.connect(_on_accessory_slot_pressed)
		_companion_accessory_slot_view = accessory_slot
		accessory_vbox.add_child(accessory_slot)
		# Keep a reference to accessory view for later updates
		_companion_accessory_slot_view = accessory_slot

		# Companion info area (details that don't fit in Party UI)
		var info_vbox = VBoxContainer.new()
		info_vbox.name = "InfoVBox"
		info_vbox.add_theme_constant_override("separation", 4)

		var name_label = Label.new()
		name_label.name = "NameLabel"
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_vbox.add_child(name_label)

		var role_label = Label.new()
		role_label.name = "RoleLabel"
		role_label.add_theme_font_size_override("font_size", 10)
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_vbox.add_child(role_label)

		var title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.visible = false
		info_vbox.add_child(title_label)

		var stat_hbox = HBoxContainer.new()
		stat_hbox.name = "StatsHBox"
		stat_hbox.add_theme_constant_override("separation", 6)

		var hp_label = Label.new()
		hp_label.name = "HPLabel"
		hp_label.add_theme_font_size_override("font_size", 10)
		stat_hbox.add_child(hp_label)

		var atk_label = Label.new()
		atk_label.name = "ATKLabel"
		atk_label.add_theme_font_size_override("font_size", 10)
		stat_hbox.add_child(atk_label)

		var def_label = Label.new()
		def_label.name = "DEFLabel"
		def_label.add_theme_font_size_override("font_size", 10)
		stat_hbox.add_child(def_label)

		info_vbox.add_child(stat_hbox)

		# Show extra info: companion name, role, title, and stats
		info_vbox.visible = true

		content_container.add_child(info_vbox)
		
		slots_hbox.add_child(accessory_vbox)
		
		# Center the horizontal container
		var slots_center = CenterContainer.new()
		slots_center.add_child(slots_hbox)
		content_container.add_child(slots_center)

	# Add Hunt button for companion (only show for companion)
	if not is_player:
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		content_container.add_child(spacer)
		
		var hunt_button = Button.new()
		hunt_button.name = "HuntButton"
		hunt_button.text = "Hunt"
		hunt_button.custom_minimum_size = Vector2(120, 40)
		hunt_button.add_theme_font_size_override("font_size", 14)
		hunt_button.modulate = Color(0.9, 0.7, 0.2)  # Golden color
		hunt_button.pressed.connect(_on_hunt_button_pressed)
		
		var hunt_center = CenterContainer.new()
		hunt_center.add_child(hunt_button)
		content_container.add_child(hunt_center)

	return panel


func _on_behavior_button_pressed(mode: String):
	"""Change companion behavior mode"""
	var companion = get_tree().get_first_node_in_group("companions")
	if companion and companion.has_method("set_behavior_mode"):
		companion.set_behavior_mode(mode)
		print("🎯 Companion behavior set to: %s" % mode.capitalize())


func _load_avatar_for_panel(avatar_texture: TextureRect, is_player: bool):
	"""Load the appropriate avatar sprite for player or companion"""
	if is_player:
		# Load player avatar from PlayerData
		var sprite_path = PlayerData.get_avatar_path()
		if sprite_path != "" and ResourceLoader.exists(sprite_path):
			avatar_texture.texture = load(sprite_path)
	else:
		# Load companion avatar using roster-aware helper (preferred) to avoid
		# mismatches with PartyUI.
		var sprite_path = CompanionManager.get_active_avatar_path()
		if sprite_path != "" and ResourceLoader.exists(sprite_path):
			avatar_texture.texture = load(sprite_path)


func _on_equipment_slot_pressed(is_player_slot: bool):
	"""Handle clicking on equipment slots"""
	var equipment_slot = _player_weapon_slot if is_player_slot else _companion_weapon_slot
	var equipment_slot_view = _player_weapon_slot_view if is_player_slot else _companion_weapon_slot_view

	if _dragged_slot == -1:
		# Not dragging anything - try to pick up equipped item
		if equipment_slot != null:
			# Start dragging equipped item
			_dragged_slot = -999 if is_player_slot else -998  # Special IDs for equipment slots
			equipment_slot_view.get_display().set_item(null)
			_dragged_item_view.start(equipment_slot)
	else:
		# Dragging something - try to equip it
		var dragged_item = null

		# Get the item being dragged
		if _dragged_slot >= 0:
			# Dragging from inventory
			dragged_item = _slots[_dragged_slot]
		elif _dragged_slot == -999:
			# Dragging player weapon
			dragged_item = _player_weapon_slot
		elif _dragged_slot == -998:
			# Dragging companion weapon
			dragged_item = _companion_weapon_slot

		# Check if it's a weapon (TYPE_ITEM)
		if dragged_item != null and dragged_item.type == InventoryItem.TYPE_ITEM:
			# Equip the weapon
			if _dragged_slot >= 0:
				# Remove from inventory
				_slots[_dragged_slot] = equipment_slot  # Swap (put old weapon in inventory)
				_slot_views[_dragged_slot].get_display().set_item(_slots[_dragged_slot])
			elif _dragged_slot == -999:
				# Moving player weapon - just clear it
				_player_weapon_slot = null
			elif _dragged_slot == -998:
				# Moving companion weapon - just clear it
				_companion_weapon_slot = null
				# Clear saved weapon (will use default)
				CompanionManager.equipped_weapon_id = -1
				CompanionManager.save_to_file()

			# Equip new weapon
			if is_player_slot:
				_player_weapon_slot = dragged_item
				_player_weapon_slot_view.get_display().set_item(_player_weapon_slot)
			else:
				_companion_weapon_slot = dragged_item
				_companion_weapon_slot_view.get_display().set_item(_companion_weapon_slot)
				# Save to CompanionManager
				CompanionManager.equipped_weapon_id = dragged_item.id
				CompanionManager.save_to_file()

			_dragged_item_view.stop()
			_dragged_slot = -1
			emit_signal("changed")
			emit_signal("equipment_changed")
		else:
			# Can't equip non-weapons
			print("Can only equip weapons in weapon slot!")
			# Cancel drag
			if _dragged_slot >= 0:
				_slot_views[_dragged_slot].get_display().set_item(_slots[_dragged_slot])
			elif _dragged_slot == -999:
				_player_weapon_slot_view.get_display().set_item(_player_weapon_slot)
			elif _dragged_slot == -998:
				_companion_weapon_slot_view.get_display().set_item(_companion_weapon_slot)
			_dragged_item_view.stop()
			_dragged_slot = -1


## ============================================================================
## ACCESSORY SLOT FUNCTIONS (Companion Only)
## ============================================================================

func _on_accessory_slot_pressed():
	"""Handle clicking companion accessory slot"""
	if _dragged_slot != -1:
		# Try to equip dragged item
		var dragged_item = _slots[_dragged_slot] if _dragged_slot >= 0 else null
		
		if dragged_item != null:
			# Check if it's a valid accessory (must have an EQUIP power)
			if dragged_item.skyshard_power != "" and _is_equip_power(dragged_item.skyshard_power):
				# Swap items
				var old_accessory = _companion_accessory_slot
				_companion_accessory_slot = dragged_item
				_slots[_dragged_slot] = old_accessory
				
				# Update views
				_update_accessory_slot_view()
				_slot_views[_dragged_slot].get_display().set_item(_slots[_dragged_slot])
				
				# End drag
				_dragged_item_view.stop()
				_dragged_slot = -1
				
				# Notify companion
				_update_companion_accessory()
				
				equipment_changed.emit()
				print("✨ Equipped accessory with power: %s" % dragged_item.skyshard_power)
			else:
				# Invalid item - return it to original slot
				print("❌ Only EQUIP powers (stone_skin, moon_jump, flame_aura, glide, return) can go in accessory slot!")
				if _dragged_slot >= 0 and _dragged_slot < _slots.size():
					# Return item to original slot
					_slot_views[_dragged_slot].get_display().set_item(_slots[_dragged_slot])
				_dragged_item_view.stop()
				_dragged_slot = -1
		else:
			_dragged_item_view.stop()
			_dragged_slot = -1
	else:
		# Start dragging accessory if there is one
		if _companion_accessory_slot != null:
			_dragged_slot = -997  # Special ID for accessory slot
			_dragged_item_view.start(_companion_accessory_slot)
func _on_companion_roster_swapped(index: int) -> void:
	"""Called when player swaps companions in the roster; refresh inventory UI."""
	print("Inventory: companion swap signal received -> index=%d" % index)
	# Schedule immediate and deferred updates to ensure the new companion shows up
	# Update right away and schedule follow-ups to ensure the spawned Companion
	# and any delayed state changes are picked up by the UI.
	_update_companion_panel()
	call_deferred("_update_companion_panel")
	call_deferred("_update_companion_panel")

	# Also schedule a couple of short timer-based refreshes in case the spawn
	# happens later in the frame pipeline. This is robust against race
	# conditions observed where the swap signal arrives slightly before the
	# Companion node is added to the scene.
	# NOTE: Using await/get_tree().create_timer allows the UI to re-check after
	# a few frames without creating a permanent Timer node.
	await get_tree().create_timer(0.05).timeout
	_update_companion_panel()


# _on_companion_spawned was removed during revert - inventory listens only to companion_swapped

func _update_companion_panel() -> void:
	"""Refresh the companion paper-doll area with name, role, HP, ATK, DEF, and avatar."""
	if not _companion_equipment_panel:
		# Try to locate the panel in the scene tree if it wasn't created yet
		var found = get_tree().get_root().find_node("CompanionEquipment", true, false)
		if found:
			_companion_equipment_panel = found
			print("Inventory: found CompanionEquipment node at runtime")
		else:
			print("Inventory: CompanionEquipment not found, can't update panel")
			return
	print("Inventory: Updating companion panel - _companion_equipment_panel valid: %s" % (_companion_equipment_panel != null))
	# Traverse to content_container first
	var content_container = null
	for child in _companion_equipment_panel.get_children():
		if child is Container:
			# Heuristic: look for the first container with AvatarBG and InfoVBox children
			if child.find_child("AvatarBG", true, false) and child.find_child("InfoVBox", true, false):
				content_container = child
				break
	if not content_container:
		print("Inventory: content_container not found in CompanionEquipment panel")
		return
	# Now look for AvatarBG/AvatarTexture and InfoVBox inside content_container
	var avatar_bg = content_container.find_child("AvatarBG", true, false)
	var avatar_texture = null
	if avatar_bg:
		for child in avatar_bg.get_children():
			if child is TextureRect and child.name == "AvatarTexture":
				avatar_texture = child
				break
	print("Inventory: AvatarBG node: %s" % (avatar_bg != null))
	print("Inventory: AvatarTexture node: %s" % (avatar_texture != null))
	if avatar_texture and avatar_texture is TextureRect:
		var active = null
		if CompanionManager and CompanionManager.using_roster_system:
			active = CompanionManager.get_active_companion()
		var race = CompanionManager.companion_race
		var gender = CompanionManager.companion_gender
		if active != null:
			race = active.race
			gender = active.gender
		# Use roster-aware avatar helper so Inventory and PartyUI pick the same sprite
		var avatar_path = CompanionManager.get_active_avatar_path("ready")
		print("Inventory: companion avatar path=%s (race=%s gender=%s)" % [avatar_path, race, gender])
		var avatar_exists = ResourceLoader.exists(avatar_path)
		print("Inventory: ResourceLoader.exists(%s) = %s" % [avatar_path, avatar_exists])
		if avatar_exists:
			var loaded_texture = load(avatar_path)
			print("Inventory: loaded texture: %s" % (loaded_texture != null))
			avatar_texture.texture = loaded_texture
			print("Inventory: avatar texture set for %s" % race)
		else:
			print("Inventory: Avatar texture path does not exist: %s" % avatar_path)
	elif avatar_texture:
		print("Inventory: AvatarTexture node is not a TextureRect! Type: %s" % typeof(avatar_texture))
	var info_vbox = content_container.find_child("InfoVBox", true, false)
	print("Inventory: InfoVBox node: %s" % (info_vbox != null))
	if info_vbox:
		var name_label = info_vbox.find_child("NameLabel", true, false)
		var role_label = info_vbox.find_child("RoleLabel", true, false)
		var title_label = info_vbox.find_child("TitleLabel", true, false)
		var hp_label = info_vbox.find_child("HPLabel", true, false)
		var atk_label = info_vbox.find_child("ATKLabel", true, false)
		var def_label = info_vbox.find_child("DEFLabel", true, false)
		print("Inventory: NameLabel: %s, RoleLabel: %s, TitleLabel: %s, HPLabel: %s, ATKLabel: %s, DEFLabel: %s" % [name_label != null, role_label != null, title_label != null, hp_label != null, atk_label != null, def_label != null])

		var active = null
		if CompanionManager and CompanionManager.using_roster_system:
			active = CompanionManager.get_active_companion()
		# If active is still null, ensure we fall back to legacy companion
		if active == null:
			print("Inventory: no roster active companion. Falling back to legacy values.")

		# Debug output
		print("Inventory: Updating companion panel. using_roster_system=%s" % CompanionManager.using_roster_system)
		var a_name = active.companion_name if active != null else CompanionManager.get_companion_name()
		print("Inventory: active companion name=%s" % a_name)

		# Name & role
		if name_label:
			name_label.text = active.companion_name if active != null else CompanionManager.get_companion_name()
		if role_label:
			var r = active.role if active != null else CompanionManager.companion_role
			role_label.text = "[%s]" % CharacterQuiz.get_role_name(r)

		# Title
		if title_label:
			var te = ""
			var tt = ""
			if active != null:
				te = active.title_emoji
				tt = active.active_title
			else:
				te = CompanionManager.saved_title_emoji
				tt = CompanionManager.saved_title
			if tt != "":
				title_label.text = "%s %s" % [te, tt]
				title_label.visible = true
			else:
				title_label.text = ""
				title_label.visible = false

		# HP + stats
		if hp_label:
			var current_hp = CompanionManager.get_companion_max_hp()
			var max_hp = CompanionManager.get_companion_max_hp()
			var comps = get_tree().get_nodes_in_group("companions")
			if comps.size() > 0:
				var comp_node = comps[0]
				if comp_node and typeof(comp_node.current_hp) in [TYPE_INT, TYPE_FLOAT]:
					current_hp = comp_node.current_hp
					var comp_max = comp_node.get("max_hp")
					if comp_max != null:
						max_hp = comp_max
			if max_hp == 0:
				max_hp = CompanionManager.get_companion_max_hp()
			hp_label.text = "%d/%d HP" % [current_hp, max_hp]

		if atk_label:
			atk_label.text = "ATK: +%d" % CompanionManager.get_companion_attack_bonus()

		if def_label:
			def_label.text = "DEF: %d" % CompanionManager.get_companion_defense()

	# Update weapon and accessory slots (use roster data if present, otherwise use legacy saved values)
	var active = null
	if CompanionManager and CompanionManager.using_roster_system:
		active = CompanionManager.get_active_companion()

	# Weapon
	if active != null and active.equipped_weapon_id >= 0:
		# Validate that the item still exists (could have been sold)
		if _validate_item_exists(active.equipped_weapon_id):
			_companion_weapon_slot = _make_item_with_count(InventoryItem.TYPE_ITEM, active.equipped_weapon_id, active.equipped_weapon_count)
			# Set skyshard power if present
			if active.equipped_weapon_power != "":
				_companion_weapon_slot.skyshard_power = active.equipped_weapon_power
			print("🔍 Inventory: equipped weapon from roster: %d (x%d) with power '%s'" % [active.equipped_weapon_id, active.equipped_weapon_count, active.equipped_weapon_power])
			print("🔍   weapon_slot.id=%d, .count=%d, .skyshard_power='%s'" % [
				_companion_weapon_slot.id, _companion_weapon_slot.count, _companion_weapon_slot.skyshard_power
			])
			if _companion_weapon_slot_view:
				_companion_weapon_slot_view.get_display().set_item(_companion_weapon_slot)
		else:
			# Item was sold or no longer exists - fall back to default
			print("Inventory: equipped weapon %d no longer exists, falling back to default" % active.equipped_weapon_id)
			active.equipped_weapon_id = -1  # Reset in roster
			_initialize_companion_default_weapon()
	else:
		if CompanionManager and CompanionManager.equipped_weapon_id >= 0:
			if _validate_item_exists(CompanionManager.equipped_weapon_id):
				_companion_weapon_slot = _make_item(InventoryItem.TYPE_ITEM, CompanionManager.equipped_weapon_id)
				if _companion_weapon_slot_view:
					_companion_weapon_slot_view.get_display().set_item(_companion_weapon_slot)
			else:
				print("Inventory: legacy equipped weapon %d no longer exists, falling back to default" % CompanionManager.equipped_weapon_id)
				CompanionManager.equipped_weapon_id = -1
				_initialize_companion_default_weapon()
		else:
			# No saved weapon; initialize default
			_initialize_companion_default_weapon()
			print("Inventory: initialized default companion weapon")

	# Accessory
	if active != null and active.equipped_accessory_id >= 0:
		# Validate that the item still exists (could have been sold)
		if _validate_item_exists(active.equipped_accessory_id):
			_companion_accessory_slot = _make_item_with_count(InventoryItem.TYPE_ITEM, active.equipped_accessory_id, active.equipped_accessory_count)
			# Set skyshard power if present
			if active.equipped_accessory_power != "":
				_companion_accessory_slot.skyshard_power = active.equipped_accessory_power
			print("🔍 Inventory: equipped accessory from roster: %d (x%d) with power '%s'" % [active.equipped_accessory_id, active.equipped_accessory_count, active.equipped_accessory_power])
			print("🔍   accessory_slot.id=%d, .count=%d, .skyshard_power='%s'" % [
				_companion_accessory_slot.id, _companion_accessory_slot.count, _companion_accessory_slot.skyshard_power
			])
			if _companion_accessory_slot_view:
				_companion_accessory_slot_view.get_display().set_item(_companion_accessory_slot)
		else:
			# Item was sold or no longer exists - reset to none
			print("Inventory: equipped accessory %d no longer exists, removing" % active.equipped_accessory_id)
			active.equipped_accessory_id = -1  # Reset in roster
			_companion_accessory_slot = null
			if _companion_accessory_slot_view:
				_companion_accessory_slot_view.get_display().set_item(null)
	else:
		# Companion has no accessory (either from roster or legacy)
		if CompanionManager and CompanionManager.saved_accessory_id >= 0:
			if _validate_item_exists(CompanionManager.saved_accessory_id):
				print("Inventory: loaded legacy accessory %d" % CompanionManager.saved_accessory_id)
				_companion_accessory_slot = _make_item(InventoryItem.TYPE_ITEM, CompanionManager.saved_accessory_id)
				if _companion_accessory_slot_view:
					_companion_accessory_slot_view.get_display().set_item(_companion_accessory_slot)
			else:
				print("Inventory: legacy accessory %d no longer exists, removing" % CompanionManager.saved_accessory_id)
				CompanionManager.saved_accessory_id = -1
				_companion_accessory_slot = null
				if _companion_accessory_slot_view:
					_companion_accessory_slot_view.get_display().set_item(null)
		else:
			# No accessory at all - clear the slot
			_companion_accessory_slot = null
			if _companion_accessory_slot_view:
				_companion_accessory_slot_view.get_display().set_item(null)


func _update_player_panel() -> void:
	"""Refresh the player paper-doll area with name, role, HP, and bonus stats."""
	if not _player_equipment_panel:
		return

	# Find the InfoVBox in the player panel
	var content_container = _player_equipment_panel  # For player, the panel IS the content container
	var info_vbox = content_container.find_child("InfoVBox", true, false)

	if not info_vbox:
		return

	# Get labels (HP/ATK in StatsHBox1, DEF/LUCK in StatsHBox2)
	var name_label = info_vbox.find_child("NameLabel", true, false)
	var role_label = info_vbox.find_child("RoleLabel", true, false)
	var stat_hbox1 = info_vbox.find_child("StatsHBox1", true, false)
	var stat_hbox2 = info_vbox.find_child("StatsHBox2", true, false)

	var hp_label = null
	var atk_label = null
	var def_label = null
	var luck_label = null

	if stat_hbox1:
		hp_label = stat_hbox1.find_child("HPLabel", true, false)
		atk_label = stat_hbox1.find_child("ATKLabel", true, false)

	if stat_hbox2:
		def_label = stat_hbox2.find_child("DEFLabel", true, false)
		luck_label = stat_hbox2.find_child("LUCKLabel", true, false)

	# Update name
	if name_label:
		name_label.text = PlayerData.player_name if PlayerData.player_name != "" else "Player"

	# Update role
	if role_label:
		role_label.text = "[%s]" % PlayerData.get_role_name()

	# Update HP (get from player entity if available)
	if hp_label:
		var current_hp = PlayerData.max_hp  # Default to max HP
		var max_hp = PlayerData.max_hp
		var player = get_tree().get_first_node_in_group("player")
		if player:
			current_hp = player.current_hp
			max_hp = player.max_hp
		hp_label.text = "%d/%d HP" % [current_hp, max_hp]

	# Update bonus stats
	if atk_label:
		var bonus = PlayerData.bonus_attack
		atk_label.text = "ATK: +%d" % bonus if bonus > 0 else "ATK: 0"

	if def_label:
		var bonus = PlayerData.bonus_defense
		def_label.text = "DEF: +%d" % bonus if bonus > 0 else "DEF: 0"

	if luck_label:
		var bonus = PlayerData.bonus_luck
		luck_label.text = "LUCK: +%d" % bonus if bonus > 0 else "LUCK: 0"


func _validate_item_exists(item_id: int) -> bool:
	"""Validate that an item ID exists in the item database"""
	if item_id < 0:
		return false
	if not _item_db:
		return false
	# Try to get the item - if it fails, item doesn't exist
	var item = _item_db.get_item(item_id)
	return item != null


func _is_equip_power(power_name: String) -> bool:
	"""Check if power is an EQUIP type (passive powers)"""
	return power_name in ["stone_skin", "moon_jump", "flame_aura", "glide", "return"]


func _update_accessory_slot_view():
	"""Update companion accessory slot display"""
	if _companion_accessory_slot_view:
		_companion_accessory_slot_view.get_display().set_item(_companion_accessory_slot)


func _update_companion_accessory():
	"""Notify companion of accessory change"""
	var companion = get_tree().get_first_node_in_group("companions")
	if companion and companion.has_method("set_accessory"):
		companion.set_accessory(_companion_accessory_slot)


## ============================================================================
## HUNT BUTTON FUNCTIONS
## ============================================================================

func _on_hunt_button_pressed() -> void:
	"""Show hunt dialog when Hunt button is clicked"""
	_show_hunt_modal()


func _show_hunt_modal() -> void:
	"""Show modal dialog for hunt duration selection"""
	# Create modal background
	var modal_bg = ColorRect.new()
	modal_bg.name = "HuntModalBG"
	modal_bg.color = Color(0, 0, 0, 0.7)
	modal_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal_bg)
	
	# Create modal dialog
	var modal_dialog = Control.new()
	modal_dialog.name = "HuntModal"
	modal_dialog.custom_minimum_size = Vector2(400, 300)
	add_child(modal_dialog)
	
	# Center on screen
	var screen_size = get_viewport_rect().size
	modal_dialog.position = (screen_size - modal_dialog.custom_minimum_size) / 2
	
	# Modal background panel
	var panel = Panel.new()
	panel.custom_minimum_size = modal_dialog.custom_minimum_size
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.15, 0.1, 0.95)
	panel_style.border_color = Color(0.8, 0.6, 0.3)
	panel_style.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", panel_style)
	modal_dialog.add_child(panel)
	
	# Modal content container
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	content.position = Vector2(20, 20)
	content.size = modal_dialog.custom_minimum_size - Vector2(40, 40)
	modal_dialog.add_child(content)
	
	# Title
	var title = Label.new()
	title.text = "How long to hunt?"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	
	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "%s will hunt and find food/materials" % CompanionManager.get_companion_name()
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	content.add_child(spacer)
	
	# Button container
	var button_container = VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 10)
	content.add_child(button_container)
	
	# Duration buttons
	var durations = [
		{"hours": 4, "label": "4 Hours"},
		{"hours": 8, "label": "8 Hours"},
		{"hours": 24, "label": "Full Day (24 Hours)"}
	]
	
	for duration_data in durations:
		var btn = Button.new()
		btn.text = duration_data["label"]
		btn.custom_minimum_size = Vector2(350, 40)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_hunt_duration_selected.bindv([duration_data["hours"], modal_bg, modal_dialog]))
		button_container.add_child(btn)
	
	# Cancel button
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(350, 30)
	cancel_btn.add_theme_font_size_override("font_size", 12)
	cancel_btn.modulate = Color.GRAY
	cancel_btn.pressed.connect(_on_hunt_cancel.bindv([modal_bg, modal_dialog]))
	button_container.add_child(cancel_btn)


func _on_hunt_duration_selected(hours: int, modal_bg: ColorRect, modal_dialog: Control) -> void:
	"""Called when hunt duration is selected"""
	# Close modal
	modal_bg.queue_free()
	modal_dialog.queue_free()
	
	# Get hunting system
	var hunting_system = HuntingSystem
	if not hunting_system:
		push_error("Inventory: Could not find HuntingSystem (autoload)")
		return
	
	# Get companion - try multiple paths
	var companion = get_node_or_null("/root/Main/Game/Companion")
	if not companion:
		push_warning("Inventory: Path /root/Main/Game/Companion not found, trying alternate...")
		companion = get_node_or_null("../../../../Companion")  # Relative from inventory
		if not companion:
			push_error("Inventory: Could not find Companion via any path")
			return
	
	print("Inventory: Found companion: %s" % companion.name)
	
	# Start hunt
	if hunting_system.start_hunt(companion, hours):
		print("Inventory: Hunt started for %d hours" % hours)
		# Connect to hunt signals
		if not hunting_system.hunt_completed.is_connected(_on_hunt_completed):
			hunting_system.hunt_completed.connect(_on_hunt_completed)
		if not hunting_system.hunt_cancelled.is_connected(_on_hunt_cancelled):
			hunting_system.hunt_cancelled.connect(_on_hunt_cancelled)
	else:
		push_error("Inventory: start_hunt() returned false")


func _on_hunt_cancel(modal_bg: ColorRect, modal_dialog: Control) -> void:
	"""Called when cancel button is pressed"""
	modal_bg.queue_free()
	modal_dialog.queue_free()


func _on_hunt_completed(loot: Array) -> void:
	"""Called when hunt completes"""
	print("Inventory: Hunt completed! Loot count: %d" % loot.size())
	
	# Get hunting system to add loot to inventory
	if HuntingSystem:
		var loot_summary = HuntingSystem.add_loot_to_inventory(loot)
		_show_hunt_return_dialog(loot_summary)


func _on_hunt_cancelled(loot_kept: Array, loot_lost: Array) -> void:
	"""Called when hunt is cancelled"""
	print("Inventory: Hunt cancelled. Kept: %s, Lost: %s" % [loot_kept, loot_lost])
	
	# Get hunting system to add loot to inventory
	var hunting_system = get_node_or_null("/root/Main/Game/HuntingSystem")
	if hunting_system:
		var loot_summary = hunting_system.add_loot_to_inventory(loot_kept)
		_show_hunt_return_dialog(loot_summary, true)


func _show_hunt_return_dialog(loot_summary: Dictionary, was_cancelled: bool = false) -> void:
	"""Show dialog when companion returns from hunt"""
	# Create modal background
	var modal_bg = ColorRect.new()
	modal_bg.name = "HuntReturnBG"
	modal_bg.color = Color(0, 0, 0, 0.7)
	modal_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal_bg)
	
	# Create modal dialog
	var modal_dialog = Control.new()
	modal_dialog.name = "HuntReturnModal"
	modal_dialog.custom_minimum_size = Vector2(500, 350)
	add_child(modal_dialog)
	
	# Center on screen
	var screen_size = get_viewport_rect().size
	modal_dialog.position = (screen_size - modal_dialog.custom_minimum_size) / 2
	
	# Modal background panel
	var panel = Panel.new()
	panel.custom_minimum_size = modal_dialog.custom_minimum_size
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.15, 0.1, 0.95)
	panel_style.border_color = Color(0.2, 0.8, 0.2) if not was_cancelled else Color(0.8, 0.3, 0.2)
	panel_style.set_border_width_all(3)
	panel.add_theme_stylebox_override("panel", panel_style)
	modal_dialog.add_child(panel)
	
	# Modal content container
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	content.position = Vector2(20, 20)
	content.size = modal_dialog.custom_minimum_size - Vector2(40, 40)
	modal_dialog.add_child(content)
	
	# Companion name
	var companion_name_label = Label.new()
	companion_name_label.text = CompanionManager.get_companion_name()
	companion_name_label.add_theme_font_size_override("font_size", 18)
	companion_name_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
	companion_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(companion_name_label)
	
	# Return message
	var message = Label.new()
	if was_cancelled:
		message.text = "I'm back! The hunt was cut short.\n(Lost 50% of my findings)"
	elif loot_summary.size() == 0:
		message.text = "I'm back... but I didn't find anything good.\nMaybe next time!"
	else:
		message.text = "I'm back! I found some great stuff!\nSome of these might make a good dish!"
	message.add_theme_font_size_override("font_size", 14)
	message.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(message)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	content.add_child(spacer)
	
	# Loot items
	if loot_summary.size() > 0:
		var loot_label = Label.new()
		loot_label.text = "Found:"
		loot_label.add_theme_font_size_override("font_size", 12)
		loot_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		content.add_child(loot_label)
		
		var items_text = ""
		for item_name in loot_summary.keys():
			var count = loot_summary[item_name]
			items_text += "• %s x%d\n" % [item_name, count]
		
		var items_label = Label.new()
		items_label.text = items_text.trim_suffix("\n")
		items_label.add_theme_font_size_override("font_size", 11)
		items_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		content.add_child(items_label)
	else:
		var empty_label = Label.new()
		empty_label.text = "(Found nothing this time...)"
		empty_label.add_theme_font_size_override("font_size", 11)
		empty_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		content.add_child(empty_label)
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(460, 40)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.pressed.connect(_on_hunt_return_close.bindv([modal_bg, modal_dialog]))
	content.add_child(close_btn)


func _on_hunt_return_close(modal_bg: ColorRect, modal_dialog: Control) -> void:
	"""Called when closing hunt return dialog"""
	modal_bg.queue_free()
	modal_dialog.queue_free()


# ============================================================================
# SKYSHARD ENHANCEMENT SYSTEM
# ============================================================================

func _show_power_selection_modal(weapon_slot_idx: int) -> void:
	"""Show modal to choose a permanent power for a weapon that has 5 skyshards"""
	# Create modal background
	var modal_bg = ColorRect.new()
	modal_bg.name = "PowerSelectionBG"
	modal_bg.color = Color(0, 0, 0, 0.8)
	modal_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal_bg)

	# Create modal dialog
	var modal_dialog = Control.new()
	modal_dialog.name = "PowerSelectionModal"
	modal_dialog.custom_minimum_size = Vector2(600, 500)
	add_child(modal_dialog)

	# Center on screen
	var screen_size = get_viewport_rect().size
	modal_dialog.position = (screen_size - modal_dialog.custom_minimum_size) / 2

	# Modal background panel
	var panel = Panel.new()
	panel.custom_minimum_size = modal_dialog.custom_minimum_size
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.98)
	panel_style.border_color = Color(0.4, 0.7, 1.0)  # Light blue (skyshard color)
	panel_style.set_border_width_all(4)
	panel.add_theme_stylebox_override("panel", panel_style)
	modal_dialog.add_child(panel)

	# Modal content container
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	content.position = Vector2(20, 20)
	content.size = modal_dialog.custom_minimum_size - Vector2(40, 40)
	modal_dialog.add_child(content)

	# Get weapon info
	var weapon = _slots[weapon_slot_idx]
	var weapon_name = _item_db.get_item(weapon.id).base_info.name.capitalize()

	# Title
	var title = Label.new()
	title.text = "✨ Skyshard Power Selection ✨"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Choose a permanent power for: %s\n(This choice cannot be changed!)" % weapon_name
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	content.add_child(spacer)

	# Power options
	# Active powers = work from hotbar when attacking
	# Passive powers = work from equipment slot (always active)
	var powers = [
		{"name": "life_steal", "display": "Life Steal", "desc": "Heals 25% of damage dealt", "slot": "HOTBAR"},
		{"name": "meteor_strike", "display": "Meteor Strike", "desc": "Summons a meteor on hit", "slot": "HOTBAR"},
		{"name": "ice_burst", "display": "Ice Burst", "desc": "Freezes enemies in radius on hit", "slot": "HOTBAR"},
		{"name": "lightning_chain", "display": "Lightning Chain", "desc": "Damage jumps to nearby enemies", "slot": "HOTBAR"},
		{"name": "poison_cloud", "display": "Poison Cloud", "desc": "Leaves poison AoE on impact", "slot": "HOTBAR"},
		{"name": "knife_volley", "display": "Knife Volley", "desc": "Launches 3 knives on attack", "slot": "HOTBAR"},
		{"name": "wind_dash", "display": "Wind Dash", "desc": "Speed boost for 3s after hit", "slot": "HOTBAR"},
		{"name": "return", "display": "Return", "desc": "Retrieve thrown projectiles with right-click", "slot": "EQUIP"},
		{"name": "stone_skin", "display": "Stone Skin", "desc": "+50% defense while equipped", "slot": "EQUIP"},
		{"name": "moon_jump", "display": "Moon Jump", "desc": "Triple jump height while equipped", "slot": "EQUIP"},
		{"name": "flame_aura", "display": "Flame Aura", "desc": "Burns nearby enemies constantly", "slot": "EQUIP"},
		{"name": "glide", "display": "Glide", "desc": "Slow fall (synergy with Wind Walker Boots)", "slot": "EQUIP"}
	]

	# GRAPPLING HOOK EXCLUSIVE POWER: Pull (only shows for grappling hook)
	const GRAPPLING_HOOK_ID = 1
	if weapon.id == GRAPPLING_HOOK_ID:
		powers.append({"name": "pull", "display": "Pull", "desc": "Right-click to pull enemies toward you (yeet mechanic!)", "slot": "HOTBAR"})

	# Scroll container for powers
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 320)
	content.add_child(scroll)

	var power_list = VBoxContainer.new()
	power_list.add_theme_constant_override("separation", 8)
	scroll.add_child(power_list)

	# Create button for each power
	for power_data in powers:
		var power_btn = Button.new()
		power_btn.custom_minimum_size = Vector2(540, 50)
		power_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Determine slot icon and color
		var slot_icon = "⚔️" if power_data["slot"] == "HOTBAR" else "🛡️"
		var slot_text = "[Hotbar]" if power_data["slot"] == "HOTBAR" else "[Equip]"

		# Button text: [Slot] Icon Power name - description
		power_btn.text = "  %s %s %s - %s" % [slot_text, slot_icon, power_data["display"], power_data["desc"]]
		power_btn.add_theme_font_size_override("font_size", 12)

		# Connect to selection handler
		power_btn.pressed.connect(_on_power_selected.bind(weapon_slot_idx, power_data["name"], modal_bg, modal_dialog))

		power_list.add_child(power_btn)


func _on_power_selected(weapon_slot_idx: int, power_name: String, modal_bg: ColorRect, modal_dialog: Control) -> void:
	"""Called when a power is selected"""
	var weapon = _slots[weapon_slot_idx]

	# Set the power (permanent, cannot be changed!)
	weapon.skyshard_power = power_name

	# Keep skyshard_count at 5 to show weapon is "maxed out"
	# (System prevents adding more skyshards once a power is chosen)
	weapon.skyshard_count = 5

	# Update display
	_slot_views[weapon_slot_idx].get_display().set_item(weapon)

	# Close modal
	modal_bg.queue_free()
	modal_dialog.queue_free()

	# Show confirmation
	var weapon_name = _item_db.get_item(weapon.id).base_info.name.capitalize()
	print("⚡ Power Unlocked! %s now has '%s' power (PERMANENT)" % [weapon_name, power_name])
	print("   This weapon cannot be enhanced further. Choose wisely for your next weapon!")

	emit_signal("changed")


# ============================================================================
# POWER HARMONIZATION SYSTEM (Fusion)
# ============================================================================

var _harmonization_slot1: InventoryItem = null  # Source item (will be destroyed)
var _harmonization_slot2: InventoryItem = null  # Target item (will receive power)
var _harmonization_modal_bg: ColorRect = null
var _harmonization_modal: Control = null

func _show_power_harmonization_modal() -> void:
	"""Show modal for fusing two powered items together"""
	print("🔧 _show_power_harmonization_modal called!")

	# Get the root scene to add modal to (not inventory!)
	var root = get_tree().root
	if not root:
		push_error("Cannot show harmonization modal - no root node")
		return

	# Create modal background (fill entire screen)
	_harmonization_modal_bg = ColorRect.new()
	_harmonization_modal_bg.name = "HarmonizationBG"
	_harmonization_modal_bg.color = Color(0, 0, 0, 0.85)
	_harmonization_modal_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	# Make it fill the screen
	_harmonization_modal_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_harmonization_modal_bg)
	print("  Added modal background to root")

	# Create modal dialog
	_harmonization_modal = Control.new()
	_harmonization_modal.name = "HarmonizationModal"
	_harmonization_modal.custom_minimum_size = Vector2(700, 600)
	root.add_child(_harmonization_modal)
	print("  Added modal dialog to root")

	# IMPORTANT: Force mouse to be visible when modal opens
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Center on screen
	var screen_size = get_viewport_rect().size
	_harmonization_modal.position = (screen_size - _harmonization_modal.custom_minimum_size) / 2

	# Modal background panel (matches other shops - brown/gold theme)
	var panel = Panel.new()
	panel.custom_minimum_size = _harmonization_modal.custom_minimum_size
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.1, 0.05, 0.95)  # Dark brown (matches other shops)
	panel_style.border_color = Color(0.8, 0.6, 0.2, 1.0)  # Golden border (matches other shops)
	panel_style.set_border_width_all(3)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	_harmonization_modal.add_child(panel)

	# Main content container
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	content.position = Vector2(20, 20)
	content.size = _harmonization_modal.custom_minimum_size - Vector2(40, 40)
	_harmonization_modal.add_child(content)

	# Title
	var title = Label.new()
	title.text = "✨ Power Harmonization ✨"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Combine two powered items to create a dual-power weapon"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.7, 0.9))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)

	# Fusion slots area (horizontal layout with two slots + preview)
	var fusion_area = HBoxContainer.new()
	fusion_area.add_theme_constant_override("separation", 20)
	fusion_area.alignment = BoxContainer.ALIGNMENT_CENTER
	fusion_area.custom_minimum_size = Vector2(660, 120)
	content.add_child(fusion_area)

	# === Slot 1: Source (Destroyed) ===
	var slot1_panel = _create_fusion_slot_panel("Source Item", "🔴 DESTROYED", Color(0.8, 0.2, 0.2))
	slot1_panel.name = "Slot1Panel"
	fusion_area.add_child(slot1_panel)

	# === Center: Fusion Arrow & Preview ===
	var center_panel = VBoxContainer.new()
	center_panel.custom_minimum_size = Vector2(250, 120)

	var arrow = Label.new()
	arrow.text = "◉ → ⚡ ← ◉"
	arrow.add_theme_font_size_override("font_size", 20)
	arrow.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_panel.add_child(arrow)

	var preview_label = Label.new()
	preview_label.name = "PreviewLabel"
	preview_label.text = "Select items to fuse"
	preview_label.add_theme_font_size_override("font_size", 10)
	preview_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.8))
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	preview_label.custom_minimum_size = Vector2(240, 0)
	center_panel.add_child(preview_label)

	fusion_area.add_child(center_panel)

	# === Slot 2: Target (Survives) ===
	var slot2_panel = _create_fusion_slot_panel("Target Item", "✅ KEEPS ITEM", Color(0.2, 0.8, 0.2))
	slot2_panel.name = "Slot2Panel"
	fusion_area.add_child(slot2_panel)

	# Cost label with hybrid currency (skyshards OR rust blocks)
	const SKYSHARD_ITEM_ID = 21
	const SKYSHARD_COST = 20
	const RUST_BLOCK_COST = 100  # 5 rust blocks per skyshard
	var skyshard_count = _count_item_in_inventory(SKYSHARD_ITEM_ID)
	var rust_block_count = get_rust_block_count()

	var cost_label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = "Cost: %d Skyshards OR %d Rust Blocks\n(You have: %d ⭐ / %d 💎)" % [
		SKYSHARD_COST, RUST_BLOCK_COST,
		skyshard_count, rust_block_count
	]
	cost_label.add_theme_font_size_override("font_size", 14)

	# Green if player can afford with either currency, red if neither
	var can_afford = (skyshard_count >= SKYSHARD_COST) or (rust_block_count >= RUST_BLOCK_COST)
	var cost_color = Color(0.2, 0.8, 0.2) if can_afford else Color(0.8, 0.2, 0.2)
	cost_label.add_theme_color_override("font_color", cost_color)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(cost_label)

	# Item grid (shows all powered items)
	var grid_label = Label.new()
	grid_label.text = "Select Powered Items (🟧 = Player Equipped, 🟩 = Companion Equipped):"
	grid_label.add_theme_font_size_override("font_size", 12)
	grid_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	content.add_child(grid_label)

	# Scroll container for item grid
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(660, 250)
	content.add_child(scroll)

	var item_grid = GridContainer.new()
	item_grid.name = "ItemGrid"
	item_grid.columns = 6
	item_grid.add_theme_constant_override("h_separation", 10)
	item_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(item_grid)

	# Populate grid with powered items
	_populate_harmonization_item_grid(item_grid)

	# Buttons
	var button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 15)
	content.add_child(button_row)

	var harmonize_btn = Button.new()
	harmonize_btn.name = "HarmonizeButton"
	harmonize_btn.text = "⚡ Harmonize Powers ⚡"
	harmonize_btn.custom_minimum_size = Vector2(200, 40)
	harmonize_btn.disabled = true  # Disabled until both slots filled
	harmonize_btn.pressed.connect(_on_harmonize_pressed)

	# Style Harmonize button (golden theme for action button)
	var harmonize_normal = StyleBoxFlat.new()
	harmonize_normal.bg_color = Color(0.3, 0.25, 0.15, 0.9)  # Darker brown
	harmonize_normal.border_width_left = 2
	harmonize_normal.border_width_top = 2
	harmonize_normal.border_width_right = 2
	harmonize_normal.border_width_bottom = 2
	harmonize_normal.border_color = Color(0.8, 0.6, 0.2, 1.0)  # Golden border
	harmonize_normal.corner_radius_top_left = 6
	harmonize_normal.corner_radius_top_right = 6
	harmonize_normal.corner_radius_bottom_left = 6
	harmonize_normal.corner_radius_bottom_right = 6
	harmonize_btn.add_theme_stylebox_override("normal", harmonize_normal)

	var harmonize_hover = harmonize_normal.duplicate()
	harmonize_hover.bg_color = Color(0.35, 0.3, 0.18, 1.0)  # Brighter on hover
	harmonize_hover.border_color = Color(1.0, 0.8, 0.3, 1.0)  # Brighter gold
	harmonize_btn.add_theme_stylebox_override("hover", harmonize_hover)

	var harmonize_disabled = harmonize_normal.duplicate()
	harmonize_disabled.bg_color = Color(0.15, 0.12, 0.08, 0.6)  # Dim when disabled
	harmonize_disabled.border_color = Color(0.3, 0.25, 0.15, 0.8)  # Dim border
	harmonize_btn.add_theme_stylebox_override("disabled", harmonize_disabled)

	button_row.add_child(harmonize_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(120, 40)
	cancel_btn.pressed.connect(_close_harmonization_modal)

	# Style Cancel button (matches other shop cancel buttons)
	var cancel_normal = StyleBoxFlat.new()
	cancel_normal.bg_color = Color(0.2, 0.15, 0.1, 0.8)
	cancel_normal.border_width_left = 2
	cancel_normal.border_width_top = 2
	cancel_normal.border_width_right = 2
	cancel_normal.border_width_bottom = 2
	cancel_normal.border_color = Color(0.4, 0.3, 0.2, 1.0)
	cancel_normal.corner_radius_top_left = 6
	cancel_normal.corner_radius_top_right = 6
	cancel_normal.corner_radius_bottom_left = 6
	cancel_normal.corner_radius_bottom_right = 6
	cancel_btn.add_theme_stylebox_override("normal", cancel_normal)

	var cancel_hover = cancel_normal.duplicate()
	cancel_hover.bg_color = Color(0.25, 0.2, 0.13, 0.9)
	cancel_hover.border_color = Color(0.6, 0.5, 0.3, 1.0)
	cancel_btn.add_theme_stylebox_override("hover", cancel_hover)

	button_row.add_child(cancel_btn)


func _create_fusion_slot_panel(slot_title: String, status_text: String, status_color: Color) -> VBoxContainer:
	"""Helper to create a fusion slot panel"""
	var panel = VBoxContainer.new()
	panel.custom_minimum_size = Vector2(150, 120)

	var title_label = Label.new()
	title_label.text = slot_title
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title_label)

	# Item icon placeholder (will be updated when item selected)
	var icon = TextureRect.new()
	icon.name = "ItemIcon"
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(icon)

	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = status_text
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", status_color)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(status_label)

	return panel


func _populate_harmonization_item_grid(grid: GridContainer) -> void:
	"""Populate grid with all powered items from inventory and equipment slots"""
	# Collect all powered items from inventory
	for i in range(_slots.size()):
		var item = _slots[i]
		if item == null or item.type != InventoryItem.TYPE_ITEM:
			continue

		# Only show items with powers
		if item.skyshard_power == "" and item.skyshard_powers.is_empty():
			continue

		# Create item button with VBoxContainer for layout (matches shop grid style)
		var item_btn = Button.new()
		item_btn.custom_minimum_size = Vector2(72, 102)  # 72x72 button + 30 for label

		# Apply shop grid button styling (brown/gold theme)
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.2, 0.15, 0.1, 0.8)  # Dark brown
		normal_style.border_width_left = 2
		normal_style.border_width_top = 2
		normal_style.border_width_right = 2
		normal_style.border_width_bottom = 2
		normal_style.border_color = Color(0.4, 0.3, 0.2, 1.0)  # Brown border
		normal_style.corner_radius_top_left = 4
		normal_style.corner_radius_top_right = 4
		normal_style.corner_radius_bottom_left = 4
		normal_style.corner_radius_bottom_right = 4
		item_btn.add_theme_stylebox_override("normal", normal_style)

		# Hover style (lighter brown, brighter border)
		var hover_style = normal_style.duplicate()
		hover_style.bg_color = Color(0.25, 0.2, 0.13, 0.9)  # Lighter brown on hover
		hover_style.border_color = Color(0.6, 0.5, 0.3, 1.0)  # Golden border on hover
		item_btn.add_theme_stylebox_override("hover", hover_style)

		# Create vertical layout inside button
		var vbox = VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_btn.add_child(vbox)

		# Get item info
		var item_data = _item_db.get_item(item.id)
		var item_name = item_data.base_info.name.capitalize()

		# Add item texture
		var texture_rect = TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(48, 48)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_rect.texture = item_data.base_info.sprite

		var texture_center = CenterContainer.new()
		texture_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_center.add_child(texture_rect)
		vbox.add_child(texture_center)

		# Check if equipped
		var equipped_indicator = ""
		if _player_weapon_slot != null and _player_weapon_slot.id == item.id and i == _get_slot_index(_player_weapon_slot):
			equipped_indicator = "🟧 "  # Orange square for player
		elif _companion_weapon_slot != null and _companion_weapon_slot.id == item.id and i == _get_slot_index(_companion_weapon_slot):
			equipped_indicator = "🟩 "  # Green square for companion
		elif _companion_accessory_slot != null and _companion_accessory_slot.id == item.id and i == _get_slot_index(_companion_accessory_slot):
			equipped_indicator = "🟩 "  # Green square for companion accessory

		# Get all powers
		var powers = item.get_all_powers()
		var power_text = "\n".join(powers)

		# Add text labels
		var name_label = Label.new()
		name_label.text = "%s%s" % [equipped_indicator, item_name]
		name_label.add_theme_font_size_override("font_size", 10)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_label)

		var power_label = Label.new()
		power_label.text = power_text
		power_label.add_theme_font_size_override("font_size", 9)
		power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		power_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(power_label)

		# Connect to selection handler
		item_btn.pressed.connect(_on_harmonization_item_selected.bind(i))

		grid.add_child(item_btn)


func _get_slot_index(item: InventoryItem) -> int:
	"""Helper to find slot index of an item"""
	for i in range(_slots.size()):
		if _slots[i] == item:
			return i
	return -1


func _on_harmonization_item_selected(slot_index: int) -> void:
	"""Handle item selection for harmonization"""
	var item = _slots[slot_index]

	# Assign to next empty slot
	if _harmonization_slot1 == null:
		_harmonization_slot1 = item
		print("✨ Slot 1 (Source): %s" % _item_db.get_item(item.id).base_info.name)
	elif _harmonization_slot2 == null and item != _harmonization_slot1:
		_harmonization_slot2 = item
		print("✨ Slot 2 (Target): %s" % _item_db.get_item(item.id).base_info.name)
	else:
		# Both slots full, clear and restart
		_harmonization_slot1 = item
		_harmonization_slot2 = null
		print("✨ Slot 1 (Source): %s" % _item_db.get_item(item.id).base_info.name)

	_update_harmonization_ui()


func _update_harmonization_ui() -> void:
	"""Update the harmonization UI to show selected items"""
	if not _harmonization_modal:
		return

	# Update slot 1 icon
	var slot1_panel = _harmonization_modal.find_child("Slot1Panel", true, false)
	if slot1_panel:
		var icon1 = slot1_panel.find_child("ItemIcon", true, false)
		if icon1 and _harmonization_slot1 != null:
			var item_data = _item_db.get_item(_harmonization_slot1.id)
			icon1.texture = item_data.base_info.sprite

	# Update slot 2 icon
	var slot2_panel = _harmonization_modal.find_child("Slot2Panel", true, false)
	if slot2_panel:
		var icon2 = slot2_panel.find_child("ItemIcon", true, false)
		if icon2 and _harmonization_slot2 != null:
			var item_data = _item_db.get_item(_harmonization_slot2.id)
			icon2.texture = item_data.base_info.sprite

	# Update preview
	var preview_label = _harmonization_modal.find_child("PreviewLabel", true, false)
	if _harmonization_slot1 != null and _harmonization_slot2 != null:
		var powers1 = _harmonization_slot1.get_all_powers()
		var powers2 = _harmonization_slot2.get_all_powers()

		# Determine which power becomes major/minor
		var major_power = powers1[0] if powers1.size() > 0 else ""
		var minor_power = powers2[0] if powers2.size() > 0 else ""

		# Check power types
		var major_is_equip = _is_equip_power(major_power)
		var minor_is_equip = _is_equip_power(minor_power)

		var preview_text = "Major: %s (100%%)\nMinor: %s (60%%)" % [major_power, minor_power]

		# Add usage hint based on power types
		if major_is_equip and minor_is_equip:
			preview_text += "\n\n💡 EQUIP powers only\n→ Use in Accessory slot"
		elif not major_is_equip and not minor_is_equip:
			preview_text += "\n\n⚔️ HOTBAR powers only\n→ Use in Hotbar or Accessory"
		else:
			preview_text += "\n\n⚡ Mixed powers!\n→ Use in Accessory slot for both to work"

		preview_label.text = preview_text
	else:
		preview_label.text = "Select items to fuse"

	# Enable/disable harmonize button
	var harmonize_btn = _harmonization_modal.find_child("HarmonizeButton", true, false)
	if harmonize_btn:
		harmonize_btn.disabled = (_harmonization_slot1 == null or _harmonization_slot2 == null)


func _on_harmonize_pressed() -> void:
	"""Execute the power harmonization (fusion)"""
	if _harmonization_slot1 == null or _harmonization_slot2 == null:
		print("❌ ERROR: Both slots must be filled!")
		return

	# Check hybrid currency cost (20 skyshards OR 100 rust blocks)
	const SKYSHARD_ITEM_ID = 21
	const SKYSHARD_COST = 20
	const RUST_BLOCK_COST = 100
	var skyshard_count = _count_item_in_inventory(SKYSHARD_ITEM_ID)
	var rust_block_count = get_rust_block_count()

	# Determine which currency to use (prefer skyshards)
	var use_skyshards = (skyshard_count >= SKYSHARD_COST)
	var use_rust_blocks = (rust_block_count >= RUST_BLOCK_COST)

	if not use_skyshards and not use_rust_blocks:
		print("❌ ERROR: Need %d skyshards OR %d rust blocks! You have: %d ⭐ / %d 💎" % [
			SKYSHARD_COST, RUST_BLOCK_COST,
			skyshard_count, rust_block_count
		])
		return

	# Get powers
	var powers1 = _harmonization_slot1.get_all_powers()
	var powers2 = _harmonization_slot2.get_all_powers()

	if powers1.is_empty() or powers2.is_empty():
		print("❌ ERROR: Both items must have powers!")
		return

	# Perform fusion
	var major_power = powers1[0]
	var minor_power = powers2[0]

	# Clear existing powers array and set new dual-power structure
	_harmonization_slot2.skyshard_powers = [
		{"name": major_power, "strength": 1.0},  # Major power (100%)
		{"name": minor_power, "strength": 0.6}   # Minor power (60%)
	]
	_harmonization_slot2.skyshard_power = ""  # Clear legacy power

	# Consume currency (prefer skyshards, fallback to rust blocks)
	if use_skyshards:
		_consume_item_from_inventory(SKYSHARD_ITEM_ID, SKYSHARD_COST)
		print("💰 Paid %d Skyshards" % SKYSHARD_COST)
	else:
		spend_rust_blocks(RUST_BLOCK_COST)
		print("💰 Paid %d Rust Blocks" % RUST_BLOCK_COST)

	# Destroy slot 1 item
	var slot1_index = _get_slot_index(_harmonization_slot1)
	if slot1_index >= 0:
		_slots[slot1_index] = null
		_slot_views[slot1_index].get_display().set_item(null)

	# Update slot 2 display
	var slot2_index = _get_slot_index(_harmonization_slot2)
	if slot2_index >= 0:
		_slot_views[slot2_index].get_display().set_item(_harmonization_slot2)

	# Success message
	var item2_name = _item_db.get_item(_harmonization_slot2.id).base_info.name
	print("⚡ HARMONIZATION COMPLETE!")
	print("   %s now has:" % item2_name)
	print("   - Major: %s (100%%)" % major_power)
	print("   - Minor: %s (60%%)" % minor_power)

	# Add usage hint based on power types
	var major_is_equip = _is_equip_power(major_power)
	var minor_is_equip = _is_equip_power(minor_power)

	if major_is_equip and minor_is_equip:
		print("   💡 EQUIP powers only → Use in Accessory slot")
	elif not major_is_equip and not minor_is_equip:
		print("   ⚔️ HOTBAR powers only → Use in Hotbar or Accessory")
	else:
		print("   ⚡ Mixed powers! → Use in Accessory slot for both to work")

	emit_signal("changed")

	# Close modal
	_close_harmonization_modal()


func _close_harmonization_modal() -> void:
	"""Close the harmonization modal"""
	_harmonization_slot1 = null
	_harmonization_slot2 = null

	# Restore mouse capture (hide cursor)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if _harmonization_modal_bg:
		_harmonization_modal_bg.queue_free()
		_harmonization_modal_bg = null

	if _harmonization_modal:
		_harmonization_modal.queue_free()
		_harmonization_modal = null


func _count_item_in_inventory(item_id: int) -> int:
	"""Count total quantity of an item in inventory"""
	var total = 0
	for item in _slots:
		if item != null and item.type == InventoryItem.TYPE_ITEM and item.id == item_id:
			total += item.count
	return total


func _consume_item_from_inventory(item_id: int, amount: int) -> void:
	"""Consume a specific amount of an item from inventory"""
	var remaining = amount
	for i in range(_slots.size()):
		if remaining <= 0:
			break

		var item = _slots[i]
		if item != null and item.type == InventoryItem.TYPE_ITEM and item.id == item_id:
			var to_remove = min(remaining, item.count)
			item.count -= to_remove
			remaining -= to_remove

			# Remove item if count reaches 0
			if item.count <= 0:
				_slots[i] = null
				_slot_views[i].get_display().set_item(null)
			else:
				_slot_views[i].get_display().set_item(item)

	emit_signal("changed")


# ============================================================================
# RUST BLOCK CURRENCY SYSTEM
# ============================================================================

## Count total rust blocks in inventory (used as currency in item shops)
func get_rust_block_count() -> int:
	"""Count total rust blocks across all inventory slots"""
	var blocks_node = get_node("/root/Main/Game/Blocks")
	if not blocks_node:
		return 0

	var rust_block = blocks_node.get_block_by_name("rust_block")
	if not rust_block:
		return 0

	var rust_block_id = rust_block.base_info.id
	var total = 0
	for item in _slots:
		if item != null and item.type == InventoryItem.TYPE_BLOCK and item.id == rust_block_id:
			total += item.count
	return total


## Spend rust blocks from inventory (returns true if successful)
func spend_rust_blocks(amount: int) -> bool:
	"""Remove rust blocks from inventory, return true if player had enough"""
	if get_rust_block_count() < amount:
		return false  # Not enough rust blocks

	var blocks_node = get_node("/root/Main/Game/Blocks")
	if not blocks_node:
		return false

	var rust_block = blocks_node.get_block_by_name("rust_block")
	if not rust_block:
		return false

	var rust_block_id = rust_block.base_info.id
	var remaining = amount
	for i in range(_slots.size()):
		if remaining <= 0:
			break

		var item = _slots[i]
		if item != null and item.type == InventoryItem.TYPE_BLOCK and item.id == rust_block_id:
			var to_remove = min(remaining, item.count)
			item.count -= to_remove
			remaining -= to_remove

			# Remove item if count reaches 0
			if item.count <= 0:
				_slots[i] = null
				_slot_views[i].get_display().set_item(null)
			else:
				_slot_views[i].get_display().set_item(item)

	emit_signal("changed")
	return true


## Add rust blocks to inventory (selling items to Daniels)
func add_rust_blocks(amount: int) -> void:
	"""Add rust blocks to inventory (find existing stack or create new)"""
	var blocks_node = get_node("/root/Main/Game/Blocks")
	if not blocks_node:
		print("WARNING: Could not find Blocks node to add rust blocks")
		return

	var rust_block = blocks_node.get_block_by_name("rust_block")
	if not rust_block:
		print("WARNING: Could not find rust_block definition")
		return

	var rust_block_id = rust_block.base_info.id

	# Try to stack with existing rust blocks first
	for i in range(_slots.size()):
		if _slots[i] != null and _slots[i].type == InventoryItem.TYPE_BLOCK and _slots[i].id == rust_block_id:
			_slots[i].count += amount
			_slot_views[i].get_display().set_item(_slots[i])
			emit_signal("changed")
			return

	# No existing stack found - create new stack in first empty slot
	for i in range(_slots.size()):
		if _slots[i] == null:
			var new_item = InventoryItem.new()
			new_item.type = InventoryItem.TYPE_BLOCK
			new_item.id = rust_block_id
			new_item.count = amount
			_slots[i] = new_item
			_slot_views[i].get_display().set_item(new_item)
			emit_signal("changed")
			return

	# Inventory full - drop on ground? For now just print warning
	print("WARNING: Inventory full! Could not add %d rust blocks" % amount)


# ============================================================================
# SAVE/LOAD SYSTEM
# ============================================================================

func serialize_inventory() -> Dictionary:
	"""Convert inventory to Dictionary for saving"""
	var data = {
		"slots": [],
		"player_weapon": null,
		"companion_weapon": null,
		"companion_accessory": null,
		"bento_slots": []
	}

	# Serialize inventory slots
	for item in _slots:
		if item == null:
			data["slots"].append(null)
		else:
			data["slots"].append({
				"type": item.type,
				"id": item.id,
				"count": item.count,
				"skyshard_count": item.skyshard_count,
				"skyshard_power": item.skyshard_power,
				"skyshard_powers": item.skyshard_powers
			})

	# Serialize equipped weapons
	if _player_weapon_slot != null:
		data["player_weapon"] = {
			"type": _player_weapon_slot.type,
			"id": _player_weapon_slot.id,
			"count": _player_weapon_slot.count,
			"skyshard_count": _player_weapon_slot.skyshard_count,
			"skyshard_power": _player_weapon_slot.skyshard_power,
			"skyshard_powers": _player_weapon_slot.skyshard_powers
		}

	if _companion_weapon_slot != null:
		data["companion_weapon"] = {
			"type": _companion_weapon_slot.type,
			"id": _companion_weapon_slot.id,
			"count": _companion_weapon_slot.count,
			"skyshard_count": _companion_weapon_slot.skyshard_count,
			"skyshard_power": _companion_weapon_slot.skyshard_power,
			"skyshard_powers": _companion_weapon_slot.skyshard_powers
		}
	
	# Serialize companion accessory
	if _companion_accessory_slot != null:
		data["companion_accessory"] = {
			"type": _companion_accessory_slot.type,
			"id": _companion_accessory_slot.id,
			"count": _companion_accessory_slot.count,
			"skyshard_count": _companion_accessory_slot.skyshard_count,
			"skyshard_power": _companion_accessory_slot.skyshard_power,
			"skyshard_powers": _companion_accessory_slot.skyshard_powers
		}

	# Serialize bento box slots
	for item in _bento_slots:
		if item == null:
			data["bento_slots"].append(null)
		else:
			data["bento_slots"].append({
				"type": item.type,
				"id": item.id,
				"count": item.count,
				"skyshard_count": item.skyshard_count,
				"skyshard_power": item.skyshard_power,
				"skyshard_powers": item.skyshard_powers
			})

	return data


func deserialize_inventory(data: Dictionary) -> void:
	"""Load inventory from Dictionary"""
	if not data.has("slots"):
		push_warning("Inventory data has no 'slots' key")
		return

	# Clear existing inventory
	for i in range(_slots.size()):
		_slots[i] = null

	# Load slots
	for i in range(min(data["slots"].size(), _slots.size())):
		var slot_data = data["slots"][i]
		if slot_data != null:
			var item = InventoryItem.new()
			item.type = slot_data["type"]
			item.id = slot_data["id"]
			item.count = slot_data.get("count", 1)
			item.skyshard_count = slot_data.get("skyshard_count", 0)
			item.skyshard_power = slot_data.get("skyshard_power", "")
			item.skyshard_powers = slot_data.get("skyshard_powers", [])
			_slots[i] = item

	# Load equipped weapons
	_player_weapon_slot = null
	_companion_weapon_slot = null
	_companion_accessory_slot = null

	if data.has("player_weapon") and data["player_weapon"] != null:
		var weapon_data = data["player_weapon"]
		var weapon = InventoryItem.new()
		weapon.type = weapon_data["type"]
		weapon.id = weapon_data["id"]
		weapon.count = weapon_data.get("count", 1)
		weapon.skyshard_count = weapon_data.get("skyshard_count", 0)
		weapon.skyshard_power = weapon_data.get("skyshard_power", "")
		weapon.skyshard_powers = weapon_data.get("skyshard_powers", [])
		_player_weapon_slot = weapon

	if data.has("companion_weapon") and data["companion_weapon"] != null:
		var weapon_data = data["companion_weapon"]
		var weapon = InventoryItem.new()
		weapon.type = weapon_data["type"]
		weapon.id = weapon_data["id"]
		weapon.count = weapon_data.get("count", 1)
		weapon.skyshard_count = weapon_data.get("skyshard_count", 0)
		weapon.skyshard_power = weapon_data.get("skyshard_power", "")
		weapon.skyshard_powers = weapon_data.get("skyshard_powers", [])
		_companion_weapon_slot = weapon
	
	if data.has("companion_accessory") and data["companion_accessory"] != null:
		var accessory_data = data["companion_accessory"]
		var accessory = InventoryItem.new()
		accessory.type = accessory_data["type"]
		accessory.id = accessory_data["id"]
		accessory.count = accessory_data.get("count", 1)
		accessory.skyshard_count = accessory_data.get("skyshard_count", 0)
		accessory.skyshard_power = accessory_data.get("skyshard_power", "")
		accessory.skyshard_powers = accessory_data.get("skyshard_powers", [])
		_companion_accessory_slot = accessory

	# Load bento box slots
	if data.has("bento_slots") and data["bento_slots"] != null:
		for i in range(min(data["bento_slots"].size(), BENTO_SLOTS)):
			var slot_data = data["bento_slots"][i]
			if slot_data != null:
				var item = InventoryItem.new()
				item.type = slot_data["type"]
				item.id = slot_data["id"]
				item.count = slot_data.get("count", 1)
				item.skyshard_count = slot_data.get("skyshard_count", 0)
				item.skyshard_power = slot_data.get("skyshard_power", "")
				item.skyshard_powers = slot_data.get("skyshard_powers", [])
				_bento_slots[i] = item

	# Update views
	_update_views()

	# Update equipment slot views
	if _player_weapon_slot_view:
		_player_weapon_slot_view.get_display().set_item(_player_weapon_slot)
	if _companion_weapon_slot_view:
		_companion_weapon_slot_view.get_display().set_item(_companion_weapon_slot)
	if _companion_accessory_slot_view:
		_companion_accessory_slot_view.get_display().set_item(_companion_accessory_slot)

	# Update bento box views
	for i in range(BENTO_SLOTS):
		if _bento_slot_views[i]:
			_bento_slot_views[i].get_display().set_item(_bento_slots[i])

	# Refresh hotbar display to show loaded items
	_refresh_hotbar_display()

	# Update companion's equipment
	_update_companion_accessory()

	print("Inventory loaded from save data")
