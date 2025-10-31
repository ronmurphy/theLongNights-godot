extends CenterContainer

const InventoryItem = preload("../../player/inventory_item.gd")

@onready var _selected_frame = $HBoxContainer/HotbarSlot/HotbarSlotSelect
@onready var _slot_container = $HBoxContainer
@onready var _block_types = get_node(^"/root/Main/Game/Blocks")
@onready var _inventory = get_node(^"../Inventory")

var _hotbar_index := 0
var _mining_progress_bar : ProgressBar = null


func _ready():
	call_deferred("_update_views")
	_create_mining_progress_bar()


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
			# TODO Item db
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
