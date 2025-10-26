extends Node3D

@onready var _particles = $Particles
@onready var _animation_player = $AnimationPlayer


func _ready():
	# Set particle count based on graphics settings
	_particles.amount = GraphicsSettings.get_particle_count()
	_particles.emitting = true
	_animation_player.play("explode")


func _on_Timer_timeout():
	queue_free()
