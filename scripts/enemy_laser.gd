extends CharacterBody2D

@export var shoot_interval: float = 3.0
@export var shoot_direction: Vector2 = Vector2.RIGHT
@export var laser_color: Color = Color(1.0, 0.9, 0.1, 1.0) # Radiant neon yellow laser
@export var laser_muzzle_offset: Vector2 = Vector2(-12, 22) # Relative to sprite center
@export var float_amplitude: float = 0.0
@export var float_speed: float = 0.0

var spawn_position: Vector2 = Vector2.ZERO
var time_elapsed: float = 0.0
var shoot_timer: float = 0.0

var is_dead: bool = false
var is_time_reversing: bool = false
var was_revived_in_reverse: bool = false
var player_in_zone: bool = false

const SCRAP_TEXTURE = preload("res://assets/Scrap.png")
@onready var SFX_REVIVE = load("res://assets/SFX/revive.mp3")
var scrap_sprite: Sprite2D = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var revive_label: Label = $ReviveLabel
@onready var revive_zone: Area2D = $ReviveZone
@onready var main_collision: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hitbox_to_hurt_player



func _ready() -> void:
	add_to_group("enemies")
	spawn_position = position
	shoot_timer = shoot_interval

	if revive_label:
		revive_label.visible = false
		revive_label.text = "Press Y to Revive"

	if revive_zone:
		revive_zone.body_entered.connect(_on_zone_entered)
		revive_zone.body_exited.connect(_on_zone_exited)

	if hurtbox:
		hurtbox.body_entered.connect(_on_hurtbox_entered)

	if animated_sprite:
		animated_sprite.play("idle")
		animated_sprite.frame_changed.connect(_on_frame_changed)
		animated_sprite.animation_finished.connect(_on_animation_finished)

func _get_st() -> Node:
	return get_node_or_null("/root/SceneTransition")

func _is_reverse_phase() -> bool:
	var st = _get_st()
	return st != null and st.is_reversing

func _physics_process(delta: float) -> void:
	if is_dead or is_time_reversing or was_revived_in_reverse:
		return

	# Handle shooting timer
	var st = _get_st()
	if st and st.is_reversing:
		return

	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = shoot_interval
		if animated_sprite and not is_dead:
			animated_sprite.play("shoot")

func _play_sfx(stream: AudioStream) -> void:
	var audio_player = AudioStreamPlayer2D.new()
	audio_player.stream = stream
	audio_player.volume_db = -6.0 # <--- ADD THIS (Cuts volume in half)
	add_child(audio_player)
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)
	

func _process(_delta: float) -> void:
	var in_reverse: bool = _is_reverse_phase()

	if was_revived_in_reverse and not in_reverse:
		_fully_restore()
		return

	if revive_label:
		revive_label.visible = in_reverse and is_time_reversing and player_in_zone

	if in_reverse and is_time_reversing and player_in_zone:
		if Input.is_action_just_pressed("interact"):
			revive()

func _on_frame_changed() -> void:
	if is_dead or is_time_reversing or was_revived_in_reverse:
		return
		
	if animated_sprite and animated_sprite.animation == "shoot" and animated_sprite.frame == 3:
		fire_laser()

func _on_animation_finished() -> void:
	if animated_sprite and animated_sprite.animation == "shoot":
		animated_sprite.play("idle")

func fire_laser() -> void:
	# Calculate global muzzle position
	var muzzle_pos = global_position + Vector2(laser_muzzle_offset.x * scale.x, laser_muzzle_offset.y * scale.y)
	if animated_sprite and animated_sprite.flip_h:
		# Flip offset if sprite is flipped
		var flipped_offset = laser_muzzle_offset
		flipped_offset.x = - flipped_offset.x
		muzzle_pos = global_position + Vector2(flipped_offset.x * scale.x, flipped_offset.y * scale.y)

	var dir = shoot_direction.normalized()
	if animated_sprite and animated_sprite.flip_h:
		dir.x = - dir.x

	# 1. Cast Ray to find collision point
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(muzzle_pos, muzzle_pos + dir * 1500.0, 1) # Layer 1 is environment / player
	# Include player collision layer specifically if needed, but let's query all layers
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	var end_pos = muzzle_pos + dir * 1500.0
	if result:
		end_pos = result.position
		var hit_collider = result.collider
		if hit_collider and hit_collider.name.contains("Player"):
			if hit_collider.has_method("die"):
				hit_collider.die()

	# 2. Draw Premium Laser Beam Visuals
	_spawn_laser_beam_effect(muzzle_pos, end_pos)

func _spawn_laser_beam_effect(start: Vector2, end: Vector2) -> void:
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = Vector2.ZERO

	# Outer glowing beam
	var outer_line = Line2D.new()
	outer_line.points = PackedVector2Array([start, end])
	outer_line.width = 8.0
	outer_line.default_color = laser_color
	outer_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outer_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	effect.add_child(outer_line)

	# Inner intense white core
	var inner_line = Line2D.new()
	inner_line.points = PackedVector2Array([start, end])
	inner_line.width = 3.0
	inner_line.default_color = Color(1.0, 1.0, 1.0, 1.0)
	inner_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	inner_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	effect.add_child(inner_line)

	# High energy PointLight2D flash along the laser beam center
	var light = PointLight2D.new()
	light.color = laser_color
	light.energy = 4.0
	light.texture_scale = 2.0
	light.global_position = (start + end) / 2.0

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

	# 3. Create muzzle burst particles
	var muzzle_particles = CPUParticles2D.new()
	muzzle_particles.global_position = start
	muzzle_particles.amount = 12
	muzzle_particles.lifetime = 0.3
	muzzle_particles.explosiveness = 1.0
	muzzle_particles.spread = 45.0
	muzzle_particles.direction = shoot_direction
	if animated_sprite and animated_sprite.flip_h:
		muzzle_particles.direction.x = - muzzle_particles.direction.x
	muzzle_particles.gravity = Vector2.ZERO
	muzzle_particles.initial_velocity_min = 100.0
	muzzle_particles.initial_velocity_max = 200.0
	muzzle_particles.scale_amount_min = 2.0
	muzzle_particles.scale_amount_max = 4.0
	muzzle_particles.color = laser_color
	effect.add_child(muzzle_particles)
	muzzle_particles.emitting = true

	# 4. Impact burst particles (if ray hit something)
	var impact_particles = CPUParticles2D.new()
	impact_particles.global_position = end
	impact_particles.amount = 8
	impact_particles.lifetime = 0.3
	impact_particles.explosiveness = 1.0
	impact_particles.spread = 180.0
	impact_particles.gravity = Vector2(0, 50)
	impact_particles.initial_velocity_min = 50.0
	impact_particles.initial_velocity_max = 120.0
	impact_particles.scale_amount_min = 1.5
	impact_particles.scale_amount_max = 3.0
	impact_particles.color = laser_color
	effect.add_child(impact_particles)
	impact_particles.emitting = true

	# Fade out beam and light dynamically using Tweens
	var tween = effect.create_tween()
	tween.tween_property(outer_line, "width", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(inner_line, "width", 0.0, 0.2)
	tween.parallel().tween_property(light, "energy", 0.0, 0.25)
	tween.tween_callback(effect.queue_free)

func take_damage(_amount: int) -> void:
	if is_time_reversing:
		return

	is_time_reversing = true

	if main_collision:
		main_collision.set_deferred("disabled", true)

	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		
	# Hide animated sprite
	if animated_sprite:
		animated_sprite.visible = false
		
	# Find ground position
	var ground_local_pos = Vector2(0, 0)
	var raycast = RayCast2D.new()
	raycast.target_position = Vector2(0, 500)
	raycast.exclude_parent = true
	raycast.collision_mask = 1
	add_child(raycast)
	raycast.force_raycast_update()
	if raycast.is_colliding():
		ground_local_pos = to_local(raycast.get_collision_point())
		ground_local_pos.x = animated_sprite.position.x if animated_sprite else 0.0
		ground_local_pos.y -= 8.0
	raycast.queue_free()
		
	if not scrap_sprite:
		scrap_sprite = Sprite2D.new()
		scrap_sprite.texture = SCRAP_TEXTURE
		scrap_sprite.position = ground_local_pos
		scrap_sprite.scale = Vector2(4.5, 4.5)
		add_child(scrap_sprite)
	else:
		scrap_sprite.position = ground_local_pos
		scrap_sprite.visible = true

func revive() -> void:
	is_time_reversing = false
	was_revived_in_reverse = true
	shoot_timer = shoot_interval # Reset firing timer upon revival
	
	_play_sfx(SFX_REVIVE)

	if revive_label:
		revive_label.visible = false
		
	if scrap_sprite:
		scrap_sprite.visible = false
	if animated_sprite:
		animated_sprite.visible = true
		animated_sprite.play("idle")

func _fully_restore() -> void:
	was_revived_in_reverse = false

	if main_collision:
		main_collision.set_deferred("disabled", false)

	if hurtbox:
		hurtbox.set_deferred("monitoring", true)
		
	if scrap_sprite:
		scrap_sprite.visible = false
	if animated_sprite:
		animated_sprite.visible = true
		animated_sprite.play("idle")

func _on_zone_entered(body: Node2D) -> void:
	if body.name.contains("Player"):
		player_in_zone = true

func _on_zone_exited(body: Node2D) -> void:
	if body.name.contains("Player"):
		player_in_zone = false
		if revive_label:
			revive_label.visible = false

func _on_hurtbox_entered(body: Node2D) -> void:
	if not is_dead and not is_time_reversing and not was_revived_in_reverse:
		if body.has_method("die"):
			body.die()

func revive_enemy() -> void:
	is_dead = false
	is_time_reversing = false
	was_revived_in_reverse = false
	time_elapsed = 0.0
	shoot_timer = shoot_interval
	position = spawn_position

	if main_collision:
		main_collision.set_deferred("disabled", false)

	if hurtbox:
		hurtbox.set_deferred("monitoring", true)
		
	if scrap_sprite:
		scrap_sprite.visible = false
	if animated_sprite:
		animated_sprite.visible = true
		animated_sprite.play("idle")
