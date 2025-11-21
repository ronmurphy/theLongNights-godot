extends "../item.gd"

## Ring of Thorns - Magical ring with orbiting thorn projectiles
## Click to activate/deactivate:
## - Spawns 3 orbiting green thorn projectiles around the player
## - Thorns auto-fire at nearest enemy within 15 blocks every 2 seconds
## - Each thorn deals 8 damage
## - Synergizes with weapon powers (poison, life steal, etc.)
##
## Can be used by: All classes except Tank

const ALLOWED_ROLES = ["wizard", "healer", "rogue", "elf"]

## Check if a role can equip this ring
static func can_equip(role: String) -> bool:
	return role in ALLOWED_ROLES


## Click to toggle thorns on/off
func use(trans: Transform3D, inv_item_or_count = 1):
	# Get the player (owner of the item)
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Toggle the thorns
	if player.has_method("toggle_ring_of_thorns"):
		player.toggle_ring_of_thorns()
