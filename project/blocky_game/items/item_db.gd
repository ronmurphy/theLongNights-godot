extends Node

const ROOT = "res://blocky_game/items"

const Item = preload("./item.gd")


var _items := []


func _init():
	_create_item({
		"name": "rocket_launcher",
		"behavior": "rocket_launcher.gd"
	})
	_create_item({
		"name": "grappling_hook",
		"behavior": "grappling_hook.gd"
	})
	_create_item({
		"name": "wind_walker_boots",
		"behavior": "wind_walker_boots.gd"
	})
	_create_item({
		"name": "ice_bow",
		"behavior": "ice_bow.gd"
	})
	_create_item({
		"name": "fire_staff",
		"behavior": "fire_staff.gd"
	})
	_create_item({
		"name": "throwing_knives",
		"behavior": "throwing_knives.gd"
	})
	_create_item({
		"name": "torch",
		"behavior": "torch.gd"
	})
	_create_item({
		"name": "portal_compass",
		"behavior": "portal_compass.gd"
	})
	_create_item({
		"name": "stone_hammer",
		"behavior": "stone_hammer.gd"
	})
	_create_item({
		"name": "machete",
		"behavior": "machete.gd"
	})
	_create_item({
		"name": "crossbow",
		"behavior": "crossbow.gd"
	})
	_create_item({
		"name": "sword",
		"behavior": "sword.gd"
	})
	_create_item({
		"name": "tree_feller",
		"behavior": "tree_feller.gd"
	})
	# Food items from hunting
	_create_item({
		"name": "egg",
		"behavior": "egg.gd"
	})
	_create_item({
		"name": "rabbit",
		"behavior": "rabbit.gd"
	})
	_create_item({
		"name": "berries",
		"behavior": "berries.gd"
	})
	_create_item({
		"name": "honey",
		"behavior": "honey.gd"
	})
	# Material items from goblin hunting
	_create_item({
		"name": "stone_ore",
		"behavior": "stone_ore.gd"
	})
	_create_item({
		"name": "coal",
		"behavior": "coal.gd"
	})
	_create_item({
		"name": "iron_ore",
		"behavior": "iron_ore.gd"
	})
	_create_item({
		"name": "gold_ore",
		"behavior": "gold_ore.gd"
	})
	# Rare blood moon material
	_create_item({
		"name": "skyshard",
		"behavior": "skyshard.gd"
	})
	# Food items from farming/harvesting (Phase 1A)
	_create_item({
		"name": "wheat_seeds",
		"behavior": "wheat_seeds.gd"
	})
	_create_item({
		"name": "pumpkin_seeds",
		"behavior": "pumpkin_seeds.gd"
	})
	_create_item({
		"name": "pumpkin",
		"behavior": "pumpkin.gd"
	})
	_create_item({
		"name": "mushroom",
		"behavior": "mushroom.gd"
	})
	_create_item({
		"name": "fish",
		"behavior": "fish.gd"
	})
	# Cooked food items (Phase 2 - Cooking System)
	_create_item({
		"name": "grilled_fish",
		"behavior": "grilled_fish.gd"
	})
	_create_item({
		"name": "berry_honey_snack",
		"behavior": "berry_honey_snack.gd"
	})
	_create_item({
		"name": "cooked_egg",
		"behavior": "cooked_egg.gd"
	})
	_create_item({
		"name": "roasted_rabbit",
		"behavior": "roasted_rabbit.gd"
	})
	_create_item({
		"name": "pumpkin_soup",
		"behavior": "pumpkin_soup.gd"
	})
	_create_item({
		"name": "mushroom_bites",
		"behavior": "mushroom_bites.gd"
	})
	_create_item({
		"name": "honey_bread",
		"behavior": "honey_bread.gd"
	})
	_create_item({
		"name": "pumpkin_pie",
		"behavior": "pumpkin_pie.gd"
	})
	_create_item({
		"name": "fish_mushroom_stew",
		"behavior": "fish_mushroom_stew.gd"
	})
	_create_item({
		"name": "berry_honey_bread",
		"behavior": "berry_honey_bread.gd"
	})
	_create_item({
		"name": "egg_mushroom_omelette",
		"behavior": "egg_mushroom_omelette.gd"
	})
	_create_item({
		"name": "hunters_feast",
		"behavior": "hunters_feast.gd"
	})
	_create_item({
		"name": "super_stew",
		"behavior": "super_stew.gd"
	})
	_create_item({
		"name": "light_orb",
		"behavior": "light_orb.gd"
	})
	_create_item({
		"name": "spear",
		"behavior": "spear.gd"
	})
	_create_item({
		"name": "keepers_charm",
		"behavior": "keepers_charm.gd"
	})
	_create_item({
		"name": "wood_shield",
		"behavior": "wood_shield.gd"
	})
	_create_item({
		"name": "shield",
		"behavior": "shield.gd"
	})
	_create_item({
		"name": "shield_crusader",
		"behavior": "shield_crusader.gd"
	})


func get_item(id: int) -> Item:
	assert(id >= 0)
	return _items[id]


func _create_item(d: Dictionary):
	var dir = str(ROOT, "/", d.name, "/")
	
	var item : Item
	if d.has("behavior"):
		var behavior_script = load(str(dir, d.name, ".gd"))
		item = behavior_script.new()
	else:
		item = Item.new()
	
	# Give the node a deterministic name for networking
	item.name = d.name
	
	var base_info = item.base_info
	base_info.id = len(_items)
	base_info.name = d.name
	base_info.sprite = load(str(dir, d.name, "_sprite.png"))
	_items.append(item)
	add_child(item)
