extends "../item.gd"

# Wind Walker Boots - passive mobility item that enables aerial gliding
# When equipped in hotbar, provides slow fall and limited steering while airborne
# Synergizes with [Glide] power for enhanced aerial control

const BASE_FALL_SPEED = -4.0  # Slow fall speed cap (Y velocity per second)
const BASE_TURN_SPEED = 0.3   # Limited turn speed (30% of normal)
const SYNERGY_FALL_SPEED = -3.0  # Enhanced fall speed cap with [Glide] power
const SYNERGY_TURN_SPEED = 1.0   # Full aerial control (100%) with [Glide] power

# This is a passive item with automatic effects when equipped
# The character controller will detect these boots and modify fall behavior
# Enhanced effects activate when combined with [Glide] power:
#   Boots alone: -4.0 fall cap, 30% steering
#   Glide alone: -4.0 fall cap, 30% steering
#   Boots + Glide: -3.0 fall cap, 100% steering (SYNERGY!)
