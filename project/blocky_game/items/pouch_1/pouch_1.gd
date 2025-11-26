extends "../item.gd"

## Pouch Tier 1 - Common loot bag
## Drops from Tier 1 enemies
## Contains: 1 skyshard + common materials/food

const SERVER_PEER_ID = 1
const InventoryItem = preload("../../player/inventory_item.gd")

# Loot table - Common materials and food
const LOOT_TABLE = {
	# Common drops (weight 15-20)
	"stone_ore": 20,
	"coal": 20,
	"berries": 15,
	"egg": 15,
	"rabbit": 12,
	"fish": 12,
	"mushroom": 10,
	"torch": 15,

	# Rare chance for basic weapons (weight 2-3)
	"throwing_knives": 2,
	"spear": 2,

	# Limited potions - rare drops (weight 3-4)
	"limited_hppotion": 4,
	"limited_atkpotion": 3,
	"limited_defpotion": 3,
	"limited_luckpotion": 3,
}


func use(trans: Transform3D, inv_item_or_count = 1):
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_use", trans, inv_item_or_count)
	else:
		_use(trans, inv_item_or_count)


func _use(trans: Transform3D, inv_item_or_count):
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var inventory = player.get_node_or_null("Inventory")
	if not inventory:
		return

	# Decrement pouch count
	if typeof(inv_item_or_count) == TYPE_OBJECT:
		inv_item_or_count.count -= 1

	# Always give 1 skyshard
	var skyshard_item = _find_item_by_name("skyshard")
	if skyshard_item:
		_add_item_to_inventory(inventory, skyshard_item.base_info.id, 1)
		print("💰 Common Pouch opened! +1 Skyshard")

	# Give 1 random item from loot table
	var random_item_name = _roll_loot_table()
	var random_item = _find_item_by_name(random_item_name)
	if random_item:
		var count = 1
		# Give more of common materials (2-4)
		if random_item_name in ["stone_ore", "coal", "berries", "torch"]:
			count = randi_range(2, 4)

		_add_item_to_inventory(inventory, random_item.base_info.id, count)
		print("   +%d %s" % [count, random_item_name])


func _roll_loot_table() -> String:
	var total_weight = 0
	for weight in LOOT_TABLE.values():
		total_weight += weight

	var roll = randi() % total_weight
	var current_weight = 0
	for item_name in LOOT_TABLE.keys():
		current_weight += LOOT_TABLE[item_name]
		if roll < current_weight:
			return item_name

	return "berries"


func _find_item_by_name(item_name: String):
	var items_node = get_node_or_null("/root/Main/Game/Items")
	if not items_node:
		return null

	for i in range(100):
		var item = items_node.get_item(i)
		if item and item.base_info.name == item_name:
			return item
	return null


func _add_item_to_inventory(inventory, item_id: int, count: int = 1):
	# Try to find existing stack first
	for i in range(inventory._slots.size()):
		var slot = inventory._slots[i]
		if slot != null and slot.type == InventoryItem.TYPE_ITEM and slot.id == item_id:
			slot.count += count
			inventory._slot_views[i].get_display().set_item(slot)
			inventory.changed.emit()
			return

	# No existing stack, find first empty slot
	for i in range(inventory._slots.size()):
		if inventory._slots[i] == null:
			var new_item = InventoryItem.new()
			new_item.type = InventoryItem.TYPE_ITEM
			new_item.id = item_id
			new_item.count = count
			inventory._slots[i] = new_item
			inventory._slot_views[i].get_display().set_item(new_item)
			inventory.changed.emit()
			return

	push_warning("Inventory full! Could not add item ID %d" % item_id)


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, inv_item_or_count = 1):
	_use(trans, inv_item_or_count)
