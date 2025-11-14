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


func _ready():
	print("HomeBaseManager: Initialized")


func set_game_reference(game_node: Node):
	"""Set reference to the main game node"""
	_game = game_node
	print("HomeBaseManager: Game reference set")


func set_player_reference(player_node: Node):
	"""Set reference to the player node"""
	_player = player_node


func set_home_base(position: Vector3, ruin_id: String = ""):
	"""Establish home base at the given position"""
	home_base_position = position
	has_home_base = true
	home_base_ruin_id = ruin_id
	
	# Check if we're setting home base in a ruin
	var ruin = RuinRegistry.get_ruin_at_position(position, 50.0)  # 50 block tolerance
	
	if ruin:
		# We're in a ruin!
		home_base_ruin_id = ruin.ruin_name
		print("🏠 Home Base established in: %s (%s)" % [ruin.ruin_name, ruin.ruin_type])
		print("   Size: %s, Position: %s" % [ruin.ruin_size, ruin.position])
		
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

	# Spawn home structure
	_spawn_home_structure()

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
	
	has_home_base = false
	home_base_position = Vector3.ZERO
	home_base_ruin_id = ""
	home_structure_tier = 0
	
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
	var terrain = _game.get_node_or_null("Terrain")
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
		# Normal ruin fence
		min_corner = ruin_base
		max_corner = ruin_base + ruin_size
		print("🔨 Building planks fence around homebase...")
		print("   Ruin: %s" % ruin.ruin_name)
		print("   Base: %s, Size: %s" % [ruin_base, ruin_size])

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

	# Build 3-block tall fence around perimeter
	# Bottom y level of the ruin (approximate ground level)
	var ground_y = ruin_base.y
	var gap_size = 5  # Leave 5-block gap around entrances

	# Build fence on all 4 sides
	for y_offset in range(3):  # 3 blocks tall
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


## ============================================================================
## SAVE/LOAD SYSTEM
## ============================================================================

func save_to_dict() -> Dictionary:
	"""Save home base state to dictionary"""
	return {
		"has_home_base": has_home_base,
		"home_base_position": {
			"x": home_base_position.x,
			"y": home_base_position.y,
			"z": home_base_position.z
		},
		"home_base_ruin_id": home_base_ruin_id,
		"home_structure_tier": home_structure_tier
	}


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
	
	# Respawn structure if we had a home base
	if has_home_base:
		print("🏠 Home Base restored at: %s (Tier %d: %s)" % [
			home_base_position, 
			home_structure_tier, 
			TIER_NAMES[home_structure_tier]
		])
		_spawn_home_structure()
		_relocate_benched_companions()
