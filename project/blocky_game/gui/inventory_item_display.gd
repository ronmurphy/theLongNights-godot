extends TextureRect

const InventoryItem = preload("res://blocky_game/player/inventory_item.gd")
const Blocks = preload("../blocks/blocks.gd")
const ItemDB = preload("../items/item_db.gd")

@onready var _block_types : Blocks = get_node("/root/Main/Game/Blocks")
@onready var _item_db : ItemDB = get_node("/root/Main/Game/Items")

var _count_label : Label = null
var _skyshard_label : Label = null  # Skyshard counter (bottom-left, light blue)


func _ready():
	# Create count label for stackable items
	_count_label = Label.new()
	_count_label.name = "CountLabel"
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count_label.add_theme_color_override("font_color", Color.WHITE)
	_count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_count_label.add_theme_constant_override("outline_size", 2)
	_count_label.visible = false
	add_child(_count_label)

	# Position label at bottom-right of item icon
	_count_label.anchor_right = 1.0
	_count_label.anchor_bottom = 1.0
	_count_label.offset_right = -2
	_count_label.offset_bottom = -2

	# Create skyshard counter label (bottom-left, light blue)
	_skyshard_label = Label.new()
	_skyshard_label.name = "ShyshardLabel"
	_skyshard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_skyshard_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_skyshard_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))  # Light blue
	_skyshard_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_skyshard_label.add_theme_constant_override("outline_size", 2)
	_skyshard_label.visible = false
	add_child(_skyshard_label)

	# Position label at bottom-left of item icon
	_skyshard_label.anchor_bottom = 1.0
	_skyshard_label.offset_left = 2
	_skyshard_label.offset_bottom = -2


func set_item(data: InventoryItem):
	if data == null:
		texture = null
		tooltip_text = ""
		if _count_label:
			_count_label.visible = false
		if _skyshard_label:
			_skyshard_label.visible = false

	elif data.type == InventoryItem.TYPE_BLOCK:
		var block := _block_types.get_block(data.id)
		var sprite_texture = block.base_info.sprite_texture

		# Set tooltip with block name
		tooltip_text = block.base_info.name.capitalize()

		# Check if this block has no sprite (might be tinted)
		if sprite_texture == null:
			# This is a tinted block - we need to find its tint and apply it
			# For now, use a placeholder or default sprite
			texture = null
		else:
			texture = sprite_texture

		# Show count for blocks when more than 1
		if _count_label:
			if data.count > 1:
				_count_label.text = str(data.count)
				_count_label.visible = true
			else:
				_count_label.visible = false

		# Blocks never have skyshard enhancements
		if _skyshard_label:
			_skyshard_label.visible = false

	elif data.type == InventoryItem.TYPE_ITEM:
		var item := _item_db.get_item(data.id)
		texture = item.base_info.sprite

		# Set tooltip with item name
		tooltip_text = item.base_info.name.capitalize()

		# Add power to tooltip if weapon has skyshard enhancement
		if data.skyshard_power != "":
			var power_display_name = _get_power_display_name(data.skyshard_power)
			tooltip_text += "\n✨ Power: " + power_display_name

		# Show count for all items when more than 1
		if _count_label:
			if data.count > 1:
				_count_label.text = str(data.count)
				_count_label.visible = true
			else:
				_count_label.visible = false

		# Show skyshard counter if this weapon/tool has skyshards infused
		if _skyshard_label:
			if data.skyshard_count > 0:
				_skyshard_label.text = str(data.skyshard_count)
				_skyshard_label.visible = true
			else:
				_skyshard_label.visible = false

	else:
		assert(false)


func _get_power_display_name(power_id: String) -> String:
	"""Convert power ID to human-readable display name"""
	match power_id:
		"meteor_strike":
			return "Meteor Strike"
		"ice_burst":
			return "Ice Burst"
		"lightning_chain":
			return "Lightning Chain"
		"life_steal":
			return "Life Steal"
		"moon_jump":
			return "Moon Jump"
		"flame_aura":
			return "Flame Aura"
		"wind_dash":
			return "Wind Dash"
		"poison_cloud":
			return "Poison Cloud"
		"stone_skin":
			return "Stone Skin"
		"knife_volley":
			return "Knife Volley"
		_:
			return power_id.capitalize()  # Fallback
