extends AnimatableBody2D

@export var point_a: Node2D
@export var point_b: Node2D
@export var speed: float = 100.0
@export var wait_time: float = 0.5

var target_point: Node2D
var wait_timer: float = 0.0
var moving_to_b: bool = true

var is_paused: bool = false

# Time Rewind History
var history: Array = []
var max_history_duration: float = 3.0
var current_recording_time: float = 0.0

func _ready() -> void:
	add_to_group("moving_platforms")
	add_to_group("rewindable_objects")
	if point_a:
		global_position = point_a.global_position
		target_point = point_b
	else:
		target_point = point_b

func _physics_process(delta: float) -> void:
	if not point_a or not point_b:
		return
		
	if is_paused:
		set_physics_process(false)
		return
		
	current_recording_time += delta
	history.append({
		"time": current_recording_time,
		"pos": global_position,
		"moving_to_b": moving_to_b,
		"wait_timer": wait_timer
	})
	
	while history.size() > 0 and (current_recording_time - history[0]["time"]) > max_history_duration:
		history.remove_at(0)
		
	if wait_timer > 0.0:
		wait_timer -= delta
		return
		
	var current_target = point_b if moving_to_b else point_a
	var target_pos = current_target.global_position
	var distance = global_position.distance_to(target_pos)
	
	if distance > 1.0:
		var step = speed * delta
		if step >= distance:
			global_position = target_pos
			_arrive_at_destination()
		else:
			global_position = global_position.move_toward(target_pos, step)
	else:
		_arrive_at_destination()

func _arrive_at_destination() -> void:
	wait_timer = wait_time
	moving_to_b = !moving_to_b

func set_paused(paused: bool) -> void:
	is_paused = paused
	set_physics_process(not paused)

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
			
	global_position = closest_entry["pos"]
	moving_to_b = closest_entry["moving_to_b"]
	wait_timer = closest_entry["wait_timer"]

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
