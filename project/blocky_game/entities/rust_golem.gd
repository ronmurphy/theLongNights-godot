extends FlyingEntity

## Rust Golem - FLYING enemy for underground depths
## Massive rusted mechanical construct found in Mechanical Warrens (Y=-300 to -400)
## Flies through tight cave tunnels - terrifying in confined spaces!

@export var chase_distance := 25.0  # Longer chase in caves (can't escape easily!)
@export var attack_range := 2.5
@export var attack_cooldown := 1.8  # Slightly faster than sky golem
@export var fly_speed := 4.0  # Slightly faster in tunnels

var _current_target: Node = null
var _attack_timer := 0.0
var _retarget_timer := 0.0
const RETARGET_INTERVAL := 2.0


func _ready():
	entity_id = "rust_golem"

	# Load from JSON if it exists
	var data = EntityBase.load_entity_data("rust_golem")
	if not data.is_empty():
		apply_entity_data(data)
	else:
		# Fallback - similar to sky golem but underground variant
		entity_name = "Rust Golem"
		team = Team.ENEMY
		max_hp = 40  # Slightly tougher
		attack_damage = 9  # Slightly more damage
		defense = 15
		movement_speed = 4.0
		current_hp = max_hp

	super._ready()

	# Flying entity settings
	float_height = 1.5  # Lower hover (caves have lower ceilings)
	bob_amplitude = 0.3  # More erratic bobbing (damaged/unstable)
	bob_frequency = 1.2  # Faster bob (more aggressive)

	_sprite = _create_sprite("res://assets/art/entities/rust_golem_ready.png", 0.005)
	_create_health_bar()
	_find_best_target()

	print("Rust Golem spawned (UNDERGROUND FLYING) at: ", global_position)


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

	# Update bobbing animation
	apply_bob_movement(delta)

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
	var distance_3d = target_pos.distance_to(global_position)

	if distance_3d > chase_distance:
		# Too far, idle in place with bobbing
		pass
	elif distance_3d > attack_range:
		# Chase using flying movement (pursues in 3D through caves!)
		move_toward_target(delta, target_pos, fly_speed, false)  # Full 3D chase!
	else:
		# In attack range - hover and attack
		if _attack_timer <= 0:
			_perform_attack()
			_attack_timer = attack_cooldown


func _perform_attack():
	if _current_target == null:
		return

	var target_name = _current_target.get("entity_name") if _current_target.has_method("get") else "target"
	print("%s attacks %s for %d damage!" % [entity_name, target_name, attack_damage])

	# Actually damage the target (player OR companion)
	if _current_target.has_method("take_damage"):
		_current_target.take_damage(attack_damage, self)

	# Swap to attack sprite
	if _sprite:
		var attack_texture = load("res://assets/art/entities/rust_golem_attack.png")
		if attack_texture:
			_sprite.texture = attack_texture
			await get_tree().create_timer(0.3).timeout  # Quick mechanical attack
			if _sprite and is_alive:
				var ready_texture = load("res://assets/art/entities/rust_golem_ready.png")
				if ready_texture:
					_sprite.texture = ready_texture


func _on_death() -> void:
	"""Override death to add rust-specific effects"""
	super._on_death()

	# No loot drops from enemies currently
	# (Could spawn rust blocks in world here if desired)

	queue_free()
