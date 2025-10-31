extends "../item.gd"
## Sword - Balanced melee weapon with powerful slash attack
## Higher damage than machete, slightly slower
## Deals single-target damage with medium attack speed

const SERVER_PEER_ID = 1

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")

const MAX_TARGET_DISTANCE = 4.5  # Slightly longer reach than machete
const DAMAGE = 30  # Higher damage than machete
const ATTACK_SPEED = 0.75  # Slower than machete


func get_mining_power() -> int:
	return DAMAGE  # Good for mining


func use(trans: Transform3D):
	var mp := get_tree().get_multiplayer()
	if mp.has_multiplayer_peer() and not mp.is_server():
		rpc_id(SERVER_PEER_ID, &"receive_use", trans)
	else:
		_use(trans)


func _use(trans: Transform3D):
	var origin = trans.origin
	var direction = -trans.basis.z.normalized()

	# Find target entity with raycast
	var target_entity = _find_target_entity(origin, direction)

	if target_entity:
		# Direct hit on entity
		_slash_attack(target_entity, origin)
	else:
		# Slash at air (show slash effect)
		var slash_pos = origin + direction * 2.5
		_spawn_slash_effect(slash_pos, direction)

	print("Sword slash!")


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


func _slash_attack(entity: Node, attacker_pos: Vector3):
	# Deal damage
	entity.take_damage(DAMAGE, self)

	# Spawn slash effect at entity position
	_spawn_slash_effect(entity.global_position, (entity.global_position - attacker_pos).normalized())

	print("Sword hit %s for %d damage!" % [entity.entity_name, DAMAGE])


func _spawn_slash_effect(pos: Vector3, direction: Vector3):
	# Create slash effect quad with shader
	var mesh_inst = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(2.5, 2.5)  # Larger slash than machete
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
	material.set_shader_parameter("slash_color", Color(1.0, 0.9, 0.7, 1.0))  # Golden slash
	material.set_shader_parameter("emission_strength", 2.5)
	material.set_shader_parameter("time_scale", 3.5)  # Slightly slower, heavier slash

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
	await get_tree().create_timer(0.28).timeout  # Slightly longer animation
	mesh_inst.queue_free()


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D):
	_use(trans)
