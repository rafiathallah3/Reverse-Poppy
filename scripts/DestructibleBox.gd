extends StaticBody2D

var is_destroyed: bool = false
var spawn_position: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

func _ready() -> void:
	add_to_group("destructible")
	spawn_position = position

func get_center_global_position() -> Vector2:
	if collision_shape:
		return global_position + collision_shape.position
	return global_position

func take_explosion_damage() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	_spawn_break_effect()
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if sprite:
		sprite.visible = false

func revive_box() -> void:
	is_destroyed = false
	position = spawn_position
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	if sprite:
		sprite.visible = true

func _spawn_break_effect() -> void:
	var particles = CPUParticles2D.new()
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.amount = 12
	particles.explosiveness = 1.0
	particles.one_shot = true        
	particles.spread = 180.0
	particles.gravity = Vector2(0, 200)
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 160.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color(0.8, 0.5, 0.2, 1.0)
	particles.emitting = true
	await get_tree().create_timer(1.5).timeout
	particles.queue_free()
