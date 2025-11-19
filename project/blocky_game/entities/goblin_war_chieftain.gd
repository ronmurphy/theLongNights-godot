extends GroundEntity

## Goblin War Chieftain - Tier 4 Mini-Boss
## Leader of goblin clans, tactical genius with War Cry ability

@export var chase_distance := 20.0
@export var attack_range := 2.5
@export var attack_cooldown := 1.8

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
var _war_cry_cooldown := 0.0
const RETARGET_INTERVAL := 2.0
const WAR_CRY_COOLDOWN := 15.0  # War Cry every 15 seconds


func _ready():
	entity_id = "goblin_war_chieftain"

	var data = EntityBase.load_entity_data("goblin_war_chieftain")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Goblin War Chieftain"
		team = Team.ENEMY
		max_hp = 45
		attack_damage = 8
		defense = 16
		movement_speed = 4.0
		current_hp = max_hp

	super._ready()

	_sprite = _create_sprite("res://assets/art/entities/goblin_war_chieftain_ready_pose_enhanced.png", 0.0035)
	set_collision_box(Vector3(0.7, 1.2, 0.7))
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

	if _war_cry_cooldown > 0:
		_war_cry_cooldown -= delta

	if _current_target == null or not is_instance_valid(_current_target) or _current_target.get("is_alive") != true:
		_find_best_target()
		if _current_target == null:
			return

	if _attack_timer > 0:
		_attack_timer -= delta

	# War Cry buff nearby goblins
	if _war_cry_cooldown <= 0:
		_perform_war_cry()
		_war_cry_cooldown = WAR_CRY_COOLDOWN

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
			_perform_attack()
			_attack_timer = attack_cooldown

	apply_ground_movement(delta, movement_input)


func _perform_war_cry():
	"""War Cry: Buff nearby goblin enemies"""
	print("⚔️ %s roars WAR CRY! Goblins gain +50%% attack!" % entity_name)

	# Find all goblin enemies in range
	var goblins = get_tree().get_nodes_in_group("enemy_entities")
	for goblin in goblins:
		if not is_instance_valid(goblin) or not goblin.is_alive:
			continue

		# Check if it's a goblin and within range
		var goblin_id = goblin.get("entity_id")
		if goblin_id and ("goblin" in goblin_id):
			var distance = global_position.distance_to(goblin.global_position)
			if distance < 15.0:
				# Apply buff (temporary damage boost)
				if goblin.has_method("set_meta"):
					goblin.set_meta("war_cry_buff", true)
					goblin.attack_damage = int(goblin.attack_damage * 1.5)
					print("  🎺 %s buffed!" % goblin.get("entity_name"))


func _perform_attack():
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	print("👑 %s attacks %s for %d damage!" % [entity_name, target_name, attack_damage])

	if _current_target.has_method("take_damage"):
		_current_target.take_damage(attack_damage, self)

	if _sprite:
		var attack_texture = load("res://assets/art/entities/goblin_war_chieftain_attack_pose_enhanced.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.4).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/goblin_war_chieftain_ready_pose_enhanced.png")
				if ready_texture:
					_sprite.texture = ready_texture
