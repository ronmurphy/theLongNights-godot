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
const ICE = 47
const CHEST = 48
const RUST_BLOCK = 49
const RUST_PIPE = 50
const RUST_CUBE = 51
const RUST_FLOOR = 52


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
var _cave_noise := FastNoiseLite.new()
var _biome_noise := FastNoiseLite.new()
var _rust_hills_noise := FastNoiseLite.new()
var _island_noise := FastNoiseLite.new()
var _trees_min_y := 0
var _trees_max_y := 0

# Cave and depth constants
const BEDROCK_LEVEL = -512
const CAVE_THRESHOLD = 0.35  # Higher = bigger caves
const MIN_CAVE_HEIGHT = -10  # Caves start just below surface


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

	# Initialize 3D cave noise for cave carving
	_cave_noise.seed = world_seed + 1000  # Different seed for caves
	_cave_noise.frequency = 1.0 / 32.0  # Smaller = larger cave systems
	_cave_noise.fractal_octaves = 3
	_cave_noise.noise_type = FastNoiseLite.TYPE_PERLIN

	# Initialize biome noise for depth-based biome variation
	_biome_noise.seed = world_seed + 2000
	_biome_noise.frequency = 1.0 / 64.0
	_biome_noise.fractal_octaves = 2

	# Initialize rust hills noise for bedrock floor coating
	_rust_hills_noise.seed = world_seed + 3000
	_rust_hills_noise.frequency = 1.0 / 24.0  # Rolling hills
	_rust_hills_noise.fractal_octaves = 3
	_rust_hills_noise.noise_type = FastNoiseLite.TYPE_PERLIN

	# Initialize island placement noise for large landmark islands
	_island_noise.seed = world_seed + 4000
	_island_noise.frequency = 1.0 / 120.0  # Large scale, sparse islands
	_island_noise.fractal_octaves = 2
	_island_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	_island_noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN

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
					
					# Below heightmap minimum, use deep underground generation with caves
					if world_y < _heightmap_min_y:
						# 2-block thick bedrock layer at the bottom
						if world_y == BEDROCK_LEVEL or world_y == BEDROCK_LEVEL + 1:
							buffer.set_voxel(BEDROCK, x, y, z, _CHANNEL)
						# Rust hills coating on bedrock (Y -510 upward)
						elif world_y > BEDROCK_LEVEL + 1 and world_y <= BEDROCK_LEVEL + 12:
							var global_x = gx
							var global_z = gz
							var hill_height = _get_rust_hills_height(global_x, global_z)
							var hill_top_y = BEDROCK_LEVEL + 2 + hill_height  # +2 for bedrock layers

							if world_y <= hill_top_y:
								# Rust hills - mix of rust blocks and stone
								var rust_rng := RandomNumberGenerator.new()
								rust_rng.seed = global_x ^ (global_z * 31) ^ (world_y * 13)

								if rust_rng.randf() < 0.6:
									buffer.set_voxel(RUST_BLOCK, x, y, z, _CHANNEL)
								elif rust_rng.randf() < 0.3:
									buffer.set_voxel(RUST_CUBE, x, y, z, _CHANNEL)
								else:
									buffer.set_voxel(STONE, x, y, z, _CHANNEL)
							else:
								# Above rust hills, continue with normal cave generation
								if _is_cave(global_x, world_y, global_z):
									buffer.set_voxel(AIR, x, y, z, _CHANNEL)
								else:
									var is_wall = false
									if _is_cave(global_x + 1, world_y, global_z) or \
									   _is_cave(global_x - 1, world_y, global_z) or \
									   _is_cave(global_x, world_y + 1, global_z) or \
									   _is_cave(global_x, world_y - 1, global_z) or \
									   _is_cave(global_x, world_y, global_z + 1) or \
									   _is_cave(global_x, world_y, global_z - 1):
										is_wall = true
									var block_type = _get_depth_biome_block(world_y, global_x, global_z, rng, is_wall)
									if block_type == STONE:
										if world_y > -64 and rng.randf() < 0.08:
											block_type = DIRT
										elif world_y > -128 and world_y <= -64 and rng.randf() < 0.04:
											block_type = DIRT
										elif world_y > -200 and world_y <= -128 and rng.randf() < 0.02:
											block_type = DIRT
										var iron_chance = 0.04 if world_y > -64 else (0.06 if world_y > -128 else (0.08 if world_y > -200 else 0.10))
										if rng.randf() < iron_chance:
											block_type = IRON_ORE
										else:
											var gold_chance = 0.0
											if world_y <= -64 and world_y > -128:
												gold_chance = 0.03
											elif world_y <= -128 and world_y > -200:
												gold_chance = 0.06
											elif world_y <= -200:
												gold_chance = 0.08
											if gold_chance > 0 and rng.randf() < gold_chance:
												block_type = GOLD_ORE
									buffer.set_voxel(block_type, x, y, z, _CHANNEL)
						elif world_y > BEDROCK_LEVEL + 12:
							# Check if this position should be a cave
							var global_x = gx
							var global_z = gz

							if _is_cave(global_x, world_y, global_z):
								# Carve out cave (air)
								buffer.set_voxel(AIR, x, y, z, _CHANNEL)
							else:
								# Solid underground - use depth biome blocks
								var is_wall = false
								# Check if adjacent to cave (wall detection)
								if _is_cave(global_x + 1, world_y, global_z) or \
								   _is_cave(global_x - 1, world_y, global_z) or \
								   _is_cave(global_x, world_y + 1, global_z) or \
								   _is_cave(global_x, world_y - 1, global_z) or \
								   _is_cave(global_x, world_y, global_z + 1) or \
								   _is_cave(global_x, world_y, global_z - 1):
									is_wall = true

								var block_type = _get_depth_biome_block(world_y, global_x, global_z, rng, is_wall)

								# Override with ores if stone
								if block_type == STONE:
									# Depth-based dirt pockets
									if world_y > -64 and rng.randf() < 0.08:
										block_type = DIRT
									elif world_y > -128 and world_y <= -64 and rng.randf() < 0.04:
										block_type = DIRT
									elif world_y > -200 and world_y <= -128 and rng.randf() < 0.02:
										block_type = DIRT

									# Add ores to stone
									var iron_chance = 0.04 if world_y > -64 else (0.06 if world_y > -128 else (0.08 if world_y > -200 else 0.10))
									if rng.randf() < iron_chance:
										block_type = IRON_ORE
									else:
										var gold_chance = 0.0
										if world_y <= -64 and world_y > -128:
											gold_chance = 0.03
										elif world_y <= -128 and world_y > -200:
											gold_chance = 0.06
										elif world_y <= -200:
											gold_chance = 0.08
										if gold_chance > 0 and rng.randf() < gold_chance:
											block_type = GOLD_ORE

								buffer.set_voxel(block_type, x, y, z, _CHANNEL)
					
					# Within heightmap range, use normal terrain generation
					elif y < relative_height:
						# Check if this position should be carved as a cave entrance
						if world_y < MIN_CAVE_HEIGHT and _is_cave(gx, world_y, gz):
							# Carve cave entrance - leave as air
							buffer.set_voxel(AIR, x, y, z, _CHANNEL)
						else:
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


# Fill deep underground (below heightmap min down to bedrock)
func _fill_deep_underground(buffer: VoxelBuffer, chunk_y: int, block_size: int, chunk_pos: Vector3):
	var rng := RandomNumberGenerator.new()
	rng.seed = _get_chunk_seed_2d(chunk_pos)

	# Calculate global x/z origin for this chunk
	var origin_x = int(chunk_pos.x * block_size)
	var origin_z = int(chunk_pos.z * block_size)

	for y in block_size:
		var world_y = chunk_y + y

		# 2-block thick bedrock layer at bottom
		if world_y == BEDROCK_LEVEL or world_y == BEDROCK_LEVEL + 1:
			buffer.fill_area(BEDROCK, Vector3(0, y, 0), Vector3(block_size, y + 1, block_size), _CHANNEL)
			continue

		# Below bedrock layer, nothing generates
		if world_y < BEDROCK_LEVEL:
			buffer.fill_area(AIR, Vector3(0, y, 0), Vector3(block_size, y + 1, block_size), _CHANNEL)
			continue

		# Rust hills coating on bedrock (Y -510 to ~-500)
		if world_y > BEDROCK_LEVEL + 1 and world_y <= BEDROCK_LEVEL + 12:
			for x in block_size:
				for z in block_size:
					var global_x = origin_x + x
					var global_z = origin_z + z
					var hill_height = _get_rust_hills_height(global_x, global_z)
					var hill_top_y = BEDROCK_LEVEL + 2 + hill_height  # +2 for bedrock layers

					if world_y <= hill_top_y:
						# Rust hills - mix of rust blocks and stone
						var rust_rng := RandomNumberGenerator.new()
						rust_rng.seed = global_x ^ (global_z * 31) ^ (world_y * 13)

						if rust_rng.randf() < 0.6:
							buffer.set_voxel(RUST_BLOCK, x, y, z, _CHANNEL)
						elif rust_rng.randf() < 0.3:
							buffer.set_voxel(RUST_CUBE, x, y, z, _CHANNEL)
						else:
							buffer.set_voxel(STONE, x, y, z, _CHANNEL)
					else:
						# Above rust hills - air (will be filled with caves/stone below)
						buffer.set_voxel(AIR, x, y, z, _CHANNEL)
			continue

		# Above rust hills, generate stone with ores and caves
		for x in block_size:
			for z in block_size:
				var global_x = origin_x + x
				var global_z = origin_z + z

				# Check if this position should be a cave
				if _is_cave(global_x, world_y, global_z):
					buffer.set_voxel(AIR, x, y, z, _CHANNEL)
					continue

				# Solid underground - determine if wall
				var is_wall = false
				if _is_cave(global_x + 1, world_y, global_z) or \
				   _is_cave(global_x - 1, world_y, global_z) or \
				   _is_cave(global_x, world_y + 1, global_z) or \
				   _is_cave(global_x, world_y - 1, global_z) or \
				   _is_cave(global_x, world_y, global_z + 1) or \
				   _is_cave(global_x, world_y, global_z - 1):
					is_wall = true

				var block_type = _get_depth_biome_block(world_y, global_x, global_z, rng, is_wall)

				# Override with ores/dirt if base stone
				if block_type == STONE:
					# Depth-based dirt pockets
					if world_y > -64 and rng.randf() < 0.08:
						block_type = DIRT
					elif world_y > -128 and world_y <= -64 and rng.randf() < 0.04:
						block_type = DIRT
					elif world_y > -200 and world_y <= -128 and rng.randf() < 0.02:
						block_type = DIRT

					# Add ores (only to stone)
					if block_type == STONE:
						# Iron ore distribution by depth
						var iron_chance = 0.04 if world_y > -64 else (0.06 if world_y > -128 else (0.08 if world_y > -200 else 0.10))

						if rng.randf() < iron_chance:
							block_type = IRON_ORE
						else:
							# Gold ore distribution by depth
							var gold_chance = 0.0
							if world_y <= -64 and world_y > -128:
								gold_chance = 0.03
							elif world_y <= -128 and world_y > -200:
								gold_chance = 0.06
							elif world_y <= -200:
								gold_chance = 0.08

							if gold_chance > 0 and rng.randf() < gold_chance:
								block_type = GOLD_ORE

				# Place the final block
				buffer.set_voxel(block_type, x, y, z, _CHANNEL)


func _get_height_at(x: int, z: int) -> int:
	var t = 0.5 + 0.5 * _heightmap_noise.get_noise_2d(x, z)
	return int(HeightmapCurve.sample_baked(t))


func _get_rust_hills_height(x: int, z: int) -> int:
	"""Get height of rust hills on bedrock floor (0-10 blocks above bedrock)"""
	var noise_value = _rust_hills_noise.get_noise_2d(x, z)
	# Map noise from [-1, 1] to [0, 10] for hill height
	var height = int((noise_value + 1.0) * 5.0)
	return clamp(height, 0, 10)


func _is_in_large_island_zone(x: int, y: int, z: int) -> bool:
	"""Check if position is within a large landmark island zone"""
	# Define key depth levels with their island sizes (radius)
	var island_depths = {
		-150: 15,  # 30x30 island (radius 15)
		-250: 20,  # 40x40 island (radius 20)
		-350: 25   # 50x50 island (radius 25)
	}

	# Check each depth level
	for depth in island_depths.keys():
		var radius = island_depths[depth]
		var vertical_tolerance = 8  # Island extends ±8 blocks vertically

		# Check if Y is within this island's vertical range
		if abs(y - depth) <= vertical_tolerance:
			# Use cellular noise to create sparse island centers
			var noise_value = _island_noise.get_noise_2d(x, z)

			# Threshold for island center (only create islands where noise is high)
			# This makes islands sparse - not every location gets one
			if noise_value > 0.6:  # Only top 40% of noise values = islands
				return true

	return false


# Check if position should be carved as cave using 3D noise
func _is_cave(x: int, y: int, z: int) -> bool:
	# Don't carve caves above MIN_CAVE_HEIGHT or at/below bedrock
	if y > MIN_CAVE_HEIGHT or y <= BEDROCK_LEVEL:
		return false

	# Protect large landmark islands from being carved
	if _is_in_large_island_zone(x, y, z):
		return false

	# Use 3D Perlin noise to determine cave structure
	var noise_value = _cave_noise.get_noise_3d(x, y, z)

	# Apply depth-based cave density (more caves deeper down)
	var depth_factor = 1.0
	if y < -200:
		depth_factor = 1.2  # More caves in the abyss
	elif y < -100:
		depth_factor = 1.1  # Slightly more caves at medium depth

	return abs(noise_value * depth_factor) < CAVE_THRESHOLD


# Get biome-specific block type based on depth and biome noise
func _get_depth_biome_block(y: int, x: int, z: int, rng: RandomNumberGenerator, is_wall: bool) -> int:
	var biome_value = _biome_noise.get_noise_2d(x, z)

	# Depth-based biome layers
	if y > -150:
		# GOBLIN TUNNELS (Y=-10 to -150)
		# Wood-supported tunnels with occasional goblin structures
		if is_wall:
			# Mostly stone/dirt with occasional wood supports
			if rng.randf() < 0.05:
				return PLANKS  # Wood support beam
			elif rng.randf() < 0.3:
				return DIRT
			else:
				return STONE
		else:
			return STONE  # Floor

	elif y > -300:
		# UNDEAD CRYPTS (Y=-150 to -300)
		# Ancient stone tombs and crypts
		if is_wall:
			if rng.randf() < 0.15:
				return RUIN_STONE  # Ancient carved stone
			elif rng.randf() < 0.1:
				return RUIN_FLOOR  # Decorative floor tiles
			else:
				return STONE
		else:
			return RUIN_FLOOR if rng.randf() < 0.3 else STONE

	elif y > -400:
		# MECHANICAL WARRENS (Y=-300 to -400)
		# Industrial/mechanical structures with rust blocks
		if is_wall:
			# Rust pipes on walls (vertical structures)
			if rng.randf() < 0.15:
				return RUST_PIPE  # Rusted pipes
			elif rng.randf() < 0.12:
				return RUST_BLOCK  # Rust-covered stone
			elif rng.randf() < 0.08:
				return IRON_ORE  # Exposed metal ore
			elif rng.randf() < 0.05:
				return BOX  # Metal crates
			else:
				return STONE
		else:
			# Rust floors mixed with stone
			if rng.randf() < 0.2:
				return RUST_CUBE  # Rusted floor tiles
			elif rng.randf() < 0.1:
				return RUST_BLOCK  # Mixed rust blocks
			else:
				return STONE

	else:
		# FLOODED CAVERNS / ABYSS (Y=-400 to -512)
		# Water-filled dangerous depths
		# Use special stone variants and water
		if is_wall:
			if rng.randf() < 0.2:
				return SAND_STONE  # Weathered stone
			elif rng.randf() < 0.1:
				return GOLD_ORE  # Rare ores more common
			else:
				return STONE
		else:
			# Floor often has water
			if rng.randf() < 0.4:
				return WATER_FULL
			else:
				return STONE

	return STONE  # Default
