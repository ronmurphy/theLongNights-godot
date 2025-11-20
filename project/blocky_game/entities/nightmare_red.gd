extends GroundEntity

## Nightmare Red - Tier 2 Boss
## Floating orb covered in furious red eyes
## Becomes stronger when damaged (rage mechanic)

@export var chase_distance := 30.0
@export var attack_range := 2.0
@export var attack_cooldown := 2.0
@export var chase_speed := 5.0

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
var _rage_stacks := 0  # Gains stacks when damaged
const RETARGET_INTERVAL := 2.0
const MAX_RAGE_STACKS := 5


func _ready():
	entity_id = "nightmare_red"

	var data = EntityBase.load_entity_data("nightmare_red")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		entity_name = "Nightmare Red"
		team = Team.ENEMY
		max_hp = 250
		attack_damage = 12
		defense = 27
		movement_speed = 5.0
		current_hp = max_hp

	super._ready()

	# Larger sprite for nightmare (1024x1024)
	_sprite = _create_sprite("res://assets/art/entities/nightmare_ready_red.png", 0.008)
	_find_best_target()

	# Connect to took_damage signal to build rage
	took_damage.connect(_on_damage_taken)


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


func _on_damage_taken(amount: int, from: Node):
	# Build rage when damaged
	if _rage_stacks < MAX_RAGE_STACKS:
		_rage_stacks += 1
		print("🔥 %s's eyes burn with RAGE! (Stacks: %d)" % [entity_name, _rage_stacks])


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

	if distance > chase_distance:
		pass
	elif distance > attack_range:
		# Chase target (faster when enraged)
		var speed = movement_speed * (1.0 + (_rage_stacks * 0.1))
		var direction = (target_pos - global_position).normalized()
		var velocity = direction * speed
		apply_ground_movement(delta, velocity)

		# Face target
		look_at(target_pos, Vector3.UP)
	else:
		if _attack_timer <= 0:
			_perform_rage_strike()
			_attack_timer = attack_cooldown


func _perform_rage_strike():
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"

	# Damage increases with rage stacks
	var damage = attack_damage + (_rage_stacks * 2)

	print("👁️ %s strikes %s with RAGE for %d damage! (Rage: %d)" % [entity_name, target_name, damage, _rage_stacks])

	if _current_target.has_method("take_damage"):
		_current_target.take_damage(damage, self)

	# Animate
	if _sprite:
		var attack_texture = load("res://assets/art/entities/nightmare_attack_red.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.4).timeout
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/nightmare_ready_red.png")
				if ready_texture:
					_sprite.texture = ready_texture
