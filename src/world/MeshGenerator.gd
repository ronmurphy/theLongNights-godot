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

	# Generate faces for all solid voxels (with face culling)
	_generate_voxel_faces(chunk_data, chunk_pos, surface_tool)

	# Commit the mesh - SurfaceTool will handle empty meshes
	surface_tool.commit(mesh)

	return mesh

## Check if a voxel is solid (helper function)
func _is_solid(chunk_data: Array, local_x: int, local_y: int, local_z: int) -> bool:
	# Out of bounds in Y = air (above/below chunk)
	if local_y < 0 or local_y >= CHUNK_SIZE:
		return false

	# Out of bounds in X/Z = assume solid (neighboring chunk likely has block)
	# This prevents rendering faces at chunk edges
	if local_x < 0 or local_x >= CHUNK_SIZE or \
	   local_z < 0 or local_z >= CHUNK_SIZE:
		return true  # Assume solid in neighboring chunk

	var index = local_y * CHUNK_SIZE * CHUNK_SIZE + local_z * CHUNK_SIZE + local_x
	if index >= chunk_data.size():
		return false

	return chunk_data[index] > 0  # 0 = air, >0 = solid

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

				# Local position of this voxel (within the chunk)
				# ChunkView will handle positioning the whole chunk at world coordinates
				var voxel_pos = Vector3(local_x, local_y, local_z)

				# Only add faces that are exposed to air (face culling)
				_add_cube_faces_culled(chunk_data, voxel_pos, local_x, local_y, local_z, surface_tool, voxel_value)

## Add cube faces only if exposed to air (culled version)
func _add_cube_faces_culled(chunk_data: Array, pos: Vector3, lx: int, ly: int, lz: int, surface_tool: SurfaceTool, voxel_type: int) -> void:
	# Color based on voxel type
	var color = Color.WHITE
	if voxel_type == 1:
		color = Color(0.2, 0.6, 0.2)  # Grass (darker, more natural green)

	var p = pos  # Position shorthand
	var s = 1.0  # Size (each voxel is 1x1x1)

	# Top face (+Y) - only if block above is air
	if not _is_solid(chunk_data, lx, ly + 1, lz):
		_add_quad(surface_tool,
			p + Vector3(0, s, 0),
			p + Vector3(s, s, 0),
			p + Vector3(s, s, s),
			p + Vector3(0, s, s),
			Vector3.UP, color)

	# Bottom face (-Y) - only if block below is air
	if not _is_solid(chunk_data, lx, ly - 1, lz):
		_add_quad(surface_tool,
			p + Vector3(0, 0, s),
			p + Vector3(s, 0, s),
			p + Vector3(s, 0, 0),
			p + Vector3(0, 0, 0),
			Vector3.DOWN, color)

	# Front face (+Z) - only if block in front is air
	if not _is_solid(chunk_data, lx, ly, lz + 1):
		_add_quad(surface_tool,
			p + Vector3(0, 0, s),
			p + Vector3(s, 0, s),
			p + Vector3(s, s, s),
			p + Vector3(0, s, s),
			Vector3.FORWARD, color)

	# Back face (-Z) - only if block behind is air
	if not _is_solid(chunk_data, lx, ly, lz - 1):
		_add_quad(surface_tool,
			p + Vector3(s, 0, 0),
			p + Vector3(0, 0, 0),
			p + Vector3(0, s, 0),
			p + Vector3(s, s, 0),
			Vector3.BACK, color)

	# Right face (+X) - only if block to right is air
	if not _is_solid(chunk_data, lx + 1, ly, lz):
		_add_quad(surface_tool,
			p + Vector3(s, 0, 0),
			p + Vector3(s, 0, s),
			p + Vector3(s, s, s),
			p + Vector3(s, s, 0),
			Vector3.RIGHT, color)

	# Left face (-X) - only if block to left is air
	if not _is_solid(chunk_data, lx - 1, ly, lz):
		_add_quad(surface_tool,
			p + Vector3(0, 0, s),
			p + Vector3(0, 0, 0),
			p + Vector3(0, s, 0),
			p + Vector3(0, s, s),
			Vector3.LEFT, color)

## Add cube faces at a given position (OLD - keeping for reference)
func _add_cube_faces(pos: Vector3, surface_tool: SurfaceTool, voxel_type: int) -> void:
	# Color based on voxel type
	var color = Color.WHITE
	if voxel_type == 1:
		color = Color(0.2, 0.6, 0.2)  # Grass (darker, more natural green)

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

## Add a quad (2 triangles) to the surface with UV coordinates
func _add_quad(surface_tool: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, normal: Vector3, color: Color) -> void:
	surface_tool.set_normal(normal)
	surface_tool.set_color(color)

	# UV coordinates for texture mapping (0,0 to 1,1)
	var uv0 = Vector2(0, 0)
	var uv1 = Vector2(1, 0)
	var uv2 = Vector2(1, 1)
	var uv3 = Vector2(0, 1)

	# First triangle
	surface_tool.set_uv(uv0)
	surface_tool.add_vertex(v0)
	surface_tool.set_uv(uv1)
	surface_tool.add_vertex(v1)
	surface_tool.set_uv(uv2)
	surface_tool.add_vertex(v2)

	# Second triangle
	surface_tool.set_uv(uv0)
	surface_tool.add_vertex(v0)
	surface_tool.set_uv(uv2)
	surface_tool.add_vertex(v2)
	surface_tool.set_uv(uv3)
	surface_tool.add_vertex(v3)
