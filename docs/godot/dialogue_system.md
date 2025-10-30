# Dialogue System - Implementation Complete ✅

**Status:** FULLY IMPLEMENTED AND WORKING
**Date:** October 30, 2025
**Implementation Time:** ~4 hours

---

## Overview

Visual novel-style dialogue system for companion conversations, NPC interactions, tutorials, and story progression. Features character portraits with mood changes, variable substitution, manual/click advancement, and progress tracking.

---

## Features Implemented

### Core Features ✅
- ✅ Character portraits (left = companion/NPC, right = player)
- ✅ Sequential message display
- ✅ Manual advance (X key + left-click anywhere)
- ✅ Mood/expression changes during dialogue
- ✅ Variable substitution ({{player_name}}, {{companion_name}}, etc.)
- ✅ Progress tracking (one-time dialogues with `"once": true`)
- ✅ Save/load dialogue history
- ✅ Character name system (player + companion)
- ✅ Quiz integration (player name input after character creation)

### Input System ✅
- **X Key** - Advance dialogue
- **Left Mouse Click** - Advance dialogue (click anywhere on screen)
- **No auto-advance timer** - Players can take breaks without missing content
- **Background blocks game interaction** - Can't place blocks during dialogue

---

## Character Name System

### Player Names
When the quiz completes, players can input their custom name or accept a default based on race/gender:

| Race   | Male      | Female   |
|--------|-----------|----------|
| Dwarf  | Thrain    | Katrin   |
| Elf    | Aelindor  | Lyralei  |
| Goblin | Grix      | Snick    |
| Human  | Marcus    | Elena    |

**Quiz Flow:**
1. Answer 3 personality questions (role, race, gender)
2. Name input screen appears with default name pre-filled
3. Player can type custom name or press Enter to accept default
4. Name is saved and used throughout game

### Companion Names
Companions get complementary names based on their race/gender (opposite from player):

| Race   | Male      | Female   |
|--------|-----------|----------|
| Dwarf  | Borin     | Helga    |
| Elf    | Faelar    | Sylvara  |
| Goblin | Zikk      | Nixie    |
| Human  | Thomas    | Sarah    |

**Companion Selection Logic:**
- Player Tank → Companion Healer
- Player Wizard → Companion Tank
- Player Healer → Companion Rogue
- Player Rogue → Companion Wizard

Companion race is always different from player for diversity.

---

## System Architecture

### Files Structure
```
project/
├── long_nights/
│   ├── DialogueManager.gd          # Singleton - loads JSON, tracks progress
│   ├── PlayerData.gd                # Singleton - player character data + name
│   ├── CompanionManager.gd          # Singleton - companion data + name
│   └── CharacterQuiz.gd             # Character creation with name input
├── blocky_game/
│   ├── gui/dialogue/
│   │   ├── DialogueUI.tscn          # UI scene
│   │   └── DialogueUI.gd            # UI controller
│   └── main.gd                      # Quiz → game integration
└── assets/
    └── data/dialogues/
        └── companion_intro.json     # Example dialogue data
```

### Autoload Singletons
Registered in `project.godot`:
- **DialogueManager** - Manages dialogue system
- **PlayerData** - Stores player stats + name
- **CompanionManager** - Stores companion stats + name

---

## DialogueManager.gd API

### Core Functions
```gdscript
# Load dialogue data from JSON file
func load_dialogue_file(path: String) -> bool

# Trigger a dialogue by ID
func trigger_dialogue(dialogue_id: String) -> bool

# Check if dialogue has been seen
func has_seen_dialogue(dialogue_id: String) -> bool

# Mark dialogue as seen (auto-called when triggered)
func mark_dialogue_seen(dialogue_id: String) -> void

# Reset all progress (for new game)
func reset_progress() -> void
```

### Signals
```gdscript
signal dialogue_started(dialogue_id: String)
signal dialogue_ended(dialogue_id: String)
```

### Variable Substitution
Text in JSON can use these variables:
- `{{player_name}}` → "Marcus" (or custom name)
- `{{companion_name}}` → "Sylvara"
- `{{companion_race}}` → "elf"
- `{{player_race}}` → "human"

---

## JSON Dialogue Format

### Basic Structure
```json
{
  "dialogues": {
    "dialogue_id": {
      "id": "dialogue_id",
      "once": true,
      "messages": [
        {
          "speaker": "companion",
          "mood": "normal",
          "text": "Hey {{player_name}}! I'm {{companion_name}}.",
          "delay": 0
        },
        {
          "speaker": "companion",
          "mood": "ready",
          "text": "Let's explore this world together!",
          "delay": 0
        }
      ]
    }
  }
}
```

### Message Fields
| Field    | Type   | Description                                          |
|----------|--------|------------------------------------------------------|
| speaker  | string | "companion", "player", "narrator", or custom NPC ID  |
| mood     | string | Portrait state (see Moods section)                   |
| text     | string | Dialogue text (supports {{variables}})               |
| delay    | int    | **DEPRECATED** - No longer used (manual advance only)|

**Note:** The `delay` field is kept for backwards compatibility but is ignored. All dialogue now requires manual advancement.

### Dialogue Metadata
| Field | Type    | Description                                    |
|-------|---------|------------------------------------------------|
| id    | string  | Unique dialogue identifier                     |
| once  | boolean | If true, only shows once per save file         |

### Speaker Types
- **"companion"** - Uses CompanionManager race/gender/name, portrait on left
- **"player"** - Uses PlayerData race/gender/name, portrait on right
- **"narrator"** - Uses narrator.png, no portrait on right

---

## Portrait System

### Current Available Moods
Location: `assets/art/player_avatars/`

**Filename Format:** `{race}_{gender}_{mood}.png`

**Currently Available:**
- `{race}_{gender}.png` - Normal/calm expression
- `{race}_{gender}_ready.png` - Alert/prepared stance
- `{race}_{gender}_attack.png` - Aggressive/angry expression
- `{race}_{gender}_back.png` - Rear view (walking away)
- `narrator.png` - Special portrait for system messages

### 🎨 **TODO: Additional Moods Needed**

**Essential Moods to Create (Priority 1):**
- `_happy` - Smiling, cheerful (celebrations, good news, jokes)
- `_sad` - Downcast, melancholic (bad news, loss, disappointment)
- `_worried` - Concerned, anxious (danger approaching, uncertain)
- `_angry` - Frowning, upset (conflict, disagreement, frustration)

**Nice-to-Have Moods (Priority 2):**
- `_surprised` - Wide eyes, shocked (unexpected events, revelations)
- `_embarrassed` - Blushing, awkward (caught off-guard, social mishaps)
- `_hurt` - In pain, grimacing (after taking damage, injuries)
- `_thinking` - Contemplative, hand on chin (puzzles, decisions)

**Total Images to Create:**
- 4 essential moods × 4 races × 2 genders = **32 images**
- 4 nice-to-have moods × 4 races × 2 genders = **32 more images**
- **Total: 64 new portrait images**

**Races:** dwarf, elf, goblin, human
**Genders:** male, female

**Example Filenames:**
```
human_male_happy.png
elf_female_sad.png
dwarf_male_worried.png
goblin_female_angry.png
```

---

## DialogueUI.gd - User Interface

### UI Layout
```
DialogueUI (CanvasLayer)
├── BackgroundDim (ColorRect - blocks game input)
├── LeftPortrait (TextureRect - companion/NPC)
├── RightPortrait (TextureRect - player)
└── DialogueBox (PanelContainer)
    └── MarginContainer
        └── VBoxContainer
            ├── SpeakerName (Label)
            ├── DialogueText (RichTextLabel)
            └── CloseButton (Button - "Press X or Click")
```

### Input Handling
- **X Key** - Captured via `_input()` with `InputEventKey`
- **Mouse Click** - Background ColorRect captures all clicks via `gui_input`
- **Input Consumption** - Uses `get_viewport().set_input_as_handled()` to prevent game interaction

### Advance Logic
1. If not last message → show next message
2. If last message → close dialogue and emit `dialogue_closed` signal
3. Background dim blocks all mouse interaction with game world

---

## Integration Examples

### Triggering Dialogue from Code
```gdscript
# In blocky_game.gd (on game start)
func _on_player_spawned():
    # Load dialogue data first
    DialogueManager.load_dialogue_file("res://assets/data/dialogues/companion_intro.json")

    # Trigger game start dialogue
    if not DialogueManager.has_seen_dialogue("game_start"):
        DialogueManager.trigger_dialogue("game_start")
```

### Loading Multiple Dialogue Files
```gdscript
func _ready():
    DialogueManager.load_dialogue_file("res://assets/data/dialogues/companion_intro.json")
    DialogueManager.load_dialogue_file("res://assets/data/dialogues/tutorials.json")
    DialogueManager.load_dialogue_file("res://assets/data/dialogues/ruin_encounters.json")
```

### Console Command for Testing
```gdscript
# In GameConsole.gd
func _cmd_dialogue(args: Array):
    if args.is_empty():
        add_output("[color=yellow]Usage: dialogue <dialogue_id>[/color]")
        add_output("Available dialogues: game_start, first_night, ruin_discovered")
        return

    var dialogue_id = args[0]
    DialogueManager.trigger_dialogue(dialogue_id)
```

Console usage:
```bash
dialogue game_start
dialogue first_night
dialogue reset  # Reset all progress
```

---

## Example Dialogue Files

### Game Start Introduction
**File:** `assets/data/dialogues/companion_intro.json`

```json
{
  "dialogues": {
    "game_start": {
      "id": "game_start",
      "once": true,
      "messages": [
        {
          "speaker": "companion",
          "mood": "normal",
          "text": "Hey there! Welcome to the world! I'm {{companion_name}}, your companion.",
          "delay": 0
        },
        {
          "speaker": "companion",
          "mood": "ready",
          "text": "This place can be dangerous, especially at night. Stick with me, {{player_name}}!",
          "delay": 0
        },
        {
          "speaker": "player",
          "mood": "normal",
          "text": "Thanks {{companion_name}}. I'm ready for anything!",
          "delay": 0
        }
      ]
    }
  }
}
```

### First Night Warning
```json
{
  "dialogues": {
    "first_night": {
      "id": "first_night",
      "once": true,
      "messages": [
        {
          "speaker": "companion",
          "mood": "worried",
          "text": "{{player_name}}, the sun is setting. Monsters come out at night!",
          "delay": 0
        },
        {
          "speaker": "companion",
          "mood": "ready",
          "text": "Stay close to me. We'll survive this together.",
          "delay": 0
        }
      ]
    }
  }
}
```

---

## Save Data Format

### Dialogue Progress
**File:** `user://dialogue_progress.json`

```json
{
  "seen_dialogues": {
    "game_start": true,
    "first_night": true,
    "ruin_discovered": false
  },
  "timestamp": 1698678000
}
```

### Player Character Data
**File:** `user://player_character.save`

```json
{
  "role": "tank",
  "race": "human",
  "gender": "male",
  "player_name": "Marcus"
}
```

### Companion Data
**File:** `user://companion.save`

```json
{
  "race": "elf",
  "role": "healer",
  "gender": "female",
  "companion_name": "Sylvara",
  "equipped_weapon_id": 9
}
```

---

## PartyUI Integration

The Party UI (top-right corner) displays character names instead of race names:

**Before:**
```
Human [Tank]
Elf [Healer]
```

**After:**
```
Marcus [Tank]
Sylvara [Healer]
```

**File:** `long_nights/PartyUI.gd:262, 358`

---

## Testing Checklist

### ✅ Completed Tests
- [x] Quiz shows name input after questions
- [x] Default names appear correctly
- [x] Custom names save and load
- [x] Companion gets correct complementary name
- [x] Dialogue displays both character names
- [x] Variable substitution works ({{player_name}}, {{companion_name}})
- [x] X key advances dialogue
- [x] Left-click anywhere advances dialogue
- [x] Last message shows "Press X or Click to Close"
- [x] One-time dialogues don't repeat
- [x] Progress resets on new game
- [x] Portrait mood changes work (_normal → _ready → _attack)
- [x] PartyUI shows character names

### 🎨 Art Tasks Remaining
- [ ] Create essential mood portraits (happy, sad, worried, angry) - 32 images
- [ ] Create nice-to-have mood portraits (surprised, embarrassed, hurt, thinking) - 32 images
- [ ] Test all new moods in dialogue system
- [ ] Update companion_intro.json to use new moods

---

## Console Commands

```bash
# Trigger dialogues
dialogue game_start
dialogue first_night
dialogue ruin_discovered

# Reset all dialogue progress (for testing)
dialogue reset

# List available dialogues
dialogue
```

---

## Future Enhancements (Not Implemented)

### Possible Future Features
- [ ] Choice system (branching dialogue with 2-4 options)
- [ ] Typewriter text effect
- [ ] Voice blip sounds (Animal Crossing style)
- [ ] Portrait animations (bounce, shake)
- [ ] Background blur shader
- [ ] Dialogue history log
- [ ] Skip dialogue (hold button to fast-forward)

**Note:** The old JavaScript version had a node-based visual novel editor (Sargem) with choice nodes, combat nodes, show art nodes, give items nodes, etc. We're keeping the current system simple and JSON-based. If complex branching is needed later, the JSON format can be extended without major refactoring.

---

## Code Refactoring Notes

### Name Generation Consolidation
All character name generation is centralized in `CharacterQuiz.gd:237-254`:

```gdscript
static func get_default_name(race: String, gender: String, is_companion: bool = false) -> String
```

**Usage:**
- `CharacterQuiz.get_default_name("human", "male", false)` → "Marcus"
- `CharacterQuiz.get_default_name("elf", "female", true)` → "Sylvara"

This eliminates duplicate code in PlayerData and CompanionManager.

---

## Architecture Decisions

### Why Manual Advance Only?
**Original Design:** Auto-advance after delay (e.g., 2500ms)
**Problem:** Players might leave during dialogue (bathroom, drink, etc.) and miss content
**Solution:** All dialogue requires X key or left-click to advance

**Benefits:**
- Players control pacing
- No missed dialogue
- Can read at their own speed
- Can pause mid-conversation

### Why No Node Editor?
**Old System:** Visual node-based editor (Sargem) with complex branching
**Current System:** Simple JSON trigger-based dialogues

**Reasoning:**
- JSON is easier to edit outside game
- No need to rebuild editor in Godot
- Simpler = fewer bugs
- Can extend JSON format later if needed
- Most dialogues are linear anyway

---

## Performance Considerations

### Dialogue UI Lifecycle
1. **Created on first trigger** - DialogueManager instantiates DialogueUI.tscn
2. **Reused for all dialogues** - Same UI instance persists in scene tree
3. **Hidden when not in use** - `visible = false` instead of destroying
4. **Portrait textures loaded on demand** - `load()` called when needed

### Save File Size
- Dialogue progress: ~1KB for 50 dialogues
- Character data: <1KB
- Total overhead: Negligible

---

## Known Issues & Limitations

### Current Limitations
- No branching choices (single linear path per dialogue)
- No typewriter effect (instant text display)
- No dialogue history/backlog
- Portrait moods limited to existing images (see TODO section)
- Cannot interrupt ongoing dialogue (must advance to end)

### Not Issues (By Design)
- ~~Auto-advance timer~~ - Removed intentionally
- ~~ESC to close~~ - Would conflict with pause menu
- ~~Click on dialogue box to advance~~ - Background click is better UX

---

## File Locations Reference

### Code Files
- `project/long_nights/DialogueManager.gd` - Core dialogue system
- `project/long_nights/PlayerData.gd` - Player character data + name
- `project/long_nights/CompanionManager.gd` - Companion data + name
- `project/long_nights/CharacterQuiz.gd` - Character creation + name input
- `project/long_nights/PartyUI.gd` - Top-right UI with character names
- `project/blocky_game/gui/dialogue/DialogueUI.gd` - UI controller
- `project/blocky_game/gui/dialogue/DialogueUI.tscn` - UI scene
- `project/blocky_game/main.gd` - Quiz integration
- `project/long_nights/GameConsole.gd` - Console dialogue command

### Data Files
- `project/assets/data/dialogues/companion_intro.json` - Example dialogue
- `user://dialogue_progress.json` - Save file (dialogue history)
- `user://player_character.save` - Save file (player data)
- `user://companion.save` - Save file (companion data)

### Art Assets
- `project/assets/art/player_avatars/{race}_{gender}.png` - Normal portraits
- `project/assets/art/player_avatars/{race}_{gender}_ready.png` - Alert portraits
- `project/assets/art/player_avatars/{race}_{gender}_attack.png` - Angry portraits
- `project/assets/art/player_avatars/{race}_{gender}_back.png` - Rear view
- `project/assets/art/player_avatars/narrator.png` - Narrator portrait

---

## Summary

The dialogue system is **fully functional and production-ready**. It successfully integrates with:
- Character creation quiz
- Player/companion name system
- Party UI display
- Save/load system
- Console commands for testing

**What works great:**
- Manual advance feels natural and player-controlled
- Variable substitution makes dialogues personal
- One-time dialogues prevent repetition
- Portrait mood changes add visual interest
- Integration with existing systems is seamless

**What needs work:**
- **Create mood portraits** (happy, sad, worried, angry) - 32 images needed
- Write more dialogue content for story events
- Add dialogue triggers throughout game (night warnings, ruin discoveries, etc.)

**Overall:** The system provides a solid foundation for storytelling, companion interaction, tutorials, and NPC conversations. Ready for content creation! 🎉
