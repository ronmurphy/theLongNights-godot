extends Node

## Cooking Recipe Database
## Defines all recipes and their ingredient requirements

# Recipe structure: {ingredients: [{id: int, count: int}], result_id: int, result_count: int}
var _recipes = []

func _init():
	# Simple 1-ingredient recipes
	_add_recipe([{"id": 26, "count": 1}], 27, 1)  # fish -> grilled_fish
	
	# 2-ingredient recipes  
	_add_recipe([{"id": 15, "count": 1}, {"id": 16, "count": 1}], 28, 1)  # berries + honey -> berry_honey_snack


func _add_recipe(ingredients: Array, result_id: int, result_count: int = 1):
	"""Add a recipe to the database"""
	_recipes.append({
		"ingredients": ingredients,
		"result_id": result_id,
		"result_count": result_count
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
