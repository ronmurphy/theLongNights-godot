extends Control

## BlockSelectorModal - Visual block selector for console
## Opens from `blocks` console command
## Shows all blocks in a grid, allows selecting and adding to inventory
## Can also be used as a shop interface for NPC block merchants

signal modal_closed

# UI nodes
var _main_panel: Panel
var _scroll_container: ScrollContainer
var _grid_container: GridContainer
var _player_scroll_container: ScrollContainer  # For shop mode
var _player_grid_container: GridContainer  # For shop mode
var _preview_panel: Panel
var _preview_texture: TextureRect
var _preview_label: Label
var _player_preview_texture: TextureRect  # For shop mode
var _player_preview_label: Label  # For shop mode
var _quantity_spinbox: SpinBox
var _add_button: Button
var _cancel_button: Button

# State
var _is_shop: bool = false
var _selected_block_id: int = -1
var _selected_button: Button = null
var _selected_player_block_id: int = -1
var _selected_player_button: Button = null
var _blocks_node: Node = null
var _player: Node = null
var _inventory: Node = null

# Constants
const GRID_COLUMNS = 5
const BUTTON_SIZE = 72  # Slightly smaller for tighter layout
const MODAL_WIDTH = 800  # More compact for 720p
const MODAL_HEIGHT = 650
const SHOP_MODAL_WIDTH = 1100  # Fits 720p with margins
const SHOP_MODAL_HEIGHT = 600  # Fits 720p with title bar
const SHOP_GRID_COLUMNS = 6  # Shop blocks column count (use the width!)
const PLAYER_GRID_COLUMNS = 4  # Player blocks column count (use the width!)


func _init(is_shop: bool = false):
	"""Initialize modal - set to shop mode if is_shop is true"""
	_is_shop = is_shop


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

	# In shop mode, also populate player's inventory grid
	if _is_shop:
		_populate_player_block_grid()

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
	var panel_width = SHOP_MODAL_WIDTH if _is_shop else MODAL_WIDTH
	var panel_height = SHOP_MODAL_HEIGHT if _is_shop else MODAL_HEIGHT
	_main_panel.custom_minimum_size = Vector2(panel_width, panel_height)

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
	vbox.add_theme_constant_override("separation", 6)  # Tighter spacing
	_main_panel.add_child(vbox)

	# Add margins (smaller for compact layout)
	var margin = MarginContainer.new()
	var margin_size = 12 if _is_shop else 15
	margin.add_theme_constant_override("margin_left", margin_size)
	margin.add_theme_constant_override("margin_top", margin_size)
	margin.add_theme_constant_override("margin_right", margin_size)
	margin.add_theme_constant_override("margin_bottom", margin_size)
	vbox.add_child(margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 8)  # Tighter spacing
	margin.add_child(content_vbox)

	# Title (more compact)
	var title = Label.new()
	title.text = "🏪 Block Shop" if _is_shop else "🧱 Block Selector"
	title.add_theme_font_size_override("font_size", 22)  # Smaller
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(title)

	# Subtitle (more compact)
	var subtitle = Label.new()
	if _is_shop:
		subtitle.text = "Choose a block to buy and a block to trade (1-for-1 barter)"
	else:
		subtitle.text = "Click a block to select it, then choose quantity and add to inventory"
	subtitle.add_theme_font_size_override("font_size", 11)  # Smaller
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(subtitle)

	# Separator
	var separator1 = HSeparator.new()
	separator1.add_theme_constant_override("separation", 2)
	content_vbox.add_child(separator1)

	# Grid area - either single column (normal) or dual column (shop)
	if _is_shop:
		# Dual-column layout for shop mode
		var grid_hbox = HBoxContainer.new()
		grid_hbox.add_theme_constant_override("separation", 12)  # Tighter spacing between columns
		grid_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_vbox.add_child(grid_hbox)

		# LEFT COLUMN: Shop blocks
		var shop_vbox = VBoxContainer.new()
		shop_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shop_vbox.add_theme_constant_override("separation", 4)
		grid_hbox.add_child(shop_vbox)

		var shop_label = Label.new()
		shop_label.text = "📦 SHOP BLOCKS"
		shop_label.add_theme_font_size_override("font_size", 13)  # Smaller
		shop_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		shop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop_vbox.add_child(shop_label)

		_scroll_container = ScrollContainer.new()
		_scroll_container.custom_minimum_size = Vector2(0, 310)  # More height for blocks
		_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		shop_vbox.add_child(_scroll_container)

		_grid_container = GridContainer.new()
		_grid_container.columns = SHOP_GRID_COLUMNS  # 3 columns
		_grid_container.add_theme_constant_override("h_separation", 6)  # Tighter
		_grid_container.add_theme_constant_override("v_separation", 6)  # Tighter
		_scroll_container.add_child(_grid_container)

		# RIGHT COLUMN: Player's blocks
		var player_vbox = VBoxContainer.new()
		player_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		player_vbox.add_theme_constant_override("separation", 4)
		grid_hbox.add_child(player_vbox)

		var player_label = Label.new()
		player_label.text = "🎒 YOUR BLOCKS"
		player_label.add_theme_font_size_override("font_size", 13)  # Smaller
		player_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		player_vbox.add_child(player_label)

		_player_scroll_container = ScrollContainer.new()
		_player_scroll_container.custom_minimum_size = Vector2(0, 310)  # More height for blocks
		_player_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		player_vbox.add_child(_player_scroll_container)

		_player_grid_container = GridContainer.new()
		_player_grid_container.columns = PLAYER_GRID_COLUMNS  # 2 columns
		_player_grid_container.add_theme_constant_override("h_separation", 6)  # Tighter
		_player_grid_container.add_theme_constant_override("v_separation", 6)  # Tighter
		_player_scroll_container.add_child(_player_grid_container)
	else:
		# Single-column layout for normal mode
		_scroll_container = ScrollContainer.new()
		_scroll_container.custom_minimum_size = Vector2(0, 420)  # Slightly reduced
		_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_vbox.add_child(_scroll_container)

		_grid_container = GridContainer.new()
		_grid_container.columns = GRID_COLUMNS
		_grid_container.add_theme_constant_override("h_separation", 8)  # Slightly tighter
		_grid_container.add_theme_constant_override("v_separation", 8)  # Slightly tighter
		_scroll_container.add_child(_grid_container)

	# Separator
	var separator2 = HSeparator.new()
	separator2.add_theme_constant_override("separation", 2)
	content_vbox.add_child(separator2)

	# Bottom panel for selection preview and controls
	_preview_panel = Panel.new()
	var preview_height = 115 if _is_shop else 100  # Taller for shop (proper padding)
	_preview_panel.custom_minimum_size = Vector2(0, preview_height)

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
	preview_hbox.add_theme_constant_override("separation", 12)  # Tighter
	_preview_panel.add_child(preview_hbox)

	# Preview margin (better padding for shop)
	var preview_margin = MarginContainer.new()
	var preview_margin_size = 12 if _is_shop else 10  # More padding in shop mode
	preview_margin.add_theme_constant_override("margin_left", preview_margin_size)
	preview_margin.add_theme_constant_override("margin_top", preview_margin_size)
	preview_margin.add_theme_constant_override("margin_right", preview_margin_size)
	preview_margin.add_theme_constant_override("margin_bottom", preview_margin_size)
	preview_hbox.add_child(preview_margin)

	if _is_shop:
		# Shop mode: Compact horizontal layout (everything in one row)
		var preview_vbox = VBoxContainer.new()
		preview_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview_vbox.add_theme_constant_override("separation", 4)
		preview_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		preview_margin.add_child(preview_vbox)

		# Trading label at top
		var trade_label = Label.new()
		trade_label.text = "TRADING:"
		trade_label.add_theme_font_size_override("font_size", 11)
		trade_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		trade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		preview_vbox.add_child(trade_label)

		# Main horizontal row: [You give] <--> [You get]  Quantity: [#]  [Trade] [Cancel]
		var main_hbox = HBoxContainer.new()
		main_hbox.add_theme_constant_override("separation", 15)
		main_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		preview_vbox.add_child(main_hbox)

		# LEFT: Player's block (You give)
		var player_preview_vbox = VBoxContainer.new()
		player_preview_vbox.add_theme_constant_override("separation", 2)
		main_hbox.add_child(player_preview_vbox)

		_player_preview_texture = TextureRect.new()
		_player_preview_texture.custom_minimum_size = Vector2(48, 48)  # Slightly bigger
		_player_preview_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		_player_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_player_preview_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		player_preview_vbox.add_child(_player_preview_texture)

		var player_giving_label = Label.new()
		player_giving_label.text = "You give"
		player_giving_label.add_theme_font_size_override("font_size", 10)
		player_giving_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
		player_giving_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		player_preview_vbox.add_child(player_giving_label)

		_player_preview_label = Label.new()
		_player_preview_label.text = "None"
		_player_preview_label.add_theme_font_size_override("font_size", 11)
		_player_preview_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		_player_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		player_preview_vbox.add_child(_player_preview_label)

		# CENTER-LEFT: Arrow
		var arrow_label = Label.new()
		arrow_label.text = "←→"
		arrow_label.add_theme_font_size_override("font_size", 20)
		arrow_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		main_hbox.add_child(arrow_label)

		# CENTER-RIGHT: Shop block (You get)
		var shop_preview_vbox = VBoxContainer.new()
		shop_preview_vbox.add_theme_constant_override("separation", 2)
		main_hbox.add_child(shop_preview_vbox)

		_preview_texture = TextureRect.new()
		_preview_texture.custom_minimum_size = Vector2(48, 48)  # Slightly bigger
		_preview_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_preview_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shop_preview_vbox.add_child(_preview_texture)

		var shop_getting_label = Label.new()
		shop_getting_label.text = "You get"
		shop_getting_label.add_theme_font_size_override("font_size", 10)
		shop_getting_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		shop_getting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop_preview_vbox.add_child(shop_getting_label)

		_preview_label = Label.new()
		_preview_label.text = "None"
		_preview_label.add_theme_font_size_override("font_size", 11)
		_preview_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop_preview_vbox.add_child(_preview_label)

		# Add spacer to push quantity/buttons to the right
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(20, 0)
		main_hbox.add_child(spacer)

		# RIGHT-CENTER: Quantity spinner
		var quantity_hbox = HBoxContainer.new()
		quantity_hbox.add_theme_constant_override("separation", 6)
		main_hbox.add_child(quantity_hbox)

		var quantity_label = Label.new()
		quantity_label.text = "Quantity:"
		quantity_label.add_theme_font_size_override("font_size", 11)
		quantity_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		quantity_hbox.add_child(quantity_label)

		_quantity_spinbox = SpinBox.new()
		_quantity_spinbox.min_value = 1
		_quantity_spinbox.max_value = 99
		_quantity_spinbox.value = 1
		_quantity_spinbox.custom_minimum_size = Vector2(80, 0)
		quantity_hbox.add_child(_quantity_spinbox)

		# RIGHT: Buttons
		var buttons_hbox = HBoxContainer.new()
		buttons_hbox.add_theme_constant_override("separation", 6)
		main_hbox.add_child(buttons_hbox)

		_add_button = Button.new()
		_add_button.text = "Trade"
		_add_button.custom_minimum_size = Vector2(80, 36)
		_add_button.disabled = true
		_add_button.pressed.connect(_on_trade_blocks)
		buttons_hbox.add_child(_add_button)

		_cancel_button = Button.new()
		_cancel_button.text = "Cancel"
		_cancel_button.custom_minimum_size = Vector2(80, 36)
		_cancel_button.pressed.connect(_close_modal)
		buttons_hbox.add_child(_cancel_button)
	else:
		# Normal mode: Horizontal layout (icon + info + buttons)
		var preview_content = HBoxContainer.new()
		preview_content.add_theme_constant_override("separation", 15)
		preview_margin.add_child(preview_content)

		# Preview icon
		_preview_texture = TextureRect.new()
		_preview_texture.custom_minimum_size = Vector2(72, 72)
		_preview_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		_preview_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_preview_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview_content.add_child(_preview_texture)

		# Preview info vbox
		var preview_info = VBoxContainer.new()
		preview_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview_info.add_theme_constant_override("separation", 8)
		preview_content.add_child(preview_info)

		var selected_label = Label.new()
		selected_label.text = "Selected Block:"
		selected_label.add_theme_font_size_override("font_size", 11)
		selected_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		preview_info.add_child(selected_label)

		_preview_label = Label.new()
		_preview_label.text = "None"
		_preview_label.add_theme_font_size_override("font_size", 16)
		_preview_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		preview_info.add_child(_preview_label)

		# Quantity control
		var quantity_hbox = HBoxContainer.new()
		quantity_hbox.add_theme_constant_override("separation", 8)
		preview_info.add_child(quantity_hbox)

		var quantity_label = Label.new()
		quantity_label.text = "Quantity:"
		quantity_label.add_theme_font_size_override("font_size", 12)
		quantity_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		quantity_hbox.add_child(quantity_label)

		_quantity_spinbox = SpinBox.new()
		_quantity_spinbox.min_value = 1
		_quantity_spinbox.max_value = 99
		_quantity_spinbox.value = 1
		_quantity_spinbox.custom_minimum_size = Vector2(100, 0)
		quantity_hbox.add_child(_quantity_spinbox)

		# Buttons
		var buttons_hbox = HBoxContainer.new()
		buttons_hbox.alignment = BoxContainer.ALIGNMENT_END
		buttons_hbox.add_theme_constant_override("separation", 8)
		preview_content.add_child(buttons_hbox)

		_add_button = Button.new()
		_add_button.text = "Add to Inventory"
		_add_button.custom_minimum_size = Vector2(140, 40)
		_add_button.disabled = true
		_add_button.pressed.connect(_on_add_to_inventory)
		buttons_hbox.add_child(_add_button)

		_cancel_button = Button.new()
		_cancel_button.text = "Cancel"
		_cancel_button.custom_minimum_size = Vector2(90, 40)
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

		# Block sprite (scaled to match button size)
		var texture_rect = TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(56, 56)  # Smaller for 72px button
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
		label.add_theme_font_size_override("font_size", 10)  # Smaller font
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(BUTTON_SIZE - 8, 0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(label)

		_grid_container.add_child(button)


func _populate_player_block_grid():
	"""Fill player grid with blocks from inventory (shop mode only)"""
	if not _is_shop or not _player_grid_container or not _inventory:
		return

	# Collect all block items from inventory with their total counts
	var block_counts = {}  # {block_id: count}

	for slot in _inventory._slots:
		if slot != null and slot.type == slot.TYPE_BLOCK:
			var block_id = slot.id
			if not block_counts.has(block_id):
				block_counts[block_id] = 0
			block_counts[block_id] += slot.count

	# Create buttons for each block type the player has
	for block_id in block_counts.keys():
		var count = block_counts[block_id]
		var block = _blocks_node.get_block(block_id)
		if not block:
			continue

		# Create block button with count overlay
		var button = Button.new()
		button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE + 30)
		button.pressed.connect(_on_player_block_selected.bind(block_id, button, count))

		# Button style
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.15, 0.2, 0.25, 0.8)  # Slightly different color for player blocks
		normal_style.border_width_left = 2
		normal_style.border_width_top = 2
		normal_style.border_width_right = 2
		normal_style.border_width_bottom = 2
		normal_style.border_color = Color(0.3, 0.4, 0.5, 1.0)
		normal_style.corner_radius_top_left = 4
		normal_style.corner_radius_top_right = 4
		normal_style.corner_radius_bottom_left = 4
		normal_style.corner_radius_bottom_right = 4
		button.add_theme_stylebox_override("normal", normal_style)

		var hover_style = normal_style.duplicate()
		hover_style.bg_color = Color(0.2, 0.25, 0.3, 0.9)
		hover_style.border_color = Color(0.5, 0.6, 0.7, 1.0)
		button.add_theme_stylebox_override("hover", hover_style)

		# Button content - VBox with icon + label + count
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 5)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(vbox)

		# Block sprite (scaled to match button size)
		var texture_rect = TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(56, 56)  # Smaller for 72px button
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Load sprite from block
		if block.base_info.sprite_texture:
			texture_rect.texture = block.base_info.sprite_texture

		vbox.add_child(texture_rect)

		# Count overlay (in bottom-right corner, adjusted for smaller button)
		var count_label = Label.new()
		count_label.text = str(count)
		count_label.add_theme_font_size_override("font_size", 14)  # Slightly smaller
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.add_theme_color_override("font_outline_color", Color.BLACK)
		count_label.add_theme_constant_override("outline_size", 6)  # Smaller outline
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_label.position = Vector2(BUTTON_SIZE - 28, 5)  # Adjusted for smaller button
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(count_label)

		# Block name
		var label = Label.new()
		label.text = block.base_info.name.capitalize()
		label.add_theme_font_size_override("font_size", 10)  # Smaller font
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(BUTTON_SIZE - 8, 0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(label)

		_player_grid_container.add_child(button)


func _on_block_selected(block_id: int, button: Button):
	"""Handle shop block button click"""
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
		if block.base_info.sprite_texture and _preview_texture:
			_preview_texture.texture = block.base_info.sprite_texture

		# In shop mode, only enable button if BOTH blocks are selected
		# In normal mode, enable immediately
		if _is_shop:
			_add_button.disabled = (_selected_player_block_id < 0)
		else:
			_add_button.disabled = false


func _on_player_block_selected(block_id: int, button: Button, count: int):
	"""Handle player block button click (shop mode only)"""
	_selected_player_block_id = block_id

	# Remove highlight from previous button
	if _selected_player_button and is_instance_valid(_selected_player_button):
		var prev_style = StyleBoxFlat.new()
		prev_style.bg_color = Color(0.15, 0.2, 0.25, 0.8)
		prev_style.border_width_left = 2
		prev_style.border_width_top = 2
		prev_style.border_width_right = 2
		prev_style.border_width_bottom = 2
		prev_style.border_color = Color(0.3, 0.4, 0.5, 1.0)
		prev_style.corner_radius_top_left = 4
		prev_style.corner_radius_top_right = 4
		prev_style.corner_radius_bottom_left = 4
		prev_style.corner_radius_bottom_right = 4
		_selected_player_button.add_theme_stylebox_override("normal", prev_style)

	# Highlight new button
	_selected_player_button = button
	var selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color(0.35, 0.2, 0.2, 0.9)  # Red tint (giving away)
	selected_style.border_width_left = 3
	selected_style.border_width_top = 3
	selected_style.border_width_right = 3
	selected_style.border_width_bottom = 3
	selected_style.border_color = Color(0.8, 0.4, 0.4, 1.0)  # Bright red border
	selected_style.corner_radius_top_left = 4
	selected_style.corner_radius_top_right = 4
	selected_style.corner_radius_bottom_left = 4
	selected_style.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", selected_style)

	# Update preview
	var block = _blocks_node.get_block(block_id)
	if block:
		_player_preview_label.text = block.base_info.name.capitalize()
		if block.base_info.sprite_texture and _player_preview_texture:
			_player_preview_texture.texture = block.base_info.sprite_texture

	# Update quantity spinbox max value based on player's count
	_quantity_spinbox.max_value = count
	if _quantity_spinbox.value > count:
		_quantity_spinbox.value = count

	# Enable trade button only if both blocks are selected
	_add_button.disabled = (_selected_block_id < 0)


func _on_trade_blocks():
	"""Handle trading blocks in shop mode"""
	if _selected_block_id < 0 or _selected_player_block_id < 0:
		_show_message("Select both a shop block and your block to trade!", Color.RED)
		return

	if not _player or not _inventory:
		_show_message("Error: Could not access inventory!", Color.RED)
		return

	var quantity = int(_quantity_spinbox.value)
	var shop_block = _blocks_node.get_block(_selected_block_id)
	var player_block = _blocks_node.get_block(_selected_player_block_id)

	if not shop_block or not player_block:
		return

	# Find and remove player's blocks from inventory
	var removed_count = 0
	for i in range(_inventory._slots.size()):
		if _inventory._slots[i] == null:
			continue

		var slot = _inventory._slots[i]
		if slot.type == slot.TYPE_BLOCK and slot.id == _selected_player_block_id:
			var remove_amount = min(slot.count, quantity - removed_count)
			slot.count -= remove_amount
			removed_count += remove_amount

			# If slot is now empty, remove it
			if slot.count <= 0:
				_inventory._slots[i] = null

			# Stop if we've removed enough
			if removed_count >= quantity:
				break

	if removed_count < quantity:
		_show_message("Error: Not enough blocks to trade!", Color.RED)
		return

	# Add shop blocks to inventory
	var added = false
	var InventoryItem = load("res://blocky_game/player/inventory_item.gd")

	# Try to find existing stack of the shop block
	for i in range(_inventory._slots.size()):
		if _inventory._slots[i] == null:
			continue

		var slot = _inventory._slots[i]
		if slot.type == slot.TYPE_BLOCK and slot.id == _selected_block_id:
			slot.count += quantity
			added = true
			break

	# If no existing stack, create new slot
	if not added:
		for i in range(_inventory._slots.size()):
			if _inventory._slots[i] == null:
				var item = InventoryItem.new()
				item.type = InventoryItem.TYPE_BLOCK
				item.id = _selected_block_id
				item.count = quantity
				_inventory._slots[i] = item
				added = true
				break

	if not added:
		_show_message("Inventory full! Trade cancelled.", Color.RED)
		return

	# Update inventory views
	_inventory._update_views()

	print("[BlockShop] ✅ Traded %dx %s for %dx %s" % [
		quantity, player_block.base_info.name,
		quantity, shop_block.base_info.name
	])
	_show_message("✅ Traded %dx %s for %dx %s!" % [
		quantity, player_block.base_info.name.capitalize(),
		quantity, shop_block.base_info.name.capitalize()
	], Color.GREEN)

	# Refresh player block grid to update counts
	for child in _player_grid_container.get_children():
		child.queue_free()
	await get_tree().process_frame
	_populate_player_block_grid()

	# Reset selections and quantity
	_selected_player_block_id = -1
	_selected_player_button = null
	_quantity_spinbox.value = 1
	_quantity_spinbox.max_value = 99
	_add_button.disabled = true

	if _player_preview_label:
		_player_preview_label.text = "None"
	if _player_preview_texture:
		_player_preview_texture.texture = null


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
