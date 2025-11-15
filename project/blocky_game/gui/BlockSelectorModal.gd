extends Control

## BlockSelectorModal - Visual block selector for console
## Opens from `blocks` console command
## Shows all blocks in a grid, allows selecting and adding to inventory

signal modal_closed

# UI nodes
var _main_panel: Panel
var _scroll_container: ScrollContainer
var _grid_container: GridContainer
var _preview_panel: Panel
var _preview_texture: TextureRect
var _preview_label: Label
var _quantity_spinbox: SpinBox
var _add_button: Button
var _cancel_button: Button

# State
var _selected_block_id: int = -1
var _selected_button: Button = null
var _blocks_node: Node = null
var _player: Node = null
var _inventory: Node = null

# Constants
const GRID_COLUMNS = 5
const BUTTON_SIZE = 80
const MODAL_WIDTH = 900
const MODAL_HEIGHT = 700


func _ready():
	# Get references
	_blocks_node = get_node_or_null("/root/Main/Game/Blocks")
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_inventory = _player.get_node_or_null("Inventory")

	if not _blocks_node:
		push_error("BlockSelectorModal: Could not find Blocks node")
		queue_free()
		return

	# Build UI
	_build_ui()
	_populate_block_grid()

	# Show mouse cursor
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Center modal
	await get_tree().process_frame
	var viewport_size = get_viewport_rect().size
	_main_panel.position = (viewport_size - _main_panel.size) / 2


func _process(_delta):
	# Force mouse to stay visible while modal is open
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event):
	# Close on ESC
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_modal()
		get_viewport().set_input_as_handled()


func _build_ui():
	# Main panel with dark brown background + golden border
	_main_panel = Panel.new()
	_main_panel.custom_minimum_size = Vector2(MODAL_WIDTH, MODAL_HEIGHT)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.1, 0.05, 0.95)  # Dark brown
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color(0.8, 0.6, 0.2, 1.0)  # Golden border
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	_main_panel.add_theme_stylebox_override("panel", panel_style)

	add_child(_main_panel)

	# Main vertical layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	_main_panel.add_child(vbox)

	# Add margins
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	vbox.add_child(margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 15)
	margin.add_child(content_vbox)

	# Title
	var title = Label.new()
	title.text = "🧱 Block Selector"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Click a block to select it, then choose quantity and add to inventory"
	subtitle.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(subtitle)

	# Separator
	var separator1 = HSeparator.new()
	separator1.add_theme_constant_override("separation", 2)
	content_vbox.add_child(separator1)

	# Scrollable grid container for blocks
	_scroll_container = ScrollContainer.new()
	_scroll_container.custom_minimum_size = Vector2(0, 450)
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(_scroll_container)

	_grid_container = GridContainer.new()
	_grid_container.columns = GRID_COLUMNS
	_grid_container.add_theme_constant_override("h_separation", 10)
	_grid_container.add_theme_constant_override("v_separation", 10)
	_scroll_container.add_child(_grid_container)

	# Separator
	var separator2 = HSeparator.new()
	separator2.add_theme_constant_override("separation", 2)
	content_vbox.add_child(separator2)

	# Bottom panel for selection preview and controls
	_preview_panel = Panel.new()
	_preview_panel.custom_minimum_size = Vector2(0, 120)

	var preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.1, 0.07, 0.03, 0.8)
	preview_style.border_width_left = 2
	preview_style.border_width_top = 2
	preview_style.border_width_right = 2
	preview_style.border_width_bottom = 2
	preview_style.border_color = Color(0.6, 0.4, 0.1, 0.8)
	preview_style.corner_radius_top_left = 4
	preview_style.corner_radius_top_right = 4
	preview_style.corner_radius_bottom_left = 4
	preview_style.corner_radius_bottom_right = 4
	_preview_panel.add_theme_stylebox_override("panel", preview_style)
	content_vbox.add_child(_preview_panel)

	var preview_hbox = HBoxContainer.new()
	preview_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_hbox.add_theme_constant_override("separation", 20)
	_preview_panel.add_child(preview_hbox)

	# Preview margin
	var preview_margin = MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 15)
	preview_margin.add_theme_constant_override("margin_top", 15)
	preview_margin.add_theme_constant_override("margin_right", 15)
	preview_margin.add_theme_constant_override("margin_bottom", 15)
	preview_hbox.add_child(preview_margin)

	var preview_content = HBoxContainer.new()
	preview_content.add_theme_constant_override("separation", 20)
	preview_margin.add_child(preview_content)

	# Preview icon
	_preview_texture = TextureRect.new()
	_preview_texture.custom_minimum_size = Vector2(80, 80)
	_preview_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_content.add_child(_preview_texture)

	# Preview info vbox
	var preview_info = VBoxContainer.new()
	preview_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_info.add_theme_constant_override("separation", 8)
	preview_content.add_child(preview_info)

	# Selected block label
	var selected_label = Label.new()
	selected_label.text = "Selected Block:"
	selected_label.add_theme_font_size_override("font_size", 14)
	selected_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	preview_info.add_child(selected_label)

	_preview_label = Label.new()
	_preview_label.text = "None"
	_preview_label.add_theme_font_size_override("font_size", 20)
	_preview_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	preview_info.add_child(_preview_label)

	# Quantity control
	var quantity_hbox = HBoxContainer.new()
	quantity_hbox.add_theme_constant_override("separation", 10)
	preview_info.add_child(quantity_hbox)

	var quantity_label = Label.new()
	quantity_label.text = "Quantity:"
	quantity_label.add_theme_font_size_override("font_size", 16)
	quantity_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	quantity_hbox.add_child(quantity_label)

	_quantity_spinbox = SpinBox.new()
	_quantity_spinbox.min_value = 1
	_quantity_spinbox.max_value = 99
	_quantity_spinbox.value = 1
	_quantity_spinbox.custom_minimum_size = Vector2(120, 0)
	quantity_hbox.add_child(_quantity_spinbox)

	# Buttons hbox
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_END
	buttons_hbox.add_theme_constant_override("separation", 10)
	preview_content.add_child(buttons_hbox)

	# Add button
	_add_button = Button.new()
	_add_button.text = "Add to Inventory"
	_add_button.custom_minimum_size = Vector2(160, 50)
	_add_button.disabled = true
	_add_button.pressed.connect(_on_add_to_inventory)
	buttons_hbox.add_child(_add_button)

	# Cancel button
	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.custom_minimum_size = Vector2(120, 50)
	_cancel_button.pressed.connect(_close_modal)
	buttons_hbox.add_child(_cancel_button)


func _populate_block_grid():
	"""Fill grid with all available blocks"""
	if not _blocks_node:
		return

	var block_count = _blocks_node.get_block_count()

	for block_id in range(1, block_count):  # Skip air (ID 0)
		var block = _blocks_node.get_block(block_id)
		if not block:
			continue

		# Skip bedrock optionally (uncomment to hide it)
		# if block_id == 13:  # Bedrock
		#	continue

		# Create block button
		var button = Button.new()
		button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE + 30)
		button.pressed.connect(_on_block_selected.bind(block_id, button))

		# Button style
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.2, 0.15, 0.1, 0.8)
		normal_style.border_width_left = 2
		normal_style.border_width_top = 2
		normal_style.border_width_right = 2
		normal_style.border_width_bottom = 2
		normal_style.border_color = Color(0.4, 0.3, 0.2, 1.0)
		normal_style.corner_radius_top_left = 4
		normal_style.corner_radius_top_right = 4
		normal_style.corner_radius_bottom_left = 4
		normal_style.corner_radius_bottom_right = 4
		button.add_theme_stylebox_override("normal", normal_style)

		var hover_style = normal_style.duplicate()
		hover_style.bg_color = Color(0.25, 0.2, 0.13, 0.9)
		hover_style.border_color = Color(0.6, 0.5, 0.3, 1.0)
		button.add_theme_stylebox_override("hover", hover_style)

		# Button content - VBox with icon + label
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 5)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through to button
		button.add_child(vbox)

		# Block sprite
		var texture_rect = TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(64, 64)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Load sprite from block
		if block.base_info.sprite_texture:
			texture_rect.texture = block.base_info.sprite_texture

		vbox.add_child(texture_rect)

		# Block name
		var label = Label.new()
		label.text = block.base_info.name.capitalize()
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(BUTTON_SIZE - 10, 0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(label)

		_grid_container.add_child(button)


func _on_block_selected(block_id: int, button: Button):
	"""Handle block button click"""
	_selected_block_id = block_id

	# Remove highlight from previous button
	if _selected_button and is_instance_valid(_selected_button):
		var prev_style = StyleBoxFlat.new()
		prev_style.bg_color = Color(0.2, 0.15, 0.1, 0.8)
		prev_style.border_width_left = 2
		prev_style.border_width_top = 2
		prev_style.border_width_right = 2
		prev_style.border_width_bottom = 2
		prev_style.border_color = Color(0.4, 0.3, 0.2, 1.0)
		prev_style.corner_radius_top_left = 4
		prev_style.corner_radius_top_right = 4
		prev_style.corner_radius_bottom_left = 4
		prev_style.corner_radius_bottom_right = 4
		_selected_button.add_theme_stylebox_override("normal", prev_style)

	# Highlight new button
	_selected_button = button
	var selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color(0.2, 0.35, 0.2, 0.9)  # Green tint
	selected_style.border_width_left = 3
	selected_style.border_width_top = 3
	selected_style.border_width_right = 3
	selected_style.border_width_bottom = 3
	selected_style.border_color = Color(0.4, 0.8, 0.4, 1.0)  # Bright green border
	selected_style.corner_radius_top_left = 4
	selected_style.corner_radius_top_right = 4
	selected_style.corner_radius_bottom_left = 4
	selected_style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", selected_style)

	# Update preview
	var block = _blocks_node.get_block(block_id)
	if block:
		_preview_label.text = block.base_info.name.capitalize()
		if block.base_info.sprite_texture:
			_preview_texture.texture = block.base_info.sprite_texture

		# Enable add button
		_add_button.disabled = false


func _on_add_to_inventory():
	"""Add selected block(s) to player inventory"""
	if _selected_block_id < 0:
		return

	if not _player or not _inventory:
		print("[BlockSelector] ERROR: Player or inventory not found")
		_show_message("Error: Could not access inventory!", Color.RED)
		return

	var quantity = int(_quantity_spinbox.value)
	var block = _blocks_node.get_block(_selected_block_id)
	if not block:
		return

	# Find empty slot
	var empty_slot = -1
	for i in range(_inventory._slots.size()):
		if _inventory._slots[i] == null:
			empty_slot = i
			break

	if empty_slot == -1:
		print("[BlockSelector] Inventory full!")
		_show_message("Inventory full!", Color.RED)
		return

	# Create inventory item
	var InventoryItem = load("res://blocky_game/player/inventory_item.gd")
	var item = InventoryItem.new()
	item.type = InventoryItem.TYPE_BLOCK
	item.id = _selected_block_id
	item.count = quantity

	# Add to inventory
	_inventory._slots[empty_slot] = item
	_inventory._update_views()

	print("[BlockSelector] ✅ Added %dx %s to inventory" % [quantity, block.base_info.name])
	_show_message("✅ Added %dx %s to inventory!" % [quantity, block.base_info.name.capitalize()], Color.GREEN)

	# Optional: Clear selection and reset for next block
	_quantity_spinbox.value = 1


func _show_message(text: String, color: Color):
	"""Show temporary message (could be enhanced with actual popup)"""
	# For now, just print - could add a Label that fades out
	print("[BlockSelector] ", text)


func _close_modal():
	"""Close the modal and cleanup"""
	modal_closed.emit()

	# Restore mouse mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	queue_free()
