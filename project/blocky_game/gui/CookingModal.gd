extends Control

## CookingModal - Cooking system UI
## Player can combine food items to create cooked meals
## Discovered recipes can be auto-cooked from the recipe list

signal modal_closed

# UI references
@onready var _title_label: Label
@onready var _close_button: Button
@onready var _food_inventory_container: GridContainer
@onready var _ingredient_slots: Array[Button] = []
@onready var _cook_button: Button
@onready var _result_label: Label
@onready var _recipe_panel: VBoxContainer
@onready var _hint_label: Label
@onready var _hint_particles: CPUParticles2D

# Cooking state
var _selected_ingredients: Array = []  # [{id: int, count: int}]
const MAX_INGREDIENT_SLOTS = 3
const MAX_INGREDIENT_COUNT = 5

# Discovered recipes (saved per player)
var _discovered_recipes: Array[int] = []  # Array of result_ids

# Item name to sprite mapping
# Note: Files in /animals/ with "_hunted" suffix are for cooking system
const ITEM_SPRITE_PATHS = {
	# Raw ingredients (use item ID as key)
	13: "res://assets/art/food/egg.png",
	14: "res://assets/art/animals/rabbit_hunted.png",  # _hunted suffix for cooking
	15: "res://assets/art/food/berry.png",
	16: "res://assets/art/food/honey.png",
	22: "res://assets/art/food/wheat_seeds.png",
	23: "res://assets/art/food/pumpkin_seeds.png",
	24: "res://assets/art/food/pumpkin.png",
	25: "res://assets/art/food/mushroom.png",
	26: "res://assets/art/food/fish.png",
	# Cooked foods
	27: "res://assets/art/food/grilled_fish.png",
	28: "res://assets/art/food/berry_honey_snack.png",
	29: "res://assets/art/food/cooked_egg.png",
	30: "res://assets/art/animals/rabbit_hunted.png",  # Placeholder (roasted rabbit)
	31: "res://assets/art/food/mushroom_soup.png",  # Placeholder for pumpkin soup
	32: "res://assets/art/food/mushroom_bites.png",
	33: "res://assets/art/food/honey_bread.png",
	34: "res://assets/art/food/pumpkin_pie.png",
	35: "res://assets/art/food/carrot_stew.png",  # Placeholder for fish & mushroom stew
	36: "res://assets/art/food/berry_bread.png",
	37: "res://assets/art/food/cooked_egg.png",  # Placeholder for omelette
	38: "res://assets/art/food/super_stew.png",  # Placeholder for hunter's feast
	39: "res://assets/art/food/super_stew.png",
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
	# Main panel background (wider for 3 columns)
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(1100, 600)
	panel.focus_mode = Control.FOCUS_NONE

	# Style the main panel with dark background and golden border
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.12, 0.1, 0.95)  # Dark brown
	panel_style.border_color = Color(0.7, 0.6, 0.3)  # Gold
	panel_style.set_border_width_all(3)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)

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
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))  # Warm gold
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
	
	# Main content: horizontal split (ingredients | cooking area | recipes)
	var content_hbox = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 15)
	main_vbox.add_child(content_hbox)

	# === LEFT PANEL: Food Inventory ===
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(280, 0)
	content_hbox.add_child(left_panel)

	var food_title = Label.new()
	food_title.text = "Available Ingredients"
	food_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	food_title.add_theme_font_size_override("font_size", 16)
	food_title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))  # Gold
	left_panel.add_child(food_title)

	var food_spacer = Control.new()
	food_spacer.custom_minimum_size = Vector2(0, 10)
	left_panel.add_child(food_spacer)

	# Scrollable food list
	var food_scroll = ScrollContainer.new()
	food_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(food_scroll)

	_food_inventory_container = GridContainer.new()
	_food_inventory_container.columns = 3  # 3 columns of ingredient buttons
	_food_inventory_container.add_theme_constant_override("h_separation", 8)
	_food_inventory_container.add_theme_constant_override("v_separation", 8)
	_food_inventory_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	food_scroll.add_child(_food_inventory_container)

	# === CENTER PANEL: Cooking Area ===
	var center_panel = VBoxContainer.new()
	center_panel.custom_minimum_size = Vector2(340, 0)
	content_hbox.add_child(center_panel)
	
	var cooking_title = Label.new()
	cooking_title.text = "Cooking Pot"
	cooking_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooking_title.add_theme_font_size_override("font_size", 16)
	cooking_title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))  # Gold
	center_panel.add_child(cooking_title)

	var cooking_spacer = Control.new()
	cooking_spacer.custom_minimum_size = Vector2(0, 10)
	center_panel.add_child(cooking_spacer)

	# Ingredient slots (3 slots, click-based)
	var slots_label = Label.new()
	slots_label.text = "Click ingredients to add\n(up to 3 slots, max 5 each)"
	slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slots_label.add_theme_font_size_override("font_size", 11)
	center_panel.add_child(slots_label)

	var slots_spacer = Control.new()
	slots_spacer.custom_minimum_size = Vector2(0, 15)
	center_panel.add_child(slots_spacer)

	# Container for ingredient slots
	var slots_hbox = HBoxContainer.new()
	slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_hbox.add_theme_constant_override("separation", 15)
	center_panel.add_child(slots_hbox)

	# Create 3 ingredient slots
	for i in range(MAX_INGREDIENT_SLOTS):
		var slot_btn = Button.new()
		slot_btn.custom_minimum_size = Vector2(100, 100)
		slot_btn.text = "Empty"
		slot_btn.add_theme_font_size_override("font_size", 12)
		slot_btn.pressed.connect(_on_ingredient_slot_clicked.bind(i))
		slots_hbox.add_child(slot_btn)
		_ingredient_slots.append(slot_btn)

	var slots_spacer2 = Control.new()
	slots_spacer2.custom_minimum_size = Vector2(0, 25)
	center_panel.add_child(slots_spacer2)

	# Cook button container (center it)
	var cook_btn_container = CenterContainer.new()
	center_panel.add_child(cook_btn_container)

	# Cook button
	_cook_button = Button.new()
	_cook_button.text = "🔥 Cook!"
	_cook_button.custom_minimum_size = Vector2(180, 45)
	_cook_button.add_theme_font_size_override("font_size", 18)
	_cook_button.disabled = true
	_cook_button.pressed.connect(_on_cook_pressed)

	# Style the cook button with orange/fire theme
	var cook_style_normal = StyleBoxFlat.new()
	cook_style_normal.bg_color = Color(0.8, 0.4, 0.1)  # Orange
	cook_style_normal.border_color = Color(0.6, 0.3, 0.05)
	cook_style_normal.set_border_width_all(2)
	cook_style_normal.corner_radius_top_left = 6
	cook_style_normal.corner_radius_top_right = 6
	cook_style_normal.corner_radius_bottom_left = 6
	cook_style_normal.corner_radius_bottom_right = 6
	_cook_button.add_theme_stylebox_override("normal", cook_style_normal)

	var cook_style_hover = StyleBoxFlat.new()
	cook_style_hover.bg_color = Color(0.9, 0.5, 0.15)  # Brighter orange
	cook_style_hover.border_color = Color(0.7, 0.4, 0.1)
	cook_style_hover.set_border_width_all(2)
	cook_style_hover.corner_radius_top_left = 6
	cook_style_hover.corner_radius_top_right = 6
	cook_style_hover.corner_radius_bottom_left = 6
	cook_style_hover.corner_radius_bottom_right = 6
	_cook_button.add_theme_stylebox_override("hover", cook_style_hover)

	var cook_style_pressed = StyleBoxFlat.new()
	cook_style_pressed.bg_color = Color(0.6, 0.3, 0.05)  # Darker orange
	cook_style_pressed.border_color = Color(0.4, 0.2, 0.03)
	cook_style_pressed.set_border_width_all(2)
	cook_style_pressed.corner_radius_top_left = 6
	cook_style_pressed.corner_radius_top_right = 6
	cook_style_pressed.corner_radius_bottom_left = 6
	cook_style_pressed.corner_radius_bottom_right = 6
	_cook_button.add_theme_stylebox_override("pressed", cook_style_pressed)

	cook_btn_container.add_child(_cook_button)

	var result_spacer = Control.new()
	result_spacer.custom_minimum_size = Vector2(0, 15)
	center_panel.add_child(result_spacer)

	# Result label
	_result_label = Label.new()
	_result_label.text = "Add ingredients to begin"
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 12)
	center_panel.add_child(_result_label)

	var hint_spacer = Control.new()
	hint_spacer.custom_minimum_size = Vector2(0, 10)
	center_panel.add_child(hint_spacer)

	# Recipe hint label (shown when undiscovered recipe detected)
	_hint_label = Label.new()
	_hint_label.text = "✨ New recipe available! ✨"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))  # Golden yellow
	_hint_label.visible = false
	center_panel.add_child(_hint_label)

	# Sparkle particles (centered above hint label)
	_hint_particles = CPUParticles2D.new()
	_hint_particles.position = Vector2(170, 260)  # Center of cooking area
	_hint_particles.amount = 20
	_hint_particles.lifetime = 1.5
	_hint_particles.explosiveness = 0.1
	_hint_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_hint_particles.emission_sphere_radius = 30.0
	_hint_particles.direction = Vector2(0, -1)
	_hint_particles.spread = 30.0
	_hint_particles.gravity = Vector2(0, -40)
	_hint_particles.initial_velocity_min = 20.0
	_hint_particles.initial_velocity_max = 40.0
	_hint_particles.scale_amount_min = 3.0
	_hint_particles.scale_amount_max = 6.0
	_hint_particles.color = Color(1.0, 0.9, 0.3, 1.0)  # Gold
	_hint_particles.emitting = false
	panel.add_child(_hint_particles)

	# === RIGHT PANEL: Discovered Recipes ===
	var right_panel = VBoxContainer.new()
	right_panel.custom_minimum_size = Vector2(280, 0)
	content_hbox.add_child(right_panel)

	var recipe_title = Label.new()
	recipe_title.text = "Discovered Recipes"
	recipe_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	recipe_title.add_theme_font_size_override("font_size", 16)
	recipe_title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))  # Gold
	right_panel.add_child(recipe_title)

	var recipe_spacer = Control.new()
	recipe_spacer.custom_minimum_size = Vector2(0, 10)
	right_panel.add_child(recipe_spacer)

	# Scrollable recipe list
	var recipe_scroll = ScrollContainer.new()
	recipe_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(recipe_scroll)

	_recipe_panel = VBoxContainer.new()
	_recipe_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_scroll.add_child(_recipe_panel)
	
	# Center the panel
	panel.position = (get_viewport_rect().size - panel.custom_minimum_size) / 2

	# Populate food inventory
	_populate_food_inventory()

	# Populate recipe panel
	_populate_recipes()


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
		13: "Egg", 14: "Rabbit", 15: "Berries", 16: "Honey",
		22: "Wheat Seeds", 24: "Pumpkin", 25: "Mushroom", 26: "Fish",
		# Cooked foods
		27: "Grilled Fish", 28: "Berry-Honey Snack", 29: "Cooked Egg",
		30: "Roasted Rabbit", 31: "Pumpkin Soup", 32: "Mushroom Bites",
		33: "Honey Bread", 34: "Pumpkin Pie", 35: "Fish & Mushroom Stew",
		36: "Berry Honey Bread", 37: "Egg & Mushroom Omelette",
		38: "Hunter's Feast", 39: "Super Stew"
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
		var food_name = food_names.get(food_id, "Unknown")

		# Create button with icon and count
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.pressed.connect(_on_food_item_clicked.bind(food_id))
		btn.tooltip_text = food_name  # Tooltip shows food name

		# VBox to stack icon and count
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(vbox)

		# Add icon
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(48, 48)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Load sprite from mapping
		if ITEM_SPRITE_PATHS.has(food_id):
			var sprite_path = ITEM_SPRITE_PATHS[food_id]
			if ResourceLoader.exists(sprite_path):
				icon.texture = load(sprite_path)
		vbox.add_child(icon)

		# Add count label
		var label = Label.new()
		label.text = "x%d" % count
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(label)

		_food_inventory_container.add_child(btn)
	
	if found_food.is_empty():
		var no_food_label = Label.new()
		no_food_label.text = "No food items\nin inventory"
		no_food_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_food_label.add_theme_font_size_override("font_size", 14)
		_food_inventory_container.add_child(no_food_label)


func _populate_recipes():
	"""Populate the discovered recipes panel"""
	# Load recipe database
	var Recipes = preload("res://blocky_game/cooking/recipes.gd")
	var recipes = Recipes.new()

	if _discovered_recipes.is_empty():
		var no_recipes_label = Label.new()
		no_recipes_label.text = "No recipes discovered yet.\n\nTry experimenting with\ndifferent ingredients!"
		no_recipes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_recipes_label.add_theme_font_size_override("font_size", 12)
		no_recipes_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_recipe_panel.add_child(no_recipes_label)
		return

	var food_names = {
		13: "Egg", 14: "Rabbit", 15: "Berries", 16: "Honey",
		22: "Wheat Seeds", 23: "Pumpkin Seeds", 24: "Pumpkin",
		25: "Mushroom", 26: "Fish",
		# Cooked foods
		27: "Grilled Fish", 28: "Berry-Honey Snack", 29: "Cooked Egg",
		30: "Roasted Rabbit", 31: "Pumpkin Soup", 32: "Mushroom Bites",
		33: "Honey Bread", 34: "Pumpkin Pie", 35: "Fish & Mushroom Stew",
		36: "Berry Honey Bread", 37: "Egg & Mushroom Omelette",
		38: "Hunter's Feast", 39: "Super Stew"
	}

	# Show each discovered recipe
	for result_id in _discovered_recipes:
		# Find the recipe that produces this result
		var recipe_data = null
		for recipe in recipes._recipes:
			if recipe.result_id == result_id:
				recipe_data = recipe
				break

		if not recipe_data:
			continue

		# Create recipe card
		var recipe_card = PanelContainer.new()
		recipe_card.custom_minimum_size = Vector2(0, 100)
		_recipe_panel.add_child(recipe_card)

		var card_vbox = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 5)
		recipe_card.add_child(card_vbox)

		# Recipe name and icon
		var name_hbox = HBoxContainer.new()
		card_vbox.add_child(name_hbox)

		var recipe_icon = TextureRect.new()
		recipe_icon.custom_minimum_size = Vector2(32, 32)
		recipe_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		recipe_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ITEM_SPRITE_PATHS.has(result_id):
			var sprite_path = ITEM_SPRITE_PATHS[result_id]
			if ResourceLoader.exists(sprite_path):
				recipe_icon.texture = load(sprite_path)
		name_hbox.add_child(recipe_icon)

		var name_label = Label.new()
		name_label.text = food_names.get(result_id, "Unknown")
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_hbox.add_child(name_label)

		# Ingredients list
		var ingredients_text = ""
		for i in range(recipe_data.ingredients.size()):
			var ing = recipe_data.ingredients[i]
			var ing_name = food_names.get(ing.id, "Unknown")
			ingredients_text += "%dx %s" % [ing.count, ing_name]
			if i < recipe_data.ingredients.size() - 1:
				ingredients_text += ", "

		var ingredients_label = Label.new()
		ingredients_label.text = "• " + ingredients_text
		ingredients_label.add_theme_font_size_override("font_size", 11)
		ingredients_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_vbox.add_child(ingredients_label)

		# Effects display
		if recipe_data.has("description") and recipe_data.description != "":
			var effect_label = Label.new()
			effect_label.text = recipe_data.description
			effect_label.add_theme_font_size_override("font_size", 10)
			effect_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))  # Light blue
			effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			card_vbox.add_child(effect_label)

		# Healing display
		if recipe_data.has("effects"):
			var effects = recipe_data.effects

			if effects.has("healing") and effects.healing > 0:
				var healing_label = Label.new()
				healing_label.text = "💚 Restores %d HP" % effects.healing
				healing_label.add_theme_font_size_override("font_size", 10)
				healing_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))  # Bright green
				card_vbox.add_child(healing_label)

		# Quick cook button
		var quick_cook_btn = Button.new()
		quick_cook_btn.text = "Quick Cook"
		quick_cook_btn.add_theme_font_size_override("font_size", 11)
		quick_cook_btn.pressed.connect(_on_quick_cook.bind(recipe_data))
		card_vbox.add_child(quick_cook_btn)

		# Spacer between recipes
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 5)
		_recipe_panel.add_child(spacer)


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
			# Load sprite from mapping
			if ITEM_SPRITE_PATHS.has(ingredient.id):
				var sprite_path = ITEM_SPRITE_PATHS[ingredient.id]
				if ResourceLoader.exists(sprite_path):
					icon.texture = load(sprite_path)
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

	# Check for undiscovered recipe hint
	_check_for_undiscovered_recipe()


func _check_for_undiscovered_recipe():
	"""Check if current ingredients match an undiscovered recipe and show hint"""
	if _selected_ingredients.is_empty():
		_hint_label.visible = false
		_hint_particles.emitting = false
		return

	# Load recipe database
	var Recipes = preload("res://blocky_game/cooking/recipes.gd")
	var recipes = Recipes.new()

	# Check if ingredients match a recipe
	var result = recipes.find_recipe(_selected_ingredients)

	if result.found:
		var result_id_int = int(result.result_id)  # Cast to int (JSON returns float)
		if not _discovered_recipes.has(result_id_int):
			# Undiscovered recipe found! Show hint
			_hint_label.visible = true
			_hint_particles.emitting = true
		else:
			# Recipe already discovered
			_hint_label.visible = false
			_hint_particles.emitting = false
	else:
		# No recipe found
		_hint_label.visible = false
		_hint_particles.emitting = false


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


func _on_quick_cook(recipe_data: Dictionary):
	"""Quick cook a discovered recipe"""
	# Get player inventory
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		print("Error: Player not found")
		return

	var inventory = player.get_node_or_null("Inventory")
	if inventory == null:
		print("Error: Inventory not found")
		return

	# Check if player has ingredients
	const InventoryItem = preload("res://blocky_game/player/inventory_item.gd")
	var slots = inventory._slots

	for ingredient in recipe_data.ingredients:
		var found_count = 0
		for slot in slots:
			if slot != null and slot.type == InventoryItem.TYPE_ITEM and slot.id == ingredient.id:
				found_count += slot.count

		if found_count < ingredient.count:
			_result_label.text = "❌ Not enough ingredients!"
			_result_label.add_theme_color_override("font_color", Color.RED)
			await get_tree().create_timer(2.0).timeout
			_result_label.text = "Add ingredients to begin"
			_result_label.remove_theme_color_override("font_color")
			return

	# Consume ingredients
	if not _consume_ingredients(recipe_data.ingredients, inventory):
		print("Error: Could not consume ingredients")
		return

	# Add cooked food
	if not _add_cooked_food(recipe_data.result_id, recipe_data.result_count, inventory):
		print("Error: Could not add cooked food (inventory full?)")
		_result_label.text = "❌ Inventory full!"
		_result_label.add_theme_color_override("font_color", Color.RED)
		return

	# Get cooked food name from recipe data
	var cooked_name = "food"
	if recipe_data.has("name"):
		cooked_name = recipe_data.name
	else:
		var food_names = {
			27: "Grilled Fish", 28: "Berry-Honey Snack", 29: "Cooked Egg",
			30: "Roasted Rabbit", 31: "Pumpkin Soup", 32: "Mushroom Bites",
			33: "Honey Bread", 34: "Pumpkin Pie", 35: "Fish & Mushroom Stew",
			36: "Berry Honey Bread", 37: "Egg & Mushroom Omelette",
			38: "Hunter's Feast", 39: "Super Stew"
		}
		cooked_name = food_names.get(recipe_data.result_id, "food")

	print("Quick cooking successful! Created: ", cooked_name)

	# Show success message
	_result_label.text = "✅ Cooked %s!" % cooked_name
	_result_label.add_theme_color_override("font_color", Color.GREEN)

	# Play cooking animation
	_play_cooking_animation()

	# Refresh food inventory display
	await get_tree().create_timer(0.5).timeout
	_refresh_food_inventory()

	# Reset message after delay
	await get_tree().create_timer(2.0).timeout
	_result_label.text = "Add ingredients to begin"
	_result_label.remove_theme_color_override("font_color")


func _refresh_food_inventory():
	"""Refresh the food inventory display after cooking"""
	# Clear existing buttons
	for child in _food_inventory_container.get_children():
		child.queue_free()

	# Repopulate
	_populate_food_inventory()


func _refresh_recipes():
	"""Refresh the recipes panel"""
	# Clear existing recipe cards
	for child in _recipe_panel.get_children():
		child.queue_free()

	# Repopulate
	_populate_recipes()


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

	# Discover recipe if new
	var is_new_recipe = false
	var result_id_int = int(result.result_id)  # Cast to int (JSON returns float)
	if not _discovered_recipes.has(result_id_int):
		_discovered_recipes.append(result_id_int)
		is_new_recipe = true
		print("New recipe discovered: ", cooked_name)

	# Show success message
	if is_new_recipe:
		_result_label.text = "✨ New Recipe! %s ✨" % cooked_name
	else:
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

	# Refresh recipes if new recipe discovered
	if is_new_recipe:
		_refresh_recipes()

	# Reset message after delay
	await get_tree().create_timer(2.0).timeout
	_result_label.text = "Add ingredients to begin"
	_result_label.remove_theme_color_override("font_color")
