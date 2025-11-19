extends FlyingEntity

## Bubble Fish - Tier 5 Flying/Aquatic Enemy
## Creates blinding bubbles, fast in water

@export var chase_distance := 22.0
@export var attack_range := 2.5
@export var attack_cooldown := 2.0
@export var chase_speed := 8.0

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
const RETARGET_INTERVAL := 1.5


func _ready():
	entity_id = "bubble_fish"

	var data = EntityBase.load_entity_data("bubble_fish")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Bubble Fish"
		team = Team.ENEMY
		max_hp = 38
		attack_damage = 10
		defense = 17
		movement_speed = 8.0
		current_hp = max_hp

	super._ready()

	_sprite = _create_sprite("res://assets/art/entities/bubble_fish_ready_pose_enhanced.png", 0.003)
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

	apply_bob_movement(delta)

	if _attack_timer > 0:
		_attack_timer -= delta

	var target_pos = _current_target.global_position
	var distance = global_position.distance_to(target_pos)

	if distance > chase_distance:
		pass
	elif distance > attack_range:
		# Fast flying movement
		move_toward_target(delta, target_pos, chase_speed, false)
	else:
		if _attack_timer <= 0:
			_perform_bubble_attack()
			_attack_timer = attack_cooldown


func _perform_bubble_attack():
	"""Blinding Attack: Damages and blinds target"""
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	print("🫧 %s creates blinding bubbles around %s for %d damage!" % [entity_name, target_name, attack_damage])

	if _current_target.has_method("take_damage"):
		_current_target.take_damage(attack_damage, self)

	# TODO: Apply blind status effect

	if _sprite:
		var attack_texture = load("res://assets/art/entities/bubble_fish_attack_pose_enhanced.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.4).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/bubble_fish_ready_pose_enhanced.png")
				if ready_texture:
					_sprite.texture = ready_texture
