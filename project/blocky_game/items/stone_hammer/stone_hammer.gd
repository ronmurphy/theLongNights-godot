extends "../item.gd"
## Stone Hammer - AOE melee weapon with knockback
## Used by dwarf companions
## Deals damage in 3-block radius and knocks enemies back

const SERVER_PEER_ID = 1
const Meteor = preload("../../projectiles/meteor.gd")

@onready var _terrain : VoxelTerrain = get_node("/root/Main/Game/VoxelTerrain")

const MAX_TARGET_DISTANCE = 5.0  # Short range melee
const DAMAGE = 15
const KNOCKBACK_FORCE = 10.0
const AOE_RADIUS = 3.0


func get_mining_power() -> int:
	return DAMAGE  # Good for mining stone/ore


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

	# FIRST: Check for push_block voxels (before mining can happen!)
	if await _check_and_push_voxel(origin, direction):
		return  # Hit a push_block voxel, pushed it, done!

	# Raycast to find target position (ground or entity)
	var terrain_tool = _terrain.get_voxel_tool()
	terrain_tool.channel = VoxelBuffer.CHANNEL_TYPE
	var hit = terrain_tool.raycast(origin, direction, MAX_TARGET_DISTANCE)

	var impact_pos : Vector3
	if hit != null:
		# Hit the ground
		impact_pos = Vector3(hit.position)
	else:
		# Hit nothing, use position in front of player
		impact_pos = origin + direction * MAX_TARGET_DISTANCE

	# Create visual effects at impact
	_spawn_dust_particles(impact_pos)
	_spawn_impact_shockwave(impact_pos)

	# Damage and knockback entities in AOE with stack bonus
	var total_damage = DAMAGE + stack_count
	_damage_nearby_entities(impact_pos, AOE_RADIUS, total_damage, KNOCKBACK_FORCE, inv_item_or_count)

	# Push nearby push_blocks - GOLF CLUB STYLE!
	_push_nearby_blocks(impact_pos, AOE_RADIUS, KNOCKBACK_FORCE)

	print("Stone Hammer impact at: ", impact_pos, " | Stack bonus: +", stack_count, " damage")


func _spawn_dust_particles(pos: Vector3):
	# Create simple particle effect
	var particles = GPUParticles3D.new()
	particles.position = pos + Vector3(0, 0.5, 0)  # Slightly above ground
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 20
	particles.lifetime = 0.5
	particles.explosiveness = 1.0

	# Particle material
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 1.0
	material.direction = Vector3(0, 1, 0)
	material.spread = 45.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 5.0
	material.gravity = Vector3(0, -9.8, 0)
	material.scale_min = 0.1
	material.scale_max = 0.3
	material.color = Color(0.6, 0.5, 0.4)  # Dust/dirt color

	particles.process_material = material

	# Add to scene
	get_node("/root/Main/Game").add_child(particles)

	# Auto-delete after lifetime
	await get_tree().create_timer(1.0).timeout
	particles.queue_free()


func _spawn_impact_shockwave(pos: Vector3):
	# Create shockwave effect quad with shader
	var mesh_inst = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(AOE_RADIUS * 2.0, AOE_RADIUS * 2.0)  # Match AOE radius
	mesh_inst.mesh = quad

	# Load and configure impact shader
	var material = ShaderMaterial.new()
	material.shader = load("res://blocky_game/items/impact_effect.gdshader")

	# Create noise texture
	var noise_texture = NoiseTexture2D.new()
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.frequency = 0.1
	noise_texture.noise = noise
	noise_texture.seamless = true
	noise_texture.width = 256
	noise_texture.height = 256

	material.set_shader_parameter("base_noise", noise_texture)
	material.set_shader_parameter("impact_color", Color(0.8, 0.6, 0.4, 1.0))  # Dust/stone
	material.set_shader_parameter("emission_strength", 2.5)
	material.set_shader_parameter("time_scale", 3.0)
	material.set_shader_parameter("noise_scale", 2.0)

	mesh_inst.material_override = material

	# Add to scene first (required before setting global_position/rotation)
	get_node("/root/Main/Game").add_child(mesh_inst)

	# Position on ground, oriented horizontally
	mesh_inst.global_position = pos + Vector3(0, 0.1, 0)  # Slightly above ground

	# Rotate to be parallel with ground (facing up)
	mesh_inst.rotation.x = -PI / 2.0  # Rotate 90 degrees to face up

	# Auto-delete after animation
	await get_tree().create_timer(0.33).timeout
	mesh_inst.queue_free()


func _damage_nearby_entities(center: Vector3, radius: float, damage: int, knockback: float, inv_item_or_count = null):
	var entities = get_tree().get_nodes_in_group("entities")
	var total_heal = 0  # Track total healing for Life Steal
	var hit_entities = []  # Track entities hit for Powers system

	for entity in entities:
		if not entity.is_alive:
			continue

		# Check if entity is in AOE radius
		var distance = entity.global_position.distance_to(center)
		if distance > radius:
			continue

		# Don't hit friendly entities (only hit enemies)
		if entity.team != EntityBase.Team.ENEMY:
			continue

		# Deal damage
		entity.take_damage(damage, self)

		# Apply knockback
		var knockback_dir = (entity.global_position - center).normalized()
		knockback_dir.y = 0.3  # Slight upward force

		# Apply knockback force (if entity has velocity)
		if entity is GroundEntity:
			entity._velocity += knockback_dir * knockback

		print("Stone Hammer hit %s (distance: %.1f)" % [entity.entity_name, distance])

		# ⚡ SKYSHARD POWERS - Collect data for Powers system (called once after loop)
		hit_entities.append(entity)


	# ⚡ SKYSHARD POWERS - Execute power for each hit entity via Powers system
	if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.skyshard_power != "":
		for hit_entity in hit_entities:
			var power_context = {
				"entity": hit_entity,
				"position": hit_entity.global_position,
				"stack_count": damage,
				"damage_dealt": damage,
				"attacker": get_tree().get_first_node_in_group("player")
			}
			Powers.execute_hotbar_power(inv_item_or_count.skyshard_power, power_context)

	# Apply total healing (after all damage dealt)
	if total_heal > 0:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("heal"):
			player.heal(total_heal)
			print("💚 Life Steal (AOE)! Healed %d HP from multiple enemies" % total_heal)

	# ⚡ SKYSHARD POWER: Wind Dash (activate once if any enemy hit)
	if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.has_power("wind_dash"):
		var hit_count = 0
		for entity in entities:
			if entity.is_alive and entity.team == EntityBase.Team.ENEMY:
				var distance = entity.global_position.distance_to(center)
				if distance <= radius:
					hit_count += 1

		if hit_count > 0:
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_method("activate_wind_dash"):
				player.activate_wind_dash()

	# ⚡ SKYSHARD POWER: Lightning Chain (chain from impact center to enemies outside AOE)
	if typeof(inv_item_or_count) == TYPE_OBJECT and inv_item_or_count.has_power("lightning_chain"):
		_lightning_chain_aoe(center, radius, int(damage * 0.5))


func _push_nearby_blocks(center: Vector3, radius: float, knockback: float):
	"""Push push_blocks in AOE - GOLF CLUB STYLE!"""
	var push_blocks = get_tree().get_nodes_in_group("push_blocks")

	for block in push_blocks:
		if not is_instance_valid(block):
			continue

		# Check if block is in AOE radius
		var distance = block.global_position.distance_to(center)
		if distance > radius:
			continue

		# Calculate knockback direction (away from impact, with upward arc like golf)
		var knockback_dir = (block.global_position - center).normalized()
		knockback_dir.y = 0.5  # Strong upward arc - FORE!

		# Apply strong impulse (stone hammer hits HARD!)
		var impulse = knockback_dir * knockback
		if block.has_method("apply_impulse"):
			block.apply_impulse(impulse)
			print("🔨⛳ Stone Hammer GOLF SWING! Block launched %.1f units away!" % distance)


func _check_and_push_voxel(origin: Vector3, direction: Vector3) -> bool:
	"""Check if we're hitting a push_block voxel and push it with GOLF SWING! Returns true if we hit one."""
	if not _terrain:
		return false

	var vt = _terrain.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	# Raycast to find what we're hitting
	var hit = vt.raycast(origin, direction, MAX_TARGET_DISTANCE)
	if not hit:
		return false

	var hit_pos = Vector3(hit.position)

	# Check if it's a push_block voxel
	var voxel_coord = Vector3i(
		int(floor(hit_pos.x)),
		int(floor(hit_pos.y)),
		int(floor(hit_pos.z))
	)
	var voxel_id = vt.get_voxel(voxel_coord)
	if voxel_id == 0:
		return false

	# Check if this voxel is a push_block
	var blocks_node = get_node_or_null("/root/Main/Game/Blocks")
	if not blocks_node:
		return false

	var raw_mapping = blocks_node.get_raw_mapping(voxel_id)
	if not raw_mapping:
		return false

	var block = blocks_node.get_block(raw_mapping.block_id)
	if not block or block.base_info.name != "push_block":
		return false

	# It's a push_block! Spawn entity and push it with GOLF SWING!
	var manager = get_node_or_null("/root/Main/Game/PushBlockManager")
	if not manager or not manager.has_method("create_push_block_at"):
		return false

	manager.create_push_block_at(voxel_coord)

	# Wait a frame for entity to spawn, then push it
	await get_tree().process_frame

	# Find the spawned entity
	var push_blocks = get_tree().get_nodes_in_group("push_blocks")
	for push_block in push_blocks:
		if not is_instance_valid(push_block):
			continue

		var block_voxel_pos = Vector3i(
			int(floor(push_block.global_position.x)),
			int(floor(push_block.global_position.y)),
			int(floor(push_block.global_position.z))
		)

		if block_voxel_pos == voxel_coord:
			# Found it! GOLF SWING!
			var knockback_dir = direction
			knockback_dir.y = 0.5  # Strong upward arc - FORE!
			var impulse = knockback_dir * KNOCKBACK_FORCE  # 10.0 force

			if push_block.has_method("apply_impulse"):
				push_block.apply_impulse(impulse)
				print("🔨⛳ Stone Hammer GOLF SWING on push_block voxel! (10.0 force)")

			return true

	return false


func _lightning_chain_aoe(center: Vector3, aoe_radius: float, chain_damage: int):
	"""Chain lightning to enemies OUTSIDE the AOE (extends reach)"""
	const CHAIN_RADIUS = 8.0  # Longer than single-target version
	const MAX_CHAINS = 3

	var entities = get_tree().get_nodes_in_group("entities")
	var chained = 0

	for entity in entities:
		if chained >= MAX_CHAINS:
			break

		# Skip if not alive or not enemy
		if not entity.is_alive or entity.team != EntityBase.Team.ENEMY:
			continue

		var distance = entity.global_position.distance_to(center)

		# Only chain to enemies OUTSIDE the AOE radius but within chain radius
		if distance > aoe_radius and distance <= CHAIN_RADIUS:
			entity.take_damage(chain_damage, self)
			chained += 1
			print("⚡ Lightning chained to %s (distance: %.1f)" % [entity.entity_name, distance])

	if chained > 0:
		print("⚡ Lightning Chain (AOE)! Hit %d enemies outside hammer radius" % chained)


@rpc("any_peer", "call_remote", "reliable", 0)
func receive_use(trans: Transform3D, stack_count: int = 1):
	_use(trans, stack_count)
