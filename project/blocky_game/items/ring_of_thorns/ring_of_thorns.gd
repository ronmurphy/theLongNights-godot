extends "../item.gd"

## Ring of Thorns - Magical ring with orbiting thorn projectiles
## When equipped as active item:
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
