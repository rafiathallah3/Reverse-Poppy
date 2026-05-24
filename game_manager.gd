extends Node2D

@onready var ui_canvas: CanvasLayer = $TimeUiCanvas
@onready var time_slider: HSlider = $TimeUiCanvas/ControlPanel/VBoxContainer/SliderRow/HSlider
@onready var time_label: Label = $TimeUiCanvas/ControlPanel/VBoxContainer/SliderRow/ValueLabel
@onready var resume_btn: Button = $TimeUiCanvas/ControlPanel/VBoxContainer/ButtonsRow/ResumeButton
@onready var activate_btn: Button = $TimeUiCanvas/ControlPanel/VBoxContainer/ButtonsRow/ActivateButton

@onready var bg_sky: TextureRect = get_node_or_null("BackgroundCanvas/SkyBackground")
@onready var bg_particles: CPUParticles2D = get_node_or_null("BackgroundCanvas/TimeDustParticles")
@onready var glitch_overlay: ColorRect = get_node_or_null("TimeGlitchCanvas/GlitchOverlay")

var current_slider_offset_ms: float = 0.0
var is_scrubbing: bool = false

func _ready() -> void:
	ui_canvas.visible = false
	if glitch_overlay:
		glitch_overlay.visible = false
	
	time_slider.value_changed.connect(_on_slider_value_changed)
	time_slider.drag_started.connect(_on_slider_drag_started)
	time_slider.drag_ended.connect(_on_slider_drag_ended)
	resume_btn.pressed.connect(_on_resume_pressed)
	
	activate_btn.text = "RESET TO PRESENT"
	activate_btn.pressed.connect(_on_reset_pressed)
	
	if bg_sky:
		bg_sky.modulate = Color(0.12, 0.12, 0.2, 1.0)

func _on_slider_value_changed(value: float) -> void:
	current_slider_offset_ms = value
	
	var seconds = value / 1000.0
	time_label.text = "%.1f sec" % seconds
	
	# Dynamic Background Sky Modulate
	if bg_sky:
		var t = clamp(value / 5000.0, 0.0, 1.0)
		bg_sky.modulate = Color(0.12, 0.12, 0.2, 1.0).lerp(Color(0.45, 0.65, 1.0, 1.0), t)
		
	# Dynamic Background Particles Speed & Direction
	if bg_particles:
		if is_scrubbing and value > 0:
			bg_particles.speed_scale = -1.0 - (value / 1000.0)
		else:
			bg_particles.speed_scale = 0.0
			
	# Dynamic Fullscreen CRT / Glitch Overlay (scales while active)
	if glitch_overlay and glitch_overlay.visible:
		var t = clamp(value / 5000.0, 0.0, 1.0)
		glitch_overlay.modulate.a = 0.4 + (t * 0.3)
			
	var objects = get_tree().get_nodes_in_group("rewindable_objects")
	for obj in objects:
		if obj.has_method("scrub_time"):
			obj.scrub_time(current_slider_offset_ms)

func _on_reset_pressed() -> void:
	time_slider.value = 0.0

func _on_slider_drag_started() -> void:
	is_scrubbing = true

func _on_slider_drag_ended() -> void:
	is_scrubbing = false
	if bg_particles:
		bg_particles.speed_scale = 0.0

func _on_resume_pressed() -> void:
	var objects = get_tree().get_nodes_in_group("rewindable_objects")
	for obj in objects:
		if obj.has_method("commit_scrubbed_state"):
			obj.commit_scrubbed_state(current_slider_offset_ms)
		if obj.has_method("set_paused"):
			obj.set_paused(false)
			
	ui_canvas.visible = false
	if glitch_overlay:
		glitch_overlay.visible = false
		
	# Reset background modulations and particles to their normal present-time state on resume
	if bg_sky:
		bg_sky.modulate = Color(0.12, 0.12, 0.2, 1.0)
	if bg_particles:
		bg_particles.speed_scale = 1.0


func on_player_entered_trigger() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var objects = get_tree().get_nodes_in_group("rewindable_objects")
	for obj in objects:
		if obj.has_method("set_paused"):
			obj.set_paused(true)
			
	time_slider.value = 0.0
	current_slider_offset_ms = 0.0
	time_label.text = "0.0 sec"
	
	ui_canvas.visible = true
	if glitch_overlay:
		glitch_overlay.visible = true
		glitch_overlay.modulate.a = 0.4
