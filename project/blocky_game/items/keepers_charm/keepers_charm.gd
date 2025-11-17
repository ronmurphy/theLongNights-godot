extends "../item.gd"

## Keeper's Charm - Emergency teleport to home base
## Given by Zara (the Ruinkeeper) on first meeting
## Right-click when equipped to teleport to your home base

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

	# Teleport to home base
	var teleport_pos = HomeBaseManager.home_base_position + Vector3(0, 2, 0)
	player.global_position = teleport_pos
	print("✨ Keeper's Charm activated!")
	print("🏠 Teleported to home base - You are safe now")
