extends Node

## Cooking Recipe Database
## Loads recipes from recipes_database.json

# Recipe structure: {ingredients: [{id: int, count: int}], result_id: int, result_count: int, name: String, description: String, effects: Dictionary}
var _recipes = []

func _init():
	_load_recipes_from_json()


func _load_recipes_from_json():
	"""Load all recipes from the JSON database"""
	var json_path = "res://assets/data/recipes_database.json"

	if not FileAccess.file_exists(json_path):
		print("ERROR: recipes_database.json not found at: ", json_path)
		return

	var file = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		print("ERROR: Could not open recipes_database.json")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)

	if parse_result != OK:
		print("ERROR: Failed to parse recipes_database.json: ", json.get_error_message())
		return

	var data = json.data

	# Load all recipes from the JSON
	if data.has("recipes"):
		for recipe_data in data.recipes:
			_recipes.append({
				"ingredients": recipe_data.ingredients,
				"result_id": recipe_data.result_id,
				"result_count": recipe_data.result_count,
				"name": recipe_data.name,
				"description": recipe_data.description,
				"effects": recipe_data.effects
			})

	print("Loaded ", _recipes.size(), " recipes from database")


func _add_recipe(ingredients: Array, result_id: int, result_count: int = 1):
	"""Add a recipe to the database (legacy support)"""
	_recipes.append({
		"ingredients": ingredients,
		"result_id": result_id,
		"result_count": result_count,
		"name": "",
		"description": "",
		"effects": {}
	})


func find_recipe(selected_ingredients: Array) -> Dictionary:
	"""
	Find a matching recipe for the given ingredients
	Returns: {found: bool, result_id: int, result_count: int}
	"""
	# Normalize selected ingredients for comparison (sort by id)
	var normalized_selected = _normalize_ingredients(selected_ingredients)
	
	# Check each recipe
	for recipe in _recipes:
		var normalized_recipe = _normalize_ingredients(recipe.ingredients)
		
		# Check if ingredients match exactly
		if _ingredients_match(normalized_selected, normalized_recipe):
			return {
				"found": true,
				"result_id": recipe.result_id,
				"result_count": recipe.result_count
			}
	
	# No recipe found
	return {"found": false}


func _normalize_ingredients(ingredients: Array) -> Array:
	"""Sort ingredients by id for comparison"""
	var sorted = ingredients.duplicate()
	sorted.sort_custom(func(a, b): return a.id < b.id)
	return sorted


func _ingredients_match(a: Array, b: Array) -> bool:
	"""Check if two ingredient lists match exactly"""
	if a.size() != b.size():
		return false

	for i in range(a.size()):
		if a[i].id != b[i].id or a[i].count != b[i].count:
			return false

	return true


func get_all_recipes() -> Array:
	"""Get all loaded recipes"""
	return _recipes


func get_recipe_by_result_id(result_id: int) -> Dictionary:
	"""Find a recipe by its result_id"""
	for recipe in _recipes:
		if recipe.result_id == result_id:
			return recipe
	return {}
