extends "../item.gd"

## Blade of Pursuit - Magical sword that chains attacks between enemies
## Click to launch:
## - Sword flies from player to nearest enemy (15 damage)
## - Chains to up to 5 enemies in sequence
## - Returns to player when done
## - 3 second cooldown between uses
##
## Can be used by: Wizard, Rogue, Elf

const ALLOWED_ROLES = ["wizard", "rogue", "elf"]
const FlyingBlade = preload("../../projectiles/flying_blade.gd")

## Check if a role can equip this blade
static func can_equip(role: String) -> bool:
	return role in ALLOWED_ROLES


## Click to launch the blade at enemies
func use(trans: Transform3D, inv_item_or_count = 1):
	print("⚔️ Blade of Pursuit use() called")

	# Get the player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("⚔️ ERROR: Player not found!")
		return

	# Check cooldown
	if player.has_method("is_blade_of_pursuit_ready") and not player.is_blade_of_pursuit_ready():
		print("⚔️ Blade of Pursuit on cooldown!")
		return

	# Launch the blade
	if player.has_method("launch_blade_of_pursuit"):
		player.launch_blade_of_pursuit(trans.origin)
	else:
		print("⚔️ ERROR: Player missing launch_blade_of_pursuit method!")
