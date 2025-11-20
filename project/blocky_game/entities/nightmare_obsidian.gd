extends GroundEntity

## Nightmare Obsidian - Ultimate Boss
## Tall humanoid nightmare made of pure darkness
## Reality-tearing void strikes and nightmare summoning

@export var chase_distance := 40.0
@export var attack_range := 3.0
@export var attack_cooldown := 2.0
@export var chase_speed := 6.0
@export var summon_cooldown := 15.0  # Summons minions every 15s
@export var reality_tear_threshold := 0.5  # Unlocks at 50% HP

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
var _summon_timer := 0.0
var _can_reality_tear := false
const RETARGET_INTERVAL := 2.0


func _ready():
	entity_id = "nightmare_obsidian"

	var data = EntityBase.load_entity_data("nightmare_obsidian")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Nightmare Obsidian"
		team = Team.ENEMY
		max_hp = 1000
		attack_damage = 25
		defense = 35
		movement_speed = 6.0
		current_hp = max_hp

	super._ready()

	# Larger sprite for nightmare (1024x1024)
	_sprite = _create_sprite("res://assets/art/entities/nightmare_obsidian_ready.png", 0.008)
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

	# Prioritize player for boss fight
	if player and player.get("is_alive") == true:
		_current_target = player
		return

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

	# Check for reality tear unlock
	var hp_percent = float(current_hp) / float(max_hp)
	if hp_percent <= reality_tear_threshold and not _can_reality_tear:
		_unlock_reality_tear()

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

	_summon_timer -= delta
	if _summon_timer <= 0:
		_summon_nightmare_minions()
		_summon_timer = summon_cooldown

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
			if _can_reality_tear and randf() < 0.3:  # 30% chance for reality tear
				_perform_reality_tear()
			else:
				_perform_void_strike()
			_attack_timer = attack_cooldown


func _unlock_reality_tear():
	_can_reality_tear = true
	print("🌌 %s tears through REALITY itself!" % entity_name)


func _perform_void_strike():
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	var damage = attack_damage

	print("⚫ %s strikes %s with VOID POWER for %d damage!" % [entity_name, target_name, damage])

	if _current_target.has_method("take_damage"):
		_current_target.take_damage(damage, self)

	_animate_attack()


func _perform_reality_tear():
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	var damage = int(attack_damage * 1.5)  # 50% more damage

	print("🌌 %s TEARS REALITY and strikes %s for %d damage!" % [entity_name, target_name, damage])

	if _current_target.has_method("take_damage"):
		_current_target.take_damage(damage, self)

		# Reality tear also damages nearby entities
		var nearby_entities = get_tree().get_nodes_in_group("player")
		nearby_entities.append_array(get_tree().get_nodes_in_group("friendly_entities"))

		for entity in nearby_entities:
			if entity == _current_target or not is_instance_valid(entity):
				continue

			var dist = global_position.distance_to(entity.global_position)
			if dist <= 5.0 and entity.get("is_alive") == true:
				var splash_damage = int(damage * 0.5)
				print("  🌌 Reality tear catches %s for %d splash damage!" % [entity.get("entity_name"), splash_damage])
				if entity.has_method("take_damage"):
					entity.take_damage(splash_damage, self)

	_animate_attack()


func _summon_nightmare_minions():
	print("👻 %s summons nightmare minions!" % entity_name)

	# Summon 2 angry ghosts to help
	for i in range(2):
		var AngryGhost = load("res://blocky_game/entities/angry_ghost.tscn")
		if AngryGhost:
			var minion = AngryGhost.instantiate()
			# Spawn near boss
			var spawn_offset = Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
			minion.global_position = global_position + spawn_offset
			get_tree().root.add_child(minion)


func _animate_attack():
	# Animate
	if _sprite:
		var attack_texture = load("res://assets/art/entities/nightmare_obsidian_attack.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.5).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/nightmare_obsidian_ready.png")
				if ready_texture:
					_sprite.texture = ready_texture
