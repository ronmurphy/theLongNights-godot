extends "../item.gd"

## Keeper's Charm - Emergency teleport to home base
## Given by Zara (the Ruinkeeper) on first meeting
## Left-click to teleport to your home base when in danger (with confirmation)

func use(_trans: Transform3D, _inv_item_or_count = 1):
	# Get player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("⚠️ Keeper's Charm: Player not found!")
		return

	# Check if home base is set
	if not HomeBaseManager.has_home_base:
		print("⚠️ Keeper's Charm: No home base set!")
		print("💡 Use 'homebase set' command to establish a home base first")
		return

	# Show confirmation dialog to prevent accidental teleportation
	var dialog = ConfirmationDialog.new()
	dialog.title = "Use Keeper's Charm?"
	dialog.dialog_text = "Do you want to use the Keeper's Charm to return to home base?\n\n⚠️ This will teleport you immediately!"
	dialog.ok_button_text = "Yes, Return Home"
	dialog.cancel_button_text = "No, Stay Here"

	# Make dialog exclusive (blocks all input while open)
	dialog.exclusive = true

	# Store current mouse mode
	var previous_mouse_mode = Input.mouse_mode

	# Show mouse cursor for dialog
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Connect confirmed signal to teleport
	dialog.confirmed.connect(func():
		var teleport_pos = HomeBaseManager.home_base_position + Vector3(0, 2, 0)
		player.global_position = teleport_pos
		print("✨ Keeper's Charm activated!")
		print("🏠 Teleported to home base - You are safe now")
		# Restore mouse mode before closing
		Input.mouse_mode = previous_mouse_mode
		dialog.queue_free()
	)

	# Clean up dialog on cancel
	dialog.canceled.connect(func():
		# Restore mouse mode before closing
		Input.mouse_mode = previous_mouse_mode
		dialog.queue_free()
	)

	# Also handle close button (X)
	dialog.close_requested.connect(func():
		# Restore mouse mode before closing
		Input.mouse_mode = previous_mouse_mode
		dialog.queue_free()
	)

	# Add to game tree and show
	var game = get_tree().root.get_node("Main/Game")
	if game:
		game.add_child(dialog)
		dialog.popup_centered()
	else:
		push_error("Could not find Game node for confirmation dialog")
