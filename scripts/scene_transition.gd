extends Node

var elapsed_time: float = 0.0
var is_timer_running: bool = true
var is_finished: bool = false

var is_reversing: bool = false
var is_scrubbing: bool = false
var previous_slider_value: float = 0.0

const GLITCH_SHADER = preload("res://shaders/time_glitch.gdshader")

# UI Nodes
var canvas_layer: CanvasLayer
var timer_panel: PanelContainer
var timer_label: Label
var grenade_label: Label
var bullet_label: Label # ← NEW
var black_overlay: ColorRect
var glitch_overlay: ColorRect
var time_slider: HSlider

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	setup_ui()

func setup_ui() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 128
	canvas_layer.name = "SceneTransitionCanvas"
	add_child(canvas_layer)
	
	black_overlay = ColorRect.new()
	black_overlay.name = "BlackOverlay"
	black_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	black_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(black_overlay)
	
	glitch_overlay = ColorRect.new()
	glitch_overlay.name = "GlitchOverlay"
	glitch_overlay.visible = false
	glitch_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var shader_mat = ShaderMaterial.new()
	shader_mat.shader = GLITCH_SHADER
	glitch_overlay.material = shader_mat
	canvas_layer.add_child(glitch_overlay)
	
	call_deferred("reset_overlay_position")
	
	timer_panel = PanelContainer.new()
	timer_panel.name = "TimerPanel"
	timer_panel.position = Vector2(25, 25)
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.06, 0.06, 0.1, 0.75)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.0, 0.8, 1.0, 0.45)
	style_box.set_corner_radius_all(10)
	timer_panel.add_theme_stylebox_override("panel", style_box)
	
	canvas_layer.add_child(timer_panel)
	
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_top", 8)
	margin_container.add_theme_constant_override("margin_bottom", 8)
	timer_panel.add_child(margin_container)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin_container.add_child(vbox)
	
	timer_label = Label.new()
	timer_label.text = "TIME: 00:00.00"
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vbox.add_child(timer_label)
	
	bullet_label = Label.new() # ← NEW
	bullet_label.text = "BULLETS: 30" # ← NEW
	bullet_label.add_theme_font_size_override("font_size", 16)
	bullet_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	vbox.add_child(bullet_label) # ← NEW (sits between timer and grenades)
	
	grenade_label = Label.new()
	grenade_label.text = "GRENADES: 3"
	grenade_label.add_theme_font_size_override("font_size", 16)
	grenade_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	vbox.add_child(grenade_label)
	
	time_slider = HSlider.new()
	time_slider.max_value = 5.0
	time_slider.step = 0.01
	time_slider.visible = false
	time_slider.value_changed.connect(_on_slider_changed)
	vbox.add_child(time_slider)

func _on_slider_changed(value: float) -> void:
	get_tree().call_group("rewindable_objects", "scrub_time", value * 1000.0)
	update_timer_text_to_val(value)
	
	var objects = get_tree().get_nodes_in_group("rewindable_objects")
	for obj in objects:
		if obj.has_method("scrub_time_absolute"):
			obj.scrub_time_absolute(value)
		elif obj.has_method("scrub_time"):
			var offset_ms = (elapsed_time - value) * 1000.0
			obj.scrub_time(offset_ms)
			
	# Dynamic visuals modulation for Background TimeDustParticles & SkyBackground
	var current_scene = get_tree().current_scene
	if current_scene:
		var bg_particles = current_scene.get_node_or_null("ParticleCanvas/TimeDustParticles")
		if not bg_particles:
			bg_particles = current_scene.get_node_or_null("BackgroundCanvas/TimeDustParticles")
		if bg_particles:
			# Determine scrub direction and speed scale
			var diff = value - previous_slider_value
			if diff < 0.0:
				bg_particles.speed_scale = -2.5 # Scrubbing backwards: move backwards!
			elif diff > 0.0:
				bg_particles.speed_scale = 2.5 # Scrubbing forwards: move forwards!
			else:
				bg_particles.speed_scale = 0.0 # Frozen if slider didn't change
			
		var bg_sky = current_scene.get_node_or_null("BackgroundCanvas/SkyBackground")
		if bg_sky:
			var max_val = time_slider.max_value if time_slider.max_value > time_slider.min_value else 5.0
			var t = clamp((value - time_slider.min_value) / (max_val - time_slider.min_value), 0.0, 1.0) if max_val > time_slider.min_value else 1.0
			bg_sky.modulate = Color(0.12, 0.12, 0.2, 1.0).lerp(Color(0.45, 0.65, 1.0, 1.0), t)
			
	previous_slider_value = value

func reset_overlay_position() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	black_overlay.size = viewport_size
	black_overlay.position = Vector2(0, viewport_size.y)
	if glitch_overlay:
		glitch_overlay.size = viewport_size
		glitch_overlay.position = Vector2.ZERO

func _is_menu_scene() -> bool:
	var current_scene = get_tree().current_scene
	if not current_scene: return true
	var path = current_scene.scene_file_path
	return path.contains("StartMenu") or path.contains("start_menu")

func _process(delta: float) -> void:
	var on_menu = _is_menu_scene()

	if timer_panel:
		timer_panel.visible = not on_menu

	if on_menu:
		is_timer_running = false
		is_reversing = false
		elapsed_time = 0.0
		is_finished = false
		if glitch_overlay:
			glitch_overlay.visible = false
		return

	if not is_timer_running and not is_finished:
		is_timer_running = true

	if is_timer_running:
		elapsed_time += delta
		update_timer_text()
	update_bullet_counter()
	update_grenade_counter()

	# Dynamic particle direction reversal based on is_reversing state
	if not is_scrubbing:
		var current_scene = get_tree().current_scene
		if current_scene:
			var bg_particles = current_scene.get_node_or_null("ParticleCanvas/TimeDustParticles")
			if not bg_particles:
				bg_particles = current_scene.get_node_or_null("BackgroundCanvas/TimeDustParticles")
			if bg_particles:
				if is_reversing:
					bg_particles.speed_scale = 0.0
				else:
					if bg_particles.speed_scale != 1.0:
						bg_particles.speed_scale = 1.0

# ── helper to grab the player from the current scene ──
func _get_player() -> Node:
	var current_scene = get_tree().current_scene
	if not current_scene: return null
	var player = current_scene.get_node_or_null("Player")
	if not player: player = current_scene.get_node_or_null("Player (Testing)")
	return player

func update_timer_text() -> void:
	if not timer_label: return
	var minutes = int(elapsed_time / 60.0)
	var seconds = int(elapsed_time) % 60
	var centiseconds = int((elapsed_time - int(elapsed_time)) * 100)
	timer_label.text = "TIME: %02d:%02d.%02d" % [minutes, seconds, centiseconds]

func update_timer_text_to_val(time_val: float) -> void:
	if not timer_label: return
	var minutes = int(time_val / 60.0)
	var seconds = int(time_val) % 60
	var centiseconds = int((time_val - int(time_val)) * 100)
	timer_label.text = "TIME: %02d:%02d.%02d" % [minutes, seconds, centiseconds]

func update_bullet_counter() -> void: # ← NEW
	if not bullet_label: return
	var player = _get_player()
	if player and "bullets" in player:
		bullet_label.text = "BULLETS: %d" % player.bullets

func update_grenade_counter() -> void:
	if not grenade_label: return
	var player = _get_player()
	if player and "grenades" in player:
		grenade_label.text = "GRENADES: %d" % player.grenades

func start_reverse_sequence() -> void:
	is_reversing = true
	timer_label.add_theme_color_override("font_color", Color(0.9, 0.2, 1.0))
	bullet_label.add_theme_color_override("font_color", Color(0.9, 0.2, 1.0)) # ← NEW
	grenade_label.add_theme_color_override("font_color", Color(0.9, 0.2, 1.0))
	var style_box = timer_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style_box:
		style_box.border_color = Color(0.9, 0.2, 1.0, 0.8)
	time_slider.value = 0.0
	time_slider.visible = true
		
	# Dynamic slider setup based on thrown grenades
	var min_time = 0.0
	var max_time = elapsed_time
	var has_grenade_history = false
	
	var grenades = get_tree().get_nodes_in_group("grenades")
	if grenades.size() > 0:
		var oldest_throw = 999999.0
		var latest_explosion = 0.0
		for g in grenades:
			if g.history.size() > 0:
				has_grenade_history = true
				var g_throw = g.history[0]["time"]
				var g_explode = g.explosion_real_time if g.explosion_real_time > 0 else g.current_recording_time
				if g_throw < oldest_throw:
					oldest_throw = g_throw
				if g_explode > latest_explosion:
					latest_explosion = g_explode
		if has_grenade_history:
			min_time = oldest_throw
			max_time = latest_explosion
			
	if max_time <= min_time:
		max_time = min_time + 5.0
		
	time_slider.min_value = min_time
	time_slider.max_value = max_time
	time_slider.value = max_time
	previous_slider_value = max_time
	time_slider.visible = true
	
	if glitch_overlay:
		glitch_overlay.visible = true
		glitch_overlay.modulate.a = 0.4
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Make LevelFinish visible with premium fade-in animation
	var current_scene = get_tree().current_scene
	if current_scene:
		var level_finish = current_scene.get_node_or_null("LevelFinish")
		if level_finish:
			level_finish.visible = true
			level_finish.monitoring = true
			var visual = level_finish.get_node_or_null("PortalVisual")
			if visual:
				visual.modulate.a = 0.0
				var tween = level_finish.create_tween()
				tween.tween_property(visual, "modulate:a", 0.4, 0.8)

# ── helper: stop battle music di level sebelum pindah scene ──
func _stop_level_music() -> void:
	var current_scene = get_tree().current_scene
	if not current_scene:
		return
	var music = current_scene.get_node_or_null("BattleMusic")
	if music and music.playing:
		music.stop()

func complete_level() -> void:
	_stop_level_music()
	var viewport_size = get_viewport().get_visible_rect().size
	# Pastikan overlay visible, ukuran benar, dan tidak transparan
	black_overlay.size = viewport_size
	black_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	black_overlay.position = Vector2(0, viewport_size.y)
	var tween = create_tween()
	tween.tween_property(black_overlay, "position", Vector2.ZERO, 0.6)
	await tween.finished
	await get_tree().create_timer(0.2).timeout
	
	var current_scene_path = get_tree().current_scene.scene_file_path
	var next_scene_path = ""
	
	var level_number = 0
	var regex = RegEx.new()
	regex.compile("\\d+")
	var result = regex.search(current_scene_path)
	if result:
		level_number = int(result.get_string())
	
	if not is_reversing:
		if current_scene_path.contains("game_manager"):
			next_scene_path = "res://scene/level1.tscn"
		elif level_number >= 3:
			# Level 3 adalah boss stage / level terakhir
			next_scene_path = "res://scene/StartMenu.tscn"
			elapsed_time = 0.0
		else:
			next_scene_path = "res://scene/level" + str(level_number + 1) + ".tscn"
			
	else:
		if level_number == 1:
			next_scene_path = "res://scene/level2.tscn"
			is_reversing = false
			if glitch_overlay:
				glitch_overlay.visible = false
			time_slider.visible = false
			timer_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
			bullet_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
			grenade_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
			var style_box = timer_panel.get_theme_stylebox("panel") as StyleBoxFlat
			if style_box:
				style_box.border_color = Color(0.0, 0.8, 1.0, 0.45)
		else:
			next_scene_path = "res://scene/StartMenu.tscn"
			is_reversing = false
			elapsed_time = 0.0
			time_slider.visible = false
			timer_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
			bullet_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
			grenade_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
			var style_box = timer_panel.get_theme_stylebox("panel") as StyleBoxFlat
			if style_box:
				style_box.border_color = Color(0.0, 0.8, 1.0, 0.45)
		
	get_tree().change_scene_to_file(next_scene_path)
	await get_tree().process_frame
	
	if not is_reversing:
		is_timer_running = true
	
	# Reset ukuran overlay lagi setelah scene baru (viewport bisa berubah)
	var new_viewport_size = get_viewport().get_visible_rect().size
	black_overlay.size = new_viewport_size
	black_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	black_overlay.position = Vector2.ZERO
	var out_tween = create_tween()
	out_tween.tween_property(black_overlay, "position", Vector2(0, -new_viewport_size.y), 0.6)
	out_tween.tween_callback(func():
		black_overlay.position = Vector2(0, new_viewport_size.y)
	)

func _on_slider_drag_started() -> void:
	is_scrubbing = true

func _on_slider_drag_ended(_value_changed: bool) -> void:
	is_scrubbing = false

func show_warning(text_msg: String) -> void:
	var old_label = canvas_layer.get_node_or_null("WarningLabel")
	if old_label:
		old_label.queue_free()
		
	var label = Label.new()
	label.name = "WarningLabel"
	label.text = text_msg
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2)) # Vibrant red warning
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.position = Vector2(0, 100) # Slightly offset below center
	canvas_layer.add_child(label)
	
	# Fade out and delete
	var tween = create_tween()
	tween.tween_property(label, "position:y", 60.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)

func fade_to_black(duration: float = 0.4) -> Signal:
	var viewport_size = get_viewport().get_visible_rect().size
	black_overlay.size = viewport_size
	black_overlay.position = Vector2.ZERO
	black_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	var tween = create_tween()
	tween.tween_property(black_overlay, "color:a", 1.0, duration)
	return tween.finished

func fade_from_black(duration: float = 0.4) -> Signal:
	var tween = create_tween()
	tween.tween_property(black_overlay, "color:a", 0.0, duration)
	tween.tween_callback(func():
		var viewport_size = get_viewport().get_visible_rect().size
		black_overlay.position = Vector2(0, viewport_size.y)
	)
	return tween.finished
