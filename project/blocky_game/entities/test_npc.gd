extends GroundEntity

const CharacterQuiz = preload("res://long_nights/CharacterQuiz.gd")

## TestNPC - Simple wandering NPC for testing
## Can be spawned with console: npc <race> <gender> <color> <name>
## Uses player avatar sprites with color tinting

var npc_race: String = "human"
var npc_gender: String = "female"
var npc_color: Color = Color.WHITE
var npc_display_name: String = "NPC"

# Sprite direction tracking (like companion)
var _front_sprite_path: String = ""
var _back_sprite_path: String = ""
var _current_sprite_is_front: bool = true
var _sprite_height_scale: float = 1.0  # Store scale to preserve when swapping
const MIN_SPEED_FOR_DIRECTION = 0.5  # Minimum speed to consider direction

# Wander AI
var _wander_timer: float = 0.0
var _wander_duration: float = 3.0  # Change direction every 3 seconds
var _wander_direction: Vector3 = Vector3.ZERO
var _idle_time: float = 0.0
var _is_idle: bool = false


func _ready():
	super._ready()
	
	# Set team to neutral
	team = Team.NEUTRAL
	
	# Randomize first wander direction
	_pick_new_wander_direction()
	
	# Note: Sprite and health bar are created in initialize() after race/gender are set


func initialize(race: String, gender: String, color: Color, display_name: String):
	"""Initialize NPC with race, gender, color, and name"""
	npc_race = race
	npc_gender = gender
	npc_color = color
	npc_display_name = display_name
	entity_name = display_name
	
	# Load stats from entities.json data
	_load_stats_from_race(race)
	
	# Apply race-based speed multiplier
	var speed_multiplier = CharacterQuiz.get_race_speed_multiplier(race)
	movement_speed *= speed_multiplier
	
	# Create sprite AFTER race/gender are set
	_create_sprite()
	
	# Create health bar
	_create_health_bar()
	
	# Apply race-based height scaling
	_apply_race_height_scaling(race)
	
	print("TestNPC: Initialized %s (%s %s) with color %s, speed %.2fx" % [display_name, race, gender, color, speed_multiplier])


func _load_stats_from_race(race: String):
	"""Load stats from entities.json companion data"""
	# Base stats by race (from entities.json)
	match race:
		"human":
			max_hp = 12
			attack_damage = 4
			defense = 13
		"elf":
			max_hp = 10
			attack_damage = 5
			defense = 12
		"dwarf":
			max_hp = 16
			attack_damage = 3
			defense = 15
		"goblin":
			max_hp = 8
			attack_damage = 6
			defense = 11
		_:
			# Default to human stats
			max_hp = 12
			attack_damage = 4
			defense = 13
	
	# Use unified base movement speed (will be modified by race multiplier)
	movement_speed = 4.0
	current_hp = max_hp


func _apply_race_height_scaling(race: String):
	"""Apply height scaling based on race"""
	var height_scale = 1.0
	
	match race:
		"elf":
			height_scale = 1.15  # Taller
		"human":
			height_scale = 1.0  # Normal
		"dwarf":
			height_scale = 0.8  # Shorter
		"goblin":
			height_scale = 0.75  # Shortest
	
	# Store scale for later use when swapping sprites
	_sprite_height_scale = height_scale
	
	# Apply scaling to sprite if it exists
	if _sprite:
		_sprite.scale = Vector3(height_scale, height_scale, height_scale)
	
	# Adjust health bar position based on height
	if _health_bar:
		_health_bar.position.y = 1.2 * height_scale


func _create_sprite(_texture_path: String = "", pixel_size: float = 0.004) -> Sprite3D:
	"""Create billboard sprite using NPC avatar sprites"""
	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.shaded = true
	_sprite.pixel_size = pixel_size  # 0.004 matches companion size
	
	# Build sprite paths - try npc_sprites folder first, fallback to player_avatars
	var npc_front = "res://assets/art/npc_sprites/%s_%s.png" % [npc_race, npc_gender]
	var npc_back = "res://assets/art/npc_sprites/%s_%s_back.png" % [npc_race, npc_gender]
	var fallback_front = "res://assets/art/player_avatars/%s_%s.png" % [npc_race, npc_gender]
	var fallback_back = "res://assets/art/player_avatars/%s_%s_back.png" % [npc_race, npc_gender]
	
	# Choose sprite paths (prefer npc_sprites)
	if ResourceLoader.exists(npc_front):
		_front_sprite_path = npc_front
		_back_sprite_path = npc_back
	else:
		_front_sprite_path = fallback_front
		_back_sprite_path = fallback_back
	
	# Load front sprite
	if ResourceLoader.exists(_front_sprite_path):
		_sprite.texture = load(_front_sprite_path)
	else:
		push_warning("TestNPC: Could not find sprite at %s" % _front_sprite_path)
	
	# Apply color tint
	_sprite.modulate = npc_color
	
	add_child(_sprite)
	return _sprite


func _create_health_bar():
	"""Create simple health bar above NPC"""
	_health_bar = Node3D.new()
	_health_bar.position = Vector3(0, 1.2, 0)  # Above head
	add_child(_health_bar)
	
	# Background bar (red)
	var bg_bar = MeshInstance3D.new()
	var bg_mesh = BoxMesh.new()
	bg_mesh.size = Vector3(0.5, 0.05, 0.01)
	bg_bar.mesh = bg_mesh
	var bg_material = StandardMaterial3D.new()
	bg_material.albedo_color = Color(0.3, 0.0, 0.0)
	bg_bar.material_override = bg_material
	_health_bar.add_child(bg_bar)
	
	# Foreground bar (green)
	var fg_bar = MeshInstance3D.new()
	fg_bar.name = "ForegroundBar"
	var fg_mesh = BoxMesh.new()
	fg_mesh.size = Vector3(0.5, 0.05, 0.02)
	fg_bar.mesh = fg_mesh
	var fg_material = StandardMaterial3D.new()
	fg_material.albedo_color = Color(0.0, 0.8, 0.0)
	fg_bar.material_override = fg_material
	_health_bar.add_child(fg_bar)
	
	# Name label
	var name_label = Label3D.new()
	name_label.text = npc_display_name
	name_label.font_size = 24
	name_label.outline_size = 4
	name_label.position = Vector3(0, 0.15, 0)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_bar.add_child(name_label)


func _update_health_bar():
	"""Update health bar fill amount"""
	if not _health_bar:
		return
	
	var fg_bar = _health_bar.get_node_or_null("ForegroundBar")
	if fg_bar:
		var hp_percent = float(current_hp) / float(max_hp)
		# Scale the foreground bar horizontally
		fg_bar.scale.x = hp_percent


func _process(delta):
	if not is_alive:
		return
	
	# Simple wander AI
	_wander_timer += delta
	
	if _is_idle:
		_idle_time += delta
		if _idle_time >= 2.0:  # Idle for 2 seconds
			_is_idle = false
			_idle_time = 0.0
			_pick_new_wander_direction()
	elif _wander_timer >= _wander_duration:
		_wander_timer = 0.0
		
		# 30% chance to stop and idle
		if randf() < 0.3:
			_is_idle = true
			_wander_direction = Vector3.ZERO
		else:
			_pick_new_wander_direction()
	
	# Apply movement
	var velocity = _wander_direction * movement_speed
	apply_ground_movement(delta, velocity)
	
	# Update sprite direction based on movement relative to player
	_update_sprite_direction()
	
	# Face movement direction
	if _wander_direction.length() > 0.1:
		var look_direction = _wander_direction.normalized()
		look_at(global_position + look_direction, Vector3.UP)


func _pick_new_wander_direction():
	"""Pick a random direction to wander"""
	var angle = randf() * TAU
	_wander_direction = Vector3(cos(angle), 0, sin(angle)).normalized()
	_wander_duration = randf_range(2.0, 5.0)


func _update_sprite_direction() -> void:
	"""Update sprite based on movement direction (like companion)"""
	if not _sprite:
		return
	
	# Get player reference
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Get current velocity (horizontal only)
	var velocity = get_velocity()
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	var speed = horizontal_velocity.length()
	
	# If moving too slow, keep current direction
	if speed < MIN_SPEED_FOR_DIRECTION:
		return
	
	# Get direction from NPC to player
	var to_player = (player.global_position - global_position).normalized()
	to_player.y = 0  # Only consider horizontal direction
	
	# Calculate dot product (positive = moving toward, negative = moving away)
	var dot_product = horizontal_velocity.normalized().dot(to_player)
	
	# Decide if we should show back or front
	var should_show_back = dot_product < 0  # Moving away from player
	
	# Only update if sprite direction changed
	var is_showing_front = _current_sprite_is_front
	var should_show_front = not should_show_back
	
	if is_showing_front != should_show_front:
		if should_show_back and _back_sprite_path != "":
			# Switch to back sprite
			var back_texture = load(_back_sprite_path)
			if back_texture:
				_sprite.texture = back_texture
				_current_sprite_is_front = false
				# Preserve scale and color when swapping
				_sprite.scale = Vector3(_sprite_height_scale, _sprite_height_scale, _sprite_height_scale)
				_sprite.modulate = npc_color
		elif should_show_front and _front_sprite_path != "":
			# Switch to front sprite
			var front_texture = load(_front_sprite_path)
			if front_texture:
				_sprite.texture = front_texture
				_current_sprite_is_front = true
				# Preserve scale and color when swapping
				_sprite.scale = Vector3(_sprite_height_scale, _sprite_height_scale, _sprite_height_scale)
				_sprite.modulate = npc_color
