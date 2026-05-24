extends Node

var elapsed_time: float = 0.0
var is_timer_running: bool = true

# GLOBAL REVERSE STATE
var is_reversing: bool = false

# UI Nodes
var canvas_layer: CanvasLayer
var timer_panel: PanelContainer
var timer_label: Label
var grenade_label: Label
var black_overlay: ColorRect
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

func reset_overlay_position() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	black_overlay.size = viewport_size
	black_overlay.position = Vector2(0, viewport_size.y)

func _process(delta: float) -> void:
	if is_timer_running:
		elapsed_time += delta
		update_timer_text()
	update_grenade_counter()

func update_timer_text() -> void:
	if not timer_label: return
	var minutes = int(elapsed_time / 60.0)
	var seconds = int(elapsed_time) % 60
	var centiseconds = int((elapsed_time - int(elapsed_time)) * 100)
	timer_label.text = "TIME: %02d:%02d.%02d" % [minutes, seconds, centiseconds]

func update_grenade_counter() -> void:
	if not grenade_label: return
	var current_scene = get_tree().current_scene
	if not current_scene: return
	var player = current_scene.get_node_or_null("Player")
	if not player: player = current_scene.get_node_or_null("Player (Testing)")
	if player and "grenades" in player:
		grenade_label.text = "GRENADES: %d" % player.grenades

func start_reverse_sequence() -> void:
	is_reversing = true
	is_timer_running = false 
	timer_label.add_theme_color_override("font_color", Color(0.9, 0.2, 1.0)) 
	grenade_label.add_theme_color_override("font_color", Color(0.9, 0.2, 1.0))
	var style_box = timer_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style_box:
		style_box.border_color = Color(0.9, 0.2, 1.0, 0.8)
	time_slider.visible = true 
	complete_level()

func complete_level() -> void:
	# Animation
	var viewport_size = get_viewport().get_visible_rect().size
	black_overlay.position = Vector2(0, viewport_size.y)
	var tween = create_tween()
	tween.tween_property(black_overlay, "position", Vector2.ZERO, 0.6)
	await tween.finished
	await get_tree().create_timer(0.2).timeout
	
	# --- OPTIMIZED: AUTO-SCALING LEVEL ROUTING ---
	var current_scene_path = get_tree().current_scene.scene_file_path
	var next_scene_path = ""
	
	# Extract the number from the filename (e.g., "level2.tscn" -> 2)
	var level_number = 0
	var regex = RegEx.new()
	regex.compile("\\d+") 
	var result = regex.search(current_scene_path)
	if result:
		level_number = int(result.get_string())
	
	if not is_reversing:
		# GOING FORWARD
		if current_scene_path.contains("game_manager"):
			next_scene_path = "res://scene/level1.tscn"
		else:
			next_scene_path = "res://scene/level" + str(level_number + 1) + ".tscn"
			
	else:
		# GOING BACKWARD
		if level_number > 1:
			next_scene_path = "res://scene/level" + str(level_number - 1) + ".tscn"
		elif level_number == 1:
			next_scene_path = "res://scene/game_manager.tscn"
		else:
			# REVERSED ALL THE WAY BACK
			next_scene_path = "res://scene/StartMenu.tscn"
			is_reversing = false
			elapsed_time = 0.0
			time_slider.visible = false
			timer_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
			grenade_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
			var style_box = timer_panel.get_theme_stylebox("panel") as StyleBoxFlat
			if style_box:
				style_box.border_color = Color(0.0, 0.8, 1.0, 0.45)
		
	get_tree().change_scene_to_file(next_scene_path)
	await get_tree().process_frame
	
	if not is_reversing:
		is_timer_running = true 
	
	var out_tween = create_tween()
	out_tween.tween_property(black_overlay, "position", Vector2(0, -viewport_size.y), 0.6)
