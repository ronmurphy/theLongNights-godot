extends Node3D
class_name PlayerAvatar

## PlayerAvatar - Player's visual billboard representation
## Hidden from local player camera (via layer masking), visible to others
## Matches NPC/companion visual style

var _sprite: Sprite3D = null
var _front_sprite_path: String = ""
var _back_sprite_path: String = ""
var _jumping_sprite_path: String = ""
var _jumping_back_sprite_path: String = ""
var _current_sprite_is_front: bool = true
var _current_sprite_is_jumping: bool = false
var _sprite_height_scale: float = 1.0

const MIN_SPEED_FOR_DIRECTION = 0.5
const CharacterQuiz = preload("res://long_nights/CharacterQuiz.gd")

## Initialize billboard with player's race/gender/color
func initialize(race: String, gender: String, color: Color = Color.WHITE, is_local: bool = true):
	"""Setup billboard with player's race/gender/color"""
	print("PlayerAvatar: Initializing %s %s avatar (local: %s)" % [race, gender, is_local])
	
	# Create sprite
	_create_sprite(race, gender, color)
	
	# Apply race-based height scaling
	_apply_race_height_scaling(race)
	
	# Configure visibility layers (will be implemented in Phase 2)
	if _sprite and is_local:
		# Local player - will be hidden from own camera in Phase 2
		pass
	elif _sprite:
		# Remote player - visible to everyone
		pass


func _create_sprite(race: String, gender: String, color: Color):
	"""Create billboard sprite using player avatar sprites"""
	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y  # Stay upright, don't tilt with camera
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.shaded = true
	_sprite.double_sided = true  # Show sprite on both sides so it's always visible
	_sprite.pixel_size = 0.004  # Same as companion/NPC
	
	# Position at player center (not offset - we'll hide the mesh in first-person)
	_sprite.position = Vector3(0, 1.0, 0)
	
	# Build sprite paths
	_front_sprite_path = "res://assets/art/player_avatars/%s_%s.png" % [race, gender]
	_back_sprite_path = "res://assets/art/player_avatars/%s_%s_back.png" % [race, gender]
	_jumping_sprite_path = "res://assets/art/player_avatars/%s_%s_jumping.png" % [race, gender]
	_jumping_back_sprite_path = "res://assets/art/player_avatars/%s_%s_jumping_back.png" % [race, gender]
	
	# Load front sprite
	var front_texture = null
	if ResourceLoader.exists(_front_sprite_path):
		front_texture = load(_front_sprite_path)
		_sprite.texture = front_texture
	else:
		push_warning("PlayerAvatar: Could not find sprite at %s" % _front_sprite_path)
		return
	
	# Apply color shader if color is not white (for colorized clothing)
	if color != Color.WHITE:
		var shader_material = ShaderMaterial.new()
		shader_material.shader = load("res://blocky_game/shaders/npc_colorize_3d.gdshader")
		shader_material.set_shader_parameter("texture_albedo", front_texture)
		shader_material.set_shader_parameter("target_color", color)
		shader_material.set_shader_parameter("color_tolerance", 0.15)
		
		shader_material.render_priority = 0
		_sprite.material_override = shader_material
		
		_sprite.no_depth_test = false
		_sprite.fixed_size = false
		_sprite.double_sided = false
	
	# Enable shadow casting
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	
	add_child(_sprite)
	print("  PlayerAvatar: Sprite created at %s" % _sprite.position)


func _apply_race_height_scaling(race: String):
	"""Apply height scaling based on race (same as NPCs)"""
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
		
		# Adjust sprite vertical position based on height
		_sprite.position.y = 1.0 * height_scale
	
	print("  PlayerAvatar: Applied height scale %.2fx for %s" % [height_scale, race])


func update_sprite_direction(velocity: Vector3, camera_forward: Vector3):
	"""Update sprite based on movement direction relative to camera"""
	if not _sprite:
		return
	
	# Get horizontal velocity
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	var speed = horizontal_velocity.length()
	
	# If moving too slow, keep current direction
	if speed < MIN_SPEED_FOR_DIRECTION:
		return
	
	# Calculate dot product (positive = moving toward camera, negative = away)
	var dot_product = horizontal_velocity.normalized().dot(camera_forward)
	
	# Decide if we should show back or front
	# Moving away from camera direction = show back
	var should_show_back = dot_product > 0  # Moving in same direction as camera
	
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
				
				# Update shader texture if using shader
				if _sprite.material_override:
					_sprite.material_override.set_shader_parameter("texture_albedo", back_texture)
				
				# Preserve scale when swapping
				_sprite.scale = Vector3(_sprite_height_scale, _sprite_height_scale, _sprite_height_scale)
		elif should_show_front and _front_sprite_path != "":
			# Switch to front sprite
			var front_texture = load(_front_sprite_path)
			if front_texture:
				_sprite.texture = front_texture
				_current_sprite_is_front = true
				
				# Update shader texture if using shader
				if _sprite.material_override:
					_sprite.material_override.set_shader_parameter("texture_albedo", front_texture)
				
				# Preserve scale when swapping
				_sprite.scale = Vector3(_sprite_height_scale, _sprite_height_scale, _sprite_height_scale)


func update_jumping_state(is_jumping: bool, is_facing_back: bool):
	"""Update sprite based on jumping state and facing direction"""
	if not _sprite:
		return

	# If jumping state changed, update sprite
	if is_jumping != _current_sprite_is_jumping:
		_current_sprite_is_jumping = is_jumping

		if is_jumping:
			# Switch to jumping sprite
			var jumping_path = _jumping_back_sprite_path if is_facing_back else _jumping_sprite_path

			if ResourceLoader.exists(jumping_path):
				var jumping_texture = load(jumping_path)
				if jumping_texture:
					_sprite.texture = jumping_texture

					# Update shader texture if using shader
					if _sprite.material_override:
						_sprite.material_override.set_shader_parameter("texture_albedo", jumping_texture)

					# Preserve scale
					_sprite.scale = Vector3(_sprite_height_scale, _sprite_height_scale, _sprite_height_scale)
		else:
			# Switch back to normal sprite
			var normal_path = _back_sprite_path if is_facing_back else _front_sprite_path

			if ResourceLoader.exists(normal_path):
				var normal_texture = load(normal_path)
				if normal_texture:
					_sprite.texture = normal_texture

					# Update shader texture if using shader
					if _sprite.material_override:
						_sprite.material_override.set_shader_parameter("texture_albedo", normal_texture)

					# Preserve scale
					_sprite.scale = Vector3(_sprite_height_scale, _sprite_height_scale, _sprite_height_scale)


func set_shadow_only_mode(shadow_only: bool):
	"""Enable shadow-only mode (invisible sprite but casts shadow)"""
	if not _sprite:
		return
	
	if shadow_only:
		# Make sprite invisible but keep shadow
		_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	else:
		# Normal mode - visible sprite with shadow
		_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func force_sprite_direction(show_back: bool):
	"""Force show front or back sprite (for camera orbit)"""
	if not _sprite:
		return
	
	if show_back and _back_sprite_path != "" and _current_sprite_is_front:
		# Switch to back sprite
		var back_texture = load(_back_sprite_path)
		if back_texture:
			_sprite.texture = back_texture
			_current_sprite_is_front = false
			
			if _sprite.material_override:
				_sprite.material_override.set_shader_parameter("texture_albedo", back_texture)
			
			_sprite.scale = Vector3(_sprite_height_scale, _sprite_height_scale, _sprite_height_scale)
	elif not show_back and _front_sprite_path != "" and not _current_sprite_is_front:
		# Switch to front sprite
		var front_texture = load(_front_sprite_path)
		if front_texture:
			_sprite.texture = front_texture
			_current_sprite_is_front = true
			
			if _sprite.material_override:
				_sprite.material_override.set_shader_parameter("texture_albedo", front_texture)
			
			_sprite.scale = Vector3(_sprite_height_scale, _sprite_height_scale, _sprite_height_scale)


func apply_quality_settings(quality: String):
	"""Apply graphics quality settings to avatar"""
	if not _sprite:
		return
	
	match quality:
		"low":
			_sprite.pixel_size = 0.006
			# On low settings, disable shadows completely
			_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"medium":
			_sprite.pixel_size = 0.004
			# Medium/high keep shadow-only mode (will be managed by controller)
		"high":
			_sprite.pixel_size = 0.003
			# High quality - best detail
