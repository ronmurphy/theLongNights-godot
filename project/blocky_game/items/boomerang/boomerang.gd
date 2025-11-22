extends "../item.gd"

## Boomerang - Curved throwing weapon that returns to player
## Click to launch:
## - Flies in curved arc toward raycast target (max 35 blocks)
## - Deals 1 damage per frame (60 DPS) while passing through enemies
## - Returns to player automatically (auto-catch)
## - Bounces back immediately if hits terrain
## - No cooldown (limited only by throw/return time)
##
## Can be used by: Anyone

const BoomerangProjectile = preload("../../projectiles/boomerang.gd")

## Check if a role can equip this boomerang
static func can_equip(role: String) -> bool:
	return true  # Anyone can use boomerang


## Click to throw the boomerang at raycast target
func use(trans: Transform3D, inv_item_or_count = 1):
	print("🪃 Boomerang use() called")

	# Get the player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("🪃 ERROR: Player not found!")
		return

	# Get throw position and direction from trans (player's interaction transform)
	var origin = trans.origin
	var direction = -trans.basis.z.normalized()
	var max_range = 35.0

	# Calculate target position (where player is looking)
	var target_pos = origin + (direction * max_range)

	# Launch the boomerang toward where player is looking
	if player.has_method("launch_boomerang"):
		player.launch_boomerang(origin, target_pos)
		print("🪃 Boomerang thrown toward: ", target_pos)
	else:
		print("🪃 ERROR: Player missing launch_boomerang method!")
