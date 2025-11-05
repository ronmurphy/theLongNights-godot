extends Control

## CookingModal - Cooking system UI
## Player can combine food items to create cooked meals
## Discovered recipes can be auto-cooked from the recipe list

signal modal_closed

# UI references
@onready var _title_label: Label
@onready var _close_button: Button
@onready var _food_inventory_container: VBoxContainer
@onready var _ingredient_slots: Array[Button] = []
@onready var _cook_button: Button

# Cooking state
var _selected_ingredients: Array = []  # [{id: int, count: int}]
const MAX_INGREDIENT_SLOTS = 3
const MAX_INGREDIENT_COUNT = 5


func _ready():
	# Create UI structure dynamically
	_build_ui()
	
	# IMPORTANT: Force mouse to be visible when modal opens
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Show the modal centered
	show()


func _process(_delta):
	"""Continuously enforce mouse visibility"""
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_ui():
	# Main panel background
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(900, 600)
	panel.focus_mode = Control.FOCUS_NONE
	add_child(panel)
	
	# Main vertical layout
	var main_vbox = VBoxContainer.new()
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_bottom = 1.0
	main_vbox.offset_left = 20
	main_vbox.offset_top = 20
	main_vbox.offset_right = -20
	main_vbox.offset_bottom = -20
	panel.add_child(main_vbox)
	
	# Header HBox (title + close button)
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	# Title
	_title_label = Label.new()
	_title_label.text = "🍳 Cooking Station"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(_title_label)
	
	# Close button (X)
	_close_button = Button.new()
	_close_button.text = "✕"
	_close_button.custom_minimum_size = Vector2(40, 40)
	_close_button.add_theme_font_size_override("font_size", 24)
	_close_button.pressed.connect(_on_close_pressed)
	header_hbox.add_child(_close_button)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(spacer1)
	
	# Instructions
	var instructions = Label.new()
	instructions.text = "Select ingredients to cook delicious meals"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(instructions)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(spacer2)
	
	# Main content: horizontal split (inventory | cooking area)
	var content_hbox = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_hbox)
	
	# === LEFT SIDE: Food Inventory ===
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(300, 0)
	content_hbox.add_child(left_panel)
	
	var food_title = Label.new()
	food_title.text = "Available Ingredients"
	food_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	food_title.add_theme_font_size_override("font_size", 16)
	left_panel.add_child(food_title)
	
	var food_spacer = Control.new()
	food_spacer.custom_minimum_size = Vector2(0, 10)
	left_panel.add_child(food_spacer)
	
	# Scrollable food list
	var food_scroll = ScrollContainer.new()
	food_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(food_scroll)
	
	_food_inventory_container = VBoxContainer.new()
	_food_inventory_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	food_scroll.add_child(_food_inventory_container)
	
	# === RIGHT SIDE: Cooking Area ===
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(right_panel)
	
	var cooking_title = Label.new()
	cooking_title.text = "Cooking Pot"
	cooking_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooking_title.add_theme_font_size_override("font_size", 16)
	right_panel.add_child(cooking_title)
	
	var cooking_spacer = Control.new()
	cooking_spacer.custom_minimum_size = Vector2(0, 10)
	right_panel.add_child(cooking_spacer)
	
	# Ingredient slots (3 slots, click-based)
	var slots_label = Label.new()
	slots_label.text = "Click ingredients to add (up to 3 slots, max 5 count each)"
	slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slots_label.add_theme_font_size_override("font_size", 12)
	right_panel.add_child(slots_label)
	
	var slots_spacer = Control.new()
	slots_spacer.custom_minimum_size = Vector2(0, 20)
	right_panel.add_child(slots_spacer)
	
	# Container for ingredient slots
	var slots_hbox = HBoxContainer.new()
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_hbox.add_theme_constant_override("separation", 20)
	right_panel.add_child(slots_hbox)
	
	# Create 3 ingredient slots
	for i in range(MAX_INGREDIENT_SLOTS):
		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(120, 120)
		slot_btn.text = "Empty"
		slot_btn.add_theme_font_size_override("font_size", 14)
		slot_btn.pressed.connect(_on_ingredient_slot_clicked.bind(i))
		slots_hbox.add_child(slot_btn)
		_ingredient_slots.append(slot_btn)
	
	var slots_spacer2 = Control.new()
	slots_spacer2.custom_minimum_size = Vector2(0, 30)
	right_panel.add_child(slots_spacer2)
	
	# Cook button
	_cook_button = Button.new()
	_cook_button.text = "🔥 Cook!"
	_cook_button.custom_minimum_size = Vector2(200, 50)
	_cook_button.add_theme_font_size_override("font_size", 20)
	_cook_button.disabled = true
	_cook_button.pressed.connect(_on_cook_pressed)
	right_panel.add_child(_cook_button)
	
	# Center cook button
	var cook_btn_container = CenterContainer.new()
	cook_btn_container.add_child(_cook_button)
	right_panel.add_child(cook_btn_container)
	
	var result_spacer = Control.new()
	result_spacer.custom_minimum_size = Vector2(0, 20)
	right_panel.add_child(result_spacer)
	
	# Result label
	var result_label = Label.new()
	result_label.text = "Add ingredients to begin"
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 14)
	right_panel.add_child(result_label)
	
	# Center the panel
	panel.position = (get_viewport_rect().size - panel.custom_minimum_size) / 2
	
	# Populate food inventory
	_populate_food_inventory()


func _on_close_pressed():
	"""Handle close button click"""
	_close_modal()


func _close_modal():
	"""Close the modal and restore game controls"""
	# Restore mouse capture
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Emit signal for cleanup
	modal_closed.emit()
	
	# Remove from scene
	queue_free()


func _input(event: InputEvent):
	"""Handle ESC key to close modal"""
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_modal()


func _populate_food_inventory():
	"""Populate the food inventory list from player's inventory"""
	# Get player inventory
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	
	var inventory = player.get_node_or_null("Inventory")
	if inventory == null:
		return
	
	# Raw food item IDs
	const RAW_FOOD_IDS = [13, 14, 15, 16, 22, 24, 25, 26]  # egg, rabbit, berries, honey, wheat_seeds, pumpkin, mushroom, fish
	var food_names = {
		13: "Egg",
		14: "Rabbit",
		15: "Berries",
		16: "Honey",
		22: "Wheat Seeds",
		24: "Pumpkin",
		25: "Mushroom",
		26: "Fish"
	}
	
	# Find all food items in inventory
	const InventoryItem = preload("res://blocky_game/player/inventory_item.gd")
	var slots = inventory._slots
	var found_food = {}
	
	for slot in slots:
		if slot != null and slot.type == InventoryItem.TYPE_ITEM and slot.id in RAW_FOOD_IDS:
			if not found_food.has(slot.id):
				found_food[slot.id] = 0
			found_food[slot.id] += slot.count
	
	# Create buttons for each food type found
	for food_id in found_food.keys():
		var count = found_food[food_id]
		var name = food_names.get(food_id, "Unknown")
		
		var btn = Button.new()
		btn.text = "%s (x%d)" % [name, count]
		btn.custom_minimum_size = Vector2(0, 40)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_food_item_clicked.bind(food_id))
		_food_inventory_container.add_child(btn)
	
	if found_food.is_empty():
		var no_food_label = Label.new()
		no_food_label.text = "No food items\nin inventory"
		no_food_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_food_label.add_theme_font_size_override("font_size", 14)
		_food_inventory_container.add_child(no_food_label)


func _on_food_item_clicked(food_id: int):
	"""Handle clicking a food item in the inventory list"""
	
	# Get actual count of this food in inventory
	var actual_count = _get_food_count_in_inventory(food_id)
	var max_count = min(MAX_INGREDIENT_COUNT, actual_count)
	
	# Try to add to first empty slot OR increment count if same food type
	for i in range(_selected_ingredients.size()):
		if _selected_ingredients[i].id == food_id:
			# Same food type - cycle count (1→2→...→max→1)
			_selected_ingredients[i].count += 1
			if _selected_ingredients[i].count > max_count:
				_selected_ingredients[i].count = 1
			_update_ingredient_slots()
			return
	
	# Add to first empty slot if space available
	if _selected_ingredients.size() < MAX_INGREDIENT_SLOTS:
		_selected_ingredients.append({"id": food_id, "count": 1})
		_update_ingredient_slots()


func _on_ingredient_slot_clicked(slot_index: int):
	"""Handle clicking an ingredient slot (removes ingredient)"""
	if slot_index < _selected_ingredients.size():
		_selected_ingredients.remove_at(slot_index)
		_update_ingredient_slots()


func _update_ingredient_slots():
	"""Update the visual display of ingredient slots"""
	var food_names = {
		13: "Egg",
		14: "Rabbit",
		15: "Berries",
		16: "Honey",
		22: "Wheat Seeds",
		24: "Pumpkin",
		25: "Mushroom",
		26: "Fish"
	}
	
	# Update each slot
	for i in range(MAX_INGREDIENT_SLOTS):
		if i < _selected_ingredients.size():
			var ingredient = _selected_ingredients[i]
			var name = food_names.get(ingredient.id, "Unknown")
			_ingredient_slots[i].text = "%s\nx%d" % [name, ingredient.count]
		else:
			_ingredient_slots[i].text = "Empty"
	
	# Enable/disable cook button
	_cook_button.disabled = _selected_ingredients.is_empty()


func _get_food_count_in_inventory(food_id: int) -> int:
	"""Get the total count of a specific food item in player's inventory"""
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return 0
	
	var inventory = player.get_node_or_null("Inventory")
	if inventory == null:
		return 0
	
	const InventoryItem = preload("res://blocky_game/player/inventory_item.gd")
	var total = 0
	for slot in inventory._slots:
		if slot != null and slot.type == InventoryItem.TYPE_ITEM and slot.id == food_id:
			total += slot.count
	
	return total


func _on_cook_pressed():
	"""Handle cook button press"""
	# TODO: Add recipe checking and cooked item creation
	print("CookingModal: Cook button pressed - recipe checking not yet implemented")
