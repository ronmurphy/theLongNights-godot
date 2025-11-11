extends Node

## LampManager - Tracks positions of placed light blocks AND sky ruin lights/spheres
## Manages spawning/despawning lights based on player distance
## Saves lamp positions to avoid expensive chunk scanning
##
## Handles two types of persistent lighting:
## 1. Player-placed lamps (ruin_void_lamp, void_beacon) - cyan/purple lights
## 2. Sky ruin teleport stones - colored lights + matching spheres around ruins

const SAVE_PATH = "user://save/lamps.json"
const RUINS_SAVE_PATH = "user://save/ruin_lights.json"
const ACTIVATION_DISTANCE = 48.0  # 3 chunks (16 blocks each)
const CHECK_INTERVAL = 2.0  # Check player distance every 2 seconds

# Lamp data: position → {type: "cyan" or "purple", active: bool, node: Node3D or null}
var lamps := {}

# Ruin data: ruin_position → {stones: [{pos, color}], sphere: {center, radius, color, opacity, has_enemies}}
var ruins := {}
var _check_timer := 0.0


func _ready():
	print("LampManager initialized")


func _process(delta):
	# Periodic distance checks for lamp activation/deactivation
	_check_timer += delta
	if _check_timer >= CHECK_INTERVAL:
		_check_timer = 0.0
		_update_lamp_activation()


func register_lamp(position: Vector3, type: String):
	"""Register a lamp when placed (type: "cyan" or "purple")"""
	var key = _pos_to_key(position)
	if not lamps.has(key):
		lamps[key] = {
			"position": position,
			"type": type,
			"active": false,
			"node": null
		}
		print("💡 Registered %s lamp at %s" % [type, position])
		save_lamps()


func register_ruin(ruin_position: Vector3, stone_positions_and_colors: Array, sphere_data: Dictionary):
	"""
	Register a ruin with its teleport stones and sphere
	stone_positions_and_colors: [{pos: Vector3, color: Color}, ...]
	sphere_data: {center: Vector3, radius: float, color: Color, opacity: float, has_enemies: bool}
	"""
	var key = _pos_to_key(ruin_position)
	if not ruins.has(key):
		var stones = []
		for stone in stone_positions_and_colors:
			stones.append({
				"position": stone.pos,
				"color": stone.color,
				"light_node": null
			})
		
		ruins[key] = {
			"ruin_position": ruin_position,
			"stones": stones,
			"sphere": sphere_data,
			"sphere_node": null,
			"active": false
		}
		print("🏛️ Registered ruin at %s with %d teleport stones" % [ruin_position, stones.size()])
		save_ruins()


func unregister_lamp(position: Vector3):
	"""Remove a lamp when mined"""
	var key = _pos_to_key(position)
	if lamps.has(key):
		# Remove light node if it exists
		if lamps[key].node and is_instance_valid(lamps[key].node):
			lamps[key].node.queue_free()
		lamps.erase(key)
		print("💡 Unregistered lamp at %s" % position)
		save_lamps()


func _update_lamp_activation():
	"""Check player distance and activate/deactivate lamps and ruins"""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var player_pos = player.global_position
	
	# Update regular lamps (cyan/purple void lamps)
	for key in lamps.keys():
		var lamp = lamps[key]
		var distance = lamp.position.distance_to(player_pos)
		
		# Should this lamp be active?
		var should_be_active = distance <= ACTIVATION_DISTANCE
		
		# Activate if close and not active
		if should_be_active and not lamp.active:
			_activate_lamp(key)
		
		# Deactivate if far and active
		elif not should_be_active and lamp.active:
			_deactivate_lamp(key)
	
	# Update ruin lights and spheres
	for key in ruins.keys():
		var ruin = ruins[key]
		var distance = ruin.ruin_position.distance_to(player_pos)
		
		# Should this ruin be active?
		var should_be_active = distance <= ACTIVATION_DISTANCE
		
		# Activate if close and not active
		if should_be_active and not ruin.active:
			print("🔵 Activating ruin at %s (distance: %.1f)" % [ruin.ruin_position, distance])
			_activate_ruin(key)
		
		# Deactivate if far and active
		elif not should_be_active and ruin.active:
			_deactivate_ruin(key)


func _activate_lamp(key: String):
	"""Spawn light for this lamp"""
	var lamp = lamps[key]
	if lamp.node and is_instance_valid(lamp.node):
		return  # Already has a light
	
	var game = get_tree().root.get_node_or_null("Main/Game")
	if not game:
		return
	
	if lamp.type == "cyan":
		# Spawn cyan PlacedLightOrb
		const PlacedLightOrb = preload("../blocky_game/items/light_orb/placed_light_orb.gd")
		var orb = Node3D.new()
		orb.set_script(PlacedLightOrb)
		orb.set("_custom_range", 15.0)
		game.add_child(orb)
		orb.global_position = lamp.position + Vector3(0.5, 1.0, 0.5)
		lamp.node = orb
		
	elif lamp.type == "purple":
		# Spawn purple UndervoidBeacon
		const UndervoidBeacon = preload("../blocky_game/items/light_orb/undervoid_beacon.gd")
		var beacon = Node3D.new()
		beacon.set_script(UndervoidBeacon)
		game.add_child(beacon)
		beacon.global_position = lamp.position + Vector3(0.5, 1.0, 0.5)
		lamp.node = beacon
	
	lamp.active = true


func _deactivate_lamp(key: String):
	"""Remove light for this lamp (too far away)"""
	var lamp = lamps[key]
	if lamp.node and is_instance_valid(lamp.node):
		lamp.node.queue_free()
		lamp.node = null
	lamp.active = false


func _activate_ruin(key: String):
	"""Spawn lights and sphere for this ruin"""
	var ruin = ruins[key]
	if ruin.active:
		return  # Already active
	
	var terrain = get_tree().root.get_node_or_null("Main/Game/VoxelTerrain")
	if not terrain:
		print("⚠️ Could not find VoxelTerrain node")
		return
	
	print("  ✨ Spawning %d lights and sphere for ruin" % ruin.stones.size())
	
	# Spawn teleport stone lights
	for stone in ruin.stones:
		if stone.light_node and is_instance_valid(stone.light_node):
			continue  # Already has light
		
		var light = OmniLight3D.new()
		light.name = "TeleportStoneLight"
		light.position = stone.position + Vector3(0.5, 0.5, 0.5)
		light.light_color = stone.color
		light.light_energy = 2.0
		light.omni_range = 8.0
		light.omni_attenuation = 2.0
		terrain.add_child(light)
		stone.light_node = light
	
	# Spawn ruin sphere
	if not ruin.sphere_node or not is_instance_valid(ruin.sphere_node):
		var sphere_mesh_instance = MeshInstance3D.new()
		sphere_mesh_instance.name = "RuinSphere"
		
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = ruin.sphere.radius
		sphere_mesh.height = ruin.sphere.radius * 2.0
		sphere_mesh.radial_segments = 32
		sphere_mesh.rings = 16
		sphere_mesh_instance.mesh = sphere_mesh
		
		var material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		material.albedo_color = Color(ruin.sphere.color.r, ruin.sphere.color.g, ruin.sphere.color.b, ruin.sphere.opacity)
		
		# Add emission for combat ruins
		if ruin.sphere.has_enemies:
			material.emission_enabled = true
			material.emission = Color(0.5, 0.0, 0.0)
			material.emission_energy_multiplier = 0.3
		
		sphere_mesh_instance.material_override = material
		sphere_mesh_instance.position = ruin.sphere.center
		
		terrain.add_child(sphere_mesh_instance)
		ruin.sphere_node = sphere_mesh_instance
	
	ruin.active = true


func _deactivate_ruin(key: String):
	"""Remove lights and sphere for this ruin (too far away)"""
	var ruin = ruins[key]
	
	# Remove stone lights
	for stone in ruin.stones:
		if stone.light_node and is_instance_valid(stone.light_node):
			stone.light_node.queue_free()
			stone.light_node = null
	
	# Remove sphere
	if ruin.sphere_node and is_instance_valid(ruin.sphere_node):
		ruin.sphere_node.queue_free()
		ruin.sphere_node = null
	
	ruin.active = false


func save_lamps():
	"""Save lamp positions to disk"""
	var data = []
	for key in lamps.keys():
		var lamp = lamps[key]
		data.append({
			"x": lamp.position.x,
			"y": lamp.position.y,
			"z": lamp.position.z,
			"type": lamp.type
		})
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("💾 Saved %d lamp positions" % data.size())
	else:
		push_error("Failed to save lamps to " + SAVE_PATH)


func save_ruins():
	"""Save ruin lights and spheres to disk"""
	var data = []
	for key in ruins.keys():
		var ruin = ruins[key]
		
		var stones_data = []
		for stone in ruin.stones:
			stones_data.append({
				"x": stone.position.x,
				"y": stone.position.y,
				"z": stone.position.z,
				"color_r": stone.color.r,
				"color_g": stone.color.g,
				"color_b": stone.color.b
			})
		
		data.append({
			"ruin_x": ruin.ruin_position.x,
			"ruin_y": ruin.ruin_position.y,
			"ruin_z": ruin.ruin_position.z,
			"stones": stones_data,
			"sphere_center_x": ruin.sphere.center.x,
			"sphere_center_y": ruin.sphere.center.y,
			"sphere_center_z": ruin.sphere.center.z,
			"sphere_radius": ruin.sphere.radius,
			"sphere_color_r": ruin.sphere.color.r,
			"sphere_color_g": ruin.sphere.color.g,
			"sphere_color_b": ruin.sphere.color.b,
			"sphere_opacity": ruin.sphere.opacity,
			"has_enemies": ruin.sphere.has_enemies
		})
	
	var file = FileAccess.open(RUINS_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("💾 Saved %d ruin configurations" % data.size())
	else:
		push_error("Failed to save ruins to " + RUINS_SAVE_PATH)


func load_lamps():
	"""Load lamp positions from disk and scan for existing ruins if needed"""
	if not FileAccess.file_exists(SAVE_PATH):
		print("📂 No saved lamps found")
	else:
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if not file:
			push_error("Failed to load lamps from " + SAVE_PATH)
		else:
			var json_text = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var error = json.parse(json_text)
			if error != OK:
				push_error("Failed to parse lamps JSON: " + json.get_error_message())
			else:
				var data = json.data
				if not data is Array:
					push_error("Lamps data is not an array")
				else:
					lamps.clear()
					for lamp_data in data:
						var pos = Vector3(lamp_data.x, lamp_data.y, lamp_data.z)
						var key = _pos_to_key(pos)
						lamps[key] = {
							"position": pos,
							"type": lamp_data.type,
							"active": false,
							"node": null
						}
					print("📂 Loaded %d lamp positions" % lamps.size())
	
	# Load ruin lights and spheres
	if not FileAccess.file_exists(RUINS_SAVE_PATH):
		print("📂 No saved ruin lights found")
	else:
		var file = FileAccess.open(RUINS_SAVE_PATH, FileAccess.READ)
		if not file:
			push_error("Failed to load ruins from " + RUINS_SAVE_PATH)
		else:
			var json_text = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var error = json.parse(json_text)
			if error != OK:
				push_error("Failed to parse ruins JSON: " + json.get_error_message())
			else:
				var data = json.data
				if not data is Array:
					push_error("Ruins data is not an array")
				else:
					ruins.clear()
					for ruin_data in data:
						var ruin_pos = Vector3(ruin_data.ruin_x, ruin_data.ruin_y, ruin_data.ruin_z)
						var key = _pos_to_key(ruin_pos)
						
						var stones = []
						for stone_data in ruin_data.stones:
							stones.append({
								"position": Vector3(stone_data.x, stone_data.y, stone_data.z),
								"color": Color(stone_data.color_r, stone_data.color_g, stone_data.color_b),
								"light_node": null
							})
						
						ruins[key] = {
							"ruin_position": ruin_pos,
							"stones": stones,
							"sphere": {
								"center": Vector3(ruin_data.sphere_center_x, ruin_data.sphere_center_y, ruin_data.sphere_center_z),
								"radius": ruin_data.sphere_radius,
								"color": Color(ruin_data.sphere_color_r, ruin_data.sphere_color_g, ruin_data.sphere_color_b),
								"opacity": ruin_data.sphere_opacity,
								"has_enemies": ruin_data.has_enemies
							},
							"sphere_node": null,
							"active": false
						}
					print("📂 Loaded %d ruin light configurations" % ruins.size())
	
	# If we have no saved ruins, scan for existing ones (one-time migration)
	if ruins.is_empty():
		print("🔍 No saved ruins found - scanning for existing teleport stones...")
		await get_tree().create_timer(2.0).timeout  # Wait for world to load
		_scan_for_existing_ruins()


func _scan_for_existing_ruins():
	"""One-time scan to find existing teleport stones and register ruins with LampManager"""
	print("🔍 Scanning for existing ruins with teleport stones...")
	
	# Get RuinRegistry which tracks all spawned ruins
	var ruin_registry = get_node_or_null("/root/RuinRegistry")
	if not ruin_registry:
		print("⚠️ RuinRegistry not found - cannot scan for ruins")
		return
	
	# Get all registered ruins
	var all_ruins = []
	if ruin_registry.has_method("get_all_ruins"):
		all_ruins = ruin_registry.get_all_ruins()
		print("📋 RuinRegistry has %d ruins" % all_ruins.size())
	elif ruin_registry.has_method("get_visited_ruins"):
		all_ruins = ruin_registry.get_visited_ruins()
		print("📋 RuinRegistry has %d visited ruins" % all_ruins.size())
	else:
		print("⚠️ RuinRegistry has no get_all_ruins or get_visited_ruins method")
	
	if all_ruins.is_empty():
		print("📍 No ruins found in RuinRegistry - they may not have been spawned yet")
		return
	
	var registered_count = 0
	
	for ruin_data in all_ruins:
		print("  🏛️ Processing ruin at %s with %d stones" % [ruin_data.position, ruin_data.teleport_stones.size()])
		
		# Prepare stone positions and colors
		var stone_positions_and_colors = []
		for stone in ruin_data.teleport_stones:
			var stone_world_pos = ruin_data.position + Vector3(stone.local_pos)
			print("    💎 Stone at %s, color: %s" % [stone_world_pos, stone.glow_color])
			stone_positions_and_colors.append({
				"pos": stone_world_pos,
				"color": stone.glow_color
			})
		
		# Calculate sphere data based on ruin size
		var ruin_size = ruin_data.ruin_size
		var horizontal_size = max(ruin_size.x, ruin_size.z)
		var vertical_size = ruin_size.y
		var radius = sqrt(pow(horizontal_size / 2.0, 2) + pow(horizontal_size / 2.0, 2)) + 5.0
		var vertical_radius = (vertical_size / 2.0) + 5.0
		if vertical_radius > radius:
			radius = vertical_radius
		
		var center_offset = Vector3(ruin_size) / 2.0
		var sphere_center = ruin_data.position + center_offset
		
		# Determine sphere color and opacity
		var sphere_color: Color
		var opacity: float
		if ruin_data.has_enemies:
			sphere_color = Color(0.3, 0.0, 0.0)
			opacity = 0.45
		else:
			if ruin_data.teleport_stones.size() > 0:
				sphere_color = ruin_data.teleport_stones[0].glow_color.darkened(0.6)
				opacity = 0.15
			else:
				sphere_color = Color(0.2, 0.3, 0.5)
				opacity = 0.15
		
		var sphere_data = {
			"center": sphere_center,
			"radius": radius,
			"color": sphere_color,
			"opacity": opacity,
			"has_enemies": ruin_data.has_enemies
		}
		
		# Register this ruin
		register_ruin(ruin_data.position, stone_positions_and_colors, sphere_data)
		registered_count += 1
	
	print("✅ Scanned and registered %d existing ruins" % registered_count)


func _pos_to_key(pos: Vector3) -> String:
	"""Convert position to string key for dictionary"""
	return "%d_%d_%d" % [int(pos.x), int(pos.y), int(pos.z)]
