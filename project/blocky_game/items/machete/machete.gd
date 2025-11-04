extends "../item.gd"
## Machete - Fast melee weapon with slash attack
## Used by human companions
## Deals single-target damage with quick attack speed

const SERVER_PEER_ID = 1
const Meteor = preload("../../projectiles/meteor.gd")

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")

const MAX_TARGET_DISTANCE = 4.0  # Medium melee range
const DAMAGE = 20  # Higher single-target damage than hammer
const ATTACK_SPEED = 0.5  # Fast attack (cooldown in seconds)


func get_mining_power() -> int:
	return DAMAGE  # Decent for mining


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

	# Find target entity with raycast
	var target_entity = _find_target_entity(origin, direction)

	if target_entity:
		# Direct hit on entity
		_slash_attack(target_entity, origin, inv_item_or_count)
	else:
		# Slash at air (show slash effect)
		var slash_pos = origin + direction * 2.0
		_spawn_slash_effect(slash_pos, direction)

	print("Machete slash! Stack bonus: +", stack_count, " damage")


func _find_target_entity(origin: Vector3, direction: Vector3) -> Node:
	# Raycast to find entities in attack direction
	var space_state = get_tree().root.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * MAX_TARGET_DISTANCE
	)

	var result = space_state.intersect_ray(query)
	if result:
		return result.collider

	# If no physics hit, check entities manually
	var entities = get_tree().get_nodes_in_group("entities")
	var closest_entity = null
	var closest_distance = MAX_TARGET_DISTANCE

	for entity in entities:
		if not entity.is_alive:
			continue

		# Check if entity is roughly in front of player
		var to_entity = entity.global_position - origin
		var distance = to_entity.length()

		if distance > MAX_TARGET_DISTANCE:
			continue

		# Check if entity is in attack cone (60 degree arc)
		var angle = direction.angle_to(to_entity.normalized())
		if angle > deg_to_rad(30):  # 30 degrees each side = 60 degree cone
			continue

		# Only attack enemies
		if entity.team != EntityBase.Team.ENEMY:
			continue

		if distance < closest_distance:
			closest_distance = distance
			closest_entity = entity

	return closest_entity


func _slash_attack(entity: Node, attacker_pos: Vector3, inv_item_or_count):
	var stack_count = inv_item_or_count.count if typeof(inv_item_or_count) == TYPE_OBJECT else inv_item_or_count

	# Deal damage with stack bonus
	var total_damage = DAMAGE + stack_count
	entity.take_damage(total_damage, self)

	# Spawn slash effect at entity position
	_spawn_slash_effect(entity.global_position, (entity.global_position - attacker_pos).normalized())

	print("Machete hit %s for %d damage!" % [entity.entity_name, total_damage])

	# ⚡ SKYSHARD POWER: Life Steal
	if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.skyshard_power == "life_steal":
		var heal_amount = int(total_damage * 0.25)  # 25% of damage dealt
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("heal"):
			player.heal(heal_amount)
			print("💚 Life Steal! Healed %d HP" % heal_amount)

	# ⚡ SKYSHARD POWER: Meteor Strike
	if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.skyshard_power == "meteor_strike":
		var target_pos = entity.global_position
		var sky_pos = Vector3(target_pos.x, target_pos.y + 50.0, target_pos.z)
		_spawn_meteor(sky_pos, target_pos, stack_count)
		print("☄️ Meteor Strike! Calling down meteor on %s" % entity.entity_name)

	# ⚡ SKYSHARD POWER: Wind Dash
	if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.skyshard_power == "wind_dash":
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("activate_wind_dash"):
			player.activate_wind_dash()

	# ⚡ SKYSHARD POWER: Lightning Chain
	if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.skyshard_power == "lightning_chain":
		_lightning_chain(entity.global_position, int(total_damage * 0.5), entity)


func _spawn_slash_effect(pos: Vector3, direction: Vector3):
	# Create slash effect quad with shader
	var mesh_inst = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)  # 2x2 meter slash
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
	material.set_shader_parameter("slash_color", Color(0.8, 0.9, 1.0, 1.0))  # Light blue/white
	material.set_shader_parameter("emission_strength", 2.0)
	material.set_shader_parameter("time_scale", 4.0)  # Fast slash

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
	await get_tree().create_timer(0.25).timeout  # Short slash animation
	mesh_inst.queue_free()


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


func _spawn_meteor(sky_pos: Vector3, target_pos: Vector3, stack_count: int):
	"""Spawn a meteor for Meteor Strike power"""
	var meteor = Node3D.new()
	meteor.set_script(Meteor)
	var game_node = get_node("/root/Main/Game")
	game_node.add_child(meteor)
	meteor.initialize(sky_pos, target_pos, stack_count)


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, stack_count: int = 1):
	_use(trans, stack_count)
