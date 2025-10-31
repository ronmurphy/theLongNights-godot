extends CanvasLayer
## CharacterQuiz - Initial character creation quiz
## Determines player role, race, and gender through personality questions

signal quiz_completed(role: String, race: String, gender: String, player_name: String)

# Quiz state
var current_question: int = 0
var answers: Dictionary = {
	"role": "",
	"race": "",
	"gender": ""
}

# UI Elements
var panel: PanelContainer
var question_label: Label
var button_container: VBoxContainer
var progress_label: Label

# Question data structure
var questions: Array = []


func _ready() -> void:
	_setup_questions()
	_create_ui()
	_show_question(0)


func _setup_questions() -> void:
	# Question 1: Role (disguised as personality)
	questions.append({
		"text": "When facing a challenge, you see yourself as...",
		"type": "role",
		"options": [
			{"text": "Brave and protective - I stand between danger and those I care about", "value": "tank"},
			{"text": "Wise and mystical - I harness the arcane forces of nature", "value": "wizard"},
			{"text": "Caring and supportive - I tend to wounds and lift spirits", "value": "healer"},
			{"text": "Swift and cunning - I strike from the shadows with precision", "value": "rogue"}
		]
	})

	# Question 2: Race (disguised as self-perception)
	questions.append({
		"text": "How do others describe your nature?",
		"type": "race",
		"options": [
			{"text": "Adaptable and versatile - I can thrive anywhere", "value": "human"},
			{"text": "Graceful and perceptive - I move with elegance and wisdom", "value": "elf"},
			{"text": "Sturdy and determined - I am as solid as the mountains", "value": "dwarf"},
			{"text": "Resourceful and scrappy - I make the most of what I have", "value": "goblin"}
		]
	})

	# Question 3: Gender
	questions.append({
		"text": "How do you identify?",
		"type": "gender",
		"options": [
			{"text": "Male", "value": "male"},
			{"text": "Female", "value": "female"}
		]
	})


func _create_ui() -> void:
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Main panel
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 400)
	center.add_child(panel)

	# Style panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.12, 0.1, 0.95)
	panel_style.border_color = Color(0.6, 0.5, 0.3)
	panel_style.set_border_width_all(3)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)

	# Margin
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(margin)

	# VBox for layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Character Creation"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Progress indicator
	progress_label = Label.new()
	progress_label.add_theme_font_size_override("font_size", 14)
	progress_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(progress_label)

	# Question text
	question_label = Label.new()
	question_label.add_theme_font_size_override("font_size", 20)
	question_label.add_theme_color_override("font_color", Color(1, 1, 1))
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	question_label.custom_minimum_size = Vector2(500, 0)
	vbox.add_child(question_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# Button container for answer options
	button_container = VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 12)
	vbox.add_child(button_container)


func _show_question(index: int) -> void:
	current_question = index

	if index >= questions.size():
		_finish_quiz()
		return

	var question = questions[index]

	# Update progress
	progress_label.text = "Question %d of %d" % [index + 1, questions.size()]

	# Update question text
	question_label.text = question["text"]

	# Clear previous buttons
	for child in button_container.get_children():
		child.queue_free()

	# Create answer buttons
	for option in question["options"]:
		var button = Button.new()
		button.text = option["text"]
		button.custom_minimum_size = Vector2(500, 50)
		button.add_theme_font_size_override("font_size", 16)

		# Style button
		var button_style = StyleBoxFlat.new()
		button_style.bg_color = Color(0.3, 0.25, 0.2)
		button_style.set_border_width_all(2)
		button_style.border_color = Color(0.5, 0.4, 0.3)
		button.add_theme_stylebox_override("normal", button_style)

		var button_hover = StyleBoxFlat.new()
		button_hover.bg_color = Color(0.4, 0.35, 0.25)
		button_hover.set_border_width_all(2)
		button_hover.border_color = Color(0.7, 0.6, 0.4)
		button.add_theme_stylebox_override("hover", button_hover)

		# Connect button
		button.pressed.connect(_on_answer_selected.bind(question["type"], option["value"]))

		button_container.add_child(button)


func _on_answer_selected(question_type: String, value: String) -> void:
	# Store answer
	answers[question_type] = value

	print("Quiz: Selected %s = %s" % [question_type, value])

	# Move to next question
	_show_question(current_question + 1)


func _finish_quiz() -> void:
	print("Quiz completed!")
	print("  Role: %s" % answers["role"])
	print("  Race: %s" % answers["race"])
	print("  Gender: %s" % answers["gender"])

	# Show name input screen
	_show_name_input()


func _show_name_input() -> void:
	# Get default name based on quiz results
	var default_name = get_default_name(answers["race"], answers["gender"], false)

	# Clear question UI
	progress_label.text = "Final Step"
	question_label.text = "What is your name, traveler?"

	# Clear previous buttons
	for child in button_container.get_children():
		child.queue_free()

	# Create name input field
	var name_input = LineEdit.new()
	name_input.text = default_name
	name_input.custom_minimum_size = Vector2(500, 50)
	name_input.add_theme_font_size_override("font_size", 20)
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.placeholder_text = "Enter your name..."
	name_input.select_all()  # Pre-select so typing replaces it

	# Style the LineEdit
	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0.2, 0.18, 0.15)
	input_style.set_border_width_all(2)
	input_style.border_color = Color(0.6, 0.5, 0.3)
	input_style.corner_radius_top_left = 4
	input_style.corner_radius_top_right = 4
	input_style.corner_radius_bottom_left = 4
	input_style.corner_radius_bottom_right = 4
	name_input.add_theme_stylebox_override("normal", input_style)

	var input_focus = StyleBoxFlat.new()
	input_focus.bg_color = Color(0.25, 0.22, 0.18)
	input_focus.set_border_width_all(3)
	input_focus.border_color = Color(0.8, 0.7, 0.4)
	input_focus.corner_radius_top_left = 4
	input_focus.corner_radius_top_right = 4
	input_focus.corner_radius_bottom_left = 4
	input_focus.corner_radius_bottom_right = 4
	name_input.add_theme_stylebox_override("focus", input_focus)

	button_container.add_child(name_input)

	# Create continue button
	var continue_button = Button.new()
	continue_button.text = "Begin Adventure"
	continue_button.custom_minimum_size = Vector2(500, 50)
	continue_button.add_theme_font_size_override("font_size", 18)

	# Style button
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.3, 0.25, 0.2)
	button_style.set_border_width_all(2)
	button_style.border_color = Color(0.5, 0.4, 0.3)
	continue_button.add_theme_stylebox_override("normal", button_style)

	var button_hover = StyleBoxFlat.new()
	button_hover.bg_color = Color(0.4, 0.35, 0.25)
	button_hover.set_border_width_all(2)
	button_hover.border_color = Color(0.7, 0.6, 0.4)
	continue_button.add_theme_stylebox_override("hover", button_hover)

	# Connect button
	continue_button.pressed.connect(_on_name_confirmed.bind(name_input))

	# Also allow Enter key to confirm
	name_input.text_submitted.connect(func(_text): _on_name_confirmed(name_input))

	button_container.add_child(continue_button)

	# Focus the input field
	name_input.grab_focus()


func _on_name_confirmed(name_input: LineEdit) -> void:
	var player_name = name_input.text.strip_edges()

	# If empty, use default
	if player_name == "":
		player_name = get_default_name(answers["race"], answers["gender"], false)

	print("  Player Name: %s" % player_name)

	# Emit completion signal with name
	quiz_completed.emit(answers["role"], answers["race"], answers["gender"], player_name)

	# Hide quiz
	queue_free()


## Public method to get avatar sprite path based on quiz results
static func get_avatar_path(race: String, gender: String, state: String = "") -> String:
	var base_path = "res://assets/art/player_avatars/"
	var filename = "%s_%s" % [race, gender]

	if state != "":
		filename += "_%s" % state

	return base_path + filename + ".png"


## Get role display name
static func get_role_name(role: String) -> String:
	match role:
		"tank": return "Tank"
		"wizard": return "Wizard"
		"healer": return "Healer"
		"rogue": return "Rogue"
		_: return "Unknown"


## Get race display name
static func get_race_name(race: String) -> String:
	match race:
		"human": return "Human"
		"elf": return "Elf"
		"dwarf": return "Dwarf"
		"goblin": return "Goblin"
		_: return "Unknown"


## Get default character name based on race, gender, and whether it's a companion
static func get_default_name(race: String, gender: String, is_companion: bool = false) -> String:
	var player_names = {
		"dwarf": {"male": "Thrain", "female": "Katrin"},
		"elf": {"male": "Aelindor", "female": "Lyralei"},
		"goblin": {"male": "Grix", "female": "Snick"},
		"human": {"male": "Marcus", "female": "Elena"}
	}

	var companion_names = {
		"dwarf": {"male": "Borin", "female": "Helga"},
		"elf": {"male": "Faelar", "female": "Sylvara"},
		"goblin": {"male": "Zikk", "female": "Nixie"},
		"human": {"male": "Thomas", "female": "Sarah"}
	}

	var names = companion_names if is_companion else player_names
	var fallback = "Companion" if is_companion else "Wanderer"
	return names.get(race, {}).get(gender, fallback)


## Get movement speed multiplier based on race
static func get_race_speed_multiplier(race: String) -> float:
	match race:
		"elf":
			return 1.0  # Base speed (most agile)
		"human":
			return 0.85  # Slightly slower
		"dwarf":
			return 0.7  # Short legs, heavy armor
		"goblin":
			return 0.7  # Short but scrappy
		_:
			return 1.0  # Fallback to base speed
