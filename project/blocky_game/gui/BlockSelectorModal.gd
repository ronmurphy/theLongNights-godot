extends Control

## ShopModal - Universal shop interface for blocks, items, and food
## Opens from `shop <type>` or `blocks` console command
## Supports multiple shop types with different barter systems:
## - FREE: Free block selector (original blocks command)
## - BLOCKS: Block trading (1:1 barter with NPCs)
## - ITEMS: Item/weapon shop (rust block currency)
## - FOOD: Food shop (raw/cooked separation)

signal modal_closed

# Shop type enum
enum ShopType {
	FREE,      # Free block selector (add to inventory)
	BLOCKS,    # Block shop (1:1 block trading)
	ITEMS,     # Item/weapon shop (rust block currency)
	FOOD       # Food shop (raw/cooked only)
}

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
var _shop_type: int = ShopType.FREE
var _selected_block_id: int = -1
var _selected_button: Button = null
var _selected_player_block_id: int = -1
var _selected_player_button: Button = null
var _blocks_node: Node = null
var _item_db: Node = null
var _player: Node = null
var _inventory: Node = null
var _rust_balance_label: Label = null  # Reference to rust block balance label

# Constants
const GRID_COLUMNS = 5
const BUTTON_SIZE = 72  # Slightly smaller for tighter layout
const MODAL_WIDTH = 800  # More compact for 720p
const MODAL_HEIGHT = 650
const SHOP_MODAL_WIDTH = 1100  # Fits 720p with margins
const SHOP_MODAL_HEIGHT = 600  # Fits 720p with title bar
const SHOP_GRID_COLUMNS = 6  # Shop blocks column count (use the width!)
const PLAYER_GRID_COLUMNS = 4  # Player blocks column count (use the width!)


func _init(shop_type: int = ShopType.FREE):
	"""Initialize modal with specified shop type"""
	_shop_type = shop_type


func _ready():
	# Get references
	_blocks_node = get_node_or_null("/root/Main/Game/Blocks")
	_item_db = get_node_or_null("/root/Main/Game/Items")
	_player = get_tree().get_first_node_in_group("player")
	if _player:
		_inventory = _player.get_node_or_null("Inventory")

	if not _blocks_node:
		push_error("BlockSelectorModal: Could not find Blocks node")
		queue_free()
		return

	if not _item_db:
		push_error("BlockSelectorModal: Could not find Items node")
		queue_free()
		return

	# Build UI
	_build_ui()
	_populate_shop_grid()

	# In shop modes (not FREE), also populate player's inventory grid
	if _shop_type != ShopType.FREE:
		_populate_player_inventory()

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
	var is_shop_mode = (_shop_type != ShopType.FREE)
	var panel_width = SHOP_MODAL_WIDTH if is_shop_mode else MODAL_WIDTH
	var panel_height = SHOP_MODAL_HEIGHT if is_shop_mode else MODAL_HEIGHT
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
	var margin_size = 12 if is_shop_mode else 15
	margin.add_theme_constant_override("margin_left", margin_size)
	margin.add_theme_constant_override("margin_top", margin_size)
	margin.add_theme_constant_override("margin_right", margin_size)
	margin.add_theme_constant_override("margin_bottom", margin_size)
	vbox.add_child(margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 8)  # Tighter spacing
	margin.add_child(content_vbox)

	# Title (shop type specific)
	var title = Label.new()
	title.text = _get_shop_title()
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(title)

	# Subtitle (shop type specific)
	var subtitle = Label.new()
	subtitle.text = _get_shop_subtitle()
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(subtitle)

	# Rust block balance (ITEMS mode only)
	if _shop_type == ShopType.ITEMS:
		_rust_balance_label = Label.new()
		var rust_count = _inventory.get_rust_block_count() if _inventory else 0
		_rust_balance_label.text = "💎 Rust Blocks: %d" % rust_count
		_rust_balance_label.name = "RustBalanceLabel"  # Named so we can update it later
		_rust_balance_label.add_theme_font_size_override("font_size", 13)
		_rust_balance_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
		_rust_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_vbox.add_child(_rust_balance_label)

	# Separator
	var separator1 = HSeparator.new()
	separator1.add_theme_constant_override("separation", 2)
	content_vbox.add_child(separator1)

	# Grid area - either single column (FREE) or dual column (shop modes)
	if is_shop_mode:
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
		shop_label.text = _get_shop_items_label()  # Shop type specific
		shop_label.add_theme_font_size_override("font_size", 13)
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
		player_label.text = _get_player_items_label()  # Shop type specific
		player_label.add_theme_font_size_override("font_size", 13)
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
	var preview_height = 115 if is_shop_mode else 100  # Taller for shop (proper padding)
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
	var preview_margin_size = 12 if is_shop_mode else 10  # More padding in shop mode
	preview_margin.add_theme_constant_override("margin_left", preview_margin_size)
	preview_margin.add_theme_constant_override("margin_top", preview_margin_size)
	preview_margin.add_theme_constant_override("margin_right", preview_margin_size)
	preview_margin.add_theme_constant_override("margin_bottom", preview_margin_size)
	preview_hbox.add_child(preview_margin)

	if is_shop_mode:
		# Shop mode: Compact horizontal layout (everything in one row)
		var preview_vbox = VBoxContainer.new()
		preview_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview_vbox.add_theme_constant_override("separation", 4)
		preview_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		preview_margin.add_child(preview_vbox)

		# Trading label at top (customized for shop type)
		var trade_label = Label.new()
		if _shop_type == ShopType.ITEMS:
			trade_label.text = "BUY OR SELL:"
		else:
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
		if _shop_type == ShopType.ITEMS:
			player_giving_label.text = "Your Items"
		else:
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

		# CENTER-LEFT: Arrow (hidden for ITEMS mode)
		if _shop_type != ShopType.ITEMS:
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
		if _shop_type == ShopType.ITEMS:
			shop_getting_label.text = "Shop Items"
		else:
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


func _populate_shop_grid():
	"""Fill shop grid based on shop type"""
	match _shop_type:
		ShopType.FREE, ShopType.BLOCKS:
			_populate_blocks()
		ShopType.ITEMS:
			_populate_items()  # TODO: Phase 3
		ShopType.FOOD:
			_populate_food()  # TODO: Phase 2


func _populate_blocks():
	"""Populate grid with blocks"""
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


func _populate_player_inventory():
	"""Fill player inventory grid based on shop type"""
	match _shop_type:
		ShopType.BLOCKS:
			_populate_player_blocks()
		ShopType.ITEMS:
			_populate_player_items()  # TODO: Phase 3
		ShopType.FOOD:
			_populate_player_food()  # TODO: Phase 2


func _populate_player_blocks():
	"""Fill player grid with blocks from inventory"""
	if not _player_grid_container or not _inventory:
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
	"""Handle shop block/item button click"""
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

	# Update preview based on shop type
	var is_food = button.has_meta("is_food") and button.get_meta("is_food")
	var is_item = button.has_meta("is_item") and button.get_meta("is_item")

	if is_food or is_item:
		# Item from item_db (food or weapon/tool)
		var item = _item_db.get_item(block_id)
		if item:
			_preview_label.text = item.base_info.name.replace("_", " ").capitalize()
			if item.base_info.sprite and _preview_texture:
				_preview_texture.texture = item.base_info.sprite

		# Apply food type filtering to player grid (FOOD mode only)
		if is_food and _shop_type == ShopType.FOOD and _player_grid_container:
			var selected_food_type = button.get_meta("food_type")
			_filter_player_food_by_type(selected_food_type)
	else:
		# Block item from blocks_node
		var block = _blocks_node.get_block(block_id)
		if block:
			_preview_label.text = block.base_info.name.capitalize()
			if block.base_info.sprite_texture and _preview_texture:
				_preview_texture.texture = block.base_info.sprite_texture

	# Button enable logic depends on shop type:
	# FREE: Enable immediately when shop item selected
	# ITEMS: Enable when either shop OR player item selected (buy/sell mode)
	# BLOCKS/FOOD: Enable only when both items selected (1:1 barter)
	if _shop_type == ShopType.FREE:
		_add_button.disabled = false
	elif _shop_type == ShopType.ITEMS:
		# ITEMS mode: Enable if shop item selected (for buying)
		_add_button.disabled = false
	else:
		# BLOCKS/FOOD mode: Require both items selected
		_add_button.disabled = (_selected_player_block_id < 0)


func _on_player_block_selected(block_id: int, button: Button, count: int):
	"""Handle player block/item button click (shop mode only)"""
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

	# Update preview based on shop type
	var is_food = button.has_meta("is_food") and button.get_meta("is_food")
	var is_item = button.has_meta("is_item") and button.get_meta("is_item")

	if is_food or is_item:
		# Item from item_db (food or weapon/tool)
		var item = _item_db.get_item(block_id)
		if item:
			_player_preview_label.text = item.base_info.name.replace("_", " ").capitalize()
			if item.base_info.sprite and _player_preview_texture:
				_player_preview_texture.texture = item.base_info.sprite

		# Apply food type filtering to shop grid (FOOD mode only)
		if is_food and _shop_type == ShopType.FOOD and _grid_container:
			var selected_food_type = button.get_meta("food_type")
			_filter_shop_food_by_type(selected_food_type)
	else:
		# Block item from blocks_node
		var block = _blocks_node.get_block(block_id)
		if block:
			_player_preview_label.text = block.base_info.name.capitalize()
			if block.base_info.sprite_texture and _player_preview_texture:
				_player_preview_texture.texture = block.base_info.sprite_texture

	# Update quantity spinbox max value based on player's count
	_quantity_spinbox.max_value = count
	if _quantity_spinbox.value > count:
		_quantity_spinbox.value = count

	# Button enable logic depends on shop type:
	# ITEMS: Enable when player item selected (for selling)
	# BLOCKS/FOOD: Enable only when both items selected (1:1 barter)
	if _shop_type == ShopType.ITEMS:
		# ITEMS mode: Enable if player item selected (for selling)
		_add_button.disabled = false
	else:
		# BLOCKS/FOOD mode: Require both items selected
		_add_button.disabled = (_selected_block_id < 0)


func _on_trade_blocks():
	"""Handle trading blocks or items in shop mode"""
	if not _player or not _inventory:
		_show_message("Error: Could not access inventory!", Color.RED)
		return

	var InventoryItem = load("res://blocky_game/player/inventory_item.gd")

	# ITEMS mode uses different logic (buy/sell with rust blocks)
	if _shop_type == ShopType.ITEMS:
		_handle_item_shop_transaction()
		return

	# BLOCKS and FOOD modes require both items to be selected
	if _selected_block_id < 0 or _selected_player_block_id < 0:
		_show_message("Select both items to trade!", Color.RED)
		return

	var quantity = int(_quantity_spinbox.value)

	# Determine if we're trading blocks or items (food)
	var is_food_trade = (_shop_type == ShopType.FOOD)
	var item_type = InventoryItem.TYPE_ITEM if is_food_trade else InventoryItem.TYPE_BLOCK

	# Get item/block names for display
	var shop_item_name = ""
	var player_item_name = ""

	if is_food_trade:
		var shop_item = _item_db.get_item(_selected_block_id)
		var player_item = _item_db.get_item(_selected_player_block_id)
		if not shop_item or not player_item:
			return
		shop_item_name = shop_item.base_info.name.replace("_", " ").capitalize()
		player_item_name = player_item.base_info.name.replace("_", " ").capitalize()
	else:
		var shop_block = _blocks_node.get_block(_selected_block_id)
		var player_block = _blocks_node.get_block(_selected_player_block_id)
		if not shop_block or not player_block:
			return
		shop_item_name = shop_block.base_info.name.capitalize()
		player_item_name = player_block.base_info.name.capitalize()

	# Find and remove player's items from inventory
	var removed_count = 0
	for i in range(_inventory._slots.size()):
		if _inventory._slots[i] == null:
			continue

		var slot = _inventory._slots[i]
		if slot.type == item_type and slot.id == _selected_player_block_id:
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
		_show_message("Error: Not enough items to trade!", Color.RED)
		return

	# Add shop items to inventory
	var added = false

	# Try to find existing stack of the shop item
	for i in range(_inventory._slots.size()):
		if _inventory._slots[i] == null:
			continue

		var slot = _inventory._slots[i]
		if slot.type == item_type and slot.id == _selected_block_id:
			slot.count += quantity
			added = true
			break

	# If no existing stack, create new slot
	if not added:
		for i in range(_inventory._slots.size()):
			if _inventory._slots[i] == null:
				var item = InventoryItem.new()
				item.type = item_type
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

	var shop_name = "Provisions Market" if is_food_trade else "Block Shop"
	print("[%s] ✅ Traded %dx %s for %dx %s" % [
		shop_name, quantity, player_item_name,
		quantity, shop_item_name
	])
	_show_message("✅ Traded %dx %s for %dx %s!" % [
		quantity, player_item_name,
		quantity, shop_item_name
	], Color.GREEN)

	# Refresh player inventory grid to update counts
	for child in _player_grid_container.get_children():
		child.queue_free()
	await get_tree().process_frame
	_populate_player_inventory()

	# Reset selections and quantity
	_selected_player_block_id = -1
	_selected_player_button = null
	_quantity_spinbox.value = 1
	_quantity_spinbox.max_value = 99
	_add_button.disabled = true

	# Clear food filters if we were in food shop mode
	if _shop_type == ShopType.FOOD:
		_clear_food_filters()

	if _player_preview_label:
		_player_preview_label.text = "None"
	if _player_preview_texture:
		_player_preview_texture.texture = null


func _handle_item_shop_transaction():
	"""Handle ITEMS mode transactions (buy with rust blocks OR sell for rust blocks)"""
	var InventoryItem = load("res://blocky_game/player/inventory_item.gd")

	# Determine if this is a BUY (shop item selected) or SELL (player item selected) transaction
	var is_buy = (_selected_block_id >= 0 and _selected_player_block_id < 0)
	var is_sell = (_selected_player_block_id >= 0 and _selected_block_id < 0)

	if not is_buy and not is_sell:
		_show_message("Select an item to buy or sell!", Color.RED)
		return

	if is_buy:
		# BUY: Purchase shop item with rust blocks
		var item_id = _selected_block_id
		var item = _item_db.get_item(item_id)
		if not item:
			return

		var price = 10  # Base price for shop items (no powers)

		# Check if player has enough rust blocks
		var rust_count = _inventory.get_rust_block_count()
		if rust_count < price:
			_show_message("Not enough rust blocks! Need %d, have %d" % [price, rust_count], Color.RED)
			return

		# Spend rust blocks
		if not _inventory.spend_rust_blocks(price):
			_show_message("Transaction failed!", Color.RED)
			return

		# Add item to inventory (find empty slot)
		var added = false
		for i in range(_inventory._slots.size()):
			if _inventory._slots[i] == null:
				var new_item = InventoryItem.new()
				new_item.type = InventoryItem.TYPE_ITEM
				new_item.id = item_id
				new_item.count = 1  # Items aren't stackable
				_inventory._slots[i] = new_item
				added = true
				break

		if not added:
			# Refund rust blocks if inventory full
			_inventory.add_rust_blocks(price)
			_show_message("Inventory full! Purchase cancelled.", Color.RED)
			return

		_inventory._update_views()
		print("[Item Shop] ✅ Bought %s for %d rust blocks" % [item.base_info.name, price])
		_show_message("✅ Bought %s for %d rust blocks!" % [item.base_info.name.replace("_", " ").capitalize(), price], Color.GREEN)

	else:  # is_sell
		# SELL: Sell player item for rust blocks
		var item_id = _selected_player_block_id
		var item = _item_db.get_item(item_id)
		if not item:
			return

		# Find the item in inventory to get its power count
		var item_slot = null
		var slot_index = -1
		for i in range(_inventory._slots.size()):
			var slot = _inventory._slots[i]
			if slot != null and slot.type == InventoryItem.TYPE_ITEM and slot.id == item_id:
				item_slot = slot
				slot_index = i
				break

		if not item_slot:
			_show_message("Item not found in inventory!", Color.RED)
			return

		var power_count = item_slot.skyshard_powers.size()
		var sell_price = _calculate_item_price(power_count)

		# Remove item from inventory
		_inventory._slots[slot_index] = null

		# Add rust blocks
		_inventory.add_rust_blocks(sell_price)
		_inventory._update_views()

		print("[Item Shop] ✅ Sold %s for %d rust blocks" % [item.base_info.name, sell_price])
		_show_message("✅ Sold %s for %d rust blocks!" % [item.base_info.name.replace("_", " ").capitalize(), sell_price], Color.GREEN)

	# Update rust block balance display
	_update_rust_balance_display()

	# Refresh player inventory grid to update counts
	for child in _player_grid_container.get_children():
		child.queue_free()
	await get_tree().process_frame
	_populate_player_inventory()

	# Reset selections
	_selected_block_id = -1
	_selected_button = null
	_selected_player_block_id = -1
	_selected_player_button = null
	_add_button.disabled = true

	if _preview_label:
		_preview_label.text = "None"
	if _preview_texture:
		_preview_texture.texture = null
	if _player_preview_label:
		_player_preview_label.text = "None"
	if _player_preview_texture:
		_player_preview_texture.texture = null


func _update_rust_balance_display():
	"""Update the rust block balance label in the UI"""
	if _rust_balance_label and _inventory:
		var rust_count = _inventory.get_rust_block_count()
		_rust_balance_label.text = "💎 Rust Blocks: %d" % rust_count
		print("[Item Shop] Updated balance display: %d rust blocks" % rust_count)


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


func _get_shop_title() -> String:
	"""Get title based on shop type"""
	match _shop_type:
		ShopType.BLOCKS:
			return "🏪 Block Shop"
		ShopType.ITEMS:
			return "⚔️ Item Shop"
		ShopType.FOOD:
			return "🍖 Food Shop"
		_:
			return "🧱 Block Selector"


func _get_shop_subtitle() -> String:
	"""Get subtitle based on shop type"""
	match _shop_type:
		ShopType.BLOCKS:
			return "Choose a block to buy and a block to trade (1-for-1 barter)"
		ShopType.ITEMS:
			return "Buy and sell items and weapons using rust blocks"
		ShopType.FOOD:
			return "Trade raw foods for raw foods, or cooked for cooked (1-for-1)"
		_:
			return "Click a block to select it, then choose quantity and add to inventory"


func _get_shop_items_label() -> String:
	"""Get shop items label based on shop type"""
	match _shop_type:
		ShopType.BLOCKS:
			return "📦 SHOP BLOCKS"
		ShopType.ITEMS:
			return "⚔️ SHOP ITEMS"
		ShopType.FOOD:
			return "🍖 SHOP FOOD"
		_:
			return "📦 SHOP BLOCKS"


func _get_player_items_label() -> String:
	"""Get player items label based on shop type"""
	match _shop_type:
		ShopType.BLOCKS:
			return "🎒 YOUR BLOCKS"
		ShopType.ITEMS:
			return "🎒 YOUR ITEMS"
		ShopType.FOOD:
			return "🎒 YOUR FOOD"
		_:
			return "🎒 YOUR BLOCKS"


# ============================================================================
# PHASE 3: DANIELS' ITEM SHOP (Rust Block Currency)
# ============================================================================

func _populate_items():
	"""Populate shop grid with weapons and items (excludes food)"""
	if not _item_db:
		return

	# Define weapon/item IDs (exclude food IDs 13-39)
	var weapon_ids = range(0, 13)  # IDs 0-12: rocket_launcher through tree_feller
	var misc_item_ids = [40, 41]  # light_orb, spear
	var all_item_ids = weapon_ids + misc_item_ids

	# Create buttons for each item
	for item_id in all_item_ids:
		var item = _item_db.get_item(item_id)
		if not item:
			continue

		# Create item button
		var button = Button.new()
		button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE + 30)
		button.pressed.connect(_on_block_selected.bind(item_id, button))

		# Store metadata for item type
		button.set_meta("is_item", true)
		button.set_meta("item_id", item_id)

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

		# Button content - VBox with icon + label + price
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 3)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(vbox)

		# Item sprite
		var texture_rect = TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(56, 56)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Load sprite from item
		if item.base_info.sprite:
			texture_rect.texture = item.base_info.sprite

		vbox.add_child(texture_rect)

		# Item name
		var label = Label.new()
		label.text = item.base_info.name.replace("_", " ").capitalize()
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(BUTTON_SIZE - 8, 0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(label)

		# Price label (10 rust blocks base price, no powers on shop items)
		var price_label = Label.new()
		price_label.text = "💎 10"
		price_label.add_theme_font_size_override("font_size", 9)
		price_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(price_label)

		_grid_container.add_child(button)

	print("Item Shop: Populated %d items (%d weapons, %d misc)" % [all_item_ids.size(), weapon_ids.size(), misc_item_ids.size()])


func _populate_food():
	"""Populate shop grid with food items (raw first, then cooked)"""
	if not _item_db:
		return

	# Define food IDs (from recipes_database.json)
	var raw_food_ids = [13, 14, 15, 16, 22, 24, 25, 26]  # egg, rabbit, berries, honey, wheat_seeds, pumpkin, mushroom, fish
	var cooked_food_ids = range(27, 40)  # IDs 27-39 (grilled_fish through super_stew)

	# Combine lists: raw foods first, then cooked
	var all_food_ids = raw_food_ids + cooked_food_ids

	# Create buttons for each food item
	for food_id in all_food_ids:
		var item = _item_db.get_item(food_id)
		if not item:
			continue

		# Determine food type
		var food_type = "raw" if food_id in raw_food_ids else "cooked"

		# Create food button
		var button = Button.new()
		button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE + 30)
		button.pressed.connect(_on_block_selected.bind(food_id, button))

		# Store food type as metadata for filtering
		button.set_meta("food_type", food_type)
		button.set_meta("is_food", true)

		# Button style (same as blocks)
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
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(vbox)

		# Food sprite
		var texture_rect = TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(56, 56)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Load sprite from item
		if item.base_info.sprite:
			texture_rect.texture = item.base_info.sprite

		vbox.add_child(texture_rect)

		# Food name
		var label = Label.new()
		label.text = item.base_info.name.replace("_", " ").capitalize()
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(BUTTON_SIZE - 8, 0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(label)

		_grid_container.add_child(button)

	print("Provisions Market: Populated %d food items (%d raw, %d cooked)" % [all_food_ids.size(), raw_food_ids.size(), cooked_food_ids.size()])


func _populate_player_items():
	"""Fill player grid with weapons/items from inventory (with power counts)"""
	if not _player_grid_container or not _inventory or not _item_db:
		return

	# Define weapon/item IDs (exclude food)
	var weapon_ids = range(0, 13)  # IDs 0-12
	var misc_item_ids = [40, 41]  # light_orb, spear
	var all_item_ids = weapon_ids + misc_item_ids

	# Collect all items from inventory slots
	var items_data = []  # [{item, slot_index, power_count}, ...]

	for i in range(_inventory._slots.size()):
		var slot = _inventory._slots[i]
		if slot != null and slot.type == slot.TYPE_ITEM and slot.id in all_item_ids:
			var power_count = slot.skyshard_powers.size()
			items_data.append({"item": slot, "slot_index": i, "power_count": power_count})

	# Create buttons for each item
	for item_data in items_data:
		var slot_item = item_data.item
		var item_id = slot_item.id
		var power_count = item_data.power_count
		var item = _item_db.get_item(item_id)
		if not item:
			continue

		# Calculate sell price based on power count
		var sell_price = _calculate_item_price(power_count)

		# Create item button
		var button = Button.new()
		button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE + 30)
		button.pressed.connect(_on_player_block_selected.bind(item_id, button, 1))  # Items aren't stackable

		# Store metadata for pricing
		button.set_meta("is_item", true)
		button.set_meta("power_count", power_count)
		button.set_meta("sell_price", sell_price)

		# Button style (player variant)
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.15, 0.2, 0.25, 0.8)
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

		# Button content - VBox with icon + label + price
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 3)
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(vbox)

		# Item sprite
		var texture_rect = TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(56, 56)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Load sprite from item
		if item.base_info.sprite:
			texture_rect.texture = item.base_info.sprite

		vbox.add_child(texture_rect)

		# Power count overlay (top-left corner) - only if has powers
		if power_count > 0:
			var power_label = Label.new()
			power_label.text = "⭐%d" % power_count
			power_label.add_theme_font_size_override("font_size", 12)
			power_label.add_theme_color_override("font_color", Color.YELLOW)
			power_label.add_theme_color_override("font_outline_color", Color.BLACK)
			power_label.add_theme_constant_override("outline_size", 4)
			power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			power_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			power_label.position = Vector2(4, 4)
			power_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(power_label)

		# Item name
		var label = Label.new()
		label.text = item.base_info.name.replace("_", " ").capitalize()
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(BUTTON_SIZE - 8, 0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(label)

		# Sell price label
		var price_label = Label.new()
		price_label.text = "💎 %d" % sell_price
		price_label.add_theme_font_size_override("font_size", 9)
		price_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))  # Green for sell price
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(price_label)

		_player_grid_container.add_child(button)

	print("Item Shop: Player has %d items" % items_data.size())


## Calculate item price based on power count
## Base: 10, +1 power: 20, +2 powers: 40
func _calculate_item_price(power_count: int) -> int:
	"""Calculate item buy/sell price based on number of fused powers"""
	match power_count:
		0:
			return 10
		1:
			return 20
		2:
			return 40
		_:
			return 40  # Cap at 40 for 2+ powers


func _populate_player_food():
	"""Fill player grid with food items from inventory"""
	if not _player_grid_container or not _inventory or not _item_db:
		return

	# Define food ID ranges
	var raw_food_ids = [13, 14, 15, 16, 22, 24, 25, 26]
	var cooked_food_ids = range(27, 40)
	var all_food_ids = raw_food_ids + cooked_food_ids

	# Collect all food items from inventory with their total counts
	var food_counts = {}  # {food_id: count}

	for slot in _inventory._slots:
		if slot != null and slot.type == slot.TYPE_ITEM and slot.id in all_food_ids:
			var food_id = slot.id
			if not food_counts.has(food_id):
				food_counts[food_id] = 0
			food_counts[food_id] += slot.count

	# Create buttons for each food type the player has
	for food_id in food_counts.keys():
		var count = food_counts[food_id]
		var item = _item_db.get_item(food_id)
		if not item:
			continue

		# Determine food type
		var food_type = "raw" if food_id in raw_food_ids else "cooked"

		# Create food button with count overlay
		var button = Button.new()
		button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE + 30)
		button.pressed.connect(_on_player_block_selected.bind(food_id, button, count))

		# Store food type as metadata for filtering
		button.set_meta("food_type", food_type)
		button.set_meta("is_food", true)

		# Button style (player variant)
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.15, 0.2, 0.25, 0.8)
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

		# Food sprite
		var texture_rect = TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(56, 56)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Load sprite from item
		if item.base_info.sprite:
			texture_rect.texture = item.base_info.sprite

		vbox.add_child(texture_rect)

		# Count overlay (bottom-right corner)
		var count_label = Label.new()
		count_label.text = str(count)
		count_label.add_theme_font_size_override("font_size", 14)
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.add_theme_color_override("font_outline_color", Color.BLACK)
		count_label.add_theme_constant_override("outline_size", 6)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_label.position = Vector2(BUTTON_SIZE - 28, 5)
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(count_label)

		# Food name
		var label = Label.new()
		label.text = item.base_info.name.replace("_", " ").capitalize()
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(BUTTON_SIZE - 8, 0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(label)

		_player_grid_container.add_child(button)

	print("Provisions Market: Player has %d different food items" % food_counts.size())


func _filter_player_food_by_type(selected_food_type: String):
	"""Disable player food buttons that don't match the selected shop food type"""
	if not _player_grid_container:
		return

	for child in _player_grid_container.get_children():
		if child is Button and child.has_meta("is_food"):
			var button_food_type = child.get_meta("food_type")
			# Disable if types don't match, enable if they do
			child.disabled = (button_food_type != selected_food_type)


func _filter_shop_food_by_type(selected_food_type: String):
	"""Disable shop food buttons that don't match the selected player food type"""
	if not _grid_container:
		return

	for child in _grid_container.get_children():
		if child is Button and child.has_meta("is_food"):
			var button_food_type = child.get_meta("food_type")
			# Disable if types don't match, enable if they do
			child.disabled = (button_food_type != selected_food_type)


func _clear_food_filters():
	"""Re-enable all food buttons (clear filtering)"""
	if _grid_container:
		for child in _grid_container.get_children():
			if child is Button and child.has_meta("is_food"):
				child.disabled = false

	if _player_grid_container:
		for child in _player_grid_container.get_children():
			if child is Button and child.has_meta("is_food"):
				child.disabled = false


func _close_modal():
	"""Close the modal and cleanup"""
	modal_closed.emit()

	# Restore mouse mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	queue_free()
