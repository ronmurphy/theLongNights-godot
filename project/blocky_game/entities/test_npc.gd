extends GroundEntity

const CharacterQuiz = preload("res://long_nights/CharacterQuiz.gd")
const SimplePathfinding = preload("res://blocky_game/utils/simple_pathfinding.gd")

## TestNPC - Intelligent wandering NPC with day/night behavior and animal interests
## Can be spawned with console: npc <race> <gender> <color> <name>
## Uses player avatar sprites with color tinting

## NPC Behavior States
enum NPCState {
	WANDERING,        # Daytime exploration
	SEEKING_LIGHT,    # Night - finding nearest teleport stone
	AT_LIGHT,         # Night - idling near teleport stone
	WATCHING_ANIMAL,  # Observing an interesting animal
	PATHFINDING,      # Following a computed path
}

var npc_race: String = "human"
var npc_gender: String = "female"
var npc_color: Color = Color.WHITE
var npc_display_name: String = "NPC"

# Job type and dialogue
var npc_job: String = "companion"  # "companion", "cook", "power_shop", "food_merchant", "merchant", "town_manager", "ruinkeeper"
var npc_dialogue_id: String = ""  # Dialogue ID to trigger when interacted with
var npc_voice_mode: String = "animalese" # 'animalese' for AC-style, 'loop' for single SFX
var npc_voice_speed: float = 1.0
var npc_voice_pitch: float = 3.5

# Sprite direction tracking (like companion)
var _front_sprite_path: String = ""
var _back_sprite_path: String = ""
var _current_sprite_is_front: bool = true
var _sprite_height_scale: float = 1.0  # Store scale to preserve when swapping
var _health_bar: Node3D = null  # Health bar for neutral NPC
const MIN_SPEED_FOR_DIRECTION = 0.5  # Minimum speed to consider direction

# Wander AI
var _wander_timer: float = 0.0
var _wander_duration: float = 3.0  # Change direction every 3 seconds
var _wander_direction: Vector3 = Vector3.ZERO
var _idle_time: float = 0.0
var _is_idle: bool = false
var _in_dialogue: bool = false  # Paused for player interaction (don't auto-resume)

# Behavior State Machine
var _current_state: NPCState = NPCState.WANDERING
var _state_timer: float = 0.0

# Pathfinding
var _current_path: Array = []
var _path_index: int = 0
var _path_recalculate_timer: float = 0.0
const PATH_RECALCULATE_INTERVAL = 3.0  # Recalculate every 3 seconds if needed
const WAYPOINT_REACH_DISTANCE = 1.5  # How close to get to waypoint

# Night behavior - seeking light
var _target_teleport_stone: Vector3 = Vector3.ZERO
var _at_teleport_stone: bool = false
const TELEPORT_STONE_DISTANCE = 3.0  # How close to consider "at" the stone

# Animal watching
var _watching_animal: Node = null
var _watch_timer: float = 0.0
var _watch_duration: float = 0.0  # Random duration set when starting to watch
const MIN_WATCH_TIME = 3.0
const MAX_WATCH_TIME = 10.0
const ANIMAL_WATCH_DISTANCE = 8.0  # How close to watch animals
const ANIMAL_LOST_DISTANCE = 15.0  # Stop watching if animal gets too far

# NPC Personality - Animal Preferences (set in initialize)
var _favorite_animals: Array[String] = []  # e.g. ["bird", "fish", "rabbit"]
const FAVORITE_WATCH_CHANCE = 0.7  # 70% chance to watch favorite
const OTHER_WATCH_CHANCE = 0.3    # 30% chance to watch others

# References
var _time_manager: Node = null
var _terrain: Node = null
var _ruin_manager: Node = null


func _ready():
	super._ready()

	# Set team to neutral
	team = Team.NEUTRAL

	# Add to neutral group so companions won't attack
	add_to_group("neutral_entities")
	add_to_group("npcs")

	# Get references to world systems
	_time_manager = get_node_or_null("/root/TimeManager")
	_terrain = get_node_or_null("/root/Main/Game/VoxelTerrain")
	_ruin_manager = get_node_or_null("/root/Main/Game/RuinManager")

	# Randomize first wander direction
	_pick_new_wander_direction()

	# Note: Sprite and health bar are created in initialize() after race/gender are set


func initialize(race: String, gender: String, color: Color, display_name: String, job: String = "companion", dialogue_id: String = ""):
	"""Initialize NPC with race, gender, color, name, job, and dialogue"""
	npc_race = race
	npc_gender = gender
	npc_color = color
	npc_display_name = display_name
	entity_name = display_name
	npc_job = job
	npc_dialogue_id = dialogue_id

	# Default voice settings per job if not provided
	if job == "ruinkeeper":
		npc_voice_mode = "animalese"
		npc_voice_speed = 1.0
		npc_voice_pitch = 3.5

	# Auto-generate dialogue ID if not provided
	if npc_dialogue_id == "":
		npc_dialogue_id = "npc_%s_%s" % [job, display_name.to_lower().replace(" ", "_")]

	# Load stats from entities.json data
	_load_stats_from_race(race)

	# Apply race-based speed multiplier
	var speed_multiplier = CharacterQuiz.get_race_speed_multiplier(race)
	movement_speed *= speed_multiplier

	# Create sprite AFTER race/gender are set
	_create_sprite()

	# Create health bar for neutral NPC
	_create_health_bar()

	# Apply race-based height scaling
	_apply_race_height_scaling(race)

	# Assign random animal preferences for personality
	_assign_animal_preferences()

	print("TestNPC: Initialized %s (%s %s) - Job: %s, Dialogue: %s, Likes: %s" % [display_name, race, gender, job, npc_dialogue_id, _favorite_animals])


func _load_stats_from_race(race: String):
	"""Load stats from entities.json companion data"""
	# Base stats by race (from entities.json)
	match race:
		"human":
			max_hp = 12
			attack_damage = 4
			defense = 13
		"elf":
			max_hp = 10
			attack_damage = 5
			defense = 12
		"dwarf":
			max_hp = 16
			attack_damage = 3
			defense = 15
		"goblin":
			max_hp = 8
			attack_damage = 6
			defense = 11
		_:
			# Default to human stats
			max_hp = 12
			attack_damage = 4
			defense = 13
	
	# Use slower base movement speed for NPCs (casual wandering)
	# Player walks at ~4.0, NPCs should be slower to make interaction easier
	movement_speed = 1.5
	current_hp = max_hp


func _apply_race_height_scaling(race: String):
	"""Apply height scaling based on race"""
	var height_scale = 1.0
	
	match race:
		"elf":
			height_scale = 1.15  # Taller
		"human":
			height_scale = 1.0  # Normal
		"dwarf":
			height_scale = 0.8  # Shorter
		"goblin":
			height_scale = 0.75  # Shortest
	
	# Store scale for later use when swapping sprites
	_sprite_height_scale = height_scale
	
	# Apply scaling to sprite if it exists
	if _sprite:
		_sprite.scale = Vector3(height_scale, height_scale, height_scale)
		
		# Adjust sprite vertical position based on height
		# Taller races need to be higher, shorter races need to be lower
		# Base position is 1.0, scale it by the height multiplier
		_sprite.position.y = 1.0 * height_scale
	
	# Adjust health bar position based on height
	if _health_bar:
		_health_bar.position.y = 2.2 * height_scale


func _create_sprite(_texture_path: String = "", pixel_size: float = 0.004) -> Sprite3D:
	"""Create billboard sprite using NPC avatar sprites"""
	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.shaded = true
	_sprite.pixel_size = pixel_size  # 0.004 matches companion size
	
	# Position the sprite node upward so the character's feet are at entity origin
	# Match companion positioning - sprite is centered by default, so raise it up
	_sprite.position = Vector3(0, 1.0, 0)  # Raise sprite to show full character
	
	# Build sprite paths with priority:
	# 1. Custom named sprites (Michelle.png, Daniels.png, Mahan.png, zara.png)
	# 2. Race/gender sprites in npc_sprites folder
	# 3. Fallback to player_avatars folder
	var custom_front = "res://assets/art/npc_sprites/%s.png" % npc_display_name
	var custom_back = "res://assets/art/npc_sprites/%s_back.png" % npc_display_name
	var custom_front_lower = "res://assets/art/npc_sprites/%s.png" % npc_display_name.to_lower()
	var custom_back_lower = "res://assets/art/npc_sprites/%s_back.png" % npc_display_name.to_lower()
	var npc_front = "res://assets/art/npc_sprites/%s_%s.png" % [npc_race, npc_gender]
	var npc_back = "res://assets/art/npc_sprites/%s_%s_back.png" % [npc_race, npc_gender]
	var fallback_front = "res://assets/art/player_avatars/%s_%s.png" % [npc_race, npc_gender]
	var fallback_back = "res://assets/art/player_avatars/%s_%s_back.png" % [npc_race, npc_gender]

	# Choose sprite paths (prioritize custom named sprites, check both capitalized and lowercase)
	if ResourceLoader.exists(custom_front):
		_front_sprite_path = custom_front
		_back_sprite_path = custom_back
		print("TestNPC: Using custom sprite for %s" % npc_display_name)
	elif ResourceLoader.exists(custom_front_lower):
		_front_sprite_path = custom_front_lower
		_back_sprite_path = custom_back_lower
		print("TestNPC: Using custom lowercase sprite for %s" % npc_display_name)
	elif ResourceLoader.exists(npc_front):
		_front_sprite_path = npc_front
		_back_sprite_path = npc_back
	else:
		_front_sprite_path = fallback_front
		_back_sprite_path = fallback_back
	
	# Load front sprite
	var front_texture = null
	if ResourceLoader.exists(_front_sprite_path):
		front_texture = load(_front_sprite_path)
		_sprite.texture = front_texture
	else:
		push_warning("TestNPC: Could not find sprite at %s" % _front_sprite_path)
	
	# Apply color shader (only colors white/gray clothes, not skin/hair)
	if front_texture:
		var shader_material = ShaderMaterial.new()
		shader_material.shader = load("res://blocky_game/shaders/npc_colorize_3d.gdshader")
		shader_material.set_shader_parameter("texture_albedo", front_texture)
		shader_material.set_shader_parameter("target_color", npc_color)
		shader_material.set_shader_parameter("color_tolerance", 0.15)  # More forgiving for PNG compression
		
		# CRITICAL: Set render priority to ensure proper rendering
		shader_material.render_priority = 0
		
		_sprite.material_override = shader_material
		
		# Ensure transparency settings are correct after shader is applied
		_sprite.no_depth_test = false
		_sprite.fixed_size = false
		_sprite.double_sided = false
	
	# Apply initial scale (will be set properly in _apply_race_height_scaling)
	_sprite.scale = Vector3(1.0, 1.0, 1.0)

	# Enable shadow casting (same approach as player_avatar.gd)
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	add_child(_sprite)
	return _sprite


func _create_health_bar():
	"""Create simple health bar above NPC"""
	_health_bar = Node3D.new()
	_health_bar.position = Vector3(0, 2.2, 0)  # Above head (will be scaled by race height)
	add_child(_health_bar)
	
	# Background bar (red)
	var bg_bar = MeshInstance3D.new()
	var bg_mesh = BoxMesh.new()
	bg_mesh.size = Vector3(0.5, 0.05, 0.01)
	bg_bar.mesh = bg_mesh
	var bg_material = StandardMaterial3D.new()
	bg_material.albedo_color = Color(0.3, 0.0, 0.0)
	bg_bar.material_override = bg_material
	_health_bar.add_child(bg_bar)
	
	# Foreground bar (green)
	var fg_bar = MeshInstance3D.new()
	fg_bar.name = "ForegroundBar"
	var fg_mesh = BoxMesh.new()
	fg_mesh.size = Vector3(0.5, 0.05, 0.02)
	fg_bar.mesh = fg_mesh
	var fg_material = StandardMaterial3D.new()
	fg_material.albedo_color = Color(0.0, 0.8, 0.0)
	fg_bar.material_override = fg_material
	_health_bar.add_child(fg_bar)
	
	# Name label
	var name_label = Label3D.new()
	name_label.text = npc_display_name
	name_label.font_size = 24
	name_label.outline_size = 4
	name_label.position = Vector3(0, 0.15, 0)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_health_bar.add_child(name_label)


func _update_health_bar():
	"""Update health bar fill amount"""
	if not _health_bar:
		return
	
	var fg_bar = _health_bar.get_node_or_null("ForegroundBar")
	if fg_bar:
		var hp_percent = float(current_hp) / float(max_hp)
		# Scale the foreground bar horizontally
		fg_bar.scale.x = hp_percent


func _process(delta):
	if not is_alive or _in_dialogue:
		return

	# Update state timers
	_state_timer += delta
	_wander_timer += delta
	_path_recalculate_timer += delta

	# Check if we should change states
	_update_behavior_state(delta)

	# Process current state
	match _current_state:
		NPCState.WANDERING:
			_process_wandering_state(delta)
		NPCState.SEEKING_LIGHT:
			_process_seeking_light_state(delta)
		NPCState.AT_LIGHT:
			_process_at_light_state(delta)
		NPCState.WATCHING_ANIMAL:
			_process_watching_animal_state(delta)
		NPCState.PATHFINDING:
			_process_pathfinding_state(delta)

	# Update sprite direction based on movement relative to player
	_update_sprite_direction()


## ============================================================================
## BEHAVIOR STATE MACHINE
## ============================================================================

func _update_behavior_state(delta):
	"""Check if we should transition to a different behavior state"""

	# Night/day cycle overrides other behaviors
	if _is_night_time():
		# It's night - NPCs want to be near light
		if _current_state != NPCState.SEEKING_LIGHT and _current_state != NPCState.AT_LIGHT:
			# Start seeking the nearest teleport stone
			var stone_pos = _find_nearest_teleport_stone()
			if stone_pos != Vector3.ZERO:
				_target_teleport_stone = stone_pos
				_current_state = NPCState.SEEKING_LIGHT
				_state_timer = 0.0
				_start_pathfinding(_target_teleport_stone)
				print("%s: Night time! Seeking light at teleport stone" % npc_display_name)
	else:
		# It's daytime - resume normal behaviors
		if _current_state == NPCState.AT_LIGHT or _current_state == NPCState.SEEKING_LIGHT:
			# Dawn has come - resume wandering
			_current_state = NPCState.WANDERING
			_state_timer = 0.0
			_at_teleport_stone = false
			print("%s: Daytime! Resuming wandering" % npc_display_name)

	# Check for interesting animals during daytime
	if not _is_night_time() and _current_state == NPCState.WANDERING:
		# Periodically check for animals (every 2 seconds to save performance)
		if _state_timer > 2.0:
			_state_timer = 0.0
			var animal = _find_interesting_animal()
			if animal:
				_watching_animal = animal
				_watch_timer = 0.0
				_watch_duration = randf_range(MIN_WATCH_TIME, MAX_WATCH_TIME)
				_current_state = NPCState.WATCHING_ANIMAL
				print("%s: Ooh, a %s! *watches*" % [npc_display_name, animal.name])


func _process_wandering_state(delta):
	"""Normal daytime wandering behavior"""
	if _is_idle:
		_idle_time += delta
		if _idle_time >= 2.0:
			_is_idle = false
			_idle_time = 0.0
			_pick_new_wander_direction()
	elif _wander_timer >= _wander_duration:
		_wander_timer = 0.0

		# 30% chance to stop and idle
		if randf() < 0.3:
			_is_idle = true
			_wander_direction = Vector3.ZERO
		else:
			_pick_new_wander_direction()

	# Apply movement
	var velocity = _wander_direction * movement_speed
	apply_ground_movement(delta, velocity)

	# Face movement direction
	if _wander_direction.length() > 0.1:
		var look_direction = _wander_direction.normalized()
		look_at(global_position + look_direction, Vector3.UP)


func _process_seeking_light_state(delta):
	"""Pathfinding to teleport stone at night"""
	_current_state = NPCState.PATHFINDING
	# Pathfinding state will handle the actual movement


func _process_at_light_state(delta):
	"""Idling near teleport stone at night"""
	# Check if we're still close to the stone
	var distance = global_position.distance_to(_target_teleport_stone)
	if distance > TELEPORT_STONE_DISTANCE * 2.0:
		# Drifted too far - go back
		_current_state = NPCState.SEEKING_LIGHT
		_start_pathfinding(_target_teleport_stone)
		return

	# Just idle - maybe face the stone
	var look_direction = (_target_teleport_stone - global_position).normalized()
	if look_direction.length() > 0.1:
		look_at(global_position + look_direction, Vector3.UP)

	# Stand still
	apply_ground_movement(delta, Vector3.ZERO)


func _process_watching_animal_state(delta):
	"""Watching an interesting animal"""
	_watch_timer += delta

	# Check if animal is still valid and nearby
	if not is_instance_valid(_watching_animal):
		# Animal despawned - resume wandering
		_current_state = NPCState.WANDERING
		_watching_animal = null
		return

	var distance = global_position.distance_to(_watching_animal.global_position)

	# Lost interest if too far or watched long enough
	if distance > ANIMAL_LOST_DISTANCE or _watch_timer >= _watch_duration:
		_current_state = NPCState.WANDERING
		_watching_animal = null
		print("%s: *stops watching*" % npc_display_name)
		return

	# Face the animal
	var look_direction = (_watching_animal.global_position - global_position).normalized()
	if look_direction.length() > 0.1:
		look_at(global_position + look_direction, Vector3.UP)

	# Stand still (maybe walk closer if too far?)
	if distance > ANIMAL_WATCH_DISTANCE:
		# Walk toward animal slowly
		var move_direction = look_direction
		var velocity = move_direction * movement_speed * 0.5  # Half speed
		apply_ground_movement(delta, velocity)
	else:
		# Close enough - just watch
		apply_ground_movement(delta, Vector3.ZERO)


func _process_pathfinding_state(delta):
	"""Following a computed path"""
	if _current_path.is_empty():
		# No path - check why we were pathfinding
		if _is_night_time() and _target_teleport_stone != Vector3.ZERO:
			# Try to recalculate path to stone
			if _path_recalculate_timer > PATH_RECALCULATE_INTERVAL:
				_start_pathfinding(_target_teleport_stone)
		else:
			# Give up pathfinding, resume wandering
			_current_state = NPCState.WANDERING
		return

	# Follow the path
	_follow_current_path(delta)


func _follow_current_path(delta):
	"""Move along the current path waypoints"""
	if _path_index >= _current_path.size():
		# Reached end of path!
		_current_path = []
		_path_index = 0

		# Check if we reached our goal
		if _target_teleport_stone != Vector3.ZERO:
			var distance = global_position.distance_to(_target_teleport_stone)
			if distance <= TELEPORT_STONE_DISTANCE:
				# Reached the light!
				_current_state = NPCState.AT_LIGHT
				_at_teleport_stone = true
				print("%s: Reached the light! *feels safe*" % npc_display_name)
				return

		# Didn't reach goal - try wandering or recalculate
		if _is_night_time():
			_current_state = NPCState.SEEKING_LIGHT
		else:
			_current_state = NPCState.WANDERING
		return

	# Get current waypoint
	var waypoint = _current_path[_path_index]
	var distance = global_position.distance_to(waypoint)

	# Check if reached this waypoint
	if distance < WAYPOINT_REACH_DISTANCE:
		_path_index += 1
		if _path_index >= _current_path.size():
			return  # Will be handled next frame
		waypoint = _current_path[_path_index]

	# Move toward waypoint
	var direction = (waypoint - global_position).normalized()
	var velocity = direction * movement_speed
	apply_ground_movement(delta, velocity)

	# Face movement direction
	if direction.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)


## ============================================================================
## UTILITY METHODS
## ============================================================================

func _assign_animal_preferences():
	"""Randomly assign 1-2 favorite animal types for this NPC's personality"""
	var all_animals = ["bird", "fish", "rabbit", "cat"]
	var num_favorites = randi() % 2 + 1  # 1 or 2 favorites

	for i in range(num_favorites):
		if all_animals.size() > 0:
			var random_index = randi() % all_animals.size()
			var favorite = all_animals[random_index]
			_favorite_animals.append(favorite)
			all_animals.remove_at(random_index)


func _is_night_time() -> bool:
	"""Check if it's currently night time"""
	if not _time_manager:
		return false

	var hour = _time_manager.current_hour

	# Night is 7 PM (19:00) to 7 AM (7:00)
	return hour >= 19 or hour < 7


func _find_nearest_teleport_stone() -> Vector3:
	"""Find the closest teleport stone position"""
	if not _ruin_manager:
		return Vector3.ZERO

	var nearest_pos = Vector3.ZERO
	var nearest_distance = 99999.0

	# Get all teleport stone positions from ruin manager
	if _ruin_manager.teleport_stone_positions:
		for ruin_index in _ruin_manager.teleport_stone_positions:
			var stone_pos = _ruin_manager.teleport_stone_positions[ruin_index]
			var distance = global_position.distance_to(stone_pos)

			if distance < nearest_distance:
				nearest_distance = distance
				nearest_pos = stone_pos

	return nearest_pos


func _find_interesting_animal() -> Node:
	"""Look for nearby animals that might be interesting to watch"""
	# Get all entities in the neutral group (includes animals)
	var entities = get_tree().get_nodes_in_group("neutral_entities")

	for entity in entities:
		if not is_instance_valid(entity) or entity == self:
			continue

		# Check distance
		var distance = global_position.distance_to(entity.global_position)
		if distance > ANIMAL_WATCH_DISTANCE:
			continue

		# Determine animal type
		var animal_type = ""
		var entity_name = entity.name.to_lower()
		if "swallow" in entity_name or "bluejay" in entity_name:
			animal_type = "bird"
		elif "fish" in entity_name:
			animal_type = "fish"
		elif "rabbit" in entity_name:
			animal_type = "rabbit"
		elif "cat" in entity_name:
			animal_type = "cat"
		else:
			continue  # Not an animal we're interested in

		# Check if we want to watch this animal
		var watch_chance = OTHER_WATCH_CHANCE
		if animal_type in _favorite_animals:
			watch_chance = FAVORITE_WATCH_CHANCE

		if randf() < watch_chance:
			return entity

	return null


func _start_pathfinding(goal: Vector3):
	"""Start pathfinding to a goal position"""
	if not _terrain:
		_current_path = []
		return

	# Use SimplePathfinding to find a path
	_current_path = SimplePathfinding.find_path(global_position, goal, _terrain)
	_path_index = 0
	_path_recalculate_timer = 0.0

	if _current_path.is_empty():
		print("%s: Could not find path to goal" % npc_display_name)
	else:
		print("%s: Found path with %d waypoints" % [npc_display_name, _current_path.size()])
		_current_state = NPCState.PATHFINDING


func _pick_new_wander_direction():
	"""Pick a random direction to wander - with edge detection"""
	# Pick a random direction
	var angle = randf() * TAU
	var test_direction = Vector3(cos(angle), 0, sin(angle)).normalized()

	# Only do edge check if we might be near an edge (optimization + less strict)
	# Check 4 blocks ahead to give plenty of warning
	if not _is_ground_ahead(test_direction, 4.0):
		# No ground ahead - try to find a safer direction
		# But only try a few times, then give up and accept any direction
		for attempt in range(3):
			angle = randf() * TAU
			test_direction = Vector3(cos(angle), 0, sin(angle)).normalized()

			if _is_ground_ahead(test_direction, 4.0):
				# Found a safe direction!
				break

	# Use whatever direction we ended up with (safe or not - NPCs can handle it)
	_wander_direction = test_direction
	_wander_duration = randf_range(2.0, 5.0)


func _is_ground_ahead(direction: Vector3, distance: float) -> bool:
	"""Check if there's ground ahead in the given direction (prevent falling off edges)"""
	var check_pos = global_position + direction * distance

	# Use VoxelTool to check if there's ground (more reliable for voxel terrain)
	var terrain = get_tree().root.get_node_or_null("Main/Game/VoxelTerrain")
	if not terrain:
		return true  # If we can't find terrain, assume it's safe (fail-open)

	var voxel_tool = terrain.get_voxel_tool()
	if not voxel_tool:
		return true  # Fail-open

	# Check a few blocks down from the test position
	var test_pos_i = Vector3i(check_pos)
	for y_offset in range(5):
		var check_voxel = Vector3i(test_pos_i.x, test_pos_i.y - y_offset, test_pos_i.z)
		var voxel_id = voxel_tool.get_voxel(check_voxel)
		if voxel_id != 0:  # Found solid ground
			return true

	# No ground found within 5 blocks down - probably an edge!
	return false


func _update_sprite_direction() -> void:
	"""Update sprite based on movement direction (like companion)"""
	if not _sprite:
		return
	
	# Get player reference
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Get current velocity (horizontal only)
	var velocity = get_velocity()
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	var speed = horizontal_velocity.length()
	
	# If moving too slow, keep current direction
	if speed < MIN_SPEED_FOR_DIRECTION:
		return
	
	# Get direction from NPC to player
	var to_player = (player.global_position - global_position).normalized()
	to_player.y = 0  # Only consider horizontal direction
	
	# Calculate dot product (positive = moving toward, negative = moving away)
	var dot_product = horizontal_velocity.normalized().dot(to_player)
	
	# Decide if we should show back or front
	var should_show_back = dot_product < 0  # Moving away from player
	
	# Only update if sprite direction changed
	var is_showing_front = _current_sprite_is_front
	var should_show_front = not should_show_back
	
	if is_showing_front != should_show_front:
		if should_show_back and _back_sprite_path != "":
			# Switch to back sprite
			var back_texture = load(_back_sprite_path)
			if back_texture:
				_sprite.texture = back_texture
				_current_sprite_is_front = false
				
				# Update shader texture parameter (more efficient than recreating material)
				if _sprite.material_override:
					_sprite.material_override.set_shader_parameter("texture_albedo", back_texture)
				
				# Preserve scale when swapping
				_sprite.scale = Vector3(_sprite_height_scale, _sprite_height_scale, _sprite_height_scale)
		elif should_show_front and _front_sprite_path != "":
			# Switch to front sprite
			var front_texture = load(_front_sprite_path)
			if front_texture:
				_sprite.texture = front_texture
				_current_sprite_is_front = true
				
				# Update shader texture parameter (more efficient than recreating material)
				if _sprite.material_override:
					_sprite.material_override.set_shader_parameter("texture_albedo", front_texture)
				
				# Preserve scale when swapping
				_sprite.scale = Vector3(_sprite_height_scale, _sprite_height_scale, _sprite_height_scale)


## Get default dialogue greeting text based on job type
static func get_default_greeting(job: String, npc_name: String) -> String:
	"""Generate a default greeting message based on NPC job"""
	match job:
		"cook":
			return "Hello! I'm %s, the cook. Looking for some food?" % npc_name
		"banker":
			return "Welcome to Conner's Bank! I'm %s. Want to trade blocks?" % npc_name
		"power_shop":
			return "Hey! I'm %s. Want to fuse weapons with powers?" % npc_name
		"food_merchant":
			return "Welcome! I'm %s. I sell raw and cooked foods." % npc_name
		"merchant":
			return "Welcome! I'm %s. I buy and sell weapons and items." % npc_name
		"town_manager":
			return "Hi! I'm %s, the town manager. Want to customize your homebase?" % npc_name
		"armorer":
			return "Greetings! I'm %s. Need your gear enhanced?" % npc_name
		"blacksmith":
			return "Hey there! I'm %s the blacksmith. Got rust to refine?" % npc_name
		"companion":
			return "Hi! I'm %s. Want to swap companions?" % npc_name
		"ruinkeeper":
			return "Greetings, traveler. I'm %s, keeper of the ruins. Need to travel?" % npc_name
		_:
			return "Hello! I'm %s." % npc_name
