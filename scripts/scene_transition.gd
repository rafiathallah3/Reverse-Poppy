extends Node

var elapsed_time: float = 0.0
var is_timer_running: bool = true

# UI Nodes created programmatically
var canvas_layer: CanvasLayer
var timer_panel: PanelContainer
var timer_label: Label
var grenade_label: Label
var black_overlay: ColorRect

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS # Keep running even if level is paused
	setup_ui()

func setup_ui() -> void:
	# Create CanvasLayer on top of everything
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 128
	canvas_layer.name = "SceneTransitionCanvas"
	add_child(canvas_layer)
	
	# Create Black Overlay for transitions
	black_overlay = ColorRect.new()
	black_overlay.name = "BlackOverlay"
	black_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	black_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(black_overlay)
	
	# Move the overlay below the screen initially
	# We defer this to ensure viewport is initialized and has size
	call_deferred("reset_overlay_position")
	
	# Create the Timer UI Panel (Glassmorphism design)
	timer_panel = PanelContainer.new()
	timer_panel.name = "TimerPanel"
	timer_panel.position = Vector2(25, 25)
	
	# Apply premium flat StyleBox
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.06, 0.06, 0.1, 0.75) # Translucent dark blue-grey
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.0, 0.8, 1.0, 0.45) # Sleek glowing cyan outline
	style_box.set_corner_radius_all(10)
	style_box.shadow_color = Color(0, 0, 0, 0.4)
	style_box.shadow_size = 8
	style_box.shadow_offset = Vector2(2, 4)
	timer_panel.add_theme_stylebox_override("panel", style_box)
	
	canvas_layer.add_child(timer_panel)
	
	# Margin Container inside panel for elegant padding
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_top", 8)
	margin_container.add_theme_constant_override("margin_bottom", 8)
	timer_panel.add_child(margin_container)
	
	# VBoxContainer to stack Timer and Grenade counter vertically
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin_container.add_child(vbox)
	
	# Label for modern digital stopwatch text
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "TIME: 00:00.00"
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0)) # Bright glowing cyan
	# Set pivot to center for the win-animation scale effect
	timer_label.pivot_offset = Vector2(70, 15)
	vbox.add_child(timer_label)
	
	# Label for grenade counter
	grenade_label = Label.new()
	grenade_label.name = "GrenadeLabel"
	grenade_label.text = "GRENADES: 3"
	grenade_label.add_theme_font_size_override("font_size", 16)
	grenade_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5)) # Bright glowing neon green
	vbox.add_child(grenade_label)

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
	if not timer_label:
		return
	var minutes = int(elapsed_time / 60.0)
	var seconds = int(elapsed_time) % 60
	var centiseconds = int((elapsed_time - int(elapsed_time)) * 100)
	timer_label.text = "TIME: %02d:%02d.%02d" % [minutes, seconds, centiseconds]

func update_grenade_counter() -> void:
	if not grenade_label:
		return
		
	var current_scene = get_tree().current_scene
	if not current_scene:
		grenade_label.text = "GRENADES: --"
		return
		
	var player = current_scene.get_node_or_null("Player")
	if not player:
		player = current_scene.get_node_or_null("Player (Testing)")
		
	if player and "grenades" in player:
		grenade_label.text = "GRENADES: %d" % player.grenades
	else:
		grenade_label.text = "GRENADES: --"

func complete_level() -> void:
	if not is_timer_running:
		return
		
	is_timer_running = false
	
	# 1. Premium level completion micro-animation
	# Freeze timer and animate label to a golden color with a subtle pulsing bounce
	var pulse_tween = create_tween()
	pulse_tween.set_ease(Tween.EASE_OUT)
	pulse_tween.set_trans(Tween.TRANS_ELASTIC)
	pulse_tween.tween_property(timer_label, "scale", Vector2(1.25, 1.25), 0.3)
	timer_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2)) # Premium gold finish
	
	# Update outline to gold
	var style_box = timer_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style_box:
		var border_tween = create_tween()
		border_tween.tween_property(style_box, "border_color", Color(1.0, 0.85, 0.2, 0.8), 0.3)
		
	# 2. Black transition background slides up to fill screen
	var viewport_size = get_viewport().get_visible_rect().size
	black_overlay.size = viewport_size
	# Ensure it starts from the bottom
	black_overlay.position = Vector2(0, viewport_size.y)
	
	var slide_in_tween = create_tween()
	slide_in_tween.set_ease(Tween.EASE_OUT)
	slide_in_tween.set_trans(Tween.TRANS_CUBIC)
	# Tween to fill screen at y = 0
	slide_in_tween.tween_property(black_overlay, "position", Vector2.ZERO, 0.6)
	
	# Wait for the screen to be fully covered
	await slide_in_tween.finished
	
	# Pause for a split second for cinematic pacing
	await get_tree().create_timer(0.2).timeout
	
	# 3. Transition to next level
	var current_scene_path = get_tree().current_scene.scene_file_path
	var next_scene_path = "res://scene/level1.tscn"
	if current_scene_path.contains("level1.tscn"):
		next_scene_path = "res://game_manager.tscn"
		
	get_tree().change_scene_to_file(next_scene_path)
	
	# Wait for the scene change to register and instantiate
	await get_tree().process_frame
	
	# Reset timer and UI state back to default cyan/green
	elapsed_time = 0.0
	is_timer_running = true
	timer_label.scale = Vector2.ONE
	timer_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	grenade_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
	if style_box:
		style_box.border_color = Color(0.0, 0.8, 1.0, 0.45)
	
	# 4. Slide the black background up until it's no longer shown
	var slide_out_tween = create_tween()
	slide_out_tween.set_ease(Tween.EASE_IN_OUT)
	slide_out_tween.set_trans(Tween.TRANS_CUBIC)
	# Slide up off-screen top (position.y = -viewport_height)
	slide_out_tween.tween_property(black_overlay, "position", Vector2(0, -viewport_size.y), 0.6)
	
	await slide_out_tween.finished
	
	# Reset position back to the bottom for the next transition
	black_overlay.position = Vector2(0, viewport_size.y)
