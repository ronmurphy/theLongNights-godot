extends Node3D

## Ghost - Friendly floating companion
## Follows the player at a distance, no attack behavior

@export var follow_distance := 5.0
@export var follow_speed := 2.0
@export var float_height := 1.5
@export var bob_amplitude := 0.3
@export var bob_frequency := 1.5

var _sprite: Sprite3D
var _bob_time := 0.0
var _target_player: Node3D = null


func _ready():
	# Create billboard sprite
	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # Pixel art style
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.shaded = true

	# Scale down sprite to match voxel world scale (1/4 size)
	# pixel_size controls how big each pixel is in 3D space
	_sprite.pixel_size = 0.0025  # Default is 0.01, so 1/4 size

	# Load ghost texture
	var texture = load("res://assets/art/entities/ghost.png")
	if texture:
		_sprite.texture = texture
	else:
		push_error("Ghost: Failed to load ghost.png texture")

	add_child(_sprite)

	# Find player
	_find_player()


func _find_player():
	# Try to find player in the scene tree
	_target_player = get_tree().get_first_node_in_group("player")
	if _target_player == null:
		push_warning("Ghost: Could not find player")


func _process(delta: float):
	if _target_player == null:
		_find_player()
		return

	# Bob up and down
	_bob_time += delta * bob_frequency
	var bob_offset = sin(_bob_time * TAU) * bob_amplitude

	# Calculate target position (behind and above player)
	var player_pos = _target_player.global_position
	var to_player = global_position - player_pos
	to_player.y = 0  # Only consider horizontal distance

	var distance = to_player.length()

	# If too far, move closer
	if distance > follow_distance:
		var direction = -to_player.normalized()
		global_position += direction * follow_speed * delta

	# Maintain float height above ground
	var target_height = player_pos.y + float_height + bob_offset
	global_position.y = lerp(global_position.y, target_height, delta * 3.0)

	# Make sprite face the camera (billboard handles this automatically)


## Spawn a ghost at a specific position
static func spawn(world: Node, pos: Vector3) -> Node3D:
	var ghost = preload("res://blocky_game/entities/ghost.tscn").instantiate()
	ghost.global_position = pos
	world.add_child(ghost)
	return ghost
