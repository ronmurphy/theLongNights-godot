extends GroundEntity

## Tunnel Rat - Tier 4 Enemy
## Evolved rats adapted to subway environment, fast with armor destruction

@export var chase_distance := 18.0
@export var attack_range := 1.8
@export var attack_cooldown := 1.0  # Very fast attacks

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
const RETARGET_INTERVAL := 1.5


func _ready():
	entity_id = "tunnel_rat"

	var data = EntityBase.load_entity_data("tunnel_rat")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Tunnel Rat"
		team = Team.ENEMY
		max_hp = 35
		attack_damage = 9
		defense = 16
		movement_speed = 7.0
		current_hp = max_hp

	super._ready()

	_sprite = _create_sprite("res://assets/art/entities/tunnel_rat_ready_pose_enhanced.png", 0.0025)
	set_collision_box(Vector3(0.5, 0.5, 0.5))
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
			_perform_armor_break()
			_attack_timer = attack_cooldown

	apply_ground_movement(delta, movement_input)


func _perform_armor_break():
	"""Armor Destruction: Reduce target's defense temporarily"""
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"

	# Check if already debuffed
	var armor_broken = _current_target.get_meta("armor_broken", false)
	if not armor_broken:
		# Apply armor break debuff (-5 defense)
		if _current_target.has("defense"):
			var old_defense = _current_target.defense
			_current_target.defense = max(0, _current_target.defense - 5)
			_current_target.set_meta("armor_broken", true)
			print("🐀 %s BREAKS %s's armor! Defense: %d -> %d" % [entity_name, target_name, old_defense, _current_target.defense])

	print("🐀 %s bites %s for %d damage!" % [entity_name, target_name, attack_damage])

	if _current_target.has_method("take_damage"):
		_current_target.take_damage(attack_damage, self)

	if _sprite:
		var attack_texture = load("res://assets/art/entities/tunnel_rat_attack_pose_enhanced.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.25).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/tunnel_rat_ready_pose_enhanced.png")
				if ready_texture:
					_sprite.texture = ready_texture
