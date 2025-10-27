extends GroundEntity

## Troglodyte - Tier 1 enemy
## Cave dweller, slow but tough

@export var chase_distance := 12.0  # Shorter range
@export var attack_range := 1.5
@export var attack_cooldown := 1.5  # Slower attacks

var _target_player: Node3D = null
var _attack_timer := 0.0


func _ready():
	entity_id = "troglodyte"

	# Load from JSON
	var data = EntityBase.load_entity_data("troglodyte")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		# Fallback
		entity_name = "Troglodyte"
		team = Team.ENEMY
		max_hp = 15
		attack_damage = 4
		defense = 13
		movement_speed = 2.0  # Slower
		current_hp = max_hp

	super._ready()

	_sprite = _create_sprite("res://assets/art/entities/troglodyte_ready_pose_enhanced.png", 0.0025)
	_create_health_bar()
	set_collision_box(Vector3(0.6, 0.9, 0.6))  # Bigger
	_find_player()


func _find_player():
	_target_player = get_tree().get_first_node_in_group("player")


func _process(delta: float):
	if not is_alive:
		return

	if _target_player == null:
		_find_player()
		return

	if _attack_timer > 0:
		_attack_timer -= delta

	var player_pos = _target_player.global_position
	var distance = player_pos.distance_to(global_position)

	var movement_input = Vector3.ZERO

	if distance > chase_distance:
		pass  # Too far
	elif distance > attack_range:
		# Chase (slowly)
		var direction = (player_pos - global_position).normalized()
		direction.y = 0
		movement_input = direction * movement_speed
	else:
		# Attack
		if _attack_timer <= 0:
			_perform_attack()
			_attack_timer = attack_cooldown

	apply_ground_movement(delta, movement_input)


func _perform_attack():
	if _target_player == null:
		return

	print("%s attacks for %d damage!" % [entity_name, attack_damage])

	# Actually damage the player
	if _target_player.has_method("take_damage"):
		_target_player.take_damage(attack_damage, self)

	# Swap to attack sprite
	if _sprite:
		var attack_texture = load("res://assets/art/entities/troglodyte_attack_pose_enhanced.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.3).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/troglodyte_ready_pose_enhanced.png")
				if ready_texture:
					_sprite.texture = ready_texture
