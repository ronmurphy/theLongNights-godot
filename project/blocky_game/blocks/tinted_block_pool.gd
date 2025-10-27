# Object pool for tinted blocks - reuses node instances for memory efficiency
extends Node

class_name TintedBlockPool

class PooledTintedBlock:
	var node: Node3D
	var in_use: bool = false
	var tint_block_name: String = ""
	
	func _init(p_node: Node3D):
		node = p_node
		in_use = false
		tint_block_name = ""


# Configuration
var _pool_size_per_type: int = 50  # How many of each tinted block to pre-allocate
var _blocks_system = null  # Reference to Blocks.gd
var _pool: Dictionary = {}  # Dictionary[String, Array[PooledTintedBlock]]
var _pool_parents: Dictionary = {}  # Keep pool nodes organized by type


func _ready():
	print("[TintedBlockPool] Initializing...")
	_blocks_system = get_parent()
	
	# Initialize pools for all available tinted blocks
	await get_tree().process_frame  # Wait for blocks system to be ready
	_initialize_pools()
	print("[TintedBlockPool] Initialization complete")


# Load tint definitions from JSON and pre-populate pools
func _initialize_pools():
	var tint_data = _load_tints_json()
	if tint_data == null:
		push_error("[TintedBlockPool] Failed to load block_tints.json")
		return
	
	# For each base block type that has tints
	for base_block_name in tint_data.keys():
		var tint_info = tint_data[base_block_name]
		var variants = tint_info.get("variants", [])
		
		for variant_info in variants:
			var tint_name = variant_info.get("name", "")
			if tint_name == "":
				push_error("[TintedBlockPool] Variant missing name in block_tints.json")
				continue
			
			# Create parent node for organization
			var parent = Node3D.new()
			parent.name = "Pool_" + tint_name
			add_child(parent)
			_pool_parents[tint_name] = parent
			
			# Pre-populate this tint's pool
			_pool[tint_name] = []
			for i in range(_pool_size_per_type):
				var pooled_block = _create_pooled_block(tint_name, base_block_name, variant_info)
				_pool[tint_name].append(pooled_block)


# Create a single pooled block instance
func _create_pooled_block(tint_name: String, base_block_name: String, variant_info: Dictionary) -> PooledTintedBlock:
	var node = Node3D.new()
	node.name = tint_name
	
	# Add mesh instance
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	node.add_child(mesh_instance)
	
	# Get material with tint applied
	var tinted_material = _create_tinted_material(base_block_name, variant_info)
	mesh_instance.material_override = tinted_material
	
	# Get mesh from base block
	var base_block = _blocks_system.get_block_by_name(base_block_name)
	if base_block.base_info.gui_model_path != "":
		var mesh = load(base_block.base_info.gui_model_path)
		mesh_instance.mesh = mesh
	
	# Add to pool parent
	var parent = _pool_parents[tint_name]
	parent.add_child(node)
	node.hide()  # Start hidden until requested
	
	var pooled = PooledTintedBlock.new(node)
	pooled.tint_block_name = tint_name
	return pooled


# Create a tinted material by cloning and applying color
func _create_tinted_material(base_block_name: String, variant_info: Dictionary) -> StandardMaterial3D:
	var base_block = _blocks_system.get_block_by_name(base_block_name)
	
	# Determine which base material to use based on block properties
	var base_material: StandardMaterial3D
	if base_block.base_info.transparent:
		base_material = load("res://blocky_game/blocks/terrain_material_transparent.tres")
	elif base_block.base_info.name in ["tall_grass", "leaves", "dead_shrub"]:
		base_material = load("res://blocky_game/blocks/terrain_material_foliage.tres")
	else:
		base_material = load("res://blocky_game/blocks/terrain_material.tres")
	
	# Clone and apply tint color
	var tinted_mat = base_material.duplicate()
	var color_array = variant_info.get("color", [1.0, 1.0, 1.0, 1.0])
	tinted_mat.albedo_color = Color(color_array[0], color_array[1], color_array[2], color_array[3])
	
	return tinted_mat


# Get a tinted block from the pool (or create new if pool exhausted)
func get_tinted_block(tint_block_name: String) -> Node3D:
	if not _pool.has(tint_block_name):
		push_error("[TintedBlockPool] Unknown tinted block: " + tint_block_name)
		return null
	
	var pool_array = _pool[tint_block_name]
	
	# Find available block
	var available_block: PooledTintedBlock = null
	for pooled in pool_array:
		if not pooled.in_use:
			available_block = pooled
			break
	
	# If no available blocks, create a new one (pool expansion)
	if available_block == null:
		print("[TintedBlockPool] Pool for '%s' exhausted, expanding..." % tint_block_name)
		
		# Re-load tint info to get variant details
		var tint_data = _load_tints_json()
		var variant_info = _find_variant_info(tint_data, tint_block_name)
		var base_block_name = _find_base_block_name(tint_data, tint_block_name)
		
		available_block = _create_pooled_block(tint_block_name, base_block_name, variant_info)
		pool_array.append(available_block)
	
	# Mark as in use and show
	available_block.in_use = true
	available_block.node.show()
	
	return available_block.node


# Return a tinted block to the pool
func return_tinted_block(tint_block_name: String, block_node: Node3D):
	if not _pool.has(tint_block_name):
		push_error("[TintedBlockPool] Unknown tinted block: " + tint_block_name)
		return
	
	var pool_array = _pool[tint_block_name]
	
	for pooled in pool_array:
		if pooled.node == block_node:
			pooled.in_use = false
			pooled.node.hide()
			pooled.node.get_parent().remove_child(pooled.node)  # Detach from scene
			return
	
	push_warning("[TintedBlockPool] Block not found in pool for: " + tint_block_name)


# Load and parse block_tints.json
func _load_tints_json() -> Dictionary:
	var file_path = "res://blocky_game/blocks/block_tints.json"
	var json_string = FileAccess.get_file_as_string(file_path)
	
	if json_string == "":
		push_error("[TintedBlockPool] Could not read block_tints.json")
		return {}
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("[TintedBlockPool] JSON parse error: " + str(error))
		return {}
	
	# Extract the "tints" section from JSON
	var data = json.get_data()
	if data == null:
		push_error("[TintedBlockPool] JSON data is null")
		return {}
	
	if data.has("tints"):
		return data["tints"]
	
	push_error("[TintedBlockPool] No 'tints' section in block_tints.json")
	return {}


# Helper: Find variant info by tint block name
func _find_variant_info(tint_data: Dictionary, tint_name: String) -> Dictionary:
	for base_block_name in tint_data.keys():
		var tint_info = tint_data[base_block_name]
		var variants = tint_info.get("variants", [])
		
		for variant_info in variants:
			if variant_info.get("name") == tint_name:
				return variant_info
	
	return {}


# Helper: Find base block name from tint data
func _find_base_block_name(tint_data: Dictionary, tint_name: String) -> String:
	for base_block_name in tint_data.keys():
		var tint_info = tint_data[base_block_name]
		var variants = tint_info.get("variants", [])
		
		for variant_info in variants:
			if variant_info.get("name") == tint_name:
				return base_block_name
	
	return ""


# Debug: Print pool statistics
func print_pool_stats():
	print("[TintedBlockPool] === Pool Statistics ===")
	for tint_name in _pool.keys():
		var pool_array = _pool[tint_name]
		var in_use_count = 0
		for pooled in pool_array:
			if pooled.in_use:
				in_use_count += 1
		print("  %s: %d in use, %d total" % [tint_name, in_use_count, len(pool_array)])
