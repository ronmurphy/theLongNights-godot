extends "../item.gd"

## Pouch - Loot bag that drops from enemies (20% chance)
## Right-click to open and receive:
## - Always: 1 skyshard
## - Plus: 1 random item (weapon, food, blocks, etc.)

const SERVER_PEER_ID = 1
const InventoryItem = preload("../../player/inventory_item.gd")

# Loot table for the "+1 random item"
# Format: {"item_id": weight} - higher weight = more common
const LOOT_TABLE = {
	# Common drops (weight 10-15)
	"stone_ore": 15,    # ID will be looked up
	"coal": 15,
	"berries": 12,
	"egg": 12,
	"rabbit": 10,
	"fish": 10,

	# Uncommon drops (weight 5-8)
	"iron_ore": 8,
	"gold_ore": 5,
	"mushroom": 8,
	"pumpkin": 6,
	"torch": 10,

	# Rare weapon drops (weight 2-4)
	"throwing_knives": 4,
	"boomerang": 3,
	"spear": 4,
	"crossbow": 3,
	"machete": 2,
	"sword": 2,

	# Very rare drops (weight 1)
	"ice_bow": 1,
	"fire_staff": 1,
	"blade_of_pursuit": 1,
	"ring_of_thorns": 1,
	"ring_of_teleportation": 1,
}


func use(trans: Transform3D, inv_item_or_count = 1):
	"""Open the pouch and receive loot"""
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_use", trans, inv_item_or_count)
	else:
		_use(trans, inv_item_or_count)


func _use(trans: Transform3D, inv_item_or_count):
	"""Open the pouch - always gives 1 skyshard + 1 random item"""
	print("DEBUG: Pouch _use() called! inv_item_or_count type: ", typeof(inv_item_or_count))

	# Get player and inventory
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("DEBUG: Player not found!")
		return

	print("DEBUG: Player found: ", player)

	var inventory = player.get_node_or_null("Inventory")
	if not inventory:
		print("DEBUG: Inventory not found!")
		return

	print("DEBUG: Inventory found")

	# Decrement pouch count by 1 (not the whole stack!)
	# The inventory GUI will handle removing the item if count reaches 0
	if typeof(inv_item_or_count) == TYPE_OBJECT:
		print("DEBUG: Decrementing pouch count from ", inv_item_or_count.count)
		inv_item_or_count.count -= 1
		print("DEBUG: New count: ", inv_item_or_count.count)

	# Always give 1 skyshard
	print("DEBUG: Looking for skyshard item...")
	var skyshard_item = _find_item_by_name("skyshard")
	if skyshard_item:
		_add_item_to_inventory(inventory, skyshard_item.base_info.id, 1)
		print("🎁 Pouch opened! +1 Skyshard")

	# Give 1 random item from loot table
	var random_item_name = _roll_loot_table()
	var random_item = _find_item_by_name(random_item_name)
	if random_item:
		var count = 1
		# Give more of common materials (1-3)
		if random_item_name in ["stone_ore", "coal", "berries", "torch"]:
			count = randi_range(1, 3)

		_add_item_to_inventory(inventory, random_item.base_info.id, count)
		print("🎁 Pouch bonus: +%d %s" % [count, random_item_name])


func _roll_loot_table() -> String:
	"""Weighted random selection from loot table"""
	# Calculate total weight
	var total_weight = 0
	for weight in LOOT_TABLE.values():
		total_weight += weight

	# Roll random number
	var roll = randi() % total_weight

	# Find which item was rolled
	var current_weight = 0
	for item_name in LOOT_TABLE.keys():
		current_weight += LOOT_TABLE[item_name]
		if roll < current_weight:
			return item_name

	# Fallback (shouldn't happen)
	return "berries"


func _find_item_by_name(item_name: String):
	"""Find an item by name in the Items database"""
	var items_node = get_node_or_null("/root/Main/Game/Items")
	if not items_node:
		return null

	# Items are indexed by ID, so we need to search
	for i in range(100):  # Assume max 100 items
		var item = items_node.get_item(i)
		if item and item.base_info.name == item_name:
			return item
	return null


func _add_item_to_inventory(inventory, item_id: int, count: int = 1):
	"""Add an item to the inventory by finding first empty slot or stacking"""
	# Try to find existing stack first
	for i in range(inventory._slots.size()):
		var slot = inventory._slots[i]
		if slot != null and slot.type == InventoryItem.TYPE_ITEM and slot.id == item_id:
			# Found existing stack, add to it
			slot.count += count
			inventory._slot_views[i].get_display().set_item(slot)
			inventory.changed.emit()
			return

	# No existing stack, find first empty slot
	for i in range(inventory._slots.size()):
		if inventory._slots[i] == null:
			# Found empty slot
			var new_item = InventoryItem.new()
			new_item.type = InventoryItem.TYPE_ITEM
			new_item.id = item_id
			new_item.count = count
			inventory._slots[i] = new_item
			inventory._slot_views[i].get_display().set_item(new_item)
			inventory.changed.emit()
			return

	# No empty slots found
	push_warning("Inventory full! Could not add item ID %d" % item_id)


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, inv_item_or_count = 1):
	_use(trans, inv_item_or_count)
