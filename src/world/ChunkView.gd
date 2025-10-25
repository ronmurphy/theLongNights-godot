extends Node3D
## ChunkView - Renders a single chunk as a 3D mesh
## Attached to a MeshInstance3D to display in the world

class_name ChunkView

var chunk_pos: Vector3i
var mesh_instance: MeshInstance3D
var mesh_generator: MeshGenerator

func _ready() -> void:
	# Create the mesh instance
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)

## Initialize this chunk view with data
func setup(pos: Vector3i, chunk_data: Array) -> void:
	chunk_pos = pos
	mesh_generator = MeshGenerator.new()

	# Generate mesh from chunk data
	var mesh = mesh_generator.generate_mesh(chunk_data, pos)

	# Set the mesh
	mesh_instance.mesh = mesh

	# Create a material for the mesh
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true  # Use vertex colors
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # Simple flat colors for now
	mesh_instance.set_surface_override_material(0, material)

	# Position this node at the chunk's world location (12 voxels per chunk)
	position = Vector3(
		chunk_pos.x * 12,
		chunk_pos.y * 12,
		chunk_pos.z * 12
	)

	print("🎨 Rendered chunk %s" % chunk_pos)
