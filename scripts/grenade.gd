extends Area2D

@export var speed_x: float = 450.0
@export var speed_y: float = -420.0
@export var grenade_gravity: float = 1100.0
@export var bounce_damping: float = 0.5
@export var friction_damping: float = 0.8
@export var fuse_time: float = 1.5
@export var explosion_radius: float = 110.0

var velocity: Vector2 = Vector2.ZERO
var time_remaining: float = fuse_time
var my_collision_shape: CollisionShape2D
var shapecast: ShapeCast2D


# Time Rewind variables
var is_paused: bool = false
var history: Array = []
var max_history_duration: float = 5.0 # Match the 5 sec history slider
var current_recording_time: float = 0.0

# Visual animation state
var led_on: bool = false
var led_timer: float = 0.0
var is_exploded: bool = false
var explosion_real_time: float = -1.0 # The recording time when it exploded

func _ready() -> void:
	# Add to groups for collision and time reversal
	add_to_group("grenades")
	add_to_group("rewindable_objects")
	
	# Set up a circle collision shape for the grenade physical size
	my_collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10.0
	my_collision_shape.shape = shape
	add_child(my_collision_shape)

	
	# Connect collision signals
	body_entered.connect(_on_body_entered)
	
	# Set up shapecast for wall/floor collision normal detection
	shapecast = ShapeCast2D.new()
	var cast_shape = CircleShape2D.new()
	cast_shape.radius = 8.0 # Slightly smaller to prevent ghost collisions
	shapecast.shape = cast_shape
	shapecast.exclude_parent = true
	add_child(shapecast)

func _draw() -> void:
	if is_exploded:
		return
		
	# Draw olive green body
	draw_circle(Vector2.ZERO, 10.0, Color(0.2, 0.35, 0.15, 1.0))
	draw_circle(Vector2.ZERO, 8.0, Color(0.28, 0.45, 0.22, 1.0)) # Inside highlight
	
	# Draw bronze cap
	draw_rect(Rect2(-4, -13, 8, 4), Color(0.65, 0.55, 0.2, 1.0))
	
	# Draw small metallic pin ring
	draw_arc(Vector2(-6, -11), 3.0, 0.0, TAU, 8, Color(0.5, 0.5, 0.5, 1.0), 1.5)
	
	# Draw blinking LED
	var led_color = Color(1.0, 0.1, 0.1, 1.0) if led_on else Color(0.1, 0.0, 0.0, 1.0)
	draw_circle(Vector2(0, -2), 2.5, led_color)

func _physics_process(delta: float) -> void:
	var st = get_node_or_null("/root/SceneTransition")
	if is_paused or (st and st.is_reversing):
		set_physics_process(false)
		return
		
	# If already exploded, we wait in the background for time scrubbing history cleanup
	if is_exploded:
		current_recording_time += delta
		_record_history()
		# Clean up if the explosion has fallen out of the 5-second rewind history window
		if current_recording_time - explosion_real_time > max_history_duration:
			queue_free()
		return
		
	# Apply physics
	velocity.y += grenade_gravity * delta
	position += velocity * delta
	
	# LED Blinking calculation (flashes faster as it nears 0)
	led_timer += delta
	var blink_rate = 0.25 if time_remaining > 0.8 else (0.12 if time_remaining > 0.4 else 0.05)
	if led_timer >= blink_rate:
		led_timer = 0.0
		led_on = !led_on
		queue_redraw()
		
	# Fuse countdown
	time_remaining -= delta
	if time_remaining <= 0.0:
		explode()
		
	# Update recording parameters
	current_recording_time += delta
	_record_history()

func _record_history() -> void:
	history.append({
		"time": current_recording_time,
		"pos": position,
		"vel": velocity,
		"time_rem": time_remaining,
		"exploded": is_exploded,
		"exp_time": explosion_real_time,
		"visible": visible
	})
	
	# Limit history length
	while history.size() > 0 and (current_recording_time - history[0]["time"]) > max_history_duration:
		history.remove_at(0)

func _on_body_entered(body: Node2D) -> void:
	if is_exploded:
		return
		
	# --- NEW CATCH MECHANIC ---
	if body.name.contains("Player"):
		# Safely check if the global Scene Transition manager exists
		var st = get_node_or_null("/root/SceneTransition")
		
		# If we are currently in the Time Reverse phase...
		if st and st.is_reversing:
			# Give the grenade back to the player
			if "grenades" in body:
				body.grenades += 1
				
				# Prevent the player from hoarding more than their max limit!
				if "max_grenades" in body and body.grenades > body.max_grenades:
					body.grenades = body.max_grenades
					
			# Delete the grenade from the world (it has been caught)
			queue_free()
			
		# Whether caught or not, the grenade should not bounce off the player
		return
		
	# Explode immediately on contact with enemies
	if body.is_in_group("enemies"):
		explode()
		return
		
	# Ignore bullets and other grenades
	if body.is_in_group("bullets") or body.is_in_group("grenades"):
		return
		
	# Bounce off of solid environment tiles / platforms
	var normal = Vector2.UP # Fallback
	var found_collision = false
	
	if shapecast:
		# Sweep slightly along the velocity direction to detect normal
		if velocity.length_squared() > 0.01:
			shapecast.target_position = velocity.normalized() * 5.0
		else:
			shapecast.target_position = Vector2.DOWN * 5.0
			
		shapecast.force_shapecast_update()
		for i in range(shapecast.get_collision_count()):
			var collider = shapecast.get_collider(i)
			if is_instance_valid(collider):
				if collider.name.contains("Player") or collider.is_in_group("bullets") or collider.is_in_group("grenades"):
					continue # Filter out player/bullets/grenades
				normal = shapecast.get_collision_normal(i)
				found_collision = true
				break
				
	if found_collision:
		velocity = velocity.bounce(normal)
		# Apply correct damping based on collision surface
		if abs(normal.y) > 0.5: # Floor or ceiling
			velocity.y *= bounce_damping
			velocity.x *= friction_damping
			if abs(velocity.y) < 60.0:
				velocity.y = 0.0
		else: # Walls
			velocity.x *= bounce_damping
			velocity.y *= friction_damping
			if abs(velocity.x) < 60.0:
				velocity.x = 0.0
		
		# Push out of wall along the normal to prevent clipping
		position += normal * 2.0
	else:
		# Fallback to simple Y-axis bounce
		velocity.y = -velocity.y * bounce_damping
		velocity.x = velocity.x * friction_damping
		if abs(velocity.y) < 60.0:
			velocity.y = 0.0
		position.y -= 2.0

func explode() -> void:
	if is_exploded:
		return
		
	is_exploded = true
	explosion_real_time = current_recording_time
	
	# Hide visual representation
	visible = false
	queue_redraw()
	
	# Disable shape collision so it doesn't trigger collisions anymore
	if my_collision_shape:
		my_collision_shape.set_deferred("disabled", true)

	
	# Spawn beautiful custom visual blast shockwaves & fire debris particles
	_spawn_blast_particles()
	
	# Apply dynamic screen shake to any camera in the viewport
	_apply_screen_shake()
	
	# Detect enemies in range and deal damage
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= explosion_radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(1)

func _spawn_blast_particles() -> void:
	# Main explosion center node
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = global_position
	
	# 1. Shockwave line ring
	var shockwave = Line2D.new()
	shockwave.points = _get_circle_points(20.0)
	shockwave.width = 8.0
	shockwave.default_color = Color(1.0, 0.45, 0.0, 0.95) # Glowing vibrant orange
	effect.add_child(shockwave)
	
	# 2. Inner flame core ring
	var core_ring = Line2D.new()
	core_ring.points = _get_circle_points(10.0)
	core_ring.width = 5.0
	core_ring.default_color = Color(1.0, 0.95, 0.2, 1.0) # White-yellow hot core
	effect.add_child(core_ring)
	
	# 3. Burst particles (flying debris sparks)
	var particles = CPUParticles2D.new()
	particles.amount = 22
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.gravity = Vector2(0, 180) # Slight falling gravity
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 220.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 7.0
	particles.color = Color(1.0, 0.6, 0.1, 0.9)
	effect.add_child(particles)
	particles.emitting = true
	
	# 4. Big bright explosion light flash!
	var light = PointLight2D.new()
	light.name = "ExplosionLight"
	light.color = Color(1.0, 0.55, 0.1, 1.0) # Bright fiery orange
	light.energy = 4.5 # High initial energy for blinding flash
	light.texture_scale = 1.0 # Will scale up dynamically
	
	# Radial gradient texture
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(0.0, 0.0, 0.0, 0.0)])
	
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.85, 0.85)
	grad_tex.width = 128
	grad_tex.height = 128
	
	light.texture = grad_tex
	effect.add_child(light)
	
	# Animate rings & dynamic light using Tweens
	var tween = effect.create_tween()
	tween.tween_property(shockwave, "scale", Vector2(4.5, 4.5), 0.28)
	tween.parallel().tween_property(shockwave, "default_color:a", 0.0, 0.28)
	tween.parallel().tween_property(core_ring, "scale", Vector2(3.5, 3.5), 0.22)
	tween.parallel().tween_property(core_ring, "default_color:a", 0.0, 0.22)
	tween.parallel().tween_property(light, "texture_scale", 10.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(light, "energy", 0.0, 0.35)
	tween.tween_callback(effect.queue_free)

func _get_circle_points(radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	var steps = 16
	for i in range(steps + 1):
		var angle = i * TAU / steps
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _apply_screen_shake() -> void:
	# Search for any active Camera2D in the active viewport
	var camera = get_viewport().get_camera_2d()
	if camera:
		var original_offset = camera.offset
		var shake_tween = camera.create_tween()
		
		# Rapid, organic screen shake offsets
		for i in range(5):
			var rand_offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
			shake_tween.tween_property(camera, "offset", rand_offset, 0.03)
			
		# Return back to normal camera offset
		shake_tween.tween_property(camera, "offset", original_offset, 0.05)

# --- TIME REWIND IMPLEMENTATION ---

func set_paused(paused: bool) -> void:
	is_paused = paused
	set_physics_process(not paused)

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
			
	# Restore all states
	position = closest_entry["pos"]
	velocity = closest_entry["vel"]
	time_remaining = closest_entry["time_rem"]
	is_exploded = closest_entry["exploded"]
	explosion_real_time = closest_entry["exp_time"]
	visible = closest_entry["visible"]
	
	# Safely re-enable or disable the collision shape
	if my_collision_shape:
		my_collision_shape.disabled = is_exploded
		
	queue_redraw()

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
