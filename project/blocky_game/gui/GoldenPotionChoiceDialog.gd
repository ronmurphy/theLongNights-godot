extends Control
## GoldenPotionChoiceDialog - Modal for choosing a special blessing from golden potion
## Shows 4 blessing options with descriptions

signal blessing_chosen(blessing: String)  # "speed", "regen", "mana", "glide", or "cancel"

var target_name: String = ""  # Name of who will receive the blessing

@onready var _dialog_panel = $Panel
@onready var _title_label = $Panel/VBox/Title
@onready var _message_label = $Panel/VBox/Message
@onready var _button_container = $Panel/VBox/ButtonContainer
@onready var _speed_button = $Panel/VBox/ButtonContainer/SpeedButton
@onready var _regen_button = $Panel/VBox/ButtonContainer/RegenButton
@onready var _mana_button = $Panel/VBox/ButtonContainer/ManaButton
@onready var _glide_button = $Panel/VBox/ButtonContainer/GlideButton
@onready var _cancel_button = $Panel/VBox/ButtonContainer/CancelButton


func _ready():
	add_to_group("golden_potion_dialog")
	hide()

	# Connect button signals
	_speed_button.pressed.connect(_on_speed_clicked)
	_regen_button.pressed.connect(_on_regen_clicked)
	_mana_button.pressed.connect(_on_mana_clicked)
	_glide_button.pressed.connect(_on_glide_clicked)
	_cancel_button.pressed.connect(_on_cancel_clicked)


func show_blessing_choice(target: String) -> void:
	"""Show the blessing selection dialog"""
	# Get target name
	if target == "player":
		target_name = PlayerData.player_name if PlayerData.player_name != "" else "Player"
	elif target == "companion":
		var companions = get_tree().get_nodes_in_group("companions")
		if companions.size() > 0:
			target_name = companions[0].entity_name
		else:
			target_name = "Companion"

	# Set title and message
	_title_label.text = "Choose a Blessing for %s" % target_name
	_message_label.text = "Select a permanent enhancement:"

	# Set button tooltips
	_speed_button.tooltip_text = "Increases movement speed by 15%"
	_regen_button.tooltip_text = "HP regenerates 3x faster (60s instead of 180s)"
	_mana_button.tooltip_text = "Increases max mana by 20 (for wizard/healer)"
	_glide_button.tooltip_text = "Gain permanent glide ability"

	# Show dialog
	show()


func _on_speed_clicked() -> void:
	hide()
	blessing_chosen.emit("speed")


func _on_regen_clicked() -> void:
	hide()
	blessing_chosen.emit("regen")


func _on_mana_clicked() -> void:
	hide()
	blessing_chosen.emit("mana")


func _on_glide_clicked() -> void:
	hide()
	blessing_chosen.emit("glide")


func _on_cancel_clicked() -> void:
	hide()
	blessing_chosen.emit("cancel")
