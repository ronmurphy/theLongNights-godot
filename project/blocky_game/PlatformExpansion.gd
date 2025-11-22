extends Node

# Generates large sky platforms for base expansion
# Uses RuinSpawner directly - no custom code needed!

var _terrain = null
var _blocks = null


func initialize(terrain_node: Node, blocks_node: Node):
	"""Initialize with terrain and blocks references"""
	_terrain = terrain_node
	_blocks = blocks_node
	print("PlatformExpansion initialized")


func generate_flat_platform(placement_pos: Vector3) -> bool:
	"""Generate a 120x120 flat construction platform using RuinSpawner"""
	print("🏗️ Generating 120x120 Flat Construction Platform at: %s" % placement_pos)

	# Just use RuinSpawner! It handles everything!
	var ruin_spawner = get_node("/root/Main/Game/RuinSpawner")
	if not ruin_spawner:
		push_error("RuinSpawner not found!")
		return false

	# Spawn the flat platform ruin at player's current height
	var result = await ruin_spawner.spawn_ruin_at(placement_pos, "flat_platform_120x120")

	if result != Vector3.ZERO:
		print("✅ Flat construction platform generated successfully!")
		return true
	else:
		print("❌ Failed to generate construction platform")
		return false


func generate_wilderness_platform(placement_pos: Vector3) -> bool:
	"""Generate a 120x120 wilderness platform (flat for now)"""
	print("🌿 Generating 120x120 Wilderness Platform at: %s" % placement_pos)

	# Same as flat platform for now (can add terrain noise later)
	var ruin_spawner = get_node("/root/Main/Game/RuinSpawner")
	if not ruin_spawner:
		push_error("RuinSpawner not found!")
		return false

	var result = await ruin_spawner.spawn_ruin_at(placement_pos, "flat_platform_120x120")

	if result != Vector3.ZERO:
		print("✅ Wilderness platform generated successfully!")
		return true
	else:
		print("❌ Failed to generate wilderness platform")
		return false


func generate_terrain_extraction(placement_pos: Vector3) -> bool:
	"""Generate a terrain extraction platform (flat for now)"""
	print("🌍 Generating Terrain Extraction Platform at: %s" % placement_pos)

	# Same as flat platform for now (can add ground terrain extraction later)
	var ruin_spawner = get_node("/root/Main/Game/RuinSpawner")
	if not ruin_spawner:
		push_error("RuinSpawner not found!")
		return false

	var result = await ruin_spawner.spawn_ruin_at(placement_pos, "flat_platform_120x120")

	if result != Vector3.ZERO:
		print("✅ Terrain extraction platform generated successfully!")
		return true
	else:
		print("❌ Failed to generate extraction platform")
		return false
