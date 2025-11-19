extends GroundEntity

## Scatterer - Tier 2 RANGED Enemy
## Fast-moving enemy that fires scatter shots at multiple targets

@export var chase_distance := 25.0
@export var preferred_distance := 12.0
@export var min_distance := 7.0
@export var attack_range := 20.0
@export var attack_cooldown := 2.5

const ScatterShot = preload("res://blocky_game/projectiles/scatter_shot.gd")

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
const RETARGET_INTERVAL := 1.5


func _ready():
	entity_id = "scatterer"

	var data = EntityBase.load_entity_data("scatterer")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Scatterer"
		team = Team.ENEMY
		max_hp = 16
		attack_damage = 6
		defense = 15
		movement_speed = 6.0
		current_hp = max_hp

	super._ready()

	_sprite = _create_sprite("res://assets/art/entities/scatterer_ready_pose_enhanced.png", 0.0025)
	set_collision_box(Vector3(0.5, 0.8, 0.5))
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
	elif distance < min_distance:
		var direction = (global_position - target_pos).normalized()
		direction.y = 0
		movement_input = direction * movement_speed * 0.7
	elif distance > preferred_distance:
		var direction = (target_pos - global_position).normalized()
		direction.y = 0
		movement_input = direction * movement_speed * 0.6
	else:
		if _attack_timer <= 0:
			_perform_scatter_shot()
			_attack_timer = attack_cooldown

	apply_ground_movement(delta, movement_input)


func _perform_scatter_shot():
	if _current_target == null:
		return

	print("🎯 %s fires scatter shot!" % entity_name)

	# Fire 3 projectiles in a spread pattern
	var game = get_node_or_null("/root/Main/Game")
	if not game:
		return

	var shoot_pos = global_position + Vector3(0, 1.0, 0)
	var target_pos = _current_target.global_position + Vector3(0, 0.5, 0)
	var base_direction = (target_pos - shoot_pos).normalized()

	# Fire 3 shots with slight angle variation
	for i in range(3):
		var shot = Node3D.new()
		shot.set_script(ScatterShot)
		game.add_child(shot)

		# Angle variation: -15°, 0°, +15°
		var angle_offset = (i - 1) * 0.26  # ~15 degrees in radians
		var rotated_direction = base_direction.rotated(Vector3.UP, angle_offset)
		var shot_target = shoot_pos + rotated_direction * 20.0

		shot.initialize(shoot_pos, shot_target, self)

	if _sprite:
		var attack_texture = load("res://assets/art/entities/scatterer_attack_pose_enhanced.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.4).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/scatterer_ready_pose_enhanced.png")
				if ready_texture:
					_sprite.texture = ready_texture
