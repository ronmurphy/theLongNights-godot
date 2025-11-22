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


func _ready():
	# Create visual representation - rotating sword sprite
	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Load sword sprite (using sword item sprite)
	var texture_path = "res://blocky_game/items/sword/sword_sprite.png"
	if ResourceLoader.exists(texture_path):
		_sprite.texture = load(texture_path)

	# Make it glow
	_sprite.modulate = Color(1.5, 1.5, 2.0, 1.0)  # Slight blue glow
	_sprite.pixel_size = 0.02

	add_child(_sprite)

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
	# Rotate the sprite for visual effect
	if _sprite:
		_sprite.rotate_y(_rotation_speed * delta)

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

	# Point blade toward target
	look_at(current_target.global_position, Vector3.UP)

	# Check if close enough to hit
	var distance = global_position.distance_to(current_target.global_position)
	if distance < 0.8:
		_hit_enemy(current_target)


func _process_returning(delta: float):
	"""Fly back to player"""
	if not is_instance_valid(owner_entity):
		queue_free()
		return

	# Move toward player
	var target_pos = owner_entity.global_position + Vector3(0, 1, 0)  # Aim for chest height
	var direction = (target_pos - global_position).normalized()
	global_position += direction * speed * delta

	# Check if close enough to player
	var distance = global_position.distance_to(target_pos)
	if distance < 1.0:
		queue_free()  # Blade returns to player


func _find_next_target():
	"""Find the next nearest enemy that hasn't been hit yet"""
	if hit_enemies.size() >= max_chain_count:
		# Hit maximum enemies, return to player
		_return_to_player()
		return

	if not is_instance_valid(owner_entity):
		queue_free()
		return

	# Get all entities in the scene
	var entities = get_tree().get_nodes_in_group("entity")

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

	# Find next target
	_find_next_target()


func _return_to_player():
	"""Switch to returning state"""
	state = State.RETURNING
	current_target = null
	print("⚔️ Blade returning to player (%d enemies hit)" % hit_enemies.size())
