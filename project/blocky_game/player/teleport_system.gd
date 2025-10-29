## Handles teleportation when player stands on teleport stones
## Attach this to the player or main game node
extends Node

## Reference to the RuinManager
var ruin_manager: Node = null

## Reference to the player character
var player: Node3D = null

## Teleport cooldown (seconds) to prevent repeated teleports
var teleport_cooldown: float = 2.0

## Time since last teleport
var time_since_last_teleport: float = 0.0

## Currently standing on a teleport stone?
var on_teleport_stone: bool = false

## Which ruin's teleport stone are we on?
var current_teleport_ruin: int = -1


func _ready() -> void:
	# Find RuinManager in the scene tree
	ruin_manager = get_tree().root.find_child("RuinManager", true, false)
	
	# Find player
	if get_parent() is CharacterBody3D or get_parent().is_in_group("player"):
		player = get_parent()
	else:
		player = get_tree().root.find_child("Player", true, false)
	
	if not ruin_manager:
		push_error("TeleportSystem: Could not find RuinManager in scene")
	if not player:
		push_error("TeleportSystem: Could not find Player in scene")


func _physics_process(delta: float) -> void:
	if not ruin_manager or not player:
		return
	
	time_since_last_teleport += delta
	
	# Check if player is standing on a teleport stone
	_check_teleport_stone_contact()


## Check if player is standing on a teleport stone
func _check_teleport_stone_contact() -> void:
	# Get player position (voxel coordinates)
	var player_pos = player.global_position
	
	# Check if there's a teleport stone at this position
	var ruin_index = ruin_manager.get_ruin_index_at_teleport(player_pos, 1.0)
	
	if ruin_index >= 0:
		if not on_teleport_stone:
			on_teleport_stone = true
			current_teleport_ruin = ruin_index
			print("Teleport System: Standing on teleport stone from ruin %d" % ruin_index)
	else:
		if on_teleport_stone:
			on_teleport_stone = false
			print("Teleport System: Left teleport stone")


## Trigger teleportation to the next ruin
## Call this from player input (e.g., pressing E on a teleport stone)
func teleport_to_next_ruin() -> void:
	if not ruin_manager or not player:
		return
	
	if not on_teleport_stone:
		print("Teleport System: Not standing on a teleport stone!")
		return
	
	if time_since_last_teleport < teleport_cooldown:
		print("Teleport System: Cooldown active (%.1f seconds remaining)" % (teleport_cooldown - time_since_last_teleport))
		return
	
	# Get next ruin
	var next_ruin_index = ruin_manager.get_next_ruin_index(current_teleport_ruin)
	var spawn_position = ruin_manager.get_teleport_spawn_position(next_ruin_index)
	
	# Teleport the player
	player.global_position = spawn_position
	
	# Reset cooldown
	time_since_last_teleport = 0.0
	
	print("Teleported from ruin %d to ruin %d at position %.1f,%.1f,%.1f" % [
		current_teleport_ruin, next_ruin_index, spawn_position.x, spawn_position.y, spawn_position.z
	])


## Check if player can teleport (for UI/input handling)
func can_teleport() -> bool:
	return on_teleport_stone and time_since_last_teleport >= teleport_cooldown


## Get info about current teleport stone
func get_teleport_info() -> Dictionary:
	return {
		"on_stone": on_teleport_stone,
		"current_ruin": current_teleport_ruin,
		"next_ruin": ruin_manager.get_next_ruin_index(current_teleport_ruin) if on_teleport_stone else -1,
		"can_teleport": can_teleport(),
		"cooldown_remaining": max(0, teleport_cooldown - time_since_last_teleport)
	}
