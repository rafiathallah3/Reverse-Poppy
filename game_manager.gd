extends Node2D

@onready var ui_canvas: CanvasLayer = $TimeUiCanvas
@onready var time_slider: HSlider = $TimeUiCanvas/ControlPanel/VBoxContainer/SliderRow/HSlider
@onready var time_label: Label = $TimeUiCanvas/ControlPanel/VBoxContainer/SliderRow/ValueLabel
@onready var resume_btn: Button = $TimeUiCanvas/ControlPanel/VBoxContainer/ButtonsRow/ResumeButton
@onready var activate_btn: Button = $TimeUiCanvas/ControlPanel/VBoxContainer/ButtonsRow/ActivateButton

var current_slider_offset_ms: float = 0.0

func _ready() -> void:
	print("Apalaahh")
	ui_canvas.visible = false
	
	time_slider.value_changed.connect(_on_slider_value_changed)
	resume_btn.pressed.connect(_on_resume_pressed)
	
	activate_btn.text = "RESET TO PRESENT"
	activate_btn.pressed.connect(_on_reset_pressed)

func _on_slider_value_changed(value: float) -> void:
	current_slider_offset_ms = value
	
	var seconds = value / 1000.0
	time_label.text = "%.1f sec" % seconds
	
	var objects = get_tree().get_nodes_in_group("rewindable_objects")
	for obj in objects:
		if obj.has_method("scrub_time"):
			obj.scrub_time(current_slider_offset_ms)

func _on_reset_pressed() -> void:
	time_slider.value = 0.0

func _on_resume_pressed() -> void:
	var objects = get_tree().get_nodes_in_group("rewindable_objects")
	for obj in objects:
		if obj.has_method("commit_scrubbed_state"):
			obj.commit_scrubbed_state(current_slider_offset_ms)
		if obj.has_method("set_paused"):
			obj.set_paused(false)
			
	ui_canvas.visible = false

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
