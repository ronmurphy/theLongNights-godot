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

func use(trans: Transform3D, stack_count: int = 1):
	# Portal Compass usage is handled by avatar_interaction.gd
	# when clicking on teleport stones, not through normal item use
	pass
