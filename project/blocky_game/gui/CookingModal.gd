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
@onready var _result_label: Label

# Cooking state
var _selected_ingredients: Array = []  # [{id: int, count: int}]
const MAX_INGREDIENT_SLOTS = 3
const MAX_INGREDIENT_COUNT = 5

# Sprite name mapping for items with different art file names
const SPRITE_NAME_MAP = {
	"rabbit": "rabbit_hunted",  # rabbit item uses rabbit_hunted.png from animals folder
	"berries": "berry",  # berries item uses berry.png
}


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
	
	# Cook button container (center it)
	var cook_btn_container = CenterContainer.new()
	right_panel.add_child(cook_btn_container)
	
	# Cook button
	_cook_button = Button.new()
	_cook_button.text = "🔥 Cook!"
	_cook_button.custom_minimum_size = Vector2(200, 50)
	_cook_button.add_theme_font_size_override("font_size", 20)
	_cook_button.disabled = true
	_cook_button.pressed.connect(_on_cook_pressed)
	cook_btn_container.add_child(_cook_button)
	
	var result_spacer = Control.new()
	result_spacer.custom_minimum_size = Vector2(0, 20)
	right_panel.add_child(result_spacer)
	
	# Result label
	_result_label = Label.new()
	_result_label.text = "Add ingredients to begin"
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 14)
	right_panel.add_child(_result_label)
	
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
	var item_db = get_node_or_null("/root/Main/Game/Items")
	for food_id in found_food.keys():
		var count = found_food[food_id]
		var name = food_names.get(food_id, "Unknown")
		
		# Create HBox to hold icon + text
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 50)
		btn.pressed.connect(_on_food_item_clicked.bind(food_id))
		
		var hbox = HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(hbox)
		
		# Add icon
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Try to load sprite
		if item_db and food_id < item_db._items.size():
			var item = item_db.get_item(food_id)
			if item:
				var item_name = item.base_info.name
				# Use mapped name if available
				var sprite_name = SPRITE_NAME_MAP.get(item_name, item_name)
				# Try multiple folders
				var sprite_folders = ["res://assets/art/food/", "res://assets/art/animals/"]
				for folder in sprite_folders:
					var sprite_path = folder + sprite_name + ".png"
					if ResourceLoader.exists(sprite_path):
						icon.texture = load(sprite_path)
						break
		hbox.add_child(icon)
		
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(10, 0)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(spacer)
		
		# Add label
		var label = Label.new()
		label.text = "%s (x%d)" % [name, count]
		label.add_theme_font_size_override("font_size", 14)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(label)
		
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
	
	var item_db = get_node_or_null("/root/Main/Game/Items")
	
	# Update each slot
	for i in range(MAX_INGREDIENT_SLOTS):
		# Clear existing children (icons)
		for child in _ingredient_slots[i].get_children():
			child.queue_free()
		
		if i < _selected_ingredients.size():
			var ingredient = _selected_ingredients[i]
			var name = food_names.get(ingredient.id, "Unknown")
			
			# Create VBox for icon + text
			var vbox = VBoxContainer.new()
			vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_ingredient_slots[i].add_child(vbox)
			
			# Add sprite icon
			var icon = TextureRect.new()
			icon.custom_minimum_size = Vector2(48, 48)
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Try to load sprite
			if item_db and ingredient.id < item_db._items.size():
				var item = item_db.get_item(ingredient.id)
				if item:
					var item_name = item.base_info.name
					# Use mapped name if available
					var sprite_name = SPRITE_NAME_MAP.get(item_name, item_name)
					# Try multiple folders
					var sprite_folders = ["res://assets/art/food/", "res://assets/art/animals/"]
					for folder in sprite_folders:
						var sprite_path = folder + sprite_name + ".png"
						if ResourceLoader.exists(sprite_path):
							icon.texture = load(sprite_path)
							break
			vbox.add_child(icon)
			
			# Add text label
			var label = Label.new()
			label.text = "x%d" % ingredient.count
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 16)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(label)
			
			_ingredient_slots[i].text = ""
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


func _consume_ingredients(ingredients: Array, inventory) -> bool:
	"""Remove ingredients from inventory"""
	const InventoryItem = preload("res://blocky_game/player/inventory_item.gd")
	var slots = inventory._slots
	
	# For each ingredient, remove the required count
	for ingredient in ingredients:
		var needed = ingredient.count
		
		# Find and remove from slots
		for i in range(slots.size()):
			if slots[i] != null and slots[i].type == InventoryItem.TYPE_ITEM and slots[i].id == ingredient.id:
				if slots[i].count >= needed:
					# Remove needed amount from this slot
					slots[i].count -= needed
					if slots[i].count <= 0:
						slots[i] = null
					needed = 0
					break
				else:
					# Take all from this slot and continue
					needed -= slots[i].count
					slots[i] = null
		
		if needed > 0:
			print("Error: Not enough of ingredient ID ", ingredient.id)
			return false
	
	inventory._update_views()
	return true


func _add_cooked_food(food_id: int, count: int, inventory) -> bool:
	"""Add cooked food to inventory"""
	const InventoryItem = preload("res://blocky_game/player/inventory_item.gd")
	var slots = inventory._slots
	
	# Try to stack with existing food first
	for i in range(slots.size()):
		if slots[i] != null and slots[i].type == InventoryItem.TYPE_ITEM and slots[i].id == food_id:
			slots[i].count += count
			inventory._update_views()
			return true
	
	# Find empty slot
	for i in range(slots.size()):
		if slots[i] == null:
			var item = InventoryItem.new()
			item.id = food_id
			item.type = InventoryItem.TYPE_ITEM
			item.count = count
			slots[i] = item
			inventory._update_views()
			return true
	
	return false


func _refresh_food_inventory():
	"""Refresh the food inventory display after cooking"""
	# Clear existing buttons
	for child in _food_inventory_container.get_children():
		child.queue_free()
	
	# Repopulate
	_populate_food_inventory()


func _play_cooking_animation():
	"""Bouncing fire emoji animation inside cook button"""
	# Hide button text
	var original_text = _cook_button.text
	_cook_button.text = ""
	
	# Create fire emojis inside button
	var fire_emojis = []
	var button_center_x = _cook_button.size.x / 2
	for i in range(5):
		var fire_label = Label.new()
		fire_label.text = "🔥"
		fire_label.add_theme_font_size_override("font_size", 28)
		fire_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Position horizontally spread inside button
		fire_label.position = Vector2(button_center_x + (i - 2) * 35 - 14, 10)
		_cook_button.add_child(fire_label)
		fire_emojis.append(fire_label)
	
	# Animate them bouncing
	var duration = 1.5
	var elapsed = 0.0
	var base_y = 10.0
	while elapsed < duration:
		for i in range(fire_emojis.size()):
			var offset = sin((elapsed + i * 0.3) * 8.0) * 8.0
			fire_emojis[i].position.y = base_y + offset
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	
	# Clean up
	for emoji in fire_emojis:
		emoji.queue_free()
	
	# Restore button text
	_cook_button.text = original_text


func _on_cook_pressed():
	"""Handle cook button press"""
	# Load recipe database
	var Recipes = preload("res://blocky_game/cooking/recipes.gd")
	var recipes = Recipes.new()
	
	# Check if ingredients match a recipe
	var result = recipes.find_recipe(_selected_ingredients)
	
	if not result.found:
		print("No recipe found for these ingredients")
		# TODO: Show error message in UI
		return
	
	print("Recipe found! Result ID: ", result.result_id)
	
	# Get player inventory
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		print("Error: Player not found")
		return
	
	var inventory = player.get_node_or_null("Inventory")
	if inventory == null:
		print("Error: Inventory not found")
		return
	
	# Consume ingredients from inventory
	if not _consume_ingredients(_selected_ingredients, inventory):
		print("Error: Could not consume ingredients")
		return
	
	# Add cooked food to inventory
	if not _add_cooked_food(result.result_id, result.result_count, inventory):
		print("Error: Could not add cooked food (inventory full?)")
		_result_label.text = "❌ Inventory full!"
		_result_label.add_theme_color_override("font_color", Color.RED)
		return
	
	# Get cooked food name
	var item_db = get_node_or_null("/root/Main/Game/Items")
	var cooked_name = "food"
	if item_db and result.result_id < item_db._items.size():
		var item = item_db.get_item(result.result_id)
		if item:
			cooked_name = item.base_info.name.replace("_", " ").capitalize()
	
	print("Cooking successful! Created: ", cooked_name)
	
	# Show success message
	_result_label.text = "✅ Cooked %s!" % cooked_name
	_result_label.add_theme_color_override("font_color", Color.GREEN)
	
	# Play cooking animation (flash cook button)
	_play_cooking_animation()
	
	# Clear ingredient slots after animation
	await get_tree().create_timer(0.5).timeout
	_selected_ingredients.clear()
	_update_ingredient_slots()
	
	# Refresh food inventory display
	_refresh_food_inventory()
	
	# Reset message after delay
	await get_tree().create_timer(2.0).timeout
	_result_label.text = "Add ingredients to begin"
	_result_label.remove_theme_color_override("font_color")
