#tool
extends VoxelGeneratorScript

const Structure = preload("./structure.gd")
const TreeGenerator = preload("./tree_generator.gd")
const HeightmapCurve = preload("./heightmap_curve.tres")

# TODO Don't hardcode, get by name from library somehow
const AIR = 0
const DIRT = 1
const GRASS = 2
const LOG = 3
const TALL_GRASS = 6
const WATER = 8
const WATER_FULL = 14
const WATER_TOP = 13
const LEAVES = 10
const DEAD_SHRUB = 11
const PUMPKIN = 12
# New blocks added Oct 28, 2025
const BEDROCK = 28
const STONE = 29
const GOLD_ORE = 30
const IRON_ORE = 31
const TILLED_DIRT = 32
const RUIN_STONE = 33
const RUIN_FLOOR = 34
const TELEPORT_STONE = 35
const BIRCH_LOG = 36  # birch_log_y variant
const WATER_BLOCK_ = 38
const WATER_BARREL = 37

const _CHANNEL = VoxelBuffer.CHANNEL_TYPE

const _moore_dirs = [
	Vector3(-1, 0, -1),
	Vector3(0, 0, -1),
	Vector3(1, 0, -1),
	Vector3(-1, 0, 0),
	Vector3(1, 0, 0),
	Vector3(-1, 0, 1),
	Vector3(0, 0, 1),
	Vector3(1, 0, 1)
]


var _tree_structures := []

var _heightmap_min_y := int(HeightmapCurve.min_value)
var _heightmap_max_y := int(HeightmapCurve.max_value)
var _heightmap_range := 0
var _heightmap_noise := FastNoiseLite.new()
var _trees_min_y := 0
var _trees_max_y := 0


func _init():
	# Get seed from world.config if it exists
	var world_seed = 131183  # Default seed

	# Try to load seed from world.config file directly
	var config_path = "user://save/world.config"
	if FileAccess.file_exists(config_path):
		var file = FileAccess.open(config_path, FileAccess.READ)
		if file != null:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_string) == OK:
				var data = json.data
				if typeof(data) == TYPE_DICTIONARY and "seed" in data:
					world_seed = data["seed"]
					print("Generator: Loaded seed from world.config: ", world_seed)

	print("Generator: Using world seed: ", world_seed)

	# Use seed for tree generation
	var tree_rng = RandomNumberGenerator.new()
	tree_rng.seed = world_seed

	var tree_generator = TreeGenerator.new()
	tree_generator.log_type = LOG
	tree_generator.leaves_type = LEAVES
	for i in 16:
		var s = tree_generator.generate()
		_tree_structures.append(s)

	var tallest_tree_height = 0
	for structure in _tree_structures:
		var h = int(structure.voxels.get_size().y)
		if tallest_tree_height < h:
			tallest_tree_height = h
	_trees_min_y = _heightmap_min_y
	_trees_max_y = _heightmap_max_y + tallest_tree_height

	# Set the heightmap noise seed from WorldManager
	_heightmap_noise.seed = world_seed
	_heightmap_noise.frequency = 1.0 / 128.0
	_heightmap_noise.fractal_octaves = 4

	# IMPORTANT
	# If we don't do this `Curve` could bake itself when interpolated,
	# and this causes crashes when used in multiple threads
	HeightmapCurve.bake()


func _get_used_channels_mask() -> int:
	return 1 << _CHANNEL


func _generate_block(buffer: VoxelBuffer, origin_in_voxels: Vector3i, lod: int):
	# TODO There is an issue doing this, need to investigate why because it should be supported
	# Saves from this demo used 8-bit, which is no longer the default
	# buffer.set_channel_depth(_CHANNEL, VoxelBuffer.DEPTH_8_BIT)

	# Assuming input is cubic in our use case (it doesn't have to be!)
	var block_size := int(buffer.get_size().x)
	var oy := origin_in_voxels.y
	# TODO This hardcodes a cubic block size of 16, find a non-ugly way...
	# Dividing is a false friend because of negative values
	var chunk_pos := Vector3(
		origin_in_voxels.x >> 4,
		origin_in_voxels.y >> 4,
		origin_in_voxels.z >> 4)

	_heightmap_range = _heightmap_max_y - _heightmap_min_y

	# Ground

	if origin_in_voxels.y > _heightmap_max_y:
		buffer.fill(AIR, _CHANNEL)

	elif origin_in_voxels.y + block_size < _heightmap_min_y:
		buffer.fill(DIRT, _CHANNEL)

	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = _get_chunk_seed_2d(chunk_pos)
		
		var gx : int
		var gz := origin_in_voxels.z

		for z in block_size:
			gx = origin_in_voxels.x

			for x in block_size:
				var height := _get_height_at(gx, gz)
				var relative_height := height - oy
				
				# Dirt and grass
				if relative_height > block_size:
					buffer.fill_area(DIRT,
						Vector3(x, 0, z), Vector3(x + 1, block_size, z + 1), _CHANNEL)
					# Add ore/stone in deeper underground layers
					_add_ores_to_column(buffer, x, z, 0, block_size, oy, rng)
				elif relative_height > 0:
					buffer.fill_area(DIRT,
						Vector3(x, 0, z), Vector3(x + 1, relative_height, z + 1), _CHANNEL)
					# Add ore/stone to underground blocks
					_add_ores_to_column(buffer, x, z, 0, relative_height, oy, rng)
					if height >= 0:
						buffer.set_voxel(GRASS, x, relative_height - 1, z, _CHANNEL)
						if relative_height < block_size and rng.randf() < 0.2:
							var foliage = TALL_GRASS
							if rng.randf() < 0.1:
								foliage = DEAD_SHRUB
							elif rng.randf() < (0.4 if WorldManager.is_halloween_world() else 0.05):
								# 40% chance for pumpkins on Halloween! 🎃 Otherwise 5%
								foliage = PUMPKIN
							buffer.set_voxel(foliage, x, relative_height, z, _CHANNEL)
				
				# Water
				if height < 0 and oy < 0:
					var start_relative_height := 0
					if relative_height > 0:
						start_relative_height = relative_height
					buffer.fill_area(WATER_FULL,
						Vector3(x, start_relative_height, z), 
						Vector3(x + 1, block_size, z + 1), _CHANNEL)
					if oy + block_size == 0:
						# Surface block
						buffer.set_voxel(WATER_TOP, x, block_size - 1, z, _CHANNEL)
						
				gx += 1

			gz += 1

	# Trees

	if origin_in_voxels.y <= _trees_max_y and origin_in_voxels.y + block_size >= _trees_min_y:
		var voxel_tool := buffer.get_voxel_tool()
		var structure_instances := []
			
		_get_tree_instances_in_chunk(chunk_pos, origin_in_voxels, block_size, structure_instances)
	
		# Relative to current block
		var block_aabb := AABB(Vector3(), buffer.get_size() + Vector3i(1, 1, 1))

		for dir in _moore_dirs:
			var ncpos : Vector3 = (chunk_pos + dir).round()
			_get_tree_instances_in_chunk(ncpos, origin_in_voxels, block_size, structure_instances)

		for structure_instance in structure_instances:
			var pos : Vector3 = structure_instance[0]
			var structure : Structure = structure_instance[1]
			var lower_corner_pos := pos - structure.offset
			var aabb := AABB(lower_corner_pos, structure.voxels.get_size() + Vector3i(1, 1, 1))

			if aabb.intersects(block_aabb):
				voxel_tool.paste_masked(lower_corner_pos, 
					structure.voxels, 1 << VoxelBuffer.CHANNEL_TYPE,
					# Masking
					VoxelBuffer.CHANNEL_TYPE, AIR)

	buffer.compress_uniform_channels()


func _get_tree_instances_in_chunk(
	cpos: Vector3, offset: Vector3, chunk_size: int, tree_instances: Array):
		
	var rng := RandomNumberGenerator.new()
	rng.seed = _get_chunk_seed_2d(cpos)

	for i in 4:
		var pos := Vector3(rng.randi() % chunk_size, 0, rng.randi() % chunk_size)
		pos += cpos * chunk_size
		pos.y = _get_height_at(pos.x, pos.z)
		
		if pos.y > 0:
			pos -= offset
			var si := rng.randi() % len(_tree_structures)
			var structure : Structure = _tree_structures[si]
			tree_instances.append([pos.round(), structure])


#static func get_chunk_seed(cpos: Vector3) -> int:
#	return cpos.x ^ (13 * int(cpos.y)) ^ (31 * int(cpos.z))


static func _get_chunk_seed_2d(cpos: Vector3) -> int:
	return int(cpos.x) ^ (31 * int(cpos.z))


# Add ores and stone to underground blocks based on depth
func _add_ores_to_column(buffer: VoxelBuffer, x: int, z: int, start_y: int, end_y: int, chunk_y: int, rng: RandomNumberGenerator):
	for y in range(start_y, end_y):
		var world_y = chunk_y + y
		var current_block = buffer.get_voxel(x, y, z, _CHANNEL)
		
		# Only replace dirt blocks
		if current_block != DIRT:
			continue
		
		# Stone starts appearing below surface (y < 5) and becomes more common deeper
		if world_y < 5:
			var stone_chance = min(0.3 + abs(world_y) * 0.05, 0.8)  # 30% at y=5, up to 80% deep
			if rng.randf() < stone_chance:
				buffer.set_voxel(STONE, x, y, z, _CHANNEL)
				
				# Iron ore spawns in stone (y < 0), 3% chance
				if world_y < 0 and rng.randf() < 0.03:
					buffer.set_voxel(IRON_ORE, x, y, z, _CHANNEL)
				
				# Gold ore spawns deeper (y < -10), 1% chance
				elif world_y < -10 and rng.randf() < 0.01:
					buffer.set_voxel(GOLD_ORE, x, y, z, _CHANNEL)


func _get_height_at(x: int, z: int) -> int:
	var t = 0.5 + 0.5 * _heightmap_noise.get_noise_2d(x, z)
	return int(HeightmapCurve.sample_baked(t))
