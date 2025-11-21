extends "../item.gd"

## Wood Shield - Basic defensive accessory
## Defense: +10
## Can be used by: Tank, Healer, Rogue, Wizard (all roles)

const DEFENSE_BONUS = 10
const ALLOWED_ROLES = ["tank", "healer", "rogue", "wizard"]

## Check if a role can equip this shield
static func can_equip(role: String) -> bool:
	return role in ALLOWED_ROLES

## Get the defense bonus this shield provides
func get_defense_bonus() -> int:
	return DEFENSE_BONUS
