extends Node
## MeshGenerator - Converts voxel chunk data into renderable 3D meshes
## Uses a simple greedy meshing approach for efficiency

class_name MeshGenerator

const CHUNK_SIZE = 12  # Must match WorldGenerator.CHUNK_SIZE

## Generate a mesh from chunk voxel data
## Returns an ArrayMesh that can be rendered
func generate_mesh(chunk_data: Array, chunk_pos: Vector3i) -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var surface_tool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Generate faces for all solid voxels
	_generate_voxel_faces(chunk_data, chunk_pos, surface_tool)

	# Commit the mesh - SurfaceTool will handle empty meshes
	surface_tool.commit(mesh)

	return mesh

## Generate cube faces for each solid voxel
func _generate_voxel_faces(chunk_data: Array, chunk_pos: Vector3i, surface_tool: SurfaceTool) -> void:
	# Iterate through all voxels in the chunk
	for local_x in range(CHUNK_SIZE):
		for local_y in range(CHUNK_SIZE):
			for local_z in range(CHUNK_SIZE):
				var index = local_y * CHUNK_SIZE * CHUNK_SIZE + local_z * CHUNK_SIZE + local_x

				if index >= chunk_data.size():
					continue

				var voxel_value = chunk_data[index]

				# Skip empty voxels
				if voxel_value == 0:
					continue

				# World position of this voxel
				var world_x = chunk_pos.x * CHUNK_SIZE + local_x
				var world_y = chunk_pos.y * CHUNK_SIZE + local_y
				var world_z = chunk_pos.z * CHUNK_SIZE + local_z
				var voxel_pos = Vector3(world_x, world_y, world_z)

				# Add faces for each direction (if adjacent voxel is empty)
				# We'll add all faces for now - optimization later
				_add_cube_faces(voxel_pos, surface_tool, voxel_value)

## Add cube faces at a given position
func _add_cube_faces(pos: Vector3, surface_tool: SurfaceTool, voxel_type: int) -> void:
	# Color based on voxel type
	var color = Color.WHITE
	if voxel_type == 1:
		color = Color.GREEN  # Grass

	var p = pos  # Position shorthand
	var s = 1.0  # Size (each voxel is 1x1x1)

	# Top face (+Y)
	_add_quad(surface_tool,
		p + Vector3(0, s, 0),
		p + Vector3(s, s, 0),
		p + Vector3(s, s, s),
		p + Vector3(0, s, s),
		Vector3.UP, color)

	# Bottom face (-Y)
	_add_quad(surface_tool,
		p + Vector3(0, 0, s),
		p + Vector3(s, 0, s),
		p + Vector3(s, 0, 0),
		p + Vector3(0, 0, 0),
		Vector3.DOWN, color)

	# Front face (+Z)
	_add_quad(surface_tool,
		p + Vector3(0, 0, s),
		p + Vector3(s, 0, s),
		p + Vector3(s, s, s),
		p + Vector3(0, s, s),
		Vector3.FORWARD, color)

	# Back face (-Z)
	_add_quad(surface_tool,
		p + Vector3(s, 0, 0),
		p + Vector3(0, 0, 0),
		p + Vector3(0, s, 0),
		p + Vector3(s, s, 0),
		Vector3.BACK, color)

	# Right face (+X)
	_add_quad(surface_tool,
		p + Vector3(s, 0, 0),
		p + Vector3(s, 0, s),
		p + Vector3(s, s, s),
		p + Vector3(s, s, 0),
		Vector3.RIGHT, color)

	# Left face (-X)
	_add_quad(surface_tool,
		p + Vector3(0, 0, s),
		p + Vector3(0, 0, 0),
		p + Vector3(0, s, 0),
		p + Vector3(0, s, s),
		Vector3.LEFT, color)

## Add a quad (2 triangles) to the surface
func _add_quad(surface_tool: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3, color: Color) -> void:
	surface_tool.set_normal(normal)
	surface_tool.set_color(color)

	# First triangle
	surface_tool.add_vertex(v0)
	surface_tool.add_vertex(v1)
	surface_tool.add_vertex(v2)

	# Second triangle
	surface_tool.add_vertex(v0)
	surface_tool.add_vertex(v2)
	surface_tool.add_vertex(v3)
