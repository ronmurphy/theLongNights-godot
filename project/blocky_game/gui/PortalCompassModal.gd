extends Control

# Portal Compass Navigation Modal (Phase 4a - List View)
# Shows all visited ruins in a scrollable list
# Player can select a destination and teleport there

signal destination_selected(ruin_data: RuinRegistry.RuinData)
signal modal_closed

var _selected_ruin: RuinRegistry.RuinData = null
var _ruin_buttons: Array[Button] = []

@onready var _title_label: Label
@onready var _scroll_container: ScrollContainer
@onready var _ruin_list_container: VBoxContainer
@onready var _travel_button: Button
@onready var _cancel_button: Button


func _ready():
	# Create UI structure dynamically
	_build_ui()

	# Populate with visited ruins
	_populate_ruin_list()

	# Show the modal centered
	popup_centered()


func _build_ui():
	# Main panel background
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(500, 600)
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

	# Title
	_title_label = Label.new()
	_title_label.text = "🧭 Portal Compass - Select Destination"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	main_vbox.add_child(_title_label)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(spacer1)

	# Instructions label
	var instructions = Label.new()
	instructions.text = "Click a ruin to select your destination"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size", 14)
	main_vbox.add_child(instructions)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(spacer2)

	# Scroll container for ruin list
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.custom_minimum_size = Vector2(0, 400)
	main_vbox.add_child(_scroll_container)

	# VBox inside scroll for ruin buttons
	_ruin_list_container = VBoxContainer.new()
	_ruin_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(_ruin_list_container)

	# Spacer
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(spacer3)

	# Bottom buttons
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(button_hbox)

	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.custom_minimum_size = Vector2(120, 40)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	button_hbox.add_child(_cancel_button)

	# Spacer between buttons
	var button_spacer = Control.new()
	button_spacer.custom_minimum_size = Vector2(20, 0)
	button_hbox.add_child(button_spacer)

	_travel_button = Button.new()
	_travel_button.text = "Travel"
	_travel_button.custom_minimum_size = Vector2(120, 40)
	_travel_button.disabled = true  # Disabled until a ruin is selected
	_travel_button.pressed.connect(_on_travel_pressed)
	button_hbox.add_child(_travel_button)


func _populate_ruin_list():
	var visited_ruins = RuinRegistry.get_visited_ruins()

	if visited_ruins.is_empty():
		var no_ruins_label = Label.new()
		no_ruins_label.text = "No ruins visited yet.\nExplore more to unlock destinations!"
		no_ruins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_ruins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_ruin_list_container.add_child(no_ruins_label)
		return

	# Create a button for each visited ruin
	for ruin in visited_ruins:
		var ruin_button = Button.new()
		ruin_button.custom_minimum_size = Vector2(0, 50)
		ruin_button.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Build button text with portal type indicators
		var portal_icons = []
		for stone in ruin.teleport_stones:
			match stone.stone_type:
				RuinRegistry.StoneType.NORMAL:
					portal_icons.append("🔵")
				RuinRegistry.StoneType.RETURN:
					portal_icons.append("💚")
				RuinRegistry.StoneType.HOME:
					portal_icons.append("🟣")
				RuinRegistry.StoneType.COMBAT:
					portal_icons.append("🔴")

		var button_text = ruin.ruin_name + "  " + " ".join(portal_icons)

		# Add visit count info
		if ruin.visit_count > 1:
			button_text += "  (visited " + str(ruin.visit_count) + "x)"

		ruin_button.text = button_text

		# Store ruin data reference
		ruin_button.set_meta("ruin_data", ruin)

		# Connect button press
		ruin_button.pressed.connect(_on_ruin_selected.bind(ruin, ruin_button))

		_ruin_list_container.add_child(ruin_button)
		_ruin_buttons.append(ruin_button)


func _on_ruin_selected(ruin: RuinRegistry.RuinData, button: Button):
	"""Called when player clicks a ruin in the list"""
	_selected_ruin = ruin

	# Highlight selected button, unhighlight others
	for btn in _ruin_buttons:
		if btn == button:
			btn.modulate = Color(0.7, 1.0, 0.7)  # Green tint for selected
		else:
			btn.modulate = Color(1.0, 1.0, 1.0)  # Normal

	# Enable travel button
	_travel_button.disabled = false

	print("Selected destination: ", ruin.ruin_name)


func _on_travel_pressed():
	"""Called when player clicks Travel button"""
	if _selected_ruin == null:
		return

	# Emit signal with selected ruin
	destination_selected.emit(_selected_ruin)

	# Close modal
	queue_free()


func _on_cancel_pressed():
	"""Called when player clicks Cancel button"""
	modal_closed.emit()
	queue_free()


func popup_centered():
	"""Show the modal in the center of the screen"""
	# Center the control
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -250  # Half of width (500 / 2)
	offset_top = -300   # Half of height (600 / 2)
	offset_right = 250
	offset_bottom = 300

	# Make visible
	visible = true
