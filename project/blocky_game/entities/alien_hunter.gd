extends GroundEntity

## Alien Hunter - Tier 5 RANGED Enemy
## Sophisticated alien predators hunting for sport, advanced technology

@export var chase_distance := 30.0
@export var preferred_distance := 16.0
@export var min_distance := 8.0
@export var attack_range := 25.0
@export var attack_cooldown := 2.5

const PlasmaShot = preload("res://blocky_game/projectiles/plasma_shot.gd")

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
var _stealth_active := false
var _stealth_cooldown := 0.0
const RETARGET_INTERVAL := 1.5
const STEALTH_COOLDOWN := 15.0
const STEALTH_DURATION := 5.0


func _ready():
	entity_id = "alien_hunter"

	var data = EntityBase.load_entity_data("alien_hunter")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Alien Hunter"
		team = Team.ENEMY
		max_hp = 85
		attack_damage = 13
		defense = 18
		movement_speed = 8.0
		current_hp = max_hp

	super._ready()

	_sprite = _create_sprite("res://assets/art/entities/alien_hunter_ready_pose_enhanced.png", 0.004)
	_create_health_bar()
	set_collision_box(Vector3(0.7, 1.5, 0.7))
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

	_stealth_cooldown -= delta

	# Activate stealth when needed
	if not _stealth_active and _stealth_cooldown <= 0 and current_hp < max_hp * 0.5:
		_activate_stealth()

	if _current_target == null or not is_instance_valid(_current_target) or _current_target.get("is_alive") != true:
		_find_best_target()
		if _current_target == null:
			return

	if _attack_timer > 0:
		_attack_timer -= delta

	var target_pos = _current_target.global_position
	var distance = target_pos.distance_to(global_position)

	var movement_input = Vector3.ZERO

	if distance > chase_distance:
		pass
	elif distance < min_distance:
		var direction = (global_position - target_pos).normalized()
		direction.y = 0
		movement_input = direction * movement_speed * 0.7
	elif distance > preferred_distance:
		var direction = (target_pos - global_position).normalized()
		direction.y = 0
		movement_input = direction * movement_speed * 0.5
	else:
		if _attack_timer <= 0:
			_perform_plasma_shot()
			_attack_timer = attack_cooldown

	apply_ground_movement(delta, movement_input)


func _activate_stealth():
	"""Stealth Cloak: Become harder to hit"""
	print("👽 %s activates stealth cloak!" % entity_name)
	_stealth_active = true
	_stealth_cooldown = STEALTH_COOLDOWN

	# Reduce opacity
	if _sprite:
		_sprite.modulate = Color(1, 1, 1, 0.3)

	# Deactivate after duration
	await get_tree().create_timer(STEALTH_DURATION).timeout
	_stealth_active = false
	if _sprite:
		_sprite.modulate = Color(1, 1, 1, 1.0)


func _perform_plasma_shot():
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	print("⚡ %s fires plasma shot at %s!" % [entity_name, target_name])

	var shot = Node3D.new()
	shot.set_script(PlasmaShot)

	var game = get_node_or_null("/root/Main/Game")
	if game:
		game.add_child(shot)

		var shoot_pos = global_position + Vector3(0, 1.2, 0)

		var target_velocity = Vector3.ZERO
		if _current_target.has_method("get_velocity"):
			target_velocity = _current_target.get_velocity()

		var time_to_impact = global_position.distance_to(_current_target.global_position) / 30.0
		var predicted_pos = _current_target.global_position + target_velocity * time_to_impact
		var target_shoot_pos = predicted_pos + Vector3(0, 0.8, 0)

		shot.initialize(shoot_pos, target_shoot_pos, self)

	if _sprite:
		var attack_texture = load("res://assets/art/entities/alien_hunter_attack_pose_enhanced.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.4).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/alien_hunter_ready_pose_enhanced.png")
				if ready_texture:
					_sprite.texture = ready_texture
