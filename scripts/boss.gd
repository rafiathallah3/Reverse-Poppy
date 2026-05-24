extends CharacterBody2D

# ── Boss Configuration ──────────────────────────────────────────────────────
@export var max_health: int = 5
var health: int = max_health

var is_dead: bool = false
var is_invulnerable: bool = false # Brief invulnerability after hit

const PROJECTILE_SCRIPT = preload("res://scripts/boss_projectile.gd")

# ── Shooting State ──────────────────────────────────────────────────────────
var shoot_timer: float = 0.5 # 0.5s initial delay
var has_been_hit: bool = false
var base_attack_cooldown: float = 2.2 # Initial delay (not too fast, not too slow)
var min_attack_cooldown: float = 0.8
var cooldown_reduction_per_hit: float = 0.35 # Slightly faster shooting per hit

var current_attack_cooldown: float = base_attack_cooldown
var shoot_alternate: bool = false # Alternate projectile types

# ── Floating animation ──────────────────────────────────────────────────────
var float_time: float = 0.0
var float_amplitude: float = 6.0
var float_speed: float = 3.0
var base_y: float = 0.0

# ── Visual animation state ──────────────────────────────────────────────────
var eye_glow_timer: float = 0.0
var eye_glow_intensity: float = 1.0
var aura_pulse_timer: float = 0.0
var hit_flash_timer: float = 0.0 # White flash on damage

# ── Teleportation ───────────────────────────────────────────────────────────
var platform_positions: Array = [] # Set by boss_fight_manager
var current_platform_index: int = -1

# ── References ──────────────────────────────────────────────────────────────
var my_collision: CollisionShape2D
var hurtbox: Area2D
var hurtbox_collision: CollisionShape2D
var boss_light: PointLight2D

# ── Signals ─────────────────────────────────────────────────────────────────
signal boss_damaged(new_health: int)
signal boss_defeated()

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	
	base_y = position.y
	
	# ── Main collision shape (for grenade physics / body detection) ──
	my_collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(40, 64)
	my_collision.shape = shape
	my_collision.position = Vector2(0, 0)
	add_child(my_collision)
	
	# ── Hurtbox (kills player on contact) ──
	hurtbox = Area2D.new()
	hurtbox.name = "BossHurtbox"
	hurtbox_collision = CollisionShape2D.new()
	var hurtbox_shape = RectangleShape2D.new()
	hurtbox_shape.size = Vector2(44, 68)
	hurtbox_collision.shape = hurtbox_shape
	hurtbox.add_child(hurtbox_collision)
	add_child(hurtbox)
	hurtbox.body_entered.connect(_on_hurtbox_entered)
	
	# ── Boss glow light ──
	boss_light = PointLight2D.new()
	boss_light.color = Color(0.8, 0.1, 0.9, 1.0)
	boss_light.energy = 2.0
	boss_light.texture_scale = 10.0
	
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
	boss_light.texture = grad_tex
	add_child(boss_light)

func _process(delta: float) -> void:
	if is_dead:
		return
	
	# Handle shooting cooldown
	var mgr = get_parent().get_node_or_null("BossFightManager")
	if not is_dead and mgr and not mgr.is_in_dialogue and is_instance_valid(mgr.player) and not mgr.player.is_paused:
		var is_teleporting = is_invulnerable and (mgr.active_force_field == null or not is_instance_valid(mgr.active_force_field) or mgr.active_force_field.health <= 0)
		if not is_teleporting:
			shoot_timer -= delta
			if shoot_timer <= 0.0:
				shoot_projectile()
				shoot_timer = get_current_cooldown()
	
	# Floating hover animation
	float_time += delta
	position.y = base_y + sin(float_time * float_speed) * float_amplitude
	
	# Eye glow pulsing
	eye_glow_timer += delta
	eye_glow_intensity = 0.7 + sin(eye_glow_timer * 4.0) * 0.3
	
	# Aura pulse
	aura_pulse_timer += delta
	
	# Hit flash decay
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
	
	# Boss light pulsing
	if boss_light:
		boss_light.energy = 1.5 + sin(aura_pulse_timer * 2.5) * 0.8
	
	queue_redraw()

func _draw() -> void:
	if is_dead:
		return
	
	var flash = hit_flash_timer > 0.0
	
	# ── Aura glow (outer energy) ──
	var aura_alpha = 0.15 + sin(aura_pulse_timer * 3.0) * 0.08
	var aura_color = Color(0.6, 0.1, 0.9, aura_alpha)
	if flash:
		aura_color = Color(1.0, 1.0, 1.0, 0.5)
	draw_circle(Vector2(0, 0), 42.0, aura_color)
	
	# ── Body (dark silhouette) ──
	var body_color = Color(0.08, 0.05, 0.12, 1.0)
	if flash:
		body_color = Color(1.0, 0.8, 0.8, 1.0)
	
	# Torso
	draw_rect(Rect2(-14, -20, 28, 36), body_color)
	# Head
	draw_circle(Vector2(0, -28), 14.0, body_color)
	# Legs
	draw_rect(Rect2(-12, 16, 8, 18), body_color)
	draw_rect(Rect2(4, 16, 8, 18), body_color)
	# Arms
	draw_rect(Rect2(-20, -16, 6, 24), body_color)
	draw_rect(Rect2(14, -16, 6, 24), body_color)
	
	# ── Cloak/cape detail ──
	var cape_color = Color(0.12, 0.05, 0.18, 0.9)
	if flash:
		cape_color = Color(0.9, 0.7, 0.9, 0.9)
	draw_rect(Rect2(-16, -10, 32, 28), cape_color)
	
	# ── Glowing eyes ──
	var eye_color = Color(1.0, 0.15, 0.15, eye_glow_intensity)
	if flash:
		eye_color = Color(1.0, 1.0, 1.0, 1.0)
	draw_circle(Vector2(-5, -30), 2.5, eye_color)
	draw_circle(Vector2(5, -30), 2.5, eye_color)
	
	# Eye glow halo
	var halo_color = Color(1.0, 0.1, 0.1, eye_glow_intensity * 0.3)
	draw_circle(Vector2(-5, -30), 5.0, halo_color)
	draw_circle(Vector2(5, -30), 5.0, halo_color)
	
	# ── Purple energy lines on body ──
	var energy_color = Color(0.7, 0.2, 1.0, 0.4 + sin(aura_pulse_timer * 5.0) * 0.2)
	draw_line(Vector2(-10, -15), Vector2(-10, 10), energy_color, 1.5)
	draw_line(Vector2(10, -15), Vector2(10, 10), energy_color, 1.5)
	draw_line(Vector2(-6, -5), Vector2(6, -5), energy_color, 1.5)

func take_damage(amount: int, from_grenade: bool = false) -> void:
	if is_dead or is_invulnerable or not from_grenade:
		return
	
	has_been_hit = true
	health -= amount
	hit_flash_timer = 0.3
	
	_spawn_hit_particles()
	_apply_screen_shake()
	
	boss_damaged.emit(health)
	
	if health <= 0:
		health = 0
		_die()
		return
	
	# Brief invulnerability + teleport
	is_invulnerable = true
	
	# Reset shoot timer on hit so the boss doesn't immediately shoot after teleporting
	shoot_timer = get_current_cooldown() + 0.5
	
	# Teleport to a random platform after a short delay
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(self ) and not is_dead:
		_teleport_to_random_platform()
		is_invulnerable = false

func get_current_cooldown() -> float:
	var hits_taken = max_health - health
	var cd = base_attack_cooldown - (hits_taken * cooldown_reduction_per_hit)
	
	var is_shielded = false
	var mgr = get_parent().get_node_or_null("BossFightManager")
	if mgr and is_instance_valid(mgr.active_force_field) and mgr.active_force_field.health > 0:
		is_shielded = true
		cd *= 0.55 # 45% faster shooting when shielded!
		
	var limit = 0.5 if is_shielded else min_attack_cooldown
	return max(cd, limit)

func shoot_projectile() -> void:
	var current_scene = get_tree().current_scene
	var player_node = null
	if current_scene:
		player_node = current_scene.get_node_or_null("Player")
		if not player_node:
			player_node = current_scene.get_node_or_null("Player (Testing)")
			
	if not player_node or not is_instance_valid(player_node) or player_node.is_dying:
		return
		
	var proj = Area2D.new()
	proj.set_script(PROJECTILE_SCRIPT)
	
	# Determine if we should shoot tracking projectile
	var tracking = false
	if has_been_hit:
		tracking = shoot_alternate
		shoot_alternate = !shoot_alternate
		
	proj.is_tracking = tracking
	proj.global_position = global_position
	
	# Initial direction directly at player
	var dir = (player_node.global_position - global_position).normalized()
	proj.velocity = dir * proj.speed
	proj.rotation = dir.angle()
	
	get_parent().add_child(proj)

func _teleport_to_random_platform() -> void:
	if platform_positions.size() == 0:
		return
	
	# Pick a random platform that's different from current
	var available = []
	for i in range(platform_positions.size()):
		if i != current_platform_index:
			available.append(i)
	
	if available.size() == 0:
		return
	
	var new_index = available[randi() % available.size()]
	current_platform_index = new_index
	var target_pos = platform_positions[new_index]
	
	# Teleport visual: fade out
	_spawn_teleport_effect(global_position)
	
	# Move boss above the platform
	position = target_pos + Vector2(0, -50)
	base_y = position.y
	float_time = 0.0
	
	# Teleport visual: fade in at new position
	_spawn_teleport_effect(global_position)

func _die() -> void:
	is_dead = true
	
	if my_collision:
		my_collision.set_deferred("disabled", true)
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
	if boss_light:
		boss_light.visible = false
	
	# Death dissolve effect
	_spawn_death_effect()
	
	boss_defeated.emit()
	
	# Fade out boss visual
	var tween = create_tween()
	tween.tween_property(self , "modulate:a", 0.0, 1.0)
	await tween.finished
	visible = false

func _on_hurtbox_entered(body: Node2D) -> void:
	if is_dead or is_invulnerable:
		return
	if body.name.contains("Player"):
		if body.has_method("die"):
			body.die()

func _spawn_hit_particles() -> void:
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = global_position
	
	var particles = CPUParticles2D.new()
	particles.amount = 16
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.gravity = Vector2(0, 100)
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 180.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color(0.8, 0.2, 1.0, 0.9)
	effect.add_child(particles)
	particles.emitting = true
	
	var light = PointLight2D.new()
	light.color = Color(1.0, 0.3, 0.8, 1.0)
	light.energy = 3.5
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
	
	var tween = effect.create_tween()
	tween.tween_property(light, "texture_scale", 8.0, 0.3)
	tween.parallel().tween_property(light, "energy", 0.0, 0.3)
	tween.tween_callback(effect.queue_free)

func _spawn_teleport_effect(pos: Vector2) -> void:
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = pos
	
	# Purple energy ring
	var ring = Line2D.new()
	ring.points = _get_circle_points(20.0)
	ring.width = 4.0
	ring.default_color = Color(0.7, 0.2, 1.0, 0.9)
	effect.add_child(ring)
	
	var particles = CPUParticles2D.new()
	particles.amount = 20
	particles.explosiveness = 0.9
	particles.spread = 180.0
	particles.gravity = Vector2(0, -50)
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 100.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color = Color(0.6, 0.1, 0.9, 0.8)
	effect.add_child(particles)
	particles.emitting = true
	
	var tween = effect.create_tween()
	tween.tween_property(ring, "scale", Vector2(3.0, 3.0), 0.3)
	tween.parallel().tween_property(ring, "default_color:a", 0.0, 0.3)
	tween.tween_callback(effect.queue_free)

func _spawn_death_effect() -> void:
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = global_position
	
	# Big purple explosion
	var particles = CPUParticles2D.new()
	particles.amount = 40
	particles.explosiveness = 0.95
	particles.spread = 180.0
	particles.gravity = Vector2(0, 60)
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 200.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.color = Color(0.7, 0.15, 1.0, 0.9)
	effect.add_child(particles)
	particles.emitting = true
	
	# Death flash light
	var light = PointLight2D.new()
	light.color = Color(0.8, 0.2, 1.0, 1.0)
	light.energy = 6.0
	light.texture_scale = 2.0
	
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
	light.texture = grad_tex
	effect.add_child(light)
	
	var tween = effect.create_tween()
	tween.tween_property(light, "texture_scale", 20.0, 0.8)
	tween.parallel().tween_property(light, "energy", 0.0, 0.8)
	tween.tween_callback(effect.queue_free)

func _apply_screen_shake() -> void:
	var camera = get_viewport().get_camera_2d()
	if camera:
		var original_offset = camera.offset
		var shake_tween = camera.create_tween()
		for i in range(6):
			var rand_offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
			shake_tween.tween_property(camera, "offset", rand_offset, 0.03)
		shake_tween.tween_property(camera, "offset", original_offset, 0.05)

func _get_circle_points(radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	var steps = 16
	for i in range(steps + 1):
		var angle = i * TAU / steps
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

# ── Reset for player death ──────────────────────────────────────────────────
func reset_boss() -> void:
	health = max_health
	is_dead = false
	is_invulnerable = false
	visible = true
	modulate.a = 1.0
	hit_flash_timer = 0.0
	float_time = 0.0
	
	has_been_hit = false
	shoot_timer = 0.5
	shoot_alternate = false
	
	if my_collision:
		my_collision.set_deferred("disabled", false)
	if hurtbox:
		hurtbox.set_deferred("monitoring", true)
	if boss_light:
		boss_light.visible = true
	
	queue_redraw()
