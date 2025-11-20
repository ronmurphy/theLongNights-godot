class_name SlashEffectSpawner
extends Node

## Reusable helper for spawning spatial slash effects
##
## Supports two effect types:
## - SIMPLE_GLOW: Tutorial 2 - Simple glowing slash with procedural noise
## - FIRE_SLASH: Tutorial 1 - Complex fire-like slash with textures and gradients
##
## Toggle between effects using the Z key, or call toggle_effect_type() from code.

enum EffectType {
	SIMPLE_GLOW,  ## Tutorial 2 - Simple procedural glow effect
	FIRE_SLASH    ## Tutorial 1 - Fire slash with textures and gradients
}

## Current active effect type (can be toggled with Z key)
static var current_effect_type: EffectType = EffectType.FIRE_SLASH

const SIMPLE_GLOW_SCENE = preload("res://blocky_game/items/spatial_slash_effect.tscn")
const FIRE_SLASH_SCENE = preload("res://blocky_game/items/slash_effect_fire.tscn")

## Toggle between effect types and print the change to console
static func toggle_effect_type() -> void:
	if current_effect_type == EffectType.SIMPLE_GLOW:
		current_effect_type = EffectType.FIRE_SLASH
		print("🔥 Switched to FIRE SLASH effect (Tutorial 1)")
	else:
		current_effect_type = EffectType.SIMPLE_GLOW
		print("✨ Switched to SIMPLE GLOW effect (Tutorial 2)")

## Get the name of the current effect type
static func get_current_effect_name() -> String:
	match current_effect_type:
		EffectType.SIMPLE_GLOW:
			return "Simple Glow (Tutorial 2)"
		EffectType.FIRE_SLASH:
			return "Fire Slash (Tutorial 1)"
		_:
			return "Unknown"

## Spawn a spatial slash effect at the given position and orientation
##
## Parameters:
##   parent: The node to add the effect to (usually /root/Main/Game or similar)
##   position: World position for the effect
##   direction: Forward direction the slash should face
##   color: RGBA color tint for the effect
##   duration: How long the effect lasts before auto-cleanup (seconds)
##   intensity: Brightness/emission multiplier (default: 7.0)
##   speed: Animation speed multiplier (default: 0.2)
##   scale: Size multiplier for the effect (default: 1.0)
##
## Returns: The spawned effect node (in case you need to modify it further)
static func spawn_slash(
	parent: Node,
	position: Vector3,
	direction: Vector3,
	color: Color = Color.WHITE,
	duration: float = 0.3,
	intensity: float = 7.0,
	speed: float = 0.2,
	scale: float = 1.0
) -> Node3D:
	# Choose the scene based on current effect type
	var effect_scene = FIRE_SLASH_SCENE if current_effect_type == EffectType.FIRE_SLASH else SIMPLE_GLOW_SCENE

	# Instantiate the effect
	var effect: Node3D = effect_scene.instantiate()
	parent.add_child(effect)

	# Position the effect
	effect.global_position = position

	# Orient the effect to face the attack direction
	# The mesh has a pre-rotation in the scene, so use look_at and additional rotation
	var forward = direction.normalized()

	# Make the slash face the direction of attack
	effect.look_at(position + forward, Vector3.UP)

	# The mesh is rotated in the scene file - rotate around X axis instead to fix orientation
	# Rotate 180 degrees around X to flip it vertically (fixes up/down inversion)
	effect.rotate_object_local(Vector3(1, 0, 0), deg_to_rad(180))

	# Apply scale
	effect.scale = Vector3(scale, scale, scale)

	# Get the material and duplicate it (so each effect has its own parameters)
	var mesh_instance = effect.get_node("MeshInstance3D")
	var material: ShaderMaterial = mesh_instance.get_active_material(0).duplicate()
	mesh_instance.set_surface_override_material(0, material)

	# Set shader parameters based on effect type
	if current_effect_type == EffectType.SIMPLE_GLOW:
		_configure_simple_glow(material, color, intensity, speed)
	else:
		_configure_fire_slash(material, color, intensity, speed, duration)
		# Add animator script to fire slash for speed parameter animation
		_add_fire_slash_animator(effect, speed)

	# Auto-cleanup after duration
	_cleanup_after_delay(effect, duration)

	return effect


## Configure shader parameters for Simple Glow effect (Tutorial 2)
static func _configure_simple_glow(material: ShaderMaterial, color: Color, intensity: float, speed: float) -> void:
	material.set_shader_parameter("color", color)
	material.set_shader_parameter("intensity", intensity)
	material.set_shader_parameter("speed", speed)


## Configure shader parameters for Fire Slash effect (Tutorial 1)
static func _configure_fire_slash(material: ShaderMaterial, color: Color, intensity: float, speed: float, duration: float) -> void:
	# Extract RGB for gradient colors (use the provided color as the bright color)
	var bright_color = color.to_html(false)
	var mid_color_vec = color * 0.6  # Darker mid tone
	var dark_color_vec = Color.BLACK

	# Convert color to gradient (bright → mid → dark)
	material.set_shader_parameter("Bright_Color", color)
	material.set_shader_parameter("Mid_Color", mid_color_vec)
	material.set_shader_parameter("Dark_Color", dark_color_vec)

	# Set intensity and animation parameters
	material.set_shader_parameter("intensity", intensity)
	material.set_shader_parameter("speed", 0.0)  # Start at 0, will be animated by script
	material.set_shader_parameter("duration", duration)

	# Flicker effect for fire
	material.set_shader_parameter("flicker_speed", 10.0)
	material.set_shader_parameter("flicker_strength", 0.3)

	# Fade in/out
	material.set_shader_parameter("fade_start", 0.1)
	material.set_shader_parameter("fade_end", 0.9)

	# Noise and dissolve
	material.set_shader_parameter("noise_flow", 1.0)
	material.set_shader_parameter("noise_strength", 0.1)
	material.set_shader_parameter("Dissovle", 1.0)

	# Gradient sharpness
	material.set_shader_parameter("Gradient_Sharpness", 1.5)

	# Offset for animation - increase to sweep more across the screen
	material.set_shader_parameter("offset", Vector2(2, 0))


## Add animator script to fire slash effect for speed parameter animation
static func _add_fire_slash_animator(effect: Node3D, animation_speed: float) -> void:
	var animator_script = load("res://blocky_game/items/slash_effect_animator.gd")
	var animator = animator_script.new()
	animator.animation_speed = animation_speed
	effect.add_child(animator)


## Internal helper to clean up the effect after a delay
static func _cleanup_after_delay(effect: Node3D, delay: float) -> void:
	# We need a valid node to await on, so we use the effect's tree
	await effect.get_tree().create_timer(delay).timeout
	if is_instance_valid(effect):
		effect.queue_free()
