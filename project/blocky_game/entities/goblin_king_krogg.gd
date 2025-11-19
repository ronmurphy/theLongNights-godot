extends GroundEntity

## Goblin King Krogg - Tier 5 BOSS
## Uses minions strategically, becomes more dangerous when wounded

@export var chase_distance := 25.0
@export var attack_range := 3.0
@export var attack_cooldown := 2.0

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
var _summon_cooldown := 0.0
var _berserker_active := false
const RETARGET_INTERVAL := 2.0
const SUMMON_COOLDOWN := 15.0  # Summon minions every 15 seconds


func _ready():
	entity_id = "goblin_king_krogg"

	var data = EntityBase.load_entity_data("goblin_king_krogg")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Goblin King Krogg"
		team = Team.ENEMY
		max_hp = 120
		attack_damage = 12
		defense = 18
		movement_speed = 5.0
		current_hp = max_hp

	super._ready()

	_sprite = _create_sprite("res://assets/art/entities/goblin_king_krogg_ready_pose_enhanced.png", 0.005)  # Large boss sprite
	set_collision_box(Vector3(1.0, 1.5, 1.0))
	_find_best_target()

	print("👑 BOSS FIGHT: Goblin King Krogg has arrived!")


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

	_summon_cooldown -= delta

	# Berserker Rage: Activate when below 50% HP
	if not _berserker_active and current_hp < max_hp * 0.5:
		_activate_berserker_rage()

	# Summon Minions
	if _summon_cooldown <= 0:
		_summon_minions()
		_summon_cooldown = SUMMON_COOLDOWN

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


func _activate_berserker_rage():
	"""Berserker Rage: Increase attack and speed when wounded"""
	_berserker_active = true
	attack_damage = int(attack_damage * 1.5)
	movement_speed *= 1.3
	attack_cooldown *= 0.7  # Attack faster
	print("⚔️ %s enters BERSERKER RAGE! (+50%% attack, +30%% speed!)" % entity_name)


func _summon_minions():
	"""Summon Minions: Spawn goblin grunts to help in battle"""
	print("👑 %s summons minions!" % entity_name)

	var game = get_node_or_null("/root/Main/Game")
	if not game:
		return

	# Spawn 2-3 goblin grunts around the boss
	var num_minions = randi_range(2, 3)
	for i in range(num_minions):
		var scene_path = "res://blocky_game/entities/goblin_grunt.tscn"
		if not ResourceLoader.exists(scene_path):
			continue

		var minion_scene = load(scene_path)
		var minion = minion_scene.instantiate()

		# Spawn in circle around boss
		var angle = (TAU / num_minions) * i
		var offset = Vector3(cos(angle) * 5.0, 0, sin(angle) * 5.0)
		var spawn_pos = global_position + offset

		game.add_child(minion)
		minion.global_position = spawn_pos

		print("  👑 Spawned goblin grunt minion!")


func _perform_attack():
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	var rage_text = " (BERSERKER RAGE!)" if _berserker_active else ""
	print("👑 %s attacks %s for %d damage!%s" % [entity_name, target_name, attack_damage, rage_text])

	if _current_target.has_method("take_damage"):
		_current_target.take_damage(attack_damage, self)

	if _sprite:
		var attack_texture = load("res://assets/art/entities/goblin_king_krogg_attack_pose_enhanced.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.4).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/goblin_king_krogg_ready_pose_enhanced.png")
				if ready_texture:
					_sprite.texture = ready_texture


func _on_death() -> void:
	print("👑 BOSS DEFEATED: Goblin King Krogg has fallen!")
	super._on_death()
	# TODO: Drop special loot (goblin_crown, royal_weapon, floor_key)
