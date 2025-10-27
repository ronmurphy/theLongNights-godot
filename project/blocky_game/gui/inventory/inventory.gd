extends Control

signal changed
signal equipment_changed

const BAG_WIDTH = 9
const BAG_HEIGHT = 3
const HOTBAR_HEIGHT = 1

const InventoryItem = preload("../../player/inventory_item.gd")

@onready var _bag_container = $CC/PC/VB/Bag
@onready var _hotbar_container = $CC/PC/VB/Hotbar
@onready var _dragged_item_view = $DraggedItem
@onready var _panel_container = $CC/PC

# TODO Is it worth having the hotbar in the first indexes instead of the last ones?
var _slots := []
var _slot_views := []
var _previous_mouse_mode := 0
var _dragged_slot := -1

# Equipment slots (separate from inventory)
var _player_weapon_slot: InventoryItem = null
var _companion_weapon_slot: InventoryItem = null
var _player_weapon_slot_view = null
var _companion_weapon_slot_view = null
var _player_equipment_panel = null
var _companion_equipment_panel = null


func _ready():
	# Create equipment panels first
	_create_equipment_panels()

	_slots.resize(BAG_WIDTH * (BAG_HEIGHT + HOTBAR_HEIGHT))
	assert(_bag_container.get_child_count() == BAG_WIDTH * BAG_HEIGHT)
	assert(_hotbar_container.get_child_count() == BAG_WIDTH * HOTBAR_HEIGHT)

	# Initial contents
	var hotbar_begin_index := BAG_WIDTH * BAG_HEIGHT
	_slots[hotbar_begin_index + 0] = _make_item(InventoryItem.TYPE_BLOCK, 1)
	_slots[hotbar_begin_index + 1] = _make_item(InventoryItem.TYPE_BLOCK, 2)
	_slots[hotbar_begin_index + 2] = _make_item(InventoryItem.TYPE_BLOCK, 3)
	_slots[hotbar_begin_index + 3] = _make_item(InventoryItem.TYPE_BLOCK, 4)
	_slots[hotbar_begin_index + 4] = _make_item(InventoryItem.TYPE_BLOCK, 5)
	_slots[hotbar_begin_index + 5] = _make_item(InventoryItem.TYPE_ITEM, 2)  # Climbing claws
	_slots[hotbar_begin_index + 6] = _make_item(InventoryItem.TYPE_ITEM, 1)  # Grappling hook
	_slots[hotbar_begin_index + 7] = _make_item(InventoryItem.TYPE_ITEM, 0)  # Rocket launcher
	_slots[hotbar_begin_index + 8] = _make_item(InventoryItem.TYPE_BLOCK, 9)
	_slots[0] = _make_item(InventoryItem.TYPE_BLOCK, 8)
	_slots[1] = _make_item(InventoryItem.TYPE_ITEM, 3)  # Ice bow in bag slot 1
	_slots[2] = _make_item(InventoryItem.TYPE_ITEM, 4)  # Fire staff in bag slot 2
	_slots[3] = _make_item(InventoryItem.TYPE_ITEM, 5)  # Throwing knives in bag slot 3
	# Torch in bag slot 4 with stack of 10
	var torch_item = _make_item(InventoryItem.TYPE_ITEM, 6)
	torch_item.count = 10
	_slots[4] = torch_item

	# Init views
	var slot_idx := 0
	_slot_views.resize(len(_slots))
	for container in [_bag_container, _hotbar_container]:
		for i in container.get_child_count():
			var slot = container.get_child(i)
			slot.get_display().set_item(_slots[slot_idx])
			slot.pressed.connect(_on_slot_pressed.bind(slot_idx))
			_slot_views[slot_idx] = slot
			slot_idx += 1
	
	# Initialize companion weapon slot with their default weapon
	call_deferred("_initialize_companion_default_weapon")


static func _make_item(type, id):
	var i = InventoryItem.new()
	i.id = id
	i.type = type
	return i


func _update_views():
	var slot_idx := 0
	for container in [_bag_container, _hotbar_container]:
		for i in container.get_child_count():
			var slot = container.get_child(i)
			slot.get_display().set_item(_slots[slot_idx])
			slot_idx += 1


func get_hotbar_slot_count() -> int:
	return BAG_WIDTH


func get_hotbar_slot_data(i) -> InventoryItem:
	var hotbar_begin_index := BAG_WIDTH * BAG_HEIGHT
	return _slots[hotbar_begin_index + i]


func get_player_equipped_weapon() -> InventoryItem:
	"""Get the player's currently equipped weapon"""
	return _player_weapon_slot


func get_companion_equipped_weapon() -> InventoryItem:
	"""Get the companion's currently equipped weapon"""
	return _companion_weapon_slot


func _initialize_companion_default_weapon():
	"""Initialize companion weapon slot with their default starting weapon or saved weapon"""
	var weapon_id = -1
	
	# Try to load saved equipment first
	if CompanionManager.equipped_weapon_id >= 0:
		weapon_id = CompanionManager.equipped_weapon_id
	else:
		# Get the companion's default weapon ID based on their race
		weapon_id = _get_companion_default_weapon_id()
	
	if weapon_id >= 0:
		# Create an inventory item for the weapon
		_companion_weapon_slot = _make_item(InventoryItem.TYPE_ITEM, weapon_id)
		
		# Update the visual display
		if _companion_weapon_slot_view:
			_companion_weapon_slot_view.get_display().set_item(_companion_weapon_slot)


func _get_companion_default_weapon_id() -> int:
	"""Get the default weapon ID for companion's race"""
	match CompanionManager.companion_race:
		"dwarf":
			return 7  # stone_hammer
		"elf":
			return 9  # crossbow
		"goblin":
			if CompanionManager.companion_gender == "female":
				return 5  # throwing_knives
			else:
				return 0  # rocket_launcher
		"human":
			return 8  # machete
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
		# Get the dragged item (could be from equipment slot)
		var dragged_item = null
		if _dragged_slot >= 0:
			dragged_item = _slots[_dragged_slot]
		elif _dragged_slot == -999:
			dragged_item = _player_weapon_slot
		elif _dragged_slot == -998:
			dragged_item = _companion_weapon_slot
		
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
			
			_slot_views[idx].get_display().set_item(_slots[idx])
			_dragged_item_view.stop()
			_dragged_slot = -1
			emit_signal("changed")
			emit_signal("equipment_changed")
		
		else:
			# Swap with occupied slot (only if dragging from inventory, not equipment)
			if _dragged_slot >= 0 and _dragged_slot != idx:
				# Swap
				var tmp = _slots[idx]
				_slots[idx] = _slots[_dragged_slot]
				_slots[_dragged_slot] = tmp
				_dragged_item_view.start(tmp)
				_slot_views[idx].get_display().set_item(_slots[idx])
				emit_signal("changed")
			else:
				# Can't swap equipment slots with inventory - cancel drag
				if _dragged_slot == -999:
					_player_weapon_slot_view.get_display().set_item(_player_weapon_slot)
				elif _dragged_slot == -998:
					_companion_weapon_slot_view.get_display().set_item(_companion_weapon_slot)
				elif _dragged_slot >= 0:
					_slot_views[_dragged_slot].get_display().set_item(_slots[_dragged_slot])
				_dragged_slot = -1
				_dragged_item_view.stop()



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
	hbox.add_theme_constant_override("separation", 16)
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
	panel.custom_minimum_size = Vector2(140, 200)

	# Title label
	var title = Label.new()
	title.text = character_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	panel.add_child(title)

	# Avatar (reuse party UI avatar)
	var avatar_bg = Panel.new()
	avatar_bg.custom_minimum_size = Vector2(96, 96)

	var avatar_style = StyleBoxFlat.new()
	avatar_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	avatar_style.border_color = Color(0.6, 0.5, 0.3)
	avatar_style.set_border_width_all(2)
	avatar_bg.add_theme_stylebox_override("panel", avatar_style)

	var avatar_texture = TextureRect.new()
	avatar_texture.name = "AvatarTexture"
	avatar_texture.custom_minimum_size = Vector2(92, 92)
	avatar_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	avatar_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_texture.position = Vector2(2, 2)
	avatar_bg.add_child(avatar_texture)

	# Load avatar based on player data
	_load_avatar_for_panel(avatar_texture, is_player)

	# Center avatar in panel
	var avatar_center = CenterContainer.new()
	avatar_center.add_child(avatar_bg)
	panel.add_child(avatar_center)

	# Weapon slot label
	var weapon_label = Label.new()
	weapon_label.text = "Weapon"
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_label.add_theme_font_size_override("font_size", 12)
	panel.add_child(weapon_label)

	# Weapon equipment slot
	const InventorySlot = preload("res://blocky_game/gui/inventory/inventory_slot.tscn")
	var weapon_slot = InventorySlot.instantiate()
	weapon_slot.custom_minimum_size = Vector2(64, 64)
	weapon_slot.pressed.connect(_on_equipment_slot_pressed.bind(is_player))

	# Store reference to slot view
	if is_player:
		_player_weapon_slot_view = weapon_slot
	else:
		_companion_weapon_slot_view = weapon_slot

	# Center weapon slot
	var weapon_center = CenterContainer.new()
	weapon_center.add_child(weapon_slot)
	panel.add_child(weapon_center)

	return panel


func _load_avatar_for_panel(avatar_texture: TextureRect, is_player: bool):
	"""Load the appropriate avatar sprite for player or companion"""
	if is_player:
		# Load player avatar from PlayerData
		var sprite_path = PlayerData.get_avatar_path()
		if sprite_path != "" and ResourceLoader.exists(sprite_path):
			avatar_texture.texture = load(sprite_path)
	else:
		# Load companion avatar from CompanionManager
		var sprite_path = CompanionManager.get_avatar_path()
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
