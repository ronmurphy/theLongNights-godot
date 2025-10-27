extends Control
## PartyUI - Shows player and companion status in top-right corner
## Displays: Avatar, Name, Role, HP Bar, Equipped Weapon

const CharacterQuiz = preload("res://long_nights/CharacterQuiz.gd")

# Party member data structure
class PartyMember:
	var name: String
	var race: String
	var role: String
	var current_hp: int
	var max_hp: int
	var avatar_texture: Texture2D
	var weapon_icon: Texture2D

	func _init(p_name: String, p_race: String, p_role: String, p_hp: int, p_max_hp: int):
		name = p_name
		race = p_race
		role = p_role
		current_hp = p_hp
		max_hp = p_max_hp

# UI containers
var party_container: VBoxContainer
var player_ui: Control
var companion_ui: Control

# Reference to player
var player_node: Node3D


func _ready() -> void:
	# Create UI
	_create_ui()

	# Connect to player after scene is ready
	call_deferred("_connect_to_player")

	print("PartyUI: Ready")


func _create_ui() -> void:
	# Main container for all party members
	party_container = VBoxContainer.new()
	party_container.name = "PartyContainer"
	party_container.add_theme_constant_override("separation", 8)
	add_child(party_container)

	# Position in top-right (under time/day display)
	var viewport_size = get_viewport_rect().size
	party_container.position = Vector2(viewport_size.x - 260, 70)

	# Create player UI
	player_ui = _create_party_member_ui()
	player_ui.name = "PlayerUI"
	party_container.add_child(player_ui)

	# Companion UI will be added when companion spawns
	# For now, hide it
	companion_ui = _create_party_member_ui()
	companion_ui.name = "CompanionUI"
	companion_ui.visible = false
	party_container.add_child(companion_ui)


func _create_party_member_ui() -> Control:
	# Container for one party member
	var member_container = HBoxContainer.new()
	member_container.add_theme_constant_override("separation", 8)
	member_container.custom_minimum_size = Vector2(250, 80)

	# Avatar sprite (left side)
	var avatar_bg = Panel.new()
	avatar_bg.name = "AvatarBG"
	avatar_bg.custom_minimum_size = Vector2(64, 64)

	# Style avatar background
	var avatar_style = StyleBoxFlat.new()
	avatar_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	avatar_style.border_color = Color(0.6, 0.5, 0.3)
	avatar_style.set_border_width_all(2)
	avatar_bg.add_theme_stylebox_override("panel", avatar_style)

	var avatar_texture = TextureRect.new()
	avatar_texture.name = "AvatarTexture"
	avatar_texture.custom_minimum_size = Vector2(60, 60)
	avatar_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	avatar_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_texture.position = Vector2(2, 2)
	avatar_bg.add_child(avatar_texture)

	member_container.add_child(avatar_bg)

	# Info section (right side)
	var info_vbox = VBoxContainer.new()
	info_vbox.name = "InfoVBox"
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	member_container.add_child(info_vbox)

	# Name label
	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = "Player"
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 2)
	info_vbox.add_child(name_label)

	# Role label
	var role_label = Label.new()
	role_label.name = "RoleLabel"
	role_label.text = "[Tank]"
	role_label.add_theme_font_size_override("font_size", 12)
	role_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	role_label.add_theme_color_override("font_outline_color", Color.BLACK)
	role_label.add_theme_constant_override("outline_size", 2)
	info_vbox.add_child(role_label)

	# HP Bar container (for positioning label inside)
	var hp_container = Control.new()
	hp_container.name = "HPContainer"
	hp_container.custom_minimum_size = Vector2(150, 18)
	info_vbox.add_child(hp_container)

	# HP Bar
	var hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.min_value = 0
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.custom_minimum_size = Vector2(150, 18)
	hp_bar.show_percentage = false
	hp_container.add_child(hp_bar)

	# HP Label (shows numbers) - positioned INSIDE the bar
	var hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.text = "100/100 HP"
	hp_label.add_theme_font_size_override("font_size", 12)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hp_label.add_theme_constant_override("outline_size", 2)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.position = Vector2(0, 0)
	hp_label.size = Vector2(150, 18)
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through
	hp_container.add_child(hp_label)

	# Weapon icon (in top-right corner with margin)
	var weapon_texture = TextureRect.new()
	weapon_texture.name = "WeaponIcon"
	weapon_texture.custom_minimum_size = Vector2(32, 32)
	weapon_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	weapon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Position it in top-right corner with spacing
	weapon_texture.position = Vector2(210, 2)

	# Add a background panel for visibility
	var weapon_bg = Panel.new()
	weapon_bg.custom_minimum_size = Vector2(36, 36)
	weapon_bg.position = Vector2(150, 0)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	bg_style.border_color = Color(0.4, 0.4, 0.4)
	bg_style.set_border_width_all(1)
	weapon_bg.add_theme_stylebox_override("panel", bg_style)
	member_container.add_child(weapon_bg)

	member_container.add_child(weapon_texture)

	return member_container


func _connect_to_player() -> void:
	# Find player
	player_node = get_tree().get_first_node_in_group("player")
	if not player_node:
		push_warning("PartyUI: Could not find player")
		return

	# Connect to player HP changes
	if player_node.has_signal("hp_changed"):
		player_node.hp_changed.connect(_on_player_hp_changed)

	# Initial update
	_update_player_ui()

	print("PartyUI: Connected to player")


func _update_player_ui() -> void:
	if not player_ui or not player_node:
		return

	# Update avatar
	var avatar_path = PlayerData.get_avatar_path("ready")
	var avatar_texture_rect = player_ui.get_node("AvatarBG/AvatarTexture")
	if avatar_texture_rect:
		var texture = load(avatar_path)
		if texture:
			avatar_texture_rect.texture = texture

	# Update name
	var name_label = player_ui.get_node("InfoVBox/NameLabel")
	if name_label:
		name_label.text = PlayerData.get_race_name()

	# Update role
	var role_label = player_ui.get_node("InfoVBox/RoleLabel")
	if role_label:
		role_label.text = "[%s]" % PlayerData.get_role_name()

	# Update HP
	_on_player_hp_changed(player_node.current_hp, player_node.max_hp)

	# Update weapon icon
	_update_player_weapon()


func _on_player_hp_changed(current: int, maximum: int) -> void:
	if not player_ui:
		return

	var hp_bar = player_ui.get_node("InfoVBox/HPContainer/HPBar")
	var hp_label = player_ui.get_node("InfoVBox/HPContainer/HPLabel")

	if hp_bar:
		hp_bar.max_value = maximum
		hp_bar.value = current

		# Change color based on HP percentage
		var hp_percent = float(current) / float(maximum)
		var style = StyleBoxFlat.new()

		if hp_percent > 0.5:
			style.bg_color = Color(0.0, 0.8, 0.0)  # Green
		elif hp_percent > 0.25:
			style.bg_color = Color(0.9, 0.7, 0.0)  # Yellow
		else:
			style.bg_color = Color(0.9, 0.0, 0.0)  # Red

		hp_bar.add_theme_stylebox_override("fill", style)

	if hp_label:
		hp_label.text = "%d/%d HP" % [current, maximum]


func _update_player_weapon() -> void:
	# Get weapon icon
	var weapon_icon = player_ui.get_node("WeaponIcon")
	if not weapon_icon:
		return

	# Check equipped weapon from inventory first
	var inventory = get_node_or_null("/root/Main/Game/CharacterAvatar/Inventory")
	var selected_item = null

	if inventory:
		selected_item = inventory.get_player_equipped_weapon()

	# Fallback to hotbar selection if no equipped weapon
	if not selected_item:
		var hotbar = get_tree().get_first_node_in_group("hotbar")
		if hotbar:
			selected_item = hotbar.get_selected_item()

	if not selected_item:
		weapon_icon.texture = null
		return

	# Load item sprite from item database
	if selected_item.type == 1:  # TYPE_ITEM
		var item_db = get_node_or_null("/root/Main/Game/Items")
		if item_db:
			var item = item_db.get_item(selected_item.id)
			if item and item.base_info.sprite:
				weapon_icon.texture = item.base_info.sprite
			else:
				weapon_icon.texture = null
	else:
		weapon_icon.texture = null


## Add companion to party UI (called when companion spawns)
func add_companion(companion_name: String, race: String, role: String, hp: int, max_hp: int) -> void:
	if not companion_ui:
		return

	companion_ui.visible = true

	# Update avatar
	var avatar_path = CharacterQuiz.get_avatar_path(race, "female", "ready")  # Companion gender
	var avatar_texture_rect = companion_ui.get_node("AvatarBG/AvatarTexture")
	if avatar_texture_rect:
		var texture = load(avatar_path)
		if texture:
			avatar_texture_rect.texture = texture

	# Update name
	var name_label = companion_ui.get_node("InfoVBox/NameLabel")
	if name_label:
		name_label.text = CharacterQuiz.get_race_name(race)

	# Update role
	var role_label = companion_ui.get_node("InfoVBox/RoleLabel")
	if role_label:
		role_label.text = "[%s]" % CharacterQuiz.get_role_name(role)

	# Update HP
	var hp_bar = companion_ui.get_node("InfoVBox/HPContainer/HPBar")
	var hp_label = companion_ui.get_node("InfoVBox/HPContainer/HPLabel")

	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = hp

		# Set initial color
		var hp_percent = float(hp) / float(max_hp)
		var style = StyleBoxFlat.new()
		if hp_percent > 0.5:
			style.bg_color = Color(0.0, 0.8, 0.0)
		elif hp_percent > 0.25:
			style.bg_color = Color(0.9, 0.7, 0.0)
		else:
			style.bg_color = Color(0.9, 0.0, 0.0)
		hp_bar.add_theme_stylebox_override("fill", style)

	if hp_label:
		hp_label.text = "%d/%d HP" % [hp, max_hp]

	# Set companion weapon icon
	_update_companion_weapon()

	print("PartyUI: Companion added - %s %s" % [race, role])


## Update companion HP (called when companion takes damage/heals)
func update_companion_hp(current: int, maximum: int) -> void:
	if not companion_ui or not companion_ui.visible:
		return

	var hp_bar = companion_ui.get_node("InfoVBox/HPContainer/HPBar")
	var hp_label = companion_ui.get_node("InfoVBox/HPContainer/HPLabel")

	if hp_bar:
		hp_bar.max_value = maximum
		hp_bar.value = current

		# Change color based on HP percentage
		var hp_percent = float(current) / float(maximum)
		var style = StyleBoxFlat.new()

		if hp_percent > 0.5:
			style.bg_color = Color(0.0, 0.8, 0.0)  # Green
		elif hp_percent > 0.25:
			style.bg_color = Color(0.9, 0.7, 0.0)  # Yellow
		else:
			style.bg_color = Color(0.9, 0.0, 0.0)  # Red

		hp_bar.add_theme_stylebox_override("fill", style)

	if hp_label:
		hp_label.text = "%d/%d HP" % [current, maximum]


func _process(_delta: float) -> void:
	# Keep UI positioned correctly if screen resizes
	var viewport_size = get_viewport_rect().size
	party_container.position = Vector2(viewport_size.x - 260, 70)

	# Update weapon icons regularly to reflect equipped weapons
	if player_ui and player_ui.visible:
		_update_player_weapon()
	if companion_ui and companion_ui.visible:
		_update_companion_weapon()


func _update_companion_weapon() -> void:
	"""Update companion weapon icon based on equipped weapon"""
	var weapon_icon = companion_ui.get_node("WeaponIcon")
	if not weapon_icon:
		print("PartyUI: Could not find companion WeaponIcon node!")
		return

	# Check equipped weapon from inventory first
	var inventory = get_node_or_null("/root/Main/Game/CharacterAvatar/Inventory")
	var equipped_item = null

	if inventory:
		equipped_item = inventory.get_companion_equipped_weapon()
		if equipped_item:
			print("PartyUI: Companion equipped weapon ID: %d" % equipped_item.id)

	# If no equipped weapon, show default racial weapon from item database
	if not equipped_item:
		# Get default weapon ID based on race
		var default_weapon_id = _get_companion_default_weapon_id()
		if default_weapon_id >= 0:
			var item_db = get_node_or_null("/root/Main/Game/Items")
			if item_db:
				var item = item_db.get_item(default_weapon_id)
				if item and item.base_info.sprite:
					weapon_icon.texture = item.base_info.sprite
				else:
					weapon_icon.texture = null
			else:
				weapon_icon.texture = null
		else:
			weapon_icon.texture = null
		return

	# Load equipped weapon sprite from item database
	if equipped_item.type == 1:  # TYPE_ITEM
		var item_db = get_node_or_null("/root/Main/Game/Items")
		if item_db:
			var item = item_db.get_item(equipped_item.id)
			if item and item.base_info.sprite:
				weapon_icon.texture = item.base_info.sprite
			else:
				weapon_icon.texture = null
	else:
		weapon_icon.texture = null


func _get_companion_default_weapon_id() -> int:
	"""Get the default weapon ID for companion's race"""
	# Map race to default weapon ID (from item_db.gd)
	match CompanionManager.companion_race:
		"dwarf":
			return 7  # stone_hammer
		"elf":
			return 9  # crossbow
		"goblin":
			if CompanionManager.companion_gender == "female":
				return 5  # throwing_knives
			else:
				return 0  # rocket_launcher
		"human":
			return 8  # machete
	return -1
