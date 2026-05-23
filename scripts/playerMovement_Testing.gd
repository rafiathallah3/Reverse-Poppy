extends CharacterBody2D

@export var SPEED = 250.0
@export var ACCELERATION = 1800.0  
@export var FRICTION = 2200.0     

@export var JUMP_VELOCITY = -450.0
@export var FALL_GRAVITY_MULTIPLIER = 1.6  

@export var COYOTE_DURATION = 0.1      
@export var JUMP_BUFFER_DURATION = 0.1 

var base_gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


var coyote_timer = 0.0
var jump_buffer_timer = 0.0

var is_paused: bool = false

# Shooting System Configuration
const BULLET_SCRIPT = preload("res://scripts/bullet.gd")
@export var shoot_cooldown: float = 0.3

var shoot_timer: float = 0.0
var facing_direction: float = 1.0

func _physics_process(delta):
	if is_paused:
		return
		
	if shoot_timer > 0.0:
		shoot_timer -= delta
		
	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += base_gravity * FALL_GRAVITY_MULTIPLIER * delta
		else:
			velocity.y += base_gravity * delta
		
		coyote_timer -= delta
	else:
		coyote_timer = COYOTE_DURATION 

	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_DURATION

	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0 
		coyote_timer = 0.0    

	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.45 

	var direction = Input.get_axis("move_left", "move_right")
	
	if direction != 0:
		facing_direction = sign(direction)
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	if animated_sprite:
		if direction != 0:
			animated_sprite.flip_h = direction < 0
			animated_sprite.play("walk")
		else:
			animated_sprite.play("idle")

	move_and_slide()

func set_paused(paused: bool) -> void:
	is_paused = paused
	if paused:
		velocity = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if is_paused:
		return
		
	if event.is_action_pressed("shoot"):
		shoot()

func shoot() -> void:
	if shoot_timer > 0.0:
		return
		
	shoot_timer = shoot_cooldown
	
	var bullet = Area2D.new()
	bullet.set_script(BULLET_SCRIPT)
	bullet.direction = Vector2(facing_direction, 0.0)
	get_parent().add_child(bullet)
	bullet.global_position = global_position + Vector2(facing_direction * 40.0, 0.0)
