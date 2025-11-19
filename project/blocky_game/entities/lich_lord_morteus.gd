extends FlyingEntity

## Lich Lord Morteus - Tier 5 BOSS
## Master of undead magic, uses terrain and minions strategically

@export var chase_distance := 35.0
@export var preferred_distance := 20.0
@export var min_distance := 12.0
@export var attack_range := 30.0
@export var attack_cooldown := 2.5
@export var chase_speed := 6.0

const DeathBolt = preload("res://blocky_game/projectiles/death_bolt.gd")

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
var _raise_dead_cooldown := 0.0
var _shield_cooldown := 0.0
var _shield_active := false
const RETARGET_INTERVAL := 2.0
const RAISE_DEAD_COOLDOWN := 12.0  # Raise undead every 12 seconds
const SHIELD_COOLDOWN := 20.0
const SHIELD_DURATION := 5.0


func _ready():
	entity_id = "lich_lord_morteus"

	var data = EntityBase.load_entity_data("lich_lord_morteus")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Lich Lord Morteus"
		team = Team.ENEMY
		max_hp = 180
		attack_damage = 15
		defense = 19
		movement_speed = 6.0
		current_hp = max_hp

	super._ready()

	_sprite = _create_sprite("res://assets/art/entities/lich_lord_morteus_ready_pose_enhanced.png", 0.006)  # Massive boss sprite
	_find_best_target()

	print("💀 BOSS FIGHT: Lich Lord Morteus has risen!")


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

	_raise_dead_cooldown -= delta
	_shield_cooldown -= delta

	# Apply bobbing
	apply_bob_movement(delta)

	# Raise undead minions
	if _raise_dead_cooldown <= 0:
		_raise_undead()
		_raise_dead_cooldown = RAISE_DEAD_COOLDOWN

	# Activate spell resistance shield when low HP
	if not _shield_active and _shield_cooldown <= 0 and current_hp < max_hp * 0.4:
		_activate_spell_shield()

	if _current_target == null or not is_instance_valid(_current_target) or _current_target.get("is_alive") != true:
		_find_best_target()
		if _current_target == null:
			return

	if _attack_timer > 0:
		_attack_timer -= delta

	var target_pos = _current_target.global_position
	var distance = global_position.distance_to(target_pos)

	# Flying movement AI
	if distance > chase_distance:
		pass
	elif distance < min_distance:
		# Too close, fly away
		var retreat_pos = global_position + (global_position - target_pos).normalized() * 5.0
		move_toward_target(delta, retreat_pos, chase_speed, false)
	elif distance > preferred_distance:
		# Move to preferred range
		move_toward_target(delta, target_pos, chase_speed * 0.6, false)
	else:
		# In range, attack
		if _attack_timer <= 0:
			_perform_death_bolt()
			_attack_timer = attack_cooldown


func _raise_undead():
	"""Animate Dead: Spawn zombie crawlers"""
	print("💀 %s raises the dead!" % entity_name)

	var game = get_node_or_null("/root/Main/Game")
	if not game:
		return

	# Spawn 3 zombie crawlers
	for i in range(3):
		var scene_path = "res://blocky_game/entities/zombie_crawler.tscn"
		if not ResourceLoader.exists(scene_path):
			continue

		var zombie_scene = load(scene_path)
		var zombie = zombie_scene.instantiate()

		# Spawn in circle around lich
		var angle = (TAU / 3) * i
		var offset = Vector3(cos(angle) * 8.0, -5.0, sin(angle) * 8.0)
		var spawn_pos = global_position + offset

		game.add_child(zombie)
		zombie.global_position = spawn_pos

		print("  💀 Zombie crawler raised!")


func _activate_spell_shield():
	"""Spell Resistance: Reduce incoming damage"""
	print("🛡️ %s activates spell resistance shield!" % entity_name)
	_shield_active = true
	_shield_cooldown = SHIELD_COOLDOWN

	# Visual effect: Brighten sprite
	if _sprite:
		_sprite.modulate = Color(1.5, 1.5, 2.0)

	# Deactivate after duration
	await get_tree().create_timer(SHIELD_DURATION).timeout
	_shield_active = false
	if _sprite:
		_sprite.modulate = Color(1, 1, 1)


func take_damage(damage: int, attacker = null) -> void:
	# Spell Resistance: Reduce damage by 50% when shield active
	if _shield_active:
		damage = int(damage * 0.5)
		print("🛡️ Spell resistance reduces damage to %d!" % damage)

	super.take_damage(damage, attacker)


func _perform_death_bolt():
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	print("💀 %s casts DEATH BOLT at %s!" % [entity_name, target_name])

	var bolt = Node3D.new()
	bolt.set_script(DeathBolt)

	var game = get_node_or_null("/root/Main/Game")
	if game:
		game.add_child(bolt)

		var shoot_pos = global_position + Vector3(0, 0, 0)  # From center of lich

		var target_velocity = Vector3.ZERO
		if _current_target.has_method("get_velocity"):
			target_velocity = _current_target.get_velocity()

		var time_to_impact = global_position.distance_to(_current_target.global_position) / 22.0
		var predicted_pos = _current_target.global_position + target_velocity * time_to_impact
		var target_shoot_pos = predicted_pos + Vector3(0, 1.0, 0)

		bolt.initialize(shoot_pos, target_shoot_pos, self)

	if _sprite:
		var attack_texture = load("res://assets/art/entities/lich_lord_morteus_attack_pose_enhanced.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.6).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/lich_lord_morteus_ready_pose_enhanced.png")
				if ready_texture:
					_sprite.texture = ready_texture


func _on_death() -> void:
	print("💀 BOSS DEFEATED: Lich Lord Morteus has been destroyed!")
	super._on_death()
	# TODO: Drop legendary loot (lich_phylactery, necromantic_staff, undead_crown)
