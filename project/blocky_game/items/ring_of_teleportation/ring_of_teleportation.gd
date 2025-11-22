extends "../item.gd"

## Ring of Teleportation - Magical ring that teleports the player
## Click to teleport:
## - Raycast from camera to find target position
## - Teleports player to target location (rendering distance range)
## - 30 second real-time cooldown after use
##
## Can be used by: All classes

## Click to teleport to targeted location
func use(trans: Transform3D, inv_item_or_count = 1):
	# Get the player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Check cooldown
	if player.has_method("is_teleport_ring_ready") and not player.is_teleport_ring_ready():
		# Get remaining cooldown time
		if player.has_method("get_teleport_ring_cooldown"):
			var remaining = player.get_teleport_ring_cooldown()
			print("🔮 Ring of Teleportation on cooldown! (%d seconds remaining)" % int(remaining))
		else:
			print("🔮 Ring of Teleportation on cooldown!")
		return

	# Teleport the player
	if player.has_method("teleport_to_target"):
		player.teleport_to_target(trans)
