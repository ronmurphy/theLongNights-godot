extends FlyingEntity

## Nightmare Golden - Tier 5 Boss
## FLYING nightmare wreathed in golden flames
## Launches devastating fireball volleys

@export var chase_distance := 35.0
@export var attack_range := 15.0  # Ranged attacker
@export var attack_cooldown := 3.0
@export var chase_speed := 7.0
@export var fireball_count := 3  # Fires 3 fireballs in volley

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
const RETARGET_INTERVAL := 2.0


func _ready():
	entity_id = "nightmare_golden"

	var data = EntityBase.load_entity_data("nightmare_golden")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Nightmare Golden"
		team = Team.ENEMY
		max_hp = 850
		attack_damage = 23
		defense = 33
		movement_speed = 7.0
		current_hp = max_hp

	super._ready()

	# Larger sprite for nightmare (1024x1024)
	_sprite = _create_sprite("res://assets/art/entities/nightmare_golden_ready.png", 0.008)
	_find_best_target()


func _find_best_target():
	var possible_targets = []

	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("is_alive") == true:
		possible_targets.append(player)

	var companions = get_tree().get_nodes_in_group("friendly_entities")
	for companion in companions:
		if companion.get("is_alive") == true:
			possible_targets.append(companion)

	var closest = null
	var closest_dist = INF
	for target in possible_targets:
		var dist = global_position.distance_to(target.global_position)
		if dist < closest_dist:
			closest = target
			closest_dist = dist

	_current_target = closest


func _process(delta: float):
	if not is_alive:
		return

	_retarget_timer -= delta
	if _retarget_timer <= 0:
		_find_best_target()
		_retarget_timer = RETARGET_INTERVAL

	if _current_target == null or not is_instance_valid(_current_target) or _current_target.get("is_alive") != true:
		_find_best_target()
		if _current_target == null:
			return

	# Apply bob movement for flying entity
	apply_bob_movement(delta)

	if _attack_timer > 0:
		_attack_timer -= delta

	var target_pos = _current_target.global_position
	var distance = global_position.distance_to(target_pos)

	if distance > chase_distance:
		pass
	elif distance > attack_range:
		# Chase through air - no collision for flying entity
		move_toward_target(delta, target_pos, chase_speed, false)
	else:
		# Stay at range and attack
		if _attack_timer <= 0:
			_perform_fireball_volley()
			_attack_timer = attack_cooldown


func _perform_fireball_volley():
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"

	print("🔥 %s launches FIREBALL VOLLEY at %s!" % [entity_name, target_name])

	# Fire multiple fireballs in quick succession
	for i in range(fireball_count):
		_fire_single_fireball()
		await get_tree().create_timer(0.2).timeout

	# Animate
	if _sprite:
		var attack_texture = load("res://assets/art/entities/nightmare_golden_attack.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.5).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/nightmare_golden_ready.png")
				if ready_texture:
					_sprite.texture = ready_texture


func _fire_single_fireball():
	if _current_target == null or not is_instance_valid(_current_target):
		return

	# Create fireball projectile
	var Fireball = preload("res://blocky_game/projectiles/fireball.gd")
	var fireball = Node3D.new()
	fireball.set_script(Fireball)

	# Position at nightmare's location
	fireball.global_position = global_position

	# Set projectile properties
	fireball.damage = int(attack_damage / 2)  # Each fireball does half damage
	fireball.speed = 15.0
	fireball.max_distance = 50.0
	fireball.owner_entity = self

	# Aim at target with slight spread
	var direction = ((_current_target.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))) - global_position).normalized()
	fireball.direction = direction

	# Add to scene
	get_tree().root.add_child(fireball)

	print("  🔥 Fireball launched!")
