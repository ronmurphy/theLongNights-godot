extends GroundEntity

## Rat - Tier 1 enemy
## Simple ground-based enemy that chases and attacks the player

@export var chase_distance := 15.0
@export var attack_range := 1.5
@export var attack_cooldown := 1.0

var _target_player: Node3D = null
var _attack_timer := 0.0


func _ready():
	# Set entity properties
	entity_id = "rat"

	# Load entity data from JSON
	var data = EntityBase.load_entity_data("rat")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		# Fallback defaults
		entity_name = "Rat"
		team = Team.ENEMY
		max_hp = 8
		attack_damage = 3
		defense = 13
		movement_speed = 5.0
		current_hp = max_hp

	# Call parent ready
	super._ready()

	# Create sprite
	_sprite = _create_sprite("res://assets/art/entities/rat_ready_pose_enhanced.png", 0.0025)

	# Create health bar
	_create_health_bar()

	# Set collision box size for rat (smaller than default)
	set_collision_box(Vector3(0.4, 0.4, 0.4))

	# Find player
	_find_player()


func _find_player():
	_target_player = get_tree().get_first_node_in_group("player")


func _process(delta: float):
	if not is_alive:
		return

	if _target_player == null:
		_find_player()
		return

	# Update attack cooldown
	if _attack_timer > 0:
		_attack_timer -= delta

	var player_pos = _target_player.global_position
	var to_player = player_pos - global_position
	var distance = to_player.length()

	# Determine movement
	var movement_input = Vector3.ZERO

	if distance > chase_distance:
		# Too far, idle (no movement)
		pass

	elif distance > attack_range:
		# Chase player
		var direction = to_player.normalized()
		direction.y = 0  # Only horizontal movement
		movement_input = direction * movement_speed

	else:
		# In attack range, stop and attack
		if _attack_timer <= 0:
			_perform_attack()
			_attack_timer = attack_cooldown

	# Apply ground movement (gravity, collision, etc.) - handled by GroundEntity
	apply_ground_movement(delta, movement_input)


func _perform_attack():
	if _target_player == null:
		return

	print("%s attacks for %d damage!" % [entity_name, attack_damage])

	# Actually damage the player
	if _target_player.has_method("take_damage"):
		_target_player.take_damage(attack_damage, self)

	# Play attack animation (swap sprite)
	if _sprite:
		var attack_texture = load("res://assets/art/entities/rat_attack_pose_enhanced.png")
		if attack_texture:
			_sprite.texture = attack_texture

			# Switch back to ready pose after 0.3 seconds
			await get_tree().create_timer(0.3).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/rat_ready_pose_enhanced.png")
				if ready_texture:
					_sprite.texture = ready_texture


func _on_death() -> void:
	# Play death effect
	super._on_death()

	# TODO: Drop loot/items
