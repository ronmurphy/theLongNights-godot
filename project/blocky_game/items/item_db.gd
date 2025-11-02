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
		"name": "climbing_claws",
		"behavior": "climbing_claws.gd"
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
