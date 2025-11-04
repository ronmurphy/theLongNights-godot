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
@onready var _item_db = get_node("/root/Main/Game/Items")

# TODO Is it worth having the hotbar in the first indexes instead of the last ones?
var _slots := []
var _slot_views := []
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
			_slot_views[slot_idx] = slot
			slot_idx += 1
	
	# Initialize companion weapon slot with their default weapon
	call_deferred("_initialize_companion_default_weapon")


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
	_slots[hotbar_begin_index + 0] = _make_item(InventoryItem.TYPE_ITEM, 8)  # Machete (ID 8)
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
		
		# Create 3 behavior buttons with emojis
		var behaviors = ["normal", "aggressive", "defensive"]
		var emojis = ["⚖️", "⚔️", "🛡️"]
		var colors = [
			Color(0.7, 0.7, 0.7),   # Normal - gray
			Color(1.0, 0.3, 0.3),   # Aggressive - red
			Color(0.3, 0.5, 1.0)    # Defensive - blue
		]
		var tooltips = ["Normal: Balanced behavior", "Aggressive: Attack more enemies from farther away", "Defensive: Stay close and protect"]
		
		for i in range(3):
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

	# Avatar (reuse party UI avatar)
	var avatar_bg = Panel.new()
	avatar_bg.custom_minimum_size = Vector2(128, 128)  # Bigger avatar, less squished

	var avatar_style = StyleBoxFlat.new()
	avatar_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	avatar_style.border_color = Color(0.6, 0.5, 0.3)
	avatar_style.set_border_width_all(2)
	avatar_bg.add_theme_stylebox_override("panel", avatar_style)

	var avatar_texture = TextureRect.new()
	avatar_texture.name = "AvatarTexture"
	avatar_texture.custom_minimum_size = Vector2(124, 124)  # Match larger avatar size
	avatar_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	avatar_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_texture.position = Vector2(2, 2)
	avatar_bg.add_child(avatar_texture)

	# Load avatar based on player data
	_load_avatar_for_panel(avatar_texture, is_player)

	# Center avatar in panel
	var avatar_center = CenterContainer.new()
	avatar_center.add_child(avatar_bg)
	content_container.add_child(avatar_center)

	# Equipment section - different layout for player vs companion
	if is_player:
		# Player: Single weapon slot (vertical layout)
		var weapon_label = Label.new()
		weapon_label.text = "Weapon"
		weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weapon_label.add_theme_font_size_override("font_size", 12)
		content_container.add_child(weapon_label)
		
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
				print("❌ Only EQUIP powers (stone_skin, moon_jump, flame_aura) can go in accessory slot!")
				_dragged_item_view.stop()
				_dragged_slot = -1
		else:
			_dragged_item_view.stop()
			_dragged_slot = -1
	else:
		# Start dragging accessory if there is one
		if _companion_accessory_slot != null:
			_dragged_slot = -997  # Special ID for accessory slot
			_dragged_item_view.get_display().set_item(_companion_accessory_slot)
			_dragged_item_view.start()


func _is_equip_power(power_name: String) -> bool:
	"""Check if power is an EQUIP type (passive powers)"""
	return power_name in ["stone_skin", "moon_jump", "flame_aura"]


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
		{"name": "stone_skin", "display": "Stone Skin", "desc": "+50% defense while equipped", "slot": "EQUIP"},
		{"name": "moon_jump", "display": "Moon Jump", "desc": "Triple jump height while equipped", "slot": "EQUIP"},
		{"name": "flame_aura", "display": "Flame Aura", "desc": "Burns nearby enemies constantly", "slot": "EQUIP"}
	]

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
# SAVE/LOAD SYSTEM
# ============================================================================

func serialize_inventory() -> Dictionary:
	"""Convert inventory to Dictionary for saving"""
	var data = {
		"slots": [],
		"player_weapon": null,
		"companion_weapon": null
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
				"skyshard_power": item.skyshard_power
			})

	# Serialize equipped weapons
	if _player_weapon_slot != null:
		data["player_weapon"] = {
			"type": _player_weapon_slot.type,
			"id": _player_weapon_slot.id,
			"count": _player_weapon_slot.count,
			"skyshard_count": _player_weapon_slot.skyshard_count,
			"skyshard_power": _player_weapon_slot.skyshard_power
		}

	if _companion_weapon_slot != null:
		data["companion_weapon"] = {
			"type": _companion_weapon_slot.type,
			"id": _companion_weapon_slot.id,
			"count": _companion_weapon_slot.count,
			"skyshard_count": _companion_weapon_slot.skyshard_count,
			"skyshard_power": _companion_weapon_slot.skyshard_power
		}

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
			_slots[i] = item

	# Load equipped weapons
	_player_weapon_slot = null
	_companion_weapon_slot = null

	if data.has("player_weapon") and data["player_weapon"] != null:
		var weapon_data = data["player_weapon"]
		var weapon = InventoryItem.new()
		weapon.type = weapon_data["type"]
		weapon.id = weapon_data["id"]
		weapon.count = weapon_data.get("count", 1)
		weapon.skyshard_count = weapon_data.get("skyshard_count", 0)
		weapon.skyshard_power = weapon_data.get("skyshard_power", "")
		_player_weapon_slot = weapon

	if data.has("companion_weapon") and data["companion_weapon"] != null:
		var weapon_data = data["companion_weapon"]
		var weapon = InventoryItem.new()
		weapon.type = weapon_data["type"]
		weapon.id = weapon_data["id"]
		weapon.count = weapon_data.get("count", 1)
		weapon.skyshard_count = weapon_data.get("skyshard_count", 0)
		weapon.skyshard_power = weapon_data.get("skyshard_power", "")
		_companion_weapon_slot = weapon

	# Update views
	_update_views()

	# Update equipment slot views
	if _player_weapon_slot_view:
		_player_weapon_slot_view.get_display().set_item(_player_weapon_slot)
	if _companion_weapon_slot_view:
		_companion_weapon_slot_view.get_display().set_item(_companion_weapon_slot)

	# Refresh hotbar display to show loaded items
	_refresh_hotbar_display()

	print("Inventory loaded from save data")
