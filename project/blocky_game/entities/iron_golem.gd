extends GroundEntity

## Iron Golem - Tier 5 Tank Enemy
## Massive iron construct guarding key areas, extreme HP and defense

@export var chase_distance := 20.0
@export var attack_range := 3.0
@export var attack_cooldown := 3.0  # Slow but devastating

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
const RETARGET_INTERVAL := 3.0


func _ready():
	entity_id = "iron_golem"

	var data = EntityBase.load_entity_data("iron_golem")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Iron Golem"
		team = Team.ENEMY
		max_hp = 80
		attack_damage = 12
		defense = 20
		movement_speed = 2.0
		current_hp = max_hp

	super._ready()

	_sprite = _create_sprite("res://assets/art/entities/iron_golem_ready_pose_enhanced.png", 0.005)  # Very large sprite
	set_collision_box(Vector3(1.5, 2.5, 1.5))  # Massive construct
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
			_perform_slam_attack()
			_attack_timer = attack_cooldown

	apply_ground_movement(delta, movement_input)


func _perform_slam_attack():
	"""Heavy Slam: Damages target and nearby enemies"""
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	print("🤖 %s SLAMS the ground for %d damage!" % [entity_name, attack_damage])

	# GOLEM SMASH - Break 2 blocks at once!
	break_blocks_to_target(_current_target, 4.0)  # Longer range, breaks more blocks

	# Damage primary target
	if _current_target.has_method("take_damage"):
		_current_target.take_damage(attack_damage, self)

	# Area damage (3 block radius)
	var entities = get_tree().get_nodes_in_group("entities")
	for entity in entities:
		if not is_instance_valid(entity) or not entity.is_alive:
			continue
		if entity.team == Team.ENEMY:
			continue

		var distance = global_position.distance_to(entity.global_position)
		if distance < 3.0 and entity != _current_target:
			if entity.has_method("take_damage"):
				entity.take_damage(int(attack_damage * 0.5), self)  # 50% splash damage
				print("  💥 Splash damage to %s!" % entity.get("entity_name"))

	if _sprite:
		var attack_texture = load("res://assets/art/entities/iron_golem_attack_pose_enhanced.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.6).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/iron_golem_ready_pose_enhanced.png")
				if ready_texture:
					_sprite.texture = ready_texture
