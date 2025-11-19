extends GroundEntity

## Kraken Spawn - Tier 5 Boss-Level Enemy
## Massive sea creature, uses tentacles and ink strategically

@export var chase_distance := 25.0
@export var attack_range := 4.0  # Long tentacle reach
@export var attack_cooldown := 2.5

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
var _ink_cloud_cooldown := 0.0
const RETARGET_INTERVAL := 2.5
const INK_CLOUD_COOLDOWN := 12.0


func _ready():
	entity_id = "kraken_spawn"

	var data = EntityBase.load_entity_data("kraken_spawn")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Kraken Spawn"
		team = Team.ENEMY
		max_hp = 120
		attack_damage = 14
		defense = 19
		movement_speed = 5.0
		current_hp = max_hp

	super._ready()

	_sprite = _create_sprite("res://assets/art/entities/kraken_spawn_ready_pose_enhanced.png", 0.006)  # Massive sprite
	_create_health_bar()
	set_collision_box(Vector3(2.0, 2.0, 2.0))  # Huge creature
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

	_ink_cloud_cooldown -= delta

	if _current_target == null or not is_instance_valid(_current_target) or _current_target.get("is_alive") != true:
		_find_best_target()
		if _current_target == null:
			return

	if _attack_timer > 0:
		_attack_timer -= delta

	# Use ink cloud defensively when low HP
	if current_hp < max_hp * 0.3 and _ink_cloud_cooldown <= 0:
		_deploy_ink_cloud()
		_ink_cloud_cooldown = INK_CLOUD_COOLDOWN

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
			_perform_grapple_attack()
			_attack_timer = attack_cooldown

	apply_ground_movement(delta, movement_input)


func _perform_grapple_attack():
	"""Grappling Master: Pull target closer and damage"""
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	print("🦑 %s grapples %s with tentacles for %d damage!" % [entity_name, target_name, attack_damage])

	if _current_target.has_method("take_damage"):
		_current_target.take_damage(attack_damage, self)

	# TODO: Pull target closer

	if _sprite:
		var attack_texture = load("res://assets/art/entities/kraken_spawn_attack_pose_enhanced.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.5).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/kraken_spawn_ready_pose_enhanced.png")
				if ready_texture:
					_sprite.texture = ready_texture


func _deploy_ink_cloud():
	"""Ink Defense: Create obscuring cloud"""
	print("🌫️ %s deploys ink cloud!" % entity_name)
	# TODO: Spawn ink cloud that obscures vision and provides damage reduction
