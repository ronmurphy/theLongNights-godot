extends Node3D
## ChunkView - Renders a single chunk as a 3D mesh
## Attached to a MeshInstance3D to display in the world

class_name ChunkView

var chunk_pos: Vector3i
var mesh_instance: MeshInstance3D
var mesh_generator: MeshGenerator
var texture_manager: BlockTextureManager

func _ready() -> void:
	# Create the mesh instance
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)

## Initialize this chunk view with data
func setup(pos: Vector3i, chunk_data: Array, tex_manager: BlockTextureManager) -> void:
	chunk_pos = pos
	mesh_generator = MeshGenerator.new()
	texture_manager = tex_manager

	# Generate mesh from chunk data
	var mesh = mesh_generator.generate_mesh(chunk_data, pos)

	# Set the mesh
	mesh_instance.mesh = mesh

	# Apply textured material (grass texture for now)
	# Only apply if mesh has surfaces (not empty)
	if mesh.get_surface_count() > 0:
		var grass_texture = texture_manager.textures.get("grass", null)
		if grass_texture:
			var material = texture_manager.create_textured_material(grass_texture)
			mesh_instance.set_surface_override_material(0, material)
		else:
			# Fallback to vertex colors if texture missing
			var material = StandardMaterial3D.new()
			material.vertex_color_use_as_albedo = true
			material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
			mesh_instance.set_surface_override_material(0, material)

	# Position this node at the chunk's world location (12 voxels per chunk)
	position = Vector3(
		chunk_pos.x * 12,
		chunk_pos.y * 12,
		chunk_pos.z * 12
	)

	print("Rendered chunk %s" % chunk_pos)
