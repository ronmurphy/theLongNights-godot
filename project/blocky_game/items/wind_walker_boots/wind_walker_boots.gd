extends "../item.gd"

# Wind Walker Boots - passive mobility item that enables aerial gliding
# When equipped in hotbar, provides slow fall and limited steering while airborne
# Synergizes with [Glide] power for enhanced aerial control

const BASE_FALL_SPEED = -4.0  # Slow fall speed (Y velocity per second)
const BASE_TURN_SPEED = 0.3   # Limited turn speed (30% of normal)

# This is a passive item with automatic effects when equipped
# The character controller will detect these boots and modify fall behavior
# Enhanced effects activate when combined with [Glide] power
