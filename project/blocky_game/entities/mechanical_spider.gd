extends GroundEntity

## Mechanical Spider - Tier 5 Enemy
## Mechanical construct, creates webs, wall climbing

@export var chase_distance := 20.0
@export var attack_range := 2.0
@export var attack_cooldown := 1.5

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
var _web_cooldown := 0.0
const RETARGET_INTERVAL := 2.0
const WEB_COOLDOWN := 8.0  # Create web every 8 seconds


func _ready():
	entity_id = "mechanical_spider"

	var data = EntityBase.load_entity_data("mechanical_spider")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Mechanical Spider"
		team = Team.ENEMY
		max_hp = 42
		attack_damage = 10
		defense = 18
		movement_speed = 8.0
		current_hp = max_hp

	super._ready()

	_sprite = _create_sprite("res://assets/art/entities/mechanical_spider_ready_pose_enhanced.png", 0.0035)
	_create_health_bar()
	set_collision_box(Vector3(1.2, 0.6, 1.2))  # Wide spider body
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

	_web_cooldown -= delta

	if _current_target == null or not is_instance_valid(_current_target) or _current_target.get("is_alive") != true:
		_find_best_target()
		if _current_target == null:
			return

	if _attack_timer > 0:
		_attack_timer -= delta

	# Create web trap
	if _web_cooldown <= 0:
		_create_web_trap()
		_web_cooldown = WEB_COOLDOWN

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


func _create_web_trap():
	"""Create a web trap at current position (slows enemies)"""
	print("🕸️ %s creates web trap!" % entity_name)
	# TODO: Spawn web trap entity that slows player/companions


func _perform_attack():
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	print("🕷️ %s strikes %s for %d damage!" % [entity_name, target_name, attack_damage])

	if _current_target.has_method("take_damage"):
		_current_target.take_damage(attack_damage, self)

	if _sprite:
		var attack_texture = load("res://assets/art/entities/mechanical_spider_attack_pose_enhanced.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.3).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/mechanical_spider_ready_pose_enhanced.png")
				if ready_texture:
					_sprite.texture = ready_texture
