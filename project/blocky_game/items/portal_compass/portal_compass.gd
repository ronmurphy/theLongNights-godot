extends "../item.gd"

# Portal Compass - Used to navigate between visited ruins
# This is a consumable item that decrements count on each use
#
# Usage: Hold in hotbar and click on a teleport stone
# Opens navigation modal showing all visited ruins
# Consumes 1 compass charge per teleport

# NOTE: The actual usage behavior is handled in avatar_interaction.gd
# This script just defines the item properties
# The item is marked as consumable in item_db.gd

func use(trans: Transform3D, inv_item_or_count = 1):
	var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count
	# Portal Compass usage is handled by avatar_interaction.gd
	# when clicking on teleport stones, not through normal item use
	pass
