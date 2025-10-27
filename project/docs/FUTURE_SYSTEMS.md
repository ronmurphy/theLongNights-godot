# Future Systems for The Long Nights

This document tracks planned features and systems that are not yet implemented but should be remembered for future development.

## Companion System
- **Status**: Not implemented
- **Description**: NPCs that follow and help the player
- **Features**:
  - Companions have HP and combat abilities
  - Displayed in HUD under player HP (vertical list)
  - Each companion shows: Profile picture, HP bar, Role indicator
  - Companions can take damage and be healed
  - Companions benefit from auto-regen (1 HP per 3 minutes)

## Role System
- **Status**: Not implemented
- **Description**: Class/role assignment for player and companions
- **Roles**:
  - Tank - High defense, draws enemy aggro
  - Healer - Can heal allies
  - Magician - Ranged magical attacks
  - (More roles to be designed)
- **Display**: Role icon shown in HUD next to HP bar
- **Related**: Companions will each have a role, player may choose role via initial quiz

## Initial Game Quiz
- **Status**: Not implemented
- **Description**: Quiz system at game start that determines player role/stats
- **Purpose**: Personalize player experience based on answers
- **Note**: User will explain this system in detail later

## Healing & Food System
- **Status**: Partially planned
- **Features**:
  - Crop growing system
  - Crops can be harvested and turned into healing foods
  - Healing foods restore player/companion HP
  - Auto-regeneration: 1 HP per 3 real-time minutes for all entities (player, companions, enemies)

## Entity Object Pool
- **Status**: Not implemented
- **Purpose**: Optimize entity spawning/despawning
- **Features**:
  - Entities that go out of range return to pool instead of being destroyed
  - When entity returns to pool, HP is fully restored
  - Prevents memory leaks and improves performance
  - Enemies despawn if they get too far from player

## Combat Refinements
- **Status**: Partially implemented
- **Current**: Basic damage system with defense stat
- **Planned**:
  - d20-style "roll to hit" system
  - If attack roll fails, no damage is dealt (for all entities)
  - Applies to: Player, Enemies, Companions

## Other Notes
- Health displayed as flat numbers or color-changing bar (not hearts system)
- HP bar changes color based on percentage remaining
- Game Over screen with respawn option (spawns player at spawn point, keeps world state)
