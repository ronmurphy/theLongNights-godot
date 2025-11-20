extends Node3D

## Animates the fire slash effect by updating the speed parameter over time

var elapsed_time: float = 0.0
var material: ShaderMaterial = null
var animation_speed: float = 1.0  # Multiplier for animation speed


func _ready():
	# Get the material from the MeshInstance3D child
	var mesh_instance = get_node_or_null("MeshInstance3D")
	if mesh_instance:
		material = mesh_instance.get_surface_override_material(0)
		if not material:
			material = mesh_instance.get_active_material(0)


func _process(delta: float):
	if material:
		elapsed_time += delta * animation_speed
		# Update the speed parameter - this drives the progress in the shader
		material.set_shader_parameter("speed", elapsed_time)
