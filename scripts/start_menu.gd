extends Node2D

@onready var transition_overlay: ColorRect = $TransitionOverlay
@onready var poppy_idle: AnimatedSprite2D = $CampfireScene/PoppyIdle
@onready var bg_music: AudioStreamPlayer = $BGMusic
@onready var settings_panel: Control = $UI/SettingsPanel
@onready var volume_slider: HSlider = $UI/SettingsPanel/MarginContainer/VBoxContainer/VolumeRow/VolumeSlider
@onready var volume_value_label: Label = $UI/SettingsPanel/MarginContainer/VBoxContainer/VolumeRow/VolumeValueLabel
@onready var fullscreen_check: CheckButton = $UI/SettingsPanel/MarginContainer/VBoxContainer/FullscreenRow/FullscreenToggle

func _ready() -> void:
	if get_tree().root.has_node("SceneTransition"):
		var st = get_node("/root/SceneTransition")
		st.is_timer_running = false
		st.elapsed_time = 0.0
		st.is_reversing = false

	transition_overlay.color = Color(0, 0, 0, 1)
	var tween = create_tween()
	tween.tween_property(transition_overlay, "color", Color(0, 0, 0, 0), 1.2)

	if poppy_idle:
		poppy_idle.play("idle")

	var campfire = get_node_or_null("CampfireScene/Campfire")
	if campfire:
		campfire.play("default")

	settings_panel.visible = false

	var current_linear = db_to_linear(AudioServer.get_bus_volume_db(0))
	var current_percent = clamp(current_linear * 100.0, 0.0, 100.0)
	volume_slider.value = current_percent
	volume_value_label.text = str(int(current_percent)) + "%"

	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_update_fullscreen_label(fullscreen_check.button_pressed)

func _on_play_pressed() -> void:
	_fade_and_go("res://scene/level1.tscn")

func _on_settings_pressed() -> void:
	settings_panel.modulate.a = 0
	settings_panel.visible = true
	var tween = create_tween()
	tween.tween_property(settings_panel, "modulate:a", 1.0, 0.2)

func _on_close_settings_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(settings_panel, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func(): settings_panel.visible = false)

func _on_volume_slider_changed(value: float) -> void:
	if value <= 0.0:
		AudioServer.set_bus_volume_db(0, -80.0)
	else:
		var db = linear_to_db(value / 100.0)
		AudioServer.set_bus_volume_db(0, db)
	volume_value_label.text = str(int(value)) + "%"

func _on_fullscreen_toggled(toggled: bool) -> void:
	if toggled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_update_fullscreen_label(toggled)

func _update_fullscreen_label(is_on: bool) -> void:
	fullscreen_check.text = "ON" if is_on else "OFF"

func _on_bg_music_finished() -> void:
	bg_music.play()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _fade_and_go(target_scene: String) -> void:
	var vbox = get_node_or_null("UI/VBoxContainer")
	if vbox:
		for child in vbox.get_children():
			if child is Button:
				child.disabled = true

	if get_tree().root.has_node("SceneTransition"):
		var st = get_node("/root/SceneTransition")
		st.elapsed_time = 0.0
		st.is_reversing = false
		st.is_timer_running = false

	bg_music.stop()

	var tween = create_tween()
	tween.tween_property(transition_overlay, "color", Color(0, 0, 0, 1), 0.8)
	tween.tween_callback(func(): get_tree().change_scene_to_file(target_scene))
