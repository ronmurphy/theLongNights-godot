extends GroundEntity

## Nightmare Emerald - Tier 4 Boss
## Extremely spiky dark orb
## Damages attackers with spike armor counterattack

@export var chase_distance := 30.0
@export var attack_range := 2.0
@export var attack_cooldown := 2.5
@export var chase_speed := 2.0
@export var spike_damage_percent := 0.5  # Returns 50% of damage taken

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
var _defensive_stance := false
const RETARGET_INTERVAL := 2.0


func _ready():
	entity_id = "nightmare_emerald"

	var data = EntityBase.load_entity_data("nightmare_emerald")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Nightmare Emerald"
		team = Team.ENEMY
		max_hp = 500
		attack_damage = 16
		defense = 32
		movement_speed = 2.0
		current_hp = max_hp

	super._ready()

	# Larger sprite for nightmare (1024x1024)
	_sprite = _create_sprite("res://assets/art/entities/nightmare_emerald_ready.png", 0.008)
	_find_best_target()

	# Connect to damage signal for spike counterattack
	took_damage.connect(_on_spike_counterattack)


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


func _on_spike_counterattack(amount: int, from: Node):
	# Spike armor: damage the attacker
	if from and from.has_method("take_damage"):
		var spike_damage = max(1, int(amount * spike_damage_percent))
		var attacker_name = from.get("entity_name") if from.has_method("get") else "attacker"
		print("🌵 %s's spikes pierce %s for %d damage!" % [entity_name, attacker_name, spike_damage])
		from.take_damage(spike_damage, self)


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
	var distance = global_position.distance_to(target_pos)

	# Check if should enter defensive stance (low HP)
	var hp_percent = float(current_hp) / float(max_hp)
	if hp_percent <= 0.3 and not _defensive_stance:
		_activate_defensive_stance()

	if distance > chase_distance:
		pass
	elif distance > attack_range:
		# Chase target (slow due to spikes)
		var direction = (target_pos - global_position).normalized()
		var velocity = direction * movement_speed
		apply_ground_movement(delta, velocity)

		# Face target
		look_at(target_pos, Vector3.UP)
	else:
		if _attack_timer <= 0:
			_perform_spike_attack()
			_attack_timer = attack_cooldown


func _activate_defensive_stance():
	_defensive_stance = true
	# Increase defense and spike damage when low on HP
	defense = int(defense * 1.3)
	spike_damage_percent = 0.75  # Return 75% of damage
	print("🛡️ %s enters DEFENSIVE STANCE! Spikes intensify!" % entity_name)


func _perform_spike_attack():
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	var damage = attack_damage

	print("🌵 %s impales %s with spikes for %d damage!" % [entity_name, target_name, damage])

	if _current_target.has_method("take_damage"):
		_current_target.take_damage(damage, self)

	# Animate
	if _sprite:
		var attack_texture = load("res://assets/art/entities/nightmare_emerald_attack.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.4).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/nightmare_emerald_ready.png")
				if ready_texture:
					_sprite.texture = ready_texture
