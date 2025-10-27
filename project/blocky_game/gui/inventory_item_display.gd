extends TextureRect

const InventoryItem = preload("res://blocky_game/player/inventory_item.gd")
const Blocks = preload("../blocks/blocks.gd")
const ItemDB = preload("../items/item_db.gd")

@onready var _block_types : Blocks = get_node("/root/Main/Game/Blocks")
@onready var _item_db : ItemDB = get_node("/root/Main/Game/Items")

var _count_label : Label = null


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


func set_item(data: InventoryItem):
	if data == null:
		texture = null
		if _count_label:
			_count_label.visible = false

	elif data.type == InventoryItem.TYPE_BLOCK:
		var block := _block_types.get_block(data.id)
		var sprite_texture = block.base_info.sprite_texture
		
		# Check if this block has no sprite (might be tinted)
		if sprite_texture == null:
			# This is a tinted block - we need to find its tint and apply it
			# For now, use a placeholder or default sprite
			texture = null
		else:
			texture = sprite_texture
		
		if _count_label:
			_count_label.visible = false

	elif data.type == InventoryItem.TYPE_ITEM:
		var item := _item_db.get_item(data.id)
		texture = item.base_info.sprite

		# Show count for torches (item id 6)
		if _count_label:
			if data.id == 6 and data.count > 1:  # Torch
				_count_label.text = str(data.count)
				_count_label.visible = true
			else:
				_count_label.visible = false

	else:
		assert(false)
