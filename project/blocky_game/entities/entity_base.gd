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
@export var max_hp: int = 10
@export var attack_damage: int = 3
@export var defense: int = 10
@export var movement_speed: float = 2.0

## Current state
var current_hp: int = 10
var is_alive: bool = true
var _sprite: Sprite3D = null
var _health_bar: Node3D = null
var _regen_timer: float = 0.0  # For 1 HP per 3 minutes
const REGEN_INTERVAL: float = 180.0  # 3 minutes in seconds

## Signals
signal died(entity: EntityBase)
signal took_damage(amount: int, from: Node)
signal healed(amount: int)


## d20-style roll to hit
static func roll_to_hit() -> bool:
	# Roll a d20, if 10 or higher the attack hits
	var roll = randi() % 20 + 1
	return roll >= 10


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

	# Update health bar
	if _health_bar:
		_update_health_bar()

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

	# Update health bar
	if _health_bar:
		_update_health_bar()


## Kill this entity
func die() -> void:
	if not is_alive:
		return

	is_alive = false
	died.emit(self)

	print("%s died!" % entity_name)

	# Hide health bar immediately
	if _health_bar:
		_health_bar.visible = false

	# Play death animation/effect (override in subclasses)
	_on_death()

	# Despawn after animation completes
	await get_tree().create_timer(2.0).timeout
	queue_free()


## Override in subclasses for death effects
func _on_death() -> void:
	# Fade out sprite
	if _sprite:
		var tween = create_tween()
		tween.tween_property(_sprite, "modulate:a", 0.0, 1.5)


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

	add_child(_sprite)
	return _sprite


## Create a health bar above the entity
func _create_health_bar() -> void:
	# Only create health bars for enemies
	if team != Team.ENEMY:
		return

	_health_bar = Node3D.new()
	_health_bar.position = Vector3(0, 2.0, 0)  # Above entity
	add_child(_health_bar)

	# Background bar (red)
	var bg_quad = MeshInstance3D.new()
	var bg_mesh = QuadMesh.new()
	bg_mesh.size = Vector2(1.0, 0.1)
	bg_quad.mesh = bg_mesh

	var bg_mat = StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.3, 0.0, 0.0)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_quad.material_override = bg_mat
	_health_bar.add_child(bg_quad)

	# Foreground bar (green) - this will scale with HP
	var fg_quad = MeshInstance3D.new()
	fg_quad.name = "HealthBarFill"
	var fg_mesh = QuadMesh.new()
	fg_mesh.size = Vector2(1.0, 0.1)
	fg_quad.mesh = fg_mesh
	fg_quad.position = Vector3(0, 0, -0.01)  # Slightly in front

	var fg_mat = StandardMaterial3D.new()
	fg_mat.albedo_color = Color(0.0, 0.8, 0.0)
	fg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fg_quad.material_override = fg_mat
	_health_bar.add_child(fg_quad)


## Update health bar fill based on current HP
func _update_health_bar() -> void:
	if not _health_bar:
		return

	var fill = _health_bar.get_node_or_null("HealthBarFill")
	if fill:
		var hp_percent = float(current_hp) / float(max_hp)
		fill.scale.x = hp_percent
		fill.position.x = -(1.0 - hp_percent) * 0.5  # Center the bar


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

	# Determine team based on type
	if "type" in data:
		match data["type"]:
			"enemy":
				team = Team.ENEMY
			"friendly":
				team = Team.PLAYER
			_:
				team = Team.NEUTRAL
