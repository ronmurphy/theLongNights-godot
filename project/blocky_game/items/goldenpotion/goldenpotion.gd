extends "../item.gd"

## Golden Potion - Choose a special permanent blessing
## Right-click to use - shows dialog to choose Player or Companion, then blessing type

const SERVER_PEER_ID = 1
const InventoryItem = preload("../../player/inventory_item.gd")


func use(trans: Transform3D, inv_item_or_count = 1):
	"""Use the Golden Potion - show target choice dialog first"""
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_use", trans, inv_item_or_count)
	else:
		_use(trans, inv_item_or_count)


func _use(trans: Transform3D, inv_item_or_count):
	"""Show target choice dialog (Player or Companion)"""
	# Get the PotionChoiceDialog for target selection
	var dialog = get_tree().get_first_node_in_group("potion_choice_dialog")
	if not dialog:
		push_error("PotionChoiceDialog not found! Cannot use Golden Potion.")
		return

	# Check if dialog is already visible
	if dialog.visible:
		print("Another potion is being used. Please wait.")
		return

	# Connect to the choice signal
	if not dialog.choice_made.is_connected(_on_target_chosen):
		dialog.choice_made.connect(_on_target_chosen.bind(inv_item_or_count))

	# Show target selection dialog
	dialog.show_potion_choice("golden", "Special Blessing", 1)


func _on_target_chosen(target: String, inv_item_or_count):
	"""Handle target choice, then show blessing selection"""
	# Get the dialog to disconnect
	var dialog = get_tree().get_first_node_in_group("potion_choice_dialog")
	if dialog and dialog.choice_made.is_connected(_on_target_chosen):
		dialog.choice_made.disconnect(_on_target_chosen)

	# Handle cancellation
	if target == "cancel":
		print("Golden Potion use cancelled.")
		return

	# Show blessing choice dialog
	var blessing_dialog = get_tree().get_first_node_in_group("golden_potion_dialog")
	if not blessing_dialog:
		push_error("GoldenPotionChoiceDialog not found! Cannot choose blessing.")
		return

	# Check if dialog is already visible
	if blessing_dialog.visible:
		print("Blessing dialog already open. Please wait.")
		return

	# Connect to blessing choice signal
	if not blessing_dialog.blessing_chosen.is_connected(_on_blessing_chosen):
		blessing_dialog.blessing_chosen.connect(_on_blessing_chosen.bind(target, inv_item_or_count))

	# Show blessing selection
	blessing_dialog.show_blessing_choice(target)


func _on_blessing_chosen(blessing: String, target: String, inv_item_or_count):
	"""Apply the chosen blessing to the target"""
	# Disconnect signal
	var blessing_dialog = get_tree().get_first_node_in_group("golden_potion_dialog")
	if blessing_dialog and blessing_dialog.blessing_chosen.is_connected(_on_blessing_chosen):
		blessing_dialog.blessing_chosen.disconnect(_on_blessing_chosen)

	# Handle cancellation
	if blessing == "cancel":
		print("Golden Potion blessing cancelled.")
		return

	# Apply blessing based on target
	if target == "player":
		_apply_player_blessing(blessing)
	elif target == "companion":
		_apply_companion_blessing(blessing)

	# Decrement potion count
	if typeof(inv_item_or_count) == TYPE_OBJECT:
		inv_item_or_count.count -= 1


func _apply_player_blessing(blessing: String):
	"""Apply blessing to player"""
	var player_name = PlayerData.player_name if PlayerData.player_name != "" else "Player"

	match blessing:
		"speed":
			PlayerData.bonus_speed_multiplier += 0.15
			PlayerData.save_to_file()
			print("✨ %s gained Speed Blessing! (+15%% movement speed)" % player_name)

		"regen":
			PlayerData.bonus_regen_multiplier = 3.0
			PlayerData.save_to_file()
			print("✨ %s gained Regen Blessing! (3x HP regeneration)" % player_name)

		"mana":
			PlayerData.bonus_max_mana += 20
			PlayerData.max_mana += 20
			PlayerData.save_to_file()
			print("✨ %s gained Mana Blessing! (+20 max mana)" % player_name)

		"glide":
			PlayerData.permanent_glide = true
			PlayerData.save_to_file()
			print("✨ %s gained Glide Blessing! (Permanent glide ability)" % player_name)


func _apply_companion_blessing(blessing: String):
	"""Apply blessing to companion"""
	var companion_name = "Companion"
	var companions = get_tree().get_nodes_in_group("companions")
	if companions.size() > 0:
		companion_name = companions[0].entity_name

	match blessing:
		"speed":
			CompanionManager.companion_bonus_speed_multiplier += 0.15
			CompanionManager.save_to_file()
			print("✨ %s gained Speed Blessing! (+15%% movement speed)" % companion_name)

		"regen":
			CompanionManager.companion_bonus_regen_multiplier = 3.0
			CompanionManager.save_to_file()
			print("✨ %s gained Regen Blessing! (3x HP regeneration)" % companion_name)

		"mana":
			CompanionManager.companion_bonus_max_mana += 20
			CompanionManager.save_to_file()
			print("✨ %s gained Mana Blessing! (+20 max mana)" % companion_name)

		"glide":
			CompanionManager.companion_permanent_glide = true
			CompanionManager.save_to_file()
			print("✨ %s gained Glide Blessing! (Permanent glide ability)" % companion_name)


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, inv_item_or_count = 1):
	_use(trans, inv_item_or_count)
