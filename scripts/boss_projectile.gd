extends Area2D

@export var speed: float = 320.0
@export var is_tracking: bool = false
@export var tracking_strength: float = 1.8
@export var max_lifetime: float = 5.0

var velocity: Vector2 = Vector2.ZERO
var player: CharacterBody2D = null
var lifetime: float = 0.0
var pulse_time: float = 0.0

var my_collision: CollisionShape2D
var proj_light: PointLight2D

func _ready() -> void:
	add_to_group("boss_projectiles")
	
	# Find player
	var current_scene = get_tree().current_scene
	if current_scene:
		player = current_scene.get_node_or_null("Player")
		if not player:
			player = current_scene.get_node_or_null("Player (Testing)")

	# Set lifetime
	if is_tracking:
		max_lifetime = 10.0 # as requested
		
	# Collision Shape
	my_collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8.0
	my_collision.shape = shape
	add_child(my_collision)

	# Light setup for awareness
	proj_light = PointLight2D.new()
	if is_tracking:
		proj_light.color = Color(0.8, 0.1, 1.0, 1.0) # Violet/Magenta tracking light
		proj_light.energy = 2.0
	else:
		proj_light.color = Color(1.0, 0.2, 0.1, 1.0) # Red standard light
		proj_light.energy = 1.5
	proj_light.texture_scale = 4.0
	
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0, 0, 0, 0)])
	
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.85, 0.85)
	grad_tex.width = 64
	grad_tex.height = 64
	proj_light.texture = grad_tex
	add_child(proj_light)

	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()

func _physics_process(delta: float) -> void:
	# Check if paused by the time rewind/scene transition system
	var st = get_node_or_null("/root/SceneTransition")
	if st and st.is_reversing:
		queue_free()
		return

	# Handle tracking
	if is_tracking and is_instance_valid(player) and not player.is_dying:
		var target_dir = (player.global_position - global_position).normalized()
		var current_dir = velocity.normalized()
		var new_dir = current_dir.lerp(target_dir, delta * tracking_strength).normalized()
		velocity = new_dir * speed
		
		# Rotate towards direction of travel
		rotation = velocity.angle()
	
	position += velocity * delta
	
	# Rotate for visual polish
	if not is_tracking:
		rotation += 5.0 * delta
		
	# Handle light pulse
	if proj_light:
		proj_light.energy = (2.0 if is_tracking else 1.5) + sin(pulse_time * 12.0) * 0.4

	lifetime += delta
	if lifetime >= max_lifetime:
		_explode_and_free()

func _draw() -> void:
	if is_tracking:
		# Pulsing magenta tracking orb
		var r = 8.0 + sin(pulse_time * 10.0) * 2.0
		# Outer plasma
		draw_circle(Vector2.ZERO, r, Color(0.7, 0.1, 0.9, 0.4))
		# Inner core
		draw_circle(Vector2.ZERO, 5.0, Color(0.9, 0.5, 1.0, 0.9))
		# Spike visual pointing forward
		var points = PackedVector2Array([
			Vector2(12.0, 0.0),
			Vector2(-4.0, -5.0),
			Vector2(-4.0, 5.0)
		])
		draw_colored_polygon(points, Color(0.8, 0.2, 1.0, 0.8))
	else:
		# Standard spinning red/orange fireball
		draw_circle(Vector2.ZERO, 7.0, Color(0.9, 0.2, 0.1, 0.5))
		draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.7, 0.1, 0.9))
		
		# Small orbital sparks
		var angle = pulse_time * 8.0
		draw_circle(Vector2(cos(angle), sin(angle)) * 6.0, 1.5, Color(1.0, 0.8, 0.2))
		draw_circle(Vector2(cos(angle + PI), sin(angle + PI)) * 6.0, 1.5, Color(1.0, 0.8, 0.2))

func _on_body_entered(body: Node2D) -> void:
	# Ignore self (Boss), force fields, and other boss projectiles
	if body.name == "Boss" or body.is_in_group("boss") or body.is_in_group("force_fields") or body.is_in_group("boss_projectiles"):
		return
		
	if body.name.contains("Player"):
		if body.has_method("die"):
			body.die()
		_explode_and_free()
		return
		
	# Bounces or explodes on floors/walls
	if body is TileMapLayer or body is StaticBody2D or body.name.contains("Bounds") or body.name.contains("Platform"):
		_explode_and_free()

func _explode_and_free() -> void:
	# Create impact visual effect container
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = global_position
	
	# ── 1. Visual Shockwave Ring ──
	var ring = Line2D.new()
	ring.points = _get_circle_points(10.0)
	ring.width = 3.0
	ring.default_color = Color(0.9, 0.15, 1.0, 0.95) if is_tracking else Color(1.0, 0.45, 0.1, 0.95)
	effect.add_child(ring)
	
	# ── 2. CPUParticles2D Spark Burst ──
	var particles = CPUParticles2D.new()
	particles.amount = 18
	particles.lifetime = 0.45
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.gravity = Vector2(0, 100) # Gravity pulling particles down slightly
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 160.0
	particles.scale_amount_min = 2.5
	particles.scale_amount_max = 5.5
	particles.color = Color(0.8, 0.2, 0.9, 1.0) if is_tracking else Color(1.0, 0.35, 0.1, 1.0)
	effect.add_child(particles)
	particles.emitting = true
	
	# ── 3. PointLight2D Impact Flash ──
	var light = PointLight2D.new()
	light.color = Color(0.8, 0.1, 1.0, 1.0) if is_tracking else Color(1.0, 0.3, 0.1, 1.0)
	light.energy = 3.0
	light.texture_scale = 1.0
	
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0, 0, 0, 0)])
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.85, 0.85)
	grad_tex.width = 64
	grad_tex.height = 64
	light.texture = grad_tex
	effect.add_child(light)
	
	# ── 4. Tween Animation ──
	var tween = effect.create_tween()
	tween.tween_property(ring, "scale", Vector2(2.5, 2.5), 0.25)
	tween.parallel().tween_property(ring, "default_color:a", 0.0, 0.25)
	tween.parallel().tween_property(light, "texture_scale", 6.0, 0.28).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(light, "energy", 0.0, 0.28)
	tween.tween_interval(0.2)
	tween.tween_callback(effect.queue_free)
	
	queue_free()

func _get_circle_points(radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	var steps = 12
	for i in range(steps + 1):
		var angle = i * TAU / steps
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
