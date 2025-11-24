extends "../item.gd"

## Pouch Tier 3 - Rare loot bag
## Drops from Tier 3 enemies
## Contains: 1-2 skyshards + rare weapons/materials

const SERVER_PEER_ID = 1
const InventoryItem = preload("../../player/inventory_item.gd")

# Loot table - Rare weapons and good materials
const LOOT_TABLE = {
	# Rare weapons (weight 8-10)
	"machete": 10,
	"sword": 10,
	"crossbow": 8,
	"boomerang": 8,
	"ice_bow": 6,
	"fire_staff": 6,

	# Valuable materials (weight 6-8)
	"gold_ore": 8,
	"iron_ore": 8,

	# Some uncommon items (weight 4-5)
	"pumpkin": 5,
	"mushroom": 4,
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

	if typeof(inv_item_or_count) == TYPE_OBJECT:
		inv_item_or_count.count -= 1

	# Give 1-2 skyshards
	var skyshard_count = randi_range(1, 2)
	var skyshard_item = _find_item_by_name("skyshard")
	if skyshard_item:
		_add_item_to_inventory(inventory, skyshard_item.base_info.id, skyshard_count)
		print("✨ Rare Pouch opened! +%d Skyshard(s)" % skyshard_count)

	# Give 1 random item
	var random_item_name = _roll_loot_table()
	var random_item = _find_item_by_name(random_item_name)
	if random_item:
		var count = 1
		# Ore gets 3-5
		if random_item_name in ["iron_ore", "gold_ore"]:
			count = randi_range(3, 5)

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

	return "machete"


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
	for i in range(inventory._slots.size()):
		var slot = inventory._slots[i]
		if slot != null and slot.type == InventoryItem.TYPE_ITEM and slot.id == item_id:
			slot.count += count
			inventory._slot_views[i].get_display().set_item(slot)
			inventory.changed.emit()
			return

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
