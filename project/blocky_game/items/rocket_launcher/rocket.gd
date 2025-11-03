extends Node3D

const LIFETIME = 10.0

const DebrisScene = preload("./debris.tscn")
const ExplosionScene = preload("./rocket_explosion.tscn")

@onready var _terrain : VoxelTerrain = get_node("../VoxelTerrain")
@onready var _terrain_tool := _terrain.get_voxel_tool()

var _direction := Vector3(0, 0, 1)
var _speed := 20.0
var _remaining_time := LIFETIME
var stack_bonus := 0  # Damage bonus from stacked rocket launchers


func set_direction(direction: Vector3):
	assert(is_inside_tree())
	direction += Vector3(0.0001, 0.0001, 0.001) # Haaaaak
	_direction = direction.normalized()
	look_at(global_transform.origin + _direction, Vector3(0, 1, 0))


func _physics_process(delta: float):
	_remaining_time -= delta
	if _remaining_time <= 0:
		# Spent too long not hitting anything
		queue_free()
		return
	
	var trans = global_transform
	var crossed_distance := _speed * delta
	var motion := crossed_distance * _direction
	
	var hit = _terrain_tool.raycast(trans.origin, _direction, crossed_distance)
	if hit != null:
		_explode(hit.position, trans.origin)
	else:
		trans.origin += motion
		global_transform = trans


func _explode(voxel_hit_pos: Vector3, explosion_pos: Vector3):
	var mp := get_tree().get_multiplayer()
	var total_damage = 50 + stack_bonus  # Base rocket damage + stack bonus
	if mp.has_multiplayer_peer():
		if mp.is_server():
			_do_sphere_safe(voxel_hit_pos, 4.0)
			_damage_nearby_entities(explosion_pos, 6.0, total_damage)  # 6 block radius, damage with stack bonus
			rpc(&"receive_explode", explosion_pos)
			_create_explosion_vfx(explosion_pos)
			queue_free()
		# Else, clients don't do anything. Clients could rely on their local copy of the terrain
		# to find when the collision occurs, but it can lead to false positives if terrain is synced
		# out of order, so it's more reliable to explicitely be told when to play the explosion
	else:
		_do_sphere_safe(voxel_hit_pos, 4.0)
		_damage_nearby_entities(explosion_pos, 6.0, total_damage)  # 6 block radius, damage with stack bonus
		_create_explosion_vfx(explosion_pos)
		queue_free()


func _do_sphere_safe(center: Vector3, radius: float):
	"""Destroy blocks in sphere, but skip bedrock (voxel ID 28)"""
	var r_int = int(ceil(radius))
	
	# Iterate through all positions in bounding box
	for y in range(-r_int, r_int + 1):
		for z in range(-r_int, r_int + 1):
			for x in range(-r_int, r_int + 1):
				var pos = center + Vector3(x, y, z)
				var dist = pos.distance_to(center)
				
				# If position is within sphere radius
				if dist <= radius:
					# Check what block is there
					var voxel_id = _terrain_tool.get_voxel(pos)
					
					# Only destroy if it's not bedrock (voxel ID 28) and not air (0)
					if voxel_id != 0 and voxel_id != 28:
						_terrain_tool.set_voxel(pos, 0)  # 0 = air


@rpc("authority", "call_remote", "reliable", 0)
func receive_explode(pos: Vector3):
	_create_explosion_vfx(pos)
	queue_free()


func _create_explosion_vfx(explosion_pos: Vector3):
	# VFX are not created as children of the rocket because it gets destroyed shortly after.

	var explosion = ExplosionScene.instantiate()
	explosion.position = explosion_pos
	# Note: Damage is already handled in _explode() with stack bonus
	get_parent().add_child(explosion)
	
	# Create debris (respecting graphics settings)
	var debris_count = GraphicsSettings.get_debris_count()
	for i in debris_count:
		var debris = DebrisScene.instantiate()
		var debris_velocity := \
			Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		debris_velocity *= randf_range(5.0, 30.0)
		debris.set_velocity(debris_velocity)
		debris.position = explosion_pos
		get_parent().add_child(debris)


## Damage all entities within radius of explosion
func _damage_nearby_entities(center: Vector3, radius: float, damage: int) -> void:
	# Get all entities in the scene
	var entities = get_tree().get_nodes_in_group("entities")

	for entity in entities:
		if not entity is EntityBase:
			continue

		# Skip friendly entities (don't damage player's companions)
		if entity.team == EntityBase.Team.PLAYER:
			continue

		# Check distance
		var distance = entity.global_position.distance_to(center)
		if distance <= radius:
			# Apply damage (could scale with distance)
			var scaled_damage = int(damage * (1.0 - (distance / radius)))
			entity.take_damage(scaled_damage, self)
