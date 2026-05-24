extends Node2D

@onready var transition_overlay: ColorRect = $TransitionOverlay
@onready var poppy_idle: AnimatedSprite2D = $CampfireScene/PoppyIdle
@onready var bg_music: AudioStreamPlayer = $BGMusic
@onready var settings_panel: Control = $UI/SettingsPanel
@onready var volume_slider: HSlider = $UI/SettingsPanel/MarginContainer/VBoxContainer/VolumeRow/VolumeSlider
@onready var volume_value_label: Label = $UI/SettingsPanel/MarginContainer/VBoxContainer/VolumeRow/VolumeValueLabel
@onready var fullscreen_check: CheckButton = $UI/SettingsPanel/MarginContainer/VBoxContainer/FullscreenRow/FullscreenToggle

func _ready() -> void:
	# Ensure controller inputs are mapped to standard UI actions
	_add_joypad_button_to_action("ui_up", JOY_BUTTON_DPAD_UP)
	_add_joypad_motion_to_action("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	
	_add_joypad_button_to_action("ui_down", JOY_BUTTON_DPAD_DOWN)
	_add_joypad_motion_to_action("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	
	_add_joypad_button_to_action("ui_left", JOY_BUTTON_DPAD_LEFT)
	_add_joypad_motion_to_action("ui_left", JOY_AXIS_LEFT_X, -1.0)
	
	_add_joypad_button_to_action("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joypad_motion_to_action("ui_right", JOY_AXIS_LEFT_X, 1.0)
	
	_add_joypad_button_to_action("ui_accept", JOY_BUTTON_A)
	_add_joypad_button_to_action("ui_cancel", JOY_BUTTON_B)

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

	# Dynamic focus styling overrides so selected buttons are visible
	for btn in [$UI/VBoxContainer/PlayButton, $UI/VBoxContainer/SettingsButton, $UI/VBoxContainer/QuitButton]:
		if btn:
			var hover_style = btn.get_theme_stylebox("hover")
			if hover_style:
				btn.add_theme_stylebox_override("focus", hover_style)

	var close_btn = $UI/SettingsPanel/MarginContainer/VBoxContainer/CloseButton
	if close_btn:
		var hover_style = close_btn.get_theme_stylebox("hover")
		if hover_style:
			close_btn.add_theme_stylebox_override("focus", hover_style)

	if fullscreen_check:
		var hover_style = fullscreen_check.get_theme_stylebox("hover")
		if hover_style:
			fullscreen_check.add_theme_stylebox_override("focus", hover_style)

	# Robust focus neighbor configurations for the Settings Panel
	if volume_slider and fullscreen_check and close_btn:
		volume_slider.focus_neighbor_bottom = fullscreen_check.get_path()
		fullscreen_check.focus_neighbor_top = volume_slider.get_path()
		fullscreen_check.focus_neighbor_bottom = close_btn.get_path()
		close_btn.focus_neighbor_top = fullscreen_check.get_path()

	# Focus PlayButton initially (deferred by one frame to ensure UI is ready)
	await get_tree().process_frame
	var play_btn = $UI/VBoxContainer/PlayButton
	if play_btn:
		play_btn.grab_focus()

func _on_play_pressed() -> void:
	_fade_and_go("res://scene/level1.tscn")

func _on_settings_pressed() -> void:
	settings_panel.modulate.a = 0
	settings_panel.visible = true
	var tween = create_tween()
	tween.tween_property(settings_panel, "modulate:a", 1.0, 0.2)
	if volume_slider:
		volume_slider.grab_focus()

func _on_close_settings_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(settings_panel, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		settings_panel.visible = false
		var settings_btn = $UI/VBoxContainer/SettingsButton
		if settings_btn:
			settings_btn.grab_focus()
	)

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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if settings_panel and settings_panel.visible:
			get_viewport().set_input_as_handled()
			_on_close_settings_pressed()
			
	# Fallback safety: if they press any UI action but nothing is focused, refocus the menu
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
		if get_viewport().gui_get_focus_owner() == null:
			if settings_panel and settings_panel.visible:
				if volume_slider:
					volume_slider.grab_focus()
			else:
				var play_btn = $UI/VBoxContainer/PlayButton
				if play_btn:
					play_btn.grab_focus()

func _add_joypad_button_to_action(action_name: String, button_index: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		
	var already_exists = false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and event.button_index == button_index:
			already_exists = true
			break
		
	if not already_exists:
		var new_event = InputEventJoypadButton.new()
		new_event.button_index = button_index
		InputMap.action_add_event(action_name, new_event)

func _add_joypad_motion_to_action(action_name: String, axis: int, value: float) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		
	var already_exists = false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadMotion and event.axis == axis and sign(event.axis_value) == sign(value):
			already_exists = true
			break
		
	if not already_exists:
		var new_event = InputEventJoypadMotion.new()
		new_event.axis = axis
		new_event.axis_value = value
		InputMap.action_add_event(action_name, new_event)
