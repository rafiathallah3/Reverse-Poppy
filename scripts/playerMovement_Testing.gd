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
var is_dying: bool = false

const BULLET_SCRIPT = preload("res://scripts/bullet.gd")
@export var shoot_cooldown: float = 0.3
var shoot_timer: float = 0.0

const GRENADE_SCRIPT = preload("res://scripts/grenade.gd")
@export var grenade_cooldown: float = 0.6
var grenade_timer: float = 0.0

var facing_direction: float = 1.0

var spawn_position: Vector2

@export var max_bullets: int = 10
@export var max_grenades: int = 3

var bullets: int = max_bullets
var grenades: int = max_grenades

func _ready() -> void:
	_add_key_to_action("move_left", KEY_LEFT)
	_add_key_to_action("move_right", KEY_RIGHT)
	_add_key_to_action("jump", KEY_UP)
	
	_add_joypad_button_to_action("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joypad_motion_to_action("move_left", JOY_AXIS_LEFT_X, -1.0)
	
	_add_joypad_button_to_action("move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joypad_motion_to_action("move_right", JOY_AXIS_LEFT_X, 1.0)
	
	_add_joypad_button_to_action("jump", JOY_BUTTON_A)
	_add_joypad_button_to_action("jump", JOY_BUTTON_DPAD_UP)
	
	_add_key_to_action("shoot", KEY_ENTER)
	_add_key_to_action("shoot", KEY_KP_ENTER)
	_add_joypad_button_to_action("shoot", JOY_BUTTON_X)
	_add_joypad_button_to_action("shoot", JOY_BUTTON_RIGHT_SHOULDER)
	
	_add_key_to_action("grenade", KEY_F)
	_add_joypad_button_to_action("grenade", JOY_BUTTON_B)
	_add_joypad_button_to_action("grenade", JOY_BUTTON_Y)
	_add_joypad_button_to_action("grenade", JOY_BUTTON_LEFT_SHOULDER)
	
	_add_key_to_action("move_down", KEY_DOWN)
	_add_key_to_action("move_down", KEY_S)
	_add_joypad_button_to_action("move_down", JOY_BUTTON_DPAD_DOWN)
	_add_joypad_motion_to_action("move_down", JOY_AXIS_LEFT_Y, 1.0)
	
	spawn_position = global_position
	
	# Dynamically register the death animation if not already present
	if animated_sprite and animated_sprite.sprite_frames:
		var sf = animated_sprite.sprite_frames
		if not sf.has_animation("death"):
			sf.add_animation("death")
			sf.set_animation_loop("death", false)
			
			var death_tex = load("res://assets/Poppydeath.png")
			if death_tex:
				for y in range(2):
					for x in range(2):
						var atlas = AtlasTexture.new()
						atlas.atlas = death_tex
						atlas.region = Rect2(x * 64, y * 64, 64, 64)
						sf.add_frame("death", atlas)
			else:
				print("Failed to load Poppydeath.png")
		sf.set_animation_speed("death", 16.0)



func _add_key_to_action(action_name: String, keycode: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	
	var already_exists = false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			already_exists = true
			break
	
	if not already_exists:
		var new_event = InputEventKey.new()
		new_event.physical_keycode = keycode
		InputMap.action_add_event(action_name, new_event)

func _add_joypad_button_to_action(action_name: String, button_index: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		
	var already_exists = false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and event.button_index == button_index:
			already_exists = true
			break
		
	if not already_exists:
		var new_event = InputEventJoypadButton.new()
		new_event.button_index = button_index
		InputMap.action_add_event(action_name, new_event)

func _add_joypad_motion_to_action(action_name: String, axis: int, value: float) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		
	var already_exists = false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadMotion and event.axis == axis and sign(event.axis_value) == sign(value):
			already_exists = true
			break
		
	if not already_exists:
		var new_event = InputEventJoypadMotion.new()
		new_event.axis = axis
		new_event.axis_value = value
		InputMap.action_add_event(action_name, new_event)

func _physics_process(delta):
	if is_paused:
		return
		
	if shoot_timer > 0.0:
		shoot_timer -= delta
		
	if grenade_timer > 0.0:
		grenade_timer -= delta

	if is_on_floor() and Input.is_action_just_pressed("move_down"):
		position.y += 2.0

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
	set_physics_process(not paused)
	if paused:
		velocity = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if is_paused:
		return

	if event.is_action_pressed("shoot"):
		shoot()
	elif event.is_action_pressed("grenade"):
		throw_grenade()

func shoot() -> void:
	var st = get_node_or_null("/root/SceneTransition")
	if st and st.is_reversing:
		return

	if bullets <= 0:
		print("Out of bullets!")
		return
		
	if shoot_timer > 0.0:
		return
		
	shoot_timer = shoot_cooldown
	bullets -= 1 
	
	var bullet = Area2D.new()
	bullet.set_script(BULLET_SCRIPT)
	bullet.direction = Vector2(facing_direction, 0.0)
	get_parent().add_child(bullet)
	bullet.global_position = global_position + Vector2(facing_direction * 40.0, 0.0)

func throw_grenade() -> void:
	var st = get_node_or_null("/root/SceneTransition")
	if st and st.is_reversing:
		return
		
	if grenades <= 0:
		print("No grenades left!")
		return
		
	grenade_timer = grenade_cooldown
	grenades -= 1 
	
	var grenade = Area2D.new()
	grenade.set_script(GRENADE_SCRIPT)
	grenade.velocity = Vector2(facing_direction * grenade.speed_x, grenade.speed_y)
	get_parent().add_child(grenade)
	grenade.global_position = global_position

func die() -> void:
	if is_dying:
		return
	is_dying = true
	is_paused = true
	velocity = Vector2.ZERO
	
	if animated_sprite:
		animated_sprite.play("death")
		await animated_sprite.animation_finished
	else:
		await get_tree().create_timer(0.2).timeout
		
	var st = get_node_or_null("/root/SceneTransition")
	if st:
		await st.fade_to_black(0.4)
	else:
		await get_tree().create_timer(0.4).timeout
		
	global_position = spawn_position
	velocity = Vector2.ZERO
	
	if animated_sprite:
		animated_sprite.play("idle")
	
	await get_tree().create_timer(0.1).timeout
	
	if st:
		await st.fade_from_black(0.4)
	else:
		await get_tree().create_timer(0.4).timeout
		
	is_paused = false
	is_dying = false
