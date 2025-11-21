extends "../item.gd"

## Crusader Shield - Advanced defensive accessory
## Defense: +30
## Can be used by: Tank, Healer only

const DEFENSE_BONUS = 30
const ALLOWED_ROLES = ["tank", "healer"]

## Check if a role can equip this shield
static func can_equip(role: String) -> bool:
	return role in ALLOWED_ROLES

## Get the defense bonus this shield provides
func get_defense_bonus() -> int:
	return DEFENSE_BONUS
