extends "../item.gd"

# Climbing claws - passive item that allows vertical climbing on any block
# When equipped in hotbar, player can climb by holding forward against a wall

const CLIMB_SPEED = 3.0  # Speed of climbing (blocks per second)

# This is a passive item, so it doesn't need a use() function
# The character controller will check if this item is equipped
# and modify movement behavior accordingly
