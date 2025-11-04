extends Node

const NETWORK_MODE_SINGLEPLAYER = 0
const NETWORK_MODE_CLIENT = 1
const NETWORK_MODE_HOST = 2

const SERVER_PEER_ID = 1

const CharacterScene = preload("./player/character_avatar.tscn")
const RemoteCharacterScene = preload("./player/remote_character.tscn")
const RandomTicks = preload("./random_ticks.gd")
const WaterUpdater = preload("./water.gd")
const DayNightCycle = preload("res://long_nights/DayNightCycle.gd")
const TimeDisplay = preload("res://long_nights/TimeDisplay.gd")
const GameConsole = preload("res://long_nights/GameConsole.gd")
const GameOverScreen = preload("res://long_nights/GameOverScreen.gd")
const PartyUI = preload("res://long_nights/PartyUI.gd")
const EnemySpawner = preload("res://long_nights/EnemySpawner.gd")
const SeasonalTextureSystem = preload("res://long_nights/SeasonalTextureSystem.gd")

@onready var _light : DirectionalLight3D = $DirectionalLight3D
@onready var _terrain : VoxelTerrain = $VoxelTerrain
@onready var _characters_container : Node = $Players
@onready var _blocks = $Blocks

var _network_mode := NETWORK_MODE_SINGLEPLAYER
var _ip := ""
var _port := -1

# Initially needed because when running multiple instances in the editor, Godot is mixing up the
# outputs of server and clients in the same output console...
# 2025/05/01: had to prefix because Godot now has a Logger class
class BG_Logger:
	var prefix := ""
	
	func debug(msg: String):
		print(prefix, msg)

	func error(msg: String):
		push_error(prefix, msg)


var _logger := BG_Logger.new()


func get_terrain() -> VoxelTerrain:
	return _terrain


func get_network_mode() -> int:
	return _network_mode


func set_network_mode(mode: int):
	_network_mode = mode


func set_ip(ip: String):
	_ip = ip


func set_port(port: int):
	_port = port


func _ready():
	# Apply graphics settings to the loaded scene
	GraphicsSettings.apply_profile(GraphicsSettings.get_current_profile())

	# Load dialogue files
	DialogueManager.load_dialogue_file("res://assets/data/dialogues/companion_intro.json")

	if _network_mode == NETWORK_MODE_HOST:
		_logger.prefix = "Server: "
		
		# Configure multiplayer API as server
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_server(_port, 32, 0, 0, 0)
		if err != OK:
			_logger.error(str("Failed to create server peer, error ", err))
			return
		var mp := get_tree().get_multiplayer()
		mp.peer_connected.connect(_on_peer_connected)
		mp.peer_disconnected.connect(_on_peer_disconnected)
		mp.multiplayer_peer = peer

		# Configure VoxelTerrain as server
		var synchronizer := VoxelTerrainMultiplayerSynchronizer.new()
		_terrain.add_child(synchronizer)

	elif _network_mode == NETWORK_MODE_CLIENT:
		_logger.prefix = "Client: "
		
		# Configure multiplayer API as client
		var peer := ENetMultiplayerPeer.new()
		var err := peer.create_client(_ip, _port, 0, 0, 0, 0)
		if err != OK:
			_logger.error(str("Failed to create client peer, error ", err))
			return
		var mp := get_tree().get_multiplayer()
		mp.connected_to_server.connect(_on_connected_to_server)
		mp.connection_failed.connect(_on_connection_failed)
		mp.peer_connected.connect(_on_peer_connected)
		mp.peer_disconnected.connect(_on_peer_disconnected)
		mp.server_disconnected.connect(_on_server_disconnected)
		mp.multiplayer_peer = peer

		# Configure VoxelTerrain as client
		var synchronizer := VoxelTerrainMultiplayerSynchronizer.new()
		_terrain.add_child(synchronizer)
		_terrain.stream = null

	if _network_mode == NETWORK_MODE_HOST or _network_mode == NETWORK_MODE_SINGLEPLAYER:
		add_child(RandomTicks.new())

		var water_updater := WaterUpdater.new()
		# Current code grabs this node by name, so must be named for now...
		water_updater.name = "Water"
		add_child(water_updater)

		# Add day/night cycle system
		var day_night = DayNightCycle.new()
		day_night.sun_light = _light
		# Pass the WorldEnvironment for fog updates
		var world_env = get_node_or_null("WorldEnvironment")
		if world_env:
			day_night.environment = world_env
		add_child(day_night)
		print("The Long Nights: Day/Night cycle initialized")

		# Add time display UI
		var time_ui = TimeDisplay.new()
		add_child(time_ui)
		print("The Long Nights: Time UI added")

		# Add party UI (shows player/companion)
		var party_ui = PartyUI.new()
		add_child(party_ui)
		print("The Long Nights: Party UI added")

		# Add game console
		var console = GameConsole.new()
		add_child(console)
		print("The Long Nights: Console ready (~ or F1)")

		# Add terrain mapper for block creation
		var TerrainMapper = preload("res://long_nights/TerrainMapper.gd")
		var terrain_mapper = TerrainMapper.new()
		add_child(terrain_mapper)
		print("The Long Nights: Terrain mapper ready (Ctrl+T)")

		# Add ruins system
		var RuinLibrary = preload("res://blocky_game/ruins/RuinLibrary.gd")
		var ruin_library = RuinLibrary.new()
		ruin_library.name = "RuinLibrary"
		add_child(ruin_library)

		var RuinSpawner = preload("res://blocky_game/ruins/RuinSpawner.gd")
		var ruin_spawner = RuinSpawner.new()
		ruin_spawner.name = "RuinSpawner"
		add_child(ruin_spawner)

		# Initialize spawner after it's in the tree
		await get_tree().process_frame
		ruin_spawner.initialize(ruin_library, _blocks, _terrain)
		print("The Long Nights: Ruins system initialized")

		# Add game over screen
		var game_over = GameOverScreen.new()
		add_child(game_over)
		print("The Long Nights: Game Over screen initialized")

		# Add enemy spawner system
		var spawner = EnemySpawner.new()
		add_child(spawner)
		print("The Long Nights: Enemy spawner initialized")

		# Spawn player at saved position (or default)
		var spawn_pos = WorldManager.get_player_position()
		_spawn_character(SERVER_PEER_ID, spawn_pos)

		# Spawn initial crashed ruin near spawn (wait for terrain to generate first)
		await get_tree().create_timer(1.0).timeout
		var ruin_spawner_node = get_node_or_null("RuinSpawner")
		if ruin_spawner_node:
			await ruin_spawner_node.spawn_ruin_near_spawn(Vector3i(3, 0, 3))
			print("The Long Nights: Initial crashed ruin spawned")

		# Spawn companion and add to Party UI (after a brief delay so PartyUI is ready)
		await get_tree().create_timer(0.5).timeout
		_spawn_companion()
		_add_companion_to_ui()

		# Load saved inventory if it exists (after player/companion are spawned)
		await get_tree().create_timer(0.1).timeout
		WorldManager.load_inventory_if_exists()

		# Now add seasonal texture system (after companion is loaded)
		var seasonal_system = SeasonalTextureSystem.new()
		seasonal_system.name = "SeasonalTextureSystem"
		add_child(seasonal_system)
		print("The Long Nights: Seasonal texture system initialized")


func _on_connected_to_server():
	_logger.debug("connected to server")


func _on_connection_failed():
	_logger.debug("Connection failed")


func _on_peer_connected(new_peer_id: int):
	_logger.debug(str("peer ", new_peer_id, " connected"))
	
	if _network_mode == NETWORK_MODE_HOST:
		# Spawn own character
		var new_character = _spawn_remote_character(new_peer_id, Vector3(0, 64, 0))
		_logger.debug(str("Sending own character to ", new_peer_id))
		rpc_id(new_peer_id, &"receive_own_character", new_peer_id, new_character.position)
		
		# Send existing characters to the new peer
		for i in _characters_container.get_child_count():
			var character := _characters_container.get_child(i)
			if character != new_character:
				# TODO This sucks, find a better way to get peer ID from character
				var peer_id := character.name.to_int()
				_logger.debug(str("Sending remote character ", peer_id, " to ", new_peer_id))
				rpc_id(new_peer_id, &"receive_remote_character", peer_id, character.position)
		
		# Send new character to other clients
		var peers := get_tree().get_multiplayer().get_peers()
		for peer_id in peers:
			if peer_id != new_peer_id:
				_logger.debug(str("Sending remote character ", peer_id, " to other ", new_peer_id))
				rpc_id(peer_id, &"receive_remote_character", new_peer_id, new_character.position)


func _on_peer_disconnected(peer_id: int):
	_logger.debug(str("Peer ", peer_id, " disconnected"))
	# Remove character
	var node_name = str(peer_id)
	if _characters_container.has_node(node_name):
		var character = _characters_container.get_node(node_name)
		character.queue_free()
	else:
		_logger.debug(str("Character ", peer_id, " not found"))


func _on_server_disconnected():
	_logger.debug("Server disconnected")
	# TODO Go back to main menu, the game will spam RPC errors


func _unhandled_input(event: InputEvent):
	# TODO Make a pause menu with options?
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_L:
				# Toggle shadows
				_light.shadow_enabled = not _light.shadow_enabled
#			if event.keycode == KEY_KP_0:
#				# Force save
#				_save_world()


func _notification(what: int):
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			if _network_mode == NETWORK_MODE_HOST or _network_mode == NETWORK_MODE_SINGLEPLAYER:
				# Save game when the user closes the window
				_save_world()


func _save_world():
	_terrain.save_modified_blocks()


func _spawn_character(peer_id: int, pos: Vector3) -> Node3D:
	var node_name = str(peer_id)
	if _characters_container.has_node(node_name):
		_logger.error(str("Character ", peer_id, " already created"))
		return null
	
	# Ensure spawn position is safe (not inside blocks)
	var safe_pos = _find_safe_spawn_position(pos)
	
	var character : Node3D = CharacterScene.instantiate()
	character.name = node_name
	character.position = safe_pos
	character.terrain = get_terrain().get_path()
	character.add_to_group("player")  # Add to group for easy finding
	_characters_container.add_child(character)
	
	if safe_pos != pos:
		print("Player spawn adjusted from y=", pos.y, " to safe position y=", safe_pos.y)
	
	return character


func _find_safe_spawn_position(pos: Vector3) -> Vector3:
	"""Find a safe spawn position, moving upward if the player is inside blocks"""
	var terrain_tool = _terrain.get_voxel_tool()
	var check_pos = pos
	var max_checks = 300  # Check up to 300 blocks above (from y=-256 to y=44)
	
	# Check if current position and the block above (for head room) are both air
	for i in range(max_checks):
		var voxel_at_feet = terrain_tool.get_voxel(check_pos)
		var voxel_at_head = terrain_tool.get_voxel(check_pos + Vector3(0, 1, 0))
		
		# If both feet and head positions are air (0), this is safe
		if voxel_at_feet == 0 and voxel_at_head == 0:
			return check_pos
		
		# Move up one block and check again
		check_pos.y += 1
		
		# If we've reached the sky, just use this position
		if check_pos.y > 100:
			return check_pos
	
	# If all else fails, spawn at a safe altitude
	print("Warning: Could not find safe spawn position, spawning at y=10")
	return Vector3(pos.x, 10, pos.z)


func _spawn_remote_character(peer_id: int, pos: Vector3) -> Node3D:
	var node_name = str(peer_id)
	if _characters_container.has_node(node_name):
		_logger.debug(str("Remote character ", peer_id, " already created"))
		return null
	var character := RemoteCharacterScene.instantiate()
	character.position = pos
	character.name = str(peer_id)
	if _network_mode == NETWORK_MODE_HOST:
		# The server is authoritative on voxel terrain, so it needs a viewer to load terrain
		# around each character. We'll also tell which peer ID it uses, so the terrain knows which
		# peer to send the voxels to.
		# TODO Make a specific scene?
		var viewer := VoxelViewer.new()
		viewer.view_distance = GraphicsSettings.get_setting_or("voxel_viewer_distance", 128)
		viewer.requires_visuals = false
		viewer.requires_collisions = false
		viewer.set_network_peer_id(peer_id)
		viewer.set_requires_data_block_notifications(true)
		#viewer.requires_data_block_notifications = true
		character.add_child(viewer)
	_characters_container.add_child(character)
	return character


@rpc("authority", "call_remote", "reliable", 0)
func receive_remote_character(peer_id: int, pos: Vector3):
	_logger.debug(str("receive_remote_character ", peer_id, " at ", pos))
	_spawn_remote_character(peer_id, pos)


@rpc("authority", "call_remote", "reliable", 0)
func receive_own_character(peer_id: int, pos: Vector3):
	_logger.debug(str("receive_own_character ", peer_id, " at ", pos))
	_spawn_character(peer_id, pos)


func _spawn_companion() -> void:
	# Load companion script
	const CompanionScript = preload("res://blocky_game/entities/companion.gd")

	# Create companion entity
	var companion = CompanionScript.new()
	companion.name = "Companion"

	# Add to scene first so terrain is available
	add_child(companion)

	# Check if we have saved companion data from CompanionManager
	var saved_behavior = CompanionManager.saved_behavior_mode
	var saved_position = CompanionManager.saved_position
	var saved_guard_position = CompanionManager.saved_guard_position

	# Spawn companion at saved position or near player
	if saved_position != null:
		companion.position = Vector3(saved_position[0], saved_position[1], saved_position[2])
		print("blocky_game: Companion %s spawned at saved position %s" % [CompanionManager.get_companion_name(), companion.position])
	else:
		# First time spawn - place near player
		var player = _characters_container.get_node_or_null(str(SERVER_PEER_ID))
		if player:
			var spawn_pos = player.position + Vector3(2, 5, 2)  # Start above player
			# Find ground below
			companion.position = companion.find_ground_position(spawn_pos, 15.0)
		else:
			companion.position = Vector3(0, 64, 0)  # Default spawn
		print("blocky_game: Companion %s spawned at %s" % [CompanionManager.get_companion_name(), companion.position])
	
	# Restore behavior mode and guard position after companion is ready
	if saved_behavior != "normal" or saved_guard_position != null:
		# Wait a frame for companion to fully initialize
		await get_tree().process_frame
		
		# Restore guard position if it was saved
		if saved_guard_position != null:
			companion._guard_position = Vector3(saved_guard_position[0], saved_guard_position[1], saved_guard_position[2])
		
		# Set behavior mode (this will apply modifiers and update UI)
		companion.set_behavior_mode(saved_behavior)
		print("blocky_game: Restored companion behavior: %s" % saved_behavior)

	# Trigger companion introduction dialogue
	await get_tree().create_timer(1.0).timeout  # Brief delay before dialogue
	DialogueManager.trigger_dialogue("game_start")


func _add_companion_to_ui() -> void:
	# Find PartyUI (search for it by method)
	var party_ui = null
	for child in get_children():
		if child.has_method("add_companion"):
			party_ui = child
			break

	if not party_ui:
		push_warning("blocky_game: Could not find PartyUI")
		print("blocky_game: Available children: ", get_children())
		return

	# Add companion to UI
	var companion_name = CompanionManager.get_companion_name()
	var companion_hp = CompanionManager.get_companion_max_hp()

	party_ui.add_companion(
		companion_name,
		CompanionManager.companion_race,
		CompanionManager.companion_role,
		companion_hp,
		companion_hp
	)

	print("blocky_game: Companion %s [%s] added to party UI" % [companion_name, CompanionManager.get_role_name()])
