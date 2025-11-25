extends Node

## VoidChallengeManager - Tracks void challenge completions and handles rewards
## Singleton that monitors push_block goal completion in void ruins
## Shows completion dialog, gives potion rewards, and teleports player back

# Reference to VoidRuinSpawner to access active challenge data
var _void_ruin_spawner: Node = null

# Dialog showing flag (prevent multiple dialogs)
var _dialog_showing: bool = false


func _ready():
	print("VoidChallengeManager ready")

	# Connect to all existing push_blocks (for hot reloading)
	_connect_to_existing_push_blocks()


func initialize(void_ruin_spawner: Node):
	"""Initialize with reference to VoidRuinSpawner"""
	_void_ruin_spawner = void_ruin_spawner
	print("VoidChallengeManager initialized with VoidRuinSpawner")

	# Connect to any existing push_blocks
	_connect_to_existing_push_blocks()


func _connect_to_existing_push_blocks():
	"""Connect to goal_reached signals from existing push_blocks"""
	var push_blocks = get_tree().get_nodes_in_group("push_blocks")
	for push_block in push_blocks:
		if not push_block.goal_reached.is_connected(_on_push_block_goal_reached):
			push_block.goal_reached.connect(_on_push_block_goal_reached)
			print("🔗 Connected to existing push_block: ", push_block.get_instance_id())


func register_push_block(push_block: Node3D):
	"""Register a new push_block to listen for goal completion"""
	if push_block.has_signal("goal_reached"):
		if not push_block.goal_reached.is_connected(_on_push_block_goal_reached):
			push_block.goal_reached.connect(_on_push_block_goal_reached)
			print("🔗 VoidChallengeManager registered push_block: ", push_block.get_instance_id())


func _on_push_block_goal_reached(push_block: Node3D):
	"""Called when any push_block reaches its goal"""
	print("📦 Push block reached goal! Checking if it's a void challenge...")

	# Get player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("❌ No player found!")
		return

	var player_id = player.get_instance_id()

	# Check if player has an active void challenge
	if not _void_ruin_spawner:
		print("⚠️ VoidRuinSpawner not initialized")
		return

	var challenge_data = _void_ruin_spawner.get_active_challenge_for_player(player_id)
	if challenge_data.is_empty():
		print("ℹ️ Not a void challenge, ignoring")
		return

	# This is a void challenge completion!
	print("🌌 Void challenge completed! Type: ", challenge_data.challenge_type)

	# Prevent multiple dialogs
	if _dialog_showing:
		print("⚠️ Dialog already showing, ignoring duplicate completion")
		return

	# Show completion dialog
	_show_completion_dialog(challenge_data)


func _show_completion_dialog(challenge_data: Dictionary):
	"""Show challenge completion dialog with reward info"""
	_dialog_showing = true

	# Get reward potion name
	var potion_type = challenge_data.challenge_type
	var potion_name = ""
	var potion_id = ""

	match potion_type:
		"combat":
			potion_name = "HP Potion"
			potion_id = "hppotion"
		"parkour":
			potion_name = "Luck Potion"
			potion_id = "luckpotion"
		"puzzle":
			potion_name = "Defense Potion"
			potion_id = "defpotion"
		"gauntlet":
			potion_name = "Attack Potion"
			potion_id = "atkpotion"

	# Get the VoidChallengeCompleteDialog
	var dialog = get_tree().get_first_node_in_group("void_challenge_complete_dialog")
	if not dialog:
		push_error("VoidChallengeCompleteDialog not found!")
		_dialog_showing = false
		return

	# Show dialog and wait for completion
	dialog.show_completion(potion_name, potion_id, challenge_data)

	# Connect to dialog completion signal
	if not dialog.completed.is_connected(_on_dialog_completed):
		dialog.completed.connect(_on_dialog_completed)


func _on_dialog_completed(potion_id: String, challenge_data: Dictionary):
	"""Called when player clicks Continue on completion dialog"""
	_dialog_showing = false

	print("✅ Dialog completed, giving reward and teleporting back...")

	# Give potion reward to player
	_give_potion_reward(potion_id)

	# Teleport player back to origin
	_teleport_player_back(challenge_data)

	# Clear active challenge
	var player = get_tree().get_first_node_in_group("player")
	if player and _void_ruin_spawner:
		_void_ruin_spawner.clear_active_challenge(player.get_instance_id())


func _give_potion_reward(potion_id: String):
	"""Add potion to player's inventory"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var inventory = player.get_node_or_null("Inventory")
	if not inventory:
		push_error("Player inventory not found!")
		return

	# Get Items node to find potion ID
	var items_node = get_node_or_null("/root/Main/Game/Items")
	if not items_node:
		push_error("Items node not found!")
		return

	# Find the potion item by name
	var potion_item_id = -1
	for i in range(100):
		var item = items_node.get_item(i)
		if item and item.base_info.name == potion_id:
			potion_item_id = i
			break

	if potion_item_id == -1:
		push_error("Potion item not found: ", potion_id)
		return

	# Add potion to inventory
	const InventoryItem = preload("res://blocky_game/player/inventory_item.gd")

	# Try to stack with existing potion first
	for i in range(inventory._slots.size()):
		var slot = inventory._slots[i]
		if slot != null and slot.type == InventoryItem.TYPE_ITEM and slot.id == potion_item_id:
			# Found existing stack
			slot.count += 1
			inventory._slot_views[i].get_display().set_item(slot)
			inventory.changed.emit()
			print("✨ Added potion to existing stack (slot %d)" % i)
			return

	# No existing stack, find empty slot
	for i in range(inventory._slots.size()):
		if inventory._slots[i] == null:
			var new_item = InventoryItem.new()
			new_item.type = InventoryItem.TYPE_ITEM
			new_item.id = potion_item_id
			new_item.count = 1
			inventory._slots[i] = new_item
			inventory._slot_views[i].get_display().set_item(new_item)
			inventory.changed.emit()
			print("✨ Added potion to empty slot %d" % i)
			return

	push_warning("Inventory full! Could not add potion reward.")


func _teleport_player_back(challenge_data: Dictionary):
	"""Teleport player back to origin void_teleport_stone"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var origin_pos = challenge_data.origin_pos

	# Disable gravity BEFORE teleporting
	if player.has_method("disable_gravity"):
		player.disable_gravity()
		print("🌊 Gravity disabled for return teleport")

	# Teleport player
	player.global_position = origin_pos + Vector3(0, 1, 0)  # Spawn 1 block above stone

	print("🌀 Teleported player back to origin: ", origin_pos)

	# Re-enable gravity after 2 seconds (chunks loaded)
	await get_tree().create_timer(2.0).timeout

	if player and is_instance_valid(player) and player.has_method("enable_gravity"):
		player.enable_gravity()
		print("🌊 Gravity re-enabled after return")
