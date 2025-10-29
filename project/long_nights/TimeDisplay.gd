extends Control
## TimeDisplay - Shows current time, day, and bloodmoon status
## UI overlay for The Long Nights

var time_label: Label
var day_label: Label
var bloodmoon_warning: Label
var coord_label: Label
var _player: Node3D = null

func _ready() -> void:
	# Create labels if not in scene tree
	if not time_label:
		time_label = Label.new()
		time_label.name = "TimeLabel"
		add_child(time_label)

	if not day_label:
		day_label = Label.new()
		day_label.name = "DayLabel"
		add_child(day_label)

	if not bloodmoon_warning:
		bloodmoon_warning = Label.new()
		bloodmoon_warning.name = "BloodmoonWarning"
		add_child(bloodmoon_warning)
	
	if not coord_label:
		coord_label = Label.new()
		coord_label.name = "CoordLabel"
		add_child(coord_label)

	# Style labels
	_setup_labels()

	# Connect to TimeManager
	TimeManager.hour_changed.connect(_on_time_changed)
	TimeManager.day_changed.connect(_on_day_changed)
	TimeManager.bloodmoon_started.connect(_on_bloodmoon_started)
	TimeManager.bloodmoon_ended.connect(_on_bloodmoon_ended)

	# Find player
	_find_player()

	# Initial update
	_update_display()

	print("TimeDisplay: UI ready")

func _find_player() -> void:
	# Try to find the player by group first (most reliable)
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]
		print("TimeDisplay: Found player in 'player' group")
		return
	
	# Try to find the player/avatar in the scene tree
	var player_node = get_node_or_null("/root/Main/Game/CharacterAvatar")
	if player_node:
		_player = player_node
		print("TimeDisplay: Found player at CharacterAvatar")
		return
	
	# Try Players container
	var players_container = get_node_or_null("/root/Main/Game/Players")
	if players_container and players_container.get_child_count() > 0:
		_player = players_container.get_child(0)
		print("TimeDisplay: Found player in Players container")
		return
	
	print("TimeDisplay: Could not find player node")

func _setup_labels() -> void:
	# Get viewport size for positioning
	var viewport_size = get_viewport_rect().size

	# Time label (top-right corner)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.position = Vector2(viewport_size.x - 250, 10)
	time_label.size = Vector2(240, 30)
	time_label.add_theme_font_size_override("font_size", 20)
	time_label.add_theme_color_override("font_color", Color.WHITE)
	time_label.add_theme_color_override("font_outline_color", Color.BLACK)
	time_label.add_theme_constant_override("outline_size", 2)

	# Day label (below time)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	day_label.position = Vector2(viewport_size.x - 350, 35)
	day_label.size = Vector2(340, 30)
	day_label.add_theme_font_size_override("font_size", 18)
	day_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	day_label.add_theme_color_override("font_outline_color", Color.BLACK)
	day_label.add_theme_constant_override("outline_size", 2)

	# Bloodmoon warning (center-top)
	bloodmoon_warning.position = Vector2(400, 20)  # Will adjust based on screen
	bloodmoon_warning.add_theme_font_size_override("font_size", 32)
	bloodmoon_warning.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	bloodmoon_warning.add_theme_color_override("font_outline_color", Color.BLACK)
	bloodmoon_warning.add_theme_constant_override("outline_size", 3)
	bloodmoon_warning.visible = false
	
	# Coordinate label (top-left corner)
	coord_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	coord_label.position = Vector2(10, 10)
	coord_label.size = Vector2(300, 30)
	coord_label.add_theme_font_size_override("font_size", 16)
	coord_label.add_theme_color_override("font_color", Color.WHITE)
	coord_label.add_theme_color_override("font_outline_color", Color.BLACK)
	coord_label.add_theme_constant_override("outline_size", 2)

func _on_time_changed(_hour: int) -> void:
	_update_display()

func _on_day_changed(_day: int) -> void:
	_update_display()

func _update_display() -> void:
	# Format time
	var hour = TimeManager.current_hour
	var meridiem = "AM" if hour < 12 else "PM"
	var display_hour = hour if hour <= 12 else hour - 12
	if display_hour == 0:
		display_hour = 12

	time_label.text = "%d:00 %s" % [display_hour, meridiem]

	# Format day
	var day_name = TimeManager.get_day_name()
	day_label.text = "Week %d - %s (Day %d/7)" % [
		TimeManager.current_week,
		day_name,
		TimeManager.current_day
	]

func _on_bloodmoon_started() -> void:
	bloodmoon_warning.text = "🩸 BLOOD MOON 🩸"
	bloodmoon_warning.visible = true

	# Center the warning
	var screen_size = get_viewport_rect().size
	bloodmoon_warning.position = Vector2(
		screen_size.x / 2 - 150,  # Approximate centering
		20
	)

func _on_bloodmoon_ended() -> void:
	bloodmoon_warning.visible = false

func _process(_delta: float) -> void:
	# Update coordinates
	if _player:
		var pos = _player.global_position
		coord_label.text = "Pos: X:%.0f Y:%.0f Z:%.0f" % [pos.x, pos.y, pos.z]
	else:
		# Try to find player if we don't have it yet
		if not _player:
			_find_player()
		coord_label.text = "Pos: ---"
	
	# Keep bloodmoon warning centered if screen resizes
	if bloodmoon_warning.visible:
		var screen_size = get_viewport_rect().size
		bloodmoon_warning.position = Vector2(
			screen_size.x / 2 - 150,
			20
		)
