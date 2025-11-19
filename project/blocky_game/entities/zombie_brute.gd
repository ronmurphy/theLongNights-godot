extends GroundEntity

## Zombie Brute - Tier 2 Tank Enemy
## Slow but devastating, high HP, slam attack

@export var chase_distance := 18.0
@export var attack_range := 2.5
@export var attack_cooldown := 2.5

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
const RETARGET_INTERVAL := 2.5


func _ready():
	entity_id = "zombie_brute"

	var data = EntityBase.load_entity_data("zombie_brute")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Zombie Brute"
		team = Team.ENEMY
		max_hp = 35
		attack_damage = 7
		defense = 12
		movement_speed = 1.0
		current_hp = max_hp

	super._ready()

	_sprite = _create_sprite("res://assets/art/entities/zombie_brute_ready_pose_enhanced.png", 0.0035)  # Larger sprite
	_create_health_bar()
	set_collision_box(Vector3(0.8, 1.5, 0.8))  # Big tank
	_find_best_target()


func _find_best_target():
	"""Find strongest target (highest max HP)"""
	var possible_targets = []

	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("is_alive") == true:
		possible_targets.append(player)

	var companions = get_tree().get_nodes_in_group("friendly_entities")
	for companion in companions:
		if companion.get("is_alive") == true:
			possible_targets.append(companion)

	# Find strongest target (zombie brute focuses on toughest enemy)
	var strongest = null
	var highest_hp = 0
	for target in possible_targets:
		var target_hp = target.get("max_hp") if target.has_method("get") else 0
		if target_hp > highest_hp:
			highest_hp = target_hp
			strongest = target

	_current_target = strongest


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
			_perform_attack()
			_attack_timer = attack_cooldown

	apply_ground_movement(delta, movement_input)


func _perform_attack():
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	print("💥 %s SLAMS %s for %d damage!" % [entity_name, target_name, attack_damage])

	if _current_target.has_method("take_damage"):
		_current_target.take_damage(attack_damage, self)

	if _sprite:
		var attack_texture = load("res://assets/art/entities/zombie_brute_attack_pose_enhanced.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.5).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/zombie_brute_ready_pose_enhanced.png")
				if ready_texture:
					_sprite.texture = ready_texture
