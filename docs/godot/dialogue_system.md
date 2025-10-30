# Dialogue System Design

## Overview
Visual novel-style dialogue system for companion conversations, NPC interactions, tutorials, and story progression.

## Visual Design Reference
Based on the visual novel screenshot showing:
- Large character portraits (left = NPC/companion, right = player)
- Character name tags with speaker highlighting
- Clean dialogue box with readable text
- Character stat panels on sides
- Blurred game background for focus
- "Close" button for dismissal

## Assets Available

### Character Portraits
Location: `/home/brad/Godot/theLongNights/assets/art/player_avatars/`

**Format**: `{race}_{gender}_{mood}.png`

**Races**: dwarf, elf, goblin, human
**Genders**: male, female
**Moods**:
- (none) = Normal/calm pose
- `_ready` = Alert/combat stance
- `_attack` = Aggressive/angry
- `_back` = Rear view (walking away)

**Special**: `narrator.png` for system messages

### Portrait Usage in Dialogue
Characters can change expression mid-conversation:
```
Companion: "Hey there!" → elf_female.png (calm)
Companion: "Watch out!" → elf_female_ready.png (alert)
Companion: "Take THIS!" → elf_female_attack.png (angry)
```

## JSON Data Structure (from old JS version)

### Original Files
- `/assets/data/companion_introduction.json` - Node-based dialogue graph (complex)
- `/assets/data/tutorialScripts.json` - Event-triggered tutorials (simpler) ✅ **Use this structure**

### Recommended Godot Structure
Consolidate into trigger-based system (simpler than node graphs):

```json
{
  "tutorials": {
    "game_start": {
      "id": "game_start",
      "trigger": "on_game_start",
      "once": true,
      "messages": [
        {
          "speaker": "companion",
          "mood": "normal",
          "text": "Hey there! Welcome to the world!",
          "delay": 2000
        },
        {
          "speaker": "companion",
          "mood": "ready",
          "text": "Let me show you the ropes!",
          "delay": 1500
        }
      ]
    },

    "ruin_entrance": {
      "id": "ruin_entrance",
      "trigger": "on_ruin_entered",
      "once": true,
      "messages": [
        {
          "speaker": "companion",
          "mood": "normal",
          "text": "This place is ancient... I wonder who built it?",
          "delay": 1500
        },
        {
          "speaker": "companion",
          "mood": "ready",
          "text": "Stay alert. There might be enemies inside!",
          "delay": 2000
        }
      ]
    }
  }
}
```

### Message Fields
- `speaker`: "companion" | "narrator" | "player" | custom NPC ID
- `mood`: "normal" | "ready" | "attack" | "back"
- `text`: Dialogue text to display
- `delay`: Milliseconds before advancing to next message (0 = wait for player input)
- `side` (optional): "left" | "right" (default: companion=left, player=right)

### Variable Substitution
Support for dynamic text:
- `{{companion_name}}` - Replaced with actual companion name
- `{{player_name}}` - Player character name
- `{{companion_race}}` - dwarf/elf/goblin/human

## System Architecture

### DialogueManager Singleton
**Path**: `res://long_nights/DialogueManager.gd`
**Autoload**: Yes

**Responsibilities**:
1. Load dialogue JSON files
2. Track which tutorials have been shown (save to file)
3. Provide trigger functions (e.g., `trigger_dialogue("ruin_entrance")`)
4. Emit signals when dialogue starts/ends
5. Handle variable substitution

**Key Functions**:
```gdscript
func load_dialogue_data(path: String) -> void
func trigger_dialogue(dialogue_id: String) -> bool
func has_seen_dialogue(dialogue_id: String) -> bool
func mark_dialogue_seen(dialogue_id: String) -> void
func get_portrait_path(speaker: String, race: String, gender: String, mood: String) -> String
```

**Signals**:
```gdscript
signal dialogue_started(dialogue_id: String)
signal dialogue_ended(dialogue_id: String)
signal message_changed(message_index: int)
```

### DialogueUI Scene
**Path**: `res://blocky_game/gui/dialogue/dialogue_ui.tscn`

**Node Structure**:
```
DialogueUI (Control)
├─ BackgroundBlur (ColorRect with blur shader)
├─ LeftPortrait (TextureRect)
├─ RightPortrait (TextureRect)
├─ LeftStatsPanel (Panel)
├─ RightStatsPanel (Panel)
├─ DialogueBox (Panel)
│  ├─ SpeakerTag (Label)
│  ├─ MessageText (RichTextLabel)
│  └─ CloseButton (Button)
└─ TopNotification (Panel)
```

**UI Script Responsibilities**:
1. Show/hide dialogue UI
2. Display character portraits
3. Show message text (with optional typewriter effect)
4. Handle "Close" button and auto-advance
5. Update speaker tag highlighting
6. Connect to DialogueManager signals

### Integration Points

**Trigger Events** (connect these in game code):
- `on_game_start` - First time player starts
- `on_ruin_entered` - Player enters ruin teleport stone area
- `on_item_crafted` - Player crafts specific item
- `on_first_night` - First nightfall
- `on_companion_spawned` - When companion first appears
- `on_boss_defeated` - After boss fight

**Example Trigger**:
```gdscript
# In blocky_game.gd when player spawns
func _on_player_spawned():
    if not DialogueManager.has_seen_dialogue("game_start"):
        DialogueManager.trigger_dialogue("game_start")
```

## File Locations

### JSON Dialogue Files
- `res://assets/data/dialogues/companion_intro.json` - Companion introduction
- `res://assets/data/dialogues/tutorials.json` - Tutorial messages
- `res://assets/data/dialogues/ruin_encounters.json` - Ruin-specific dialogue
- `res://assets/data/dialogues/story_events.json` - Main story progression

### Save Data
- `user://dialogue_progress.json` - Tracks which dialogues have been seen

### Portrait Paths (already exist)
- `res://assets/art/player_avatars/{race}_{gender}.png`
- `res://assets/art/player_avatars/{race}_{gender}_ready.png`
- `res://assets/art/player_avatars/{race}_{gender}_attack.png`
- `res://assets/art/player_avatars/{race}_{gender}_back.png`
- `res://assets/art/player_avatars/narrator.png`

## Implementation Plan (Tomorrow Evening - 6 hours)

### Phase 1: Core System (2 hours)
1. Create DialogueManager.gd singleton
2. Implement JSON loading
3. Create progress tracking (save/load)
4. Test with simple dialogue

### Phase 2: UI Scene (2 hours)
1. Build DialogueUI.tscn layout
2. Implement portrait swapping
3. Add typewriter effect (optional)
4. Style dialogue box to match screenshot
5. Add speaker highlighting

### Phase 3: Integration (1.5 hours)
1. Consolidate old JSON files
2. Create new dialogue files in Godot structure
3. Connect triggers in game code
4. Test companion introduction
5. Test ruin entrance dialogue

### Phase 4: Polish (30 min)
1. Add sound effects (text blips, dialogue open/close)
2. Add fade-in/out animations
3. Test with different companions
4. Verify all moods work correctly

## Features to Consider

### Must Have
- ✅ Show character portraits
- ✅ Display dialogue text
- ✅ Sequential messages
- ✅ Auto-advance with delays
- ✅ Manual advance (Close button)
- ✅ Track seen dialogues
- ✅ Trigger-based system
- ✅ Variable substitution
- ✅ Mood/expression changes

### Nice to Have
- Typewriter text effect
- Voice blip sounds (Animal Crossing style)
- Fade in/out transitions
- Shake/bounce portrait animations
- Background blur shader
- Skip dialogue option (hold button)

### Future Enhancements
- Branching dialogue choices (player responses)
- Dialogue history log
- Voice acting support
- Localization support
- Dialogue editor tool

## Notes from Old System

### Removed Features (tester feedback)
- ❌ Backpack pickup tutorial (testers hated finding backpack to unlock hotbar)
- ❌ Workbench system (too complex)
- ❌ Tool bench system (too complex)

### Systems to Keep/Add Back
- ✅ Kitchen bench (cooking system - was good, bring back)
- ✅ Companion introduction
- ✅ Ruin hints from companion (already written in tutorialScripts.json lines 66-80!)

### Existing Dialogue Content Ready to Port
From tutorialScripts.json:
- Game start introduction ✅
- First ruin sighting ✅
- Ruin entrance warning ✅
- Night warning ✅
- Ghost encounter ✅
- Rabbit hunting hint ✅

## Ready for Tomorrow!
All assets are in place, structure is planned, and we have 6 hours to build a polished dialogue system from scratch. This will be the foundation for:
- Companion interactions
- Tutorial system
- Story progression
- Ruin encounters
- NPC conversations
- Boss dialogue

Let's do this! 🎮✨
