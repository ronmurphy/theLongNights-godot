extends "../item.gd"

## Luck Potion - Permanently increases luck by 2
## Right-click to use - shows dialog to choose Player or Companion
## Luck affects hit/dodge chance in combat (hard capped at +5 effective in combat)

const SERVER_PEER_ID = 1
const InventoryItem = preload("../../player/inventory_item.gd")
const BONUS_AMOUNT = 2


func use(trans: Transform3D, inv_item_or_count = 1):
	"""Use the Luck potion - show choice dialog"""
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_use", trans, inv_item_or_count)
	else:
		_use(trans, inv_item_or_count)


func _use(trans: Transform3D, inv_item_or_count):
	"""Show potion choice dialog and wait for response"""
	# Get the PotionChoiceDialog
	var dialog = get_tree().get_first_node_in_group("potion_choice_dialog")
	if not dialog:
		push_error("PotionChoiceDialog not found! Cannot use Luck potion.")
		return

	# Check if dialog is already visible
	if dialog.visible:
		print("Another potion is being used. Please wait.")
		return

	# Connect to the choice signal
	if not dialog.choice_made.is_connected(_on_choice_made):
		dialog.choice_made.connect(_on_choice_made.bind(inv_item_or_count))

	# Show the dialog (dialog handles cap logic and UI)
	dialog.show_potion_choice("luck", "Luck", BONUS_AMOUNT)


func _on_choice_made(target: String, inv_item_or_count):
	"""Handle the player's choice"""
	# Get the dialog to disconnect
	var dialog = get_tree().get_first_node_in_group("potion_choice_dialog")
	if dialog and dialog.choice_made.is_connected(_on_choice_made):
		dialog.choice_made.disconnect(_on_choice_made)

	# Handle choice
	if target == "cancel":
		print("Luck Potion use cancelled.")
		return

	# Apply the bonus (can go above cap, but combat will clamp to 5)
	if target == "player":
		PlayerData.bonus_luck += BONUS_AMOUNT
		PlayerData.luck += BONUS_AMOUNT  # Update current luck too
		PlayerData.save_to_file()
		print("🍀 %s gained +%d Luck! (Total bonus: +%d)" % [
			PlayerData.player_name if PlayerData.player_name != "" else "Player",
			BONUS_AMOUNT,
			PlayerData.bonus_luck
		])
	elif target == "companion":
		CompanionManager.companion_bonus_luck += BONUS_AMOUNT
		CompanionManager.save_to_file()

		# Get companion name for message
		var companions = get_tree().get_nodes_in_group("companions")
		var companion_name = "Companion"
		if companions.size() > 0:
			companion_name = companions[0].entity_name

		print("🍀 %s gained +%d Luck! (Total bonus: +%d)" % [
			companion_name,
			BONUS_AMOUNT,
			CompanionManager.companion_bonus_luck
		])

	# Decrement potion count
	if typeof(inv_item_or_count) == TYPE_OBJECT:
		inv_item_or_count.count -= 1


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, inv_item_or_count = 1):
	_use(trans, inv_item_or_count)
