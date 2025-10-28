extends Node
## HuntingSystem - Manages companion hunting mechanics
## Companion hunts for X hours, finds items every in-game hour, returns with loot
## Race affects what items are found

# Preload for inventory items
const InventoryItem = preload("res://blocky_game/player/inventory_item.gd")

# Signals
signal hunt_started(companion_name: String, duration_hours: int)
signal hunt_hour_passed(items_found: Array)
signal hunt_completed(total_loot: Array)
signal hunt_cancelled(loot_kept: Array, loot_lost: Array)

# Hunt state
var is_hunting: bool = false
var hunt_duration_hours: int = 0
var hunt_elapsed_hours: int = 0
var hunt_loot: Array = []  # Items found during hunt
var hunted_companion: Node = null  # Reference to companion who is hunting

# Item definitions
const ITEM_TYPES = {
	"egg": {"type": "food", "race_weight": {"human": 1.0, "elf": 0.5, "dwarf": 2.0, "goblin": 0.3}},
	"rabbit": {"type": "food", "race_weight": {"human": 1.0, "elf": 1.0, "dwarf": 2.0, "goblin": 0.5}},
	"berries": {"type": "food", "race_weight": {"human": 1.0, "elf": 3.0, "dwarf": 0.5, "goblin": 0.2}},
	"honey": {"type": "food", "race_weight": {"human": 1.0, "elf": 2.0, "dwarf": 0.5, "goblin": 0.1}},
	"stone_ore": {"type": "material", "race_weight": {"human": 0.0, "elf": 0.0, "dwarf": 0.0, "goblin": 2.0}},
	"coal": {"type": "material", "race_weight": {"human": 0.0, "elf": 0.0, "dwarf": 0.0, "goblin": 1.5}},
	"iron_ore": {"type": "material", "race_weight": {"human": 0.0, "elf": 0.0, "dwarf": 0.0, "goblin": 1.0}},
	"gold_ore": {"type": "material", "race_weight": {"human": 0.0, "elf": 0.0, "dwarf": 0.0, "goblin": 0.5}},
}

# Item ID mapping (corresponds to item_db.gd registration order)
# IDs 0-9: Weapons
# IDs 10+: Food/Materials from hunting
const ITEM_ID_MAP = {
	"egg": 10,
	"rabbit": 11,
	"berries": 12,
	"honey": 13,
	"stone_ore": 14,
	"coal": 15,
	"iron_ore": 16,
	"gold_ore": 17,
}

func _ready():
	# Don't connect here - autoloads init too early
	print("HuntingSystem: Ready")


func _connect_to_time_manager():
	"""Connect to TimeManager - called when hunt starts to ensure connection is active"""
	print("HuntingSystem: _connect_to_time_manager called, TimeManager=%s" % TimeManager)
	if not TimeManager:
		push_error("HuntingSystem: TimeManager is null!")
		return
	
	print("HuntingSystem: TimeManager has hour_changed signal: %s" % TimeManager.has_signal("hour_changed"))
	if TimeManager.has_signal("hour_changed"):
		# Check if already connected to avoid duplicate connections
		if not TimeManager.hour_changed.is_connected(_on_hour_changed):
			TimeManager.hour_changed.connect(_on_hour_changed)
			print("HuntingSystem: Successfully connected to TimeManager.hour_changed")
		else:
			print("HuntingSystem: Already connected to TimeManager.hour_changed")
	else:
		push_error("HuntingSystem: TimeManager doesn't have hour_changed signal!")


func start_hunt(companion: Node, duration_hours: int) -> bool:
	"""Start a hunt with the given companion for specified hours"""
	if is_hunting:
		push_warning("HuntingSystem: Already hunting!")
		return false
	
	if not companion:
		push_error("HuntingSystem: No companion provided")
		return false
	
	if duration_hours <= 0:
		push_error("HuntingSystem: Invalid hunt duration")
		return false
	
	# Connect to TimeManager NOW (right when hunt starts)
	_connect_to_time_manager()
	
	# Start hunt
	is_hunting = true
	hunt_duration_hours = duration_hours
	hunt_elapsed_hours = 0
	hunt_loot = []
	hunted_companion = companion
	
	# Disable companion teleport and set them to wander
	print("HuntingSystem: Companion has set_hunting method: %s" % companion.has_method("set_hunting"))
	if companion.has_method("set_hunting"):
		print("HuntingSystem: Calling companion.set_hunting(true)")
		companion.set_hunting(true)
	else:
		push_error("HuntingSystem: Companion does not have set_hunting method!")
	
	var companion_name = CompanionManager.get_companion_name() if CompanionManager else "Companion"
	print("HuntingSystem: Hunt started! %s will hunt for %d hours" % [companion_name, duration_hours])
	hunt_started.emit(companion_name, duration_hours)
	
	return true


func cancel_hunt() -> Array:
	"""Cancel current hunt, companion returns with 50% of loot"""
	if not is_hunting:
		return []
	
	is_hunting = false
	
	# Calculate penalty (50% loss)
	var loot_kept = []
	var loot_lost = []
	
	for item in hunt_loot:
		if randf() < 0.5:  # 50% chance to keep each item
			loot_kept.append(item)
		else:
			loot_lost.append(item)
	
	# Return companion and re-enable teleport
	if hunted_companion and hunted_companion.has_method("set_hunting"):
		hunted_companion.set_hunting(false)
	
	hunt_loot = []
	hunted_companion = null
	
	print("HuntingSystem: Hunt cancelled. Kept %d items, lost %d" % [len(loot_kept), len(loot_lost)])
	hunt_cancelled.emit(loot_kept, loot_lost)
	
	return loot_kept


func _on_hour_changed(hour: int) -> void:
	"""Called every in-game hour by TimeManager"""
	print("HuntingSystem: _on_hour_changed called with hour=%d! is_hunting=%s" % [hour, is_hunting])
	
	if not is_hunting:
		return
	
	hunt_elapsed_hours += 1
	print("HuntingSystem: Hour %d/%d elapsed" % [hunt_elapsed_hours, hunt_duration_hours])
	
	# Random chance to find items
	var items_found = _discover_items()
	if items_found.size() > 0:
		hunt_loot.append_array(items_found)
		print("HuntingSystem: Found %d items!" % items_found.size())
		hunt_hour_passed.emit(items_found)
	
	# Check if hunt is complete
	if hunt_elapsed_hours >= hunt_duration_hours:
		_complete_hunt()


func _complete_hunt():
	"""Complete the hunt and return companion with all loot"""
	if not is_hunting:
		return
	
	is_hunting = false
	
	# Return companion and re-enable teleport
	if hunted_companion and hunted_companion.has_method("set_hunting"):
		hunted_companion.set_hunting(false)
	
	var final_loot = hunt_loot.duplicate()
	hunt_loot = []
	hunted_companion = null
	
	print("HuntingSystem: Hunt complete! Companion returns with %d items" % final_loot.size())
	hunt_completed.emit(final_loot)


func _discover_items() -> Array:
	"""Random item discovery for current hour"""
	var items = []
	var rng = RandomNumberGenerator.new()
	
	# Base discovery chance (per hour)
	var discovery_chance = 0.6  # 60% chance per hour
	
	if rng.randf() > discovery_chance:
		return items  # No discovery this hour
	
	# Determine companion race for loot weights
	var companion_race = CompanionManager.companion_race if CompanionManager else "human"
	
	# 1-3 items per discovery
	var item_count = rng.randi_range(1, 3)
	
	for i in range(item_count):
		var item_name = _pick_weighted_item(companion_race)
		items.append(item_name)
	
	return items


func _pick_weighted_item(race: String) -> String:
	"""Pick an item based on race weights"""
	var rng = RandomNumberGenerator.new()
	var weights = {}
	
	# Build weight table for this race
	for item_name in ITEM_TYPES.keys():
		var race_weights = ITEM_TYPES[item_name]["race_weight"]
		weights[item_name] = race_weights.get(race, 0.0)
	
	# Weighted random selection
	var total_weight = 0.0
	for weight in weights.values():
		total_weight += weight
	
	if total_weight <= 0.0:
		return "egg"  # Fallback
	
	var roll = rng.randf() * total_weight
	var accumulated = 0.0
	
	for item_name in weights.keys():
		accumulated += weights[item_name]
		if roll <= accumulated:
			return item_name
	
	return "egg"  # Fallback


func get_hunt_status() -> Dictionary:
	"""Return current hunt status"""
	return {
		"is_hunting": is_hunting,
		"duration_hours": hunt_duration_hours,
		"elapsed_hours": hunt_elapsed_hours,
		"remaining_hours": max(0, hunt_duration_hours - hunt_elapsed_hours),
		"loot_found": hunt_loot.size(),
		"items": hunt_loot.duplicate()
	}


func add_loot_to_inventory(loot: Array) -> Dictionary:
	"""Add loot array to player inventory and return summary"""
	if not loot or loot.size() == 0:
		print("HuntingSystem: No loot to add")
		return {}
	
	print("HuntingSystem: add_loot_to_inventory called with %d items" % loot.size())
	
	# Get inventory
	var inventory = get_node_or_null("/root/Main/Game/CharacterAvatar/Inventory")
	if not inventory:
		push_error("HuntingSystem: Could not find inventory at /root/Main/Game/CharacterAvatar/Inventory")
		return {}
	
	print("HuntingSystem: Found inventory: %s" % inventory.name)
	
	# Count items by name
	var item_summary = {}
	for item_name in loot:
		item_summary[item_name] = item_summary.get(item_name, 0) + 1
	
	print("HuntingSystem: Item summary: %s" % item_summary)
	
	# Add items to inventory
	for item_name in item_summary.keys():
		if not ITEM_ID_MAP.has(item_name):
			push_warning("HuntingSystem: Unknown item: %s" % item_name)
			continue
		
		var item_id = ITEM_ID_MAP[item_name]
		var count = item_summary[item_name]
		
		print("HuntingSystem: Adding %d x %s (ID %d)" % [count, item_name, item_id])
		
		# Try to add to existing stacks first via inventory method
		if inventory.has_method("add_item_by_id"):
			inventory.add_item_by_id(InventoryItem.TYPE_ITEM, item_id, count)
		else:
			# Fallback: create InventoryItem and add manually
			var inv_item = InventoryItem.new()
			inv_item.type = InventoryItem.TYPE_ITEM
			inv_item.id = item_id
			inv_item.count = count
			
			# Find first empty slot and add
			if inventory.has_method("add_item"):
				inventory.add_item(inv_item)
	
	print("HuntingSystem: Added to inventory: %s" % item_summary)
	return item_summary

