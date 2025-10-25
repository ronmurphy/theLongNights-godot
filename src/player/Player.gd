extends CharacterBody3D
## Player - Main player character controller
## Handles movement, inventory, health, and interaction

class_name Player

# Movement
@export var move_speed: float = 5.0
@export var jump_force: float = 7.0
@export var gravity: float = 9.8
@export var fly_speed: float = 15.0

# Mouse look
@export var mouse_sensitivity: float = 0.003
var mouse_motion: Vector2 = Vector2.ZERO

# Fly mode
var is_flying: bool = false

# Health
@export var max_health: int = 100
var current_health: int = 100
var is_alive: bool = true

# Inventory and crafting
var inventory: Dictionary = {}  # item_name: count
var hotbar_size: int = 9

# References
var camera: Camera3D = null  # Set by Main.gd

func _ready() -> void:
	print("Player initialized")
	current_health = max_health

	# Capture mouse for first-person controls
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	# Handle mouse movement for camera look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_motion = event.relative

func _process(delta: float) -> void:
	if not is_alive:
		return

	# Apply mouse look
	if camera and mouse_motion.length() > 0:
		# Rotate player horizontally (yaw)
		rotate_y(-mouse_motion.x * mouse_sensitivity)

		# Rotate camera vertically (pitch)
		camera.rotate_x(-mouse_motion.y * mouse_sensitivity)

		# Clamp camera pitch to prevent over-rotation
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

		mouse_motion = Vector2.ZERO

	# Handle movement input
	_handle_movement(delta)

	# Handle other inputs
	_handle_input()

	# ESC to release mouse
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _handle_movement(delta: float) -> void:
	# Get input direction (WASD / Arrow keys)
	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		input_dir.x += 1

	# Convert to 3D direction relative to player rotation
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if is_flying:
		# Fly mode - free movement in all directions
		var fly_direction = direction

		# Add vertical movement (Space/Shift)
		if Input.is_action_pressed("ui_accept"):  # Space = up
			fly_direction.y += 1
		if Input.is_key_pressed(KEY_SHIFT):  # Shift = down
			fly_direction.y -= 1

		fly_direction = fly_direction.normalized()
		velocity = fly_direction * fly_speed
	else:
		# Normal mode with gravity
		if direction:
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed)
			velocity.z = move_toward(velocity.z, 0, move_speed)

		# Apply gravity
		velocity.y -= gravity * delta

		# Jump
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = jump_force

	move_and_slide()

func _handle_input() -> void:
	# Toggle fly mode with Tab key
	if Input.is_key_pressed(KEY_TAB):
		is_flying = !is_flying
		if is_flying:
			print("Fly mode ENABLED (Space=up, Shift=down)")
		else:
			print("Fly mode DISABLED")

## Take damage
func take_damage(amount: int) -> void:
	current_health -= amount
	print("Player damaged! Health: %d/%d" % [current_health, max_health])

	if current_health <= 0:
		die()

## Die
func die() -> void:
	is_alive = false
	print("Player died!")
	GameManager.instance.on_player_died()

## Add item to inventory
func add_item(item_name: String, count: int = 1) -> void:
	if item_name not in inventory:
		inventory[item_name] = 0
	inventory[item_name] += count
	print("Added %d x %s" % [count, item_name])

## Get item count
func get_item_count(item_name: String) -> int:
	return inventory.get(item_name, 0)
