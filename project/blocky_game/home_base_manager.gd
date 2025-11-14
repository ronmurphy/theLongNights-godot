extends Node

## HomeBaseManager - Manages home base location and companion roster
## Singleton (AutoLoad) for global access

signal home_base_set(position: Vector3)
signal home_base_cleared()

# Home base state
var home_base_position: Vector3 = Vector3.ZERO
var has_home_base: bool = false
var home_base_ruin_id: String = ""  # If set at a ruin (optional)
var home_structure_node: Node3D = null
var home_structure_tier: int = 0  # 0=cave, 1=tent, 2=shack, 3=cabin, 4=lodge

# Structure tier thresholds
const TIER_THRESHOLDS = {
	0: 0,     # Cave: 0-49 blocks
	1: 50,    # Tent: 50-199 blocks
	2: 200,   # Shack: 200-499 blocks
	3: 500,   # Cabin: 500-999 blocks
	4: 1000   # Lodge: 1000+ blocks
}

const TIER_NAMES = {
	0: "Cave Shelter",
	1: "A-Frame Tent",
	2: "Wooden Shack",
	3: "Log Cabin",
	4: "Two-Story Lodge"
}

# Recycle values (50% return of approximate build cost)
const TIER_RECYCLE_BLOCKS = {
	0: 25,    # Cave returns ~25 blocks
	1: 50,    # Tent returns ~50 blocks
	2: 100,   # Shack returns ~100 blocks
	3: 250,   # Cabin returns ~250 blocks
	4: 500    # Lodge returns ~500 blocks
}

# References
var _game: Node = null
var _player: Node = null

# NPC spawning system
var homebase_set_day: int = -1  # Track what day homebase was set (-1 = not set)
var spawned_npcs: Array = []  # Track spawned NPC nodes
var npc_spawn_pool: Array = []  # Pool of NPCs to spawn
var npcs_to_spawn_index: int = 0  # Current index in spawn pool
var _pending_npc_data: Array = []  # Store NPC data from save until game is ready

# NPC templates (will spawn 1 per day in this order)
const NPC_TEMPLATES = [
	{"name": "Michelle", "race": "human", "gender": "female", "job": "cook", "color": Color(1.0, 0.9, 0.8)},
	{"name": "Mahan", "race": "dwarf", "gender": "male", "job": "blacksmith", "color": Color(0.9, 0.8, 0.7)},
	{"name": "Lydia", "race": "elf", "gender": "female", "job": "merchant", "color": Color(1.0, 0.95, 0.85)},
	{"name": "Daniels", "race": "human", "gender": "male", "job": "armorer", "color": Color(0.85, 0.75, 0.65)},
	{"name": "Zara", "race": "elf", "gender": "female", "job": "ruinkeeper", "color": Color(0.95, 0.9, 1.0)},
]


func _ready():
	print("HomeBaseManager: Initialized")

	# Connect to TimeManager's day_changed signal for NPC spawning
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.day_changed.connect(_on_day_changed)
		print("HomeBaseManager: Connected to TimeManager day_changed signal")
	else:
		push_warning("HomeBaseManager: TimeManager not found - NPC spawning disabled")

	# Initialize NPC spawn pool
	_initialize_npc_pool()


func set_game_reference(game_node: Node):
	"""Set reference to the main game node"""
	_game = game_node
	print("HomeBaseManager: Game reference set")

	# If we have pending NPC data from a load, restore them now
	if _pending_npc_data.size() > 0:
		print("HomeBaseManager: Restoring %d pending NPCs now that game is ready" % _pending_npc_data.size())
		_restore_homebase_npcs(_pending_npc_data)
		_pending_npc_data.clear()


func set_player_reference(player_node: Node):
	"""Set reference to the player node"""
	_player = player_node


func set_home_base(position: Vector3, ruin_id: String = ""):
	"""Establish home base at the given position"""
	home_base_position = position
	has_home_base = true
	home_base_ruin_id = ruin_id

	# Track the day homebase was set
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		homebase_set_day = time_manager.current_day
		print("HomeBaseManager: Homebase set on day %d (Week %d, %s)" % [
			time_manager.current_day,
			time_manager.current_week,
			time_manager.get_day_name()
		])
	
	# Check if we're setting home base in a ruin
	var ruin = RuinRegistry.get_ruin_at_position(position, 100.0)  # 100 block tolerance (increased)

	if ruin:
		# We're in a ruin!
		home_base_ruin_id = ruin.ruin_name
		print("🏠 Home Base established in: %s (%s)" % [ruin.ruin_name, ruin.ruin_type])
		print("   Ruin registered size: %s" % ruin.ruin_size)
		print("   Ruin base position: %s" % ruin.position)
		print("   Homebase set at: %s" % position)
		
		# Check if it's a sky ruin (high Y coordinate)
		if position.y > 100:  # Sky ruins are typically above y=100
			print("   🏰 Sky ruin detected - Will expand platform for home!")
		else:
			print("   🏛️ Ground ruin - Has existing structure space")
	else:
		# On open ground
		print("🏠 Home Base established at: %s" % position)
		if position.y < 80:  # Below typical ruin height
			print("   🌲 Ground level - Plenty of space for structures")
		else:
			print("   ⛰️ Elevated position")
	
	# Build fence around homebase if on a ruin
	if ruin:
		_build_homebase_fence(ruin)

	# NOTE: Homebase tier system removed - full ruin platform is given to player
	# TODO: Structure spawning (cave/tent/lodge) will be added later

	# Relocate benched companions (if any)
	_relocate_benched_companions()

	# Emit signal
	home_base_set.emit(position)


func clear_home_base(recycle: bool = false) -> int:
	"""Remove home base (for relocating). Returns blocks if recycled."""
	var blocks_returned = 0

	if recycle and home_structure_tier >= 0:
		blocks_returned = TIER_RECYCLE_BLOCKS[home_structure_tier]
		print("♻️ Recycling home structure: %d blocks returned" % blocks_returned)

	if home_structure_node:
		home_structure_node.queue_free()
		home_structure_node = null

	# Despawn benched companions
	_despawn_benched_npcs()

	# Despawn homebase NPCs
	_despawn_homebase_npcs()

	has_home_base = false
	home_base_position = Vector3.ZERO
	home_base_ruin_id = ""
	home_structure_tier = 0
	homebase_set_day = -1  # Reset day tracking
	npcs_to_spawn_index = 0  # Reset NPC spawn index

	print("🏠 Home Base cleared")
	home_base_cleared.emit()

	return blocks_returned


func is_player_at_home() -> bool:
	"""Check if player is near home base"""
	if not has_home_base or not _player:
		return false
	
	var distance = _player.global_position.distance_to(home_base_position)
	return distance < 15.0  # Within 15 blocks


func add_benched_companion_npc(comp_data: CompanionManager.CompanionData):
	"""Add a single benched companion NPC to home base"""
	if not has_home_base:
		print("🏕️ No home base set - companion will spawn when home base is created")
		return
	
	# Spawn in a circle - find next available position
	var existing_benched = get_tree().get_nodes_in_group("benched_companions")
	var total_count = existing_benched.size() + 1
	var radius = 5.0
	var angle_step = (2.0 * PI) / total_count
	var angle = angle_step * existing_benched.size()
	
	var offset = Vector3(
		cos(angle) * radius,
		0,
		sin(angle) * radius
	)
	var spawn_pos = home_base_position + offset
	
	spawn_companion_npc(comp_data, spawn_pos)


func _spawn_home_structure():
	"""Spawn the home structure at home base location"""
	# Determine what tier of structure to build based on inventory
	home_structure_tier = _determine_structure_tier()
	var tier_name = TIER_NAMES[home_structure_tier]
	
	print("🏠 Building home structure: %s (Tier %d)" % [tier_name, home_structure_tier])
	
	var ruin = RuinRegistry.get_ruin_at_position(home_base_position, 50.0)
	
	if ruin:
		# In a ruin - check if we need to expand the platform
		var expansion_info = _get_platform_expansion_info(ruin)
		
		if expansion_info.needs_expansion:
			print("🏗️ Ruin needs platform expansion:")
			print("   Current size: %s" % ruin.ruin_size)
			print("   Expanded size: %s" % expansion_info.expanded_size)
			print("   Extra space: %s blocks" % expansion_info.extra_space)
			# TODO: Actually expand the platform in Phase 2
		else:
			print("🏛️ Ruin has sufficient space for home structures")
	else:
		print("🌲 Open ground - No expansion needed")
	
	# TODO: Create home structure scenes (cave/tent/shack/cabin/lodge)
	# For now, just print that we'd spawn it
	print("🏕️ Home structure would spawn here (scene needed for tier %d)" % home_structure_tier)
	
	# When structure scenes exist:
	# var structure_scene = _load_structure_scene(home_structure_tier)
	# if structure_scene:
	#     home_structure_node = structure_scene.instantiate()
	#     home_structure_node.global_position = home_base_position
	#     if _game:
	#         _game.add_child(home_structure_node)


func _determine_structure_tier() -> int:
	"""Determine what tier of home structure to build based on player's inventory"""
	var block_count = _count_placeable_blocks_in_inventory()
	
	print("📦 Player has %d placeable blocks in inventory" % block_count)
	
	# Find highest tier they qualify for
	if block_count >= TIER_THRESHOLDS[4]:
		return 4  # Lodge
	elif block_count >= TIER_THRESHOLDS[3]:
		return 3  # Cabin
	elif block_count >= TIER_THRESHOLDS[2]:
		return 2  # Shack
	elif block_count >= TIER_THRESHOLDS[1]:
		return 1  # Tent
	else:
		return 0  # Cave


func _count_placeable_blocks_in_inventory() -> int:
	"""Count total placeable blocks in player's inventory"""
	if not _player:
		return 0
	
	var inventory = _player.get_node_or_null("Inventory")
	if not inventory:
		return 0
	
	var total = 0
	
	# Get Blocks reference for checking block types
	var blocks = null
	if _game:
		blocks = _game.get_node_or_null("Blocks")
	
	if not blocks:
		return 0
	
	# Inventory uses _slots array, not items dict
	if not inventory.has_method("get_slot_count"):
		# Fallback: try to access _slots directly
		if "_slots" in inventory:
			for slot in inventory._slots:
				if slot and slot.type == 0:  # TYPE_BLOCK = 0
					total += slot.count if "count" in slot else 1
		return total
	
	# Proper method: iterate through slots
	var slot_count = inventory.get_slot_count() if inventory.has_method("get_slot_count") else 0
	for i in range(slot_count):
		var item = inventory.get_slot(i) if inventory.has_method("get_slot") else null
		if item and item.type == 0:  # TYPE_BLOCK = 0 (from InventoryItem)
			total += item.count if "count" in item else 1
	
	return total


func _load_structure_scene(tier: int) -> PackedScene:
	"""Load the appropriate structure scene for the given tier"""
	# TODO: Create these scenes
	match tier:
		0: return null  # preload("res://blocky_game/structures/home_cave.tscn")
		1: return null  # preload("res://blocky_game/structures/home_tent.tscn")
		2: return null  # preload("res://blocky_game/structures/home_shack.tscn")
		3: return null  # preload("res://blocky_game/structures/home_cabin.tscn")
		4: return null  # preload("res://blocky_game/structures/home_lodge.tscn")
		_: return null


func _build_homebase_fence(ruin: RuinRegistry.RuinData) -> void:
	"""Build a 3-block tall planks fence around the ruin perimeter"""
	if not _game:
		push_error("HomeBaseManager: Cannot build fence - game reference not set")
		return

	# Get terrain and blocks references
	var terrain = _game.get_node_or_null("VoxelTerrain")
	if not terrain:
		push_error("HomeBaseManager: Cannot build fence - terrain not found")
		return

	var blocks_node = _game.get_node_or_null("Blocks")
	if not blocks_node:
		push_error("HomeBaseManager: Cannot build fence - blocks node not found")
		return

	# Get planks block
	var planks_block = blocks_node.get_block_by_name("planks")
	if not planks_block:
		push_error("HomeBaseManager: Cannot build fence - planks block not found")
		return

	var planks_voxel_id = planks_block.base_info.voxels[0]

	# Get voxel tool
	var voxel_tool = terrain.get_voxel_tool()
	voxel_tool.channel = VoxelBuffer.CHANNEL_TYPE

	# Calculate ruin boundaries
	var ruin_base = Vector3i(ruin.position)
	var ruin_size = ruin.ruin_size

	# DETECT if size looks like old default (10x10x10) and auto-detect actual platform size
	if ruin_size == Vector3i(10, 10, 10) and not ruin.ruin_type.contains("crashed"):
		print("   ⚠️ Ruin has old default size (10x10x10), scanning for actual platform bounds...")
		ruin_size = _detect_actual_ruin_size(ruin_base, voxel_tool)
		print("   ✓ Detected actual platform size: %s" % ruin_size)

	# Check if this is the crashed ruins by ruin type (not position!)
	var is_crashed_ruins = ruin.ruin_type.contains("crashed")

	var min_corner: Vector3i
	var max_corner: Vector3i

	if is_crashed_ruins:
		# Expand fence area for crashed ruins (small area + Undervoid entrance nearby)
		var expanded_size = 40  # 40x40 area
		var center = Vector3i(ruin.position.x, ruin_base.y, ruin.position.z)  # Use actual ruin position
		min_corner = center - Vector3i(expanded_size / 2, 0, expanded_size / 2)
		max_corner = center + Vector3i(expanded_size / 2, 0, expanded_size / 2)
		print("🔨 Building expanded fence around crashed ruins homebase...")
		print("   Position: %s" % ruin.position)
		print("   Expanded area: %dx%d (to accommodate Undervoid entrance)" % [expanded_size, expanded_size])
	else:
		# Normal ruin fence - use the full ruin platform size
		min_corner = ruin_base
		max_corner = ruin_base + ruin_size
		print("🔨 Building planks fence around %s homebase..." % ruin.ruin_name)
		print("   Platform size: %s (full ruin area)" % ruin_size)
		print("   Fence will enclose entire platform")

	var blocks_placed = 0

	# Get Undervoid entrances to avoid blocking them
	var UndervoidRegistry = get_node_or_null("/root/UndervoidRegistry")
	var entrance_positions: Array = []
	if UndervoidRegistry and UndervoidRegistry.has_method("get_all_entrances"):
		var entrances = UndervoidRegistry.get_all_entrances()
		for entrance in entrances:
			# Check if entrance is within our fence area
			var entrance_pos = Vector3i(entrance.position)
			if entrance_pos.x >= min_corner.x and entrance_pos.x <= max_corner.x and entrance_pos.z >= min_corner.z and entrance_pos.z <= max_corner.z:
				entrance_positions.append(entrance_pos)
				print("   🟣 Detected Undervoid entrance at %s - will leave gap" % entrance_pos)

	# Build 5-block tall fence around perimeter (prevents NPC step-climbing escape)
	# Bottom y level of the ruin (approximate ground level)
	var ground_y = ruin_base.y
	var gap_size = 5  # Leave 5-block gap around entrances

	# Build fence on all 4 sides
	for y_offset in range(5):  # 5 blocks tall (NPCs can step 2 blocks high)
		var y = ground_y + y_offset

		# North side (min Z)
		for x in range(min_corner.x, max_corner.x + 1):
			var pos = Vector3i(x, y, min_corner.z)
			if not _is_near_entrance(pos, entrance_positions, gap_size):
				voxel_tool.set_voxel(pos, planks_voxel_id)
				blocks_placed += 1

		# South side (max Z)
		for x in range(min_corner.x, max_corner.x + 1):
			var pos = Vector3i(x, y, max_corner.z)
			if not _is_near_entrance(pos, entrance_positions, gap_size):
				voxel_tool.set_voxel(pos, planks_voxel_id)
				blocks_placed += 1

		# West side (min X) - skip corners to avoid overlap
		for z in range(min_corner.z + 1, max_corner.z):
			var pos = Vector3i(min_corner.x, y, z)
			if not _is_near_entrance(pos, entrance_positions, gap_size):
				voxel_tool.set_voxel(pos, planks_voxel_id)
				blocks_placed += 1

		# East side (max X) - skip corners to avoid overlap
		for z in range(min_corner.z + 1, max_corner.z):
			var pos = Vector3i(max_corner.x, y, z)
			if not _is_near_entrance(pos, entrance_positions, gap_size):
				voxel_tool.set_voxel(pos, planks_voxel_id)
				blocks_placed += 1

	print("✓ Fence complete! Placed %d planks blocks" % blocks_placed)


func _is_near_entrance(pos: Vector3i, entrance_positions: Array, gap_size: int) -> bool:
	"""Check if position is near any Undervoid entrance (within gap_size)"""
	for entrance_pos in entrance_positions:
		var distance = Vector2(pos.x - entrance_pos.x, pos.z - entrance_pos.z).length()
		if distance <= gap_size:
			return true
	return false


func _detect_actual_ruin_size(ruin_base: Vector3i, voxel_tool: VoxelTool) -> Vector3i:
	"""Scan outward from ruin base to detect actual platform size by finding grass/dirt edges"""
	var max_scan = 60  # Don't scan more than 60 blocks in any direction
	var ground_y = ruin_base.y

	# Scan for X bounds (min and max)
	var min_x = ruin_base.x
	var max_x = ruin_base.x
	for x in range(ruin_base.x - max_scan, ruin_base.x + max_scan):
		var block_id = voxel_tool.get_voxel(Vector3i(x, ground_y, ruin_base.z))
		if block_id != 0:  # Not air
			min_x = min(min_x, x)
			max_x = max(max_x, x)

	# Scan for Z bounds (min and max)
	var min_z = ruin_base.z
	var max_z = ruin_base.z
	for z in range(ruin_base.z - max_scan, ruin_base.z + max_scan):
		var block_id = voxel_tool.get_voxel(Vector3i(ruin_base.x, ground_y, z))
		if block_id != 0:  # Not air
			min_z = min(min_z, z)
			max_z = max(max_z, z)

	# Calculate size from bounds
	var detected_size = Vector3i(
		max_x - min_x + 1,
		20,  # Reasonable height for most ruins
		max_z - min_z + 1
	)

	return detected_size


func _get_platform_expansion_info(ruin: RuinRegistry.RuinData) -> Dictionary:
	"""Determine if and how much a ruin needs platform expansion"""
	var info = {
		"needs_expansion": false,
		"expanded_size": ruin.ruin_size,
		"extra_space": Vector3i.ZERO,
		"is_sky_ruin": false,
		"ruin_type": ruin.ruin_type
	}
	
	# Check if it's a sky ruin (high altitude)
	info.is_sky_ruin = ruin.position.y > 100
	
	# Minimum comfortable size for home base with structures
	var MIN_HOME_SIZE = Vector3i(30, 10, 30)  # Need ~30x30 for tent + campfire + garden + NPC space
	
	# Check if ruin is too small
	if ruin.ruin_size.x < MIN_HOME_SIZE.x or ruin.ruin_size.z < MIN_HOME_SIZE.z:
		info.needs_expansion = true
		
		# Calculate how much to expand (2x the horizontal dimensions for sky ruins)
		if info.is_sky_ruin:
			info.expanded_size = Vector3i(
				max(ruin.ruin_size.x * 2, MIN_HOME_SIZE.x),
				ruin.ruin_size.y,  # Don't expand height
				max(ruin.ruin_size.z * 2, MIN_HOME_SIZE.z)
			)
		else:
			# Ground ruins - just ensure minimum size
			info.expanded_size = Vector3i(
				max(ruin.ruin_size.x, MIN_HOME_SIZE.x),
				ruin.ruin_size.y,
				max(ruin.ruin_size.z, MIN_HOME_SIZE.z)
			)
		
		info.extra_space = info.expanded_size - ruin.ruin_size
	
	# TODO Phase 2: When expanding platforms, add 3-block tall perimeter wall
	# to prevent companion NPCs from walking off the edge and falling!
	# Wall should be at the edge of expanded_size with a gate/opening for entry
	
	return info


func _relocate_benched_companions():
	"""Move benched companions to home base as NPCs"""
	# Clear any existing benched NPCs first
	_despawn_benched_npcs()
	
	# Get benched companions from roster
	var benched = CompanionManager.get_benched_companions()
	if benched.is_empty():
		print("🏕️ No benched companions to relocate")
		return
	
	print("🏕️ Relocating %d benched companions to home base..." % benched.size())
	
	# Calculate spawn positions in a circle around home base
	var radius = 5.0  # 5 blocks from center
	var angle_step = (2.0 * PI) / benched.size()
	
	for i in range(benched.size()):
		var comp = benched[i]
		var angle = angle_step * i
		var offset = Vector3(
			cos(angle) * radius,
			0,
			sin(angle) * radius
		)
		var spawn_pos = home_base_position + offset
		
		spawn_companion_npc(comp, spawn_pos)


func spawn_companion_npc(comp_data: CompanionManager.CompanionData, spawn_pos: Vector3):
	"""Spawn a benched companion as an NPC (bridge to TestNPC system)"""
	if not _game:
		push_error("HomeBaseManager: Cannot spawn NPC - game reference not set")
		return
	
	# Load TestNPC script and create instance
	var TestNPC = load("res://blocky_game/entities/test_npc.gd")
	var npc = Node3D.new()
	npc.set_script(TestNPC)
	
	# Add to game world first
	_game.add_child(npc)
	
	# Position above spawn point (will fall to ground)
	npc.global_position = spawn_pos + Vector3(0, 5, 0)
	
	# Find ground position if method exists
	if npc.has_method("find_ground_position"):
		npc.global_position = npc.find_ground_position(spawn_pos + Vector3(0, 5, 0), 15.0)
	else:
		npc.global_position = spawn_pos
	
	# Assign role-based colors and initialize
	var color = _get_role_color(comp_data.role)
	npc.initialize(comp_data.race, comp_data.gender, color, comp_data.companion_name)
	npc.add_to_group("benched_companions")
	
	print("🏕️ Spawned benched companion: %s (%s %s %s) at %s" % [
		comp_data.companion_name, comp_data.gender, comp_data.race, comp_data.role, npc.global_position
	])


func _get_role_color(role: String) -> Color:
	"""Get a color tint based on companion role"""
	match role:
		"healer": return Color(0.2, 1.0, 0.3)  # Green
		"tank": return Color(0.7, 0.7, 0.9)    # Blue-gray
		"rogue": return Color(0.6, 0.2, 0.8)   # Purple
		"wizard": return Color(0.3, 0.5, 1.0)  # Blue
		_: return Color.WHITE


func _despawn_benched_npcs():
	"""Remove existing benched companion NPCs"""
	var benched = get_tree().get_nodes_in_group("benched_companions")
	for npc in benched:
		npc.queue_free()


func _despawn_homebase_npcs():
	"""Remove homebase NPCs when clearing homebase"""
	var homebase_npcs = get_tree().get_nodes_in_group("homebase_npcs")
	for npc in homebase_npcs:
		npc.queue_free()
	spawned_npcs.clear()
	print("HomeBaseManager: Despawned %d homebase NPCs" % homebase_npcs.size())


func _restore_homebase_npcs(npc_data_array: Array):
	"""Restore homebase NPCs from save data"""
	if not _game:
		push_warning("HomeBaseManager: Cannot restore NPCs - game reference not set")
		return

	# Clear any existing homebase NPCs first
	_despawn_homebase_npcs()

	# Recreate each NPC from saved data
	for npc_data in npc_data_array:
		# Create NPC node
		var TestNPC = load("res://blocky_game/entities/test_npc.gd")
		var npc = Node3D.new()
		npc.set_script(TestNPC)

		# Add to game world
		_game.add_child(npc)

		# Restore position
		var pos = npc_data.position
		npc.global_position = Vector3(pos.x, pos.y, pos.z)

		# Restore color
		var col = npc_data.color
		var color = Color(col.r, col.g, col.b, col.a)

		# Initialize NPC with saved data
		npc.initialize(
			npc_data.race,
			npc_data.gender,
			color,
			npc_data.name,
			npc_data.job
		)

		# Add to homebase NPCs group and tracking array
		npc.add_to_group("homebase_npcs")
		spawned_npcs.append(npc)

	print("🏘️ Restored %d homebase NPCs from save data" % npc_data_array.size())


## ============================================================================
## HOMEBASE NPC SPAWNING SYSTEM (1 PER DAY)
## ============================================================================

func _initialize_npc_pool():
	"""Initialize the pool of NPCs to spawn"""
	npc_spawn_pool = NPC_TEMPLATES.duplicate()
	npcs_to_spawn_index = 0
	print("HomeBaseManager: NPC spawn pool initialized with %d NPCs" % npc_spawn_pool.size())


func _on_day_changed(day: int):
	"""Called when in-game day changes - spawn 1 NPC if homebase is set"""
	if not has_home_base:
		return

	# Set homebase_set_day if this is the first day after homebase was set
	if homebase_set_day == -1:
		var time_manager = get_node_or_null("/root/TimeManager")
		if time_manager:
			homebase_set_day = time_manager.current_day
			print("HomeBaseManager: Homebase set on day %d" % homebase_set_day)

	# Check if we have more NPCs to spawn
	if npcs_to_spawn_index >= npc_spawn_pool.size():
		return  # All NPCs have been spawned

	# Spawn 1 NPC per day
	_spawn_daily_npc()


func _spawn_daily_npc():
	"""Spawn a single NPC at homebase"""
	if not _game:
		push_warning("HomeBaseManager: Cannot spawn NPC - game reference not set")
		return

	if npcs_to_spawn_index >= npc_spawn_pool.size():
		print("HomeBaseManager: All NPCs have been spawned")
		return

	# Get next NPC template
	var npc_template = npc_spawn_pool[npcs_to_spawn_index]
	npcs_to_spawn_index += 1

	# Find spawn position within homebase
	var spawn_pos = _find_npc_spawn_position()
	if spawn_pos == Vector3.ZERO:
		push_warning("HomeBaseManager: Could not find valid spawn position for NPC")
		return

	# Create NPC node
	var TestNPC = load("res://blocky_game/entities/test_npc.gd")
	var npc = Node3D.new()
	npc.set_script(TestNPC)

	# Add to game world
	_game.add_child(npc)
	npc.global_position = spawn_pos

	# Initialize NPC with template data
	npc.initialize(
		npc_template.race,
		npc_template.gender,
		npc_template.color,
		npc_template.name,
		npc_template.job
	)

	# Add to homebase NPCs group and tracking array
	npc.add_to_group("homebase_npcs")
	spawned_npcs.append(npc)

	print("🏘️ Spawned homebase NPC: %s (%s %s) - Job: %s at %s" % [
		npc_template.name,
		npc_template.race,
		npc_template.gender,
		npc_template.job,
		spawn_pos
	])


func _find_npc_spawn_position() -> Vector3:
	"""Find a valid spawn position at the CENTER of the ruin's terrain"""
	if not has_home_base:
		return Vector3.ZERO

	# Get ruin data if homebase is on a ruin
	var ruin = RuinRegistry.get_ruin_at_position(home_base_position, 100.0)
	if not ruin:
		# Not on a ruin, spawn near homebase position
		var spawn_range = 5.0
		var offset_x = randf_range(-spawn_range, spawn_range)
		var offset_z = randf_range(-spawn_range, spawn_range)
		return home_base_position + Vector3(offset_x, 1, offset_z)

	# Get ruin dimensions
	var ruin_base = Vector3i(ruin.position)
	var ruin_size = ruin.ruin_size

	# Auto-detect actual size if old default (10x10x10)
	if ruin_size == Vector3i(10, 10, 10) and not ruin.ruin_type.contains("crashed"):
		if not _game:
			return home_base_position
		var terrain = _game.get_node_or_null("VoxelTerrain")
		if terrain:
			var voxel_tool = terrain.get_voxel_tool()
			ruin_size = _detect_actual_ruin_size(ruin_base, voxel_tool)
			print("   Auto-detected ruin size for NPC spawn: %s" % ruin_size)

	# Calculate CENTER of the ruin's terrain platform
	var center_x = ruin_base.x + (ruin_size.x / 2.0)
	var center_z = ruin_base.z + (ruin_size.z / 2.0)
	var ground_y = ruin_base.y + 1  # Slightly above ground

	# Add small random offset around center (±3 blocks)
	var spawn_range = 3.0
	var offset_x = randf_range(-spawn_range, spawn_range)
	var offset_z = randf_range(-spawn_range, spawn_range)

	var spawn_pos = Vector3(center_x + offset_x, ground_y, center_z + offset_z)

	print("   Ruin center: (%.1f, %d, %.1f), NPC spawn: %s" % [center_x, ground_y, center_z, spawn_pos])

	return spawn_pos


## ============================================================================
## SAVE/LOAD SYSTEM
## ============================================================================

func save_to_dict() -> Dictionary:
	"""Save home base state to dictionary"""
	var save_data = {
		"has_home_base": has_home_base,
		"home_base_position": {
			"x": home_base_position.x,
			"y": home_base_position.y,
			"z": home_base_position.z
		},
		"home_base_ruin_id": home_base_ruin_id,
		"home_structure_tier": home_structure_tier,
		"homebase_set_day": homebase_set_day,
		"npcs_to_spawn_index": npcs_to_spawn_index,
		"spawned_npcs": []
	}

	# Save spawned NPC data
	for npc in spawned_npcs:
		if is_instance_valid(npc):
			save_data["spawned_npcs"].append({
				"name": npc.npc_display_name,
				"race": npc.npc_race,
				"gender": npc.npc_gender,
				"job": npc.npc_job,
				"color": {
					"r": npc.npc_color.r,
					"g": npc.npc_color.g,
					"b": npc.npc_color.b,
					"a": npc.npc_color.a
				},
				"position": {
					"x": npc.global_position.x,
					"y": npc.global_position.y,
					"z": npc.global_position.z
				}
			})

	print("HomeBaseManager: Saved %d homebase NPCs" % save_data["spawned_npcs"].size())
	return save_data


func load_from_dict(data: Dictionary):
	"""Load home base state from dictionary"""
	if data.has("has_home_base"):
		has_home_base = data.has_home_base

	if data.has("home_base_position"):
		var pos = data.home_base_position
		home_base_position = Vector3(pos.x, pos.y, pos.z)

	if data.has("home_base_ruin_id"):
		home_base_ruin_id = data.home_base_ruin_id

	if data.has("home_structure_tier"):
		home_structure_tier = data.home_structure_tier
	else:
		home_structure_tier = 0  # Default to cave for old saves

	# Load NPC spawn tracking
	if data.has("homebase_set_day"):
		homebase_set_day = data.homebase_set_day
	else:
		homebase_set_day = -1  # Default for old saves

	if data.has("npcs_to_spawn_index"):
		npcs_to_spawn_index = data.npcs_to_spawn_index
	else:
		npcs_to_spawn_index = 0  # Default for old saves

	# Respawn structure if we had a home base
	if has_home_base:
		print("🏠 Home Base restored at: %s (Tier %d: %s)" % [
			home_base_position,
			home_structure_tier,
			TIER_NAMES[home_structure_tier]
		])
		_spawn_home_structure()
		_relocate_benched_companions()

		# Restore spawned NPCs (or queue for later if game isn't ready)
		if data.has("spawned_npcs"):
			if _game:
				# Game is ready, restore immediately
				_restore_homebase_npcs(data.spawned_npcs)
			else:
				# Game not ready yet, store for later
				_pending_npc_data = data.spawned_npcs
				print("HomeBaseManager: Queued %d NPCs for restoration when game is ready" % _pending_npc_data.size())
