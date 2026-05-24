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
var max_history_duration: float = 5.0
var current_recording_time: float = 0.0

# Visual animation state
var led_on: bool = false
var led_timer: float = 0.0
var is_exploded: bool = false
var explosion_real_time: float = -1.0

func _ready() -> void:
	add_to_group("grenades")
	add_to_group("rewindable_objects")
	
	my_collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10.0
	my_collision_shape.shape = shape
	add_child(my_collision_shape)

	body_entered.connect(_on_body_entered)
	
	shapecast = ShapeCast2D.new()
	var cast_shape = CircleShape2D.new()
	cast_shape.radius = 8.0
	shapecast.shape = cast_shape
	shapecast.exclude_parent = true
	add_child(shapecast)

func _draw() -> void:
	if is_exploded:
		return
		
	draw_circle(Vector2.ZERO, 10.0, Color(0.2, 0.35, 0.15, 1.0))
	draw_circle(Vector2.ZERO, 8.0, Color(0.28, 0.45, 0.22, 1.0))
	draw_rect(Rect2(-4, -13, 8, 4), Color(0.65, 0.55, 0.2, 1.0))
	draw_arc(Vector2(-6, -11), 3.0, 0.0, TAU, 8, Color(0.5, 0.5, 0.5, 1.0), 1.5)
	var led_color = Color(1.0, 0.1, 0.1, 1.0) if led_on else Color(0.1, 0.0, 0.0, 1.0)
	draw_circle(Vector2(0, -2), 2.5, led_color)

func _physics_process(delta: float) -> void:
	var st = get_node_or_null("/root/SceneTransition")
	if is_paused or (st and st.is_reversing):
		set_physics_process(false)
		return
		
	if is_exploded:
		set_physics_process(false)
		return
		
	velocity.y += grenade_gravity * delta
	position += velocity * delta
	
	led_timer += delta
	var blink_rate = 0.25 if time_remaining > 0.8 else (0.12 if time_remaining > 0.4 else 0.05)
	if led_timer >= blink_rate:
		led_timer = 0.0
		led_on = !led_on
		queue_redraw()
		
	time_remaining -= delta
	if time_remaining <= 0.0:
		explode()
		return
		
	current_recording_time += delta
	_record_history()

func _record_history() -> void:
	var st = get_node_or_null("/root/SceneTransition")
	var record_time = st.elapsed_time if st else current_recording_time
	history.append({
		"time": record_time,
		"pos": position,
		"vel": velocity,
		"time_rem": time_remaining,
		"exploded": is_exploded,
		"exp_time": explosion_real_time,
		"visible": visible
	})

func _on_body_entered(body: Node2D) -> void:
	if is_exploded:
		return

	# ── PLAYER ──────────────────────────────────────────────────────────────
	if body.name.contains("Player"):
		var st = get_node_or_null("/root/SceneTransition")
		if st and st.is_reversing:
			# Time Reverse phase: catch the grenade and return it
			if "grenades" in body:
				body.grenades += 1
				if "max_grenades" in body and body.grenades > body.max_grenades:
					body.grenades = body.max_grenades
			queue_free()
		# else: do nothing — grenade passes through the player.
		#       Damage is handled purely by blast radius in explode().
		return

	# ── DESTRUCTIBLE BOXES ───────────────────────────────────────────────────
	if body.is_in_group("destructible"):
		explode()
		return

	# ── ENEMIES ──────────────────────────────────────────────────────────────
	if body.is_in_group("enemies"):
		explode()
		return

	# ── IGNORE OTHER PROJECTILES ─────────────────────────────────────────────
	if body.is_in_group("bullets") or body.is_in_group("grenades"):
		return

	# ── BOUNCE OFF EVERYTHING ELSE (walls, floors, platforms) ────────────────
	var normal = Vector2.UP
	var found_collision = false
	
	if shapecast:
		if velocity.length_squared() > 0.01:
			shapecast.target_position = velocity.normalized() * 5.0
		else:
			shapecast.target_position = Vector2.DOWN * 5.0
			
		shapecast.force_shapecast_update()
		for i in range(shapecast.get_collision_count()):
			var collider = shapecast.get_collider(i)
			if is_instance_valid(collider):
				if collider.name.contains("Player") or collider.is_in_group("bullets") or collider.is_in_group("grenades"):
					continue
				normal = shapecast.get_collision_normal(i)
				found_collision = true
				break
				
	if found_collision:
		velocity = velocity.bounce(normal)
		if abs(normal.y) > 0.5:
			velocity.y *= bounce_damping
			velocity.x *= friction_damping
			if abs(velocity.y) < 60.0:
				velocity.y = 0.0
		else:
			velocity.x *= bounce_damping
			velocity.y *= friction_damping
			if abs(velocity.x) < 60.0:
				velocity.x = 0.0
		position += normal * 2.0
	else:
		velocity.y = -velocity.y * bounce_damping
		velocity.x = velocity.x * friction_damping
		if abs(velocity.y) < 60.0:
			velocity.y = 0.0
		position.y -= 2.0

func explode() -> void:
	if is_exploded:
		return
		
	is_exploded = true
	var st = get_node_or_null("/root/SceneTransition")
	explosion_real_time = st.elapsed_time if st else current_recording_time
	
	_record_history()
	
	visible = false
	queue_redraw()
	
	if my_collision_shape:
		my_collision_shape.set_deferred("disabled", true)

	_spawn_blast_particles()
	_apply_screen_shake()

	# ── ENEMIES in radius ────────────────────────────────────────────────────
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			if global_position.distance_to(enemy.global_position) <= explosion_radius:
				if enemy.has_method("take_damage"):
					enemy.take_damage(1)

	# ── PLAYER in radius ─────────────────────────────────────────────────────
	var current_scene = get_tree().current_scene
	if current_scene:
		var player = current_scene.get_node_or_null("Player")
		if not player:
			player = current_scene.get_node_or_null("Player (Testing)")
		if player and is_instance_valid(player):
			if global_position.distance_to(player.global_position) <= explosion_radius:
				if player.has_method("die"):
					player.die()

	# ── DESTRUCTIBLE BOXES in radius ─────────────────────────────────────────
	for box in get_tree().get_nodes_in_group("destructible"):
		if is_instance_valid(box):
			if global_position.distance_to(box.global_position) <= explosion_radius:
				if box.has_method("take_explosion_damage"):
					box.take_explosion_damage()

func _spawn_blast_particles() -> void:
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = global_position
	
	var shockwave = Line2D.new()
	shockwave.points = _get_circle_points(20.0)
	shockwave.width = 8.0
	shockwave.default_color = Color(1.0, 0.45, 0.0, 0.95)
	effect.add_child(shockwave)
	
	var core_ring = Line2D.new()
	core_ring.points = _get_circle_points(10.0)
	core_ring.width = 5.0
	core_ring.default_color = Color(1.0, 0.95, 0.2, 1.0)
	effect.add_child(core_ring)
	
	var particles = CPUParticles2D.new()
	particles.amount = 22
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.gravity = Vector2(0, 180)
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 220.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 7.0
	particles.color = Color(1.0, 0.6, 0.1, 0.9)
	effect.add_child(particles)
	particles.emitting = true
	
	var light = PointLight2D.new()
	light.name = "ExplosionLight"
	light.color = Color(1.0, 0.55, 0.1, 1.0)
	light.energy = 4.5
	light.texture_scale = 1.0
	
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
	
	var tween = effect.create_tween()
	tween.tween_property(shockwave, "scale", Vector2(4.5, 4.5), 0.28)
	tween.parallel().tween_property(shockwave, "default_color:a", 0.0, 0.28)
	tween.parallel().tween_property(core_ring, "scale", Vector2(3.5, 3.5), 0.22)
	tween.parallel().tween_property(core_ring, "default_color:a", 0.0, 0.22)
	tween.parallel().tween_property(light, "texture_scale", 10.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(light, "energy", 0.0, 0.35)
	tween.tween_callback(effect.queue_free)

func _spawn_implode_particles() -> void:
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = global_position
	
	var shockwave = Line2D.new()
	shockwave.points = _get_circle_points(20.0)
	shockwave.width = 8.0
	shockwave.default_color = Color(1.0, 0.45, 0.0, 0.0)
	shockwave.scale = Vector2(4.5, 4.5)
	effect.add_child(shockwave)
	
	var core_ring = Line2D.new()
	core_ring.points = _get_circle_points(10.0)
	core_ring.width = 5.0
	core_ring.default_color = Color(1.0, 0.95, 0.2, 0.0)
	core_ring.scale = Vector2(3.5, 3.5)
	effect.add_child(core_ring)
	
	var particles = CPUParticles2D.new()
	particles.amount = 22
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.gravity = Vector2(0, -180)
	particles.initial_velocity_min = -220.0
	particles.initial_velocity_max = -90.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 7.0
	particles.color = Color(1.0, 0.6, 0.1, 0.9)
	effect.add_child(particles)
	particles.emitting = true
	
	var light = PointLight2D.new()
	light.name = "ExplosionLight"
	light.color = Color(1.0, 0.55, 0.1, 1.0)
	light.energy = 0.0
	light.texture_scale = 10.0
	
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
	
	var tween = effect.create_tween()
	tween.tween_property(shockwave, "scale", Vector2(1.0, 1.0), 0.28)
	tween.parallel().tween_property(shockwave, "default_color:a", 0.95, 0.28)
	tween.parallel().tween_property(core_ring, "scale", Vector2(1.0, 1.0), 0.22)
	tween.parallel().tween_property(core_ring, "default_color:a", 1.0, 0.22)
	tween.parallel().tween_property(light, "texture_scale", 1.0, 0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(light, "energy", 4.5, 0.35)
	tween.tween_callback(effect.queue_free)

func _get_circle_points(radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	var steps = 16
	for i in range(steps + 1):
		var angle = i * TAU / steps
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _apply_screen_shake() -> void:
	var camera = get_viewport().get_camera_2d()
	if camera:
		var original_offset = camera.offset
		var shake_tween = camera.create_tween()
		for i in range(5):
			var rand_offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
			shake_tween.tween_property(camera, "offset", rand_offset, 0.03)
		shake_tween.tween_property(camera, "offset", original_offset, 0.05)

# --- TIME REWIND ---

func set_paused(paused: bool) -> void:
	is_paused = paused
	set_physics_process(not paused)

func scrub_time_absolute(target_time: float) -> void:
	if history.size() == 0:
		return
		
	var was_exploded_before = is_exploded
	
	var closest_entry = history[0]
	var min_diff = abs(closest_entry["time"] - target_time)
	
	for entry in history:
		var diff = abs(entry["time"] - target_time)
		if diff < min_diff:
			min_diff = diff
			closest_entry = entry
			
	position = closest_entry["pos"]
	velocity = closest_entry["vel"]
	time_remaining = closest_entry["time_rem"]
	is_exploded = closest_entry["exploded"]
	explosion_real_time = closest_entry["exp_time"]
	visible = closest_entry["visible"]
	
	if my_collision_shape:
		my_collision_shape.disabled = is_exploded
		
	if was_exploded_before and not is_exploded:
		_spawn_implode_particles()
	elif not was_exploded_before and is_exploded:
		_spawn_blast_particles()
		
	queue_redraw()

func scrub_time(offset_ms: float) -> void:
	if history.size() == 0:
		return
		
	var latest_time = history[history.size() - 1]["time"]
	var target_time = latest_time - (offset_ms / 1000.0)
	scrub_time_absolute(target_time)

func commit_scrubbed_state(offset_ms: float) -> void:
	if history.size() == 0:
		return
		
	var latest_time = history[history.size() - 1]["time"]
	var target_time = latest_time - (offset_ms / 1000.0)
	
	var new_history = []
	for entry in history:
		if entry["time"] <= target_time:
			new_history.append(entry)
			
	history = new_history
	if history.size() > 0:
		current_recording_time = history[history.size() - 1]["time"]
		var last_entry = history[history.size() - 1]
		is_exploded = last_entry["exploded"]
		if not is_exploded:
			set_physics_process(true)
	else:
		current_recording_time = 0.0
