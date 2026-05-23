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
	
	# Create a subtle glowing light for the enemy to make them slightly bright in the dark
	var light = PointLight2D.new()
	light.name = "EnemyLight"
	light.color = Color(0.85, 0.3, 0.95, 1.0) # Soft purple/pink glow matching their style
	light.energy = 2
	light.texture_scale = 5.0 # Moderate aura size
	
	# Generate a radial gradient texture programmatically
	var grad = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(0.0, 0.0, 0.0, 0.0)])
	
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.85, 0.85)
	grad_tex.width = 64
	grad_tex.height = 64
	
	light.texture = grad_tex
	add_child(light)

func _physics_process(delta: float) -> void:
	# Smooth sinusoidal floating motion — no gravity
	time_elapsed += delta
	position.x = spawn_position.x + sin(time_elapsed * float_speed * TAU) * float_amplitude

func take_damage(_amount: int) -> void:
	_spawn_death_effect()
	queue_free()

func _spawn_death_effect() -> void:
	var effect = Node2D.new()
	get_parent().add_child(effect)
	effect.global_position = global_position

	# Create multiple expanding rings for a dramatic death burst
	var colors = [
		Color(0.85, 0.15, 0.95, 0.9), # Purple outer ring
		Color(1.0, 0.3, 0.5, 0.9), # Pink middle ring
		Color(1.0, 1.0, 1.0, 1.0), # White inner flash
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


func _on_hitbox_to_hurt_player_body_entered(body: Node2D) -> void:
	if body.has_method("die"):
		body.die()
