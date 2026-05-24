extends Area2D

@export var speed: float = 4000.0
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT

# Time Rewind variables
var is_paused: bool = false
var history: Array = []
var max_history_duration: float = 5.0 # Max history duration to match slider (5 sec)
var current_recording_time: float = 0.0

var laser_rect: ColorRect
var laser_core: ColorRect

func _ready() -> void:
	# Add to groups
	add_to_group("bullets")
	add_to_group("rewindable_objects")
	
	# Create a visual representation: a modern, glowing neon red laser beam
	laser_rect = ColorRect.new()
	laser_rect.color = Color(2.5, 0.1, 0.25, 1.0) # Blindingly bright glowing HDR neon red
	laser_rect.size = Vector2(100, 6) # Extremely long and sleek for high velocity
	laser_rect.position = - laser_rect.size / 2.0 # Center the rect at bullet's position
	add_child(laser_rect)
	
	# Add a subtle inner bright core to make it look extremely premium
	laser_core = ColorRect.new()
	laser_core.color = Color(2.5, 2.5, 2.5, 1.0) # Pure white glowing core
	laser_core.size = Vector2(94, 2) # Extra long matching inner core
	laser_core.position = - laser_core.size / 2.0
	add_child(laser_core)
	
	# Create a tiny point light to make the laser beam glow in the dark
	var light = PointLight2D.new()
	light.name = "PointLight2D"
	light.color = Color(1.0, 0.15, 0.25, 1.0) # Vibrant neon red glow
	light.energy = 3.5 # Intense energy for blinding brightness
	light.texture_scale = 5.0 # Large glow aura # Compact glow surrounding the laser
	
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(0.0, 0.0, 0.0, 0.0)])
	
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.85, 0.85)
	grad_tex.width = 64
	grad_tex.height = 64
	
	light.texture = grad_tex
	add_child(light)
	
	# Create a physics collision shape matching the laser dimensions
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = laser_rect.size
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Connect the body entered signal for collision detection
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	var st = get_node_or_null("/root/SceneTransition")
	if is_paused or (st and st.is_reversing):
		set_physics_process(false)
		return
		
	# Move the bullet forward
	position += direction * speed * delta
	
	# Record position and lifetime history
	current_recording_time += delta
	history.append({
		"time": current_recording_time,
		"pos": position,
		"lifetime": lifetime
	})
	
	# Limit history length
	while history.size() > 0 and (current_recording_time - history[0]["time"]) > max_history_duration:
		history.remove_at(0)
		
	# Countdown lifetime and remove if expired
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	# Ignore collisions with the Player or other bullets
	if body.name.contains("Player") or body.is_in_group("bullets"):
		return
		
	# Spawn a beautiful premium impact burst
	_spawn_impact_effect()
	
	# If the hit body has a method for taking damage, we can call it (future scalability)
	if body.has_method("take_damage"):
		body.take_damage(1)
		
	# Destroy the bullet
	queue_free()

func _spawn_impact_effect() -> void:
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = global_position
	
	# 1. Create an expanding shockwave ring
	var line = Line2D.new()
	line.points = _get_circle_points(12.0)
	line.width = 4.0
	line.default_color = Color(1.0, 0.0, 0.1, 0.9) # Neon red glowing impact
	effect.add_child(line)
	
	# 2. Add an inner expanding ring
	var inner_line = Line2D.new()
	inner_line.points = _get_circle_points(7.0)
	inner_line.width = 2.0
	inner_line.default_color = Color(1.0, 0.9, 0.9, 1.0) # Bright core impact
	effect.add_child(inner_line)
	
	# 3. Tiny glowing point light flash!
	var light = PointLight2D.new()
	light.name = "ImpactLight"
	light.color = Color(1.0, 0.2, 0.3, 1.0) # Neon red glow
	light.energy = 2.5 # Bright initial spark
	light.texture_scale = 1.0 # Will scale up slightly
	
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(0.0, 0.0, 0.0, 0.0)])
	
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.85, 0.85)
	grad_tex.width = 32
	grad_tex.height = 32
	
	light.texture = grad_tex
	effect.add_child(light)
	
	# 4. Spunky sparks particle burst!
	var particles = CPUParticles2D.new()
	particles.amount = 8
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2(0, 80) # Slight falling weight
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 120.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1.0, 0.4, 0.2, 1.0) # Bright neon orange sparks
	effect.add_child(particles)
	particles.emitting = true
	
	# Animate the shockwave, particle timing, and light flash using a smooth Tween
	var tween = effect.create_tween()
	tween.tween_property(line, "scale", Vector2(1.8, 1.8), 0.15)
	tween.parallel().tween_property(line, "default_color:a", 0.0, 0.15)
	tween.parallel().tween_property(inner_line, "scale", Vector2(2.2, 2.2), 0.15)
	tween.parallel().tween_property(inner_line, "default_color:a", 0.0, 0.15)
	tween.parallel().tween_property(light, "texture_scale", 4.0, 0.15).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(light, "energy", 0.0, 0.15)
	tween.tween_callback(effect.queue_free)

func _get_circle_points(radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	var steps = 12
	for i in range(steps + 1):
		var angle = i * TAU / steps
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func set_paused(paused: bool) -> void:
	is_paused = paused
	set_physics_process(not paused)
	if laser_rect:
		if paused:
			laser_rect.color = Color(0.0, 0.8, 1.0, 1.0) # Tint neon cyan when paused/rewinding
			if has_node("PointLight2D"):
				$PointLight2D.color = Color(0.0, 0.8, 1.0, 1.0) # Tint light cyan
		else:
			laser_rect.color = Color(1.0, 0.0, 0.1, 1.0) # Restore neon red
			if has_node("PointLight2D"):
				$PointLight2D.color = Color(1.0, 0.1, 0.2, 1.0) # Restore light red

func scrub_time(offset_ms: float) -> void:
	if history.size() == 0:
		return
		
	var target_time = current_recording_time - (offset_ms / 1000.0)
	
	var closest_entry = history[0]
	var min_diff = abs(closest_entry["time"] - target_time)
	
	for entry in history:
		var diff = abs(entry["time"] - target_time)
		if diff < min_diff:
			min_diff = diff
			closest_entry = entry
			
	position = closest_entry["pos"]
	lifetime = closest_entry["lifetime"]

func commit_scrubbed_state(offset_ms: float) -> void:
	if history.size() == 0:
		return
		
	var target_time = current_recording_time - (offset_ms / 1000.0)
	
	var new_history = []
	for entry in history:
		if entry["time"] <= target_time:
			new_history.append(entry)
			
	history = new_history
	if history.size() > 0:
		current_recording_time = history[history.size() - 1]["time"]
	else:
		current_recording_time = 0.0
