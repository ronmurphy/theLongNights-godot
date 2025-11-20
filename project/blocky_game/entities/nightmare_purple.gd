extends GroundEntity

## Nightmare Purple - Tier 1 Boss
## Floating dark orb with countless gnashing teeth
## Aggressive biter with fear aura

@export var chase_distance := 30.0
@export var attack_range := 1.5
@export var attack_cooldown := 1.5
@export var chase_speed := 4.0
@export var bite_frenzy_threshold := 0.3  # HP% to trigger frenzy

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
var _in_frenzy := false
const RETARGET_INTERVAL := 2.0


func _ready():
	entity_id = "nightmare_purple"

	var data = EntityBase.load_entity_data("nightmare_purple")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Nightmare Purple"
		team = Team.ENEMY
		max_hp = 150
		attack_damage = 8
		defense = 24
		movement_speed = 4.0
		current_hp = max_hp

	super._ready()

	# Larger sprite for nightmare (1024x1024)
	_sprite = _create_sprite("res://assets/art/entities/nightmare_ready_purple.png", 0.008)
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

	# Check for frenzy mode
	var hp_percent = float(current_hp) / float(max_hp)
	if hp_percent <= bite_frenzy_threshold and not _in_frenzy:
		_activate_frenzy()

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
	var distance = global_position.distance_to(target_pos)

	if distance > chase_distance:
		pass
	elif distance > attack_range:
		# Chase target
		var direction = (target_pos - global_position).normalized()
		var velocity = direction * movement_speed
		apply_ground_movement(delta, velocity)

		# Face target
		look_at(target_pos, Vector3.UP)
	else:
		if _attack_timer <= 0:
			_perform_bite_attack()
			_attack_timer = attack_cooldown


func _activate_frenzy():
	_in_frenzy = true
	attack_cooldown *= 0.5  # Attack twice as fast
	movement_speed *= 1.3  # Move faster
	print("💀 %s enters BITING FRENZY!" % entity_name)


func _perform_bite_attack():
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	var damage = attack_damage

	if _in_frenzy:
		damage = int(damage * 1.5)  # 50% more damage in frenzy
		print("😈 %s FRENZIED BITE on %s for %d damage!" % [entity_name, target_name, damage])
	else:
		print("😈 %s gnashes teeth at %s for %d damage!" % [entity_name, target_name, damage])

	if _current_target.has_method("take_damage"):
		_current_target.take_damage(damage, self)

	# Animate
	if _sprite:
		var attack_texture = load("res://assets/art/entities/nightmare_attack_purple.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.4).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/nightmare_ready_purple.png")
				if ready_texture:
					_sprite.texture = ready_texture
