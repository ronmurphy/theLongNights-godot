extends Node
## Powers.gd - Centralized Skyshard Power System
## Handles all HOTBAR power effects (triggered on attack/hit)
## 
## EQUIP powers (passive buffs) are handled in character_controller.gd:
##   - stone_skin: Defense multiplier (character_controller.gd ~line 364)
##   - moon_jump: Jump multiplier (character_controller.gd ~line 186)
##   - flame_aura: Burn nearby enemies (character_controller.gd ~line 403)
##
## Autoload singleton for easy access from any weapon/projectile

const Meteor = preload("res://blocky_game/projectiles/meteor.gd")
const EntityBase = preload("res://blocky_game/entities/entity_base.gd")


## Execute a HOTBAR power (triggered on attack/hit)
## Context should contain: entity, position, stack_count, damage_dealt, attacker
func execute_hotbar_power(power_name: String, context: Dictionary) -> void:
	match power_name:
		"meteor_strike":
			_power_meteor_strike(context)
		"lightning_chain":
			_power_lightning_chain(context)
		"life_steal":
			_power_life_steal(context)
		"ice_burst":
			_power_ice_burst(context)
		"poison_cloud":
			_power_poison_cloud(context)
		"knife_volley":
			_power_knife_volley(context)
		"wind_dash":
			_power_wind_dash(context)
		_:
			print("WARNING: Unknown HOTBAR power: ", power_name)


## Get EQUIP power buffs (passive effects)
## Returns dictionary with multipliers/bonuses
## NOTE: EQUIP powers are actually implemented in character_controller.gd
## This function is provided for reference/documentation only
func get_equip_buffs(power_name: String) -> Dictionary:
	match power_name:
		"stone_skin":
			return {"defense_mult": 1.5, "name": "Stone Skin", "location": "character_controller.gd ~line 364"}
		"moon_jump":
			return {"jump_mult": 3.0, "name": "Moon Jump", "location": "character_controller.gd ~line 186"}
		"flame_aura":
			return {"has_flame_aura": true, "name": "Flame Aura", "location": "character_controller.gd ~line 403"}
		_:
			return {}


## ============================================================================
## HOTBAR POWER IMPLEMENTATIONS
## ============================================================================

func _power_meteor_strike(ctx: Dictionary) -> void:
	"""Summons a meteor from the sky to strike target position"""
	if not ctx.has("position"):
		print("ERROR: meteor_strike missing 'position' in context")
		return
	
	var target_pos: Vector3 = ctx.position
	var sky_pos = Vector3(target_pos.x, target_pos.y + 50.0, target_pos.z)
	var stack_count = ctx.get("stack_count", 1)
	
	# Get game node to add meteor to scene
	var game_node = get_node_or_null("/root/Main/Game")
	if not game_node:
		print("ERROR: Could not find /root/Main/Game node for meteor!")
		return
	
	# Spawn meteor
	var meteor = Node3D.new()
	meteor.set_script(Meteor)
	game_node.add_child(meteor)
	
	if meteor.has_method("initialize"):
		meteor.initialize(sky_pos, target_pos, stack_count)
		print("☄️ Meteor Strike! Meteor spawned at sky: %s → target: %s" % [sky_pos, target_pos])
	else:
		print("ERROR: Meteor has no initialize method!")


func _power_lightning_chain(ctx: Dictionary) -> void:
	"""Chains lightning damage to nearby enemies"""
	if not ctx.has("position") or not ctx.has("entity"):
		print("ERROR: lightning_chain missing required context")
		return
	
	var origin: Vector3 = ctx.position
	var primary_target: Node = ctx.entity
	var chain_damage = ctx.get("damage_dealt", 20)
	var stack_count = ctx.get("stack_count", 1)
	
	const CHAIN_RADIUS = 5.0
	const MAX_CHAINS = 3
	
	print("⚡ Lightning Chain - origin:", origin, " damage:", chain_damage, " primary:", primary_target.entity_name)
	
	var entities = get_tree().get_nodes_in_group("entities")
	print("DEBUG: Found", entities.size(), "entities in scene")
	
	var chained_count = 0
	for entity in entities:
		if chained_count >= MAX_CHAINS:
			break
		
		if not is_instance_valid(entity) or not entity.is_alive:
			continue
		
		# Skip the primary target
		if entity == primary_target:
			continue
		
		# Only chain to enemies
		if entity.team != EntityBase.Team.ENEMY:
			continue
		
		# Check distance
		var distance = origin.distance_to(entity.global_position)
		if distance <= CHAIN_RADIUS:
			# Chain lightning to this enemy
			var attacker = ctx.get("attacker", null)
			entity.take_damage(chain_damage + stack_count, attacker)
			print("⚡ Lightning chained to %s for %d damage (distance: %.1f)!" % [entity.entity_name, chain_damage + stack_count, distance])
			chained_count += 1


func _power_life_steal(ctx: Dictionary) -> void:
	"""Heals attacker for 25% of damage dealt"""
	if not ctx.has("damage_dealt"):
		print("ERROR: life_steal missing 'damage_dealt' in context")
		return
	
	var heal_amount = int(ctx.damage_dealt * 0.25)
	
	# Try to get player from attacker context
	var player = ctx.get("attacker", null)
	if not player:
		player = get_tree().get_first_node_in_group("player")
	
	if player and player.has_method("heal"):
		player.heal(heal_amount)
		print("💚 Life Steal! Healed %d HP" % heal_amount)
	else:
		print("WARNING: Could not find player to heal for life_steal")


func _power_ice_burst(ctx: Dictionary) -> void:
	"""Freezes enemies in radius - TODO: Implement"""
	print("❄️ Ice Burst! (Not yet implemented)")


func _power_poison_cloud(ctx: Dictionary) -> void:
	"""Leaves poison AoE on impact - TODO: Implement"""
	print("☠️ Poison Cloud! (Not yet implemented)")


func _power_knife_volley(ctx: Dictionary) -> void:
	"""Launches 3 knives on attack - TODO: Implement"""
	print("🔪 Knife Volley! (Not yet implemented)")


func _power_wind_dash(ctx: Dictionary) -> void:
	"""Speed boost for 3s after hit - TODO: Implement"""
	print("💨 Wind Dash! (Not yet implemented)")
