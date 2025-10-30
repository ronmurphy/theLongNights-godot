#tool
extends VoxelGeneratorScript

const Structure = preload("./structure.gd")
const TreeGenerator = preload("./tree_generator.gd")
const HeightmapCurve = preload("./heightmap_curve.tres")

# TODO Don't hardcode, get by name from library somehow
const AIR = 0
const DIRT = 1
const GRASS = 2
const LOG = 3  # log_x
const LOG_Y = 4
const LOG_Z = 5
const STAIRS_NX = 6
const PLANKS = 7
const TALL_GRASS = 8
const STAIRS_NZ = 9
const STAIRS_PX = 10
const STAIRS_PZ = 11
const GLASS = 12
const WATER_TOP = 13
const WATER_FULL = 14
const RAIL_X = 15
const RAIL_Z = 16
const RAIL_TURN_NX = 17
const RAIL_TURN_PX = 18
const RAIL_TURN_NZ = 19
const RAIL_TURN_PZ = 20
const RAIL_SLOPE_NX = 21
const RAIL_SLOPE_PX = 22
const RAIL_SLOPE_NZ = 23
const RAIL_SLOPE_PZ = 24
const LEAVES = 25
const DEAD_SHRUB = 26
const PUMPKIN = 27
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
const BIRCH_LOG_X = 37
const BIRCH_LOG_Z = 38
const WATER_BLOCK_ = 39
const WATER_BARREL = 40
const BOX = 41
const CRATE = 42
const PUSH_BLOCK = 43
const SAND = 44
const SAND_STONE = 45
const TEST = 46


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
	tree_generator.log_type = LOG_Y  # Use vertical logs (Y axis)
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


func _generate_block(buffer: VoxelBuffer, origin_in_voxels: Vector3i, _lod: int):
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
		# Deep underground below heightmap - fill with stone/ores/bedrock
		_fill_deep_underground(buffer, origin_in_voxels.y, block_size, chunk_pos)

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
				
				# For each vertical position, check if we're above or below heightmap
				for y in block_size:
					var world_y = oy + y
					
					# Below heightmap minimum (-32), use deep underground generation
					if world_y < _heightmap_min_y:
						if world_y == -256:
							buffer.set_voxel(BEDROCK, x, y, z, _CHANNEL)
						elif world_y > -256:
							# Generate stone with ores
							var block_type = STONE
							
							# Depth-based dirt pockets
							if world_y > -64 and rng.randf() < 0.1:
								block_type = DIRT
							elif world_y > -128 and world_y <= -64 and rng.randf() < 0.05:
								block_type = DIRT
							elif world_y > -200 and world_y <= -128 and rng.randf() < 0.02:
								block_type = DIRT
							
							buffer.set_voxel(block_type, x, y, z, _CHANNEL)
							
							# Add ores to stone
							if block_type == STONE:
								var iron_chance = 0.04 if world_y > -64 else (0.06 if world_y > -128 else (0.08 if world_y > -200 else 0.10))
								if rng.randf() < iron_chance:
									buffer.set_voxel(IRON_ORE, x, y, z, _CHANNEL)
								else:
									var gold_chance = 0.0
									if world_y <= -64 and world_y > -128:
										gold_chance = 0.03
									elif world_y <= -128 and world_y > -200:
										gold_chance = 0.06
									elif world_y <= -200:
										gold_chance = 0.08
									if gold_chance > 0 and rng.randf() < gold_chance:
										buffer.set_voxel(GOLD_ORE, x, y, z, _CHANNEL)
					
					# Within heightmap range, use normal terrain generation
					elif y < relative_height:
						# Fill with dirt below the surface
						if y < relative_height - 1:
							buffer.set_voxel(DIRT, x, y, z, _CHANNEL)
						# Top block of terrain (surface)
						elif y == relative_height - 1 and height >= 0:
							buffer.set_voxel(GRASS, x, y, z, _CHANNEL)
						else:
							buffer.set_voxel(DIRT, x, y, z, _CHANNEL)
					# Place foliage on top of grass
					elif y == relative_height and height >= 0 and y > 0:
						var below_block = buffer.get_voxel(x, y - 1, z, _CHANNEL)
						if below_block == GRASS and rng.randf() < 0.2:
							var foliage = TALL_GRASS
							if rng.randf() < 0.1:
								foliage = DEAD_SHRUB
							elif rng.randf() < (0.4 if WorldManager.is_halloween_world() else 0.05):
								foliage = PUMPKIN
							buffer.set_voxel(foliage, x, y, z, _CHANNEL)
					# Water
					elif height < 0 and world_y < 0 and world_y >= height:
						if world_y == -1:
							buffer.set_voxel(WATER_TOP, x, y, z, _CHANNEL)
						else:
							buffer.set_voxel(WATER_FULL, x, y, z, _CHANNEL)
						
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


# Fill deep underground (below heightmap min at y=-32 down to bedrock at y=-256)
func _fill_deep_underground(buffer: VoxelBuffer, chunk_y: int, block_size: int, chunk_pos: Vector3):
	var rng := RandomNumberGenerator.new()
	rng.seed = _get_chunk_seed_2d(chunk_pos)
	
	for y in block_size:
		var world_y = chunk_y + y
		
		# Bedrock layer at y=-256
		if world_y == -256:
			buffer.fill_area(BEDROCK, Vector3(0, y, 0), Vector3(block_size, y + 1, block_size), _CHANNEL)
			continue
		
		# Below bedrock layer, nothing generates
		if world_y < -256:
			buffer.fill_area(AIR, Vector3(0, y, 0), Vector3(block_size, y + 1, block_size), _CHANNEL)
			continue
		
		# Above bedrock, generate stone with ores
		for x in block_size:
			for z in block_size:
				var block_type = STONE
				
				# Depth-based distribution
				if world_y > -64:
					# y=-32 to y=-64: 90% stone, 10% dirt pockets
					if rng.randf() < 0.1:
						block_type = DIRT
				elif world_y > -128:
					# y=-64 to y=-128: 95% stone, 5% dirt
					if rng.randf() < 0.05:
						block_type = DIRT
				elif world_y > -200:
					# y=-128 to y=-200: 98% stone, 2% dirt
					if rng.randf() < 0.02:
						block_type = DIRT
				# else: y=-200 to y=-257: 100% stone
				
				# Place the base block (stone or dirt)
				buffer.set_voxel(block_type, x, y, z, _CHANNEL)
				
				# Add ores (only in stone blocks)
				if block_type == STONE:
					# Iron ore distribution by depth
					var iron_chance = 0.0
					if world_y > -64:
						iron_chance = 0.04  # 4% at shallow depths
					elif world_y > -128:
						iron_chance = 0.06  # 6% at medium depths
					elif world_y > -200:
						iron_chance = 0.08  # 8% at deep depths
					else:
						iron_chance = 0.10  # 10% very deep
					
					if rng.randf() < iron_chance:
						buffer.set_voxel(IRON_ORE, x, y, z, _CHANNEL)
						continue  # Don't place gold if we placed iron
					
					# Gold ore distribution by depth
					var gold_chance = 0.0
					if world_y <= -64 and world_y > -128:
						gold_chance = 0.03  # 3% starts appearing
					elif world_y <= -128 and world_y > -200:
						gold_chance = 0.06  # 6% more common deeper
					elif world_y <= -200:
						gold_chance = 0.08  # 8% very deep
					
					if gold_chance > 0 and rng.randf() < gold_chance:
						buffer.set_voxel(GOLD_ORE, x, y, z, _CHANNEL)


func _get_height_at(x: int, z: int) -> int:
	var t = 0.5 + 0.5 * _heightmap_noise.get_noise_2d(x, z)
	return int(HeightmapCurve.sample_baked(t))
