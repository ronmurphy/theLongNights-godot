extends Node3D

## Flying Blade - Chain-attacking sword projectile
## Flies from enemy to enemy, dealing damage to each

const EntityBase = preload("../entities/entity_base.gd")

enum State {
	SEEKING,     # Flying toward an enemy
	RETURNING    # Flying back to player
}

var state: State = State.SEEKING
var speed := 25.0
var damage := 15
var owner_entity = null  # Player who launched the blade
var max_chain_count := 5  # Maximum enemies to hit
var search_range := 20.0  # Range to search for enemies
var hit_enemies: Array = []  # Track which enemies we've already hit

# Current target
var current_target = null
var return_position := Vector3.ZERO

# Visual
var _sprite: Sprite3D = null
var _rotation_speed := 15.0  # Radians per second
var _trail_points: Array[Vector3] = []
var _trail_max_length := 15
var _trail_sprites: Array[Sprite3D] = []


func _ready():
	# Create visual representation - rotating sword sprite
	_sprite = Sprite3D.new()

	# IMPORTANT: Disable billboard completely - use integer 0 to ensure it's disabled
	_sprite.billboard = 0  # SpriteBase3D.BILLBOARD_DISABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Load sword sprite (using sword item sprite)
	var texture_path = "res://blocky_game/items/sword/sword_sprite.png"
	if ResourceLoader.exists(texture_path):
		_sprite.texture = load(texture_path)

	# Make it glow and increase size for visibility
	_sprite.modulate = Color(1.5, 1.5, 2.0, 1.0)  # Slight blue glow
	_sprite.pixel_size = 0.05  # Increased from 0.02 for better visibility

	# Orient sprite: Since the blade sprite points up-right in the texture,
	# we need to rotate it to point forward and tilt back 30 degrees
	# Sprite starts pointing up, so rotate to make it point forward
	_sprite.rotation_degrees = Vector3(-60, 0, 0)  # Tilt back 60 degrees (90 - 30 = point forward at 30 degree angle)

	add_child(_sprite)

	# Debug: Verify billboard is actually disabled
	print("⚔️ Blade sprite billboard mode: ", _sprite.billboard)

	# Add point light for glow effect
	var light = OmniLight3D.new()
	light.light_color = Color(0.6, 0.6, 1.0)  # Blue-white
	light.light_energy = 1.0
	light.omni_range = 3.0
	add_child(light)


func initialize(start_pos: Vector3, player: Node3D):
	"""Initialize the blade with starting position and player reference"""
	global_position = start_pos
	owner_entity = player
	return_position = start_pos

	# Find first target
	_find_next_target()


func _process(delta: float):
	# Rotate the sprite around its local Z axis (roll) for spinning effect
	if _sprite:
		_sprite.rotate_object_local(Vector3(0, 0, 1), _rotation_speed * delta)

	# Update trail
	_update_trail()

	match state:
		State.SEEKING:
			_process_seeking(delta)
		State.RETURNING:
			_process_returning(delta)


func _process_seeking(delta: float):
	"""Fly toward current target enemy"""
	if not is_instance_valid(current_target):
		# Target lost, find another or return
		_find_next_target()
		return

	# Move toward target
	var direction = (current_target.global_position - global_position).normalized()
	global_position += direction * speed * delta

	# Point blade toward target (this orients the Node3D, sprite follows due to being a child)
	# Use look_at to point the -Z axis toward the target
	var target_position = current_target.global_position
	look_at(target_position, Vector3.UP)

	# Check if close enough to hit
	var distance = global_position.distance_to(current_target.global_position)
	if distance < 0.8:
		_hit_enemy(current_target)


func _process_returning(delta: float):
	"""Fly back to player"""
	if not is_instance_valid(owner_entity):
		_cleanup_and_free()
		return

	# Move toward player
	var target_pos = owner_entity.global_position + Vector3(0, 1, 0)  # Aim for chest height
	var direction = (target_pos - global_position).normalized()
	global_position += direction * speed * delta

	# Point blade toward player while returning
	look_at(target_pos, Vector3.UP)

	# Check if close enough to player
	var distance = global_position.distance_to(target_pos)
	if distance < 1.0:
		_cleanup_and_free()  # Blade returns to player


func _find_next_target():
	"""Find the next nearest enemy that hasn't been hit yet"""
	if hit_enemies.size() >= max_chain_count:
		# Hit maximum enemies, return to player
		_return_to_player()
		return

	if not is_instance_valid(owner_entity):
		_cleanup_and_free()
		return

	# Get all entities in the scene
	var entities = get_tree().get_nodes_in_group("entities")

	var nearest_enemy = null
	var nearest_distance = search_range

	for entity in entities:
		if not is_instance_valid(entity):
			continue

		# Skip if not an enemy
		if "team" not in entity or entity.team != 2:  # 2 = ENEMY
			continue

		# Skip if already hit
		if hit_enemies.has(entity):
			continue

		var distance = global_position.distance_to(entity.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = entity

	if nearest_enemy:
		current_target = nearest_enemy
		print("⚔️ Blade targeting: %s (%d/%d)" % [nearest_enemy.entity_name if "entity_name" in nearest_enemy else "enemy", hit_enemies.size() + 1, max_chain_count])
	else:
		# No more enemies in range, return to player
		_return_to_player()


func _hit_enemy(enemy: Node3D):
	"""Deal damage to enemy and find next target"""
	if not is_instance_valid(enemy):
		_find_next_target()
		return

	# Mark as hit
	hit_enemies.append(enemy)

	# Deal damage
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage, owner_entity)
		print("⚔️ Blade hit %s for %d damage!" % [enemy.entity_name if "entity_name" in enemy else "enemy", damage])

	# Spawn slash effect at impact
	var direction = (enemy.global_position - global_position).normalized()
	SlashEffectSpawner.spawn_slash(
		get_node("/root/Main/Game"),
		enemy.global_position,
		direction,
		Color(0.7, 0.9, 1.2, 1.0),  # Bright blue slash for magical blade
		0.25,  # Duration
		9.0,   # Intensity (very bright)
		6.0,   # Speed (fast animation)
		2.0,   # Scale
		"res://assets/art/textures/slash_01.png"
	)

	# Find next target
	_find_next_target()


func _return_to_player():
	"""Switch to returning state"""
	state = State.RETURNING
	current_target = null
	print("⚔️ Blade returning to player (%d enemies hit)" % hit_enemies.size())


func _update_trail():
	"""Create a glowing trail effect behind the blade"""
	# Add current position to trail
	_trail_points.push_front(global_position)

	# Limit trail length
	if _trail_points.size() > _trail_max_length:
		_trail_points.pop_back()
		# Remove old sprite if it exists
		if _trail_sprites.size() > _trail_max_length:
			var old_sprite = _trail_sprites.pop_back()
			if is_instance_valid(old_sprite):
				old_sprite.queue_free()

	# Update trail sprites
	for i in range(_trail_points.size()):
		# Create new sprite if needed
		if i >= _trail_sprites.size():
			var trail_sprite = Sprite3D.new()
			trail_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # Trail uses billboard for simplicity
			trail_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			trail_sprite.texture = _sprite.texture
			trail_sprite.pixel_size = 0.04
			get_parent().add_child(trail_sprite)
			_trail_sprites.push_back(trail_sprite)

		# Update sprite position and fade
		var trail_sprite = _trail_sprites[i]
		if is_instance_valid(trail_sprite):
			trail_sprite.global_position = _trail_points[i]
			# Copy rotation from main blade for first few trail sprites
			if i < 3:
				trail_sprite.global_transform = global_transform
				trail_sprite.global_position = _trail_points[i]  # Restore position after copying transform
			# Fade based on distance from blade (older = more transparent)
			var alpha = 1.0 - (float(i) / float(_trail_max_length))
			trail_sprite.modulate = Color(0.7, 0.9, 1.2, alpha * 0.6)
			trail_sprite.scale = Vector3.ONE * (1.0 - float(i) / float(_trail_max_length) * 0.5)


func _cleanup_and_free():
	"""Clean up trail sprites before freeing the blade"""
	for trail_sprite in _trail_sprites:
		if is_instance_valid(trail_sprite):
			trail_sprite.queue_free()
	_trail_sprites.clear()
	queue_free()
