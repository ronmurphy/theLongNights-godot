extends TextureRect

const InventoryItem = preload("res://blocky_game/player/inventory_item.gd")
const Blocks = preload("../blocks/blocks.gd")
const ItemDB = preload("../items/item_db.gd")

@onready var _block_types : Blocks = get_node("/root/Main/Game/Blocks")
@onready var _item_db : ItemDB = get_node("/root/Main/Game/Items")

var _count_label : Label = null
var _skyshard_label : Label = null  # Skyshard counter (bottom-left, light blue)
var _power_badge : Label = null  # Power type badge (top-left, for harmonized items)

# Enchantment outline shader
var _enchant_shader : Shader = preload("res://blocky_game/shaders/item_enchant_outline.gdshader")
var _shader_material : ShaderMaterial = null


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

	# Create power badge label (top-left, for harmonized items)
	_power_badge = Label.new()
	_power_badge.name = "PowerBadge"
	_power_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_power_badge.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_power_badge.add_theme_color_override("font_outline_color", Color.BLACK)
	_power_badge.add_theme_constant_override("outline_size", 3)
	_power_badge.add_theme_font_size_override("font_size", 16)
	_power_badge.visible = false
	add_child(_power_badge)

	# Position label at top-left of item icon
	_power_badge.offset_left = 1
	_power_badge.offset_top = -2


func set_item(data: InventoryItem):
	if data == null:
		texture = null
		tooltip_text = ""
		if _count_label:
			_count_label.visible = false
		if _skyshard_label:
			_skyshard_label.visible = false
		if _power_badge:
			_power_badge.visible = false
		# Remove outline for empty slots
		_apply_enchant_outline(Color.TRANSPARENT, Color.TRANSPARENT)

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

		# Blocks never have skyshard enhancements or power badges
		if _skyshard_label:
			_skyshard_label.visible = false
		if _power_badge:
			_power_badge.visible = false

		# Blocks don't get enchantment outlines
		_apply_enchant_outline(Color.TRANSPARENT, Color.TRANSPARENT)

	elif data.type == InventoryItem.TYPE_ITEM:
		var item := _item_db.get_item(data.id)
		texture = item.base_info.sprite

		# Set tooltip with item name
		tooltip_text = item.base_info.name.capitalize()

		# Get all powers (legacy + new system)
		var all_powers = data.get_all_powers()

		# Add powers to tooltip
		if all_powers.size() > 0:
			# Check power types
			var hotbar_powers = []
			var equip_powers = []
			for power in all_powers:
				if _is_equip_power(power):
					equip_powers.append(power)
				else:
					hotbar_powers.append(power)

			# Build tooltip with power types
			if hotbar_powers.size() > 0:
				for power in hotbar_powers:
					var power_display = _get_power_display_name(power)
					var strength = data.get_power_strength(power)
					if strength < 1.0:
						tooltip_text += "\n⚔️ HOTBAR: %s (%.0f%%)" % [power_display, strength * 100]
					else:
						tooltip_text += "\n⚔️ HOTBAR: " + power_display

			if equip_powers.size() > 0:
				for power in equip_powers:
					var power_display = _get_power_display_name(power)
					var strength = data.get_power_strength(power)
					if strength < 1.0:
						tooltip_text += "\n🛡️ EQUIP: %s (%.0f%%)" % [power_display, strength * 100]
					else:
						tooltip_text += "\n🛡️ EQUIP: " + power_display

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

		# Show power badge for harmonized items (top-left)
		if _power_badge:
			if all_powers.size() >= 2:
				# Harmonized item - determine badge emoji
				var hotbar_count = 0
				var equip_count = 0
				for power in all_powers:
					if _is_equip_power(power):
						equip_count += 1
					else:
						hotbar_count += 1

				if hotbar_count > 0 and equip_count > 0:
					_power_badge.text = "⚡"  # Mixed powers
				elif hotbar_count > 0:
					_power_badge.text = "⚔️"  # HOTBAR powers only
				else:
					_power_badge.text = "🛡️"  # EQUIP powers only

				_power_badge.visible = true
			else:
				_power_badge.visible = false

		# Apply enchantment outline based on power type
		if all_powers.size() > 0:
			var outline_colors = _get_enchant_outline_colors(all_powers)
			_apply_enchant_outline(outline_colors[0], outline_colors[1])
		else:
			_apply_enchant_outline(Color.TRANSPARENT, Color.TRANSPARENT)

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
		"glide":
			return "Glide"
		"return":
			return "Return"
		_:
			return power_id.capitalize()  # Fallback


func _is_equip_power(power_name: String) -> bool:
	"""Check if power is an EQUIP type (passive powers)"""
	return power_name in ["stone_skin", "moon_jump", "flame_aura", "glide", "return"]


func _get_enchant_outline_colors(all_powers: Array) -> Array:
	"""Determine outline gradient colors based on power types - returns [color1, color2]"""
	if all_powers.is_empty():
		return [Color.TRANSPARENT, Color.TRANSPARENT]

	# Count power types
	var hotbar_count = 0
	var equip_count = 0
	for power in all_powers:
		if _is_equip_power(power):
			equip_count += 1
		else:
			hotbar_count += 1

	# Return appropriate gradient color pair
	if hotbar_count > 0 and equip_count > 0:
		# Mixed powers - cyan to electric blue gradient ⚡
		return [Color(0.3, 0.9, 1.0, 1.0), Color(0.0, 0.6, 1.0, 1.0)]
	elif hotbar_count > 0:
		# Hotbar powers only - purple to magenta gradient ⚔️
		return [Color(0.6, 0.2, 1.0, 1.0), Color(1.0, 0.2, 0.8, 1.0)]
	else:
		# Equip powers only - gold to orange gradient 🛡️
		return [Color(1.0, 0.9, 0.0, 1.0), Color(1.0, 0.6, 0.0, 1.0)]


func _apply_enchant_outline(outline_color: Color, outline_color_2: Color) -> void:
	"""Apply or remove enchantment outline shader with gradient"""
	if outline_color.a > 0.0:
		# Create shader material if needed
		if _shader_material == null:
			_shader_material = ShaderMaterial.new()
			_shader_material.shader = _enchant_shader

		# Set shader parameters for gradient outline
		_shader_material.set_shader_parameter("intensity", 50)
		_shader_material.set_shader_parameter("precision", 0.01)
		_shader_material.set_shader_parameter("flipColors", false)
		_shader_material.set_shader_parameter("outline_color", outline_color)
		_shader_material.set_shader_parameter("outline_color_2", outline_color_2)
		_shader_material.set_shader_parameter("use_outline_uv", false)
		_shader_material.set_shader_parameter("useTexture", false)

		# Apply shader
		material = _shader_material
	else:
		# Remove shader
		material = null
