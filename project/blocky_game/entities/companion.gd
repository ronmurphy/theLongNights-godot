extends GroundEntity
class_name Companion

const CharacterQuiz = preload("res://long_nights/CharacterQuiz.gd")

## Companion - AI companion that follows player and assists in combat
## Based on CompanionManager settings (race/role)
## Attacks what player attacks, uses items based on role

## States
enum State {
	IDLE,
	FOLLOWING,
	ATTACKING
}

var _state: State = State.IDLE
var _player: Node3D = null
var _current_target: Node = null
var _attack_cooldown: float = 0.0
var _weapon_item: Node = null  # Reference to weapon item for attacking
var _equipped_inv_item = null  # Inventory item with skyshard powers (weapon)
var _equipped_accessory_item = null  # Accessory inventory item (second equip slot)

## AI parameters - Base values (modified by behavior mode)
const BASE_FOLLOW_DISTANCE = 5.0  # Base follow distance
const BASE_ATTACK_RANGE = 40.0  # Base attack range
const TELEPORT_DISTANCE = 30.0  # Teleport to player if beyond this distance
const MELEE_RANGE = 4.0  # Melee attack range
const ATTACK_COOLDOWN = 1.5  # Seconds between attacks
const MOVE_SPEED_MULTIPLIER = 1.0  # Matches movement_speed from base class

# Active AI parameters (modified by behavior mode)
var FOLLOW_DISTANCE = BASE_FOLLOW_DISTANCE
var ATTACK_RANGE = BASE_ATTACK_RANGE

## Behavior mode
var support_mode := "normal"  # "normal", "aggressive", "defensive", "guard"
var _guard_position: Vector3 = Vector3.ZERO  # Position to guard when in guard mode
var _is_guarding: bool = false  # Whether actively guarding a position

## Companion Title System - Synergies based on role + equipment + behavior
var active_title: String = ""  # Current title name (e.g., "Paladin", "Berserker")
var title_emoji: String = ""  # Emoji badge for the title (e.g., "🛡️", "🔥")
var title_benefit: Dictionary = {}  # Benefits granted by the title

## Weapon reference (loaded from CompanionManager)
var weapon_path: String = ""
var weapon_name: String = ""
var is_ranged_weapon: bool = false
var _lightning_from_sky: bool = true  # Alternates for wizard lightning

## Hunting mode
var is_hunting: bool = false
var _hunt_wander_timer: float = 0.0
var _hunt_wander_target: Vector3 = Vector3.ZERO
const HUNT_WANDER_INTERVAL = 5.0  # Change direction every 5 seconds
const HUNT_WANDER_DISTANCE = 80.0  # Wander up to 80 blocks away

## Sprite direction tracking
var _front_sprite_path: String = ""
var _back_sprite_path: String = ""
var _jumping_sprite_path: String = ""
var _jumping_back_sprite_path: String = ""
var _running_sprite_path: String = ""  # NOTE: Only human_male and elf_female have sprites currently
var _running_back_sprite_path: String = ""  # NOTE: Will add all races/genders soon
var _current_sprite_is_front: bool = true  # Track which sprite we're currently showing
var _current_sprite_is_jumping: bool = false  # Track if showing jumping sprite
var _current_sprite_is_running: bool = false  # Track if showing running sprite
var _run_flip_distance: float = 0.0  # Track distance for flipping animation
var _last_position_for_flip: Vector3 = Vector3.ZERO  # Track movement for flip animation
const MIN_SPEED_FOR_DIRECTION = 0.5  # Minimum speed to consider direction
const MIN_SPEED_FOR_RUNNING = 2.0  # Speed threshold to show running sprite
const FLIP_DISTANCE = 1.0  # Flip sprite every 1 block traveled

## Bento auto-eat system (shares player's bento box)
var _recently_ate := false  # Prevent eating entire bento instantly
const AUTO_EAT_HP_THRESHOLD = 0.25  # Auto-eat at 25% HP
var _inventory = null  # Reference to player's inventory
var _item_db = null  # Reference to item database

## Void fog damage tracking
var _last_void_fog_position := Vector3i(999999, 999999, 999999)  # Track last fog position

## Teleport retry system (prevents infinite loop in sky ruins)
var _teleport_retry_timer: float = 0.0  # Timer before retrying teleport
const TELEPORT_RETRY_DELAY = 2.0  # Seconds to wait before retrying (matches teleport_stone cooldown)


func _ready():
	# Set up as friendly entity BEFORE calling super._ready()
	# (so entity_base adds us to the correct group)
	team = Team.PLAYER
	entity_name = CompanionManager.get_companion_name()

	super._ready()
	
	# Add to companions group so inventory buttons can find us
	add_to_group("companions")

	# Apply stats from CompanionManager
	max_hp = CompanionManager.get_companion_max_hp()
	current_hp = max_hp
	defense = CompanionManager.get_companion_defense()
	attack_damage = CompanionManager.get_companion_attack_bonus()
	movement_speed = 4.0  # Base movement speed

	# Apply race-based speed multiplier
	var speed_multiplier = CharacterQuiz.get_race_speed_multiplier(CompanionManager.companion_race)
	movement_speed *= speed_multiplier

	# Set collision box (similar to player)
	set_collision_box(Vector3(0.8, 1.6, 0.8))

	# Get sprite paths based on race/gender (front, back, and jumping)
	# Use roster-aware avatar helper to ensure the spawned companion's sprites
	# match the roster active values when the roster system is enabled.
	var sprite_path = CompanionManager.get_active_avatar_path()
	if sprite_path != "":
		_front_sprite_path = sprite_path
		create_billboard_shadow(_front_sprite_path)
		# Generate back sprite path by inserting "_back" before .png
		_back_sprite_path = sprite_path.get_basename() + "_back.png"
		# Generate jumping sprite paths
		_jumping_sprite_path = sprite_path.get_basename() + "_jumping.png"
		_jumping_back_sprite_path = sprite_path.get_basename() + "_jumping_back.png"
		# Generate running sprite paths
		# NOTE: Running sprites currently only available for human_male and elf_female
		_running_sprite_path = sprite_path.get_basename() + "_run.png"
		_running_back_sprite_path = sprite_path.get_basename() + "_run_back.png"
		_create_sprite(sprite_path, 0.004)

		# Apply stencil shader on all graphics settings
		_apply_stencil_shader(sprite_path)

	# Get weapon path and load weapon item
	weapon_path = CompanionManager.get_companion_weapon()
	_load_weapon()
	
	# Load saved accessory if available
	if CompanionManager.saved_accessory_id >= 0:
		_load_accessory(CompanionManager.saved_accessory_id)
	
	# Check for title synergies after equipment is loaded
	call_deferred("_check_for_synergy_titles")

	# Helper: after initial equip/title is set, push current live data back into
	# CompanionManager roster—this keeps inventory & PartyUI in sync quickly.
	
	# Connect to inventory equipment changes
	call_deferred("_connect_to_inventory")

	# If using roster system, update the active roster entry from this spawned entity
	# so UI and persistence reflect any live equip/title changes. Do this deferred
	# so other setup has a chance to complete.
	if CompanionManager and CompanionManager.using_roster_system:
		call_deferred("_sync_roster_from_scene")

	# Find player
	_find_player()

	# Connect to player's attack signal if available
	if _player and _player.has_signal("attacked_entity"):
		_player.attacked_entity.connect(_on_player_attacked)
	
	# Initialize behavior mode (shows in PartyUI)
	call_deferred("_initialize_behavior_mode")

	print("Companion spawned: %s %s (HP: %d, Def: %d%%, Atk: +%d)" % [
		CompanionManager.companion_race,
		CompanionManager.companion_role,
		max_hp,
		defense,
		attack_damage
	])
	print("  Speed multiplier: %.2fx (Race: %s)" % [speed_multiplier, CompanionManager.companion_race])

	# CompanionManager will emit companion_spawned after sync; this guarantees
	# the roster entry reflects live entity state before UIs react. See
	# _sync_roster_from_scene() for the actual signal emission.


func _get_inventory():
	"""Helper to find inventory in scene tree"""
	var inventory = get_node_or_null("/root/Main/Game/CharacterAvatar/Inventory")
	if not inventory and _player:
		inventory = _player.get_node_or_null("Inventory")
	return inventory


func _sync_roster_from_scene() -> void:
	if CompanionManager and CompanionManager.using_roster_system:
		print("Companion: Syncing live entity state to roster for %s" % entity_name)
		CompanionManager.update_active_companion_from_scene(self)
		# Let inventory update after roster sync
		var inv = _get_inventory()
		if inv and inv.has_method("_update_companion_panel"):
			inv.call_deferred("_update_companion_panel")
		# companion_spawned emission removed (reverted)


func _load_weapon():
	# Get item database reference
	var item_db = get_node_or_null("/root/Main/Game/Items")
	if not item_db:
		push_warning("Companion: Could not find item database")
		return
	
	# Check if companion has an equipped weapon from inventory
	var inventory = _get_inventory()
	if inventory:
		var equipped_weapon_item = inventory.get_companion_equipped_weapon()
		if equipped_weapon_item != null:
			# Store inventory item for power access
			_equipped_inv_item = equipped_weapon_item
			
			# Use equipped weapon from inventory
			_weapon_item = item_db.get_item(equipped_weapon_item.id)
			if _weapon_item:
				weapon_name = _weapon_item.base_info.name
				# Determine if ranged based on weapon
				is_ranged_weapon = weapon_name in ["crossbow", "ice_bow", "fire_staff", "rocket_launcher", "throwing_knives"]
				print("Companion using equipped weapon: %s (ID: %d)" % [weapon_name, equipped_weapon_item.id])
				
				# Check for skyshard powers
				if equipped_weapon_item.skyshard_power != "":
					print("  ✨ Companion weapon has power: %s" % equipped_weapon_item.skyshard_power)
				
				return

	# Fallback to default weapon based on race

	# Map weapon path to weapon name
	match CompanionManager.companion_race:
		"dwarf":
			weapon_name = "stone_hammer"
			is_ranged_weapon = false
		"elf":
			weapon_name = "crossbow"  # or ice_bow
			is_ranged_weapon = true
		"goblin":
			if CompanionManager.companion_gender == "female":
				weapon_name = "throwing_knives"
				is_ranged_weapon = true
			else:
				weapon_name = "rocket_launcher"
				is_ranged_weapon = true
		"human":
			weapon_name = "machete"
			is_ranged_weapon = false

	# Find the weapon item by name
	for i in range(100):  # Assume max 100 items
		var item = item_db.get_item(i)
		if item and item.base_info.name == weapon_name:
			_weapon_item = item
			print("Companion loaded default weapon: %s (ID: %d)" % [weapon_name, i])
			return

	push_warning("Companion: Could not find weapon %s in database" % weapon_name)


func _load_accessory(accessory_id: int):
	# Get item database reference
	var item_db = get_node_or_null("/root/Main/Game/Items")
	if not item_db:
		push_warning("Companion: Could not find item database")
		return
	
	# Load the accessory item from database
	var accessory_item = item_db.get_item(accessory_id)
	if accessory_item:
		# Load InventoryItem class
		const InventoryItem = preload("res://blocky_game/player/inventory_item.gd")
		
		# Create inventory item
		var inv_item = InventoryItem.new()
		inv_item.type = InventoryItem.TYPE_ITEM
		inv_item.id = accessory_id
		inv_item.count = 1
		inv_item.skyshard_power = ""  # Powers are loaded from inventory separately
		
		# Store as equipped accessory
		_equipped_accessory_item = inv_item
		print("Companion loaded accessory: %s (ID: %d)" % [accessory_item.base_info.name, accessory_id])
	else:
		push_warning("Companion: Could not load accessory ID %d" % accessory_id)


func _find_player():
	# Find player in the "player" group
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]
		print("Companion found player: ", _player.name)
	else:
		push_warning("Companion: Could not find player!")


func _connect_to_inventory():
	"""Connect to inventory's equipment_changed signal"""
	var inventory = _get_inventory()
	
	if inventory:
		if inventory.has_signal("equipment_changed"):
			inventory.equipment_changed.connect(_on_equipment_changed)
		else:
			push_warning("Companion: Inventory doesn't have equipment_changed signal!")
	else:
		# Retry after a delay
		await get_tree().create_timer(1.0).timeout
		_connect_to_inventory()


func _on_equipment_changed():
	"""Called when player changes equipment in inventory"""
	_load_weapon()
	
	# Update PartyUI weapon icon
	var game_node = get_node_or_null("/root/Main/Game")
	if game_node:
		for child in game_node.get_children():
			if child.has_method("_update_companion_weapon"):
				child._update_companion_weapon()
				break


func set_accessory(inv_item):
	"""Set companion's accessory item (for EQUIP powers)"""
	_equipped_accessory_item = inv_item
	if inv_item != null and inv_item.skyshard_power != "":
		print("  ✨ Companion accessory has power: %s" % inv_item.skyshard_power)
	
	# Check for title synergies when equipment changes
	_check_for_synergy_titles()


func get_all_equipped_powers() -> Array:
	"""Get all active EQUIP powers from weapon + accessory"""
	var powers = []
	
	# Check weapon power
	if _equipped_inv_item != null and _equipped_inv_item.skyshard_power != "":
		powers.append(_equipped_inv_item.skyshard_power)
	
	# Check accessory power
	if _equipped_accessory_item != null and _equipped_accessory_item.skyshard_power != "":
		powers.append(_equipped_accessory_item.skyshard_power)
	
	return powers


func set_behavior_mode(mode: String):
	"""Change companion's behavior mode"""
	support_mode = mode
	_apply_behavior_modifiers()
	
	# Update PartyUI to show behavior mode
	# Find PartyUI by searching for a node with the update_companion_behavior method
	var party_ui = null
	var game_node = get_tree().root.get_node_or_null("Main/Game")
	if game_node:
		for child in game_node.get_children():
			if child.has_method("update_companion_behavior"):
				party_ui = child
				break
	
	if party_ui:
		party_ui.update_companion_behavior(mode)
	
	print("🎯 %s switched to %s mode" % [entity_name, mode.capitalize()])
	
	# Check for title synergies when behavior changes
	_check_for_synergy_titles()


func _apply_behavior_modifiers():
	"""Apply stat changes based on behavior mode"""
	match support_mode:
		"aggressive":
			# Double attack range, stay closer to player for support
			ATTACK_RANGE = BASE_ATTACK_RANGE * 2.0
			FOLLOW_DISTANCE = BASE_FOLLOW_DISTANCE * 0.7
			_is_guarding = false
			print("  ⚔️ Aggressive: Attack range x2 (%.1f blocks)" % ATTACK_RANGE)
		
		"defensive":
			# Shorter attack range, stay very close to player
			ATTACK_RANGE = BASE_ATTACK_RANGE * 0.6
			FOLLOW_DISTANCE = BASE_FOLLOW_DISTANCE * 0.5
			_is_guarding = false
			print("  🛡️ Defensive: Close range (%.1f blocks), protective stance" % ATTACK_RANGE)
		
		"guard":
			# Set guard position to current location, don't follow player
			_guard_position = global_position
			_is_guarding = true
			ATTACK_RANGE = BASE_ATTACK_RANGE * 1.2  # Slightly longer range for area defense
			print("  🏰 Guard: Defending position at (%.1f, %.1f, %.1f)" % [_guard_position.x, _guard_position.y, _guard_position.z])
		
		"normal":
			# Reset to defaults
			ATTACK_RANGE = BASE_ATTACK_RANGE
			FOLLOW_DISTANCE = BASE_FOLLOW_DISTANCE
			_is_guarding = false
			print("  ⚖️ Normal: Balanced behavior")


## ============================================================================
## COMPANION TITLE SYNERGY SYSTEM
## ============================================================================

func _check_for_synergy_titles():
	"""Check for synergies between role, equipment, behavior, and award titles"""
	# Collect equipped powers
	var equipped_powers = []
	if _equipped_inv_item and _equipped_inv_item.skyshard_power != "":
		equipped_powers.append(_equipped_inv_item.skyshard_power)
	if _equipped_accessory_item and _equipped_accessory_item.skyshard_power != "":
		equipped_powers.append(_equipped_accessory_item.skyshard_power)
	
	var role = CompanionManager.companion_role
	var race = CompanionManager.companion_race
	var behavior = support_mode
	var weapon = weapon_name
	
	var new_title = ""
	var new_emoji = ""
	var new_benefits = {}
	
	# ===== HEALER TITLES =====
	if role == "healer":
		# Paladin: stone_skin + life_stealer
		if "stone_skin" in equipped_powers and "life_stealer" in equipped_powers:
			new_title = "Paladin"
			new_emoji = "🛡️"
			new_benefits = {"heal_bonus": 0.15}  # +15% healing
		
		# Battle Cleric: flame_aura + aggressive
		elif "flame_aura" in equipped_powers and behavior == "aggressive":
			new_title = "Battle Cleric"
			new_emoji = "⚡"
			new_benefits = {"damage_on_heal": 0.3}  # Deal 30% of heal as AoE damage
		
		# Moon Priestess: moon_jump + defensive
		elif "moon_jump" in equipped_powers and behavior == "defensive":
			new_title = "Moon Priestess"
			new_emoji = "🌙"
			new_benefits = {"leap_range": 1.5}  # Can leap to player from 1.5x distance
		
		# Warden: stone_skin + defensive
		elif "stone_skin" in equipped_powers and behavior == "defensive":
			new_title = "Warden"
			new_emoji = "🧱"
			new_benefits = {"tank_bonus": 0.2}  # +20% defense
	
	# ===== WARRIOR/TANK TITLES =====
	elif role == "tank":
		# Berserker: flame_aura + aggressive
		if "flame_aura" in equipped_powers and behavior == "aggressive":
			new_title = "Berserker"
			new_emoji = "🔥"
			new_benefits = {"rage_damage": 0.25}  # +25% damage below 50% HP
		
		# Mountain: stone_skin + guard
		elif "stone_skin" in equipped_powers and behavior == "guard":
			new_title = "Mountain"
			new_emoji = "🏔️"
			new_benefits = {"knockback": 1.5}  # Enemies bounce back harder
		
		# Duelist: moon_jump + normal
		elif "moon_jump" in equipped_powers and behavior == "normal":
			new_title = "Duelist"
			new_emoji = "⚔️"
			new_benefits = {"dodge_chance": 0.15}  # 15% dodge chance
		
		# Juggernaut: stone_skin + aggressive
		elif "stone_skin" in equipped_powers and behavior == "aggressive":
			new_title = "Juggernaut"
			new_emoji = "🛡️"
			new_benefits = {"unstoppable": true}  # Less knockback taken
	
	# ===== ROGUE TITLES =====
	elif role == "rogue":
		# Assassin: aggressive + ranged weapon
		if behavior == "aggressive" and is_ranged_weapon:
			new_title = "Assassin"
			new_emoji = "🗡️"
			new_benefits = {"first_strike": 0.5}  # +50% damage on first hit
		
		# Shadow Dancer: moon_jump + defensive
		elif "moon_jump" in equipped_powers and behavior == "defensive":
			new_title = "Shadow Dancer"
			new_emoji = "👻"
			new_benefits = {"evasion": 0.2}  # 20% harder to hit near player
		
		# Reaper: life_stealer + aggressive
		elif "life_stealer" in equipped_powers and behavior == "aggressive":
			new_title = "Reaper"
			new_emoji = "💀"
			new_benefits = {"kill_heal": 0.3}  # Restore 30% HP on kill
		
		# Sniper: guard + ranged weapon
		elif behavior == "guard" and is_ranged_weapon:
			new_title = "Sniper"
			new_emoji = "🎯"
			new_benefits = {"stationary_bonus": 0.3}  # +30% damage when guarding
	
	# ===== WIZARD TITLES =====
	elif role == "wizard":
		# Archmage: 2+ different powers
		if len(equipped_powers) >= 2:
			new_title = "Archmage"
			new_emoji = "🧙"
			new_benefits = {"power_efficiency": 0.15}  # Powers recharge 15% faster
		
		# Elementalist: flame_aura + ice weapon
		elif "flame_aura" in equipped_powers and ("ice" in weapon or "frost" in weapon):
			new_title = "Elementalist"
			new_emoji = "🔮"
			new_benefits = {"dual_element": true}  # Chance to apply both effects
		
		# Astral Knight: moon_jump + defensive + magic weapon
		elif "moon_jump" in equipped_powers and behavior == "defensive":
			new_title = "Astral Knight"
			new_emoji = "🌌"
			new_benefits = {"teleport_intercept": true}  # Can teleport to block attacks
	
	# Apply title if found, or clear if none matches
	if new_title != "":
		_set_title(new_title, new_emoji, new_benefits)
	else:
		_clear_title()


func _set_title(title: String, emoji: String, benefits: Dictionary):
	"""Set companion's title and benefits"""
	# Only announce if this is a new title
	var is_new_title = (active_title != title)
	
	active_title = title
	title_emoji = emoji
	title_benefit = benefits
	
	if is_new_title:
		print("✨ %s has become a %s %s!" % [entity_name, emoji, title])
		# Update PartyUI to show the new title
		_update_party_ui_title()


func _clear_title():
	"""Clear companion's title"""
	if active_title != "":
		active_title = ""
		title_emoji = ""
		title_benefit = {}
		_update_party_ui_title()


func _update_party_ui_title():
	"""Update PartyUI to display companion's title"""
	var party_ui = null
	var game_node = get_tree().root.get_node_or_null("Main/Game")
	if game_node:
		for child in game_node.get_children():
			if child.has_method("update_companion_title"):
				party_ui = child
				break
	
	if party_ui:
		party_ui.update_companion_title(title_emoji, active_title)


func _initialize_behavior_mode():
	"""Initialize behavior mode display in PartyUI on spawn"""
	# Wait for PartyUI to be ready
	await get_tree().create_timer(0.5).timeout
	
	# Find PartyUI by searching for a node with the update_companion_behavior method
	var party_ui = null
	var game_node = get_tree().root.get_node_or_null("Main/Game")
	if game_node:
		for child in game_node.get_children():
			if child.has_method("update_companion_behavior"):
				party_ui = child
				break
	
	if party_ui:
		party_ui.update_companion_behavior(support_mode)



func _process(delta: float):
	if not is_alive:
		return

	# Auto-eat from bento box if HP is low
	_try_auto_eat_from_bento()

	# Handle void_fog damage (5 damage when moving to a new fog block)
	_check_void_fog_damage()

	# Apply EQUIP powers (passive effects)
	_apply_equip_powers(delta)
	
	# Update flame aura visual effect
	_update_flame_aura_visual()

	# Update attack cooldown
	if _attack_cooldown > 0:
		_attack_cooldown -= delta

	# Update teleport retry timer
	if _teleport_retry_timer > 0:
		_teleport_retry_timer -= delta

	# Find player if we don't have one
	if _player == null:
		_find_player()
		return

	# If hunting, use special wandering logic
	if is_hunting:
		_handle_hunting(delta)
		_update_sprite_direction()  # Also update sprite during hunting!
		_update_jumping_state()  # Also update jumping sprite during hunting!
		_update_running_state()  # Also update running sprite during hunting! (NOTE: Only human_male/elf_female have sprites)
		return

	# Check if player is too far away and needs teleport (NOT in guard mode)
	var distance_to_player = global_position.distance_to(_player.global_position)
	if not _is_guarding and distance_to_player > TELEPORT_DISTANCE:
		# Only teleport if player is on the ground (check _grounded variable)
		if _player.get("_grounded") == true:
			# Check if we're still in cooldown from last failed teleport attempt
			if _teleport_retry_timer > 0:
				return  # Wait for retry timer to expire

			# Check if there's ground at the player's location before teleporting
			if _check_ground_at_player():
				_teleport_to_player()
				return
			else:
				# No ground found, set retry timer and wait
				_teleport_retry_timer = TELEPORT_RETRY_DELAY
				print("%s: No ground at player location, waiting %.1f seconds before retry..." % [entity_name, TELEPORT_RETRY_DELAY])
				return

	# Determine state based on situation
	_update_state()

	# Act based on state
	match _state:
		State.IDLE:
			_handle_idle(delta)
		State.FOLLOWING:
			_handle_following(delta)
		State.ATTACKING:
			_handle_attacking(delta)

	# Update sprite direction, jumping state, and running state based on movement
	_update_sprite_direction()
	_update_jumping_state()
	# NOTE: Running sprites currently only available for human_male and elf_female
	if not _current_sprite_is_jumping:  # Only show running when not jumping
		_update_running_state()


func _update_state():
	# Guard mode: Stay at guard position, only attack nearby enemies
	if _is_guarding:
		# Don't follow player, stay near guard position
		var distance_to_guard_pos = global_position.distance_to(_guard_position)
		
		# If we've wandered too far from guard position, return to it
		if distance_to_guard_pos > 3.0:
			_state = State.FOLLOWING  # Reuse FOLLOWING state to return to guard position
			return
		
		# Check if we have a target to attack
		if _current_target != null and is_instance_valid(_current_target) and _current_target.is_alive:
			var distance = global_position.distance_to(_current_target.global_position)
			var attack_range = ATTACK_RANGE if is_ranged_weapon else MELEE_RANGE
			if distance <= attack_range:
				_state = State.ATTACKING
				return
		
		# Otherwise stay idle at guard position
		_state = State.IDLE
		return
	
	# Normal behavior: Check if we have a target and can attack
	if _current_target != null and is_instance_valid(_current_target):
		if _current_target.is_alive:
			var distance = global_position.distance_to(_current_target.global_position)
			var attack_range = ATTACK_RANGE if is_ranged_weapon else MELEE_RANGE
			if distance <= attack_range:
				_state = State.ATTACKING
				return

	# Check distance to player
	var distance_to_player = global_position.distance_to(_player.global_position)
	if distance_to_player > FOLLOW_DISTANCE:
		_state = State.FOLLOWING
	else:
		_state = State.IDLE


func _handle_idle(delta: float):
	# Stand still, face player
	var velocity_input = Vector3.ZERO
	apply_ground_movement(delta, velocity_input)

	# Look for nearby enemies to auto-attack
	_look_for_threats()


func _handle_following(delta: float):
	# In guard mode, return to guard position instead of following player
	if _is_guarding:
		var direction = (_guard_position - global_position).normalized()
		direction.y = 0  # Don't move vertically
		var velocity_input = direction * movement_speed * MOVE_SPEED_MULTIPLIER
		apply_ground_movement(delta, velocity_input)
		return
	
	# Normal mode: Move towards player
	var direction = (_player.global_position - global_position).normalized()
	direction.y = 0  # Don't move vertically

	var velocity_input = direction * movement_speed * MOVE_SPEED_MULTIPLIER
	apply_ground_movement(delta, velocity_input)


func _handle_attacking(delta: float):
	if _current_target == null or not is_instance_valid(_current_target) or not _current_target.is_alive:
		_current_target = null
		return

	var distance = global_position.distance_to(_current_target.global_position)
	var attack_range = ATTACK_RANGE if is_ranged_weapon else MELEE_RANGE

	# Move towards target if too far (for melee, or get closer for ranged)
	var optimal_range = attack_range * 0.7 if is_ranged_weapon else attack_range * 0.8
	if distance > optimal_range:
		var direction = (_current_target.global_position - global_position).normalized()
		direction.y = 0
		var velocity_input = direction * movement_speed * MOVE_SPEED_MULTIPLIER
		apply_ground_movement(delta, velocity_input)
	else:
		# Stop moving and perform actions
		apply_ground_movement(delta, Vector3.ZERO)

		# Action priority: Self-heal > Role action > Attack
		if _attack_cooldown <= 0:
			# 1. Check if we need to self-heal
			if _try_self_heal():
				_attack_cooldown = ATTACK_COOLDOWN
				return

			# 2. Try role-specific action
			if _try_role_action():
				_attack_cooldown = ATTACK_COOLDOWN
				return

			# 3. Default: Attack with weapon
			_attack_target()
			_attack_cooldown = ATTACK_COOLDOWN


func _attack_target():
	if _current_target == null or not _current_target.is_alive:
		return

	if _weapon_item == null:
		push_warning("Companion: No weapon loaded, cannot attack!")
		return

	# Create a transform facing the target
	var aim_direction = (_current_target.global_position - global_position).normalized()
	var attack_transform = Transform3D()
	attack_transform.origin = global_position + Vector3(0, 1.0, 0)  # Aim from chest height

	# Make the transform look in the direction of the target
	attack_transform = attack_transform.looking_at(global_position + aim_direction, Vector3.UP)

	# === TITLE BENEFIT: Berserker - Rage Damage (+25% damage below 50% HP) ===
	if title_benefit.has("rage_damage"):
		var hp_percent = float(current_hp) / float(max_hp)
		if hp_percent < 0.5:
			# Apply rage bonus to weapon damage (if weapon has damage property)
			if _weapon_item.has("base_damage"):
				var original_damage = _weapon_item.base_damage
				_weapon_item.base_damage = int(original_damage * (1.0 + title_benefit.rage_damage))
				print("🔥 Berserker RAGE! (+%d%% damage)" % int(title_benefit.rage_damage * 100))

	# === TITLE BENEFIT: Sniper - Stationary Bonus (+30% damage when guarding) ===
	if title_benefit.has("stationary_bonus") and _is_guarding:
		if _weapon_item.has("base_damage"):
			var original_damage = _weapon_item.base_damage
			_weapon_item.base_damage = int(original_damage * (1.0 + title_benefit.stationary_bonus))
			print("🎯 Sniper precision! (+%d%% damage)" % int(title_benefit.stationary_bonus * 100))

	# Use the weapon's use() method (just like player does)
	# Pass inventory item so powers can trigger!
	if _equipped_inv_item != null:
		_weapon_item.use(attack_transform, _equipped_inv_item)
	else:
		_weapon_item.use(attack_transform)

	print("%s uses %s against %s!" % [entity_name, weapon_name, _current_target.entity_name])
	
	# === TITLE BENEFIT: Assassin - First Strike (+50% damage on first hit) ===
	# Note: This needs tracking if target was already hit, implement later if needed


func _look_for_threats():
	# Auto-attack nearby enemies
	var enemies = get_tree().get_nodes_in_group("enemy_entities")
	var closest_enemy = null
	var attack_range = ATTACK_RANGE if is_ranged_weapon else MELEE_RANGE
	var closest_distance = attack_range

	for enemy in enemies:
		if not enemy.is_alive:
			continue

		var distance = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy

	if closest_enemy != null:
		_current_target = closest_enemy


func _on_player_attacked(entity: Node):
	# When player attacks, companion should also attack that target
	if entity != null and entity.is_alive and entity.team == Team.ENEMY:
		_current_target = entity
		print("%s will assist player against %s!" % [entity_name, entity.entity_name])


## Override to show companion death message
func _on_death():
	print("Companion %s has fallen!" % entity_name)
	super._on_death()

	# TODO: Emit signal to PartyUI to update companion status


## Check for void_fog damage
func _check_void_fog_damage() -> void:
	# Find terrain node (should be at /root/Main/Game/VoxelTerrain)
	var terrain_node = get_node_or_null("/root/Main/Game/VoxelTerrain")
	if not terrain_node:
		return

	var vt: VoxelTool = terrain_node.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	# Check block at companion's feet
	var companion_block_pos = Vector3i(floor(global_position.x), floor(global_position.y - 0.5), floor(global_position.z))
	var block_id = vt.get_voxel(companion_block_pos)

	# VOID_FOG = 55 (from generator.gd)
	const VOID_FOG = 55
	if block_id == VOID_FOG:
		# Check if we moved to a new fog block
		if companion_block_pos != _last_void_fog_position:
			_last_void_fog_position = companion_block_pos
			# Deal 5 damage (environmental damage, respects defense)
			var actual_damage = max(1, 5 - int(5 * defense / 100.0))
			current_hp -= actual_damage
			current_hp = max(0, current_hp)
			took_damage.emit(actual_damage, null)
			print("💀 %s took void fog damage! -%d HP (now %d/%d)" % [entity_name, actual_damage, current_hp, max_hp])

			if current_hp <= 0 and is_alive:
				is_alive = false
				_on_death()
	else:
		# Not in fog anymore, reset position
		_last_void_fog_position = Vector3i(999999, 999999, 999999)


## Take damage and emit signal for UI update
func take_damage(amount: int, from: Node = null) -> void:
	# === TITLE BENEFIT: Duelist - Dodge Chance (15% dodge) ===
	if title_benefit.has("dodge_chance"):
		if randf() < title_benefit.dodge_chance:
			print("⚔️ %s DODGED the attack!" % entity_name)
			_spawn_dodge_effect()
			return  # Dodged! No damage
	
	# === TITLE BENEFIT: Shadow Dancer - Evasion (20% harder to hit near player) ===
	if title_benefit.has("evasion") and _player:
		var distance_to_player = global_position.distance_to(_player.global_position)
		if distance_to_player < FOLLOW_DISTANCE * 1.5:  # Within 1.5x follow distance
			if randf() < title_benefit.evasion:
				print("👻 %s faded into shadows and evaded!" % entity_name)
				_spawn_dodge_effect()
				return  # Evaded!
	
	# Check for stone_skin power from weapon OR accessory (50% damage reduction)
	var powers = get_all_equipped_powers()
	if "stone_skin" in powers:
		amount = int(amount * 0.5)
		print("🛡️ %s's Stone Skin! Reduced damage to %d" % [entity_name, amount])
	
	# === TITLE BENEFIT: Warden - Tank Bonus (+20% defense = -16.7% damage taken) ===
	if title_benefit.has("tank_bonus"):
		amount = int(amount * (1.0 - (title_benefit.tank_bonus * 0.8)))  # ~80% effectiveness
		print("🧱 Warden's defense! Reduced to %d damage" % amount)
	
	super.take_damage(amount, from)

	# Emit signal for PartyUI to update
	# TODO: Connect to PartyUI
	_update_party_ui()


## Heal and emit signal for UI update
func heal(amount: int) -> void:
	super.heal(amount)
	_update_party_ui()


func _update_party_ui():
	# Find PartyUI and update companion HP
	for child in get_tree().root.get_node("/root/Main/Game").get_children():
		if child.has_method("update_companion_hp"):
			child.update_companion_hp(current_hp, max_hp)
			return


func _check_ground_at_player() -> bool:
	"""Check if there's ground at/near the player's location"""
	if _player == null:
		return false

	# Get terrain node to check voxels
	var terrain_node = get_node_or_null("/root/Main/Game/VoxelTerrain")
	if not terrain_node:
		return true  # Can't check, assume it's safe

	var vt: VoxelTool = terrain_node.get_voxel_tool()
	vt.channel = VoxelBuffer.CHANNEL_TYPE

	# Check for solid ground within 15 blocks below the player
	var check_pos = _player.global_position + Vector3(2, 0, 2)  # 2 blocks away from player
	var max_check_distance = 15.0

	# Scan downward from player position
	for i in range(int(max_check_distance)):
		var check_block = Vector3i(
			floor(check_pos.x),
			floor(check_pos.y - i),
			floor(check_pos.z)
		)

		var block_id = vt.get_voxel(check_block)

		# Check if this is a solid block (not air/void_fog/water)
		# AIR = 0, VOID_FOG = 55
		if block_id != 0 and block_id != 55:
			# Found ground!
			return true

	# No ground found within search range
	return false


func _teleport_to_player():
	"""Teleport companion to player when too far away"""
	if _player == null:
		return

	# Find a safe position near the player (on the ground)
	var teleport_pos = _player.global_position + Vector3(2, 0, 2)  # 2 blocks away

	# Find ground below that position
	var ground_pos = find_ground_position(teleport_pos + Vector3(0, 5, 0), 15.0)

	# Teleport
	global_position = ground_pos

	# Reset velocity to prevent falling through
	_velocity = Vector3.ZERO
	_grounded = true

	print("%s teleported to player (was too far away)" % entity_name)


## Role-based AI behaviors

func _try_self_heal() -> bool:
	"""Attempt to heal self if HP is below 15%"""
	var hp_percent = float(current_hp) / float(max_hp)

	if hp_percent < 0.15:
		# TODO: Use healing item from inventory when inventory system exists
		# For now, just heal directly
		var heal_amount = int(max_hp * 0.3)  # Heal 30% of max HP
		
		# === TITLE BENEFIT: Paladin - Heal Bonus (+15% healing) ===
		if title_benefit.has("heal_bonus"):
			heal_amount = int(heal_amount * (1.0 + title_benefit.heal_bonus))
			print("🛡️ Paladin's holy healing! (+%d%% healing)" % int(title_benefit.heal_bonus * 100))
		
		heal(heal_amount)
		print("%s used healing! (+%d HP)" % [entity_name, heal_amount])
		return true

	return false


func _try_role_action() -> bool:
	"""Execute role-specific action based on companion role"""
	match CompanionManager.companion_role:
		"tank":
			return _role_tank()
		"wizard":
			return _role_wizard()
		"healer":
			return _role_healer()
		"rogue":
			return _role_rogue()

	return false


func _role_tank() -> bool:
	"""Tank role: High defense, always aggressive, taunts enemies"""
	# Tanks don't have special actions, they just attack
	# Their value is in their high HP and defense stats
	return false  # Let it proceed to normal attack


func _role_wizard() -> bool:
	"""Wizard role: Casts lightning bolt at enemies"""
	if _current_target == null or not _current_target.is_alive:
		return false

	# 50% chance to cast lightning instead of normal attack
	if randf() > 0.5:
		_cast_lightning()
		return true

	return false  # Use normal weapon attack


func _cast_lightning():
	"""Cast lightning bolt at current target"""
	const LightningBolt = preload("res://blocky_game/effects/lightning_bolt.gd")

	var lightning = Node3D.new()
	lightning.set_script(LightningBolt)

	# Initialize BEFORE adding to tree so values are set when _ready() is called
	lightning.target_position = _current_target.global_position
	lightning.damage = 25
	lightning.from_sky = _lightning_from_sky
	lightning.caster_position = global_position

	# Add to game scene (this triggers _ready())
	get_node("/root/Main/Game").add_child(lightning)

	# Alternate for next cast
	_lightning_from_sky = not _lightning_from_sky

	print("%s cast lightning bolt! (from %s)" % [entity_name, "sky" if not _lightning_from_sky else "hand"])


func _role_healer() -> bool:
	"""Healer role: Heals player when they're low on health"""
	if _player == null:
		return false

	# Check if player needs healing (below 50% HP)
	var player_hp_percent = float(_player.current_hp) / float(_player.max_hp)

	if player_hp_percent < 0.5:
		# Heal the player
		var heal_amount = int(_player.max_hp * 0.2)  # Heal 20% of player's max HP
		
		# === TITLE BENEFIT: Paladin - Heal Bonus (+15% healing) ===
		if title_benefit.has("heal_bonus"):
			heal_amount = int(heal_amount * (1.0 + title_benefit.heal_bonus))
			print("🛡️ Paladin blessed healing! (+%d%% healing)" % int(title_benefit.heal_bonus * 100))
		
		_player.current_hp = min(_player.max_hp, _player.current_hp + heal_amount)

		# Emit player HP changed signal
		if _player.has_signal("hp_changed"):
			_player.hp_changed.emit(_player.current_hp, _player.max_hp)

		print("%s healed player! (+%d HP)" % [entity_name, heal_amount])

		# Spawn healing effect
		_spawn_heal_effect(_player.global_position)
		
		# === TITLE BENEFIT: Battle Cleric - Damage on Heal (30% of heal as AoE damage) ===
		if title_benefit.has("damage_on_heal"):
			var aoe_damage = int(heal_amount * title_benefit.damage_on_heal)
			_battle_cleric_aoe_damage(aoe_damage)

		return true

	return false


func _role_rogue() -> bool:
	"""Rogue role: High damage, critical strikes"""
	# Rogues have a chance for critical hit (double damage)
	# This is handled in the normal attack, so no special action needed
	return false  # Let it proceed to normal attack


func _spawn_heal_effect(pos: Vector3):
	"""Create green healing particle effect"""
	var particles = GPUParticles3D.new()
	particles.position = pos + Vector3(0, 1.0, 0)
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 15
	particles.lifetime = 1.0
	particles.explosiveness = 0.8

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.5
	material.direction = Vector3(0, 1, 0)
	material.spread = 30.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 3.0
	material.gravity = Vector3(0, 2.0, 0)  # Float upward
	material.scale_min = 0.1
	material.scale_max = 0.3
	material.color = Color(0.2, 1.0, 0.3)  # Bright green

	particles.process_material = material

	# Add to scene
	get_node("/root/Main/Game").add_child(particles)

	# Auto-delete after lifetime
	await get_tree().create_timer(1.5).timeout
	particles.queue_free()


func _spawn_dodge_effect():
	"""Create white flash particle effect when dodging"""
	var particles = GPUParticles3D.new()
	particles.position = global_position + Vector3(0, 1.0, 0)
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 20
	particles.lifetime = 0.5
	particles.explosiveness = 1.0

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.8
	material.direction = Vector3(0, 0, 0)
	material.spread = 180.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 4.0
	material.gravity = Vector3(0, 0, 0)
	material.scale_min = 0.2
	material.scale_max = 0.5
	material.color = Color(1.0, 1.0, 1.0, 0.8)  # White flash

	particles.process_material = material
	get_node("/root/Main/Game").add_child(particles)

	await get_tree().create_timer(1.0).timeout
	particles.queue_free()


func _battle_cleric_aoe_damage(damage: int):
	"""Battle Cleric: Deal AoE damage when healing (30% of heal amount)"""
	print("⚡ Battle Cleric's holy wrath! %d AoE damage!" % damage)
	
	# Find all enemies within range
	var enemies = get_tree().get_nodes_in_group("enemy_entities")
	var hit_count = 0
	
	for enemy in enemies:
		if not enemy.is_alive:
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		if distance < 5.0:  # 5 block radius
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, self)
				hit_count += 1
	
	if hit_count > 0:
		_spawn_battle_cleric_effect()
		print("  ⚡ Hit %d enemies!" % hit_count)


func _spawn_battle_cleric_effect():
	"""Create yellow/gold radiant burst effect"""
	var particles = GPUParticles3D.new()
	particles.position = global_position + Vector3(0, 1.0, 0)
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 30
	particles.lifetime = 0.8
	particles.explosiveness = 0.9

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 5.0  # Match AoE range
	material.direction = Vector3(0, 1, 0)
	material.spread = 45.0
	material.initial_velocity_min = 3.0
	material.initial_velocity_max = 6.0
	material.gravity = Vector3(0, 1.0, 0)
	material.scale_min = 0.15
	material.scale_max = 0.4
	material.color = Color(1.0, 0.9, 0.3, 0.9)  # Golden radiance

	particles.process_material = material
	get_node("/root/Main/Game").add_child(particles)

	await get_tree().create_timer(1.2).timeout
	particles.queue_free()


func on_enemy_killed(enemy: Node):
	"""Called when companion kills an enemy - used for title benefits"""
	# === TITLE BENEFIT: Reaper - Kill Heal (restore 30% HP on kill) ===
	if title_benefit.has("kill_heal"):
		var heal_amount = int(max_hp * title_benefit.kill_heal)
		heal(heal_amount)
		print("💀 Reaper's life drain! Restored %d HP" % heal_amount)
		_spawn_reaper_effect()


func _spawn_reaper_effect():
	"""Create dark purple/red life drain effect"""
	var particles = GPUParticles3D.new()
	particles.position = global_position + Vector3(0, 1.0, 0)
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 15
	particles.lifetime = 1.0
	particles.explosiveness = 0.7

	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.5
	material.direction = Vector3(0, -1, 0)  # Flow toward companion
	material.spread = 30.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 4.0
	material.gravity = Vector3(0, -5.0, 0)  # Pull toward companion
	material.scale_min = 0.1
	material.scale_max = 0.3
	material.color = Color(0.7, 0.1, 0.3)  # Dark red/purple

	particles.process_material = material
	get_node("/root/Main/Game").add_child(particles)

	await get_tree().create_timer(1.5).timeout
	particles.queue_free()


## ============================================================================
## HUNTING MODE FUNCTIONS
## ============================================================================

func set_hunting(hunting: bool) -> void:
	"""Enable/disable hunting mode"""
	print("Companion: set_hunting called with hunting=%s (currently is_hunting=%s)" % [hunting, is_hunting])
	is_hunting = hunting
	if hunting:
		print("Companion: Entering hunting mode - will wander freely")
		_hunt_wander_timer = 0.0
		_pick_new_wander_target()
		print("Companion: Hunting mode activated. Wander target: %s" % _hunt_wander_target)
	else:
		print("Companion: Exiting hunting mode - returning to normal")
		_hunt_wander_target = Vector3.ZERO


func _handle_hunting(delta: float):
	"""Handle companion behavior while hunting (wandering around)"""
	# Update wander timer
	_hunt_wander_timer -= delta
	
	# Pick a new wander target periodically
	if _hunt_wander_timer <= 0.0:
		_pick_new_wander_target()
		_hunt_wander_timer = HUNT_WANDER_INTERVAL
	
	# Calculate direction toward wander target
	var direction_to_target = (_hunt_wander_target - global_position).normalized()
	direction_to_target.y = 0  # Don't move vertically
	
	# Move toward wander target
	var velocity_input = direction_to_target * movement_speed * MOVE_SPEED_MULTIPLIER
	apply_ground_movement(delta, velocity_input)


func _pick_new_wander_target() -> void:
	"""Pick a new random wander target location"""
	var rng = RandomNumberGenerator.new()
	
	# Get current position as base
	var current_pos = global_position
	
	# Random angle in horizontal plane
	var angle = rng.randf() * TAU
	var distance = rng.randf_range(20.0, HUNT_WANDER_DISTANCE)
	
	# Calculate target position in horizontal plane
	var offset_xz = Vector2(cos(angle), sin(angle)) * distance
	_hunt_wander_target = current_pos + Vector3(offset_xz.x, 0, offset_xz.y)
	
	print("Companion: New wander target at distance %.1f blocks" % distance)


func _update_sprite_direction() -> void:
	"""Update sprite based on whether companion is moving toward or away from player"""
	if not _sprite or not _player:
		return
	
	# Get current velocity (horizontal only)
	var velocity = get_velocity()
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	var speed = horizontal_velocity.length()
	
	# If moving too slow, keep current direction
	if speed < MIN_SPEED_FOR_DIRECTION:
		return
	
	# Get direction from companion to player
	var to_player = (_player.global_position - global_position).normalized()
	to_player.y = 0  # Only consider horizontal direction
	
	# Calculate dot product (positive = moving toward, negative = moving away)
	var dot_product = horizontal_velocity.normalized().dot(to_player)
	
	# Decide if we should show back or front
	var should_show_back = dot_product < 0  # Moving away from player
	
	# Only update if sprite direction changed
	# Check if current state matches desired state
	var is_showing_front = _current_sprite_is_front
	var should_show_front = not should_show_back
	
	if is_showing_front != should_show_front:
		if should_show_back and _back_sprite_path != "":
			# Switch to back sprite
			var back_texture = load(_back_sprite_path)
			if back_texture:
				_sprite.texture = back_texture
				_current_sprite_is_front = false
				# Update shader textures if using stencil shader
				if _sprite.material_override:
					_sprite.material_override.set_shader_parameter("main_texture", back_texture)
					# Also update the silhouette shader texture
					if _sprite.material_override.next_pass:
						_sprite.material_override.next_pass.set_shader_parameter("main_texture", back_texture)
			else:
				push_error("Failed to load back texture: %s" % _back_sprite_path)
		elif should_show_front and _front_sprite_path != "":
			# Switch to front sprite
			var front_texture = load(_front_sprite_path)
			if front_texture:
				_sprite.texture = front_texture
				_current_sprite_is_front = true
				# Update shader textures if using stencil shader
				if _sprite.material_override:
					_sprite.material_override.set_shader_parameter("main_texture", front_texture)
					# Also update the silhouette shader texture
					if _sprite.material_override.next_pass:
						_sprite.material_override.next_pass.set_shader_parameter("main_texture", front_texture)
			else:
				push_error("Failed to load front texture: %s" % _front_sprite_path)


func _update_jumping_state() -> void:
	"""Update sprite based on jumping state and facing direction"""
	if not _sprite or not _player:
		return

	# Check if jumping (not grounded)
	var is_jumping = not _grounded

	# Get direction from companion to player to determine facing
	var to_player = (_player.global_position - global_position).normalized()
	to_player.y = 0

	var velocity = get_velocity()
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)

	# Determine if facing back based on movement
	var is_facing_back = _current_sprite_is_front == false

	# Only update velocity-based direction if moving
	if horizontal_velocity.length() >= MIN_SPEED_FOR_DIRECTION:
		var dot_product = horizontal_velocity.normalized().dot(to_player)
		is_facing_back = dot_product < 0  # Moving away from player

	# If jumping state changed, update sprite
	if is_jumping != _current_sprite_is_jumping:
		_current_sprite_is_jumping = is_jumping

		if is_jumping:
			# Switch to jumping sprite
			var jumping_path = _jumping_back_sprite_path if is_facing_back else _jumping_sprite_path

			if ResourceLoader.exists(jumping_path):
				var jumping_texture = load(jumping_path)
				if jumping_texture:
					_sprite.texture = jumping_texture

					# Update shader textures if using stencil shader
					if _sprite.material_override:
						_sprite.material_override.set_shader_parameter("main_texture", jumping_texture)
						# Also update the silhouette shader texture
						if _sprite.material_override.next_pass:
							_sprite.material_override.next_pass.set_shader_parameter("main_texture", jumping_texture)
		else:
			# Switch back to normal sprite
			var normal_path = _back_sprite_path if is_facing_back else _front_sprite_path

			if ResourceLoader.exists(normal_path):
				var normal_texture = load(normal_path)
				if normal_texture:
					_sprite.texture = normal_texture

					# Update shader textures if using stencil shader
					if _sprite.material_override:
						_sprite.material_override.set_shader_parameter("main_texture", normal_texture)
						# Also update the silhouette shader texture
						if _sprite.material_override.next_pass:
							_sprite.material_override.next_pass.set_shader_parameter("main_texture", normal_texture)


func _update_running_state() -> void:
	"""
	Update sprite based on running state with flip animation
	NOTE: Running sprites currently only available for human_male and elf_female
	TODO: Add running sprites for all races/genders
	"""
	if not _sprite or not _player:
		return

	# Get velocity and speed
	var velocity = get_velocity()
	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	var speed = horizontal_velocity.length()

	# Determine if running (grounded + fast movement)
	var is_running = _grounded and speed >= MIN_SPEED_FOR_RUNNING

	# Get direction from companion to player to determine facing
	var to_player = (_player.global_position - global_position).normalized()
	to_player.y = 0

	# Determine if facing back based on movement
	var is_facing_back = _current_sprite_is_front == false

	# Only update velocity-based direction if moving
	if horizontal_velocity.length() >= MIN_SPEED_FOR_DIRECTION:
		var dot_product = horizontal_velocity.normalized().dot(to_player)
		is_facing_back = dot_product < 0  # Moving away from player

	# Only process running if sprites exist
	var running_path = _running_back_sprite_path if is_facing_back else _running_sprite_path
	var has_running_sprites = ResourceLoader.exists(running_path)

	# Update running state
	if is_running != _current_sprite_is_running and has_running_sprites:
		_current_sprite_is_running = is_running

		if is_running:
			# Switch to running sprite
			if ResourceLoader.exists(running_path):
				var running_texture = load(running_path)
				if running_texture:
					_sprite.texture = running_texture

					# Update shader textures if using stencil shader
					if _sprite.material_override:
						_sprite.material_override.set_shader_parameter("main_texture", running_texture)
						# Also update the silhouette shader texture
						if _sprite.material_override.next_pass:
							_sprite.material_override.next_pass.set_shader_parameter("main_texture", running_texture)

					# Reset flip animation
					_run_flip_distance = 0.0
					_last_position_for_flip = global_position
					_sprite.flip_h = false
		else:
			# Switch back to normal sprite (not jumping)
			var normal_path = _back_sprite_path if is_facing_back else _front_sprite_path

			if ResourceLoader.exists(normal_path):
				var normal_texture = load(normal_path)
				if normal_texture:
					_sprite.texture = normal_texture

					# Update shader textures if using stencil shader
					if _sprite.material_override:
						_sprite.material_override.set_shader_parameter("main_texture", normal_texture)
						# Also update the silhouette shader texture
						if _sprite.material_override.next_pass:
							_sprite.material_override.next_pass.set_shader_parameter("main_texture", normal_texture)

					# Reset flip
					_sprite.flip_h = false

	# Handle flip animation while running
	if _current_sprite_is_running and has_running_sprites:
		# Calculate distance traveled since last flip
		var distance_moved = global_position.distance_to(_last_position_for_flip)
		_run_flip_distance += distance_moved
		_last_position_for_flip = global_position

		# Flip sprite every FLIP_DISTANCE blocks for running animation
		if _run_flip_distance >= FLIP_DISTANCE:
			_sprite.flip_h = !_sprite.flip_h
			_run_flip_distance = 0.0


func _apply_stencil_shader(texture_path: String) -> void:
	"""Apply stencil-based silhouette shader to the companion sprite"""
	if not _sprite:
		push_warning("Companion: Cannot apply stencil shader, sprite not found")
		return

	# Load the stencil material (first pass)
	var stencil_material = load("res://blocky_game/entities/companion_shaders/companion_stencil_material.tres")
	if not stencil_material:
		push_error("Companion: Failed to load stencil material")
		return

	# Load the silhouette material (second pass)
	var silhouette_material = load("res://blocky_game/entities/companion_shaders/companion_silhouette_material.tres")
	if not silhouette_material:
		push_error("Companion: Failed to load silhouette material")
		return

	# Duplicate materials so each companion instance has its own
	stencil_material = stencil_material.duplicate()
	silhouette_material = silhouette_material.duplicate()

	# Set the texture on both shaders
	var texture = load(texture_path)
	if texture:
		stencil_material.set_shader_parameter("main_texture", texture)
		silhouette_material.set_shader_parameter("main_texture", texture)

	# Apply the stencil material to the sprite
	_sprite.material_override = stencil_material

	# Set the silhouette as the Next Pass
	stencil_material.next_pass = silhouette_material

	print("Companion: Applied stencil silhouette shader")


func _try_auto_eat_from_bento() -> void:
	"""Auto-eat from player's bento box when HP is low (25% threshold)"""
	if _recently_ate:
		return

	# Get inventory and item_db references if we don't have them
	if _inventory == null:
		_inventory = _get_inventory()
	if _item_db == null:
		_item_db = get_node_or_null("/root/Main/Game/Items")

	if not _inventory or not _item_db:
		return

	# Check if HP is below threshold (25%)
	var hp_percent = float(current_hp) / float(max_hp)
	if hp_percent <= AUTO_EAT_HP_THRESHOLD:
		# Try to auto-eat weakest food from bento (shares player's bento)
		var food = _inventory.consume_bento_food_smart()
		if food != null:
			# Food healing values for cooked food (matching recipes_database.json)
			const BENTO_FOOD_HEALING = {
				27: 15, 28: 10, 29: 10, 30: 20, 31: 15, 32: 10,
				33: 25, 34: 20, 35: 20, 36: 25, 37: 20, 38: 28, 39: 30
			}

			var heal_amount = BENTO_FOOD_HEALING.get(food.id, 10)

			# Apply healing
			var old_hp = current_hp
			current_hp = min(current_hp + heal_amount, max_hp)
			var actual_heal = current_hp - old_hp

			# Emit healed signal (entity_base signal)
			healed.emit(actual_heal)

			# Get food name
			var item = _item_db.get_item(food.id)
			var food_name = item.base_info.name.replace("_", " ").capitalize()

			# Show message
			print("🍱 %s AUTO-ATE %s from bento! +%d HP (now %d/%d)" % [entity_name, food_name, actual_heal, current_hp, max_hp])

			# Set cooldown to prevent eating entire bento instantly
			_recently_ate = true
			await get_tree().create_timer(2.0).timeout
			_recently_ate = false


func _apply_equip_powers(delta: float) -> void:
	"""Apply passive EQUIP powers from companion's weapon AND accessory"""
	var powers = get_all_equipped_powers()
	
	if powers.is_empty():
		return
	
	# Apply all active EQUIP powers
	for power in powers:
		match power:
			"stone_skin":
				# Defense bonus is handled in take_damage()
				pass

			"moon_jump":
				# Jump boost - companions don't really jump, but could apply to movement
				pass

			"flame_aura":
				# Burn nearby enemies periodically
				_apply_companion_flame_aura(delta)

			"glide":
				# Slow fall effect - cap fall speed
				_apply_glide_fall_cap()
	
	# Defensive mode: Auto-heal when low HP
	if support_mode == "defensive":
		_apply_defensive_heal(delta)


# Timer for flame aura
var _companion_flame_aura_timer := 0.0
# Timer for defensive heal
var _defensive_heal_timer := 0.0
# Flame aura visual effect
var _flame_aura_visual: MeshInstance3D = null

func _apply_defensive_heal(delta: float) -> void:
	"""Defensive mode: Auto-heal when below 50% HP"""
	_defensive_heal_timer += delta
	
	if _defensive_heal_timer >= 3.0:  # Check every 3 seconds
		_defensive_heal_timer = 0.0
		
		if current_hp < max_hp * 0.5:  # Below 50% HP
			var heal_amount = int(max_hp * 0.1)  # Heal 10% of max HP
			current_hp = min(current_hp + heal_amount, max_hp)
			print("💚 %s (Defensive) auto-heals! (+%d HP)" % [entity_name, heal_amount])
			_update_party_ui()

func _apply_companion_flame_aura(delta: float) -> void:
	"""Companion's flame aura - burns nearby enemies"""
	_companion_flame_aura_timer += delta
	
	if _companion_flame_aura_timer >= 1.0:  # Every 1 second
		_companion_flame_aura_timer = 0.0
		
		const FLAME_RADIUS = 4.0
		const FLAME_DAMAGE = 3  # Companions do less flame damage than player
		
		var entities = get_tree().get_nodes_in_group("entities")
		var burned_count = 0
		
		for entity in entities:
			if not is_instance_valid(entity) or not entity.is_alive:
				continue
			
			# Only burn enemies
			if entity.team != Team.ENEMY:
				continue
			
			# Check if within flame aura radius
			var distance = global_position.distance_to(entity.global_position)
			if distance <= FLAME_RADIUS:
				entity.take_damage(FLAME_DAMAGE, self)
				burned_count += 1
		
		if burned_count > 0:
			print("🔥 %s's Flame Aura! Burned %d nearby enemies for %d damage each" % [entity_name, burned_count, FLAME_DAMAGE])


func _apply_glide_fall_cap() -> void:
	"""Cap fall speed when gliding (works with or without Wind Walker Boots)"""
	# Only apply when falling
	if _velocity.y >= 0:
		return

	# Check if player has Wind Walker Boots equipped (companions share player's inventory)
	var player_has_boots = false
	if _player and _player.has_method("_has_wind_walker_boots"):
		player_has_boots = _player._has_wind_walker_boots()

	# Check if companion has glide power equipped in THEIR accessory slot or weapon
	var powers = get_all_equipped_powers()  # Gets powers from companion's weapon AND accessory
	var has_glide_power = "glide" in powers

	# Determine fall speed cap based on synergy
	var fall_speed_cap = -4.0

	if has_glide_power and player_has_boots:
		# Synergy: boots + glide power = slower fall (-3.0)
		fall_speed_cap = -3.0
	elif has_glide_power or player_has_boots:
		# Either boots or power: base fall speed (-4.0)
		fall_speed_cap = -4.0
	else:
		# No glide, no boots - don't cap
		return

	# Apply slow-fall cap ONLY if falling fast enough (not right after jump/being launched)
	# This prevents glide from activating immediately
	if _velocity.y < fall_speed_cap:
		_velocity.y = max(_velocity.y, fall_speed_cap)


## Create flame aura visual effect for companion
func _create_flame_aura_visual() -> void:
	"""Create a glowing orange/fire sphere around the companion"""
	if _flame_aura_visual:
		return  # Already exists
	
	_flame_aura_visual = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 1.5  # 3-block diameter (1.5 radius = 3 blocks wide)
	sphere_mesh.height = 3.0
	sphere_mesh.radial_segments = 24
	sphere_mesh.rings = 16
	_flame_aura_visual.mesh = sphere_mesh
	
	# Create fiery orange material with transparency and emission
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.5, 0.1, 0.01)  # Orange/red, very see-through
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.4, 0.0)  # Bright fire orange
	material.emission_energy_multiplier = 2.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible from inside
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD  # Additive blending for glow effect
	_flame_aura_visual.material_override = material
	
	add_child(_flame_aura_visual)
	
	# Animate pulsing effect
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(_flame_aura_visual, "scale", Vector3(1.1, 1.1, 1.1), 0.8)
	tween.tween_property(_flame_aura_visual, "scale", Vector3(0.9, 0.9, 0.9), 0.8)


## Remove flame aura visual effect
func _remove_flame_aura_visual() -> void:
	"""Remove the flame aura visual when power is unequipped"""
	if _flame_aura_visual:
		_flame_aura_visual.queue_free()
		_flame_aura_visual = null


## Update flame aura visual (check if should be visible)
func _update_flame_aura_visual() -> void:
	"""Show/hide flame aura based on equipped items"""
	# Check equipped powers from weapon and accessory
	var equipped_powers = []
	if _equipped_inv_item and _equipped_inv_item.skyshard_power != "":
		equipped_powers.append(_equipped_inv_item.skyshard_power)
	if _equipped_accessory_item and _equipped_accessory_item.skyshard_power != "":
		equipped_powers.append(_equipped_accessory_item.skyshard_power)
	
	var has_flame_aura = "flame_aura" in equipped_powers
	
	if has_flame_aura and not _flame_aura_visual:
		_create_flame_aura_visual()
	elif not has_flame_aura and _flame_aura_visual:
		_remove_flame_aura_visual()
