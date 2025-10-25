extends Node
## BlockTextureManager - Loads and manages block textures
## Handles naming conventions: -all, -sides, -top, -bottom, -top-bottom

class_name BlockTextureManager

# Texture cache
var textures: Dictionary = {}  # Dictionary[String, Texture2D]

# Block definitions with texture mappings
var block_types: Dictionary = {
	0: {"name": "air", "textures": {}},  # Empty block
	1: {"name": "grass", "textures": {"top": "grass", "sides": "dirt", "bottom": "dirt"}},  # Grass block
	2: {"name": "dirt", "textures": {"all": "dirt"}},  # Dirt block
	3: {"name": "stone", "textures": {"all": "stone"}},  # Stone block
}

func _ready() -> void:
	print("Loading block textures...")
	_load_textures()
	print("Block textures loaded successfully")

## Load all textures from assets/art/blocks/
func _load_textures() -> void:
	var texture_names = ["grass", "dirt", "stone"]

	for tex_name in texture_names:
		var path = "res://assets/art/blocks/%s.jpeg" % tex_name
		if ResourceLoader.exists(path):
			var texture = load(path)
			textures[tex_name] = texture
			print("  Loaded: %s" % tex_name)
		else:
			print("  WARNING: Missing texture: %s" % path)

## Get texture for a specific block face
## Returns Texture2D or null
func get_block_face_texture(block_id: int, face: String) -> Texture2D:
	if not block_types.has(block_id):
		return null

	var block = block_types[block_id]
	var tex_map = block["textures"]

	# Check for specific face texture
	if tex_map.has(face):
		var tex_name = tex_map[face]
		return textures.get(tex_name, null)

	# Check for "all" faces texture
	if tex_map.has("all"):
		var tex_name = tex_map["all"]
		return textures.get(tex_name, null)

	# Check for sides/top-bottom groups
	if face in ["front", "back", "left", "right"] and tex_map.has("sides"):
		var tex_name = tex_map["sides"]
		return textures.get(tex_name, null)

	return null

## Create a material with a texture
func create_textured_material(texture: Texture2D) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # Pixelated look
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	return material
