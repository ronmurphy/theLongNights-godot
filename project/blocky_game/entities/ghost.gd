extends FlyingEntity

## Ghost - Friendly floating companion
## Follows the player at a distance, no attack behavior

@export var follow_distance := 5.0
@export var follow_speed := 2.0

var _target_player: Node3D = null


func _ready():
	# Set entity properties
	entity_id = "ghost"
	entity_name = "Ghost"
	team = Team.PLAYER
	max_hp = 8
	current_hp = max_hp

	# Load entity data from JSON
	var data = EntityBase.load_entity_data("ghost")
	if not data.is_empty():
		apply_entity_data(data)

	# Call parent ready
	super._ready()

	# Create sprite
	_sprite = _create_sprite("res://assets/art/entities/ghost.png", 0.0025)

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

	# Update bobbing
	apply_bob_movement(delta)

	# Follow player if too far
	var player_pos = _target_player.global_position
	var distance_2d = Vector2(global_position.x - player_pos.x, global_position.z - player_pos.z).length()

	if distance_2d > follow_distance:
		move_toward_target(delta, player_pos, follow_speed, true)


## Spawn a ghost at a specific position
static func spawn(world: Node, pos: Vector3) -> Node3D:
	var ghost = preload("res://blocky_game/entities/ghost.tscn").instantiate()
	ghost.global_position = pos
	world.add_child(ghost)
	return ghost
