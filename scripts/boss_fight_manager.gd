extends Node

const BOSS_SCRIPT = preload("res://scripts/boss.gd")
const FORCE_FIELD_SCRIPT = preload("res://scripts/force_field.gd")

var boss: CharacterBody2D = null
var active_force_field: StaticBody2D = null
var player: CharacterBody2D = null

var ui_canvas: CanvasLayer = null
var boss_ui_panel: PanelContainer = null
var boss_name_label: Label = null
var boss_health_label: Label = null

var dialogue_panel: PanelContainer = null
var dialogue_text: Label = null
var dialogue_prompt: Label = null
var white_fade_rect: ColorRect = null

var boss_max_health: int = 1
var boss_current_health: int = 1
var platform_positions: Array = []
var active_platform_nodes: Array = []

var dialogue_lines: Array = [
	"I am not a mere scrapile.",
	"I'm your father, Poppy.",
	"Goodbye."
]
var current_dialogue_index: int = -1
var is_in_dialogue: bool = false
var is_intro_dialogue: bool = false
var typewriter_speed: float = 0.04
var current_text_visible_ratio: float = 0.0
var dialogue_timer: float = 0.0

func _ready() -> void:
	name = "BossFightManager"
	call_deferred("_setup_boss_fight")

func _setup_boss_fight() -> void:
	# Find player
	var current_scene = get_tree().current_scene
	if current_scene:
		player = current_scene.get_node_or_null("Player")
		if not player:
			player = current_scene.get_node_or_null("Player (Testing)")

	# Scan for floating platforms (nodes starting with "FP_")
	platform_positions.clear()
	active_platform_nodes.clear()
	for child in get_parent().get_children():
		if child.name.begins_with("FP_"):
			platform_positions.append(child.global_position)
			active_platform_nodes.append(child)

	if platform_positions.size() == 0:
		platform_positions = [
			Vector2(280, 350),
			Vector2(180, 440),
			Vector2(530, 490),
			Vector2(820, 430),
			Vector2(1200, 290),
			Vector2(1580, 430),
			Vector2(1870, 490),
			Vector2(2220, 440),
			Vector2(2120, 350)
		]

	ui_canvas = CanvasLayer.new()
	ui_canvas.layer = 100
	ui_canvas.name = "BossFightCanvas"
	add_child(ui_canvas)

	_create_boss_ui()

	_spawn_boss()

	_create_dialogue_ui()

	if player and is_instance_valid(player):
		player.bullets = 90
		player.grenades = 20
		if player.has_method("set_paused"):
			player.set_paused(true)
			
		var camera = player.get_node_or_null("Camera2D")
		if camera and camera is Camera2D:
			camera.enabled = true
			camera.make_current()
			camera.position = Vector2.ZERO
			camera.limit_left = 0
			camera.limit_top = -200
			camera.limit_right = 2400
			camera.limit_bottom = 580
			camera.position_smoothing_enabled = true

	is_intro_dialogue = true
	dialogue_lines = ["You are suddenly granted with 20 grenades and 90 bullets for some reason..."]
	_start_dialogue_sequence()

func _create_boss_ui() -> void:
	# Container for boss health
	boss_ui_panel = PanelContainer.new()
	boss_ui_panel.name = "BossUIPanel"
	boss_ui_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	boss_ui_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	
	# Transparent panel style with premium neon border
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.05, 0.03, 0.08, 0.6)
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.8, 0.1, 0.9, 0.4) # Glowing neon magenta
	style_box.set_corner_radius_all(0)
	style_box.content_margin_top = 10
	style_box.content_margin_bottom = 10
	boss_ui_panel.add_theme_stylebox_override("panel", style_box)
	ui_canvas.add_child(boss_ui_panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	boss_ui_panel.add_child(vbox)

	# Boss Name Label
	boss_name_label = Label.new()
	boss_name_label.text = "Evil Man"
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.add_theme_font_size_override("font_size", 24)
	boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.1, 0.35)) # Menacing red-pink
	boss_name_label.add_theme_constant_override("outline_size", 6)
	boss_name_label.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.1, 0.9))
	vbox.add_child(boss_name_label)

	# Boss Health Dashes Label
	boss_health_label = Label.new()
	boss_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_health_label.add_theme_font_size_override("font_size", 20)
	boss_health_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.8)) # Glowing magenta
	boss_health_label.add_theme_constant_override("outline_size", 4)
	boss_health_label.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.1, 0.8))
	vbox.add_child(boss_health_label)

	_update_health_ui()

func _update_health_ui() -> void:
	if not boss_health_label:
		return
	var dashes = ""
	for i in range(boss_current_health):
		dashes += "- "
	boss_health_label.text = dashes.strip_edges()

func _spawn_boss() -> void:
	# Find FP_CenterTop platform position to spawn
	var spawn_pos = Vector2(1200, 240)
	var center_top_index = -1
	
	for i in range(active_platform_nodes.size()):
		if active_platform_nodes[i].name == "FP_CenterTop":
			spawn_pos = platform_positions[i]
			center_top_index = i
			break

	# Find the existing Boss node in the scene tree
	boss = get_parent().get_node_or_null("Boss")
	if boss:
		boss.position = spawn_pos + Vector2(0, -50)
		boss.platform_positions = platform_positions
		boss.current_platform_index = center_top_index
		boss.max_health = boss_max_health
		boss.health = boss_current_health

		# Connect signals
		boss.boss_damaged.connect(_on_boss_damaged)
		boss.boss_defeated.connect(_on_boss_defeated)

func _create_dialogue_ui() -> void:
	# Subtitle dialogue panel at the bottom
	dialogue_panel = PanelContainer.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dialogue_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dialogue_panel.offset_left = 150
	dialogue_panel.offset_right = -150
	dialogue_panel.offset_top = -180
	dialogue_panel.offset_bottom = -40
	dialogue_panel.visible = false

	# Glassmorphism panel style
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.06, 0.04, 0.1, 0.85)
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.8, 0.1, 0.9, 0.5) # Glowing magenta outline
	style_box.set_corner_radius_all(10)
	style_box.content_margin_left = 24
	style_box.content_margin_right = 24
	style_box.content_margin_top = 16
	style_box.content_margin_bottom = 16
	dialogue_panel.add_theme_stylebox_override("panel", style_box)
	ui_canvas.add_child(dialogue_panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dialogue_panel.add_child(vbox)

	dialogue_text = Label.new()
	dialogue_text.text = ""
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialogue_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_text.add_theme_font_size_override("font_size", 22)
	dialogue_text.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(dialogue_text)

	dialogue_prompt = Label.new()
	dialogue_prompt.text = "[Press Enter/Y to Continue]"
	dialogue_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dialogue_prompt.add_theme_font_size_override("font_size", 12)
	dialogue_prompt.add_theme_color_override("font_color", Color(0.8, 0.1, 0.9, 0.7))
	vbox.add_child(dialogue_prompt)

	# Setup prompt blink animation
	var pulse_tween = dialogue_prompt.create_tween().set_loops()
	pulse_tween.tween_property(dialogue_prompt, "modulate:a", 0.2, 0.8)
	pulse_tween.tween_property(dialogue_prompt, "modulate:a", 1.0, 0.8)

	# Fullscreen overlay for white fade
	white_fade_rect = ColorRect.new()
	white_fade_rect.name = "WhiteFadeRect"
	white_fade_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	white_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	white_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_canvas.add_child(white_fade_rect)

func _process(delta: float) -> void:
	# Monitor active force field destruction
	if boss and boss.is_invulnerable and active_force_field != null:
		if not is_instance_valid(active_force_field) or active_force_field.health <= 0:
			active_force_field = null
			boss.is_invulnerable = false

	# Handle Dialogue typewriter speed and advancement
	if is_in_dialogue:
		if dialogue_text.visible_ratio < 1.0:
			dialogue_text.visible_ratio = min(dialogue_text.visible_ratio + (delta / (dialogue_text.text.length() * typewriter_speed)), 1.0)
		
		# Allow auto-advancement after some time or key press
		dialogue_timer += delta
		var dialogue_complete = dialogue_text.visible_ratio >= 1.0
		
		if Input.is_action_just_pressed("shoot") or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
			if not dialogue_complete:
				dialogue_text.visible_ratio = 1.0
			else:
				_advance_dialogue()

func _on_boss_damaged(new_health: int) -> void:
	boss_current_health = new_health
	_update_health_ui()

	if boss_current_health > 0:
		# Teleport creates brief invulnerability, now spawn the force field
		# Force field will appear at the boss's new position after the teleport sequence completes
		await get_tree().create_timer(0.6).timeout
		if is_instance_valid(boss) and not boss.is_dead:
			_spawn_force_field()

func _spawn_force_field() -> void:
	if active_force_field != null and is_instance_valid(active_force_field):
		active_force_field.queue_free()

	active_force_field = StaticBody2D.new()
	active_force_field.name = "BossForceField"
	active_force_field.set_script(FORCE_FIELD_SCRIPT)
	active_force_field.global_position = boss.global_position
	active_force_field.max_health = 5
	active_force_field.health = 5
	get_parent().add_child(active_force_field)

	# Ensure boss is invulnerable while force field is active
	boss.is_invulnerable = true

func _on_boss_defeated() -> void:
	# Hide health UI
	if boss_ui_panel:
		var fade_ui = create_tween()
		fade_ui.tween_property(boss_ui_panel, "modulate:a", 0.0, 0.4)
		fade_ui.tween_callback(func(): boss_ui_panel.visible = false)

	# Stop battle music
	var music_script = get_parent()
	if music_script and music_script.has_method("stop_music"):
		music_script.stop_music()

	# Pause player movement during dialogue
	if player and is_instance_valid(player) and player.has_method("set_paused"):
		player.set_paused(true)

	# Set dialogue lines for defeat
	is_intro_dialogue = false
	dialogue_lines = [
		"I am not a mere scrapile.",
		"I'm your father, Poppy.",
		"Goodbye."
	]

	# Start final dialogue
	await get_tree().create_timer(1.2).timeout
	_start_dialogue_sequence()

func _start_dialogue_sequence() -> void:
	is_in_dialogue = true
	current_dialogue_index = -1
	dialogue_panel.visible = true
	dialogue_panel.modulate.a = 0.0
	var fade_panel = create_tween()
	fade_panel.tween_property(dialogue_panel, "modulate:a", 1.0, 0.3)
	
	_advance_dialogue()

func _advance_dialogue() -> void:
	current_dialogue_index += 1
	if current_dialogue_index >= dialogue_lines.size():
		_finish_dialogue()
		return

	dialogue_text.text = dialogue_lines[current_dialogue_index]
	dialogue_text.visible_ratio = 0.0
	dialogue_timer = 0.0

func _finish_dialogue() -> void:
	is_in_dialogue = false
	
	# Hide dialogue UI
	if dialogue_panel:
		var fade_panel = create_tween()
		fade_panel.tween_property(dialogue_panel, "modulate:a", 0.0, 0.4)
		fade_panel.tween_callback(func(): dialogue_panel.visible = false)
	
	if is_intro_dialogue:
		is_intro_dialogue = false
		if player and is_instance_valid(player) and player.has_method("set_paused"):
			player.set_paused(false)
	else:
		_finish_boss_fight()

func _finish_boss_fight() -> void:
	is_in_dialogue = false
	
	# Hide dialogue UI
	if dialogue_panel:
		var fade_panel = create_tween()
		fade_panel.tween_property(dialogue_panel, "modulate:a", 0.0, 0.4)
		fade_panel.tween_callback(func(): dialogue_panel.visible = false)

	# Fade in white screen with screen shake
	if white_fade_rect:
		_apply_long_screen_shake(2.0)
		var fade_white = create_tween()
		fade_white.tween_property(white_fade_rect, "color:a", 1.0, 2.0)
		await fade_white.finished

	# Stop time triggers and save level 3 time before going to EndMenu
	if get_tree().root.has_node("SceneTransition"):
		var st = get_node("/root/SceneTransition")
		st.is_timer_running = false
		# Save level 3's time into level_times so EndMenu can display it
		var level_time = st.elapsed_time - st.level_start_time
		st.level_times["Level 3"] = level_time

	# Transition to EndMenu
	get_tree().change_scene_to_file("res://scene/EndMenu.tscn")

func _apply_long_screen_shake(duration: float) -> void:
	var camera = get_viewport().get_camera_2d()
	if camera:
		var original_offset = camera.offset
		var shake_tween = camera.create_tween()
		var step_time = 0.04
		var steps = int(duration / step_time)
		for i in range(steps):
			var intensity = 10.0
			var rand_offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
			shake_tween.tween_property(camera, "offset", rand_offset, step_time)
		shake_tween.tween_property(camera, "offset", original_offset, 0.05)

# ── Reset for player death ──────────────────────────────────────────────────
func reset_boss_fight() -> void:
	# Clear active force fields
	if active_force_field != null and is_instance_valid(active_force_field):
		active_force_field.queue_free()
	active_force_field = null

	# Reset dialogue state
	is_in_dialogue = false
	current_dialogue_index = -1
	if dialogue_panel:
		dialogue_panel.visible = false
	if white_fade_rect:
		white_fade_rect.color.a = 0.0

	# Reset health to max
	boss_current_health = boss_max_health
	_update_health_ui()
	if boss_ui_panel:
		boss_ui_panel.visible = true
		boss_ui_panel.modulate.a = 1.0

	# Reset boss script state and position
	if boss != null and is_instance_valid(boss):
		boss.reset_boss()
		
		# Find FP_CenterTop index to reset boss position
		var spawn_pos = Vector2(1200, 240)
		var center_top_index = -1
		for i in range(active_platform_nodes.size()):
			if active_platform_nodes[i].name == "FP_CenterTop":
				spawn_pos = platform_positions[i]
				center_top_index = i
				break
		boss.position = spawn_pos + Vector2(0, -50)
		boss.base_y = boss.position.y
		boss.current_platform_index = center_top_index
