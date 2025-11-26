extends Node3D
class_name EntityBase

## EntityBase - Base class for all entities (enemies and companions)
## Handles HP, damage, team affiliation, and death

enum Team {
	NEUTRAL = 0,
	PLAYER = 1,
	ENEMY = 2
}

## Entity stats (loaded from entities.json)
@export var entity_id: String = ""
@export var entity_name: String = "Unknown"
@export var team: Team = Team.NEUTRAL
@export var entity_tier: int = 1  # Enemy tier (1-5) for loot drops
@export var max_hp: int = 10
@export var attack_damage: int = 3
@export var defense: int = 10
@export var luck: int = 0  # Affects hit/dodge chance in combat
@export var movement_speed: float = 2.0

## Current state
var current_hp: int = 10
var is_alive: bool = true
var _sprite: Sprite3D = null
var _regen_timer: float = 0.0  # For 1 HP per 3 minutes
const REGEN_INTERVAL: float = 180.0  # 3 minutes in seconds

## Signals
signal died(entity: EntityBase)
signal took_damage(amount: int, from: Node)
signal healed(amount: int)


## d20-style roll to hit with luck modifiers
static func roll_to_hit(attacker_luck: int = 0, defender_luck: int = 0) -> bool:
	# Roll a d20, base threshold is 10
	# Attacker luck lowers threshold (easier to hit)
	# Defender luck raises threshold (harder to hit)
	# Luck is capped at +5 effective (80% max hit chance)
	const LUCK_CAP = 5
	var clamped_attacker_luck = mini(attacker_luck, LUCK_CAP)
	var clamped_defender_luck = mini(defender_luck, LUCK_CAP)

	var roll = randi() % 20 + 1
	var hit_threshold = 10 - clamped_attacker_luck + clamped_defender_luck
	return roll >= hit_threshold


func _ready():
	# Initialize HP
	current_hp = max_hp

	# Add to entity group for targeting
	add_to_group("entities")

	# Add to team-specific groups
	match team:
		Team.PLAYER:
			add_to_group("friendly_entities")
		Team.ENEMY:
			add_to_group("enemy_entities")

	# Add collision detection for raycasts (grapple-pull, etc.)
	_add_collision_detection()


## Deal damage to this entity
func take_damage(amount: int, from: Node = null) -> void:
	if not is_alive:
		return

	# Roll to hit - if failed, no damage
	if not roll_to_hit():
		print("%s dodged attack! (Roll failed)" % entity_name)
		return

	# Apply defense (simple formula: reduce damage by defense%)
	var actual_damage = max(1, amount - int(amount * (defense / 100.0)))

	current_hp -= actual_damage
	current_hp = max(0, current_hp)

	took_damage.emit(actual_damage, from)

	# Blood spray particle effect on damage
	_spawn_blood_spray()
	
	# Flash red when taking damage
	_flash_red()

	# Check for death
	if current_hp <= 0:
		die()

	print("%s took %d damage (HP: %d/%d)" % [entity_name, actual_damage, current_hp, max_hp])


## Heal this entity
func heal(amount: int) -> void:
	if not is_alive:
		return

	current_hp += amount
	current_hp = min(max_hp, current_hp)

	healed.emit(amount)


## Kill this entity
func die() -> void:
	if not is_alive:
		return

	is_alive = false
	died.emit(self)

	print("%s died!" % entity_name)

	# Track blood moon kill for performance rewards
	if has_meta("is_bloodmoon_spawn") and get_meta("is_bloodmoon_spawn"):
		TimeManager.increment_bloodmoon_kill()

	# Check for blood moon sky ruin drops
	_check_bloodmoon_sky_drops()

	# Play death animation/effect (override in subclasses)
	_on_death()

	# Despawn after animation completes
	await get_tree().create_timer(2.0).timeout
	queue_free()


## Override in subclasses for death effects
func _on_death() -> void:
	# Choose death effect based on graphics quality
	match GraphicsSettings.current_profile:
		"low":
			_death_effect_low()
		"medium":
			_death_effect_medium()
		"high":
			_death_effect_high()
		_:
			# Fallback to medium if unknown
			_death_effect_medium()


## Low quality death: Simple particle puff
func _death_effect_low() -> void:
	print("Death effect LOW quality triggered")
	if not _sprite:
		print("WARNING: No sprite found for death effect")
		return
	
	# Create particle explosion
	var particles = GPUParticles3D.new()
	add_child(particles)
	
	# Position at sprite location
	particles.global_position = _sprite.global_position
	
	# Configure particle material
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.5
	material.direction = Vector3(0, 1, 0)
	material.spread = 45.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 4.0
	material.gravity = Vector3(0, -5.0, 0)
	material.scale_min = 0.1
	material.scale_max = 0.3
	material.color = _sprite.modulate  # Use entity's color
	
	particles.process_material = material
	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	# Create simple quad mesh for particles
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.2, 0.2)
	particles.draw_pass_1 = quad_mesh
	
	# Hide sprite immediately
	_sprite.visible = false
	
	# Emit particles
	particles.emitting = true
	
	# Clean up particles after they're done
	await get_tree().create_timer(particles.lifetime + 0.5).timeout
	particles.queue_free()


## Blood spray effect when entity takes damage
func _spawn_blood_spray() -> void:
	if not _sprite:
		return

	# Create particle effect
	var particles = GPUParticles3D.new()
	add_child(particles)

	# Position at sprite center (billboard center)
	particles.global_position = _sprite.global_position

	# Configure particle material for sphere burst effect (like 3D fireworks)
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.2  # Tight center point
	material.direction = Vector3(0, 1, 0)  # Default direction (not really used with 180 spread)
	material.spread = 180.0  # Full sphere burst - 360 degree visibility
	material.initial_velocity_min = 2.5
	material.initial_velocity_max = 4.0
	material.gravity = Vector3(0, -5.0, 0)  # Moderate gravity for arc effect
	material.scale_min = 0.3  # Much larger particles for visibility
	material.scale_max = 0.5

	# Bright red color for blood - highly visible
	material.color = Color(0.9, 0.1, 0.1, 1.0)
	material.color_ramp = _create_blood_fade_gradient()

	particles.process_material = material
	particles.amount = 25  # More particles for better sphere burst effect
	particles.lifetime = 0.8  # Short burst
	particles.one_shot = true
	particles.explosiveness = 1.0  # Instant burst

	# Create larger quad mesh for particles with unshaded material
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.4, 0.4)  # Larger mesh for visibility

	# Make particle material unshaded and emissive for better visibility
	var particle_mat = StandardMaterial3D.new()
	particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_mat.vertex_color_use_as_albedo = true  # Use particle color
	particle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad_mesh.material = particle_mat

	particles.draw_pass_1 = quad_mesh

	# Emit particles
	particles.emitting = true

	# Clean up particles after they're done
	await get_tree().create_timer(particles.lifetime + 0.5).timeout
	particles.queue_free()


## Create gradient for blood particles to fade out
func _create_blood_fade_gradient() -> GradientTexture1D:
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))  # Start opaque
	gradient.set_color(1, Color(1, 1, 1, 0))  # Fade to transparent
	
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	return gradient_texture


## Flash the sprite red when taking damage
func _check_bloodmoon_sky_drops() -> void:
	"""Drop special loot if killed during blood moon in a sky ruin"""
	# Only drop from enemies
	if team != Team.ENEMY:
		return

	# ALWAYS: 20% chance to drop a tiered pouch (any enemy, any location)
	if randf() < 0.20:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var inventory = player.get_node_or_null("Inventory")
			var items = get_node_or_null("/root/Main/Game/Items")
			if inventory and items:
				# Roll for pouch tier based on enemy tier
				var pouch_tier = _roll_pouch_tier(entity_tier)
				var pouch_name = "pouch_%d" % pouch_tier
				var pouch_item = _find_item_by_name(items, pouch_name)
				if pouch_item:
					_add_item_to_inventory(inventory, pouch_item.base_info.id, 1)
					var tier_names = ["", "Common", "Uncommon", "Rare", "Epic", "Legendary"]
					var tier_emoji = ["", "💰", "💎", "✨", "🔥", "🌟"]
					print("%s [%s] Tier %d enemy dropped %s Pouch (tier %d)!" % [tier_emoji[pouch_tier], entity_name, entity_tier, tier_names[pouch_tier], pouch_tier])

	# Check if this was a blood moon spawn
	if not has_meta("is_bloodmoon_spawn"):
		return

	# Check if killed in a sky ruin (Y > 3000)
	var spawn_y = get_meta("spawn_y_position", 0.0)
	if spawn_y < 3000.0:
		return

	# This enemy was killed in a sky ruin during a blood moon!
	print("💎 Blood Moon Sky Ruin Kill! Dropping special loot...")

	# Get player to give items to
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# Get inventory
	var inventory = player.get_node_or_null("Inventory")
	if not inventory:
		return

	# Get Items database
	var items = get_node_or_null("/root/Main/Game/Items")
	if not items:
		return

	# Always drop 1 skyshard
	var skyshard_item = _find_item_by_name(items, "skyshard")
	if skyshard_item:
		_add_item_to_inventory(inventory, skyshard_item.base_info.id, 1)
		print("  + 1 Skyshard")

	# 25% chance to drop a portal compass
	if randf() < 0.25:
		var compass_item = _find_item_by_name(items, "portal_compass")
		if compass_item:
			_add_item_to_inventory(inventory, compass_item.base_info.id, 1)
			print("  + 1 Portal Compass (bonus!)")


func _roll_pouch_tier(enemy_tier: int) -> int:
	"""Roll for which pouch tier drops based on enemy tier
	Enemy tier determines the MAX pouch tier that can drop
	Weighted toward lower tiers, but higher tiers have a chance
	"""
	# Tier-based drop weights
	# Format: [tier1_weight, tier2_weight, tier3_weight, tier4_weight, tier5_weight]
	var drop_weights = []

	match enemy_tier:
		1:
			drop_weights = [100, 0, 0, 0, 0]  # Only tier 1
		2:
			drop_weights = [70, 30, 0, 0, 0]  # Mostly tier 1, some tier 2
		3:
			drop_weights = [50, 35, 15, 0, 0]  # Mix of 1-3
		4:
			drop_weights = [40, 30, 20, 10, 0]  # Mix of 1-4
		5:
			drop_weights = [30, 25, 25, 15, 5]  # All tiers, 5% legendary
		_:
			drop_weights = [100, 0, 0, 0, 0]  # Default to tier 1

	# Calculate total weight
	var total_weight = 0
	for weight in drop_weights:
		total_weight += weight

	# Roll
	var roll = randi() % total_weight
	var current_weight = 0
	for tier_index in range(drop_weights.size()):
		current_weight += drop_weights[tier_index]
		if roll < current_weight:
			return tier_index + 1  # +1 because tiers are 1-indexed

	return 1  # Fallback


func _find_item_by_name(items_node, item_name: String):
	"""Helper to find an item by name in the Items database"""
	for i in range(100):  # Assume max 100 items
		var item = items_node.get_item(i)
		if item and item.base_info.name == item_name:
			return item
	return null


func _add_item_to_inventory(inventory, item_id: int, count: int = 1):
	"""Add an item to the inventory by finding first empty slot or stacking"""
	const InventoryItem = preload("res://blocky_game/player/inventory_item.gd")

	# Try to find existing stack first
	for i in range(inventory._slots.size()):
		var slot = inventory._slots[i]
		if slot != null and slot.type == InventoryItem.TYPE_ITEM and slot.id == item_id:
			# Found existing stack, add to it
			slot.count += count
			inventory._slot_views[i].get_display().set_item(slot)
			inventory.changed.emit()
			return

	# No existing stack, find first empty slot
	for i in range(inventory._slots.size()):
		if inventory._slots[i] == null:
			# Found empty slot
			var new_item = InventoryItem.new()
			new_item.type = InventoryItem.TYPE_ITEM
			new_item.id = item_id
			new_item.count = count
			inventory._slots[i] = new_item
			inventory._slot_views[i].get_display().set_item(new_item)
			inventory.changed.emit()
			return

	# No empty slots found
	push_warning("Inventory full! Could not add item ID %d" % item_id)


func _flash_red() -> void:
	if not _sprite:
		return
	
	# Store original modulate color
	var original_color = _sprite.modulate
	
	# Flash red
	_sprite.modulate = Color(1.5, 0.5, 0.5, 1.0)  # Bright red tint
	
	# Tween back to original color
	var tween = create_tween()
	tween.tween_property(_sprite, "modulate", original_color, 0.3)


## Medium quality death: Dissolve shader effect (same as high but faster)
func _death_effect_medium() -> void:
	print("Death effect MEDIUM quality triggered")
	if not _sprite:
		print("WARNING: No sprite found for death effect")
		return
	
	# Load and apply dissolve shader (same as high quality)
	var dissolve_shader = load("res://blocky_game/shaders/entity_dissolve.gdshader")
	var shader_material = ShaderMaterial.new()
	shader_material.shader = dissolve_shader
	
	# Copy the original texture to the shader
	if _sprite.texture:
		shader_material.set_shader_parameter("texture_albedo", _sprite.texture)
	
	# Set shader parameters (faster wave speed for medium)
	shader_material.set_shader_parameter("dissolve_amount", 0.0)
	shader_material.set_shader_parameter("wave_height", 0.15)
	shader_material.set_shader_parameter("wave_speed", 5.0)  # Faster than high
	shader_material.set_shader_parameter("grain_size", 8.0)
	
	# Apply shader to sprite
	_sprite.material_override = shader_material
	
	# Animate dissolve (faster than high quality)
	var tween = create_tween()
	tween.tween_method(
		func(value): shader_material.set_shader_parameter("dissolve_amount", value),
		0.0,
		1.0,
		0.8  # Faster than high (1.5s)
	)


## High quality death: Dissolve shader effect
func _death_effect_high() -> void:
	print("Death effect HIGH quality triggered")
	if not _sprite:
		print("WARNING: No sprite found for death effect")
		return
	
	# Load and apply dissolve shader
	var dissolve_shader = load("res://blocky_game/shaders/entity_dissolve.gdshader")
	var shader_material = ShaderMaterial.new()
	shader_material.shader = dissolve_shader
	
	# Copy the original texture to the shader
	if _sprite.texture:
		shader_material.set_shader_parameter("texture_albedo", _sprite.texture)
	
	# Set shader parameters
	shader_material.set_shader_parameter("dissolve_amount", 0.0)
	shader_material.set_shader_parameter("wave_height", 0.15)
	shader_material.set_shader_parameter("wave_speed", 3.0)
	shader_material.set_shader_parameter("grain_size", 8.0)
	
	# Apply shader to sprite
	_sprite.material_override = shader_material
	
	# Animate dissolve
	var tween = create_tween()
	tween.tween_method(
		func(value): shader_material.set_shader_parameter("dissolve_amount", value),
		0.0,
		1.0,
		1.5
	)


## Add collision detection for raycasts (grapple hook, etc.)
func _add_collision_detection():
	"""Add a StaticBody3D with collision shape so entities can be detected by raycasts"""
	var static_body = StaticBody3D.new()
	static_body.name = "RaycastCollision"
	var collision_shape = CollisionShape3D.new()
	var capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = 0.4  # Wide enough to catch most entities
	capsule_shape.height = 1.5  # Tall enough for humanoid entities
	collision_shape.shape = capsule_shape

	static_body.add_child(collision_shape)
	add_child(static_body)


## Create a billboard sprite for this entity
func _create_sprite(texture_path: String, pixel_size: float = 0.0025) -> Sprite3D:
	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.shaded = true
	_sprite.pixel_size = pixel_size

	var texture = load(texture_path)
	if texture:
		_sprite.texture = texture
	else:
		push_error("EntityBase: Failed to load texture: " + texture_path)

	# Enable shadow casting (same approach as player_avatar.gd)
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	add_child(_sprite)
	return _sprite




## Load entity data from entities.json
static func load_entity_data(entity_id: String) -> Dictionary:
	var json_path = "res://assets/art/entities/entities.json"
	var file = FileAccess.open(json_path, FileAccess.READ)

	if file == null:
		push_error("EntityBase: Failed to open entities.json")
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("EntityBase: Failed to parse entities.json")
		return {}

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("EntityBase: entities.json is not a dictionary")
		return {}

	# Search in monsters section
	if "monsters" in data and entity_id in data["monsters"]:
		return data["monsters"][entity_id]

	push_error("EntityBase: Entity '%s' not found in entities.json" % entity_id)
	return {}


## Apply stats from entities.json data
func apply_entity_data(data: Dictionary) -> void:
	if "name" in data:
		entity_name = data["name"]
	if "hp" in data:
		max_hp = data["hp"]
		current_hp = max_hp
	if "attack" in data:
		attack_damage = data["attack"]
	if "defense" in data:
		defense = data["defense"]
	if "speed" in data:
		movement_speed = data["speed"]
	if "tier" in data:
		entity_tier = int(data["tier"])  # Read tier from JSON

	# Determine team based on type
	if "type" in data:
		match data["type"]:
			"enemy":
				team = Team.ENEMY
			"friendly":
				team = Team.PLAYER
			_:
				team = Team.NEUTRAL
