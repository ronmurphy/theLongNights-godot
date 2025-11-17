extends Control
class_name FishingUI

## FishingUI - Bar filling minigame interface
## Displays the bar, target zone, and handles spacebar input

signal attempt_completed(success: bool)
signal minigame_finished(caught: bool)

# UI state
var attempt: int = 0
var max_attempts: int = 5
var successes_needed: int = 3
var current_successes: int = 0
var target_zone_width: float = 0.4
var bar_fill_speed: float = 1.0

# Bar state
var bar_value: float = 0.0  # 0.0 to 1.0
var is_filling: bool = false
var current_attempt_active: bool = false

# UI References
var bar_container: PanelContainer = null
var bar_progress: ProgressBar = null
var target_zone_visual: Control = null
var status_label: Label = null
var attempt_label: Label = null

func _ready():
	pass

func setup(p_attempt: int, p_max_attempts: int, p_successes_needed: int, p_current_successes: int, p_target_zone_width: float) -> void:
	"""Initialize minigame state"""
	attempt = p_attempt
	max_attempts = p_max_attempts
	successes_needed = p_successes_needed
	current_successes = p_current_successes
	target_zone_width = p_target_zone_width

	_build_ui()

func _build_ui() -> void:
	"""Create the fishing minigame UI"""
	# Root container
	var root = VBoxContainer.new()
	root.custom_minimum_size = Vector2(600, 200)
	root.anchor_left = 0.5
	root.anchor_top = 0.5
	root.anchor_right = 0.5
	root.anchor_bottom = 0.5
	root.offset_left = -300
	root.offset_top = -100
	add_child(root)

	# Title
	var title = Label.new()
	title.text = "FISHING MINIGAME"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	# Attempt counter
	attempt_label = Label.new()
	attempt_label.text = "Attempt: %d / %d | Success: %d / %d" % [attempt + 1, max_attempts, current_successes, successes_needed]
	attempt_label.add_theme_font_size_override("font_size", 14)
	attempt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(attempt_label)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	root.add_child(spacer1)

	# Bar container
	bar_container = PanelContainer.new()
	bar_container.custom_minimum_size = Vector2(500, 80)
	root.add_child(bar_container)

	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	bar_container.add_child(bar_bg)

	# Progress bar (the filling bar)
	bar_progress = ProgressBar.new()
	bar_progress.min_value = 0.0
	bar_progress.max_value = 1.0
	bar_progress.value = 0.0
	bar_progress.custom_minimum_size = Vector2(500, 50)
	bar_progress.show_percentage = false
	bar_container.add_child(bar_progress)

	# Style the bar
	var bar_theme = Theme.new()
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.2, 0.8, 0.2, 0.8)  # Green fill
	bar_theme.set_stylebox("fill", "ProgressBar", bar_style)
	bar_progress.theme = bar_theme

	# Target zone visual (overlay showing the target area)
	target_zone_visual = Control.new()
	target_zone_visual.custom_minimum_size = Vector2(500, 50)
	bar_container.add_child(target_zone_visual)
	target_zone_visual.draw.connect(_draw_target_zone)

	# Status label
	status_label = Label.new()
	status_label.text = "Press SPACEBAR when the bar reaches the target zone!"
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.custom_minimum_size = Vector2(500, 0)
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(status_label)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	root.add_child(spacer2)

	# Instructions
	var instructions = Label.new()
	instructions.text = "Miss 3 times = Game Over | Get %d successes to catch the fish!" % successes_needed
	instructions.add_theme_font_size_override("font_size", 11)
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.modulate = Color(0.8, 0.8, 0.8)
	instructions.custom_minimum_size = Vector2(500, 0)
	root.add_child(instructions)

func start_attempt(p_bar_fill_speed: float) -> void:
	"""Start a new attempt"""
	current_attempt_active = true
	bar_fill_speed = p_bar_fill_speed
	bar_value = 0.0
	is_filling = true
	bar_progress.value = 0.0

	# Randomize target zone position in the bar (0.0 to 1.0 - target_zone_width)
	_randomize_target_zone()

	status_label.text = "Press SPACEBAR when the bar reaches the target zone!"
	target_zone_visual.queue_redraw()

func _process(delta: float) -> void:
	"""Update bar filling"""
	if not current_attempt_active or not is_filling:
		return

	# Increase bar value
	bar_value += delta * bar_fill_speed

	# Check if bar filled completely (failure)
	if bar_value >= 1.0:
		_fail_attempt()
		return

	# Update progress bar
	bar_progress.value = bar_value

func _input(event: InputEvent) -> void:
	"""Handle spacebar input"""
	if not current_attempt_active or not is_filling:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		get_tree().root.set_input_as_handled()
		_check_success()

func _randomize_target_zone() -> void:
	"""Randomize where the target zone appears in the bar"""
	# Target zone position (start of the zone as percentage)
	var target_start = randf_range(0.0, 1.0 - target_zone_width)
	var target_end = target_start + target_zone_width

	# Store for checking
	target_zone_visual.set_meta("target_start", target_start)
	target_zone_visual.set_meta("target_end", target_end)

func _draw_target_zone() -> void:
	"""Draw the target zone on the bar"""
	if not target_zone_visual.has_meta("target_start"):
		return

	var target_start = target_zone_visual.get_meta("target_start") as float
	var target_end = target_zone_visual.get_meta("target_end") as float

	var bar_width = target_zone_visual.size.x
	var zone_start = target_start * bar_width
	var zone_width = (target_end - target_start) * bar_width

	# Draw semi-transparent green rectangle for target zone
	target_zone_visual.draw_rect(
		Rect2(zone_start, 0, zone_width, target_zone_visual.size.y),
		Color(0, 1, 0, 0.3)
	)

	# Draw border
	target_zone_visual.draw_line(Vector2(zone_start, 0), Vector2(zone_start, target_zone_visual.size.y), Color(0, 1, 0, 0.8), 2.0)
	target_zone_visual.draw_line(Vector2(zone_start + zone_width, 0), Vector2(zone_start + zone_width, target_zone_visual.size.y), Color(0, 1, 0, 0.8), 2.0)

func _check_success() -> void:
	"""Check if spacebar was pressed in the target zone"""
	if not target_zone_visual.has_meta("target_start"):
		return

	var target_start = target_zone_visual.get_meta("target_start") as float
	var target_end = target_zone_visual.get_meta("target_end") as float

	var success = bar_value >= target_start and bar_value <= target_end

	is_filling = false
	current_attempt_active = false

	if success:
		status_label.text = "✓ Success!"
		status_label.add_theme_color_override("font_color", Color.GREEN)
		await get_tree().create_timer(0.5).timeout
		current_successes += 1
	else:
		status_label.text = "✗ Miss!"
		status_label.add_theme_color_override("font_color", Color.RED)
		await get_tree().create_timer(0.5).timeout

	attempt_completed.emit(success)

func _fail_attempt() -> void:
	"""Called when bar fills completely"""
	is_filling = false
	current_attempt_active = false

	status_label.text = "✗ Bar filled - Miss!"
	status_label.add_theme_color_override("font_color", Color.RED)

	await get_tree().create_timer(0.5).timeout
	attempt_completed.emit(false)
