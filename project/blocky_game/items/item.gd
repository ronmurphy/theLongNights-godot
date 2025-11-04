extends Node


class BaseInfo:
	var id := 0
	var name := ""
	var sprite : Texture


var base_info := BaseInfo.new()


func use(_trans: Transform3D, _inv_item_or_count = 1):
	# _inv_item_or_count can be either:
	# - InventoryItem object (for skyshard power support)
	# - int (backward compatibility for old weapons)
	pass


# Returns the mining power for this item
# 0 = cannot mine blocks (special items like torch, grapple)
# >0 = can mine blocks, higher = faster mining
func get_mining_power() -> int:
	return 0  # Default: cannot mine

