extends Control

## VoidChallengeCompleteDialog - Shows when void challenge is completed
## Displays reward potion and Continue button
## Emits completed signal when player clicks Continue

signal completed(potion_id: String, challenge_data: Dictionary)

@onready var _dialog_panel = $Panel
@onready var _title_label = $Panel/VBox/Title
@onready var _message_label = $Panel/VBox/Message
@onready var _continue_button = $Panel/VBox/ContinueButton

# Store challenge data for signal emission
var _current_potion_id: String = ""
var _current_challenge_data: Dictionary = {}


func _ready():
	hide()

	# Connect button signal
	_continue_button.pressed.connect(_on_continue_clicked)


func show_completion(potion_name: String, potion_id: String, challenge_data: Dictionary):
	"""Show the completion dialog with reward info"""
	_current_potion_id = potion_id
	_current_challenge_data = challenge_data

	# Set title
	_title_label.text = "Challenge Complete!"

	# Set message with reward
	_message_label.text = "Your reward is %s!" % potion_name

	# Show dialog
	show()

	# Pause game input (player can't move while dialog is open)
	get_tree().paused = false  # Don't actually pause, just show dialog


func _on_continue_clicked():
	"""Player clicked Continue button"""
	hide()

	# Emit completion signal with potion ID and challenge data
	completed.emit(_current_potion_id, _current_challenge_data)

	# Clear data
	_current_potion_id = ""
	_current_challenge_data = {}
