extends StaticBody2D

func _ready() -> void:
	add_to_group("destructible")

func take_explosion_damage() -> void:
	_spawn_break_effect()
	queue_free()

func _spawn_break_effect() -> void:
	var particles = CPUParticles2D.new()
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.amount = 12
	particles.explosiveness = 1.0
	particles.one_shot = true        
	particles.spread = 180.0
	particles.gravity = Vector2(0, 200)
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 160.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color(0.8, 0.5, 0.2, 1.0)
	particles.emitting = true
	await get_tree().create_timer(1.5).timeout
	particles.queue_free()
