extends GroundEntity

## Water Elemental - Tier 5 Enemy
## Controls water environment, attempts to drown enemies

@export var chase_distance := 20.0
@export var attack_range := 3.0
@export var attack_cooldown := 2.5

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
const RETARGET_INTERVAL := 2.0


func _ready():
	entity_id = "water_elemental"

	var data = EntityBase.load_entity_data("water_elemental")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Water Elemental"
		team = Team.ENEMY
		max_hp = 65
		attack_damage = 11
		defense = 16
		movement_speed = 6.0
		current_hp = max_hp

	super._ready()

	_sprite = _create_sprite("res://assets/art/entities/water_elemental_ready_pose_enhanced.png", 0.004)
	_create_health_bar()
	set_collision_box(Vector3(1.0, 1.8, 1.0))
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

	if _attack_timer > 0:
		_attack_timer -= delta

	var target_pos = _current_target.global_position
	var distance = target_pos.distance_to(global_position)

	var movement_input = Vector3.ZERO

	if distance > chase_distance:
		pass
	elif distance > attack_range:
		var direction = (target_pos - global_position).normalized()
		direction.y = 0
		movement_input = direction * movement_speed
	else:
		if _attack_timer <= 0:
			_perform_water_attack()
			_attack_timer = attack_cooldown

	apply_ground_movement(delta, movement_input)


func _perform_water_attack():
	"""Water Form: Damages and slows target"""
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	print("💧 %s engulfs %s in water for %d damage!" % [entity_name, target_name, attack_damage])

	if _current_target.has_method("take_damage"):
		_current_target.take_damage(attack_damage, self)

	# TODO: Apply drowning/slow effect

	if _sprite:
		var attack_texture = load("res://assets/art/entities/water_elemental_attack_pose_enhanced.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.5).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/water_elemental_ready_pose_enhanced.png")
				if ready_texture:
					_sprite.texture = ready_texture
