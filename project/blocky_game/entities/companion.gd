extends GroundEntity
class_name Companion

## Companion - AI companion that follows player and assists in combat
## Based on CompanionManager settings (race/role)
## Attacks what player attacks, uses items based on role

## States
enum State {
	IDLE,
	FOLLOWING,
	ATTACKING
}

var _state: State = State.IDLE
var _player: Node3D = null
var _current_target: Node = null
var _attack_cooldown: float = 0.0
var _weapon_item: Node = null  # Reference to weapon item for attacking

## AI parameters
const FOLLOW_DISTANCE = 5.0  # Stay within this distance of player
const TELEPORT_DISTANCE = 30.0  # Teleport to player if beyond this distance
const ATTACK_RANGE = 40.0  # Attack enemies within this range (long for ranged weapons)
const MELEE_RANGE = 4.0  # Melee attack range
const ATTACK_COOLDOWN = 1.5  # Seconds between attacks
const MOVE_SPEED_MULTIPLIER = 1.0  # Matches movement_speed from base class

## Weapon reference (loaded from CompanionManager)
var weapon_path: String = ""
var weapon_name: String = ""
var is_ranged_weapon: bool = false
var _lightning_from_sky: bool = true  # Alternates for wizard lightning
var _last_equipped_weapon_id: int = -1  # Track equipped weapon changes


func _ready():
	super._ready()

	# Set up as friendly entity
	team = Team.PLAYER
	entity_name = CompanionManager.get_companion_name()

	# Apply stats from CompanionManager
	max_hp = CompanionManager.get_companion_max_hp()
	current_hp = max_hp
	defense = CompanionManager.get_companion_defense()
	attack_damage = CompanionManager.get_companion_attack_bonus()
	movement_speed = 4.0  # Base movement speed

	# Set collision box (similar to player)
	set_collision_box(Vector3(0.8, 1.6, 0.8))

	# Get sprite path based on race/gender
	var sprite_path = CompanionManager.get_avatar_path()
	if sprite_path != "":
		_create_sprite(sprite_path, 0.004)

	# Get weapon path and load weapon item
	weapon_path = CompanionManager.get_companion_weapon()
	_load_weapon()

	# Find player
	_find_player()

	# Connect to player's attack signal if available
	if _player and _player.has_signal("attacked_entity"):
		_player.attacked_entity.connect(_on_player_attacked)

	print("Companion spawned: %s %s (HP: %d, Def: %d%%, Atk: +%d)" % [
		CompanionManager.companion_race,
		CompanionManager.companion_role,
		max_hp,
		defense,
		attack_damage
	])


func _load_weapon():
	# Check if companion has an equipped weapon from inventory
	var inventory = get_node_or_null("/root/Main/Game/CharacterAvatar/Inventory")
	if inventory:
		var equipped_weapon_item = inventory.get_companion_equipped_weapon()
		print("Companion _load_weapon: equipped_weapon_item = ", equipped_weapon_item)
		if equipped_weapon_item != null:
			print("  - Found equipped weapon, ID: %d, Type: %d" % [equipped_weapon_item.id, equipped_weapon_item.type])
			# Use equipped weapon from inventory
			var item_db = get_node_or_null("/root/Main/Game/Items")
			if item_db:
				_weapon_item = item_db.get_item(equipped_weapon_item.id)
				if _weapon_item:
					weapon_name = _weapon_item.base_info.name
					# Determine if ranged based on weapon
					is_ranged_weapon = weapon_name in ["crossbow", "ice_bow", "fire_staff", "rocket_launcher", "throwing_knives"]
					print("Companion using equipped weapon: %s (ID: %d)" % [weapon_name, equipped_weapon_item.id])
					return
				else:
					print("  - ERROR: Could not get weapon from item_db!")
			else:
				print("  - ERROR: Could not find item_db!")
		else:
			print("  - No equipped weapon, using default")

	# Fallback to default weapon based on race
	var item_db = get_node_or_null("/root/Main/Game/Items")
	if not item_db:
		push_warning("Companion: Could not find item database")
		return

	# Map weapon path to weapon name
	match CompanionManager.companion_race:
		"dwarf":
			weapon_name = "stone_hammer"
			is_ranged_weapon = false
		"elf":
			weapon_name = "crossbow"  # or ice_bow
			is_ranged_weapon = true
		"goblin":
			if CompanionManager.companion_gender == "female":
				weapon_name = "throwing_knives"
				is_ranged_weapon = true
			else:
				weapon_name = "rocket_launcher"
				is_ranged_weapon = true
		"human":
			weapon_name = "machete"
			is_ranged_weapon = false

	# Find the weapon item by name
	for i in range(100):  # Assume max 100 items
		var item = item_db.get_item(i)
		if item and item.base_info.name == weapon_name:
			_weapon_item = item
			print("Companion loaded default weapon: %s (ID: %d)" % [weapon_name, i])
			return

	push_warning("Companion: Could not find weapon %s in database" % weapon_name)


func _find_player():
	# Find player in the "player" group
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]
		print("Companion found player: ", _player.name)
	else:
		push_warning("Companion: Could not find player!")


func _process(delta: float):
	if not is_alive:
		return

	# Check if equipped weapon changed
	_check_equipped_weapon()

	# Update attack cooldown
	if _attack_cooldown > 0:
		_attack_cooldown -= delta

	# Find player if we don't have one
	if _player == null:
		_find_player()
		return

	# Check if player is too far away and needs teleport
	var distance_to_player = global_position.distance_to(_player.global_position)
	if distance_to_player > TELEPORT_DISTANCE:
		# Only teleport if player is on the ground (check _grounded variable)
		if _player.get("_grounded") == true:
			_teleport_to_player()
			return

	# Determine state based on situation
	_update_state()

	# Act based on state
	match _state:
		State.IDLE:
			_handle_idle(delta)
		State.FOLLOWING:
			_handle_following(delta)
		State.ATTACKING:
			_handle_attacking(delta)


func _update_state():
	# Check if we have a target and can attack
	if _current_target != null and is_instance_valid(_current_target):
		if _current_target.is_alive:
			var distance = global_position.distance_to(_current_target.global_position)
			var attack_range = ATTACK_RANGE if is_ranged_weapon else MELEE_RANGE
			if distance <= attack_range:
				_state = State.ATTACKING
				return

	# Check distance to player
	var distance_to_player = global_position.distance_to(_player.global_position)
	if distance_to_player > FOLLOW_DISTANCE:
		_state = State.FOLLOWING
	else:
		_state = State.IDLE


func _handle_idle(delta: float):
	# Stand still, face player
	var velocity_input = Vector3.ZERO
	apply_ground_movement(delta, velocity_input)

	# Look for nearby enemies to auto-attack
	_look_for_threats()


func _handle_following(delta: float):
	# Move towards player
	var direction = (_player.global_position - global_position).normalized()
	direction.y = 0  # Don't move vertically

	var velocity_input = direction * movement_speed * MOVE_SPEED_MULTIPLIER
	apply_ground_movement(delta, velocity_input)


func _handle_attacking(delta: float):
	if _current_target == null or not is_instance_valid(_current_target) or not _current_target.is_alive:
		_current_target = null
		return

	var distance = global_position.distance_to(_current_target.global_position)
	var attack_range = ATTACK_RANGE if is_ranged_weapon else MELEE_RANGE

	# Move towards target if too far (for melee, or get closer for ranged)
	var optimal_range = attack_range * 0.7 if is_ranged_weapon else attack_range * 0.8
	if distance > optimal_range:
		var direction = (_current_target.global_position - global_position).normalized()
		direction.y = 0
		var velocity_input = direction * movement_speed * MOVE_SPEED_MULTIPLIER
		apply_ground_movement(delta, velocity_input)
	else:
		# Stop moving and perform actions
		apply_ground_movement(delta, Vector3.ZERO)

		# Action priority: Self-heal > Role action > Attack
		if _attack_cooldown <= 0:
			# 1. Check if we need to self-heal
			if _try_self_heal():
				_attack_cooldown = ATTACK_COOLDOWN
				return

			# 2. Try role-specific action
			if _try_role_action():
				_attack_cooldown = ATTACK_COOLDOWN
				return

			# 3. Default: Attack with weapon
			_attack_target()
			_attack_cooldown = ATTACK_COOLDOWN


func _attack_target():
	if _current_target == null or not _current_target.is_alive:
		return

	if _weapon_item == null:
		push_warning("Companion: No weapon loaded, cannot attack!")
		return

	# Create a transform facing the target
	var aim_direction = (_current_target.global_position - global_position).normalized()
	var attack_transform = Transform3D()
	attack_transform.origin = global_position + Vector3(0, 1.0, 0)  # Aim from chest height

	# Make the transform look in the direction of the target
	attack_transform = attack_transform.looking_at(global_position + aim_direction, Vector3.UP)

	# Use the weapon's use() method (just like player does)
	_weapon_item.use(attack_transform)

	print("%s uses %s against %s!" % [entity_name, weapon_name, _current_target.entity_name])


func _look_for_threats():
	# Auto-attack nearby enemies
	var enemies = get_tree().get_nodes_in_group("enemy_entities")
	var closest_enemy = null
	var attack_range = ATTACK_RANGE if is_ranged_weapon else MELEE_RANGE
	var closest_distance = attack_range

	for enemy in enemies:
		if not enemy.is_alive:
			continue

		var distance = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy

	if closest_enemy != null:
		_current_target = closest_enemy


func _on_player_attacked(entity: Node):
	# When player attacks, companion should also attack that target
	if entity != null and entity.is_alive and entity.team == Team.ENEMY:
		_current_target = entity
		print("%s will assist player against %s!" % [entity_name, entity.entity_name])


## Override to show companion death message
func _on_death():
	print("Companion %s has fallen!" % entity_name)
	super._on_death()

	# TODO: Emit signal to PartyUI to update companion status


## Take damage and emit signal for UI update
func take_damage(amount: int, from: Node = null) -> void:
	super.take_damage(amount, from)

	# Emit signal for PartyUI to update
	# TODO: Connect to PartyUI
	_update_party_ui()


## Heal and emit signal for UI update
func heal(amount: int) -> void:
	super.heal(amount)
	_update_party_ui()


func _update_party_ui():
	# Find PartyUI and update companion HP
	for child in get_tree().root.get_node("/root/Main/Game").get_children():
		if child.has_method("update_companion_hp"):
			child.update_companion_hp(current_hp, max_hp)
			return


func _teleport_to_player():
	"""Teleport companion to player when too far away"""
	if _player == null:
		return

	# Find a safe position near the player (on the ground)
	var teleport_pos = _player.global_position + Vector3(2, 0, 2)  # 2 blocks away

	# Find ground below that position
	var ground_pos = find_ground_position(teleport_pos + Vector3(0, 5, 0), 15.0)

	# Teleport
	global_position = ground_pos

	# Reset velocity to prevent falling through
	_velocity = Vector3.ZERO
	_grounded = true

	print("%s teleported to player (was too far away)" % entity_name)


## Role-based AI behaviors

func _try_self_heal() -> bool:
	"""Attempt to heal self if HP is below 15%"""
	var hp_percent = float(current_hp) / float(max_hp)

	if hp_percent < 0.15:
		# TODO: Use healing item from inventory when inventory system exists
		# For now, just heal directly
		var heal_amount = int(max_hp * 0.3)  # Heal 30% of max HP
		heal(heal_amount)
		print("%s used healing! (+%d HP)" % [entity_name, heal_amount])
		return true

	return false


func _try_role_action() -> bool:
	"""Execute role-specific action based on companion role"""
	match CompanionManager.companion_role:
		"tank":
			return _role_tank()
		"wizard":
			return _role_wizard()
		"healer":
			return _role_healer()
		"rogue":
			return _role_rogue()

	return false


func _role_tank() -> bool:
	"""Tank role: High defense, always aggressive, taunts enemies"""
	# Tanks don't have special actions, they just attack
	# Their value is in their high HP and defense stats
	return false  # Let it proceed to normal attack


func _role_wizard() -> bool:
	"""Wizard role: Casts lightning bolt at enemies"""
	if _current_target == null or not _current_target.is_alive:
		return false

	# 50% chance to cast lightning instead of normal attack
	if randf() > 0.5:
		_cast_lightning()
		return true

	return false  # Use normal weapon attack


func _cast_lightning():
	"""Cast lightning bolt at current target"""
	const LightningBolt = preload("res://blocky_game/effects/lightning_bolt.gd")

	var lightning = Node3D.new()
	lightning.set_script(LightningBolt)

	# Initialize BEFORE adding to tree so values are set when _ready() is called
	lightning.target_position = _current_target.global_position
	lightning.damage = 25
	lightning.from_sky = _lightning_from_sky
	lightning.caster_position = global_position

	# Add to game scene (this triggers _ready())
	get_node("/root/Main/Game").add_child(lightning)

	# Alternate for next cast
	_lightning_from_sky = not _lightning_from_sky

	print("%s cast lightning bolt! (from %s)" % [entity_name, "sky" if not _lightning_from_sky else "hand"])


func _role_healer() -> bool:
	"""Healer role: Heals player when they're low on health"""
	if _player == null:
		return false

	# Check if player needs healing (below 50% HP)
	var player_hp_percent = float(_player.current_hp) / float(_player.max_hp)

	if player_hp_percent < 0.5:
		# Heal the player
		var heal_amount = int(_player.max_hp * 0.2)  # Heal 20% of player's max HP
		_player.current_hp = min(_player.max_hp, _player.current_hp + heal_amount)

		# Emit player HP changed signal
		if _player.has_signal("hp_changed"):
			_player.hp_changed.emit(_player.current_hp, _player.max_hp)

		print("%s healed player! (+%d HP)" % [entity_name, heal_amount])

		# Spawn healing effect
		_spawn_heal_effect(_player.global_position)

		return true

	return false


func _role_rogue() -> bool:
	"""Rogue role: High damage, critical strikes"""
	# Rogues have a chance for critical hit (double damage)
	# This is handled in the normal attack, so no special action needed
	return false  # Let it proceed to normal attack


func _spawn_heal_effect(pos: Vector3):
	"""Create green healing particle effect"""
	var particles = GPUParticles3D.new()
	particles.position = pos + Vector3(0, 1.0, 0)
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 15
	particles.lifetime = 1.0
	particles.explosiveness = 0.8

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.5
	material.direction = Vector3(0, 1, 0)
	material.spread = 30.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 3.0
	material.gravity = Vector3(0, 2.0, 0)  # Float upward
	material.scale_min = 0.1
	material.scale_max = 0.3
	material.color = Color(0.2, 1.0, 0.3)  # Bright green

	particles.process_material = material

	# Add to scene
	get_node("/root/Main/Game").add_child(particles)

	# Auto-delete after lifetime
	await get_tree().create_timer(1.5).timeout
	particles.queue_free()


func _check_equipped_weapon():
	"""Check if equipped weapon changed and reload if needed"""
	var inventory = get_node_or_null("/root/Main/Game/CharacterAvatar/Inventory")
	if not inventory:
		return

	var equipped_weapon_item = inventory.get_companion_equipped_weapon()

	# Get current equipped weapon ID
	var current_id = -1
	if equipped_weapon_item != null:
		current_id = equipped_weapon_item.id

	# If weapon changed, reload
	if current_id != _last_equipped_weapon_id:
		print("Companion weapon changed from ID %d to ID %d - reloading" % [_last_equipped_weapon_id, current_id])
		_last_equipped_weapon_id = current_id
		_load_weapon()
