extends Control

## CookingModal - Cooking system UI
## Player can combine food items to create cooked meals
## Discovered recipes can be auto-cooked from the recipe list

signal modal_closed

# UI references
@onready var _title_label: Label
@onready var _close_button: Button


func _ready():
	# Create UI structure dynamically
	_build_ui()
	
	# IMPORTANT: Force mouse to be visible when modal opens
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Show the modal centered
	show()


func _process(_delta):
	"""Continuously enforce mouse visibility"""
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _build_ui():
	# Main panel background
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(900, 600)
	panel.focus_mode = Control.FOCUS_NONE
	add_child(panel)
	
	# Main vertical layout
	var main_vbox = VBoxContainer.new()
	main_vbox.anchor_right = 1.0
	main_vbox.anchor_bottom = 1.0
	main_vbox.offset_left = 20
	main_vbox.offset_top = 20
	main_vbox.offset_right = -20
	main_vbox.offset_bottom = -20
	panel.add_child(main_vbox)
	
	# Header HBox (title + close button)
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)
	
	# Title
	_title_label = Label.new()
	_title_label.text = "🍳 Cooking Station"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(_title_label)
	
	# Close button (X)
	_close_button = Button.new()
	_close_button.text = "✕"
	_close_button.custom_minimum_size = Vector2(40, 40)
	_close_button.add_theme_font_size_override("font_size", 24)
	_close_button.pressed.connect(_on_close_pressed)
	header_hbox.add_child(_close_button)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(spacer1)
	
	# Instructions
	var instructions = Label.new()
	instructions.text = "Select ingredients to cook delicious meals"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(instructions)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(spacer2)
	
	# Content area (will be expanded in later steps)
	var content_label = Label.new()
	content_label.text = "[Cooking UI - Step 1 Complete]"
	content_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_label)
	
	# Center the panel
	panel.position = (get_viewport_rect().size - panel.custom_minimum_size) / 2


func _on_close_pressed():
	"""Handle close button click"""
	_close_modal()


func _close_modal():
	"""Close the modal and restore game controls"""
	print("CookingModal: Closing")
	
	# Restore mouse capture
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Emit signal for cleanup
	modal_closed.emit()
	
	# Remove from scene
	queue_free()


func _input(event: InputEvent):
	"""Handle ESC key to close modal"""
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_modal()
