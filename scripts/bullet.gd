extends Area2D

@export var speed: float = 850.0
@export var lifetime: float = 2.0

var direction: Vector2 = Vector2.RIGHT

# Time Rewind variables
var is_paused: bool = false
var history: Array = []
var max_history_duration: float = 5.0 # Max history duration to match slider (5 sec)
var current_recording_time: float = 0.0

var laser_rect: ColorRect
var laser_core: ColorRect

func _ready() -> void:
	# Add to groups
	add_to_group("bullets")
	add_to_group("rewindable_objects")
	
	# Create a visual representation: a modern, glowing neon red laser beam
	laser_rect = ColorRect.new()
	laser_rect.color = Color(1.0, 0.0, 0.1, 1.0) # Vivid neon red
	laser_rect.size = Vector2(36, 10) # Larger size for high visibility
	laser_rect.position = -laser_rect.size / 2.0 # Center the rect at bullet's position
	add_child(laser_rect)
	
	# Add a subtle inner bright core to make it look extremely premium
	laser_core = ColorRect.new()
	laser_core.color = Color(1.0, 0.9, 0.9, 1.0) # Bright rose-white core
	laser_core.size = Vector2(28, 4) # Thicker inner core
	laser_core.position = -laser_core.size / 2.0
	add_child(laser_core)
	
	# Create a physics collision shape matching the laser dimensions
	var collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = laser_rect.size
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Connect the body entered signal for collision detection
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if is_paused:
		return
		
	# Move the bullet forward
	position += direction * speed * delta
	
	# Record position and lifetime history
	current_recording_time += delta
	history.append({
		"time": current_recording_time,
		"pos": position,
		"lifetime": lifetime
	})
	
	# Limit history length
	while history.size() > 0 and (current_recording_time - history[0]["time"]) > max_history_duration:
		history.remove_at(0)
		
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

func set_paused(paused: bool) -> void:
	is_paused = paused
	if laser_rect:
		if paused:
			laser_rect.color = Color(0.0, 0.8, 1.0, 1.0) # Tint neon cyan when paused/rewinding
		else:
			laser_rect.color = Color(1.0, 0.0, 0.1, 1.0) # Restore neon red

func scrub_time(offset_ms: float) -> void:
	if history.size() == 0:
		return
		
	var target_time = current_recording_time - (offset_ms / 1000.0)
	
	var closest_entry = history[0]
	var min_diff = abs(closest_entry["time"] - target_time)
	
	for entry in history:
		var diff = abs(entry["time"] - target_time)
		if diff < min_diff:
			min_diff = diff
			closest_entry = entry
			
	position = closest_entry["pos"]
	lifetime = closest_entry["lifetime"]

func commit_scrubbed_state(offset_ms: float) -> void:
	if history.size() == 0:
		return
		
	var target_time = current_recording_time - (offset_ms / 1000.0)
	
	var new_history = []
	for entry in history:
		if entry["time"] <= target_time:
			new_history.append(entry)
			
	history = new_history
	if history.size() > 0:
		current_recording_time = history[history.size() - 1]["time"]
	else:
		current_recording_time = 0.0
