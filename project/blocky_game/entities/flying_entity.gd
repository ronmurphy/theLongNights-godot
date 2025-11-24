extends EntityBase
class_name FlyingEntity

## FlyingEntity - Base class for flying/floating entities
## Handles hovering, bobbing, and aerial movement
## Used by: ghost, angry_ghost, etc.

@export var float_height := 1.5  # Height above ground/target
@export var bob_amplitude := 0.3  # How much to bob up/down
@export var bob_frequency := 1.5  # Speed of bobbing

var _bob_time := 0.0
var _velocity := Vector3.ZERO  # External velocity (for grapple pulls, knockback, etc.)
var _velocity_decay := 0.9  # How quickly external velocity decays
var _external_force_timer := 0.0  # Prevent AI movement override when > 0


func _ready():
	super._ready()
	# Derived classes should call create_billboard_shadow() after sprite is set


## Call this in _process to apply bobbing effect
func apply_bob_movement(delta: float) -> void:
	_bob_time += delta * bob_frequency

	# Handle auto-regeneration (1 HP every 3 minutes)
	if current_hp < max_hp:
		_regen_timer += delta
		if _regen_timer >= REGEN_INTERVAL:
			_regen_timer = 0.0
			heal(1)

	# Apply external velocity (grapple pull, knockback, etc.)
	if _velocity.length() > 0.1:
		global_position += _velocity * delta
		_velocity *= _velocity_decay  # Decay over time


## Get the current bob offset (add this to your target Y position)
func get_bob_offset() -> float:
	return sin(_bob_time * TAU) * bob_amplitude


## Smoothly move toward a target position with bobbing
func move_toward_target(delta: float, target_pos: Vector3, speed: float, maintain_height: bool = true) -> void:
	if not is_alive:
		return

	# Update external force timer
	if _external_force_timer > 0:
		_external_force_timer -= delta

	# Skip AI movement if being affected by external force
	if _external_force_timer > 0:
		return

	# Calculate direction to target
	var to_target = target_pos - global_position

	if maintain_height:
		# Only move horizontally toward target
		to_target.y = 0

	var distance = to_target.length()

	# Move if not at target
	if distance > 0.1:
		var direction = to_target.normalized()
		global_position += direction * speed * delta

	# Apply float height and bobbing
	if maintain_height:
		var bob_offset = get_bob_offset()
		var target_y = target_pos.y + float_height + bob_offset
		global_position.y = lerp(global_position.y, target_y, delta * 3.0)


## Apply external force (grapple pull, knockback, etc.)
func apply_external_force(force: Vector3):
	"""Apply an external force to the flying entity (overrides velocity and disables AI movement briefly)"""
	_velocity = force
	_external_force_timer = 0.5  # Disable AI movement for 0.5 seconds


func create_billboard_shadow(texture_path: String, shadow_scale: Vector3 = Vector3(1.2, 1.2, 1.2)) -> void:
	var shadow_mesh = QuadMesh.new()
	shadow_mesh.size = Vector2(1, 1)
	var shadow_instance = MeshInstance3D.new()
	shadow_instance.mesh = shadow_mesh
	shadow_instance.scale = shadow_scale
	shadow_instance.position = Vector3(0, 0.01, 0)
	var shadow_material = StandardMaterial3D.new()
	shadow_material.albedo_texture = load(texture_path)
	shadow_material.albedo_color = Color(0, 0, 0, 0.5)
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow_instance.material_override = shadow_material
	shadow_instance.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(shadow_instance)
