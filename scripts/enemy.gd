extends CharacterBody2D

## How far up/down the enemy floats from its spawn point
@export var float_amplitude: float = 120.0
## How fast the enemy bobs up and down (cycles per second)
@export var float_speed: float = 1.5

var spawn_position: Vector2 = Vector2.ZERO
var time_elapsed: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	spawn_position = position

func _physics_process(delta: float) -> void:
	# Smooth sinusoidal floating motion — no gravity
	time_elapsed += delta
	position.y = spawn_position.y + sin(time_elapsed * float_speed * TAU) * float_amplitude

func take_damage(_amount: int) -> void:
	_spawn_death_effect()
	queue_free()

func _spawn_death_effect() -> void:
	var effect = Node2D.new()
	effect.global_position = global_position
	get_parent().add_child(effect)

	# Create multiple expanding rings for a dramatic death burst
	var colors = [
		Color(0.85, 0.15, 0.95, 0.9),  # Purple outer ring
		Color(1.0, 0.3, 0.5, 0.9),     # Pink middle ring
		Color(1.0, 1.0, 1.0, 1.0),     # White inner flash
	]
	var radii = [16.0, 10.0, 5.0]
	var widths = [4.0, 3.0, 2.0]
	var final_scales = [Vector2(3.0, 3.0), Vector2(2.5, 2.5), Vector2(2.0, 2.0)]

	var tween = effect.create_tween()
	for i in range(colors.size()):
		var ring = Line2D.new()
		ring.points = _get_circle_points(radii[i])
		ring.width = widths[i]
		ring.default_color = colors[i]
		effect.add_child(ring)

		tween.parallel().tween_property(ring, "scale", final_scales[i], 0.25)
		tween.parallel().tween_property(ring, "default_color:a", 0.0, 0.25)

	tween.tween_callback(effect.queue_free)

func _get_circle_points(radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	var steps = 16
	for i in range(steps + 1):
		var angle = i * TAU / steps
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
