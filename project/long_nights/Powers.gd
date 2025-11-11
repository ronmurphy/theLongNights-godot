extends Node
## Powers.gd - Centralized Skyshard Power System
## Handles all HOTBAR power effects (triggered on attack/hit)
## 
## EQUIP powers (passive buffs) are handled in character_controller.gd:
##   - stone_skin: Defense multiplier (character_controller.gd ~line 364)
##   - moon_jump: Jump multiplier (character_controller.gd ~line 186)
##   - flame_aura: Burn nearby enemies (character_controller.gd ~line 403)
##
## Autoload singleton for easy access from any weapon/projectile

const Meteor = preload("res://blocky_game/projectiles/meteor.gd")
const EntityBase = preload("res://blocky_game/entities/entity_base.gd")
const ThrowingKnife = preload("res://blocky_game/projectiles/throwing_knife.gd")


## Execute a HOTBAR power (triggered on attack/hit)
## Context should contain: entity, position, stack_count, damage_dealt, attacker
func execute_hotbar_power(power_name: String, context: Dictionary) -> void:
	match power_name:
		"meteor_strike":
			_power_meteor_strike(context)
		"lightning_chain":
			_power_lightning_chain(context)
		"life_steal":
			_power_life_steal(context)
		"ice_burst":
			_power_ice_burst(context)
		"poison_cloud":
			_power_poison_cloud(context)
		"knife_volley":
			_power_knife_volley(context)
		"wind_dash":
			_power_wind_dash(context)
		"return":
			_power_return(context)
		_:
			print("WARNING: Unknown HOTBAR power: ", power_name)


## Get EQUIP power buffs (passive effects)
## Returns dictionary with multipliers/bonuses
## NOTE: EQUIP powers are actually implemented in character_controller.gd
## This function is provided for reference/documentation only
func get_equip_buffs(power_name: String) -> Dictionary:
	match power_name:
		"stone_skin":
			return {"defense_mult": 1.5, "name": "Stone Skin", "location": "character_controller.gd ~line 364"}
		"moon_jump":
			return {"jump_mult": 3.0, "name": "Moon Jump", "location": "character_controller.gd ~line 186"}
		"flame_aura":
			return {"has_flame_aura": true, "name": "Flame Aura", "location": "character_controller.gd ~line 403"}
		_:
			if power_name == "glide":
				return {"fall_speed": -4.0, "turn_speed": 0.3, "name": "Glide", "location": "character_controller.gd"}
			return {}


## ============================================================================
## HOTBAR POWER IMPLEMENTATIONS
## ============================================================================

func _power_meteor_strike(ctx: Dictionary) -> void:
	"""Summons a SWARM of mini-meteors in an X pattern"""
	if not ctx.has("position"):
		print("ERROR: meteor_strike missing 'position' in context")
		return
	
	var center_pos: Vector3 = ctx.position
	var stack_count = ctx.get("stack_count", 0)
	var attacker = ctx.get("attacker", null)
	
	# Get game node to add meteors to scene
	var game_node = get_node_or_null("/root/Main/Game")
	if not game_node:
		print("ERROR: Could not find /root/Main/Game node for meteor swarm!")
		return
	
	print("☄️ Meteor Swarm! Raining fire at: ", center_pos)
	
	# Spawn 5 mini-meteors in X pattern
	# Pattern offsets from center (3 blocks apart for overlap)
	var swarm_offsets = [
		Vector3(0, 0, 0),      # Center
		Vector3(3, 0, -3),     # NE
		Vector3(-3, 0, -3),    # NW
		Vector3(3, 0, 3),      # SE
		Vector3(-3, 0, 3),     # SW
	]
	
	var delay = 0.0
	for offset in swarm_offsets:
		var target = center_pos + offset
		# Stagger the meteors slightly for visual effect
		get_tree().create_timer(delay).timeout.connect(
			func(): _spawn_mini_meteor(game_node, target, stack_count, attacker)
		)
		delay += 0.1  # 0.1 second between each meteor


func _power_lightning_chain(ctx: Dictionary) -> void:
	"""Chains lightning damage to nearby enemies"""
	if not ctx.has("position") or not ctx.has("entity"):
		print("ERROR: lightning_chain missing required context")
		return
	
	var origin: Vector3 = ctx.position
	var primary_target: Node = ctx.entity
	var chain_damage = ctx.get("damage_dealt", 20)
	var stack_count = ctx.get("stack_count", 1)
	
	const CHAIN_RADIUS = 5.0
	const MAX_CHAINS = 3
	
	print("⚡ Lightning Chain - origin:", origin, " damage:", chain_damage, " primary:", primary_target.entity_name)
	
	var entities = get_tree().get_nodes_in_group("entities")
	
	var chained_targets = []
	var last_position = origin  # Track position for chaining visuals
	
	var chained_count = 0
	for entity in entities:
		if chained_count >= MAX_CHAINS:
			break
		
		if not is_instance_valid(entity) or not entity.is_alive:
			continue
		
		# Skip the primary target
		if entity == primary_target:
			continue
		
		# Only chain to enemies
		if entity.team != EntityBase.Team.ENEMY:
			continue
		
		# Check distance from LAST position (creates chain effect)
		var distance = last_position.distance_to(entity.global_position)
		if distance <= CHAIN_RADIUS:
			# Chain lightning to this enemy
			var attacker = ctx.get("attacker", null)
			entity.take_damage(chain_damage + stack_count, attacker)
			
			# Store for visual chaining
			chained_targets.append({
				"from": last_position,
				"to": entity.global_position,
				"entity_name": entity.entity_name
			})
			
			last_position = entity.global_position  # Next chain starts from this enemy
			print("⚡ Lightning chained to %s for %d damage (distance: %.1f)!" % [entity.entity_name, chain_damage + stack_count, distance])
			chained_count += 1
	
	# Spawn lightning bolt visuals between all chained targets
	if chained_targets.size() > 0:
		_spawn_chain_lightning_visuals(chained_targets)

func _power_life_steal(ctx: Dictionary) -> void:
	"""Heals attacker for 25% of damage dealt"""
	if not ctx.has("damage_dealt"):
		print("ERROR: life_steal missing 'damage_dealt' in context")
		return
	
	var heal_amount = int(ctx.damage_dealt * 0.25)
	
	# Try to get player from attacker context
	var player = ctx.get("attacker", null)
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	if player and player.has_method("heal"):
		player.heal(heal_amount)
		print("💚 Life Steal! Healed %d HP" % heal_amount)
	else:
		print("WARNING: Could not find player to heal for life_steal")


func _power_ice_burst(ctx: Dictionary) -> void:
	"""Freezes enemies in radius and creates ice terrain"""
	if not ctx.has("position"):
		print("ERROR: ice_burst missing 'position' in context")
		return
	
	var center: Vector3 = ctx.position
	var stack_count = ctx.get("stack_count", 1)
	
	const ICE_RADIUS = 3.0  # Larger than ice arrow (1.5)
	const ICE_DAMAGE = 15
	const ICE_VOXEL_ID = 47  # Ice block
	
	print("❄️ Ice Burst! Freezing area at: ", center)
	
	# Get terrain to create ice blocks
	var terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")
	if terrain:
		var vt = terrain.get_voxel_tool()
		vt.channel = VoxelBuffer.CHANNEL_TYPE
		
		# Create ice blocks in radius (larger than ice arrow)
		var radius_int = int(ICE_RADIUS)
		for x in range(-radius_int, radius_int + 1):
			for y in range(-radius_int, radius_int + 1):
				for z in range(-radius_int, radius_int + 1):
					var offset = Vector3(x, y, z)
					if offset.length() <= ICE_RADIUS:
						var block_pos = center + offset
						# Only freeze non-air blocks
						var current_voxel = vt.get_voxel(block_pos)
						if current_voxel != 0:  # Don't freeze air
							vt.set_voxel(block_pos, ICE_VOXEL_ID)
	
	# Damage and slow nearby enemies
	var entities = get_tree().get_nodes_in_group("entities")
	var frozen_count = 0
	
	for entity in entities:
		if not is_instance_valid(entity) or not entity.is_alive:
			continue
		
		# Only affect enemies
		if entity.team != EntityBase.Team.ENEMY:
			continue
		
		var distance = center.distance_to(entity.global_position)
		if distance <= ICE_RADIUS:
			# Scale damage with distance
			var scaled_damage = int((ICE_DAMAGE + stack_count) * (1.0 - (distance / ICE_RADIUS)))
			var attacker = ctx.get("attacker", null)
			entity.take_damage(scaled_damage, attacker)
			
			# TODO: Add "frozen" status effect to slow enemy movement
			# For now, just damage
			
			print("❄️ Ice Burst froze %s for %d damage (distance: %.1f)" % [entity.entity_name, scaled_damage, distance])
			frozen_count += 1
	
	if frozen_count > 0:
		print("❄️ Ice Burst! Froze %d enemies" % frozen_count)
	
	# Spawn ice burst visual effect
	_spawn_ice_burst_effect(center)


func _power_poison_cloud(ctx: Dictionary) -> void:
	"""Spawns a lingering poison cloud that damages enemies over time"""
	var center: Vector3 = ctx.get("position", Vector3.ZERO)
	var stack_count: int = ctx.get("stack_count", 0)
	var attacker = ctx.get("attacker", null)
	
	# Get game node to spawn the poison cloud
	var game_node = get_node_or_null("/root/Main/Game")
	if not game_node:
		print("WARNING: Could not find Game node for poison cloud")
		return
	
	print("☠️ Poison Cloud! Spawning deadly gas at: ", center)
	
	# Create the poison cloud area
	_spawn_poison_cloud(game_node, center, stack_count, attacker)


func _power_knife_volley(ctx: Dictionary) -> void:
	"""Launches 3 knives toward nearby enemies"""
	if not ctx.has("position") or not ctx.has("entity"):
		print("ERROR: knife_volley missing required context")
		return
	
	var origin: Vector3 = ctx.position
	var primary_target: Node = ctx.entity
	var attacker = ctx.get("attacker", null)
	var stack_count = ctx.get("stack_count", 1)
	
	const VOLLEY_RADIUS = 10.0  # Search radius for targets
	const MAX_KNIVES = 3
	
	print("🔪 Knife Volley! Launching knives from: ", origin)
	
	# Find nearby enemies to target
	var entities = get_tree().get_nodes_in_group("entities")
	var targets = []
	
	for entity in entities:
		if not is_instance_valid(entity) or not entity.is_alive:
			continue
		
		# Only target enemies
		if entity.team != EntityBase.Team.ENEMY:
			continue
		
		# Check distance
		var distance = origin.distance_to(entity.global_position)
		if distance <= VOLLEY_RADIUS:
			targets.append(entity)
	
	# Limit to 3 targets
	if targets.size() > MAX_KNIVES:
		targets.resize(MAX_KNIVES)
	
	# If no targets found, just throw knives in a spread forward
	if targets.size() == 0:
		print("🔪 No targets found - throwing knives in spread pattern")
		_spawn_knife_spread(origin, primary_target.global_position, attacker, stack_count)
		return
	
	# Spawn a knife for each target
	var game_node = get_node_or_null("/root/Main/Game")
	if not game_node:
		print("ERROR: Could not find /root/Main/Game for knife volley")
		return
	
	for target in targets:
		var knife = Node3D.new()
		knife.set_script(ThrowingKnife)
		game_node.add_child(knife)
		
		# Initialize knife in DIRECT SHOT mode (no spiraling)
		knife.initialize(origin, target.global_position, stack_count, attacker, null, true)
		print("🔪 Volley knife targeting: %s" % target.entity_name)
	
	print("🔪 Knife Volley! Launched %d knives" % targets.size())


func _spawn_knife_spread(origin: Vector3, forward_pos: Vector3, attacker: Node, stack_count: int) -> void:
	"""Spawn 3 knives in a spread pattern when no targets available"""
	var game_node = get_node_or_null("/root/Main/Game")
	if not game_node:
		return
	
	var forward_dir = (forward_pos - origin).normalized()
	var right_dir = forward_dir.cross(Vector3.UP).normalized()
	
	# Spawn 3 knives: center, left, right
	var offsets = [
		Vector3.ZERO,  # Center
		right_dir * -3.0,  # Left
		right_dir * 3.0   # Right
	]
	
	for offset in offsets:
		var target_pos = forward_pos + offset + Vector3(0, randf_range(-2, 2), 0)
		
		var knife = Node3D.new()
		knife.set_script(ThrowingKnife)
		game_node.add_child(knife)
		# Spread pattern also uses direct shot mode
		knife.initialize(origin, target_pos, stack_count, attacker, null, true)


func _power_wind_dash(ctx: Dictionary) -> void:
	"""Speed boost for 3s after hitting enemy"""
	var attacker = ctx.get("attacker", null)

	# Try to get player from attacker context
	if not attacker:
		attacker = get_tree().get_first_node_in_group("player")

	if not attacker:
		print("WARNING: wind_dash could not find player")
		return

	# Check if player has the activate_wind_dash method
	if attacker.has_method("activate_wind_dash"):
		attacker.activate_wind_dash()
		print("💨 Wind Dash! Speed boost activated for 3 seconds")
	else:
		print("WARNING: Player does not have activate_wind_dash method")


func _power_return(ctx: Dictionary) -> void:
	"""Retrieval power - allows projectiles to be recovered after hitting entities"""
	# Context: entity, position, stack_count, damage_dealt, attacker
	# This is called when a projectile hits an entity with Return power equipped

	var attacker = ctx.get("attacker", null)

	if not attacker:
		attacker = get_tree().get_first_node_in_group("player")

	if not attacker:
		print("WARNING: return power could not find attacker")
		return

	# The projectile that triggered this is not directly available in context
	# Instead, we mark it for retrieval by tagging it so avatar_interaction.gd
	# can find and retrieve it when right-clicked

	# For automatic retrieval on entity hit, we'll set a flag on the projectile itself
	# This will be handled when the projectile calls this power

	print("✨ Return power triggered! Projectile eligible for retrieval")


## ============================================================================
## VISUAL EFFECT HELPERS
## ============================================================================

func _spawn_ice_burst_effect(pos: Vector3) -> void:
	"""Create ice explosion visual effect"""
	var game_node = get_node_or_null("/root/Main/Game")
	if not game_node:
		return
	
	# Spawn multiple ice crystal particles flying outward
	for i in range(20):
		var particle = MeshInstance3D.new()
		var crystal = BoxMesh.new()
		crystal.size = Vector3(0.15, 0.2, 0.15)
		particle.mesh = crystal
		
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(0.6, 0.9, 1.0, 0.8)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.emission_enabled = true
		material.emission = Color(0.7, 1.0, 1.0)
		material.emission_energy_multiplier = 4.0
		particle.material_override = material
		
		game_node.add_child(particle)
		particle.global_position = pos
		particle.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		
		# Random direction for each crystal
		var direction = Vector3(
			randf_range(-1, 1),
			randf_range(0, 1),
			randf_range(-1, 1)
		).normalized()
		
		# Animate crystal flying outward and fading
		var tween = get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", pos + direction * 4.0, 0.6)
		tween.tween_property(particle, "scale", Vector3.ZERO, 0.6)
		tween.tween_callback(particle.queue_free)


func _spawn_mini_meteor(game_node: Node, target: Vector3, stack_count: int, attacker) -> void:
	"""Spawns a single mini-meteor that falls and explodes in a small radius"""
	const MINI_METEOR_DAMAGE = 3  # Base damage per mini-meteor
	const MINI_METEOR_RADIUS = 1.5  # Small AOE radius
	const FALL_HEIGHT = 20.0  # Lower spawn height for faster impact
	
	# Create meteor node
	var meteor = Node3D.new()
	meteor.name = "MiniMeteor"
	var sky_pos = Vector3(target.x, target.y + FALL_HEIGHT, target.z)
	meteor.position = sky_pos
	game_node.add_child(meteor)
	
	# Visual: Glowing orange/red sphere
	var mesh_instance = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.3  # Small meteor
	sphere.height = 0.6
	mesh_instance.mesh = sphere
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.4, 0.1)  # Orange
	material.emission_enabled = true
	material.emission = Color(1.0, 0.5, 0.0)  # Bright orange glow
	material.emission_energy_multiplier = 8.0
	mesh_instance.material_override = material
	meteor.add_child(mesh_instance)
	
	# Add trail particles
	var trail = GPUParticles3D.new()
	trail.emitting = true
	trail.amount = 15
	trail.lifetime = 0.5
	trail.one_shot = false
	
	var trail_mat = ParticleProcessMaterial.new()
	trail_mat.direction = Vector3(0, 1, 0)  # Upward trail as it falls
	trail_mat.spread = 20.0
	trail_mat.initial_velocity_min = 2.0
	trail_mat.initial_velocity_max = 4.0
	trail_mat.gravity = Vector3.ZERO
	trail_mat.scale_min = 0.05
	trail_mat.scale_max = 0.15
	trail_mat.color = Color(1.0, 0.6, 0.1, 0.8)
	trail.process_material = trail_mat
	
	var trail_mesh = QuadMesh.new()
	trail.draw_pass_1 = trail_mesh
	
	var trail_shader_mat = StandardMaterial3D.new()
	trail_shader_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_shader_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_shader_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	trail_shader_mat.albedo_color = Color(1.0, 0.5, 0.1, 0.6)
	trail.material_override = trail_shader_mat
	meteor.add_child(trail)
	
	# Animate falling
	var fall_duration = 0.4  # Fast fall
	var tween = get_tree().create_tween()
	tween.tween_property(meteor, "position", target, fall_duration)
	tween.tween_callback(func(): _mini_meteor_impact(meteor, target, stack_count, attacker))


func _mini_meteor_impact(meteor: Node3D, impact_pos: Vector3, stack_count: int, attacker) -> void:
	"""Handle mini-meteor impact - damage and visual effect"""
	const MINI_METEOR_DAMAGE = 3
	const MINI_METEOR_RADIUS = 1.5
	
	# Stop trail
	for child in meteor.get_children():
		if child is GPUParticles3D:
			child.emitting = false
	
	# Find and damage entities in small radius
	var entities_hit = _find_entities_in_radius(impact_pos, MINI_METEOR_RADIUS)
	var damage = MINI_METEOR_DAMAGE + stack_count
	
	for entity in entities_hit:
		if entity and is_instance_valid(entity):
			entity.take_damage(damage, attacker)
	
	if entities_hit.size() > 0:
		print("  ☄️ Mini-meteor hit %d enemies for %d damage" % [entities_hit.size(), damage])
	
	# Impact visual effect
	_spawn_mini_meteor_explosion(meteor, impact_pos)
	
	# Cleanup after explosion animation
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(meteor):
		meteor.queue_free()


func _spawn_mini_meteor_explosion(meteor: Node3D, pos: Vector3) -> void:
	"""Small explosion effect for mini-meteors"""
	# Flash the meteor bright
	for child in meteor.get_children():
		if child is MeshInstance3D:
			var mat = child.material_override as StandardMaterial3D
			if mat:
				var tween = get_tree().create_tween()
				tween.tween_property(mat, "emission_energy_multiplier", 20.0, 0.1)
				tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.3)
	
	# Small explosion particles
	var explosion = GPUParticles3D.new()
	explosion.emitting = true
	explosion.amount = 10
	explosion.lifetime = 0.5
	explosion.one_shot = true
	explosion.explosiveness = 0.9
	meteor.add_child(explosion)
	
	var exp_mat = ParticleProcessMaterial.new()
	exp_mat.direction = Vector3(0, 1, 0)
	exp_mat.spread = 180.0
	exp_mat.initial_velocity_min = 3.0
	exp_mat.initial_velocity_max = 6.0
	exp_mat.gravity = Vector3(0, -5.0, 0)
	exp_mat.scale_min = 0.1
	exp_mat.scale_max = 0.3
	exp_mat.color = Color(1.0, 0.5, 0.0, 0.8)
	explosion.process_material = exp_mat
	
	var exp_mesh = QuadMesh.new()
	explosion.draw_pass_1 = exp_mesh
	
	var exp_shader_mat = StandardMaterial3D.new()
	exp_shader_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	exp_shader_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	exp_shader_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	exp_shader_mat.albedo_color = Color(1.0, 0.4, 0.0, 0.7)
	explosion.material_override = exp_shader_mat
	
	# Small light flash
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.0)
	light.light_energy = 3.0
	light.omni_range = 3.0
	meteor.add_child(light)
	
	var light_tween = get_tree().create_tween()
	light_tween.tween_property(light, "light_energy", 0.0, 0.4)


func _spawn_chain_lightning_visuals(chain_data: Array) -> void:
	"""Spawn lightning bolt visuals between chained enemies"""
	const LightningBolt = preload("res://blocky_game/effects/lightning_bolt.gd")
	
	var game_node = get_node_or_null("/root/Main/Game")
	if not game_node:
		print("WARNING: Could not find Game node for lightning visuals")
		return
	
	# Spawn a lightning bolt for each chain link with slight delay
	var delay = 0.0
	for link in chain_data:
		get_tree().create_timer(delay).timeout.connect(
			func(): _spawn_single_lightning_arc(game_node, link["from"], link["to"])
		)
		delay += 0.05  # Stagger each arc slightly
	
	print("⚡ Lightning Chain! Spawned %d electric arcs" % chain_data.size())


func _spawn_single_lightning_arc(game_node: Node, start: Vector3, end: Vector3) -> void:
	"""Spawn a single lightning arc between two points"""
	const LightningBolt = preload("res://blocky_game/effects/lightning_bolt.gd")
	
	# Create lightning bolt node
	var bolt = Node3D.new()
	bolt.set_script(LightningBolt)
	
	# Make it horizontal (from one enemy to another)
	# We'll create our own simpler arc since the existing one expects sky/caster
	game_node.add_child(bolt)
	bolt.global_position = start
	
	# Create the visual arc
	_create_chain_arc(bolt, start, end)


func _create_chain_arc(parent: Node3D, start: Vector3, end: Vector3) -> void:
	"""Create a jagged lightning arc between two points"""
	var distance = start.distance_to(end)
	
	# Main bolt beam
	var bolt = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.height = distance
	cylinder.top_radius = 0.06
	cylinder.bottom_radius = 0.06
	bolt.mesh = cylinder
	
	# Electric blue glowing material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.8, 1.0)  # Light blue
	material.emission_enabled = true
	material.emission = Color(0.7, 0.9, 1.0)
	material.emission_energy_multiplier = 12.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bolt.material_override = material
	
	parent.add_child(bolt)
	
	# Position bolt between start and end
	bolt.global_position = (start + end) / 2.0
	bolt.look_at(end, Vector3.UP)
	bolt.rotate_object_local(Vector3.RIGHT, PI / 2)
	
	# Add outer glow
	var glow = MeshInstance3D.new()
	var glow_cyl = CylinderMesh.new()
	glow_cyl.height = distance
	glow_cyl.top_radius = 0.12
	glow_cyl.bottom_radius = 0.12
	glow.mesh = glow_cyl
	
	var glow_mat = StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.6, 0.9, 1.0, 0.6)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.8, 0.95, 1.0)
	glow_mat.emission_energy_multiplier = 10.0
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = glow_mat
	
	bolt.add_child(glow)
	
	# Animate bolt flickering
	var tween = get_tree().create_tween()
	tween.set_loops(3)
	tween.tween_property(material, "emission_energy_multiplier", 18.0, 0.04)
	tween.tween_property(material, "emission_energy_multiplier", 6.0, 0.04)
	
	# Add electric sparks at impact point
	for i in range(6):
		var spark = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.08, 0.2, 0.08)
		spark.mesh = box
		
		var spark_mat = StandardMaterial3D.new()
		spark_mat.albedo_color = Color(0.7, 0.95, 1.0)
		spark_mat.emission_enabled = true
		spark_mat.emission = Color(0.9, 1.0, 1.0)
		spark_mat.emission_energy_multiplier = 15.0
		spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark.material_override = spark_mat
		
		parent.add_child(spark)
		spark.global_position = end
		
		# Random spark direction
		var direction = Vector3(
			randf_range(-1, 1),
			randf_range(-0.5, 1),
			randf_range(-1, 1)
		).normalized()
		
		# Animate spark
		var spark_tween = get_tree().create_tween()
		spark_tween.set_parallel(true)
		spark_tween.tween_property(spark, "global_position", end + direction * 1.5, 0.25)
		spark_tween.tween_property(spark, "scale", Vector3.ZERO, 0.25)
	
	# Auto-cleanup
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(parent):
		parent.queue_free()


func _find_entities_in_radius(center: Vector3, radius: float) -> Array:
	"""Helper function to find all alive enemy entities within a radius"""
	var result = []
	var entities = get_tree().get_nodes_in_group("entities")
	
	for entity in entities:
		if not is_instance_valid(entity) or not entity.is_alive:
			continue
		
		# Only target enemies
		if entity.team != EntityBase.Team.ENEMY:
			continue
		
		# Check distance
		var distance = center.distance_to(entity.global_position)
		if distance <= radius:
			result.append(entity)
	
	return result


func _spawn_poison_cloud(game_node: Node, pos: Vector3, stack_count: int, attacker) -> void:
	"""Creates a poison cloud area that damages enemies over time"""
	
	# Create root node for the poison cloud
	var cloud = Node3D.new()
	cloud.name = "PoisonCloud"
	cloud.position = pos
	game_node.add_child(cloud)
	
	# Create particle system for visual cloud effect
	var particles = GPUParticles3D.new()
	particles.name = "Particles"
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 2.0
	particles.one_shot = false  # Keep emitting during cloud lifetime
	particles.explosiveness = 0.3
	cloud.add_child(particles)
	
	# Particle material for poison cloud look
	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.direction = Vector3(0, 0.5, 0)  # Slight upward bias
	particle_mat.spread = 180.0  # Full sphere
	particle_mat.initial_velocity_min = 1.0
	particle_mat.initial_velocity_max = 3.0
	particle_mat.gravity = Vector3(0, -0.5, 0)  # Very light gravity, cloud hugs ground
	particle_mat.damping_min = 2.0
	particle_mat.damping_max = 3.0
	particle_mat.scale_min = 2.0
	particle_mat.scale_max = 4.0
	particle_mat.color = Color(0.3, 1.0, 0.3, 0.6)  # Green poison color
	
	# Color gradient - fade in and out
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.4, 1.0, 0.4, 0.0))  # Start transparent
	gradient.set_color(1, Color(0.2, 0.8, 0.3, 0.0))  # End transparent
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	particle_mat.color_ramp = gradient_tex
	
	particles.process_material = particle_mat
	
	# Simple quad mesh for particles
	var mesh = QuadMesh.new()
	particles.draw_pass_1 = mesh
	
	# Particle shader material for billboard + transparency
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color(0.3, 1.0, 0.3, 0.4)  # Green tint
	particles.material_override = mat
	
	# Add pulsing light for extra atmosphere
	var light = OmniLight3D.new()
	light.name = "PoisonLight"
	light.light_color = Color(0.3, 1.0, 0.3)  # Green glow
	light.light_energy = 3.0
	light.omni_range = 4.0
	cloud.add_child(light)
	
	# Pulse animation for light
	var light_tween = get_tree().create_tween()
	light_tween.set_loops()
	light_tween.tween_property(light, "light_energy", 6.0, 0.5)
	light_tween.tween_property(light, "light_energy", 2.0, 0.5)
	
	# Constants for damage
	const POISON_DURATION = 5.0  # 5 seconds total
	const POISON_RADIUS = 3.0    # 3 block radius
	const POISON_TICK = 0.5      # Damage every 0.5 seconds
	const POISON_DAMAGE = 5      # Base damage per tick
	
	# Create damage timer
	var damage_timer = Timer.new()
	damage_timer.name = "DamageTimer"
	damage_timer.wait_time = POISON_TICK
	damage_timer.autostart = true
	cloud.add_child(damage_timer)
	
	# Track total ticks
	var ticks_remaining = int(POISON_DURATION / POISON_TICK)
	
	# Damage function
	var do_damage = func():
		ticks_remaining -= 1
		
		# Find all entities in radius
		var entities_in_area = _find_entities_in_radius(pos, POISON_RADIUS)
		var damaged_count = 0
		
		for entity in entities_in_area:
			if entity and is_instance_valid(entity):
				var damage = POISON_DAMAGE + stack_count
				entity.take_damage(damage, attacker)
				damaged_count += 1
		
		if damaged_count > 0:
			print("☠️ Poison Cloud damaged %d enemies for %d HP" % [damaged_count, POISON_DAMAGE + stack_count])
		
		# Clean up when done
		if ticks_remaining <= 0:
			damage_timer.stop()
			particles.emitting = false
			# Wait for particles to finish before cleanup
			await get_tree().create_timer(2.0).timeout
			cloud.queue_free()
	
	damage_timer.timeout.connect(do_damage)
	
	# Cleanup timer as backup
	var cleanup_timer = Timer.new()
	cleanup_timer.name = "CleanupTimer"
	cleanup_timer.wait_time = POISON_DURATION + 3.0
	cleanup_timer.one_shot = true
	cleanup_timer.autostart = true
	cloud.add_child(cleanup_timer)
	cleanup_timer.timeout.connect(func(): if is_instance_valid(cloud): cloud.queue_free())
