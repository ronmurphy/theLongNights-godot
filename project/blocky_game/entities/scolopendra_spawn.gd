extends GroundEntity

## Scolopendra Spawn - Tier 4 Enemy
## Offspring of the great Scolopendra, multi-attack, corruption aura

@export var chase_distance := 18.0
@export var attack_range := 2.5
@export var attack_cooldown := 1.2  # Fast attacks

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
var _corruption_aura_timer := 0.0
const RETARGET_INTERVAL := 2.0
const CORRUPTION_TICK := 2.0  # Damage every 2 seconds


func _ready():
	entity_id = "scolopendra_spawn"

	var data = EntityBase.load_entity_data("scolopendra_spawn")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Scolopendra Spawn"
		team = Team.ENEMY
		max_hp = 45
		attack_damage = 9
		defense = 17
		movement_speed = 6.0
		current_hp = max_hp

	super._ready()

	_sprite = _create_sprite("res://assets/art/entities/scolopendra_spawn_ready_pose_enhanced.png", 0.0035)
	_create_health_bar()
	set_collision_box(Vector3(1.0, 0.8, 1.0))  # Long segmented body
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

	_corruption_aura_timer += delta
	if _corruption_aura_timer >= CORRUPTION_TICK:
		_corruption_aura_timer = 0.0
		_apply_corruption_aura()

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
			_perform_multi_attack()
			_attack_timer = attack_cooldown

	apply_ground_movement(delta, movement_input)


func _perform_multi_attack():
	"""Multi-Attack: Strike twice in rapid succession"""
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	print("🐛 %s multi-attacks %s!" % [entity_name, target_name])

	# First strike
	if _current_target.has_method("take_damage"):
		_current_target.take_damage(attack_damage, self)

	# Second strike (delayed slightly)
	await get_tree().create_timer(0.2).timeout
	if _current_target and is_instance_valid(_current_target) and _current_target.has_method("take_damage"):
		_current_target.take_damage(attack_damage, self)
		print("  🐛 Second strike!")

	if _sprite:
		var attack_texture = load("res://assets/art/entities/scolopendra_spawn_attack_pose_enhanced.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.3).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/scolopendra_spawn_ready_pose_enhanced.png")
				if ready_texture:
					_sprite.texture = ready_texture


func _apply_corruption_aura():
	"""Corruption Aura: Damage nearby enemies every 2 seconds"""
	var entities = get_tree().get_nodes_in_group("entities")
	for entity in entities:
		if not is_instance_valid(entity) or not entity.is_alive:
			continue
		if entity.team == Team.ENEMY:
			continue  # Don't corrupt other enemies

		var distance = global_position.distance_to(entity.global_position)
		if distance < 5.0:  # 5 block aura
			if entity.has_method("take_damage"):
				entity.take_damage(2, self)  # Minor corruption damage
				print("🟣 %s corrupts %s (2 damage)" % [entity_name, entity.get("entity_name")])
