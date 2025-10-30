extends CanvasLayer
class_name DialogueUI

## DialogueUI - Visual novel style dialogue interface
## Displays character portraits, speaker names, and dialogue text

# Signals
signal dialogue_advanced
signal dialogue_closed

# UI References
@onready var background_dim: ColorRect = $BackgroundDim
@onready var left_portrait: TextureRect = $LeftPortrait
@onready var right_portrait: TextureRect = $RightPortrait
@onready var dialogue_box: PanelContainer = $DialogueBox
@onready var speaker_name: Label = $DialogueBox/MarginContainer/VBoxContainer/SpeakerName
@onready var dialogue_text: RichTextLabel = $DialogueBox/MarginContainer/VBoxContainer/DialogueText
@onready var close_button: Button = $DialogueBox/MarginContainer/VBoxContainer/CloseButton

# State
var current_messages: Array = []
var current_message_index: int = 0


func _ready() -> void:
	# Hide by default
	hide()

	# Connect close button
	close_button.pressed.connect(_on_close_pressed)

	# Make dialogue box stop mouse input (prevents game interaction)
	dialogue_box.mouse_filter = Control.MOUSE_FILTER_STOP

	# Background captures all mouse input AND advances dialogue on click
	background_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	background_dim.gui_input.connect(_on_background_clicked)


# Removed _process - no longer needed without auto-advance


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Handle keyboard input (X key to advance)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_X:
			_on_advance_requested()
			get_viewport().set_input_as_handled()


## Show dialogue with messages
func show_dialogue(messages: Array) -> void:
	current_messages = messages
	current_message_index = 0

	if messages.size() == 0:
		push_warning("DialogueUI: No messages to show")
		return

	show()
	_display_message(0)


## Display a specific message
func _display_message(index: int) -> void:
	if index >= current_messages.size():
		_finish_dialogue()
		return

	var message = current_messages[index]
	current_message_index = index

	# Update text
	speaker_name.text = message.get("speaker_display", "???")
	dialogue_text.text = message.get("text", "")

	# Update portraits
	var left_path = message.get("portrait_left", "")
	var right_path = message.get("portrait_right", "")

	if left_path != "":
		var texture = load(left_path)
		if texture:
			left_portrait.texture = texture
			left_portrait.show()
		else:
			left_portrait.hide()
	else:
		left_portrait.hide()

	if right_path != "":
		var texture = load(right_path)
		if texture:
			right_portrait.texture = texture
			right_portrait.show()
		else:
			right_portrait.hide()
	else:
		right_portrait.hide()

	# Check if this is the last message
	if index >= current_messages.size() - 1:
		close_button.text = "Press X or Click to Close"
	else:
		close_button.text = "Press X or Click"

	dialogue_advanced.emit()


## Advance to next message
func _advance_message() -> void:
	_display_message(current_message_index + 1)


## Finish dialogue sequence
func _finish_dialogue() -> void:
	hide()
	current_messages.clear()
	current_message_index = 0
	dialogue_closed.emit()


## Background clicked (anywhere on screen)
func _on_background_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("[DialogueUI] Background clicked - advancing")
			_on_advance_requested()


## Close button pressed
func _on_close_pressed() -> void:
	_on_advance_requested()


## Unified advance handler (called by button, click, or keyboard)
func _on_advance_requested() -> void:
	# Manual advance or close
	if current_message_index < current_messages.size() - 1:
		_advance_message()
	else:
		_finish_dialogue()


## Force close dialogue
func close_dialogue() -> void:
	_finish_dialogue()
