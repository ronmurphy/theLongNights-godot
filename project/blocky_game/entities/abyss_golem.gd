extends GroundEntity

## Abyss Golem - Tier 6 Undervoid Boss
## First ranged enemy! Shoots purple void bolts at player and companions
## Guards Undervoid structures with devastating purple energy attacks

@export var chase_distance := 120.0  # X-RAY: Void sense penetrates all!
@export var preferred_distance := 10.0  # Ideal shooting distance
@export var min_distance := 5.0  # Back away if closer than this
@export var attack_range := 100.0  # Void bolts strike from afar!
@export var attack_cooldown := 2.5  # Slower attack rate for ranged

const VoidBolt = preload("res://blocky_game/projectiles/void_bolt.gd")

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
const RETARGET_INTERVAL := 1.5  # Re-evaluate target frequently


func _ready():
	entity_id = "abyss_golem"

	# Load from JSON
	var data = EntityBase.load_entity_data("abyss_golem")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		# Fallback
		entity_name = "Abyss Golem"
		team = Team.ENEMY
		max_hp = 100
		attack_damage = 14
		defense = 22
		movement_speed = 3.0
		current_hp = max_hp

	super._ready()

	_sprite = _create_sprite("res://assets/art/entities/abyss_golem_ready.png", 0.004)
	set_collision_box(Vector3(1.0, 1.8, 1.0))  # Larger than normal enemies
	_find_best_target()


func _find_best_target():
	"""Find the closest valid target (player OR companion)"""
	var possible_targets = []

	# Add player to potential targets
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("is_alive") == true:
		possible_targets.append(player)

	# Add ALL companions to potential targets
	var companions = get_tree().get_nodes_in_group("friendly_entities")
	for companion in companions:
		if companion.get("is_alive") == true:
			possible_targets.append(companion)

	# Pick closest target
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

	# Re-evaluate target periodically
	_retarget_timer -= delta
	if _retarget_timer <= 0:
		_find_best_target()
		_retarget_timer = RETARGET_INTERVAL

	# If no target or target is dead, find a new one
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
		# Too far, don't engage
		pass
	elif distance < min_distance:
		# Too close! Back away to maintain shooting distance
		var direction = (global_position - target_pos).normalized()
		direction.y = 0
		movement_input = direction * movement_speed * 0.7  # Move slower when backing up
	elif distance > preferred_distance:
		# Move closer to preferred shooting range
		var direction = (target_pos - global_position).normalized()
		direction.y = 0
		movement_input = direction * movement_speed * 0.5  # Move slowly to maintain position
	else:
		# In range! Stop and shoot
		if _attack_timer <= 0:
			_perform_ranged_attack()
			_attack_timer = attack_cooldown

	apply_ground_movement(delta, movement_input)


func _perform_ranged_attack():
	"""Shoot a void bolt at the target"""
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	print("🟣 %s shoots void bolt at %s!" % [entity_name, target_name])

	# Create void bolt projectile
	var bolt = Node3D.new()
	bolt.set_script(VoidBolt)

	# Add to game world
	var game = get_node_or_null("/root/Main/Game")
	if game:
		game.add_child(bolt)

		# Shoot from slightly above golem's position
		var shoot_pos = global_position + Vector3(0, 1.0, 0)

		# Lead the target slightly (predict where they'll be)
		var target_velocity = Vector3.ZERO
		if _current_target.has_method("get_velocity"):
			target_velocity = _current_target.get_velocity()

		var time_to_impact = global_position.distance_to(_current_target.global_position) / 20.0  # 20 = bolt speed
		var predicted_pos = _current_target.global_position + target_velocity * time_to_impact

		# Aim for center mass (slightly above ground)
		var target_shoot_pos = predicted_pos + Vector3(0, 0.5, 0)

		bolt.initialize(shoot_pos, target_shoot_pos, self)

	# Swap to attack sprite
	if _sprite:
		var attack_texture = load("res://assets/art/entities/abyss_golem_attack.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.5).timeout  # Hold attack pose longer
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/abyss_golem_ready.png")
				if ready_texture:
					_sprite.texture = ready_texture
