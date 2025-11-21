extends GroundEntity

## Dire Wolf - Tier 5 Enemy
## Alpha predator, leads wolf packs, relentless pursuit

@export var chase_distance := 30.0  # Long chase range
@export var attack_range := 2.0
@export var attack_cooldown := 1.3

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
var _howl_cooldown := 0.0
const RETARGET_INTERVAL := 2.0
const HOWL_COOLDOWN := 20.0  # Pack buff every 20 seconds


func _ready():
	entity_id = "dire_wolf"

	var data = EntityBase.load_entity_data("dire_wolf")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Dire Wolf"
		team = Team.ENEMY
		max_hp = 70
		attack_damage = 12
		defense = 16
		movement_speed = 7.0
		current_hp = max_hp

	super._ready()

	_sprite = _create_sprite("res://assets/art/entities/dire_wolf_ready_pose_enhanced.png", 0.0035)
	set_collision_box(Vector3(0.8, 1.0, 0.8))
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

	_howl_cooldown -= delta

	# Howl to buff pack
	if _howl_cooldown <= 0:
		_perform_howl()
		_howl_cooldown = HOWL_COOLDOWN

	if _current_target == null or not is_instance_valid(_current_target) or _current_target.get("is_alive") != true:
		_find_best_target()
		if _current_target == null:
			return

	if _attack_timer > 0:
		_attack_timer -= delta

	var target_pos = _current_target.global_position
	var distance = target_pos.distance_to(global_position)

	var movement_input = Vector3.ZERO

	# Relentless: Chase even at very long distances
	if distance > attack_range:
		var direction = (target_pos - global_position).normalized()
		direction.y = 0
		movement_input = direction * movement_speed
	else:
		if _attack_timer <= 0:
			_perform_attack()
			_attack_timer = attack_cooldown

	apply_ground_movement(delta, movement_input)


func _perform_howl():
	"""Pack Leader: Buff nearby wolf-type enemies"""
	print("🐺 %s howls! Pack gains speed boost!" % entity_name)

	# Find all nearby enemies (could buff other dire wolves or regular wolves)
	var enemies = get_tree().get_nodes_in_group("enemy_entities")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_alive:
			continue

		var distance = global_position.distance_to(enemy.global_position)
		if distance < 20.0:
			# Apply speed buff
			if "movement_speed" in enemy:
				enemy.movement_speed *= 1.3  # +30% speed
				enemy.set_meta("pack_buff", true)
				print("  🐺 %s buffed!" % enemy.get("entity_name"))


func _perform_attack():
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	print("🐺 %s bites %s for %d damage!" % [entity_name, target_name, attack_damage])

	if _current_target.has_method("take_damage"):
		_current_target.take_damage(attack_damage, self)

	if _sprite:
		var attack_texture = load("res://assets/art/entities/dire_wolf_attack_pose_enhanced.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.3).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/dire_wolf_ready_pose_enhanced.png")
				if ready_texture:
					_sprite.texture = ready_texture
