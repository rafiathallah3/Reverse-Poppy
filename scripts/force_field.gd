extends StaticBody2D

@export var max_health: int = 5
var health: int = max_health

var pulse_time: float = 0.0
var hit_flash_timer: float = 0.0
var shield_radius: float = 65.0

var my_collision: CollisionShape2D
var shield_light: PointLight2D

func _ready() -> void:
	add_to_group("force_fields")
	
	# ── Collision Shape ──
	my_collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = shield_radius
	my_collision.shape = shape
	add_child(my_collision)
	
	# ── Glowing Light ──
	shield_light = PointLight2D.new()
	shield_light.color = Color(0.0, 0.7, 1.0, 1.0) # Electric cyan
	shield_light.energy = 1.5
	shield_light.texture_scale = 8.0
	
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0, 0, 0, 0)])
	
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.85, 0.85)
	grad_tex.width = 128
	grad_tex.height = 128
	shield_light.texture = grad_tex
	add_child(shield_light)

func _process(delta: float) -> void:
	pulse_time += delta
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
	
	# Pulse light energy slightly
	if shield_light:
		var flash_boost = 2.0 if hit_flash_timer > 0.0 else 0.0
		shield_light.energy = 1.0 + sin(pulse_time * 6.0) * 0.4 + flash_boost
		
	queue_redraw()

func _draw() -> void:
	var flash = hit_flash_timer > 0.0
	var alpha_pulse = 0.25 + sin(pulse_time * 5.0) * 0.1
	
	var base_color = Color(0.0, 0.8, 1.0, alpha_pulse) # Electric cyan
	var edge_color = Color(0.0, 0.9, 1.0, 0.7 + sin(pulse_time * 8.0) * 0.1)
	
	if flash:
		base_color = Color(1.0, 1.0, 1.0, 0.6)
		edge_color = Color(1.0, 1.0, 1.0, 0.95)
		
	# Draw filled circle with low opacity
	draw_circle(Vector2.ZERO, shield_radius, base_color)
	
	# Draw outer glowing ring
	draw_arc(Vector2.ZERO, shield_radius, 0.0, TAU, 32, edge_color, 3.0)
	draw_arc(Vector2.ZERO, shield_radius - 2.0, 0.0, TAU, 32, edge_color * 0.5, 1.0)
	
	# Draw internal glowing hexagonal lines/grid structure for high-tech effect
	var hex_color = edge_color * 0.4
	hex_color.a = alpha_pulse * 0.7
	_draw_shield_hex_pattern(hex_color)

func _draw_shield_hex_pattern(color: Color) -> void:
	# Draw simple geometric grid lines to simulate hex shield
	var segments = 6
	for i in range(segments):
		var angle1 = i * TAU / segments + pulse_time * 0.2
		var angle2 = (i + 1) * TAU / segments + pulse_time * 0.2
		
		var p1 = Vector2(cos(angle1), sin(angle1)) * (shield_radius * 0.7)
		var p2 = Vector2(cos(angle2), sin(angle2)) * (shield_radius * 0.7)
		draw_line(p1, p2, color, 1.5)
		draw_line(Vector2.ZERO, p1, color, 1.0)

func take_damage(amount: int) -> void:
	if health <= 0:
		return
		
	health -= amount
	hit_flash_timer = 0.2
	
	_spawn_spark_particles()
	
	if health <= 0:
		health = 0
		_shatter()

func _spawn_spark_particles() -> void:
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = global_position
	
	var particles = CPUParticles2D.new()
	particles.amount = 10
	particles.lifetime = 0.4
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 140.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(0.0, 0.9, 1.0, 1.0) # Cyan sparks
	effect.add_child(particles)
	particles.emitting = true
	
	var tween = effect.create_tween()
	tween.tween_interval(0.4)
	tween.tween_callback(effect.queue_free)

func _shatter() -> void:
	# Disable collision immediately
	if my_collision:
		my_collision.set_deferred("disabled", true)
		
	# Spawn shatter particles
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = global_position
	
	var particles = CPUParticles2D.new()
	particles.amount = 25
	particles.lifetime = 0.6
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2(0, 150) # Fall down when shattered
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 220.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color(0.0, 0.8, 1.0, 0.9)
	effect.add_child(particles)
	particles.emitting = true
	
	# Flash light out
	if shield_light:
		var flash_tween = create_tween()
		flash_tween.tween_property(shield_light, "energy", 0.0, 0.4)
		flash_tween.parallel().tween_property(shield_light, "texture_scale", 12.0, 0.4)
	
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	fade_tween.tween_callback(queue_free)
	
	var cleanup_tween = effect.create_tween()
	cleanup_tween.tween_interval(0.6)
	cleanup_tween.tween_callback(effect.queue_free)
