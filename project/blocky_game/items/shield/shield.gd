extends "../item.gd"

## Shield - Standard defensive accessory
## Defense: +20
## Can be used by: Tank, Healer, Rogue

const DEFENSE_BONUS = 20
const ALLOWED_ROLES = ["tank", "healer", "rogue"]

## Check if a role can equip this shield
static func can_equip(role: String) -> bool:
	return role in ALLOWED_ROLES

## Get the defense bonus this shield provides
func get_defense_bonus() -> int:
	return DEFENSE_BONUS
