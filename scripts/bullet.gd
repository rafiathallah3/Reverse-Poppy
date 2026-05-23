extends Area2D

@export var speed: float = 850.0
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	# Add to groups
	add_to_group("bullets")
	
	# Create a visual representation: a modern, glowing neon red laser beam
	var rect = ColorRect.new()
	rect.color = Color(1.0, 0.0, 0.1, 1.0) # Vivid neon red
	rect.size = Vector2(36, 10) # Larger size for high visibility
	rect.position = -rect.size / 2.0 # Center the rect at bullet's position
	add_child(rect)
	
	# Add a subtle inner bright core to make it look extremely premium
	var core_rect = ColorRect.new()
	core_rect.color = Color(1.0, 0.9, 0.9, 1.0) # Bright rose-white core
	core_rect.size = Vector2(28, 4) # Thicker inner core
	core_rect.position = -core_rect.size / 2.0
	add_child(core_rect)
	
	# Create a physics collision shape matching the laser dimensions
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = rect.size
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Connect the body entered signal for collision detection
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# Move the bullet forward
	position += direction * speed * delta
	
	# Countdown lifetime and remove if expired
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	# Ignore collisions with the Player or other bullets
	if body.name.contains("Player") or body.is_in_group("bullets"):
		return
		
	# Spawn a beautiful premium impact burst
	_spawn_impact_effect()
	
	# If the hit body has a method for taking damage, we can call it (future scalability)
	if body.has_method("take_damage"):
		body.take_damage(1)
		
	# Destroy the bullet
	queue_free()

func _spawn_impact_effect() -> void:
	var effect = Node2D.new()
	effect.global_position = global_position
	get_parent().add_child(effect)
	
	# Create an expanding shockwave ring
	var line = Line2D.new()
	line.points = _get_circle_points(12.0)
	line.width = 4.0
	line.default_color = Color(1.0, 0.0, 0.1, 0.9) # Neon red glowing impact
	effect.add_child(line)
	
	# Add an inner expanding ring
	var inner_line = Line2D.new()
	inner_line.points = _get_circle_points(7.0)
	inner_line.width = 2.0
	inner_line.default_color = Color(1.0, 0.9, 0.9, 1.0) # Bright core impact
	effect.add_child(inner_line)
	
	# Animate the shockwave using a smooth Tween
	var tween = effect.create_tween()
	tween.tween_property(line, "scale", Vector2(1.8, 1.8), 0.15)
	tween.parallel().tween_property(line, "default_color:a", 0.0, 0.15)
	tween.parallel().tween_property(inner_line, "scale", Vector2(2.2, 2.2), 0.15)
	tween.parallel().tween_property(inner_line, "default_color:a", 0.0, 0.15)
	tween.tween_callback(effect.queue_free)

func _get_circle_points(radius: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	var steps = 12
	for i in range(steps + 1):
		var angle = i * TAU / steps
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
