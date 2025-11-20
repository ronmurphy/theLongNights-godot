extends Control

## CompanionRosterModal - UI for creating and managing companions
## Supports companion creation with race/gender/role selection and roster management
## Opened via 'roster shop' console command or NPC interaction

signal modal_closed
signal companion_created(companion_data: Dictionary)

# Shop type for consistency
enum ShopType {
	ROSTER
}

# UI nodes - LEFT COLUMN (Creation)
var _race_dropdown: OptionButton
var _gender_dropdown: OptionButton
var _role_dropdown: OptionButton
var _name_input: LineEdit
var _random_name_button: Button
var _add_button: Button

# UI nodes - CENTER COLUMN (Roster List)
var _roster_scroll_container: ScrollContainer
var _roster_vbox_container: VBoxContainer
var _companion_buttons: Array[Button] = []
var _roster_count_label: Label

# UI nodes - RIGHT COLUMN (Details)
var _details_panel: Panel
var _avatar_texture: TextureRect
var _weapon_texture_display: TextureRect
var _accessory_texture_display: TextureRect
var _hp_bar: ProgressBar
var _hp_label: Label
var _atk_label: Label
var _def_label: Label
var _name_label: Label
var _race_label: Label
var _gender_label: Label
var _role_label: Label
var _level_label: Label
var _equip_button: Button
var _remove_button: Button

# State
var _selected_companion_index: int = -1
var _selected_button: Button = null
var _main_panel: Panel

# Reference nodes
var _companion_manager: Node = null

# Name pools for random generation
var _name_pools = {
	"human": {
		"male": ["Marcus", "Thomas", "James", "David", "Michael", "Richard", "Samuel", "Henry"],
		"female": ["Elena", "Sarah", "Margaret", "Catherine", "Emma", "Elizabeth", "Victoria", "Anna"]
	},
	"elf": {
		"male": ["Aelindor", "Faelar", "Theron", "Lysander", "Aldaron", "Elorian", "Silvus", "Elarian"],
		"female": ["Lyralei", "Sylvara", "Elowen", "Aelara", "Istara", "Meriel", "Ayleth", "Nessa"]
	},
	"dwarf": {
		"male": ["Borin", "Thrain", "Thorin", "Gunnar", "Balin", "Dwalin", "Gloin", "Oin"],
		"female": ["Helga", "Katrin", "Dori", "Sigrid", "Edith", "Marta", "Brynhildr", "Greta"]
	},
	"goblin": {
		"male": ["Zikk", "Grix", "Squik", "Blinker", "Squeek", "Sneak", "Zip", "Grat"],
		"female": ["Nixie", "Snick", "Squeak", "Fizz", "Zing", "Skitter", "Pip", "Zilla"]
	}
}

const MODAL_WIDTH = 1100
const MODAL_HEIGHT = 650
const LEFT_PANEL_WIDTH = 180
const CENTER_PANEL_WIDTH = 280
const RIGHT_PANEL_WIDTH = 580


func _ready() -> void:
	# Get companion manager reference (it's an AutoLoad)
	_companion_manager = CompanionManager
	print("🔍 CompanionRosterModal._ready() - Getting CompanionManager (AutoLoad)")
	print("   Found: %s" % (_companion_manager != null))
	if _companion_manager:
		print("   Companion count: %d" % _companion_manager.get_companion_count())
		print("   Active companion index: %d" % _companion_manager.active_companion_index)

	if not _companion_manager:
		push_error("CompanionRosterModal: Could not find CompanionManager")
		queue_free()
		return

	# Wait a frame for CompanionManager to finish initialization/conversion
	await get_tree().process_frame
	print("🔍 After process_frame - Companion count: %d" % _companion_manager.get_companion_count())

	# Initialize roster from legacy if needed (same as GameConsole does)
	if not _companion_manager.using_roster_system:
		print("🔄 Converting legacy companion to roster system...")
		_companion_manager.initialize_roster_from_legacy()
		# Save the converted roster immediately
		_companion_manager.save_to_file()

	print("🔍 After legacy conversion - Companion count: %d" % _companion_manager.get_companion_count())

	# Build UI
	_build_ui()
	_populate_roster_list()

	# Show mouse cursor
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Center modal
	await get_tree().process_frame
	var viewport_size = get_viewport_rect().size
	_main_panel.position = (viewport_size - _main_panel.size) / 2


func _process(_delta: float) -> void:
	# Force mouse to stay visible while modal is open
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	# Close on ESC
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_modal()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	# Main panel with dark brown background + golden border (matching shop style)
	_main_panel = Panel.new()
	_main_panel.custom_minimum_size = Vector2(MODAL_WIDTH, MODAL_HEIGHT)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.1, 0.05, 0.95)  # Dark brown
	panel_style.set_border_width_all(3)
	panel_style.border_color = Color(0.8, 0.6, 0.2, 1.0)  # Golden border
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	_main_panel.add_theme_stylebox_override("panel", panel_style)

	add_child(_main_panel)

	# Main vertical layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	_main_panel.add_child(vbox)

	# Add margins
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	vbox.add_child(margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(content_vbox)

	# Title
	var title = Label.new()
	title.text = "🎭 Companion Recruitment"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Create and manage your companion roster"
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(subtitle)

	# Separator
	var separator1 = HSeparator.new()
	separator1.add_theme_constant_override("separation", 2)
	content_vbox.add_child(separator1)

	# Three-column main area
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 10)
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(main_hbox)

	# LEFT COLUMN: Creation controls
	_build_left_column(main_hbox)

	# CENTER COLUMN: Roster list
	_build_center_column(main_hbox)

	# RIGHT COLUMN: Companion details
	_build_right_column(main_hbox)

	# Separator
	var separator2 = HSeparator.new()
	separator2.add_theme_constant_override("separation", 2)
	content_vbox.add_child(separator2)

	# Bottom buttons
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 12)
	content_vbox.add_child(button_hbox)

	var close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(120, 40)
	close_button.pressed.connect(_close_modal)
	button_hbox.add_child(close_button)


func _build_left_column(parent: HBoxContainer) -> void:
	"""Build the left column with creation controls"""
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(LEFT_PANEL_WIDTH, 0)
	left_vbox.add_theme_constant_override("separation", 8)
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(left_vbox)

	# Title
	var left_title = Label.new()
	left_title.text = "Create Companion"
	left_title.add_theme_font_size_override("font_size", 14)
	left_title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	left_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(left_title)

	# Race dropdown
	var race_label = Label.new()
	race_label.text = "Race"
	race_label.add_theme_font_size_override("font_size", 11)
	race_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	left_vbox.add_child(race_label)

	_race_dropdown = OptionButton.new()
	_race_dropdown.add_item("Human", 0)
	_race_dropdown.add_item("Elf", 1)
	_race_dropdown.add_item("Dwarf", 2)
	_race_dropdown.add_item("Goblin", 3)
	_race_dropdown.custom_minimum_size = Vector2(0, 30)
	left_vbox.add_child(_race_dropdown)

	# Gender dropdown
	var gender_label = Label.new()
	gender_label.text = "Gender"
	gender_label.add_theme_font_size_override("font_size", 11)
	gender_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	left_vbox.add_child(gender_label)

	_gender_dropdown = OptionButton.new()
	_gender_dropdown.add_item("Male", 0)
	_gender_dropdown.add_item("Female", 1)
	_gender_dropdown.custom_minimum_size = Vector2(0, 30)
	left_vbox.add_child(_gender_dropdown)

	# Role dropdown
	var role_label = Label.new()
	role_label.text = "Role"
	role_label.add_theme_font_size_override("font_size", 11)
	role_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	left_vbox.add_child(role_label)

	_role_dropdown = OptionButton.new()
	_role_dropdown.add_item("Tank", 0)
	_role_dropdown.add_item("Healer", 1)
	_role_dropdown.add_item("Rogue", 2)
	_role_dropdown.add_item("Wizard", 3)
	_role_dropdown.custom_minimum_size = Vector2(0, 30)
	left_vbox.add_child(_role_dropdown)

	# Name controls
	var name_label = Label.new()
	name_label.text = "Name"
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	left_vbox.add_child(name_label)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Enter name..."
	_name_input.custom_minimum_size = Vector2(0, 30)
	_name_input.text = _get_random_name()
	left_vbox.add_child(_name_input)

	# Random name button
	_random_name_button = Button.new()
	_random_name_button.text = "🎲 Random"
	_random_name_button.custom_minimum_size = Vector2(0, 30)
	_random_name_button.pressed.connect(_on_random_name_pressed)
	left_vbox.add_child(_random_name_button)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	left_vbox.add_child(spacer)

	# Add button
	_add_button = Button.new()
	_add_button.text = "+ Add"
	_add_button.custom_minimum_size = Vector2(0, 40)
	_add_button.add_theme_font_size_override("font_size", 12)
	_add_button.pressed.connect(_on_add_companion)
	left_vbox.add_child(_add_button)


func _build_center_column(parent: HBoxContainer) -> void:
	"""Build the center column with roster list"""
	var center_vbox = VBoxContainer.new()
	center_vbox.custom_minimum_size = Vector2(CENTER_PANEL_WIDTH, 0)
	center_vbox.add_theme_constant_override("separation", 6)
	center_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(center_vbox)

	# Title with count
	var center_title = Label.new()
	center_title.text = "Roster"
	center_title.add_theme_font_size_override("font_size", 14)
	center_title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	center_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_vbox.add_child(center_title)

	_roster_count_label = Label.new()
	_roster_count_label.text = "0/12 Companions"
	_roster_count_label.add_theme_font_size_override("font_size", 10)
	_roster_count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_roster_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_vbox.add_child(_roster_count_label)

	# Roster list panel
	var roster_panel = PanelContainer.new()
	roster_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_vbox.add_child(roster_panel)

	_roster_scroll_container = ScrollContainer.new()
	_roster_scroll_container.name = "RosterListContainer"
	_roster_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roster_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_scroll_container.focus_mode = Control.FOCUS_NONE
	roster_panel.add_child(_roster_scroll_container)

	_roster_vbox_container = VBoxContainer.new()
	_roster_vbox_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_scroll_container.add_child(_roster_vbox_container)


func _build_right_column(parent: HBoxContainer) -> void:
	"""Build the right column with companion details"""
	var right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(RIGHT_PANEL_WIDTH, 0)
	right_vbox.add_theme_constant_override("separation", 8)
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(right_vbox)

	# Title
	var right_title = Label.new()
	right_title.text = "Companion Details"
	right_title.add_theme_font_size_override("font_size", 14)
	right_title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	right_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(right_title)

	# Avatar and Equipment panel - FULL HEIGHT
	_details_panel = Panel.new()
	_details_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var details_style = StyleBoxFlat.new()
	details_style.bg_color = Color(0.1, 0.07, 0.03, 0.8)
	details_style.set_border_width_all(2)
	details_style.border_color = Color(0.6, 0.4, 0.1, 0.8)
	details_style.corner_radius_top_left = 4
	details_style.corner_radius_top_right = 4
	details_style.corner_radius_bottom_left = 4
	details_style.corner_radius_bottom_right = 4
	_details_panel.add_theme_stylebox_override("panel", details_style)
	right_vbox.add_child(_details_panel)

	# Main 3-column layout with better spacing
	var details_hbox = HBoxContainer.new()
	details_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	details_hbox.add_theme_constant_override("separation", 12)
	details_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	_details_panel.add_child(details_hbox)

	# ============================================================
	# COLUMN 1: Avatar (left column, top-center aligned)
	# ============================================================
	var col1_container = VBoxContainer.new()
	col1_container.custom_minimum_size = Vector2(160, 0)
	col1_container.add_theme_constant_override("separation", 0)
	col1_container.alignment = BoxContainer.ALIGNMENT_BEGIN  # Top-aligned
	details_hbox.add_child(col1_container)

	var col1_margin = MarginContainer.new()
	col1_margin.add_theme_constant_override("margin_left", 8)
	col1_margin.add_theme_constant_override("margin_top", 8)
	col1_margin.add_theme_constant_override("margin_right", 8)
	col1_margin.add_theme_constant_override("margin_bottom", 8)
	col1_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col1_container.add_child(col1_margin)

	_avatar_texture = TextureRect.new()
	_avatar_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_avatar_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	col1_margin.add_child(_avatar_texture)

	# ============================================================
	# COLUMN 2: Equipment & Stats (center column, top-center aligned)
	# ============================================================
	var col2_container = VBoxContainer.new()
	col2_container.custom_minimum_size = Vector2(140, 0)
	col2_container.add_theme_constant_override("separation", 8)
	col2_container.alignment = BoxContainer.ALIGNMENT_BEGIN  # Top-aligned
	details_hbox.add_child(col2_container)

	var col2_margin = MarginContainer.new()
	col2_margin.add_theme_constant_override("margin_top", 8)
	col2_margin.add_theme_constant_override("margin_bottom", 8)
	col2_container.add_child(col2_margin)

	var col2_vbox = VBoxContainer.new()
	col2_vbox.add_theme_constant_override("separation", 8)
	col2_margin.add_child(col2_vbox)

	var equipment_label = Label.new()
	equipment_label.text = "Equipment & Stats"
	equipment_label.add_theme_font_size_override("font_size", 11)
	equipment_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	equipment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col2_vbox.add_child(equipment_label)

	# Weapon section - centered
	var weapon_vbox = VBoxContainer.new()
	weapon_vbox.add_theme_constant_override("separation", 4)
	col2_vbox.add_child(weapon_vbox)

	var weapon_label = Label.new()
	weapon_label.text = "Weapon"
	weapon_label.add_theme_font_size_override("font_size", 10)
	weapon_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_vbox.add_child(weapon_label)

	var weapon_slot_center = CenterContainer.new()
	weapon_vbox.add_child(weapon_slot_center)

	var weapon_slot = Panel.new()
	weapon_slot.custom_minimum_size = Vector2(40, 40)
	var weapon_style = StyleBoxFlat.new()
	weapon_style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	weapon_style.set_border_width_all(1)
	weapon_style.border_color = Color(0.4, 0.3, 0.2, 1.0)
	weapon_slot.add_theme_stylebox_override("panel", weapon_style)
	weapon_slot_center.add_child(weapon_slot)

	var weapon_texture = TextureRect.new()
	weapon_texture.custom_minimum_size = Vector2(36, 36)
	weapon_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	weapon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	weapon_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_slot.add_child(weapon_texture)
	_weapon_texture_display = weapon_texture

	# Accessory section - centered
	var accessory_vbox = VBoxContainer.new()
	accessory_vbox.add_theme_constant_override("separation", 4)
	col2_vbox.add_child(accessory_vbox)

	var accessory_label = Label.new()
	accessory_label.text = "Accessory"
	accessory_label.add_theme_font_size_override("font_size", 10)
	accessory_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	accessory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	accessory_vbox.add_child(accessory_label)

	var accessory_slot_center = CenterContainer.new()
	accessory_vbox.add_child(accessory_slot_center)

	var accessory_slot = Panel.new()
	accessory_slot.custom_minimum_size = Vector2(40, 40)
	var accessory_style = StyleBoxFlat.new()
	accessory_style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	accessory_style.set_border_width_all(1)
	accessory_style.border_color = Color(0.4, 0.3, 0.2, 1.0)
	accessory_slot.add_theme_stylebox_override("panel", accessory_style)
	accessory_slot_center.add_child(accessory_slot)

	var accessory_texture = TextureRect.new()
	accessory_texture.custom_minimum_size = Vector2(36, 36)
	accessory_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	accessory_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	accessory_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	accessory_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accessory_slot.add_child(accessory_texture)
	_accessory_texture_display = accessory_texture

	# HP Bar - centered
	var hp_center = CenterContainer.new()
	col2_vbox.add_child(hp_center)

	var hp_container = Control.new()
	hp_container.custom_minimum_size = Vector2(100, 24)
	hp_center.add_child(hp_container)

	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0
	_hp_bar.max_value = 100
	_hp_bar.value = 100
	_hp_bar.custom_minimum_size = Vector2(100, 18)
	_hp_bar.show_percentage = false
	_hp_bar.add_theme_stylebox_override("fill", _create_hp_bar_style(Color.GREEN))
	hp_container.add_child(_hp_bar)

	_hp_label = Label.new()
	_hp_label.text = "100/100 HP"
	_hp_label.add_theme_font_size_override("font_size", 10)
	_hp_label.add_theme_color_override("font_color", Color.WHITE)
	_hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hp_label.add_theme_constant_override("outline_size", 2)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.position = Vector2(0, 0)
	_hp_label.size = Vector2(100, 18)
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_container.add_child(_hp_label)

	# Stats - centered
	var stats_center = CenterContainer.new()
	col2_vbox.add_child(stats_center)

	var stats_hbox = HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 8)
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_center.add_child(stats_hbox)

	_atk_label = Label.new()
	_atk_label.text = "ATK: +0"
	_atk_label.add_theme_font_size_override("font_size", 9)
	_atk_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	stats_hbox.add_child(_atk_label)

	_def_label = Label.new()
	_def_label.text = "DEF: 0"
	_def_label.add_theme_font_size_override("font_size", 9)
	_def_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	stats_hbox.add_child(_def_label)

	# ============================================================
	# COLUMN 3: Companion Info (right column, top-center aligned)
	# ============================================================
	var col3_container = VBoxContainer.new()
	col3_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col3_container.add_theme_constant_override("separation", 0)
	col3_container.alignment = BoxContainer.ALIGNMENT_BEGIN  # Top-aligned
	details_hbox.add_child(col3_container)

	var col3_margin = MarginContainer.new()
	col3_margin.add_theme_constant_override("margin_top", 8)
	col3_margin.add_theme_constant_override("margin_bottom", 8)
	col3_margin.add_theme_constant_override("margin_left", 8)
	col3_margin.add_theme_constant_override("margin_right", 8)
	col3_container.add_child(col3_margin)

	# Info labels - all centered
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 6)
	col3_margin.add_child(info_vbox)

	_name_label = Label.new()
	_name_label.text = "No companion selected"
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(_name_label)

	_race_label = Label.new()
	_race_label.text = ""
	_race_label.add_theme_font_size_override("font_size", 11)
	_race_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_race_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(_race_label)

	_gender_label = Label.new()
	_gender_label.text = ""
	_gender_label.add_theme_font_size_override("font_size", 11)
	_gender_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_gender_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(_gender_label)

	_role_label = Label.new()
	_role_label.text = ""
	_role_label.add_theme_font_size_override("font_size", 11)
	_role_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(_role_label)

	_level_label = Label.new()
	_level_label.text = ""
	_level_label.add_theme_font_size_override("font_size", 11)
	_level_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(_level_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	right_vbox.add_child(spacer)

	# Action buttons
	var button_vbox = VBoxContainer.new()
	button_vbox.add_theme_constant_override("separation", 6)
	right_vbox.add_child(button_vbox)

	_equip_button = Button.new()
	_equip_button.text = "⚔️ Equip"
	_equip_button.custom_minimum_size = Vector2(0, 36)
	_equip_button.disabled = true
	_equip_button.pressed.connect(_on_equip_companion)
	button_vbox.add_child(_equip_button)

	_remove_button = Button.new()
	_remove_button.text = "🗑️ Remove"
	_remove_button.custom_minimum_size = Vector2(0, 36)
	_remove_button.disabled = true
	_remove_button.pressed.connect(_on_remove_companion)
	button_vbox.add_child(_remove_button)


func _populate_roster_list() -> void:
	"""Populate the roster list with current companions"""
	print("📋 _populate_roster_list() called")
	print("   _companion_manager: %s" % (_companion_manager != null))

	# Clear existing buttons
	for button in _companion_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_companion_buttons.clear()

	var count = _companion_manager.get_companion_count()
	print("   Companion count: %d" % count)
	_roster_count_label.text = "%d/12 Companions" % count

	if count == 0:
		print("   No companions found - showing empty message")
		var empty_label = Label.new()
		empty_label.text = "No companions yet"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_roster_vbox_container.add_child(empty_label)
		return

	# Create button for each companion
	for i in range(count):
		var comp = _companion_manager.companion_roster[i]
		var is_active = i == _companion_manager.active_companion_index

		var button = Button.new()
		button.custom_minimum_size = Vector2(0, 50)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT

		# Determine status indicator
		var status_icon = "✓" if is_active else "○"
		var button_text = "%s %s (%s %s)" % [status_icon, comp.companion_name, comp.race.capitalize(), comp.role.capitalize()]

		button.text = button_text
		button.pressed.connect(_on_companion_selected.bind(i, button))

		# Style button
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.2, 0.15, 0.1, 0.8)
		normal_style.set_border_width_all(2)
		normal_style.border_color = Color(0.4, 0.3, 0.2, 1.0)
		normal_style.corner_radius_top_left = 4
		normal_style.corner_radius_top_right = 4
		normal_style.corner_radius_bottom_left = 4
		normal_style.corner_radius_bottom_right = 4
		button.add_theme_stylebox_override("normal", normal_style)

		var hover_style = normal_style.duplicate()
		hover_style.bg_color = Color(0.25, 0.2, 0.13, 0.9)
		hover_style.border_color = Color(0.6, 0.5, 0.3, 1.0)
		button.add_theme_stylebox_override("hover", hover_style)

		_roster_vbox_container.add_child(button)
		_companion_buttons.append(button)


func _on_companion_selected(index: int, button: Button) -> void:
	"""Handle companion list selection"""
	_selected_companion_index = index

	# Remove highlight from previous button
	if _selected_button and is_instance_valid(_selected_button):
		_selected_button.modulate = Color(1.0, 1.0, 1.0)

	# Highlight selected button
	button.modulate = Color(0.7, 1.0, 0.7)
	_selected_button = button

	# Update details panel
	_update_details_panel(index)

	# Enable action buttons
	_equip_button.disabled = false
	_remove_button.disabled = false


func _update_details_panel(index: int) -> void:
	"""Update the right panel with selected companion details"""
	if index < 0 or index >= _companion_manager.get_companion_count():
		_name_label.text = "No companion selected"
		_race_label.text = ""
		_gender_label.text = ""
		_role_label.text = ""
		_level_label.text = ""
		_avatar_texture.texture = null
		_weapon_texture_display.texture = null
		_accessory_texture_display.texture = null
		_hp_label.text = "0/0 HP"
		_atk_label.text = "ATK: +0"
		_def_label.text = "DEF: 0"
		return

	var comp = _companion_manager.companion_roster[index]

	# Update labels
	_name_label.text = comp.companion_name
	_race_label.text = "%s" % comp.race.capitalize()
	_gender_label.text = "%s" % comp.gender.capitalize()
	_role_label.text = "Role: %s" % comp.role.capitalize()
	_level_label.text = "Level %d" % comp.level

	# Load avatar texture based on race/gender
	var avatar_path = "res://assets/art/player_avatars/%s_%s.png" % [comp.race, comp.gender]
	if ResourceLoader.exists(avatar_path):
		_avatar_texture.texture = load(avatar_path)
	else:
		_avatar_texture.texture = null

	# Load equipped weapon and accessory textures
	_load_equipped_item_textures(comp)

	# Update HP and stats
	_update_companion_stats(comp)


func _on_add_companion() -> void:
	"""Add a new companion to the roster"""
	var race_index = _race_dropdown.get_selected_id()
	var gender_index = _gender_dropdown.get_selected_id()
	var role_index = _role_dropdown.get_selected_id()
	var name_text = _name_input.text.strip_edges()

	# Validate inputs
	if name_text.is_empty():
		name_text = _get_random_name()

	# Map dropdown indices to values
	var races = ["human", "elf", "dwarf", "goblin"]
	var genders = ["male", "female"]
	var roles = ["tank", "healer", "rogue", "wizard"]

	var race = races[race_index]
	var gender = genders[gender_index]
	var role = roles[role_index]

	# Create companion data
	var comp = _companion_manager.CompanionData.new()
	comp.companion_name = name_text
	comp.race = race
	comp.gender = gender
	comp.role = role
	comp.is_active = false

	# Add to roster
	_companion_manager.add_companion_to_roster(comp)

	# Debug: Check active_companion_index before save
	print("🔍 Before save - active_companion_index: %d, roster size: %d" % [_companion_manager.active_companion_index, _companion_manager.get_companion_count()])

	# Save to file immediately so new companions persist
	_companion_manager.save_to_file()

	# Debug: Check after save
	print("🔍 After save - active_companion_index: %d" % _companion_manager.active_companion_index)

	# Spawn as NPC at home base if home base is set
	var home_base = get_node_or_null("/root/HomeBaseManager")
	if home_base and home_base.has_home_base:
		home_base.add_benched_companion_npc(comp)

	# Refresh roster list
	_populate_roster_list()

	# Reset creation controls
	_name_input.text = _get_random_name()

	# Show feedback
	print("✓ Added %s to roster!" % name_text)


func _on_random_name_pressed() -> void:
	"""Generate a random name based on current selections"""
	_name_input.text = _get_random_name()


func _get_random_name() -> String:
	"""Generate a random name based on current race/gender selections"""
	var race_index = _race_dropdown.get_selected_id()
	var gender_index = _gender_dropdown.get_selected_id()

	var races = ["human", "elf", "dwarf", "goblin"]
	var genders = ["male", "female"]

	var race = races[race_index]
	var gender = genders[gender_index]

	var name_pool = _name_pools.get(race, {}).get(gender, ["Companion"])
	return name_pool[randi() % name_pool.size()]


func _on_equip_companion() -> void:
	"""Swap to selected companion"""
	if _selected_companion_index < 0:
		return

	# Swap companion
	if not _companion_manager.swap_to_companion(_selected_companion_index):
		print("Failed to equip companion")
		return

	# Despawn existing live companions
	var live = get_tree().get_nodes_in_group("companions")
	for node in live:
		node.queue_free()

	# Spawn new companion in-world
	var game = get_node_or_null("/root/Main/Game")
	if game and game.has_method("_spawn_companion"):
		game._spawn_companion()

	# Update benched NPCs at home base
	var home_base = get_node_or_null("/root/HomeBaseManager")
	if home_base and home_base.has_method("_relocate_benched_companions"):
		home_base._relocate_benched_companions()

	_companion_manager.save_to_file()

	# Refresh roster list to show new active status
	_populate_roster_list()

	# Update details
	_update_details_panel(_selected_companion_index)

	print("✓ Equipped companion at index %d" % _selected_companion_index)


func _on_remove_companion() -> void:
	"""Remove selected companion from roster"""
	if _selected_companion_index < 0:
		return

	var comp_name = _companion_manager.companion_roster[_selected_companion_index].companion_name

	if _companion_manager.remove_companion_from_roster(_selected_companion_index):
		# Refresh home NPCs
		var home_base = get_node_or_null("/root/HomeBaseManager")
		if home_base and home_base.has_method("_relocate_benched_companions"):
			home_base._relocate_benched_companions()

		# Refresh roster list
		_populate_roster_list()

		# Clear details panel
		_selected_companion_index = -1
		_selected_button = null
		_update_details_panel(-1)
		_equip_button.disabled = true
		_remove_button.disabled = true

		print("✓ Removed %s from roster" % comp_name)
	else:
		print("Failed to remove companion")


func _load_equipped_item_textures(comp: Variant) -> void:
	"""Load and display equipped weapon and accessory item textures"""
	var item_db = get_node_or_null("/root/Main/Game/Items")
	if not item_db:
		_weapon_texture_display.texture = null
		_accessory_texture_display.texture = null
		return

	# Clear textures first
	_weapon_texture_display.texture = null
	_accessory_texture_display.texture = null

	# Load weapon texture based on companion's equipped weapon
	if comp.equipped_weapon_id >= 0:
		var weapon_item = item_db.get_item(comp.equipped_weapon_id)
		if weapon_item and weapon_item.base_info and weapon_item.base_info.sprite:
			_weapon_texture_display.texture = weapon_item.base_info.sprite
	else:
		# Get default weapon for this race/role combo
		var default_weapon_id = _get_default_weapon_for_companion(comp)
		if default_weapon_id >= 0:
			var weapon_item = item_db.get_item(default_weapon_id)
			if weapon_item and weapon_item.base_info and weapon_item.base_info.sprite:
				_weapon_texture_display.texture = weapon_item.base_info.sprite

	# Load accessory texture (if companion has one equipped)
	if comp.equipped_accessory_id >= 0:
		var accessory_item = item_db.get_item(comp.equipped_accessory_id)
		if accessory_item and accessory_item.base_info and accessory_item.base_info.sprite:
			_accessory_texture_display.texture = accessory_item.base_info.sprite


func _get_default_weapon_for_companion(comp: Variant) -> int:
	"""Get the default weapon ID for companion's race (matches inventory logic)"""
	match comp.race:
		"dwarf":
			return 7  # stone_hammer
		"elf":
			return 9  # crossbow
		"goblin":
			if comp.gender == "female":
				return 5  # throwing_knives
			else:
				return 0  # rocket_launcher
		"human":
			return 8  # machete
	return -1


func _update_companion_stats(comp: Variant) -> void:
	"""Update HP bar and stats display for companion"""
	# Get HP values
	var max_hp = _companion_manager.get_companion_max_hp()
	var current_hp = max_hp  # Default to full HP

	# Try to get actual HP from live companion in world
	var live_companions = get_tree().get_nodes_in_group("companions")
	if live_companions.size() > 0:
		var comp_node = live_companions[0]
		if comp_node and typeof(comp_node.current_hp) in [TYPE_INT, TYPE_FLOAT]:
			current_hp = comp_node.current_hp
			var comp_max = comp_node.get("max_hp")
			if comp_max != null:
				max_hp = comp_max

	# Update HP bar
	if max_hp > 0:
		_hp_bar.max_value = max_hp
		_hp_bar.value = current_hp

		# Update HP bar color based on health percentage
		var hp_percent = float(current_hp) / float(max_hp)
		if hp_percent > 0.5:
			_hp_bar.add_theme_stylebox_override("fill", _create_hp_bar_style(Color.GREEN))
		elif hp_percent > 0.25:
			_hp_bar.add_theme_stylebox_override("fill", _create_hp_bar_style(Color.YELLOW))
		else:
			_hp_bar.add_theme_stylebox_override("fill", _create_hp_bar_style(Color.RED))

		_hp_label.text = "%d/%d HP" % [current_hp, max_hp]
	else:
		_hp_label.text = "0/0 HP"

	# Update stats
	var atk_bonus = _companion_manager.get_companion_attack_bonus()
	var defense = _companion_manager.get_companion_defense()

	_atk_label.text = "ATK: +%d" % atk_bonus
	_def_label.text = "DEF: %d" % defense


func _create_hp_bar_style(color: Color) -> StyleBoxFlat:
	"""Create a styled ProgressBar fill"""
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	return style


func _close_modal() -> void:
	"""Close the modal"""
	modal_closed.emit()
	queue_free()
