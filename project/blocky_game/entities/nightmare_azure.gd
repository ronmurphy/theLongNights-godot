extends GroundEntity

## Nightmare Azure - Tier 3 Boss
## Dark orb with writhing tendrils
## Slows and grapples enemies with multi-strike

@export var chase_distance := 30.0
@export var attack_range := 3.0
@export var attack_cooldown := 2.5
@export var chase_speed := 3.0
@export var slow_aura_range := 5.0

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
var _slow_aura_timer := 0.0
const RETARGET_INTERVAL := 2.0
const SLOW_AURA_TICK := 0.5


func _ready():
	entity_id = "nightmare_azure"

	var data = EntityBase.load_entity_data("nightmare_azure")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Nightmare Azure"
		team = Team.ENEMY
		max_hp = 400
		attack_damage = 15
		defense = 30
		movement_speed = 3.0
		current_hp = max_hp

	super._ready()

	# Larger sprite for nightmare (1024x1024)
	_sprite = _create_sprite("res://assets/art/entities/nightmare_azure_ready.png", 0.008)
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

	# Slow aura effect
	_slow_aura_timer -= delta
	if _slow_aura_timer <= 0:
		_apply_slow_aura()
		_slow_aura_timer = SLOW_AURA_TICK

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
			_perform_tendril_attack()
			_attack_timer = attack_cooldown


func _apply_slow_aura():
	# Slow all nearby enemies (player and companions)
	var nearby_entities = get_tree().get_nodes_in_group("player")
	nearby_entities.append_array(get_tree().get_nodes_in_group("friendly_entities"))

	for entity in nearby_entities:
		if not is_instance_valid(entity) or entity.get("is_alive") != true:
			continue

		var distance = global_position.distance_to(entity.global_position)
		if distance <= slow_aura_range:
			# Apply temporary slow (reduce movement speed)
			# This is a basic implementation - could be enhanced with actual status effects
			if entity.has_method("get") and entity.get("movement_speed"):
				var current_speed = entity.get("movement_speed")
				# Slow effect handled by game mechanics (visual feedback only here)
				print("🌀 %s's tendrils slow nearby enemies!" % entity_name)


func _perform_tendril_attack():
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"

	# Multi-strike: hit 3 times with tendrils
	var damage_per_hit = int(attack_damage / 3)

	print("🐙 %s lashes %s with tendrils! (Multi-Strike x3)" % [entity_name, target_name])

	if _current_target.has_method("take_damage"):
		for i in range(3):
			_current_target.take_damage(damage_per_hit, self)
			await get_tree().create_timer(0.15).timeout  # Quick succession

	# Animate
	if _sprite:
		var attack_texture = load("res://assets/art/entities/nightmare_azure_attack.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.6).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/nightmare_azure_ready.png")
				if ready_texture:
					_sprite.texture = ready_texture
