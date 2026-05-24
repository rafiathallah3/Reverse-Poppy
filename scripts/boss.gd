extends CharacterBody2D

# ── Boss Configuration ──────────────────────────────────────────────────────
@export var max_health: int = 5
var health: int = max_health

var is_dead: bool = false
var is_invulnerable: bool = false # Brief invulnerability after hit

const PROJECTILE_SCRIPT = preload("res://scripts/boss_projectile.gd")

@onready var SFX_BOSS_TEMBAK = load("res://assets/SFX/boss_tembak.mp3")

# ── Shooting State ──────────────────────────────────────────────────────────
var shoot_timer: float = 0.5 # 0.5s initial delay
var has_been_hit: bool = false
var base_attack_cooldown: float = 2.8 # Initial delay (slower)
var min_attack_cooldown: float = 1.2
var cooldown_reduction_per_hit: float = 0.35 # Slightly faster shooting per hit

var current_attack_cooldown: float = base_attack_cooldown
var shoot_alternate: bool = false # Alternate projectile types

# ── Sprite References ───────────────────────────────────────────────────────
var head_sprite: Sprite2D = null
var segment_sprites: Array = []
var death_sprite: Sprite2D = null

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
	
	# Reference sprites
	head_sprite = get_node_or_null("4")
	var s3 = get_node_or_null("3")
	var s2 = get_node_or_null("2")
	var s1 = get_node_or_null("1")
	segment_sprites.clear()
	if s3: segment_sprites.append(s3)
	if s2: segment_sprites.append(s2)
	if s1: segment_sprites.append(s1)
	death_sprite = get_node_or_null("Death")
	
	# Center all sprites on the boss local origin
	if head_sprite:
		head_sprite.position = Vector2(0, 0)
	if death_sprite:
		death_sprite.position = Vector2(0, 0)
	for seg in segment_sprites:
		if is_instance_valid(seg):
			seg.position = Vector2(0, 0)
			if seg is AnimatedSprite2D:
				seg.play("default")
				
	_update_sprite_visibility()
	
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
	
	# Floating hover animation applied to all sprites
	float_time += delta
	var hover_offset = sin(float_time * float_speed) * float_amplitude
	if is_instance_valid(head_sprite):
		head_sprite.position = Vector2(0, hover_offset)
	if is_instance_valid(death_sprite):
		death_sprite.position = Vector2(0, hover_offset)
	for seg in segment_sprites:
		if is_instance_valid(seg):
			seg.position = Vector2(0, hover_offset)
	
	# Eye glow pulsing
	eye_glow_timer += delta
	eye_glow_intensity = 0.7 + sin(eye_glow_timer * 4.0) * 0.3
	
	# Aura pulse
	aura_pulse_timer += delta
	
	# Hit flash decay
	if hit_flash_timer > 0.0:
		hit_flash_timer -= delta
		
	# Hit flash glow on all sprites
	var is_flashing = hit_flash_timer > 0.0
	var flash_mod = Color(5.0, 5.0, 5.0, 1.0) if is_flashing else Color(1.0, 1.0, 1.0, 1.0)
	
	if is_instance_valid(head_sprite):
		head_sprite.modulate = flash_mod
	if is_instance_valid(death_sprite):
		death_sprite.modulate = flash_mod
	for seg in segment_sprites:
		if is_instance_valid(seg):
			seg.modulate = flash_mod
	
	# Boss light pulsing
	if boss_light:
		boss_light.energy = 1.5 + sin(aura_pulse_timer * 2.5) * 0.8
		boss_light.global_position = global_position
	
	queue_redraw()

func _draw() -> void:
	pass

func take_damage(amount: int, from_grenade: bool = false) -> void:
	if is_dead or is_invulnerable or not from_grenade:
		return
	
	has_been_hit = true
	health -= amount
	hit_flash_timer = 0.3
	
	_spawn_hit_particles()
	_apply_screen_shake()
	
	_update_sprite_visibility()
	
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

func _play_sfx_detached(stream: AudioStream) -> void:
	var audio_player = AudioStreamPlayer2D.new()
	audio_player.stream = stream
	audio_player.volume_db = -6.0
	audio_player.global_position = global_position
	get_parent().add_child(audio_player)
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)

func shoot_projectile() -> void:
	var current_scene = get_tree().current_scene
	var player_node = null
	if current_scene:
		player_node = current_scene.get_node_or_null("Player")
		if not player_node:
			player_node = current_scene.get_node_or_null("Player (Testing)")
			
	if not player_node or not is_instance_valid(player_node) or player_node.is_dying:
		return
		
	_play_sfx_detached(SFX_BOSS_TEMBAK)
	
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
	
	# Hide living sprites, show death sprite
	_update_sprite_visibility()
	if is_instance_valid(death_sprite):
		death_sprite.modulate.a = 1.0
	
	# Fade out boss visual
	var tween = create_tween()
	if is_instance_valid(death_sprite):
		tween.tween_property(death_sprite, "modulate:a", 0.0, 1.2)
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
	
	if is_instance_valid(head_sprite):
		head_sprite.position = Vector2(0, 0)
		head_sprite.modulate = Color(1, 1, 1)
	for seg in segment_sprites:
		if is_instance_valid(seg):
			seg.position = Vector2(0, 0)
			seg.modulate = Color(1, 1, 1)
	if is_instance_valid(death_sprite):
		death_sprite.visible = false
		
	_update_sprite_visibility()
	
	if my_collision:
		my_collision.set_deferred("disabled", false)
	if hurtbox:
		hurtbox.set_deferred("monitoring", true)
	if boss_light:
		boss_light.visible = true
	
	queue_redraw()

func _update_sprite_visibility() -> void:
	# At full health (5), use assets/bossig.png (head_sprite "4")
	# After first hit (4), switch to assets/Bosssegment1 (node "3")
	# After second hit (3), switch to assets/Bosssegment2 (node "2")
	# After third hit (2 or 1), switch to assets/Bossegment3 (node "1")
	# When no HP left (0), sprite is assets/Bossdead.png (death_sprite)
	
	if is_instance_valid(head_sprite):
		head_sprite.visible = (health == 5)
		
	var s3 = get_node_or_null("3")
	if is_instance_valid(s3):
		s3.visible = (health == 4)
		
	var s2 = get_node_or_null("2")
	if is_instance_valid(s2):
		s2.visible = (health == 3)
		
	var s1 = get_node_or_null("1")
	if is_instance_valid(s1):
		s1.visible = (health == 2 or health == 1)
		
	if is_instance_valid(death_sprite):
		death_sprite.visible = (health == 0)
