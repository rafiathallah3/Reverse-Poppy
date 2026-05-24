extends CharacterBody2D

@export var float_amplitude: float = 5.0
@export var float_speed: float = 5.5

var spawn_position: Vector2 = Vector2.ZERO
var time_elapsed: float = 0.0

var is_dead: bool = false
var is_time_reversing: bool = false    
var was_revived_in_reverse: bool = false  
var player_in_zone: bool = false

const SCRAP_TEXTURE = preload("res://assets/Scrap.png")
@onready var SFX_REVIVE = load("res://assets/SFX/revive.mp3")
var scrap_sprite: Sprite2D = null

@onready var revive_label: Label = $ReviveLabel
@onready var revive_zone: Area2D = $ReviveZone
@onready var main_collision: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hitbox_to_hurt_player

func _ready() -> void:
	add_to_group("enemies")
	spawn_position = position

	if revive_label:
		revive_label.visible = false
		revive_label.text = "Press Y to Revive"

	if revive_zone:
		revive_zone.body_entered.connect(_on_zone_entered)
		revive_zone.body_exited.connect(_on_zone_exited)

	if hurtbox:
		hurtbox.body_entered.connect(_on_hurtbox_entered)

func _get_st() -> Node:
	return get_node_or_null("/root/SceneTransition")

func _is_reverse_phase() -> bool:
	var st = _get_st()
	return st != null and st.is_reversing

func _play_sfx(stream: AudioStream) -> void:
	var audio_player = AudioStreamPlayer2D.new()
	audio_player.stream = stream
	audio_player.volume_db = -6.0 # <--- ADD THIS (Cuts volume in half)
	add_child(audio_player)
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)

func _physics_process(delta: float) -> void:
	if is_dead or is_time_reversing or was_revived_in_reverse:
		velocity = Vector2.ZERO
		return

	time_elapsed += delta
	position.x = spawn_position.x + sin(time_elapsed * float_speed * TAU) * float_amplitude

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

func take_damage(_amount: int) -> void:
	if is_time_reversing:
		return

	is_time_reversing = true

	if main_collision:
		main_collision.set_deferred("disabled", true)

	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		
	# Hide animated sprite
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.visible = false
		
	# Find the ground directly underneath the enemy using a temporary RayCast2D
	var ground_local_pos = Vector2(65, 82) # Fallback to original sprite position
	var raycast = RayCast2D.new()
	raycast.target_position = Vector2(0, 500) # Raycast downwards up to 500 pixels
	raycast.exclude_parent = true
	raycast.collision_mask = 1 # Detect solid floors/geometry
	add_child(raycast)
	raycast.force_raycast_update()
	if raycast.is_colliding():
		ground_local_pos = to_local(raycast.get_collision_point())
		# Align Scrap with the center of the enemy X-wise, but put Y on the ground
		ground_local_pos.x = sprite.position.x if sprite else 65.0
		# Offset slightly upwards so the bottom of the scrap sits nicely on the ground
		ground_local_pos.y -= 8.0
	raycast.queue_free()
		
	if not scrap_sprite:
		scrap_sprite = Sprite2D.new()
		scrap_sprite.texture = SCRAP_TEXTURE
		scrap_sprite.position = ground_local_pos
		scrap_sprite.scale = Vector2(4.5, 4.5) # Scale up to make it bigger and prominent
		add_child(scrap_sprite)
	else:
		scrap_sprite.position = ground_local_pos
		scrap_sprite.visible = true

func revive() -> void:
	is_time_reversing = false
	was_revived_in_reverse = true 
	
	_play_sfx(SFX_REVIVE) 

	if revive_label:
		revive_label.visible = false
		
	# Hide Scrap sprite and show animated sprite
	if scrap_sprite:
		scrap_sprite.visible = false
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.visible = true

func _fully_restore() -> void:
	was_revived_in_reverse = false

	if main_collision:
		main_collision.set_deferred("disabled", false)

	if hurtbox:
		hurtbox.set_deferred("monitoring", true)
		
	# Double check visuals are restored
	if scrap_sprite:
		scrap_sprite.visible = false
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.visible = true


func _on_zone_entered(body: Node2D) -> void:
	if body.name.contains("Player"):
		player_in_zone = true

func _on_zone_exited(body: Node2D) -> void:
	if body.name.contains("Player"):
		player_in_zone = false
		if revive_label:
			revive_label.visible = false

func _on_hurtbox_entered(body: Node2D) -> void:
	# Never damage player if: dead, awaiting revival, or revived-but-reverse-ongoing
	if not is_dead and not is_time_reversing and not was_revived_in_reverse:
		if body.has_method("die"):
			body.die()

func _spawn_death_effect() -> void:
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = global_position

func revive_enemy() -> void:
	is_dead = false
	is_time_reversing = false
	was_revived_in_reverse = false
	time_elapsed = 0.0
	position = spawn_position

	if main_collision:
		main_collision.set_deferred("disabled", false)

	if hurtbox:
		hurtbox.set_deferred("monitoring", true)
		
	if scrap_sprite:
		scrap_sprite.visible = false
	var sprite = get_node_or_null("AnimatedSprite2D")
	if sprite:
		sprite.visible = true
