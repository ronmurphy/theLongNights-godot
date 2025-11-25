extends Control
## PotionChoiceDialog - Modal for choosing who drinks a stat potion
## Shows smart UI based on stat caps and availability

signal choice_made(target: String)  # "player", "companion", or "cancel"

const LUCK_CAP = 5  # Effective luck cap (can store more, but only 5 counts in combat)

var potion_type: String = ""  # "hp", "defense", "attack", "luck"
var stat_name: String = ""  # Display name
var bonus_amount: int = 0  # How much this potion gives

@onready var _dialog_panel = $Panel
@onready var _title_label = $Panel/VBox/Title
@onready var _message_label = $Panel/VBox/Message
@onready var _button_container = $Panel/VBox/ButtonContainer
@onready var _player_button = $Panel/VBox/ButtonContainer/PlayerButton
@onready var _companion_button = $Panel/VBox/ButtonContainer/CompanionButton
@onready var _cancel_button = $Panel/VBox/ButtonContainer/CancelButton


func _ready():
	hide()

	# Connect button signals
	_player_button.pressed.connect(_on_player_clicked)
	_companion_button.pressed.connect(_on_companion_clicked)
	_cancel_button.pressed.connect(_on_cancel_clicked)


func show_potion_choice(p_type: String, p_stat_name: String, p_bonus: int) -> void:
	"""Show the dialog with appropriate options based on current stats"""
	potion_type = p_type
	stat_name = p_stat_name
	bonus_amount = p_bonus

	# Get current stat bonuses
	var player_current = _get_player_stat_bonus()
	var companion_current = _get_companion_stat_bonus()

	# Check caps (only luck has a cap currently)
	var player_at_cap = false
	var companion_at_cap = false

	if potion_type == "luck":
		player_at_cap = (player_current >= LUCK_CAP)
		companion_at_cap = (companion_current >= LUCK_CAP)

	# Get companion name (or "None" if no companion)
	var companion_name = _get_active_companion_name()
	var has_companion = (companion_name != "")

	# Set title
	_title_label.text = "Who drinks the %s Potion?" % stat_name.capitalize()

	# Determine which buttons to show
	if potion_type == "luck":
		if player_at_cap and companion_at_cap:
			# BOTH at cap - only show cancel
			_message_label.text = "Both you and your companion have max %s! (%d/%d)\nSell to Daniel for 20 rust blocks or save for a new companion." % [stat_name, LUCK_CAP, LUCK_CAP]
			_player_button.hide()
			_companion_button.hide()
			_cancel_button.show()
			_cancel_button.text = "Cancel"

		elif player_at_cap and not companion_at_cap:
			# Player at cap, companion not
			if has_companion:
				_message_label.text = "Your %s is maxed out! (%d/%d)\nUse potion on companion?" % [stat_name, player_current, LUCK_CAP]
				_player_button.hide()
				_companion_button.show()
				_companion_button.text = companion_name
				_cancel_button.show()
				_cancel_button.text = "Cancel"
			else:
				# No companion to give it to
				_message_label.text = "Your %s is maxed out! (%d/%d)\nNo companion to use potion on." % [stat_name, player_current, LUCK_CAP]
				_player_button.hide()
				_companion_button.hide()
				_cancel_button.show()
				_cancel_button.text = "Cancel"

		elif not player_at_cap and companion_at_cap:
			# Companion at cap, player not
			if has_companion:
				_message_label.text = "Companion's %s is maxed out! (%d/%d)\nUse potion?" % [stat_name, companion_current, LUCK_CAP]
				_player_button.show()
				_player_button.text = PlayerData.player_name if PlayerData.player_name != "" else "Player"
				_companion_button.hide()
				_cancel_button.show()
				_cancel_button.text = "Cancel"
			else:
				# Normal choice, just player
				_message_label.text = "%s (+%d)" % [stat_name.capitalize(), bonus_amount]
				_player_button.show()
				_player_button.text = PlayerData.player_name if PlayerData.player_name != "" else "Player"
				_companion_button.hide()
				_cancel_button.show()
				_cancel_button.text = "Cancel"
		else:
			# Neither at cap - show both options
			_message_label.text = "%s (+%d)" % [stat_name.capitalize(), bonus_amount]
			_player_button.show()
			_player_button.text = PlayerData.player_name if PlayerData.player_name != "" else "Player"
			if has_companion:
				_companion_button.show()
				_companion_button.text = companion_name
			else:
				_companion_button.hide()
			_cancel_button.show()
			_cancel_button.text = "Cancel"
	else:
		# HP/Defense/Attack - no caps, just show both options
		_message_label.text = "%s (+%d)" % [stat_name.capitalize(), bonus_amount]
		_player_button.show()
		_player_button.text = PlayerData.player_name if PlayerData.player_name != "" else "Player"
		if has_companion:
			_companion_button.show()
			_companion_button.text = companion_name
		else:
			_companion_button.hide()
		_cancel_button.show()
		_cancel_button.text = "Cancel"

	# Show dialog
	show()


func _get_player_stat_bonus() -> int:
	"""Get player's current bonus for this potion type"""
	match potion_type:
		"hp": return PlayerData.bonus_max_hp
		"defense": return PlayerData.bonus_defense
		"attack": return PlayerData.bonus_attack
		"luck": return PlayerData.bonus_luck
		_: return 0


func _get_companion_stat_bonus() -> int:
	"""Get companion's current bonus for this potion type"""
	match potion_type:
		"hp": return CompanionManager.companion_bonus_max_hp
		"defense": return CompanionManager.companion_bonus_defense
		"attack": return CompanionManager.companion_bonus_attack
		"luck": return CompanionManager.companion_bonus_luck
		_: return 0


func _get_active_companion_name() -> String:
	"""Get active companion's name, or empty string if none"""
	var companions = get_tree().get_nodes_in_group("companions")
	if companions.size() > 0:
		return companions[0].entity_name
	return ""


func _on_player_clicked() -> void:
	hide()
	choice_made.emit("player")


func _on_companion_clicked() -> void:
	hide()
	choice_made.emit("companion")


func _on_cancel_clicked() -> void:
	hide()
	choice_made.emit("cancel")
