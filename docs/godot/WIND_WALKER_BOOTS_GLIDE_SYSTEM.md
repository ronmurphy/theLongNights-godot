# Wind Walker Boots & Glide System Design

**Date Created:** November 10, 2025  
**Status:** In Development  
**Purpose:** Repurpose climbing_claws into Wind Walker Boots with glide mechanics

---

## Overview

The Wind Walker Boots are a mobility-focused equip item that provides aerial control. They work standalone but achieve full potential when combined with the [Glide] Power, creating the game's first item-power synergy system.

---

## Design Goals

1. **Repurpose unused climbing_claws** - Give them meaningful gameplay value
2. **Enable sky ruin traversal** - Support grapple-pogo aerial movement
3. **Create power synergy example** - Showcase how items + powers interact
4. **Provide progression path** - Useful at discovery, powerful when mastered
5. **Support Undervoid exploration** - Work in vertical void environments

---

## Item: Wind Walker Boots

### Base Properties (No Power Required)

**When Equipped:**
- **Slow Fall Effect:** Reduces fall speed to Y -4 per second (vs normal falling)
- **Limited Steering:** 30% turn speed while airborne
- **Always Active:** Works automatically when falling
- **No Stamina Cost:** Passive effect

**Use Case:** Safe exploration of sky ruins, emergency fall protection, basic aerial mobility

### Visual Design
- Light, flowing boots (not heavy climbing gear)
- Feather or wind motifs
- Sky blue/white with cyan accents
- Subtle air particle trail when active

---

## Power: [Glide] (Equip Slot)

### Base Functionality (Any Item)

**When Activated (Hold Power Button):**
- **Glide Descent:** Y -4 per second (same as basic boots)
- **Turn Speed:** 30% (limited control)
- **Manual Activation:** Must hold button while airborne
- **Universal:** Works on any equip item (staff, bow, sword, etc.)

**Use Case:** Emergency saves, basic aerial movement without boots, combat mobility

---

## Synergy: Boots + Power

### Combined Effect

**Wind Walker Boots Equipped + [Glide] Power Active:**
- **Enhanced Descent:** Y -2 per second (true gliding, not falling)
- **Full Steering:** 100% turn speed (complete aerial control)
- **Smooth Movement:** Fluid transitions, responsive controls
- **Wind Particles:** Enhanced visual effects

**Use Case:** Intended aerial traversal method, sky ruin hopping, Undervoid navigation

---

## Progression Paths

### Path A: Boots First
1. **Early Game:** Normal falling (dangerous at height)
2. **Find Boots:** Slow fall unlocked (safe sky ruin exploration)
3. **Unlock Power:** Full glide mastery (complete aerial freedom)

### Path B: Power First
1. **Early Game:** Normal falling
2. **Unlock Power:** Basic glide (functional but limited)
3. **Find Boots:** Synergy unlocked (optimal performance)

Both paths work, encouraging different playstyles and rewarding discovery.

---

## Technical Implementation

### Phase 1: Rename Item
- Rename `climbing_claws` → `wind_walker_boots`
- Reuse existing item ID (no new ID needed)
- Update internal name, tooltip, description
- Copy/rename item folder structure

### Phase 2: Base Slow Fall Mechanic
- Detect when Wind Walker Boots equipped
- Override fall velocity to Y -4 per second
- Add basic turn control (30% speed)
- No power activation required

### Phase 3: Create [Glide] Power
- New equip power in Powers.gd
- Hold-to-activate (not auto-trigger)
- Works on any equipped item
- Base stats: Y -4 descent, 30% turn

### Phase 4: Synergy Detection
- Check: `is_wind_walker_boots_equipped() AND is_glide_power_active()`
- If true: Apply enhanced stats (Y -2, 100% turn)
- If false: Apply base stats

### Phase 5: Visual/Audio Polish
- Particle effects (basic vs enhanced)
- Wind whoosh sounds
- Optional: Camera tilt during gliding
- Tutorial hints

---

## Stat Summary Table

| Scenario | Descent Speed | Turn Speed | Notes |
|----------|--------------|------------|-------|
| **No Boots, No Power** | Normal fall | N/A | Default behavior |
| **Boots Only** | Y -4/sec | 30% | Safe but slow |
| **Power Only (any item)** | Y -4/sec | 30% | Functional mobility |
| **Boots + Power** | Y -2/sec | 100% | Optimal gliding |

---

## Gameplay Applications

### Sky Ruins
- **Grapple-Pogo Launch:** Use grappling hook at feet for high launch
- **Apex Glide:** Activate glide at peak height
- **Island Hopping:** Navigate between multiple visible ruins
- **Safe Landing:** Controlled descent onto landing platforms

### Undervoid
- **Void Island Navigation:** Cross gaps between floating structures
- **Enemy Evasion:** Launch off cliffs to escape combat
- **Purple Beacon Approach:** Glide toward distant beacon lights
- **Vertical Exploration:** Access multiple elevation levels

### Combat
- **Aerial Advantage:** Rain attacks from above
- **Escape Tool:** Disengage from dangerous encounters
- **Positioning:** Flank enemies using vertical space
- **Item Choice:** Glide power on staff/bow for combat-mobility hybrid

---

## Balance Considerations

### Why No Fall Damage?
- Vertical traversal is core to gameplay
- Punishing aerial movement feels bad
- Time/distance lost is sufficient consequence
- Encourages experimentation and mastery

### Power Slot Trade-off
- Using [Glide] means NOT using other powers
- Creates meaningful choice: mobility vs combat/utility
- Boots synergy makes glide power more attractive
- Still competitive without boots (basic functionality)

### Discovery Order Flexibility
- Either item can be found first
- Both useful independently
- No "wrong" progression order
- Rewards exploration

---

## Future Expansion Ideas

### Potential Upgrades (Optional)
- **Tier 2:** Increased glide duration (stamina-based?)
- **Tier 3:** Air dash ability (horizontal burst)
- **Tier 4:** Updraft surfing (gain altitude in wind)

### Weather Integration
- Strong winds affect glide direction
- Bloodmoon storms create turbulence
- Sky ruin updrafts boost altitude

### Achievement/Challenge
- "Sky Walker" - Glide 1000 blocks total
- "Island Hopper" - Visit 5 ruins in one flight
- "Void Diver" - Glide from surface to Undervoid

---

## Files to Modify

### Phase 1 (Rename Item)
- `blocky_game/items/climbing_claws/` → `wind_walker_boots/`
- `climbing_claws.gd` → `wind_walker_boots.gd`
- Item sprite, model, tooltip text
- Inventory references

### Phase 2 (Base Mechanic)
- `blocky_game/player/character_controller.gd` - Fall velocity override
- `wind_walker_boots.gd` - Equipment detection

### Phase 3 (Glide Power)
- `long_nights/Powers.gd` - Add new glide power
- Power activation/deactivation logic
- Hold-button detection

### Phase 4 (Synergy)
- `character_controller.gd` - Enhanced stats when both active
- Visual effect switching

---

## Testing Checklist

- [ ] Boots slow fall works without power
- [ ] Glide power works on other items
- [ ] Synergy activates with boots + power
- [ ] Stats match specification (Y -4 vs Y -2)
- [ ] Turn speed differences feel noticeable
- [ ] Works in sky ruins
- [ ] Works in Undervoid
- [ ] Grapple-pogo integration smooth
- [ ] No conflicts with other powers
- [ ] Save/load preserves equipment state

---

## Notes

- This creates the **first item-power synergy** in the game
- Template for future synergies (e.g., Fire Staff + [Flame] power?)
- Discovered through organic playtesting (grapple-pogo technique)
- Player practiced movement for a month before design formalized
- Fits gothic/supernatural theme (wind magic, aerial freedom)
