extends Node

## DialogueManager - Singleton for managing dialogue system
## Loads dialogue JSON, tracks progress, and coordinates with DialogueUI

# Signals
signal dialogue_started(dialogue_id: String)
signal dialogue_ended(dialogue_id: String)

# Data
var dialogue_data: Dictionary = {}
var seen_dialogues: Dictionary = {}  # Track which dialogues have been shown

# Paths
const DIALOGUE_SAVE_PATH = "user://dialogue_progress.json"

# UI Reference
var dialogue_ui: CanvasLayer = null


func _ready() -> void:
	load_progress()
	print("[DialogueManager] Ready - Dialogue system initialized")


## Load dialogue data from JSON file
func load_dialogue_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("DialogueManager: File not found: %s" % path)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("DialogueManager: Failed to open file: %s" % path)
		return false

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error != OK:
		push_error("DialogueManager: Failed to parse JSON: %s" % path)
		return false

	var data = json.get_data()

	# Merge into dialogue_data
	if data.has("dialogues"):
		for id in data["dialogues"]:
			dialogue_data[id] = data["dialogues"][id]
			print("[DialogueManager] Loaded dialogue: %s" % id)

	return true


## Trigger a dialogue by ID
func trigger_dialogue(dialogue_id: String) -> bool:
	if not dialogue_data.has(dialogue_id):
		push_warning("DialogueManager: Dialogue not found: %s" % dialogue_id)
		return false

	var dialogue = dialogue_data[dialogue_id]

	# Check if it's a "once" dialogue that's already been seen
	if dialogue.get("once", false) and has_seen_dialogue(dialogue_id):
		print("[DialogueManager] Dialogue '%s' already seen (once-only)" % dialogue_id)
		return false

	# Prepare messages for UI
	var messages = _prepare_messages(dialogue.get("messages", []))

	if messages.size() == 0:
		push_warning("DialogueManager: No messages in dialogue: %s" % dialogue_id)
		return false

	# Get or create UI
	if dialogue_ui == null:
		_create_dialogue_ui()

	# Show dialogue
	dialogue_ui.show_dialogue(messages)

	# Mark as seen
	mark_dialogue_seen(dialogue_id)

	# Emit signal
	dialogue_started.emit(dialogue_id)

	print("[DialogueManager] Triggered dialogue: %s" % dialogue_id)
	return true


## Trigger a dynamically generated dialogue (not from JSON)
func trigger_dynamic_dialogue(dialogue_dict: Dictionary) -> bool:
	# Prepare messages for UI
	var messages = _prepare_messages(dialogue_dict.get("messages", []))

	if messages.size() == 0:
		push_warning("DialogueManager: No messages in dynamic dialogue")
		return false

	# Get or create UI
	if dialogue_ui == null:
		_create_dialogue_ui()

	# Show dialogue
	dialogue_ui.show_dialogue(messages)

	# Dynamic dialogues don't get marked as seen (they're ephemeral)

	# Emit signal with dynamic ID
	var dialogue_id = dialogue_dict.get("id", "dynamic")
	dialogue_started.emit(dialogue_id)

	print("[DialogueManager] Triggered dynamic dialogue: %s" % dialogue_id)
	return true


## Prepare messages with portraits and formatting
func _prepare_messages(raw_messages: Array) -> Array:
	var prepared = []

	for msg in raw_messages:
		var speaker = msg.get("speaker", "narrator")
		var mood = msg.get("mood", "normal")
		var text = msg.get("text", "")
		var delay = msg.get("delay", 0)

		# Get character info for portraits
		var left_path = ""
		var right_path = ""
		var speaker_display = ""

		if speaker == "companion":
			# Get companion info from CompanionManager
			var race = CompanionManager.companion_race
			var gender = CompanionManager.companion_gender
			left_path = _get_portrait_path(race, gender, mood)
			speaker_display = CompanionManager.get_companion_name()

		elif speaker == "player":
			# Get player info from PlayerData
			var race = PlayerData.race
			var gender = PlayerData.gender
			right_path = _get_portrait_path(race, gender, mood)
			speaker_display = "You"

		elif speaker == "narrator":
			left_path = "res://assets/art/player_avatars/narrator.png"
			speaker_display = "Narrator"

		else:
			# Custom NPC - would need to be expanded
			speaker_display = speaker

		# Substitute variables in text
		text = _substitute_variables(text)

		prepared.append({
			"speaker": speaker,
			"speaker_display": speaker_display,
			"text": text,
			"delay": delay,
			"portrait_left": left_path,
			"portrait_right": right_path
		})

	return prepared


## Get portrait path for character
func _get_portrait_path(race: String, gender: String, mood: String) -> String:
	var base = "res://assets/art/player_avatars/"
	var filename = "%s_%s" % [race, gender]

	if mood != "" and mood != "normal":
		filename += "_%s" % mood

	return base + filename + ".png"


## Substitute variables in text
func _substitute_variables(text: String) -> String:
	# Replace {{companion_name}}
	text = text.replace("{{companion_name}}", CompanionManager.get_companion_name())

	# Replace {{player_name}}
	text = text.replace("{{player_name}}", PlayerData.player_name)

	# Replace {{companion_race}}
	text = text.replace("{{companion_race}}", CompanionManager.companion_race)

	# Replace {{player_race}}
	text = text.replace("{{player_race}}", PlayerData.race)

	return text


## Create dialogue UI instance
func _create_dialogue_ui() -> void:
	var scene = load("res://blocky_game/gui/dialogue/DialogueUI.tscn")
	if not scene:
		push_error("DialogueManager: Failed to load DialogueUI scene")
		return

	dialogue_ui = scene.instantiate()

	# Connect signals
	dialogue_ui.dialogue_closed.connect(_on_dialogue_closed)

	# Add to scene tree
	get_tree().root.add_child(dialogue_ui)

	print("[DialogueManager] Created DialogueUI")


## Called when dialogue UI closes
func _on_dialogue_closed() -> void:
	# Emit signal (could pass dialogue_id if we tracked it)
	dialogue_ended.emit("")


## Check if a dialogue has been seen
func has_seen_dialogue(dialogue_id: String) -> bool:
	return seen_dialogues.get(dialogue_id, false)


## Mark a dialogue as seen
func mark_dialogue_seen(dialogue_id: String) -> void:
	seen_dialogues[dialogue_id] = true
	save_progress()


## Save dialogue progress to disk
func save_progress() -> void:
	var data = {
		"seen_dialogues": seen_dialogues,
		"timestamp": Time.get_ticks_msec()
	}

	var json_string = JSON.stringify(data)
	var file = FileAccess.open(DIALOGUE_SAVE_PATH, FileAccess.WRITE)

	if file:
		file.store_string(json_string)
		print("[DialogueManager] Saved dialogue progress")
	else:
		push_warning("[DialogueManager] Failed to save dialogue progress")


## Load dialogue progress from disk
func load_progress() -> void:
	if not FileAccess.file_exists(DIALOGUE_SAVE_PATH):
		print("[DialogueManager] No saved progress found (first run)")
		return

	var file = FileAccess.open(DIALOGUE_SAVE_PATH, FileAccess.READ)
	if not file:
		push_warning("[DialogueManager] Failed to load dialogue progress")
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)

	if error == OK:
		var data = json.get_data()
		if data.has("seen_dialogues"):
			seen_dialogues = data["seen_dialogues"]
			print("[DialogueManager] Loaded dialogue progress (%d seen)" % seen_dialogues.size())
	else:
		push_warning("[DialogueManager] Failed to parse dialogue progress")


## Reset all dialogue progress (for testing)
func reset_progress() -> void:
	seen_dialogues.clear()
	save_progress()
	print("[DialogueManager] Reset all dialogue progress")
