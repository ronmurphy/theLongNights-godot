extends "../item.gd"

## HP Potion - Permanently increases max HP by 10
## Right-click to use - shows dialog to choose Player or Companion

const SERVER_PEER_ID = 1
const InventoryItem = preload("../../player/inventory_item.gd")
const BONUS_AMOUNT = 10


func use(trans: Transform3D, inv_item_or_count = 1):
	"""Use the HP potion - show choice dialog"""
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
		push_error("PotionChoiceDialog not found! Cannot use HP potion.")
		return

	# Check if dialog is already visible
	if dialog.visible:
		print("Another potion is being used. Please wait.")
		return

	# Connect to the choice signal
	if not dialog.choice_made.is_connected(_on_choice_made):
		dialog.choice_made.connect(_on_choice_made.bind(inv_item_or_count))

	# Show the dialog
	dialog.show_potion_choice("hp", "Max HP", BONUS_AMOUNT)


func _on_choice_made(target: String, inv_item_or_count):
	"""Handle the player's choice"""
	# Get the dialog to disconnect
	var dialog = get_tree().get_first_node_in_group("potion_choice_dialog")
	if dialog and dialog.choice_made.is_connected(_on_choice_made):
		dialog.choice_made.disconnect(_on_choice_made)

	# Handle choice
	if target == "cancel":
		print("HP Potion use cancelled.")
		return

	# Apply the bonus
	if target == "player":
		PlayerData.bonus_max_hp += BONUS_AMOUNT
		PlayerData.max_hp += BONUS_AMOUNT  # Update current max_hp too
		PlayerData.save_to_file()
		print("💪 %s gained +%d Max HP! (Total bonus: +%d)" % [
			PlayerData.player_name if PlayerData.player_name != "" else "Player",
			BONUS_AMOUNT,
			PlayerData.bonus_max_hp
		])

		# Update the player entity's max_hp property
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.max_hp = PlayerData.max_hp

			# Refresh PartyUI to show new max HP
			var party_ui = get_tree().get_first_node_in_group("party_ui")
			if party_ui:
				party_ui._on_player_hp_changed(player.current_hp, player.max_hp)
	elif target == "companion":
		CompanionManager.companion_bonus_max_hp += BONUS_AMOUNT
		CompanionManager.save_to_file()

		# Get companion and update its max_hp
		var companions = get_tree().get_nodes_in_group("companions")
		var companion_name = "Companion"
		var companion_current_hp = 0
		var companion_max_hp = CompanionManager.get_companion_max_hp()

		if companions.size() > 0:
			var companion = companions[0]
			companion_name = companion.entity_name
			companion_current_hp = companion.current_hp

			# Update the companion entity's max_hp property
			companion.max_hp = companion_max_hp

		print("💪 %s gained +%d Max HP! (Total bonus: +%d)" % [
			companion_name,
			BONUS_AMOUNT,
			CompanionManager.companion_bonus_max_hp
		])

		# Refresh PartyUI to show new max HP
		var party_ui = get_tree().get_first_node_in_group("party_ui")
		if party_ui:
			party_ui.update_companion_hp(companion_current_hp, companion_max_hp)

	# Decrement potion count
	if typeof(inv_item_or_count) == TYPE_OBJECT:
		inv_item_or_count.count -= 1


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, inv_item_or_count = 1):
	_use(trans, inv_item_or_count)
