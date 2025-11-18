extends Control
## GameConsole - In-game debug console for The Long Nights
## Toggle with ~ (tilde) or F1
## Type 'help' for commands

const InteractionCommon = preload("res://blocky_game/player/interaction_common.gd")

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

	# Register fishing command (declared later in file)
	commands["fish"] = _cmd_fish

	# Start hidden
	visible = false

	print("GameConsole: Ready (Press ~ or F1 to open)")

func _build_ui() -> void:
	# Main panel (bottom half of screen)
	console_panel = Panel.new()
	console_panel.name = "ConsolePanel"
	console_panel.focus_mode = Control.FOCUS_NONE  # Don't steal focus
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
	output_label.focus_mode = Control.FOCUS_NONE  # Don't steal focus on scroll
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


func execute_command(command_text: String) -> void:
	"""Public method to execute a command from other scripts"""
	_execute_command(command_text)

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
	commands["season"] = _cmd_season
	commands["perfmon"] = _cmd_perfmon
	commands["cooking"] = _cmd_cooking
	commands["blocks"] = _cmd_blocks
	commands["shop"] = _cmd_shop
	commands["npc"] = _cmd_npc
	commands["homebase"] = _cmd_homebase
	commands["home"] = _cmd_homebase  # Alias
	commands["roster"] = _cmd_roster
	commands["drain"] = _cmd_drain
	commands["undervoid"] = _cmd_undervoid  # Spawn Undervoid structure
	commands["charview"] = _cmd_charview  # Character view - orbit camera around player
	commands["photo"] = _cmd_photo  # Photo mode - manual camera control for screenshots

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
	add_output("[color=cyan]Season Commands:[/color]")
	add_output("  [color=yellow]season[/color] - Show current season")
	add_output("  [color=yellow]season <spring|summer|autumn|winter>[/color] - Change season")
	add_output("")
	add_output("[color=cyan]Bloodmoon Commands:[/color]")
	add_output("  [color=yellow]bloodmoon start[/color] - Trigger bloodmoon")
	add_output("  [color=yellow]bloodmoon stop[/color] - End bloodmoon")
	add_output("")
	add_output("[color=cyan]Item Commands:[/color]")
	add_output("  [color=yellow]list items[/color] - Show all available items")
	add_output("  [color=yellow]give <item_name> [amount][/color] - Give item to inventory")
	add_output("  [color=yellow]blocks[/color] - Open free block selector (add blocks to inventory)")
	add_output("")
	add_output("[color=cyan]Shop Commands:[/color]")
	add_output("  [color=yellow]shop blocks[/color] - Open block shop (1-for-1 block trading)")
	add_output("  [color=yellow]shop items[/color] - Open item shop (buy/sell with rust blocks)")
	add_output("  [color=yellow]shop food[/color] - Open food shop (raw/cooked trading)")
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
	add_output("  [color=yellow]dialogue test new[/color] - Trigger a demo for new dialogue features (SFX, choices)")
	add_output("  [color=yellow]dialogue test voice <speed>[/color] - Trigger AC-style voice demo at given speed (1.0 = normal)")
	add_output("  [color=yellow]dialogue reset[/color] - Reset dialogue progress")
	add_output("  [color=yellow]testhunt success/failure[/color] - Test hunt return dialogue")
	add_output("")
	add_output("[color=cyan]Build/Creative Commands:[/color]")
	add_output("  [color=yellow]creative on[/color] - Enable creative mode (instant building, all blocks in inventory)")
	add_output("    * Current inventory backed up automatically")
	add_output("    * Loads all building blocks into inventory")
	add_output("  [color=yellow]creative off[/color] - Disable creative mode (return to survival)")
	add_output("    * Restores previous inventory or resets to survival loadout")
	add_output("")
	add_output("[color=cyan]Performance Monitoring:[/color]")
	add_output("  [color=yellow]perfmon start[/color] - Start FPS/frame time monitoring")
	add_output("  [color=yellow]perfmon stop[/color] - Stop monitoring and show report")
	add_output("")
	add_output("[color=cyan]Cooking System:[/color]")
	add_output("  [color=yellow]cooking[/color] - Open cooking interface")
	add_output("  [color=yellow]give food[/color] - Give 3x of each raw food item")
	add_output("")
	add_output("[color=cyan]NPC System:[/color]")
	add_output("  [color=yellow]npc <race> <gender> <color> <name>[/color] - Spawn a wandering NPC")
	add_output("    Races: human, elf, dwarf, goblin")
	add_output("    Gender: male, female")
	add_output("    Color: red, green, blue, yellow, etc. (tints clothing)")
	add_output("    Example: npc human female green Angelica")
	add_output("")
	add_output("[color=cyan]Player & Camera:[/color]")
	add_output("  [color=yellow]charview[/color] - Orbit camera around player to view character")
	add_output("  [color=yellow]photo[/color] - Enter photo mode for manual camera control & screenshots")
	add_output("")
	add_output("[color=cyan]Home Base:[/color]")
	add_output("  [color=yellow]homebase set[/color] - Set home base at current location")
	add_output("  [color=yellow]homebase go[/color] - Teleport to your home base")
	add_output("  [color=yellow]homebase clear[/color] - Remove home base (tip: mine for full materials!)")
	add_output("  [color=yellow]homebase clear recycle[/color] - Remove and get 50% blocks back")
	add_output("  [color=yellow]homebase status[/color] - Show home base info")
	add_output("")
	add_output("[color=cyan]Companion Roster:[/color]")
	add_output("  [color=yellow]roster[/color] - Show all companions in roster")
	add_output("  [color=yellow]roster add <race> <gender> <role> <name>[/color] - Add companion to roster")
	add_output("    Example: roster add dwarf male tank Thorin")
	add_output("")
	add_output("[color=cyan]World Modification:[/color]")
	add_output("  [color=yellow]drain [radius][/color] - Remove water in area (default 30 blocks)")
	add_output("    Example: drain 50 - Removes water in 50 block radius from player")

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
	
	# Special keyword: 'food' gives all raw food items
	if item_name == "food":
		_give_all_food_items()
		return
	
	var amount = 1
	if args.size() > 1:
		amount = args[1].to_int()
		if amount < 1:
			amount = 1

	# Item name to ID mapping (must match item_db.gd order!)
	var item_map = {
		"rocketlauncher": 0,
		"grapplinghook": 1,
		"grapple": 1,
		"windwalkerboots": 2,
		"windboots": 2,
		"boots": 2,
		"icebow": 3,
		"bow": 3,
		"fire_staff": 4,
		"staff": 4,
		"throwing_knives": 5,
		"knives": 5,
		"torch": 6,
		"portal_compass": 7,
		"compass": 7,
		"stone_hammer": 8,
		"stonehammer": 8,
		"hammer": 8,
		"machete": 9,
		"crossbow": 10,
		"sword": 11,
		"tree_feller": 12,
		"treefeller": 12,
		"axe": 12,
		"skyshard": 21,
		"shard": 21,
		"light_orb": 40,
		"lightsphere": 40,
		"orb": 40,
		"spear": 41
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

	# Items that can stack with amount multiplier (consumed on use)
	if item_name == "torch" or item_name == "skyshard" or item_name == "shard" or item_name == "portal_compass" or item_name == "compass" or item_name == "light_orb" or item_name == "lightsphere" or item_name == "orb":
		item.count = amount
	# Spear stacks but doesn't use amount multiplier (always gives 1)
	elif item_name == "spear":
		item.count = 1
		if amount > 1:
			add_output("[color=yellow]Note: spear count is always 1, amount ignored[/color]")
	else:
		# Other items have "infinite ammo" - single instance
		item.count = 1
		if amount > 1:
			add_output("[color=yellow]Note: " + item_name + " has infinite ammo, amount ignored[/color]")

	slots[empty_slot] = item
	inventory._update_views()

	var display_name = "skyshard" if (item_name == "shard") else item_name
	display_name = "portal_compass" if (item_name == "compass") else display_name
	display_name = "light_orb" if (item_name == "lightsphere" or item_name == "orb") else display_name
	var show_amount = (item_name == "torch" or item_name == "skyshard" or item_name == "shard" or item_name == "portal_compass" or item_name == "compass" or item_name == "light_orb" or item_name == "lightsphere" or item_name == "orb")
	add_output("[color=lime]Gave " + (str(amount) + "x " if show_amount else "") + display_name + "[/color]")

func _cmd_list(args: Array) -> void:
	if args.is_empty():
		add_output("[color=red]Usage: list items[/color]")
		return

	var subcmd = args[0].to_lower()

	if subcmd == "items":
		add_output("[color=lime]=== Available Items ===[/color]")
		add_output("")
		add_output("[color=cyan]Ranged Weapons (Infinite Ammo):[/color]")
		add_output("  [color=yellow]rocketlauncher[/color] - Explosive projectile launcher")
		add_output("  [color=yellow]grapplinghook[/color] (or 'grapple') - Arc to distant blocks")
		add_output("  [color=yellow]icebow[/color] (or 'bow') - Zigzag homing ice arrow")
		add_output("  [color=yellow]firestaff[/color] (or 'staff') - Meteor strike from sky")
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
		add_output("  [color=yellow]wind_walker_boots[/color] (or 'boots') - Aerial gliding and mobility")
		add_output("")
		add_output("[color=cyan]Materials (Stackable):[/color]")
		add_output("  [color=yellow]skyshard[/color] (or 'shard') - Rare material for weapon enhancement")
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

	# Special demo command: "dialogue test new" to show new dialogue features
	if dialogue_id == "test" and args.size() > 1 and args[1].to_lower() == "new":
		# Trigger a dynamic demo — use an existing dialogue with sfx and choices if available
		var demo_id = "zara_keepers_charm"
		var success = DialogueManager.trigger_dialogue(demo_id)
		if success:
			add_output("[color=lime]Triggered demo dialogue: %s[/color]" % demo_id)
		else:
			# If the dialogue is already marked as seen (once-only) or otherwise blocked,
			# fallback to showing it dynamically (does not mark as seen)
			if DialogueManager.dialogue_data.has(demo_id):
				DialogueManager.trigger_dynamic_dialogue(DialogueManager.dialogue_data[demo_id])
				add_output("[color=lime]Demo dialogue triggered as dynamic version (already seen)[/color]")
			else:
				add_output("[color=red]Failed to trigger demo dialogue: %s[/color]" % demo_id)
		return

	# Special demo - animalese voice test: dialogue test voice <speed>
	if dialogue_id == "test" and args.size() > 1 and args[1].to_lower() == "voice":
		var speed = 1.0
		if args.size() > 2:
			speed = float(args[2])
		# Build a small demo using AC voice
		var demo = {
			"id":"console_demo_voice",
			"messages":[
				{"speaker":"npc","speaker_display":"Console Demo","text":"This is a quick demo of animalese voice at speed %.2f" % speed,"voice_mode":"animalese","voice_speed":speed,"voice_pitch":3.5,"delay":1000}
			]
		}
		DialogueManager.trigger_dynamic_dialogue(demo)
		add_output("[color=lime]Triggered dynamic animalese demo (speed=%.2f)[/color]" % speed)
		return

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
		add_output("[color=cyan]Block placement is instant and doesn't consume items[/color]")
		add_output("[color=yellow]Inventory backed up and loaded with all building blocks[/color]")
	elif mode == "off":
		avatar_interaction.set_creative_mode(false)
		add_output("[color=lime]Creative mode DISABLED[/color]")
		add_output("[color=cyan]Normal mining mode active[/color]")
		add_output("[color=yellow]Inventory restored to survival loadout (machete + 10 torches)[/color]")
	else:
		add_output("[color=red]Invalid mode. Use 'creative on' or 'creative off'[/color]")


## Season Commands

func _cmd_season(args: Array) -> void:
	"""Change the current season and update textures"""
	# Valid season names
	var valid_seasons = ["spring", "summer", "autumn", "winter"]

	if args.is_empty():
		# Show current season
		var time_manager = get_tree().root.get_node("TimeManager")
		if time_manager:
			var current_season = time_manager.current_season
			add_output("[color=lime]Current season: %s[/color]" % current_season.to_upper())
		add_output("[color=yellow]Usage: season <spring|summer|autumn|winter>[/color]")
		return

	var season = args[0].to_lower()

	# Validate season
	if not season in valid_seasons:
		add_output("[color=red]Invalid season: " + season + "[/color]")
		add_output("[color=yellow]Valid seasons: spring, summer, autumn, winter[/color]")
		return

	# Find the SeasonalTextureSystem node
	var seasonal_system = get_node_or_null("/root/Main/Game/SeasonalTextureSystem")
	if seasonal_system == null:
		add_output("[color=red]Error: SeasonalTextureSystem not found[/color]")
		return

	# Update TimeManager's current season and emit signal
	var time_manager = get_tree().root.get_node("TimeManager")
	if time_manager:
		time_manager.current_season = season
		time_manager.season_changed.emit(season)  # Emit signal so systems respond

	# Apply the season textures
	if seasonal_system.has_method("apply_season"):
		seasonal_system.apply_season(season)
		add_output("[color=lime]Season changed to: " + season.to_upper() + "[/color]")
		add_output("[color=cyan]Textures updated[/color]")
	else:
		add_output("[color=red]Error: apply_season method not found[/color]")


func _cmd_perfmon(args: Array) -> void:
	"""Performance monitoring commands"""
	var perfmon = get_node_or_null("/root/PerformanceMonitor")
	if perfmon == null:
		add_output("[color=red]Error: PerformanceMonitor not loaded (add to autoloads)[/color]")
		return

	if args.is_empty():
		add_output("[color=yellow]Usage: perfmon <start|stop>[/color]")
		add_output("  start - Begin monitoring FPS and frame times")
		add_output("  stop  - Stop monitoring and show performance report")
		return

	var subcmd = args[0].to_lower()

	if subcmd == "start":
		if perfmon.has_method("start_monitoring"):
			perfmon.start_monitoring()
			add_output("[color=lime]Performance monitoring started[/color]")
			add_output("[color=cyan]Change season now, then type 'perfmon stop' to see impact[/color]")
	elif subcmd == "stop":
		if perfmon.has_method("stop_monitoring"):
			var report = perfmon.stop_monitoring()
			add_output(report)
	else:
		add_output("[color=red]Invalid command. Use 'perfmon start' or 'perfmon stop'[/color]")


func _cmd_cooking(_args: Array) -> void:
	"""Open the cooking modal (test)"""
	add_output("[color=lime]Opening cooking interface...[/color]")

	# Load and create cooking modal
	var CookingModal = load("res://blocky_game/gui/CookingModal.gd")
	var modal = CookingModal.new()

	# Disable player input while modal is open
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)

	# Get avatar interaction to disable hotbar scroll wheel
	var avatar_interaction = player.get_node_or_null("Head/Interaction")
	if avatar_interaction and avatar_interaction.has_method("set_cooking_modal_open"):
		avatar_interaction.set_cooking_modal_open(true)

	# Connect modal_closed signal to re-enable input
	modal.modal_closed.connect(func():
		if player and player.has_method("set_input_enabled"):
			player.set_input_enabled(true)
		# Re-enable hotbar scroll wheel
		if avatar_interaction and avatar_interaction.has_method("set_cooking_modal_open"):
			avatar_interaction.set_cooking_modal_open(false)
	)

	# Add to scene tree
	get_tree().root.add_child(modal)


func _cmd_blocks(_args: Array) -> void:
	"""Open the free block selector (backward compatible)"""
	add_output("[color=lime]Opening block selector...[/color]")

	# Close console first
	toggle_console()

	# Load and create modal in FREE mode
	var ShopModal = load("res://blocky_game/gui/BlockSelectorModal.gd")
	var modal = ShopModal.new(ShopModal.ShopType.FREE)

	# Disable player input while modal is open
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)

	# Get avatar interaction to disable hotbar scroll wheel
	var avatar_interaction = player.get_node_or_null("Head/Interaction")
	if avatar_interaction and avatar_interaction.has_method("set_cooking_modal_open"):
		avatar_interaction.set_cooking_modal_open(true)

	# Connect modal_closed signal to re-enable input
	modal.modal_closed.connect(func():
		if player and player.has_method("set_input_enabled"):
			player.set_input_enabled(true)
		# Re-enable hotbar scroll wheel
		if avatar_interaction and avatar_interaction.has_method("set_cooking_modal_open"):
			avatar_interaction.set_cooking_modal_open(false)
	)

	# Add to scene tree
	get_tree().root.add_child(modal)


func _cmd_shop(args: Array) -> void:
	"""Open shop modal: shop <blocks|items|food>"""
	if args.size() == 0:
		add_output("[color=red]Usage: shop <blocks|items|food>[/color]")
		add_output("[color=yellow]  shop blocks - Block trading (1-for-1)[/color]")
		add_output("[color=yellow]  shop items - Item/weapon shop (rust blocks)[/color]")
		add_output("[color=yellow]  shop food - Food shop (raw/cooked)[/color]")
		return

	var shop_type_str = args[0].to_lower()
	var ShopModal = load("res://blocky_game/gui/BlockSelectorModal.gd")
	var shop_type = ShopModal.ShopType.FREE
	var shop_name = ""

	match shop_type_str:
		"blocks", "block":
			shop_type = ShopModal.ShopType.BLOCKS
			shop_name = "block shop"
		"items", "item", "weapons", "weapon":
			shop_type = ShopModal.ShopType.ITEMS
			shop_name = "item shop"
		"food", "foods":
			shop_type = ShopModal.ShopType.FOOD
			shop_name = "food shop"
		_:
			add_output("[color=red]Unknown shop type: %s[/color]" % shop_type_str)
			add_output("[color=yellow]Valid types: blocks, items, food[/color]")
			return

	add_output("[color=lime]Opening %s...[/color]" % shop_name)

	# Close console first
	toggle_console()

	# Create modal with specified shop type
	var modal = ShopModal.new(shop_type)

	# Disable player input while modal is open
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)

	# Get avatar interaction to disable hotbar scroll wheel
	var avatar_interaction = player.get_node_or_null("Head/Interaction")
	if avatar_interaction and avatar_interaction.has_method("set_cooking_modal_open"):
		avatar_interaction.set_cooking_modal_open(true)

	# Connect modal_closed signal to re-enable input
	modal.modal_closed.connect(func():
		if player and player.has_method("set_input_enabled"):
			player.set_input_enabled(true)
		# Re-enable hotbar scroll wheel
		if avatar_interaction and avatar_interaction.has_method("set_cooking_modal_open"):
			avatar_interaction.set_cooking_modal_open(false)
	)

	# Add to scene tree
	get_tree().root.add_child(modal)


func _cmd_npc(args: Array) -> void:
	"""Spawn a test NPC: npc <race> <gender> <color> <name> [job]"""
	if args.size() < 4:
		add_output("[color=red]Usage: npc <race> <gender> <color> <name> [job][/color]")
		add_output("[color=yellow]Races: human, elf, dwarf, goblin[/color]")
		add_output("[color=yellow]Gender: male, female[/color]")
		add_output("[color=yellow]Color: red, green, blue, yellow, white, etc.[/color]")
		add_output("[color=yellow]Jobs: companion, cook, power_shop, food_merchant, merchant, town_manager, ruinkeeper[/color]")
		add_output("[color=yellow]Example: npc human female white Emma cook[/color]")
		return

	var race = args[0].to_lower()
	var gender = args[1].to_lower()
	var color_name = args[2].to_lower()
	var npc_name = args[3]
	var job = args[4].to_lower() if args.size() >= 5 else "companion"

	# Validate race
	if not race in ["human", "elf", "dwarf", "goblin"]:
		add_output("[color=red]Invalid race! Use: human, elf, dwarf, or goblin[/color]")
		return

	# Validate gender
	if not gender in ["male", "female"]:
		add_output("[color=red]Invalid gender! Use: male or female[/color]")
		return

	# Validate job
	if not job in ["companion", "cook", "power_shop", "food_merchant", "merchant", "town_manager", "ruinkeeper"]:
		add_output("[color=red]Invalid job! Use: companion, cook, power_shop, food_merchant, merchant, town_manager, or ruinkeeper[/color]")
		return

	# Parse color
	var npc_color = _parse_color(color_name)
	
	# Get player position
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		add_output("[color=red]Error: Player not found[/color]")
		return
	
	# Spawn NPC in front of player
	var TestNPC = load("res://blocky_game/entities/test_npc.gd")
	var npc = Node3D.new()
	npc.set_script(TestNPC)
	
	# Add to game world
	var game = get_node_or_null("/root/Main/Game")
	if not game:
		add_output("[color=red]Error: Game node not found[/color]")
		return
	
	game.add_child(npc)
	
	# Position 5 units in front of player
	var spawn_pos = player.global_position + player.transform.basis.z * -5.0
	spawn_pos.y += 5.0  # Start above ground
	
	# Find ground position
	if npc.has_method("find_ground_position"):
		npc.global_position = npc.find_ground_position(spawn_pos, 15.0)
	else:
		npc.global_position = spawn_pos
	
	# Initialize NPC with data
	npc.initialize(race, gender, npc_color, npc_name, job)

	add_output("[color=lime]✓ Spawned %s NPC: %s (%s %s)[/color]" % [job, npc_name, race, gender])


func _parse_color(color_name: String) -> Color:
	"""Parse color from name or hex code (#RRGGBB)"""
	# Check if it's a hex code
	if color_name.begins_with("#"):
		return Color(color_name)
	
	# Otherwise match named colors
	match color_name:
		"red": return Color.RED
		"green": return Color.GREEN
		"blue": return Color.BLUE
		"yellow": return Color.YELLOW
		"orange": return Color.ORANGE
		"purple": return Color.PURPLE
		"pink": return Color.PINK
		"white": return Color.WHITE
		"black": return Color.BLACK
		"gray", "grey": return Color.GRAY
		"brown": return Color(0.6, 0.4, 0.2)
		"cyan": return Color.CYAN
		"magenta": return Color.MAGENTA
		"lime": return Color(0.5, 1.0, 0.0)
		"navy": return Color(0.0, 0.0, 0.5)
		"maroon": return Color(0.5, 0.0, 0.0)
		"olive": return Color(0.5, 0.5, 0.0)
		"teal": return Color(0.0, 0.5, 0.5)
		_: return Color.WHITE  # Default to white


func _give_all_food_items() -> void:
	"""Give 3 of each raw food item for cooking tests"""
	const InventoryItem = preload("res://blocky_game/player/inventory_item.gd")
	
	# Get player and inventory
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		add_output("[color=red]Error: Player not found[/color]")
		return
	
	var inventory = player.get_node_or_null("Inventory")
	if inventory == null:
		add_output("[color=red]Error: Inventory not found[/color]")
		return
	
	# Raw food item IDs: egg=13, rabbit=14, berries=15, honey=16, wheat_seeds=22, pumpkin=24, mushroom=25, fish=26
	var food_data = [
		{"id": 13, "name": "egg"},
		{"id": 14, "name": "rabbit"},
		{"id": 15, "name": "berries"},
		{"id": 16, "name": "honey"},
		{"id": 22, "name": "wheat_seeds"},
		{"id": 24, "name": "pumpkin"},
		{"id": 25, "name": "mushroom"},
		{"id": 26, "name": "fish"}
	]
	
	var slots = inventory._slots
	var items_given = 0
	
	# Add each food item
	for food in food_data:
		var food_id = food.id
		
		# Try to find existing stack first
		var existing_slot = -1
		for i in range(slots.size()):
			if slots[i] != null and slots[i].type == InventoryItem.TYPE_ITEM and slots[i].id == food_id:
				existing_slot = i
				break
		
		if existing_slot != -1:
			# Add to existing stack
			slots[existing_slot].count += 3
			items_given += 1
		else:
			# Find empty slot
			var empty_slot = -1
			for i in range(slots.size()):
				if slots[i] == null:
					empty_slot = i
					break
			
			if empty_slot != -1:
				# Create new stack
				var item = InventoryItem.new()
				item.id = food_id
				item.type = InventoryItem.TYPE_ITEM
				item.count = 3
				slots[empty_slot] = item
				items_given += 1
			else:
				add_output("[color=yellow]Inventory full, skipped: " + food.name + "[/color]")
	
	inventory._update_views()
	
	if items_given > 0:
		add_output("[color=lime]Gave 3x of %d food types[/color]" % items_given)
	else:
		add_output("[color=red]Could not add any food items (inventory full?)[/color]")


func _cmd_homebase(args: Array) -> void:
	"""Home base management commands"""
	if args.is_empty():
		add_output("[color=red]Usage: homebase <set|go|cr|clear|status>[/color]")
		return

	var player = get_tree().get_first_node_in_group("player")
	var subcmd = args[0].to_lower()

	match subcmd:
		"cr":
			if not player:
				add_output("[color=red]Player not found![/color]")
				return

			# Teleport player to crashed ruins
			# Crashed ruins spawn at (48, ground_y, 48) - 3 chunks from spawn
			# Teleport a bit above to ensure we're not underground
			var crashed_ruins_pos = Vector3(48, 5, 48)  # Y=5 above the ruin floor
			player.global_position = crashed_ruins_pos
			add_output("[color=lime]💥 Teleported to Crashed Ruins location[/color]")
			add_output("[color=cyan]Coordinates: (48, 5, 48)[/color]")

		"go":
			if not player:
				add_output("[color=red]Player not found![/color]")
				return

			if not HomeBaseManager.has_home_base:
				add_output("[color=yellow]No home base set![/color]")
				add_output("Use [color=cyan]homebase set[/color] to establish one first")
				return

			# Teleport player to home base
			var teleport_pos = HomeBaseManager.home_base_position + Vector3(0, 2, 0)  # Spawn slightly above ground
			player.global_position = teleport_pos

			var tier_name = HomeBaseManager.TIER_NAMES[HomeBaseManager.home_structure_tier]
			add_output("[color=lime]🏠 Teleported to home base (%s)[/color]" % tier_name)
			add_output("[color=cyan]Welcome home![/color]")
			
			# LampManager will automatically activate nearby lamps within 48 blocks
			# No scan needed - proximity checks happen every 2 seconds

		"set":
			if not player:
				add_output("[color=red]Player not found![/color]")
				return
			
			var player_pos = player.global_position
			HomeBaseManager.set_home_base(player_pos)
			add_output("[color=lime]🏠 Home Base set at: %s[/color]" % player_pos)
			add_output("[color=yellow]Your benched companions will now live here![/color]")
		
		"clear":
			if not HomeBaseManager.has_home_base:
				add_output("[color=yellow]No home base to clear[/color]")
				return
			
			# Check if they want to recycle
			var recycle = false
			if args.size() > 1 and args[1].to_lower() == "recycle":
				recycle = true
			
			var tier = HomeBaseManager.home_structure_tier
			var tier_name = HomeBaseManager.TIER_NAMES[tier]
			
			if recycle:
				var blocks_returned = HomeBaseManager.TIER_RECYCLE_BLOCKS[tier]
				add_output("[color=yellow]♻️ Recycling %s...[/color]" % tier_name)
				HomeBaseManager.clear_home_base(true)
				
				# Add blocks to inventory
				if player:
					var inventory = player.get_node_or_null("Inventory")
					if inventory and inventory.has_method("add_item"):
						# Give back mixed blocks (dirt for simplicity)
						inventory.add_item(1, blocks_returned)  # 1 = dirt block ID
						add_output("[color=lime]✓ Received %d blocks from recycling![/color]" % blocks_returned)
					else:
						add_output("[color=lime]✓ Would receive %d blocks (inventory not accessible)[/color]" % blocks_returned)
			else:
				HomeBaseManager.clear_home_base(false)
				var blocks_recyclable = HomeBaseManager.TIER_RECYCLE_BLOCKS[tier]
				add_output("[color=lime]🏠 Home Base cleared[/color]")
				add_output("[color=yellow]💡 Tip: Use 'homebase clear recycle' to get ~%d blocks back[/color]" % blocks_recyclable)
				add_output("[color=cyan]   Or mine it yourself for 100%% of materials![/color]")
		
		"status":
			if HomeBaseManager.has_home_base:
				add_output("[color=lime]🏠 Home Base Status:[/color]")
				add_output("  Location: %s" % HomeBaseManager.home_base_position)
				
				# Show structure tier
				var tier = HomeBaseManager.home_structure_tier
				var tier_name = HomeBaseManager.TIER_NAMES[tier]
				add_output("  Structure: %s (Tier %d)" % [tier_name, tier])
				
				if HomeBaseManager.home_base_ruin_id != "":
					add_output("  At Ruin: %s" % HomeBaseManager.home_base_ruin_id)
				
				# Check distance if player exists
				if player:
					var distance = player.global_position.distance_to(HomeBaseManager.home_base_position)
					add_output("  Distance: %.1f blocks" % distance)
					if HomeBaseManager.is_player_at_home():
						add_output("  [color=lime]✓ You are at home![/color]")
			else:
				add_output("[color=yellow]No home base set[/color]")
				add_output("Use [color=cyan]homebase set[/color] to establish one")
		
		_:
			add_output("[color=red]Unknown subcommand: %s[/color]" % subcmd)
			add_output("[color=yellow]Use: homebase <set|go|clear|status>[/color]")


func _cmd_roster(args: Array) -> void:
	"""Companion roster management"""
	# Initialize roster from legacy if needed
	if not CompanionManager.using_roster_system:
		CompanionManager.initialize_roster_from_legacy()
	
	if args.is_empty():
		# Show roster
		var count = CompanionManager.get_companion_count()
		if count == 0:
			add_output("[color=yellow]No companions in roster yet[/color]")
			return
		
		add_output("[color=lime]🎭 Companion Roster (%d total):[/color]" % count)
		add_output("")
		
		for i in range(count):
			var comp = CompanionManager.companion_roster[i]
			var status = "[✓ ACTIVE]" if i == CompanionManager.active_companion_index else "[ ] BENCHED"
			var status_color = "lime" if i == CompanionManager.active_companion_index else "gray"
			
			add_output("[color=%s]%s %s[/color]" % [status_color, status, comp.companion_name])
			add_output("  %s %s (Level %d)" % [comp.race.capitalize(), comp.role.capitalize(), comp.level])
			if comp.active_title != "":
				add_output("  %s %s" % [comp.title_emoji, comp.active_title])
			add_output("")
		
		return
	
	var subcmd = args[0].to_lower()
	
	match subcmd:
		"add":
			if args.size() < 5:
				add_output("[color=red]Usage: roster add <race> <gender> <role> <name>[/color]")
				add_output("  Races: human, elf, dwarf, goblin")
				add_output("  Gender: male, female")
				add_output("  Roles: healer, tank, rogue, wizard")
				return
			
			var race = args[1].to_lower()
			var gender = args[2].to_lower()
			var role = args[3].to_lower()
			var name = args[4]
			
			# Validate race
			if not race in ["human", "elf", "dwarf", "goblin"]:
				add_output("[color=red]Invalid race: %s[/color]" % race)
				return
			
			# Validate gender
			if not gender in ["male", "female"]:
				add_output("[color=red]Invalid gender: %s[/color]" % gender)
				return
			
			# Validate role
			if not role in ["healer", "tank", "rogue", "wizard"]:
				add_output("[color=red]Invalid role: %s[/color]" % role)
				return
			
			# Create new companion
			var comp = CompanionManager.CompanionData.new()
			comp.companion_name = name
			comp.race = race
			comp.gender = gender
			comp.role = role
			comp.is_active = false  # Will be benched
			
			CompanionManager.add_companion_to_roster(comp)
			add_output("[color=lime]✓ Added %s to roster![/color]" % name)
			add_output("  %s %s %s will be waiting at your home base" % [gender.capitalize(), race.capitalize(), role.capitalize()])
			
			# Spawn as NPC at home base if home base is set
			if HomeBaseManager.has_home_base:
				HomeBaseManager.add_benched_companion_npc(comp)
				add_output("  [color=lime]🏕️ %s has appeared at your home base![/color]" % name)
			else:
				add_output("  [color=yellow]💡 They'll appear when you set a home base with: homebase set[/color]")
		
		_:
			add_output("[color=red]Unknown subcommand: %s[/color]" % subcmd)
			add_output("[color=yellow]Use: roster [add][/color]")


func _cmd_drain(args: Array) -> void:
	"""Remove water in an area around the player"""
	var radius = 30  # Default radius
	
	if args.size() > 0:
		if args[0].is_valid_int():
			radius = int(args[0])
			if radius < 1 or radius > 100:
				add_output("[color=red]Radius must be between 1 and 100 blocks[/color]")
				return
		else:
			add_output("[color=red]Usage: drain [radius][/color]")
			add_output("[color=yellow]Example: drain 50[/color]")
			return
	
	# Get player position
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		add_output("[color=red]Error: Player not found[/color]")
		return
	
	# Get terrain and voxel tool
	var game = get_node_or_null("/root/Main/Game")
	if not game:
		add_output("[color=red]Error: Game node not found[/color]")
		return
	
	var terrain = game.get_node_or_null("VoxelTerrain")
	if not terrain:
		add_output("[color=red]Error: VoxelTerrain not found[/color]")
		return
	
	var voxel_tool = terrain.get_voxel_tool()
	voxel_tool.set_channel(VoxelBuffer.CHANNEL_TYPE)
	
	# Get water block IDs
	var blocks = game.get_node_or_null("Blocks")
	if not blocks:
		add_output("[color=red]Error: Blocks node not found[/color]")
		return
	
	var water_block = blocks.get_block_by_name("water")
	if not water_block:
		add_output("[color=red]Error: Water block not found[/color]")
		return
	
	var water_full = water_block.base_info.voxels[0]
	var water_top = water_block.base_info.voxels[1]
	
	# Get player position in block coordinates
	var player_pos = player.global_position
	var center = Vector3i(
		int(floor(player_pos.x)),
		int(floor(player_pos.y)),
		int(floor(player_pos.z))
	)
	
	add_output("[color=yellow]🌊 Draining water in %d block radius...[/color]" % radius)
	
	var water_removed = 0
	var radius_squared = radius * radius
	var vertical_range = 10  # Only scan ±10 blocks vertically from player Y
	
	# Scan area around player
	for x in range(-radius, radius + 1):
		for z in range(-radius, radius + 1):
			# Check if within circular radius (not square)
			if (x * x + z * z) > radius_squared:
				continue
			
			# Scan vertically within limited range (±10 blocks from player Y, not ±radius!)
			for y in range(-vertical_range, vertical_range + 1):
				var check_pos = center + Vector3i(x, y, z)
				var voxel_id = voxel_tool.get_voxel(check_pos)

				# If it's water (full or top), replace with air
				if voxel_id == water_full or voxel_id == water_top:
					# Use safe_set_voxel for bedrock protection
					if InteractionCommon.safe_set_voxel(voxel_tool, check_pos, 0):  # 0 = air
						water_removed += 1
	
	if water_removed > 0:
		add_output("[color=lime]✓ Removed %d water blocks[/color]" % water_removed)
	else:
		add_output("[color=yellow]No water found in area[/color]")


func _cmd_undervoid(_args: Array) -> void:
	"""Spawn an Undervoid structure at player's current position"""
	# Get player position
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		add_output("[color=red]Error: Player not found[/color]")
		return

	# Get game node and Undervoid spawner
	var game = get_node_or_null("/root/Main/Game")
	if not game:
		add_output("[color=red]Error: Game node not found[/color]")
		return

	var undervoid_spawner = game.get_node_or_null("UndervoidSpawner")
	if not undervoid_spawner:
		add_output("[color=red]Error: UndervoidSpawner not found[/color]")
		add_output("[color=yellow]Make sure you're in a loaded game world[/color]")
		return

	# Get player position and depth
	var spawn_pos = player.global_position
	var depth = int(spawn_pos.y)

	add_output("[color=yellow]🟣 Spawning Undervoid structure at your position (Y: %d)...[/color]" % depth)

	# Spawn structure
	var success = await undervoid_spawner.spawn_structure_at(spawn_pos, depth)

	if success:
		add_output("[color=lime]✓ Undervoid structure spawned with purple beacon![/color]")
		add_output("[color=cyan]Look for the purple glow above the structure[/color]")
	else:
		add_output("[color=red]✗ Failed to spawn structure[/color]")
		add_output("[color=yellow]Make sure you're on solid ground in the Undervoid (Y -150 to -400)[/color]")


func _cmd_charview(_args: Array) -> void:
	"""Orbit camera around player to view character avatar (billboard sprite)"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		add_output("[color=red]Error: Player not found[/color]")
		return
	
	# Check if player has the start_camera_orbit method
	if not player.has_method("start_camera_orbit"):
		add_output("[color=red]Error: Player doesn't support camera orbit[/color]")
		return
	
	# Start the orbit
	player.start_camera_orbit()
	add_output("[color=cyan]📷 Camera orbiting around your character...[/color]")
	add_output("[color=yellow]The camera will complete one full rotation (8 seconds)[/color]")
	add_output("[color=yellow]You'll see front/back sprite switching as camera rotates[/color]")


func _cmd_photo(_args: Array) -> void:
	"""Enter photo mode - manual camera control for screenshots"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		add_output("[color=red]Error: Player not found[/color]")
		return
	
	# Check if player has the start_photo_mode method
	if not player.has_method("start_photo_mode"):
		add_output("[color=red]Error: Player doesn't support photo mode[/color]")
		return
	
	# Start photo mode
	player.start_photo_mode()
	add_output("[color=cyan]📷 Photo mode enabled![/color]")
	add_output("[color=yellow]Controls:[/color]")
	add_output("  [color=white]Arrow Keys[/color] - Rotate camera")
	add_output("  [color=white]Q/E[/color] - Zoom in/out")
	add_output("  [color=white]F5[/color] - Take screenshot")
	add_output("  [color=white]Esc or P[/color] - Exit photo mode")


func _cmd_fish(_args: Array) -> void:
	"""Spawn a fish in nearby water for testing fishing minigame"""
	# Get player
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		add_output("[color=red]Error: Player not found[/color]")
		return

	# Get terrain and voxel tool
	var terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")
	if not terrain:
		add_output("[color=red]Error: VoxelTerrain not found[/color]")
		return

	var vt = terrain.get_voxel_tool()
	vt.set_channel(VoxelBuffer.CHANNEL_TYPE)

	# Get blocks registry
	var blocks = get_node_or_null("/root/Main/Game/Blocks")
	if not blocks:
		add_output("[color=red]Error: Blocks not found[/color]")
		return

	var water_block = blocks.get_block_by_name("water")
	if not water_block:
		add_output("[color=red]Error: Water block not found[/color]")
		return

	var water_voxels = water_block.base_info.voxels
	add_output("[color=yellow]Debug: Looking for water voxels: %s[/color]" % water_voxels)

	# Search for water near player - check DIRECTLY AROUND PLAYER FIRST
	var spawn_pos = Vector3.ZERO

	# First, check directly at and near player position for water
	add_output("[color=yellow]Debug: Checking around player at %s[/color]" % player.global_position)
	for y_offset in range(-5, 5):
		for x_offset in range(-5, 5):
			for z_offset in range(-5, 5):
				var check_pos = player.global_position + Vector3(x_offset, y_offset, z_offset)
				var voxel_pos = check_pos.floor()
				var voxel_id = vt.get_voxel(voxel_pos)

				if voxel_id in water_voxels:
					add_output("[color=cyan]Found water at %s (voxel_id: %d)[/color]" % [voxel_pos, voxel_id])
					spawn_pos = Vector3(voxel_pos) + Vector3(0.5, 0.5, 0.5)
					break
			if spawn_pos != Vector3.ZERO:
				break
		if spawn_pos != Vector3.ZERO:
			break

	if spawn_pos == Vector3.ZERO:
		add_output("[color=red]Error: No water found in 5-block radius of player[/color]")
		return

	# Spawn fish
	const Fish = preload("res://blocky_game/entities/fish.gd")
	var fish = Node3D.new()
	fish.set_script(Fish)

	var game = get_node_or_null("/root/Main/Game")
	if game:
		game.add_child(fish)
		fish.global_position = spawn_pos

		# Mark fish as "fishing_available" so it won't despawn
		fish.set_meta("fishing_available", true)

		# Tell player about the fish - avatar_interaction is a child node
		var avatar_interaction = null
		for child in player.get_children():
			if child.get_script() and child.get_script().resource_path.contains("avatar_interaction"):
				avatar_interaction = child
				break

		if avatar_interaction and avatar_interaction.has_method("set_nearby_fish"):
			avatar_interaction.set_nearby_fish(fish)
			add_output("[color=cyan]🐟 Fish spawned at %s[/color]" % spawn_pos)
			add_output("[color=yellow]Press F to start fishing![/color]")
		else:
			add_output("[color=orange]⚠️ Fish spawned but couldn't register with player[/color]")
	else:
		add_output("[color=red]Error: Game node not found[/color]")
