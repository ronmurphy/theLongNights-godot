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

# Track previous HP to detect damage vs healing
var _prev_player_hp: int = 0
var _prev_companion_hp: int = 0

# Track jumping states for avatar updates
var _player_is_jumping: bool = false
var _companion_is_jumping: bool = false


func _get_inventory():
	"""Helper to find inventory in scene tree"""
	var inventory = get_node_or_null("/root/Main/Game/CharacterAvatar/Inventory")
	if not inventory:
		var char_avatar = get_tree().get_first_node_in_group("player")
		if char_avatar:
			inventory = char_avatar.get_node_or_null("Inventory")
	return inventory


func _ready() -> void:
	# Create UI
	_create_ui()

	# Connect to player after scene is ready
	call_deferred("_connect_to_player")
	
	# Connect to inventory equipment changes
	call_deferred("_connect_to_inventory")

	print("PartyUI: Ready")


func _create_ui() -> void:
	# Main container for all party members
	party_container = VBoxContainer.new()
	party_container.name = "PartyContainer"
	party_container.add_theme_constant_override("separation", 8)
	add_child(party_container)

	# Position in top-right (under time/day display) with margin from edge
	var viewport_size = get_viewport_rect().size
	party_container.position = Vector2(viewport_size.x - 310, 70)

	# Create player UI
	player_ui = _create_party_member_ui(false)
	player_ui.name = "PlayerUI"
	party_container.add_child(player_ui)

	# Companion UI will be added when companion spawns
	# For now, hide it
	companion_ui = _create_party_member_ui(true)
	companion_ui.name = "CompanionUI"
	companion_ui.visible = false
	party_container.add_child(companion_ui)


func _create_party_member_ui(is_companion: bool = false) -> Control:
	# Container for one party member
	var member_container = HBoxContainer.new()
	member_container.add_theme_constant_override("separation", 8)
	member_container.custom_minimum_size = Vector2(280, 90)  # Adjusted for larger avatar

	# Avatar sprite (left side)
	var avatar_bg = Panel.new()
	avatar_bg.name = "AvatarBG"
	avatar_bg.custom_minimum_size = Vector2(90, 90)  # Larger for better visibility

	# Style avatar background
	var avatar_style = StyleBoxFlat.new()
	avatar_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	avatar_style.border_color = Color(0.6, 0.5, 0.3)
	avatar_style.set_border_width_all(2)
	avatar_bg.add_theme_stylebox_override("panel", avatar_style)

	var avatar_texture = TextureRect.new()
	avatar_texture.name = "AvatarTexture"
	avatar_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	avatar_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Center the texture within the panel
	avatar_texture.anchor_left = 0.0
	avatar_texture.anchor_top = 0.0
	avatar_texture.anchor_right = 1.0
	avatar_texture.anchor_bottom = 1.0
	avatar_texture.grow_horizontal = Control.GROW_DIRECTION_BOTH
	avatar_texture.grow_vertical = Control.GROW_DIRECTION_BOTH
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
	
	# Title label (for companion synergy titles)
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = ""  # Hidden by default
	title_label.add_theme_font_size_override("font_size", 11)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))  # Gold color
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.add_theme_constant_override("outline_size", 1)
	title_label.visible = false
	info_vbox.add_child(title_label)

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

	# Hunt countdown timer (only for companions, shows when hunting)
	var hunt_timer_label = Label.new()
	hunt_timer_label.name = "HuntTimerLabel"
	hunt_timer_label.text = ""
	hunt_timer_label.add_theme_font_size_override("font_size", 11)
	hunt_timer_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	hunt_timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hunt_timer_label.add_theme_constant_override("outline_size", 1)
	hunt_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(hunt_timer_label)

	# Behavior mode label (only for companions, shows current AI behavior)
	var behavior_label = Label.new()
	behavior_label.name = "BehaviorLabel"
	behavior_label.text = ""  # Hidden by default until mode is set
	behavior_label.add_theme_font_size_override("font_size", 11)
	behavior_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	behavior_label.add_theme_color_override("font_outline_color", Color.BLACK)
	behavior_label.add_theme_constant_override("outline_size", 1)
	behavior_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_vbox.add_child(behavior_label)

	# Weapon icon container (added to HBoxContainer to position properly)
	var weapon_container = Control.new()
	weapon_container.name = "WeaponContainer"
	weapon_container.custom_minimum_size = Vector2(40, 80)  # Match avatar height
	
	# Add a background panel for visibility
	var weapon_bg = Panel.new()
	weapon_bg.name = "WeaponBG"
	weapon_bg.custom_minimum_size = Vector2(36, 36)
	weapon_bg.position = Vector2(2, 2)  # Small offset from container edge
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	bg_style.border_color = Color(0.4, 0.4, 0.4)
	bg_style.set_border_width_all(1)
	weapon_bg.add_theme_stylebox_override("panel", bg_style)
	weapon_container.add_child(weapon_bg)
	
	# Weapon icon (positioned inside the background)
	var weapon_texture = TextureRect.new()
	weapon_texture.name = "WeaponIcon"
	weapon_texture.custom_minimum_size = Vector2(32, 32)
	weapon_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	weapon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	weapon_texture.position = Vector2(4, 4)  # Centered in background
	weapon_container.add_child(weapon_texture)

	member_container.add_child(weapon_container)

	return member_container


func _connect_to_player() -> void:
	# Find player
	player_node = get_tree().get_first_node_in_group("player")
	if not player_node:
		# Player not spawned yet, retry after a delay
		await get_tree().create_timer(0.5).timeout
		_connect_to_player()
		return

	# Connect to player HP changes
	if player_node.has_signal("hp_changed"):
		player_node.hp_changed.connect(_on_player_hp_changed)

	# Initial update
	_update_player_ui()

	print("PartyUI: Connected to player")


func _connect_to_inventory() -> void:
	"""Connect to inventory's equipment_changed signal"""
	var inventory = _get_inventory()
	
	if inventory:
		if inventory.has_signal("equipment_changed"):
			inventory.equipment_changed.connect(_on_equipment_changed)
		else:
			push_warning("PartyUI: Inventory doesn't have equipment_changed signal!")
	else:
		# Retry after a delay
		await get_tree().create_timer(1.0).timeout
		_connect_to_inventory()


func _on_equipment_changed() -> void:
	"""Called when equipment changes in inventory"""
	_update_player_weapon()
	_update_companion_weapon()



func _update_player_ui() -> void:
	if not player_ui or not player_node:
		return

	# Update avatar
	var avatar_path = PlayerData.get_avatar_path("ready")
	var avatar_texture_rect = player_ui.get_node("AvatarBG/AvatarTexture")
	if avatar_texture_rect:
		if ResourceLoader.exists(avatar_path):
			var texture = load(avatar_path)
			if texture:
				avatar_texture_rect.texture = texture
			else:
				push_warning("PartyUI: Failed to load player avatar texture from: ", avatar_path)
		else:
			push_warning("PartyUI: Player avatar path does not exist: ", avatar_path)

	# Update name
	var name_label = player_ui.get_node("InfoVBox/NameLabel")
	if name_label:
		name_label.text = PlayerData.player_name

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
	
	# Flash red only when taking damage (HP decreased)
	if _prev_player_hp > 0 and current < _prev_player_hp:
		_flash_avatar_red(player_ui)
	
	_prev_player_hp = current


func _update_player_weapon() -> void:
	# Get weapon icon
	var weapon_icon = player_ui.get_node("WeaponContainer/WeaponIcon")
	if not weapon_icon:
		return

	# Check equipped weapon from inventory first
	var inventory = _get_inventory()
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
		name_label.text = CompanionManager.get_companion_name()

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
	
	# Flash red only when taking damage (HP decreased)
	if _prev_companion_hp > 0 and current < _prev_companion_hp:
		_flash_avatar_red(companion_ui)
	
	_prev_companion_hp = current


func _process(_delta: float) -> void:
	# Keep UI positioned correctly if screen resizes
	var viewport_size = get_viewport_rect().size
	party_container.position = Vector2(viewport_size.x - 310, 70)

	# Update hunt timer display
	_update_hunt_timer()

	# Update jumping avatars
	_update_jumping_avatars()


func _update_jumping_avatars() -> void:
	"""Update player and companion avatars to show jumping sprites when airborne"""
	# Update player avatar
	if player_node:
		var player_jumping = not player_node._grounded
		if player_jumping != _player_is_jumping:
			_player_is_jumping = player_jumping
			_update_player_avatar_for_jump()

	# Update companion avatar
	var companion = get_tree().get_first_node_in_group("companion")
	if companion:
		var companion_jumping = not companion._grounded
		if companion_jumping != _companion_is_jumping:
			_companion_is_jumping = companion_jumping
			_update_companion_avatar_for_jump()


func _update_player_avatar_for_jump() -> void:
	"""Update player avatar based on jumping state"""
	if not player_ui:
		return

	var pose = "jumping" if _player_is_jumping else "ready"
	var avatar_path = PlayerData.get_avatar_path(pose)
	var avatar_texture_rect = player_ui.get_node("AvatarBG/AvatarTexture")

	if avatar_texture_rect and ResourceLoader.exists(avatar_path):
		var texture = load(avatar_path)
		if texture:
			avatar_texture_rect.texture = texture


func _update_companion_avatar_for_jump() -> void:
	"""Update companion avatar based on jumping state"""
	if not companion_ui or not companion_ui.visible:
		return

	var race = CompanionManager.race
	var gender = CompanionManager.gender
	var pose = "jumping" if _companion_is_jumping else "ready"
	var avatar_path = CharacterQuiz.get_avatar_path(race, gender, pose)
	var avatar_texture_rect = companion_ui.get_node("AvatarBG/AvatarTexture")

	if avatar_texture_rect and ResourceLoader.exists(avatar_path):
		var texture = load(avatar_path)
		if texture:
			avatar_texture_rect.texture = texture


func _update_companion_weapon() -> void:
	"""Update companion weapon icon based on equipped weapon"""
	if not companion_ui:
		return
		
	if not companion_ui.visible:
		return
		
	var weapon_icon = companion_ui.get_node("WeaponContainer/WeaponIcon")
	if not weapon_icon:
		push_warning("PartyUI: Could not find companion WeaponIcon node!")
		return

	# Check equipped weapon from inventory first
	var inventory = _get_inventory()
	var equipped_item = null

	if inventory:
		equipped_item = inventory.get_companion_equipped_weapon()

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


func update_companion_behavior(mode: String) -> void:
	"""Update companion behavior mode display in PartyUI"""
	if not companion_ui or not companion_ui.visible:
		return
	
	var behavior_label = companion_ui.get_node_or_null("InfoVBox/BehaviorLabel")
	if not behavior_label:
		return
	
	# Update text and color based on mode
	match mode:
		"aggressive":
			behavior_label.text = "⚔️ Aggressive"
			behavior_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		"defensive":
			behavior_label.text = "🛡️ Defensive"
			behavior_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
		"guard":
			behavior_label.text = "🏰 Guard"
			behavior_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
		"normal":
			behavior_label.text = "⚖️ Normal"
			behavior_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		_:
			behavior_label.text = ""


func _update_hunt_timer() -> void:
	"""Update hunt countdown timer for companion"""
	if not companion_ui or not companion_ui.visible:
		return
	
	var hunt_timer_label = companion_ui.get_node_or_null("InfoVBox/HuntTimerLabel")
	if not hunt_timer_label:
		return
	
	# Check if HuntingSystem exists and if hunting
	if not HuntingSystem or not HuntingSystem.is_hunting:
		hunt_timer_label.text = ""
		return
	
	# Calculate remaining hunt time
	var hours_remaining = HuntingSystem.hunt_duration_hours - HuntingSystem.hunt_elapsed_hours
	var minutes_remaining = 0  # Could track partial hours if needed
	
	if hours_remaining <= 0:
		hunt_timer_label.text = ""
	else:
		hunt_timer_label.text = "Hunting: %d:%02d remaining" % [hours_remaining, minutes_remaining]


## Flash avatar red when taking damage
func _flash_avatar_red(member_ui: Control) -> void:
	if not member_ui:
		return
	
	var avatar_texture = member_ui.get_node_or_null("AvatarBG/AvatarTexture")
	if not avatar_texture:
		return
	
	# Kill any existing tweens on this node to prevent conflicts
	var tweens = get_tree().get_processed_tweens()
	for tween in tweens:
		if tween.is_valid():
			tween.kill()
	
	# Store original modulate color
	var original_color = Color(1.0, 1.0, 1.0, 1.0)  # Default white
	
	# Flash red
	avatar_texture.modulate = Color(1.5, 0.5, 0.5, 1.0)  # Bright red tint
	
	# Tween back to original color
	var tween = create_tween()
	tween.tween_property(avatar_texture, "modulate", original_color, 0.3)


func update_companion_title(emoji: String, title: String):
	"""Update companion's earned title display"""
	if not companion_ui:
		return
	
	var title_label = companion_ui.get_node_or_null("InfoVBox/TitleLabel")
	if not title_label:
		return
	
	if title != "":
		title_label.text = "%s %s" % [emoji, title]
		title_label.visible = true
		title_label.tooltip_text = "Synergy Title: %s" % title
	else:
		title_label.text = ""
		title_label.visible = false
		title_label.tooltip_text = ""
