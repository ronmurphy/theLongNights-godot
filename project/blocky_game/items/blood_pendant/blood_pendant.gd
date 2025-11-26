extends "../item.gd"

## Blood Pendant - Crimson amulet that amplifies damage during blood moons
## Passive Equipment (Accessory Slot):
## - Equip in player or companion accessory slot
## - +50% weapon damage during blood moons only
## - Can be enhanced with skyshard powers for additional effects
##
## Can be used by: All classes

## Check if a role can equip this pendant
static func can_equip(role: String) -> bool:
	return true  # All classes can equip


## Passive item - no use() function needed
## Damage bonus is applied automatically when equipped during blood moon
