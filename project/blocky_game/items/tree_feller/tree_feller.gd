extends "../item.gd"
## Tree Feller - Heavy axe weapon with cleaving slash
## Slower than sword but deals massive damage
## Can hit multiple targets in arc

const SERVER_PEER_ID = 1
const Meteor = preload("../../projectiles/meteor.gd")

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")

const MAX_TARGET_DISTANCE = 4.0  # Medium range
const DAMAGE = 35  # Highest melee damage
const ATTACK_SPEED = 1.0  # Slowest attack speed
const CLEAVE_ANGLE = 45.0  # Wide attack arc


func get_mining_power() -> int:
	return DAMAGE  # Best for mining (especially wood)


func use(trans: Transform3D, inv_item_or_count = 1):
	var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_use", trans, stack_count)
	else:
		_use(trans, inv_item_or_count)


func _use(trans: Transform3D, inv_item_or_count):
	var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count
	var origin = trans.origin
	var direction = -trans.basis.z.normalized()

	# Find ALL targets in cleave arc
	var target_entities = _find_targets_in_arc(origin, direction)

	if target_entities.size() > 0:
		# Hit all entities in arc
		for entity in target_entities:
			_cleave_attack(entity, origin, inv_item_or_count)

		# ⚡ SKYSHARD POWER: Wind Dash (activate once if any enemy hit)
		if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.has_power("wind_dash"):
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_method("activate_wind_dash"):
				player.activate_wind_dash()
	else:
		# Slash at air (show slash effect)
		var slash_pos = origin + direction * 2.0
		_spawn_slash_effect(slash_pos, direction)

	print("Tree Feller cleave! Hit %d targets | Stack bonus: +%d damage" % [target_entities.size(), stack_count])


func _find_targets_in_arc(origin: Vector3, direction: Vector3) -> Array:
	var targets = []
	var entities = get_tree().get_nodes_in_group("entities")

	for entity in entities:
		if not entity.is_alive:
			continue

		# Only attack enemies
		if entity.team != EntityBase.Team.ENEMY:
			continue

		# Check if entity is in range
		var to_entity = entity.global_position - origin
		var distance = to_entity.length()

		if distance > MAX_TARGET_DISTANCE:
			continue

		# Check if entity is in wide cleave arc
		var angle = direction.angle_to(to_entity.normalized())
		if angle <= deg_to_rad(CLEAVE_ANGLE / 2.0):  # Half angle on each side
			targets.append(entity)

	return targets


func _cleave_attack(entity: Node, attacker_pos: Vector3, inv_item_or_count):
	var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count

	# Deal damage with stack bonus
	var total_damage = DAMAGE + stack_count
	entity.take_damage(total_damage, self)

	# Spawn slash effect at entity position
	_spawn_slash_effect(entity.global_position, (entity.global_position - attacker_pos).normalized())

	print("Tree Feller hit %s for %d damage! (base: %d + stack: %d)" % [entity.entity_name, total_damage, DAMAGE, stack_count])

	# ⚡ SKYSHARD POWERS - Use centralized Powers system
	if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.skyshard_power != "":
		var power_context = {
			"entity": entity,
			"position": entity.global_position,
			"stack_count": stack_count,
			"damage_dealt": total_damage,
			"attacker": get_tree().get_first_node_in_group("player")
		}
		Powers.execute_hotbar_power(inv_item_or_count.skyshard_power, power_context)


func _lightning_chain(origin: Vector3, chain_damage: int, primary_target: Node):
	"""Chain lightning damage to nearby enemies"""
	const CHAIN_RADIUS = 5.0
	const MAX_CHAINS = 3

	var entities = get_tree().get_nodes_in_group("entities")
	var chained = 0

	for entity in entities:
		if chained >= MAX_CHAINS:
			break

		# Skip if not alive, not enemy, or is the primary target
		if not entity.is_alive or entity.team != EntityBase.Team.ENEMY or entity == primary_target:
			continue

		# Check if within chain radius
		var distance = entity.global_position.distance_to(origin)
		if distance <= CHAIN_RADIUS:
			entity.take_damage(chain_damage, self)
			chained += 1
			print("⚡ Lightning chained to %s for %d damage!" % [entity.entity_name, chain_damage])

	if chained > 0:
		print("⚡ Lightning Chain! Hit %d additional enemies" % chained)


func _spawn_slash_effect(pos: Vector3, direction: Vector3):
	# Create slash effect quad with shader
	var mesh_inst = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(3.0, 3.0)  # Largest slash (heavy axe)
	mesh_inst.mesh = quad

	# Load and configure slash shader
	var material = ShaderMaterial.new()
	material.shader = load("res://blocky_game/items/slash_effect.gdshader")

	# Create noise texture
	var noise_texture = NoiseTexture2D.new()
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_MANHATTAN
	noise.frequency = 0.05
	noise_texture.noise = noise
	noise_texture.seamless = true
	noise_texture.width = 512
	noise_texture.height = 128

	material.set_shader_parameter("base_noise", noise_texture)
	material.set_shader_parameter("slash_color", Color(0.6, 0.8, 0.4, 1.0))  # Green slash (woodsy)
	material.set_shader_parameter("emission_strength", 3.0)
	material.set_shader_parameter("time_scale", 3.0)  # Slow, heavy slash

	mesh_inst.material_override = material

	# Add to scene first (required before setting global_transform)
	get_node("/root/Main/Game").add_child(mesh_inst)

	# Position and orient the slash
	mesh_inst.global_position = pos + Vector3(0, 1.0, 0)  # Chest height

	# Orient slash diagonally - tilted 45 degrees, horizontal swing
	# The slash should sweep across horizontally, tilted like a sword slash
	var forward = direction.normalized()
	var right = forward.cross(Vector3.UP).normalized()
	if right.length() < 0.1:  # Handle vertical direction edge case
		right = Vector3.RIGHT

	# Tilt the slash 45 degrees (diagonal sword swing)
	var up_tilted = (Vector3.UP + right).normalized()
	var forward_adjusted = right.cross(up_tilted).normalized()

	mesh_inst.global_transform.basis = Basis(right, up_tilted, -forward_adjusted)

	# Auto-delete after animation
	await get_tree().create_timer(0.33).timeout  # Longest animation (heavy weapon)
	mesh_inst.queue_free()

@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, stack_count: int = 1):
	_use(trans, stack_count)
