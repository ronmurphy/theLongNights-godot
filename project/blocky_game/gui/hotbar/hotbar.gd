extends CenterContainer

const InventoryItem = preload("../../player/inventory_item.gd")

@onready var _selected_frame = $HBoxContainer/HotbarSlot/HotbarSlotSelect
@onready var _slot_container = $HBoxContainer
@onready var _block_types = get_node(^"/root/Main/Game/Blocks")
@onready var _inventory = get_node(^"../Inventory")

var _hotbar_index := 0
var _mining_progress_bar : ProgressBar = null
var _bento_slot_views := []  # 6 bento slot displays for HUD
var _bento_left_panel : Panel = null  # Left 3 slots panel
var _bento_right_panel : Panel = null  # Right 3 slots panel

# Cooldown overlay system
var _cooldown_overlays := {}  # Maps slot index -> {panel: ColorRect, label: Label}

# Chain counter overlay system (for Blade of Pursuit)
var _chain_counter_overlays := {}  # Maps slot index -> Label


func _ready():
	call_deferred("_update_views")
	_create_mining_progress_bar()
	_create_bento_hud()


func _process(_delta: float):
	"""Update cooldown overlays for items with cooldowns"""
	_update_cooldown_overlays()
	_update_chain_counter_overlays()


func _create_mining_progress_bar():
	# Create container for progress bar above hotbar
	var vbox = VBoxContainer.new()
	vbox.name = "ProgressContainer"
	vbox.add_theme_constant_override("separation", 4)

	# Create progress bar
	_mining_progress_bar = ProgressBar.new()
	_mining_progress_bar.name = "MiningProgressBar"
	_mining_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mining_progress_bar.custom_minimum_size = Vector2(0, 12)  # Height only, width will match hotbar
	_mining_progress_bar.max_value = 100.0
	_mining_progress_bar.value = 0.0
	_mining_progress_bar.show_percentage = false
	_mining_progress_bar.visible = false

	# Style the progress bar
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style_bg.border_color = Color(0.4, 0.4, 0.4)
	style_bg.set_border_width_all(1)

	var style_fg = StyleBoxFlat.new()
	style_fg.bg_color = Color(0.3, 0.8, 0.3, 0.9)  # Green progress

	_mining_progress_bar.add_theme_stylebox_override("background", style_bg)
	_mining_progress_bar.add_theme_stylebox_override("fill", style_fg)

	# Get the existing HBoxContainer (hotbar slots)
	var hbox = get_node("HBoxContainer")

	# Remove HBoxContainer from CenterContainer
	remove_child(hbox)

	# Add progress bar and hotbar to VBox
	vbox.add_child(_mining_progress_bar)
	vbox.add_child(hbox)

	# Add VBox to CenterContainer
	add_child(vbox)


func _create_bento_hud():
	"""Create split bento box HUD above hotbar (3 left + 3 right)"""
	const InventoryItemDisplay = preload("../inventory_item_display.gd")

	# Get the VBox that contains mining progress bar and hotbar
	var vbox = get_node("ProgressContainer")

	# Create horizontal container for [BentoLeft] [MiningBar] [BentoRight]
	var bento_row = HBoxContainer.new()
	bento_row.name = "BentoRow"
	bento_row.add_theme_constant_override("separation", 4)
	bento_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# LEFT BENTO PANEL (3 slots)
	_bento_left_panel = Panel.new()
	_bento_left_panel.custom_minimum_size = Vector2(144, 44)  # 3 slots @ 40x40 + padding
	var left_style = StyleBoxFlat.new()
	left_style.bg_color = Color(0.25, 0.2, 0.15, 0.9)  # Dark brown
	left_style.border_color = Color(0.8, 0.6, 0.3)  # Golden border
	left_style.set_border_width_all(2)
	_bento_left_panel.add_theme_stylebox_override("panel", left_style)

	var left_hbox = HBoxContainer.new()
	left_hbox.add_theme_constant_override("separation", 4)
	left_hbox.position = Vector2(2, 2)
	_bento_left_panel.add_child(left_hbox)

	# Create 3 left bento slots
	for i in range(3):
		var slot_bg = Panel.new()
		slot_bg.custom_minimum_size = Vector2(40, 40)
		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.15, 0.12, 0.1, 0.8)
		slot_style.border_color = Color(0.4, 0.35, 0.3)
		slot_style.set_border_width_all(1)
		slot_bg.add_theme_stylebox_override("panel", slot_style)

		var item_display = TextureRect.new()
		item_display.custom_minimum_size = Vector2(40, 40)
		item_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item_display.set_script(InventoryItemDisplay)
		slot_bg.add_child(item_display)

		left_hbox.add_child(slot_bg)
		_bento_slot_views.append(item_display)

	bento_row.add_child(_bento_left_panel)

	# CENTER SPACER (mining bar will overlap this area)
	var center_spacer = Control.new()
	center_spacer.custom_minimum_size = Vector2(200, 44)  # Space for mining bar
	center_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bento_row.add_child(center_spacer)

	# RIGHT BENTO PANEL (3 slots)
	_bento_right_panel = Panel.new()
	_bento_right_panel.custom_minimum_size = Vector2(144, 44)
	var right_style = StyleBoxFlat.new()
	right_style.bg_color = Color(0.25, 0.2, 0.15, 0.9)
	right_style.border_color = Color(0.8, 0.6, 0.3)
	right_style.set_border_width_all(2)
	_bento_right_panel.add_theme_stylebox_override("panel", right_style)

	var right_hbox = HBoxContainer.new()
	right_hbox.add_theme_constant_override("separation", 4)
	right_hbox.position = Vector2(2, 2)
	_bento_right_panel.add_child(right_hbox)

	# Create 3 right bento slots (indices 3-5)
	for i in range(3):
		var slot_bg = Panel.new()
		slot_bg.custom_minimum_size = Vector2(40, 40)
		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.15, 0.12, 0.1, 0.8)
		slot_style.border_color = Color(0.4, 0.35, 0.3)
		slot_style.set_border_width_all(1)
		slot_bg.add_theme_stylebox_override("panel", slot_style)

		var item_display = TextureRect.new()
		item_display.custom_minimum_size = Vector2(40, 40)
		item_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item_display.set_script(InventoryItemDisplay)
		slot_bg.add_child(item_display)

		right_hbox.add_child(slot_bg)
		_bento_slot_views.append(item_display)

	bento_row.add_child(_bento_right_panel)

	# Insert bento row at the top of the VBox (above mining bar)
	vbox.add_child(bento_row)
	vbox.move_child(bento_row, 0)

	# Connect to inventory changes
	if _inventory:
		_inventory.changed.connect(_update_bento_views)

	# Initial update
	call_deferred("_update_bento_views")


func _update_bento_views():
	"""Update bento slot displays from inventory"""
	if not _inventory:
		return

	for i in range(6):
		if i < _bento_slot_views.size():
			var bento_item = _inventory.get_bento_slot_data(i)
			_bento_slot_views[i].set_item(bento_item)


func set_mining_progress(progress_percent: float):
	"""Update mining progress bar (0-100)"""
	if _mining_progress_bar:
		if progress_percent > 0:
			_mining_progress_bar.visible = true
			_mining_progress_bar.value = progress_percent
		else:
			_mining_progress_bar.visible = false
			_mining_progress_bar.value = 0


func _update_views():
	for i in _inventory.get_hotbar_slot_count():
		var slot_data = _inventory.get_hotbar_slot_data(i)
		var slot_view = _slot_container.get_child(i)
		slot_view.get_display().set_item(slot_data)


func select_slot(i: int):
	if _hotbar_index == i:
		return
	assert(i >= 0 and i < _inventory.get_hotbar_slot_count())
	_hotbar_index = i
	
	var item = _inventory.get_hotbar_slot_data(_hotbar_index)
	if item != null:
		if item.type == InventoryItem.TYPE_BLOCK:
			var block = _block_types.get_block(item.id)
			print("Hotbar select block ", block.base_info.name)
		elif item.type == InventoryItem.TYPE_ITEM:
			print("Hotbar select item ", item.id)
	
	_selected_frame.get_parent().remove_child(_selected_frame)
	var slot = _slot_container.get_child(i)
	slot.add_child(_selected_frame)


func get_selected_item() -> InventoryItem:
	return _inventory.get_hotbar_slot_data(_hotbar_index)


func get_selected_slot_index() -> int:
	return _hotbar_index


func try_select_slot_by_block_id(block_id: int):
	for i in _inventory.get_hotbar_slot_count():
		var item = _inventory.get_hotbar_slot_data(i)
		if item.type == InventoryItem.TYPE_BLOCK:
			if item.id == block_id:
				select_slot(i)
				break


func select_next_slot():
	var i = _hotbar_index + 1
	if i >= _inventory.get_hotbar_slot_count():
		i = 0
	select_slot(i)


func select_previous_slot():
	var i = _hotbar_index - 1
	if i < 0:
		i = _inventory.get_hotbar_slot_count() - 1
	select_slot(i)


func _on_Inventory_changed():
	_update_views()


func refresh_display():
	"""Manually refresh hotbar display (called when loadouts are switched)"""
	_update_views()


func _update_cooldown_overlays():
	"""Update cooldown visual overlays for items with cooldowns"""
	# Get player to check cooldown status
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Check each hotbar slot
	for i in _inventory.get_hotbar_slot_count():
		var slot_data = _inventory.get_hotbar_slot_data(i)
		if not slot_data:
			# Remove overlay if it exists
			if _cooldown_overlays.has(i):
				_cooldown_overlays[i].panel.queue_free()
				_cooldown_overlays.erase(i)
			continue

		# Check if this is an item with cooldown
		var cooldown_time = 0.0
		var item_name = ""

		if slot_data.type == InventoryItem.TYPE_ITEM:
			# Ring of Teleportation (ID 48)
			if slot_data.id == 48:
				if player.has_method("get_teleport_ring_cooldown"):
					cooldown_time = player.get_teleport_ring_cooldown()
					item_name = "Teleport"
			# Blade of Pursuit (ID 47)
			elif slot_data.id == 47:
				if player.has_method("get_blade_of_pursuit_cooldown"):
					cooldown_time = player.get_blade_of_pursuit_cooldown()
					item_name = "Blade"

		# Update or create overlay
		if cooldown_time > 0:
			_create_or_update_cooldown_overlay(i, cooldown_time, item_name)
		else:
			# Remove overlay if cooldown is done
			if _cooldown_overlays.has(i):
				_cooldown_overlays[i].panel.queue_free()
				_cooldown_overlays.erase(i)


func _create_or_update_cooldown_overlay(slot_index: int, cooldown_seconds: float, item_name: String):
	"""Create or update cooldown overlay for a hotbar slot"""
	var slot_view = _slot_container.get_child(slot_index)

	if not _cooldown_overlays.has(slot_index):
		# Create new overlay
		var overlay_panel = ColorRect.new()
		overlay_panel.color = Color(0, 0, 0, 0.7)  # Dark overlay
		overlay_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay_panel.z_index = 10

		# Create countdown label
		var label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 2)
		overlay_panel.add_child(label)

		slot_view.add_child(overlay_panel)

		_cooldown_overlays[slot_index] = {
			"panel": overlay_panel,
			"label": label
		}

	# Update label text
	var overlay = _cooldown_overlays[slot_index]
	overlay.label.text = str(int(ceil(cooldown_seconds)))


func _update_chain_counter_overlays():
	"""Update chain counter overlays for Blade of Pursuit"""
	# Get player to check chain progress
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Check each hotbar slot
	for i in _inventory.get_hotbar_slot_count():
		var slot_data = _inventory.get_hotbar_slot_data(i)
		if not slot_data:
			# Remove overlay if it exists
			if _chain_counter_overlays.has(i):
				_chain_counter_overlays[i].queue_free()
				_chain_counter_overlays.erase(i)
			continue

		# Check if this is the Blade of Pursuit (ID 47)
		if slot_data.type == InventoryItem.TYPE_ITEM and slot_data.id == 47:
			# Get chain progress
			if player.has_method("get_blade_chain_progress"):
				var progress = player.get_blade_chain_progress()
				if progress.active:
					# Show counter: "2/5" or "2/10"
					_create_or_update_chain_counter(i, progress.current, progress.max)
				else:
					# Remove counter when blade is not active
					if _chain_counter_overlays.has(i):
						_chain_counter_overlays[i].queue_free()
						_chain_counter_overlays.erase(i)
		else:
			# Not blade of pursuit, remove counter if it exists
			if _chain_counter_overlays.has(i):
				_chain_counter_overlays[i].queue_free()
				_chain_counter_overlays.erase(i)


func _create_or_update_chain_counter(slot_index: int, current: int, max_count: int):
	"""Create or update chain counter for Blade of Pursuit slot"""
	var slot_view = _slot_container.get_child(slot_index)

	if not _chain_counter_overlays.has(slot_index):
		# Create new chain counter label
		var label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.position = Vector2(2, 2)  # Top-left corner
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 15  # Above cooldown overlay

		slot_view.add_child(label)
		_chain_counter_overlays[slot_index] = label

	# Update label text
	var label = _chain_counter_overlays[slot_index]
	label.text = "%d/%d" % [current, max_count]
