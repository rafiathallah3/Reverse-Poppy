extends CanvasLayer

var is_paused: bool = false

# Referensi node — dibuat manual di _ready()
var _panel:          PanelContainer
var _settings_panel: PanelContainer
var _vol_slider:     HSlider
var _vol_label:      Label
var _fs_toggle:      CheckButton

# ── Style helpers ─────────────────────────────
func _make_panel_style(bg: Color, border: Color, radius: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left   = 2
	s.border_width_top    = 2
	s.border_width_right  = 2
	s.border_width_bottom = 2
	s.border_color = border
	s.set_corner_radius_all(radius)
	return s

func _make_btn_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left   = 2
	s.border_width_top    = 2
	s.border_width_right  = 2
	s.border_width_bottom = 2
	s.border_color = border
	s.set_corner_radius_all(8)
	return s

func _style_button(btn: Button, color: Color = Color(0.9, 0.9, 0.9)) -> void:
	var normal := _make_btn_style(Color(0.1, 0.1, 0.18, 0.9),  Color(0.0, 0.78, 1.0, 0.45))
	var hover  := _make_btn_style(Color(0.15, 0.45, 0.7, 0.95), Color(0.0, 0.9,  1.0, 0.9))
	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_font_size_override("font_size", 18)
	btn.custom_minimum_size = Vector2(216, 44)

# ── Build UI ──────────────────────────────────
func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	layer = 100
	_build_ui()

func _build_ui() -> void:
	# ── Dim overlay ──
	var dim := ColorRect.new()
	dim.name = "DimOverlay"
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# ── Main panel ──
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.add_theme_stylebox_override("panel",
		_make_panel_style(Color(0.05, 0.05, 0.10, 0.93), Color(0.0, 0.78, 1.0, 0.5), 14))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   32)
	margin.add_theme_constant_override("margin_right",  32)
	margin.add_theme_constant_override("margin_top",    28)
	margin.add_theme_constant_override("margin_bottom", 28)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	vbox.add_child(title)

	# Separator space
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(sep)

	# Buttons
	var resume_btn := Button.new()
	resume_btn.text = "▶  Resume"
	_style_button(resume_btn)
	resume_btn.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_btn)

	var settings_btn := Button.new()
	settings_btn.text = "⚙  Settings"
	_style_button(settings_btn)
	settings_btn.pressed.connect(_on_settings_pressed)
	vbox.add_child(settings_btn)

	var restart_btn := Button.new()
	restart_btn.text = "↺  Restart"
	_style_button(restart_btn)
	restart_btn.pressed.connect(_on_restart_pressed)
	vbox.add_child(restart_btn)

	var quit_btn := Button.new()
	quit_btn.text = "✕  Quit to Menu"
	_style_button(quit_btn, Color(1.0, 0.45, 0.45))
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

	# ── Settings sub-panel ──
	_settings_panel = PanelContainer.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.add_theme_stylebox_override("panel",
		_make_panel_style(Color(0.05, 0.05, 0.12, 0.97), Color(0.0, 0.78, 1.0, 0.5), 12))
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_settings_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	# Offset ke kanan panel utama (approx)
	_settings_panel.offset_left  =  170
	_settings_panel.offset_top   = -120
	_settings_panel.offset_right =  170 + 260
	_settings_panel.offset_bottom = -120 + 260
	_settings_panel.visible = false
	add_child(_settings_panel)

	var sm := MarginContainer.new()
	sm.add_theme_constant_override("margin_left",   24)
	sm.add_theme_constant_override("margin_right",  24)
	sm.add_theme_constant_override("margin_top",    20)
	sm.add_theme_constant_override("margin_bottom", 20)
	_settings_panel.add_child(sm)

	var svbox := VBoxContainer.new()
	svbox.add_theme_constant_override("separation", 12)
	sm.add_child(svbox)

	var stitle := Label.new()
	stitle.text = "SETTINGS"
	stitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stitle.add_theme_font_size_override("font_size", 20)
	stitle.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	svbox.add_child(stitle)

	# Volume row
	var vlabel := Label.new()
	vlabel.text = "Volume"
	vlabel.add_theme_font_size_override("font_size", 14)
	vlabel.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	svbox.add_child(vlabel)

	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 8)
	svbox.add_child(vrow)

	_vol_slider = HSlider.new()
	_vol_slider.min_value = 0.0
	_vol_slider.max_value = 100.0
	_vol_slider.step      = 1.0
	_vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vol_slider.custom_minimum_size = Vector2(140, 0)
	_vol_slider.value_changed.connect(_on_volume_slider_changed)
	vrow.add_child(_vol_slider)

	_vol_label = Label.new()
	_vol_label.custom_minimum_size = Vector2(44, 0)
	_vol_label.add_theme_font_size_override("font_size", 14)
	_vol_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vrow.add_child(_vol_label)

	# Fullscreen row
	var fslabel := Label.new()
	fslabel.text = "Fullscreen"
	fslabel.add_theme_font_size_override("font_size", 14)
	fslabel.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	svbox.add_child(fslabel)

	var fsrow := HBoxContainer.new()
	svbox.add_child(fsrow)

	_fs_toggle = CheckButton.new()
	_fs_toggle.add_theme_font_size_override("font_size", 14)
	_fs_toggle.toggled.connect(_on_fullscreen_toggled)
	fsrow.add_child(_fs_toggle)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.add_theme_font_size_override("font_size", 14)
	back_btn.add_theme_stylebox_override("normal", _make_btn_style(Color(0.1,0.1,0.18,0.9), Color(0,0.78,1,0.45)))
	back_btn.add_theme_stylebox_override("hover",  _make_btn_style(Color(0.15,0.45,0.7,0.95), Color(0,0.9,1,0.9)))
	back_btn.custom_minimum_size = Vector2(0, 36)
	back_btn.pressed.connect(_on_close_settings_pressed)
	svbox.add_child(back_btn)

	# ── Sync initial values ──
	var current_linear := db_to_linear(AudioServer.get_bus_volume_db(0))
	_vol_slider.value = clamp(current_linear * 100.0, 0.0, 100.0)
	_vol_label.text   = str(int(_vol_slider.value)) + "%"
	_fs_toggle.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_update_fs_label(_fs_toggle.button_pressed)

	# Hide everything initially
	_panel.visible          = false
	_settings_panel.visible = false
	dim.visible             = false
	dim.name                = "DimOverlay"  # so we can find it later

# ── Input ─────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()

# ── Pause logic ───────────────────────────────
func _toggle_pause() -> void:
	_apply_pause(not is_paused)

func _apply_pause(paused: bool) -> void:
	is_paused = paused
	get_tree().paused = paused

	_panel.visible          = paused
	_settings_panel.visible = false

	var dim := get_node_or_null("DimOverlay")
	if dim:
		dim.visible = paused

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_HIDDEN

	var player := _get_player()
	if player and player.has_method("set_paused"):
		player.set_paused(paused)

# ── Button callbacks ──────────────────────────
func _on_resume_pressed() -> void:
	_apply_pause(false)

func _on_settings_pressed() -> void:
	_settings_panel.modulate.a = 0.0
	_settings_panel.visible    = true
	var tw := create_tween()
	tw.tween_property(_settings_panel, "modulate:a", 1.0, 0.18)

func _on_close_settings_pressed() -> void:
	var tw := create_tween()
	tw.tween_property(_settings_panel, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func(): _settings_panel.visible = false)

func _on_restart_pressed() -> void:
	var current_path := get_tree().current_scene.scene_file_path
	_apply_pause(false)
	var st := get_node_or_null("/root/SceneTransition")
	if st:
		st.elapsed_time     = 0.0
		st.is_reversing     = false
		st.is_timer_running = false
	get_tree().change_scene_to_file(current_path)

func _on_quit_pressed() -> void:
	_apply_pause(false)
	var st := get_node_or_null("/root/SceneTransition")
	if st:
		st.elapsed_time     = 0.0
		st.is_reversing     = false
		st.is_timer_running = false
	get_tree().change_scene_to_file("res://scene/StartMenu.tscn")

# ── Settings callbacks ────────────────────────
func _on_volume_slider_changed(value: float) -> void:
	if value <= 0.0:
		AudioServer.set_bus_volume_db(0, -80.0)
	else:
		AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))
	_vol_label.text = str(int(value)) + "%"

func _on_fullscreen_toggled(toggled: bool) -> void:
	if toggled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_update_fs_label(toggled)

func _update_fs_label(is_on: bool) -> void:
	_fs_toggle.text = "ON" if is_on else "OFF"

# ── Helper ────────────────────────────────────
func _get_player() -> Node:
	var scene := get_tree().current_scene
	if not scene: return null
	var p := scene.get_node_or_null("Player")
	if not p: p = scene.get_node_or_null("Player (Testing)")
	return p
