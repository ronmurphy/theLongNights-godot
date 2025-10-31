extends Control
## GameConsole - In-game debug console for The Long Nights
## Toggle with ~ (tilde) or F1
## Type 'help' for commands

@onready var console_panel: Panel
@onready var output_label: RichTextLabel
@onready var input_field: LineEdit

var is_visible: bool = false
var command_history: Array[String] = []
var history_index: int = -1
var max_output_lines: int = 20

# Command registry
var commands: Dictionary = {}

# Reference to player for input control
var _player_input_enabled: bool = true

func _ready() -> void:
	# Create UI elements
	_build_ui()

	# Register commands
	_register_commands()

	# Start hidden
	visible = false

	print("GameConsole: Ready (Press ~ or F1 to open)")

func _build_ui() -> void:
	# Main panel (bottom half of screen)
	console_panel = Panel.new()
	console_panel.name = "ConsolePanel"
	add_child(console_panel)

	# Style panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.85)
	panel_style.border_color = Color(0.3, 0.3, 0.3)
	panel_style.set_border_width_all(2)
	console_panel.add_theme_stylebox_override("panel", panel_style)

	# Output label (scrollable text area)
	output_label = RichTextLabel.new()
	output_label.name = "OutputLabel"
	output_label.bbcode_enabled = true
	output_label.scroll_following = true
	console_panel.add_child(output_label)

	# Input field (command entry)
	input_field = LineEdit.new()
	input_field.name = "InputField"
	input_field.placeholder_text = "Type 'help' for commands..."
	input_field.text_submitted.connect(_on_command_submitted)
	console_panel.add_child(input_field)

	# Style input
	input_field.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	input_field.add_theme_color_override("caret_color", Color.WHITE)

	_resize_console()

func _resize_console() -> void:
	var screen_size = get_viewport_rect().size

	# Panel takes bottom 40% of screen
	var panel_height = screen_size.y * 0.4
	console_panel.position = Vector2(0, screen_size.y - panel_height)
	console_panel.size = Vector2(screen_size.x, panel_height)

	# Output label fills most of panel
	output_label.position = Vector2(10, 10)
	output_label.size = Vector2(screen_size.x - 20, panel_height - 50)

	# Input field at bottom
	input_field.position = Vector2(10, panel_height - 35)
	input_field.size = Vector2(screen_size.x - 20, 30)

func _input(event: InputEvent) -> void:
	# Toggle console with ~ or F1
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_QUOTELEFT or event.keycode == KEY_F1:  # ~ or F1
			toggle_console()
			get_viewport().set_input_as_handled()

		# Screenshot with F2
		if event.keycode == KEY_F2:
			_take_screenshot()
			get_viewport().set_input_as_handled()

		# History navigation with up/down arrows
		if is_visible and input_field.has_focus():
			if event.keycode == KEY_UP:
				_history_up()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_DOWN:
				_history_down()
				get_viewport().set_input_as_handled()

	# Handle mouse wheel scrolling when console is open
	if is_visible and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			# Scroll up in console output
			var vscroll = output_label.get_v_scroll_bar()
			vscroll.value -= 20
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Scroll down in console output
			var vscroll = output_label.get_v_scroll_bar()
			vscroll.value += 20
			get_viewport().set_input_as_handled()

func toggle_console() -> void:
	is_visible = !is_visible
	visible = is_visible

	if is_visible:
		# Console opening - disable player input
		input_field.grab_focus()
		_disable_player_input()
		# Release mouse for typing
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		# Console closing - re-enable player input
		input_field.release_focus()
		_enable_player_input()
		# Recapture mouse for gameplay
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _disable_player_input() -> void:
	"""Disable player movement controls when console is open"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		if player and player.has_method("set_input_enabled"):
			player.set_input_enabled(false)
			_player_input_enabled = false


func _enable_player_input() -> void:
	"""Re-enable player movement controls when console is closed"""
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		if player and player.has_method("set_input_enabled"):
			player.set_input_enabled(true)
			_player_input_enabled = true

func _on_command_submitted(command: String) -> void:
	if command.strip_edges().is_empty():
		return

	# Add to history
	command_history.append(command)
	history_index = command_history.size()

	# Show command in output
	add_output("[color=cyan]> " + command + "[/color]")

	# Execute command
	_execute_command(command)

	# Clear input
	input_field.clear()

func _execute_command(command_text: String) -> void:
	var parts = command_text.strip_edges().split(" ", false)
	if parts.is_empty():
		return

	var cmd = parts[0].to_lower()
	var args = parts.slice(1)

	# Check if command exists
	if commands.has(cmd):
		commands[cmd].call(args)
	else:
		add_output("[color=red]Unknown command: " + cmd + "[/color]")
		add_output("[color=yellow]Type 'help' for available commands[/color]")

func add_output(text: String) -> void:
	output_label.append_text(text + "\n")

	# Limit output lines
	var line_count = output_label.get_line_count()
	if line_count > max_output_lines:
		# Remove old lines (not perfect but works)
		pass

func _history_up() -> void:
	if command_history.is_empty():
		return
	history_index = max(0, history_index - 1)
	input_field.text = command_history[history_index]
	input_field.caret_column = input_field.text.length()

func _history_down() -> void:
	if command_history.is_empty():
		return
	history_index = min(command_history.size(), history_index + 1)
	if history_index < command_history.size():
		input_field.text = command_history[history_index]
	else:
		input_field.text = ""
	input_field.caret_column = input_field.text.length()

## Register all available commands
func _register_commands() -> void:
	commands["help"] = _cmd_help
	commands["clear"] = _cmd_clear
	commands["time"] = _cmd_time
	commands["day"] = _cmd_day
	commands["week"] = _cmd_week
	commands["bloodmoon"] = _cmd_bloodmoon
	commands["fps"] = _cmd_fps
	commands["give"] = _cmd_give
	commands["list"] = _cmd_list
	commands["fog"] = _cmd_fog
	commands["graphics"] = _cmd_graphics
	commands["spawn"] = _cmd_spawn
	commands["damage"] = _cmd_damage
	commands["heal"] = _cmd_heal
	commands["hp"] = _cmd_hp
	commands["dialogue"] = _cmd_dialogue
	commands["dlg"] = _cmd_dialogue  # Short alias
	commands["testhunt"] = _cmd_testhunt
	commands["creative"] = _cmd_creative

## Commands Implementation

func _cmd_help(_args: Array) -> void:
	add_output("[color=lime]=== The Long Nights Console Commands ===[/color]")
	add_output("")
	add_output("[color=yellow]help[/color] - Show this help message")
	add_output("[color=yellow]clear[/color] - Clear console output")
	add_output("")
	add_output("[color=cyan]Time Commands:[/color]")
	add_output("  [color=yellow]time[/color] - Show current time")
	add_output("  [color=yellow]time set <hour>[/color] - Set time (0-23)")
	add_output("  [color=yellow]time add <hours>[/color] - Add hours to time")
	add_output("")
	add_output("[color=cyan]Day Commands:[/color]")
	add_output("  [color=yellow]day[/color] - Show current day")
	add_output("  [color=yellow]day set <day>[/color] - Set day (1-7)")
	add_output("  [color=yellow]day next[/color] - Skip to next day")
	add_output("")
	add_output("[color=cyan]Week Commands:[/color]")
	add_output("  [color=yellow]week[/color] - Show current week")
	add_output("  [color=yellow]week set <week>[/color] - Set week number")
	add_output("")
	add_output("[color=cyan]Bloodmoon Commands:[/color]")
	add_output("  [color=yellow]bloodmoon start[/color] - Trigger bloodmoon")
	add_output("  [color=yellow]bloodmoon stop[/color] - End bloodmoon")
	add_output("")
	add_output("[color=cyan]Item Commands:[/color]")
	add_output("  [color=yellow]list items[/color] - Show all available items")
	add_output("  [color=yellow]give <item_name> [amount][/color] - Give item to inventory")
	add_output("")
	add_output("[color=cyan]Graphics Commands:[/color]")
	add_output("  [color=yellow]graphics low[/color] - Set to LOW profile (50 chunks)")
	add_output("  [color=yellow]graphics medium[/color] - Set to MEDIUM profile (112 chunks)")
	add_output("  [color=yellow]graphics high[/color] - Set to HIGH profile (128 chunks)")
	add_output("")
	add_output("[color=cyan]Display Commands:[/color]")
	add_output("  [color=yellow]fps true[/color] - Show FPS counter")
	add_output("  [color=yellow]fps false[/color] - Hide FPS counter")
	add_output("  [color=yellow]fog true[/color] - Enable fog")
	add_output("  [color=yellow]fog false[/color] - Disable fog")
	add_output("")
	add_output("[color=cyan]Entity Commands:[/color]")
	add_output("  [color=yellow]spawn ghost[/color] - Spawn a friendly ghost companion")
	add_output("  [color=yellow]spawn rat[/color] - Spawn a tier 1 enemy (fast, weak)")
	add_output("  [color=yellow]spawn goblin[/color] - Spawn a tier 1 enemy (balanced)")
	add_output("  [color=yellow]spawn troglodyte[/color] - Spawn a tier 1 enemy (slow, tough)")
	add_output("")
	add_output("[color=cyan]Player Commands:[/color]")
	add_output("  [color=yellow]hp[/color] - Show current HP")
	add_output("  [color=yellow]damage <amount>[/color] - Damage player (for testing)")
	add_output("  [color=yellow]heal <amount>[/color] - Heal player")
	add_output("")
	add_output("[color=cyan]Dialogue Commands:[/color]")
	add_output("  [color=yellow]dialogue <id>[/color] - Trigger a dialogue (or 'dlg' for short)")
	add_output("  [color=yellow]dialogue reset[/color] - Reset dialogue progress")
	add_output("  [color=yellow]testhunt success/failure[/color] - Test hunt return dialogue")
	add_output("")
	add_output("[color=cyan]Build/Creative Commands:[/color]")
	add_output("  [color=yellow]creative on[/color] - Enable creative mode (instant block breaking, no collection)")
	add_output("  [color=yellow]creative off[/color] - Disable creative mode (return to normal mining)")

func _cmd_clear(_args: Array) -> void:
	output_label.clear()
	add_output("[color=lime]Console cleared[/color]")

func _cmd_time(args: Array) -> void:
	if args.is_empty():
		# Show current time
		var hour = TimeManager.current_hour
		var meridiem = "AM" if hour < 12 else "PM"
		var display_hour = hour if hour <= 12 else hour - 12
		if display_hour == 0:
			display_hour = 12
		add_output("[color=lime]Current time: %d:00 %s (Hour %d)[/color]" % [display_hour, meridiem, hour])
		return

	var subcmd = args[0].to_lower()

	if subcmd == "set":
		if args.size() < 2:
			add_output("[color=red]Usage: time set <hour>[/color]")
			return
		var hour = args[1].to_int()
		if hour < 0 or hour > 23:
			add_output("[color=red]Hour must be 0-23[/color]")
			return
		TimeManager.current_hour = hour
		TimeManager.hour_changed.emit(hour)
		add_output("[color=lime]Time set to hour %d[/color]" % hour)

	elif subcmd == "add":
		if args.size() < 2:
			add_output("[color=red]Usage: time add <hours>[/color]")
			return
		var hours = args[1].to_int()
		for i in range(hours):
			TimeManager.advance_hour()
		add_output("[color=lime]Advanced time by %d hours[/color]" % hours)

	else:
		add_output("[color=red]Unknown time command. Use: time, time set <hour>, time add <hours>[/color]")

func _cmd_day(args: Array) -> void:
	if args.is_empty():
		# Show current day
		add_output("[color=lime]Current day: %s (Day %d/7, Week %d)[/color]" % [
			TimeManager.get_day_name(),
			TimeManager.current_day,
			TimeManager.current_week
		])
		return

	var subcmd = args[0].to_lower()

	if subcmd == "set":
		if args.size() < 2:
			add_output("[color=red]Usage: day set <day>[/color]")
			return
		var day = args[1].to_int()
		if day < 1 or day > 7:
			add_output("[color=red]Day must be 1-7[/color]")
			return
		TimeManager.current_day = day
		TimeManager.day_changed.emit(day)
		add_output("[color=lime]Day set to %d (%s)[/color]" % [day, TimeManager.get_day_name()])

	elif subcmd == "next":
		TimeManager.advance_day()
		add_output("[color=lime]Advanced to next day[/color]")

	else:
		add_output("[color=red]Unknown day command. Use: day, day set <day>, day next[/color]")

func _cmd_week(args: Array) -> void:
	if args.is_empty():
		add_output("[color=lime]Current week: %d[/color]" % TimeManager.current_week)
		return

	var subcmd = args[0].to_lower()

	if subcmd == "set":
		if args.size() < 2:
			add_output("[color=red]Usage: week set <week>[/color]")
			return
		var week = args[1].to_int()
		if week < 1:
			add_output("[color=red]Week must be >= 1[/color]")
			return
		TimeManager.current_week = week
		add_output("[color=lime]Week set to %d (Difficulty multiplier: %.1fx)[/color]" % [
			week,
			TimeManager.get_difficulty_multiplier()
		])

	else:
		add_output("[color=red]Unknown week command. Use: week, week set <week>[/color]")

func _cmd_bloodmoon(args: Array) -> void:
	if args.is_empty():
		add_output("[color=red]Usage: bloodmoon start | bloodmoon stop[/color]")
		return

	var subcmd = args[0].to_lower()

	if subcmd == "start":
		# Force bloodmoon conditions
		TimeManager.current_day = 7
		TimeManager.current_hour = 21
		TimeManager.is_bloodmoon = true
		TimeManager.bloodmoon_started.emit()
		add_output("[color=red]🩸 BLOODMOON STARTED (forced)[/color]")

	elif subcmd == "stop":
		TimeManager.is_bloodmoon = false
		TimeManager.bloodmoon_ended.emit()
		add_output("[color=lime]Bloodmoon ended[/color]")

	else:
		add_output("[color=red]Unknown bloodmoon command. Use: bloodmoon start | bloodmoon stop[/color]")

func _cmd_fps(args: Array) -> void:
	if args.is_empty():
		add_output("[color=red]Usage: fps true | fps false[/color]")
		return

	var value = args[0].to_lower()
	var debug_info = get_node_or_null("/root/Main/Game/DebugInfo")

	if debug_info == null:
		add_output("[color=red]Error: DebugInfo node not found[/color]")
		return

	if value == "true" or value == "on" or value == "1":
		debug_info.set_fps_visible(true)
		add_output("[color=lime]FPS counter enabled[/color]")
	elif value == "false" or value == "off" or value == "0":
		debug_info.set_fps_visible(false)
		add_output("[color=lime]FPS counter disabled[/color]")
	else:
		add_output("[color=red]Invalid value. Use: fps true | fps false[/color]")

func _cmd_give(args: Array) -> void:
	if args.is_empty():
		add_output("[color=red]Usage: give <item_name> [amount][/color]")
		add_output("[color=yellow]Example: give torch 10[/color]")
		add_output("[color=yellow]Type 'list items' to see available items[/color]")
		return

	var item_name = args[0].to_lower()
	var amount = 1
	if args.size() > 1:
		amount = args[1].to_int()
		if amount < 1:
			amount = 1

	# Item name to ID mapping
	var item_map = {
		"rocket_launcher": 0,
		"grappling_hook": 1,
		"grapple": 1,
		"climbing_claws": 2,
		"claws": 2,
		"ice_bow": 3,
		"bow": 3,
		"fire_staff": 4,
		"staff": 4,
		"throwing_knives": 5,
		"knives": 5,
		"torch": 6,
		"stone_hammer": 7,
		"stonehammer": 7,
		"hammer": 7,
		"machete": 8,
		"crossbow": 9,
		"sword": 10,
		"tree_feller": 11,
		"treefeller": 11,
		"axe": 11
	}

	if not item_map.has(item_name):
		add_output("[color=red]Unknown item: " + item_name + "[/color]")
		add_output("[color=yellow]Type 'list items' to see available items[/color]")
		return

	var item_id = item_map[item_name]
	
	# Get player using group (more reliable than hard-coded path)
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		add_output("[color=red]Error: Player not found[/color]")
		return
	
	# Inventory is a direct child of the player
	var inventory = player.get_node_or_null("Inventory")
	if inventory == null:
		add_output("[color=red]Error: Inventory not found[/color]")
		return

	# Find first empty slot in inventory
	var slots = inventory._slots
	var empty_slot = -1
	for i in range(slots.size()):
		if slots[i] == null:
			empty_slot = i
			break

	if empty_slot == -1:
		add_output("[color=red]Inventory is full![/color]")
		return

	# Create item
	const InventoryItem = preload("res://blocky_game/player/inventory_item.gd")
	var item = InventoryItem.new()
	item.id = item_id
	item.type = InventoryItem.TYPE_ITEM

	# Only torches can stack
	if item_name == "torch":
		item.count = amount
	else:
		# Other items have "infinite ammo" - single instance
		item.count = 1
		if amount > 1:
			add_output("[color=yellow]Note: " + item_name + " has infinite ammo, amount ignored[/color]")

	slots[empty_slot] = item
	inventory._update_views()

	add_output("[color=lime]Gave " + (str(amount) + "x " if item_name == "torch" else "") + item_name + "[/color]")

func _cmd_list(args: Array) -> void:
	if args.is_empty():
		add_output("[color=red]Usage: list items[/color]")
		return

	var subcmd = args[0].to_lower()

	if subcmd == "items":
		add_output("[color=lime]=== Available Items ===[/color]")
		add_output("")
		add_output("[color=cyan]Ranged Weapons (Infinite Ammo):[/color]")
		add_output("  [color=yellow]rocket_launcher[/color] - Explosive projectile launcher")
		add_output("  [color=yellow]grappling_hook[/color] (or 'grapple') - Arc to distant blocks")
		add_output("  [color=yellow]ice_bow[/color] (or 'bow') - Zigzag homing ice arrow")
		add_output("  [color=yellow]fire_staff[/color] (or 'staff') - Meteor strike from sky")
		add_output("  [color=yellow]throwing_knives[/color] (or 'knives') - Spiral attack")
		add_output("  [color=yellow]crossbow[/color] - Precision ranged weapon")
		add_output("")
		add_output("[color=cyan]Melee Weapons:[/color]")
		add_output("  [color=yellow]machete[/color] - Fast slashing weapon (20 dmg, 0.5s)")
		add_output("  [color=yellow]sword[/color] - Balanced melee weapon (30 dmg, 0.75s)")
		add_output("  [color=yellow]treefeller[/color] (or 'axe') - Heavy axe with cleave (35 dmg, 1.0s)")
		add_output("  [color=yellow]stonehammer[/color] (or 'hammer') - Crushing weapon with AOE")
		add_output("")
		add_output("[color=cyan]Tools:[/color]")
		add_output("  [color=yellow]climbing_claws[/color] (or 'claws') - Climb vertical walls")
		add_output("")
		add_output("[color=cyan]Consumables (Stackable):[/color]")
		add_output("  [color=yellow]torch[/color] - Throwable light source")
		add_output("")
		add_output("[color=yellow]Usage: give <item_name> [amount][/color]")
	else:
		add_output("[color=red]Unknown list command. Use: list items[/color]")

func _cmd_fog(args: Array) -> void:
	if args.is_empty():
		var status = "ON" if GraphicsSettings.get_fog_enabled() else "OFF"
		add_output("[color=cyan]Fog is currently: " + status + "[/color]")
		add_output("[color=yellow]Usage: fog true | fog false[/color]")
		return

	var value = args[0].to_lower()

	if value == "true" or value == "on" or value == "1":
		GraphicsSettings.set_fog_enabled(true)
		add_output("[color=lime]Fog enabled[/color]")
	elif value == "false" or value == "off" or value == "0":
		GraphicsSettings.set_fog_enabled(false)
		add_output("[color=lime]Fog disabled[/color]")
	else:
		add_output("[color=red]Invalid value. Use: fog true | fog false[/color]")

func _cmd_graphics(args: Array) -> void:
	if args.is_empty():
		var current = GraphicsSettings.get_current_profile()
		add_output("[color=cyan]Current graphics profile: " + current.to_upper() + "[/color]")
		add_output("[color=yellow]Usage: graphics low | medium | high[/color]")
		return

	var profile = args[0].to_lower()

	# Validate profile exists
	if profile not in ["low", "medium", "high"]:
		add_output("[color=red]Invalid profile: " + profile + "[/color]")
		add_output("[color=yellow]Valid profiles: low, medium, high[/color]")
		return

	# Apply the profile
	GraphicsSettings.apply_profile(profile)
	add_output("[color=lime]Graphics profile changed to: " + profile.to_upper() + "[/color]")

	# Show profile details
	var voxel_dist = GraphicsSettings.get_setting("voxel_viewer_distance")
	var camera_far = GraphicsSettings.get_setting("camera_far_clip")
	var shadows = GraphicsSettings.get_setting("directional_light_shadows")
	var particles = GraphicsSettings.get_setting("particle_count")
	var debris = GraphicsSettings.get_setting("debris_count")

	add_output("[color=cyan]Profile Details:[/color]")
	add_output("  Voxel Distance: " + str(voxel_dist) + " chunks")
	add_output("  Camera Far Clip: " + str(camera_far) + " units")
	add_output("  Shadows: " + ("ON" if shadows else "OFF"))
	add_output("  Particles: " + str(particles))
	add_output("  Debris Count: " + str(debris))

func _cmd_spawn(args: Array) -> void:
	if args.is_empty():
		add_output("[color=yellow]Usage: spawn <entity_type>[/color]")
		add_output("[color=yellow]Available: ghost, rat, goblin, troglodyte[/color]")
		return

	var entity_type = args[0].to_lower()

	# Get player position
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		add_output("[color=red]Error: Cannot find player[/color]")
		return

	# Spawn 5 units in front of player (start above ground)
	var spawn_pos = player.global_position + player.transform.basis.z * -5.0
	spawn_pos.y += 5.0  # Start 5 blocks above

	var entity_scenes = {
		"ghost": "res://blocky_game/entities/ghost.tscn",
		"rat": "res://blocky_game/entities/rat.tscn",
		"goblin": "res://blocky_game/entities/goblin_grunt.tscn",
		"troglodyte": "res://blocky_game/entities/troglodyte.tscn"
	}

	if entity_type in entity_scenes:
		var scene_path = entity_scenes[entity_type]
		var entity_scene = load(scene_path)
		if entity_scene:
			var entity = entity_scene.instantiate()

			# Add to game world first
			var game = get_node_or_null("/root/Main/Game")
			if game:
				game.add_child(entity)

				# Find ground position for ground entities
				if entity is GroundEntity:
					entity.global_position = entity.find_ground_position(spawn_pos, 15.0)
				else:
					# Flying entities can spawn in air
					entity.global_position = spawn_pos

				add_output("[color=lime]Spawned " + entity_type + " at " + str(entity.global_position) + "[/color]")
			else:
				add_output("[color=red]Error: Could not find game node[/color]")
		else:
			add_output("[color=red]Error: Could not load " + entity_type + " scene[/color]")
	else:
		add_output("[color=red]Unknown entity: " + entity_type + "[/color]")
		add_output("[color=yellow]Available: " + str(entity_scenes.keys()) + "[/color]")


## Take screenshot with F2
func _take_screenshot() -> void:
	var timestamp = Time.get_ticks_msec()
	var filename = "user://screenshot_%d.png" % timestamp

	# Get the viewport texture and save as PNG
	var image = get_viewport().get_texture().get_image()
	if image:
		var error = image.save_png(filename)
		if error == OK:
			print("[Screenshot] Saved to: ", filename)
			add_output("[color=lime]Screenshot saved: screenshot_%d.png[/color]" % (timestamp % 1000000))
		else:
			print("[Screenshot] Error saving screenshot: ", error)
			add_output("[color=red]Error saving screenshot: code %d[/color]" % error)
	else:
		print("[Screenshot] Error: Could not get viewport image")
		add_output("[color=red]Error: Could not capture screenshot[/color]")


## Player HP Commands

func _cmd_hp(_args: Array) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		add_output("[color=red]Error: Player not found[/color]")
		return

	add_output("[color=lime]Player HP: %d/%d[/color]" % [player.current_hp, player.max_hp])


func _cmd_damage(args: Array) -> void:
	if args.size() < 1:
		add_output("[color=red]Usage: damage <amount>[/color]")
		return

	var amount = int(args[0])
	if amount <= 0:
		add_output("[color=red]Error: Damage amount must be positive[/color]")
		return

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		add_output("[color=red]Error: Player not found[/color]")
		return

	# Damage player directly (bypass roll to hit for testing)
	var actual_damage = max(1, amount - int(amount * (player.defense / 100.0)))
	player.current_hp -= actual_damage
	player.current_hp = max(0, player.current_hp)
	player.hp_changed.emit(player.current_hp, player.max_hp)

	add_output("[color=yellow]Dealt %d damage to player (HP: %d/%d)[/color]" % [actual_damage, player.current_hp, player.max_hp])

	if player.current_hp <= 0:
		player.die()


func _cmd_heal(args: Array) -> void:
	if args.size() < 1:
		add_output("[color=red]Usage: heal <amount>[/color]")
		return

	var amount = int(args[0])
	if amount <= 0:
		add_output("[color=red]Error: Heal amount must be positive[/color]")
		return

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		add_output("[color=red]Error: Player not found[/color]")
		return

	if not player.is_alive:
		add_output("[color=red]Error: Player is dead[/color]")
		return

	player.heal(amount)
	add_output("[color=lime]Healed player for %d HP (HP: %d/%d)[/color]" % [amount, player.current_hp, player.max_hp])


func _cmd_dialogue(args: Array) -> void:
	if args.is_empty():
		add_output("[color=yellow]Usage: dialogue <dialogue_id>[/color]")
		add_output("[color=yellow]Available dialogues:[/color]")
		add_output("  test_dialogue - Test all mood changes")
		add_output("  game_start - Companion introduction")
		add_output("  first_night - Night warning")
		add_output("  ruin_discovered - Ruin sighting")
		add_output("  ruin_entrance - Ruin entrance")
		add_output("")
		add_output("[color=cyan]Tips:[/color]")
		add_output("  Use 'dialogue reset' to reset progress (see dialogues again)")
		return

	var dialogue_id = args[0].to_lower()

	if dialogue_id == "reset":
		DialogueManager.reset_progress()
		add_output("[color=lime]Dialogue progress reset! All dialogues can be seen again.[/color]")
		return

	# Try to trigger the dialogue
	var success = DialogueManager.trigger_dialogue(dialogue_id)

	if success:
		add_output("[color=lime]Triggered dialogue: " + dialogue_id + "[/color]")
	else:
		add_output("[color=red]Failed to trigger dialogue: " + dialogue_id + "[/color]")
		add_output("[color=yellow]Check if dialogue ID is correct or if it's already been seen (once-only)[/color]")


func _cmd_testhunt(args: Array) -> void:
	"""Test hunt return dialogue with fake items (no actual items given)"""
	if args.is_empty():
		add_output("[color=yellow]Usage: testhunt <success|failure>[/color]")
		add_output("  success - Test dialogue with found items (fake)")
		add_output("  failure - Test dialogue with no items found")
		add_output("[color=gray]Note: No items are actually added to inventory[/color]")
		return

	var mode = args[0].to_lower()

	if mode == "success":
		# Test successful hunt dialogue (no items given)
		HuntingSystem.test_hunt_dialogue(true)
		add_output("[color=lime]Triggered successful hunt dialogue (no items added)[/color]")
	elif mode == "failure":
		# Test failed hunt dialogue
		HuntingSystem.test_hunt_dialogue(false)
		add_output("[color=lime]Triggered failed hunt dialogue[/color]")
	else:
		add_output("[color=red]Invalid mode. Use 'success' or 'failure'[/color]")


func _cmd_creative(args: Array) -> void:
	"""Toggle creative mode on/off"""
	if args.is_empty():
		add_output("[color=yellow]Usage: creative <on|off>[/color]")
		return

	var mode = args[0].to_lower()
	var player = get_tree().get_first_node_in_group("player")

	if player == null:
		add_output("[color=red]Error: Player not found[/color]")
		return

	# Get the avatar interaction script (node is called "Interaction")
	var avatar_interaction = player.get_node_or_null("Interaction")
	if avatar_interaction == null:
		add_output("[color=red]Error: Interaction node not found[/color]")
		return

	if mode == "on":
		avatar_interaction.set_creative_mode(true)
		add_output("[color=lime]Creative mode ENABLED[/color]")
		add_output("[color=cyan]Blocks break instantly and are not collected[/color]")
	elif mode == "off":
		avatar_interaction.set_creative_mode(false)
		add_output("[color=lime]Creative mode DISABLED[/color]")
		add_output("[color=cyan]Normal mining mode active[/color]")
	else:
		add_output("[color=red]Invalid mode. Use 'creative on' or 'creative off'[/color]")
