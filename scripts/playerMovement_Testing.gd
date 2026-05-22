extends CharacterBody2D

@export var SPEED = 250.0
@export var ACCELERATION = 1800.0  
@export var FRICTION = 2200.0     

@export var JUMP_VELOCITY = -450.0
@export var FALL_GRAVITY_MULTIPLIER = 1.6  

@export var COYOTE_DURATION = 0.1      
@export var JUMP_BUFFER_DURATION = 0.1 

var base_gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var coyote_timer = 0.0
var jump_buffer_timer = 0.0

func _physics_process(delta):
	
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
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	move_and_slide()
