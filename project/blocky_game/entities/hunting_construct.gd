extends GroundEntity

## Hunting Construct - Tier 5 RANGED Enemy
## Advanced hunting robot designed to track and eliminate targets

@export var chase_distance := 35.0  # Very long tracking range
@export var preferred_distance := 18.0
@export var min_distance := 10.0
@export var attack_range := 30.0
@export var attack_cooldown := 2.0

const EnergyBeam = preload("res://blocky_game/projectiles/energy_beam.gd")

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
var _target_locked := false
const RETARGET_INTERVAL := 1.0  # Very frequent retargeting


func _ready():
	entity_id = "hunting_construct"

	var data = EntityBase.load_entity_data("hunting_construct")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Hunting Construct"
		team = Team.ENEMY
		max_hp = 110
		attack_damage = 15
		defense = 20
		movement_speed = 9.0
		current_hp = max_hp

	super._ready()

	_sprite = _create_sprite("res://assets/art/entities/hunting_construct_ready_pose_enhanced.png", 0.004)
	_create_health_bar()
	set_collision_box(Vector3(0.8, 1.6, 0.8))
	_find_best_target()


func _find_best_target():
	"""Advanced AI: Target lowest HP enemy"""
	var possible_targets = []

	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("is_alive") == true:
		possible_targets.append(player)

	var companions = get_tree().get_nodes_in_group("friendly_entities")
	for companion in companions:
		if companion.get("is_alive") == true:
			possible_targets.append(companion)

	# Advanced AI: Target lowest HP (finish off wounded targets)
	var weakest = null
	var lowest_hp = INF
	for target in possible_targets:
		var target_hp = target.get("current_hp") if target.has_method("get") else INF
		if target_hp < lowest_hp:
			lowest_hp = target_hp
			weakest = target

	_current_target = weakest
	_target_locked = _current_target != null


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
		pass  # Don't give up chase easily
	elif distance < min_distance:
		var direction = (global_position - target_pos).normalized()
		direction.y = 0
		movement_input = direction * movement_speed * 0.6
	elif distance > preferred_distance:
		var direction = (target_pos - global_position).normalized()
		direction.y = 0
		movement_input = direction * movement_speed * 0.7
	else:
		if _attack_timer <= 0:
			_perform_energy_beam()
			_attack_timer = attack_cooldown

	apply_ground_movement(delta, movement_input)


func _perform_energy_beam():
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	print("🤖 %s fires energy beam at %s!" % [entity_name, target_name])

	var beam = Node3D.new()
	beam.set_script(EnergyBeam)

	var game = get_node_or_null("/root/Main/Game")
	if game:
		game.add_child(beam)

		var shoot_pos = global_position + Vector3(0, 1.3, 0)

		# Advanced targeting with prediction
		var target_velocity = Vector3.ZERO
		if _current_target.has_method("get_velocity"):
			target_velocity = _current_target.get_velocity()

		var time_to_impact = global_position.distance_to(_current_target.global_position) / 35.0
		var predicted_pos = _current_target.global_position + target_velocity * time_to_impact
		var target_shoot_pos = predicted_pos + Vector3(0, 0.8, 0)

		beam.initialize(shoot_pos, target_shoot_pos, self)

	if _sprite:
		var attack_texture = load("res://assets/art/entities/hunting_construct_attack_pose_enhanced.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.4).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/hunting_construct_ready_pose_enhanced.png")
				if ready_texture:
					_sprite.texture = ready_texture
