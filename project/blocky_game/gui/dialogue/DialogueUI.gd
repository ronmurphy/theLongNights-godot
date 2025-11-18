extends CanvasLayer
class_name DialogueUI

## DialogueUI - Visual novel style dialogue interface
## Displays character portraits, speaker names, and dialogue text

# Signals
signal dialogue_advanced
signal dialogue_closed
signal choice_selected(choice)

# UI References
@onready var background_dim: ColorRect = $BackgroundDim
@onready var left_portrait: TextureRect = $LeftPortrait
@onready var right_portrait: TextureRect = $RightPortrait
@onready var dialogue_box: PanelContainer = $DialogueBox
@onready var speaker_name: Label = $DialogueBox/MarginContainer/VBoxContainer/SpeakerName
@onready var dialogue_text: RichTextLabel = $DialogueBox/MarginContainer/VBoxContainer/DialogueText
@onready var close_button: Button = $DialogueBox/MarginContainer/VBoxContainer/CloseButton

# Typing + timing
var typing_timer: Timer = null
var auto_advance_timer: Timer = null
var typing_speed_chars_per_sec: int = 60 # characters per second for typing effect
var typing_active: bool = false
var typing_target_chars: int = 0
var audio_player: AudioStreamPlayer = null
var voice_player: AudioStreamPlayer = null
var ac_voicebox: Node = null
var use_animalese_voice: bool = false
var is_choice_active: bool = false

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

	# Timers
	typing_timer = Timer.new()
	typing_timer.wait_time = 0.02
	typing_timer.one_shot = false
	typing_timer.autostart = false
	add_child(typing_timer)
	typing_timer.timeout.connect(_on_typing_tick)

	auto_advance_timer = Timer.new()
	auto_advance_timer.one_shot = true
	add_child(auto_advance_timer)
	auto_advance_timer.timeout.connect(_on_auto_advance_timeout)

	# Audio player for SFX
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)

	# Voice player for talking loops
	voice_player = AudioStreamPlayer.new()
	voice_player.name = "VoicePlayer"
	voice_player.bus = "SFX"
	add_child(voice_player)

	# Try to create an AC-style voicebox if available
	if ResourceLoader.exists("res://blocky_game/gui/dialogue/ACVoicebox.gd"):
		var script = load("res://blocky_game/gui/dialogue/ACVoicebox.gd")
		ac_voicebox = script.new()
		add_child(ac_voicebox)
		# Connect signals to sync typing
		ac_voicebox.characters_sounded.connect(_on_ac_characters_sounded)
		ac_voicebox.finished_phrase.connect(_on_ac_finished_phrase)
		print("[DialogueUI] ACVoicebox loaded")
	else:
		print("[DialogueUI] ACVoicebox not found - skipping animalese feature")
	# When voice finishes, restart if typing still active (simulate talk loop)
	voice_player.finished.connect(_on_voice_finished)


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

	# Reset choices state
	is_choice_active = false
	_remove_choices_ui()

	# Typing start (if animalese voice is requested, we'll let ACVoicebox drive character timings)
	use_animalese_voice = message.get("voice_mode", "") == "animalese"

	if use_animalese_voice and ac_voicebox:
		# Reset visible characters and let the voicebox emit character events
		dialogue_text.visible_characters = 0
		typing_active = true
		ac_voicebox.base_pitch = message.get("voice_pitch", ac_voicebox.base_pitch)
		ac_voicebox.play_speed = message.get("voice_speed", ac_voicebox.play_speed)
		ac_voicebox.play_string(message.get("text", ""))
		# Set number of characters expected so AC voice can update visible count
		typing_target_chars = dialogue_text.get_total_character_count() if dialogue_text.has_method("get_total_character_count") else str(dialogue_text.text).length()
	else:
		_start_typing()

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

	# Play sfx if provided
	var sfx = message.get("sfx", "")
	if sfx != "":
		var stream = load(sfx)
		if stream:
			audio_player.stream = stream
			audio_player.play()

	# Play voice (loop) if provided
	var voice = message.get("voice", "")
	if voice != "":
		var vstream = load(voice)
		if vstream:
			voice_player.stream = vstream
			voice_player.play()
	else:
		voice_player.stop()

	# show choices (if any)
	var choices = message.get("choices", null)
	if choices and choices.size() > 0:
		# Create choice buttons; lock advancing until one is selected
		is_choice_active = true
		_create_choices_ui(choices)
		# Ensure the box can't be advanced by click or key until choice made
		# The _on_advance_requested checks is_choice_active



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
	# Close button doubles as advance; if typing active -> skip to full, else advance
	_on_advance_requested()


## Unified advance handler (called by button, click, or keyboard)
func _on_advance_requested() -> void:
	# Manual advance or close
	# If the choices UI is active, don't advance until the player makes a choice
	if is_choice_active:
		print("[DialogueUI] Choice is active; ignoring advance until selection")
		return

	# If we're typing, skip to finish rather than advancing
	if typing_active:
		_print_and_skip_typing()
		return

	if current_message_index < current_messages.size() - 1:
		_advance_message()
	else:
		_finish_dialogue()


## Force close dialogue
func close_dialogue() -> void:
	_finish_dialogue()


## Typing
func _start_typing() -> void:
	# Reset timers/visibility
	dialogue_text.visible_characters = 0
	if dialogue_text.has_method("get_total_character_count"):
		typing_target_chars = dialogue_text.get_total_character_count()
	else:
		typing_target_chars = str(dialogue_text.text).length()

	# If zero chars, fire instantly
	if typing_target_chars <= 0:
		typing_active = false
		_on_typing_finished()
		return

	typing_active = true
	typing_timer.start()


func _on_typing_tick() -> void:
	if not typing_active:
		return

	# Increase visible characters by characters per tick
	var step = max(1, round(typing_speed_chars_per_sec * typing_timer.wait_time))
	dialogue_text.visible_characters = min(typing_target_chars, dialogue_text.visible_characters + step)

	if dialogue_text.visible_characters >= typing_target_chars:
		typing_timer.stop()
		typing_active = false
		_on_typing_finished()

	# If AC voice is driving typing we don't use this timer

	# If ac voice is driving typing, ignore timer behavior
	if use_animalese_voice:
		return


func _print_and_skip_typing() -> void:
	if not typing_active:
		return

	typing_timer.stop()
	typing_active = false
	dialogue_text.visible_characters = typing_target_chars
	# Stop animalese if playing
	if ac_voicebox:
		ac_voicebox.remaining_sounds.clear()
		if ac_voicebox.playing:
			ac_voicebox.stop()
	_on_typing_finished()


func _on_typing_finished() -> void:
	# When typing ends, if message specified a delay, auto advance after that delay
	var delay_ms = current_messages[current_message_index].get("delay", 0)
	if delay_ms and delay_ms > 0:
		auto_advance_timer.wait_time = delay_ms / 1000.0
		auto_advance_timer.start()

	# Typing finished -> stop voice
	if voice_player and voice_player.playing:
		voice_player.stop()

	# Reset animalese flag
	use_animalese_voice = false

	# Ensure AC voice is stopped
	if ac_voicebox and ac_voicebox.playing:
		ac_voicebox.remaining_sounds.clear()
		ac_voicebox.stop()


func _on_auto_advance_timeout() -> void:
	_on_advance_requested()


func _on_voice_finished() -> void:
	# If typing is still active, restart voice to simulate a continuous talking sound
	if typing_active and voice_player and voice_player.stream:
		voice_player.play()


func _on_ac_characters_sounded(characters: String) -> void:
	# Called by ACVoicebox when a sound is emitted and characters should be shown
	# characters may be multi-letter tokens like 'th' or 'sh', so increment accordingly
	dialogue_text.visible_characters = min(typing_target_chars, dialogue_text.visible_characters + characters.length())


func _on_ac_finished_phrase() -> void:
	# When AC voice finishes, treat as typing finished
	typing_active = false
	_on_typing_finished()


## Choices UI helpers
func _create_choices_ui(choices: Array) -> void:
	# Drop into the VBoxContainer under the DialogueBox (keep consistent with layout)
	var parent = dialogue_box.get_node("MarginContainer/VBoxContainer")
	if not parent:
		return

	# Remove any old choices
	_remove_choices_ui()

	var choices_box = VBoxContainer.new()
	choices_box.name = "Choices"
	choices_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(choices_box)

	for c in choices:
		var btn = Button.new()
		btn.text = c.get("text", "Choice")
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Connect with full choice dict as arg
		btn.pressed.connect(_on_choice_pressed.bind(c))
		choices_box.add_child(btn)


func _remove_choices_ui() -> void:
	var parent = dialogue_box.get_node("MarginContainer/VBoxContainer")
	if not parent:
		return
	if parent.has_node("Choices"):
		parent.get_node("Choices").queue_free()


func _on_choice_pressed(choice: Dictionary) -> void:
	# Emit selected choice and close (or not depending on the choice data)
	is_choice_active = false
	_remove_choices_ui()
	choice_selected.emit(choice)
