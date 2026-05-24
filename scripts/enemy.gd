extends CharacterBody2D

@export var float_amplitude: float = 5.0
@export var float_speed: float = 5.5

var spawn_position: Vector2 = Vector2.ZERO
var time_elapsed: float = 0.0

var is_dead: bool = false
var is_time_reversing: bool = false    
var was_revived_in_reverse: bool = false  
var player_in_zone: bool = false

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

func revive() -> void:
	is_time_reversing = false
	was_revived_in_reverse = true  


	if revive_label:
		revive_label.visible = false

func _fully_restore() -> void:
	was_revived_in_reverse = false

	if main_collision:
		main_collision.set_deferred("disabled", false)

	if hurtbox:
		hurtbox.set_deferred("monitoring", true)


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
