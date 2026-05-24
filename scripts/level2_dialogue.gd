extends Node

const PIXEL_FONT_PATH = "res://assets/font/upheavtt.ttf"
var dialogue_lines: Array = [
	{
		"speaker": "",
		"text": "[ SECTOR 2 — RESTRICTED ZONE ]",
		"color": Color(0.4, 0.9, 1.0)
	},
	{
		"speaker": "POPPY",
		"text": "This place... something feels off. The machines here are different.",
		"color": Color(1.0, 0.75, 0.3)
	},
	{
		"speaker": "SYSTEM",
		"text": "WARNING: Hostile units detected. Proceed with extreme caution.",
		"color": Color(1.0, 0.3, 0.3)
	},
	{
		"speaker": "POPPY",
		"text": "No turning back now. Let's move.",
		"color": Color(1.0, 0.75, 0.3)
	},
]

# ── Typewriter settings 
var typewriter_speed: float = 0.032   # detik per karakter

# ── State
var current_index: int = -1
var is_in_dialogue: bool = false
var _char_timer: float = 0.0
var _chars_shown: int = 0
var _current_full_text: String = ""

# ── UI References 
var _canvas: CanvasLayer
var _backdrop: ColorRect
var _panel: PanelContainer
var _speaker_label: Label
var _speaker_line: ColorRect
var _text_label: Label
var _prompt_label: Label
var _portrait_rect: ColorRect   
var _scanline_rect: ColorRect

# ── Corner decorations 
var _corner_tl: Label
var _corner_tr: Label
var _corner_bl: Label
var _corner_br: Label

# ── Speaker color untuk accent line
var _current_speaker_color: Color = Color(0.4, 0.9, 1.0)

# 
func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_build_ui()
	call_deferred("_start_intro")

func _start_intro() -> void:
	# Pause player
	var player = _get_player()
	if player and player.has_method("set_paused"):
		player.set_paused(true)

	# Fade in backdrop 
	_backdrop.modulate.a = 0.0
	_backdrop.visible = true
	var tw = create_tween()
	tw.tween_property(_backdrop, "modulate:a", 1.0, 0.5)
	await tw.finished

	# Fade in panel
	_panel.modulate.a = 0.0
	_panel.visible = true
	var tw2 = create_tween()
	tw2.tween_property(_panel, "modulate:a", 1.0, 0.35)
	await tw2.finished

	is_in_dialogue = true
	_advance_dialogue()


#  INPUT
# 
func _unhandled_input(event: InputEvent) -> void:
	if not is_in_dialogue:
		return

	if event.is_action_pressed("ui_accept") or \
   		event.is_action_pressed("shoot") or \
   		event.is_action_pressed("jump") or \
   		(event is InputEventKey and event.physical_keycode == KEY_Y) or \
   		(event is InputEventJoypadButton and event.button_index == JOY_BUTTON_Y):
		if _chars_shown < _current_full_text.length():
			# Skip typewriter — tampilkan semua sekarang
			_chars_shown = _current_full_text.length()
			_text_label.visible_characters = -1
			_prompt_label.visible = true
		else:
			_advance_dialogue()
		get_viewport().set_input_as_handled()

# 
#  PROCESS — typewriter
# 
func _process(delta: float) -> void:
	if not is_in_dialogue:
		return
	if _chars_shown >= _current_full_text.length():
		return

	_char_timer += delta
	while _char_timer >= typewriter_speed and _chars_shown < _current_full_text.length():
		_char_timer -= typewriter_speed
		_chars_shown += 1
		_text_label.visible_characters = _chars_shown

	if _chars_shown >= _current_full_text.length():
		_prompt_label.visible = true

# 
#  DIALOGUE LOGIC
# 
func _advance_dialogue() -> void:
	current_index += 1
	if current_index >= dialogue_lines.size():
		_finish_dialogue()
		return

	var entry = dialogue_lines[current_index]
	_current_full_text = entry["text"]
	_current_speaker_color = entry.get("color", Color(1, 1, 1))

	# Update speaker
	var speaker: String = entry.get("speaker", "")
	if speaker == "":
		_speaker_label.visible = false
		_speaker_line.visible = false
	else:
		_speaker_label.visible = true
		_speaker_line.visible = true
		_speaker_label.text = speaker
		_speaker_label.add_theme_color_override("font_color", _current_speaker_color)
		_speaker_line.color = _current_speaker_color

	# Update border accent color on panel
	var style = _panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = Color(_current_speaker_color.r, _current_speaker_color.g, _current_speaker_color.b, 0.7)

	# Reset typewriter
	_text_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	_text_label.text = _current_full_text
	_text_label.visible_characters = 0
	_chars_shown = 0
	_char_timer = 0.0
	_prompt_label.visible = false

	# (no slide animation — panel stays at bottom)

func _finish_dialogue() -> void:
	is_in_dialogue = false

	# Fade out panel lalu backdrop
	var tw = create_tween()
	tw.tween_property(_panel, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): _panel.visible = false)
	tw.tween_property(_backdrop, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): _backdrop.visible = false)
	await tw.finished

	# Unpause player
	var player = _get_player()
	if player and player.has_method("set_paused"):
		player.set_paused(false)

# 
#  UI BUILDER
# 
func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 90
	_canvas.name = "Level2DialogueCanvas"
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)

	# ── Semi-transparent backdrop 
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.0, 0.0, 0.05, 0.55)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.visible = false
	_canvas.add_child(_backdrop)

	# ── Main panel 
	_panel = PanelContainer.new()
	_panel.name = "DialoguePanel"
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left   = 80.0
	_panel.offset_right  = -80.0
	_panel.offset_top    = -160.0
	_panel.offset_bottom = -20.0
	_panel.visible = false

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color           = Color(0.03, 0.04, 0.09, 0.92)
	panel_style.border_width_left   = 2
	panel_style.border_width_top    = 2
	panel_style.border_width_right  = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color        = Color(0.4, 0.9, 1.0, 0.7)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left   = 22
	panel_style.content_margin_right  = 22
	panel_style.content_margin_top    = 14
	panel_style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", panel_style)
	_canvas.add_child(_panel)

	# ── Corner decorations 
	_add_corners()

	# ── Scanline overlay 
	# (subtle grid texture via modulate; real scanlines need shader)
	_scanline_rect = ColorRect.new()
	_scanline_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_scanline_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scanline_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_scanline_rect)

	# ── Inner layout 
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(main_vbox)

	# Speaker row (name + accent line)
	var speaker_row := HBoxContainer.new()
	speaker_row.add_theme_constant_override("separation", 10)
	main_vbox.add_child(speaker_row)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 14)
	_speaker_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	_speaker_label.add_theme_constant_override("outline_size", 3)
	_speaker_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_speaker_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_try_load_font(_speaker_label)
	speaker_row.add_child(_speaker_label)

	_speaker_line = ColorRect.new()
	_speaker_line.color = Color(0.4, 0.9, 1.0)
	_speaker_line.custom_minimum_size = Vector2(0, 2)
	_speaker_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speaker_line.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	speaker_row.add_child(_speaker_line)

	# Dialogue text
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text_label.add_theme_font_size_override("font_size", 19)
	_text_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	_text_label.add_theme_constant_override("outline_size", 2)
	_text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.visible_characters = 0
	_try_load_font(_text_label, 19)
	main_vbox.add_child(_text_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 2)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer)

	# Prompt (blink)
	_prompt_label = Label.new()
	_prompt_label.text = "▶  ENTER / Y  to continue"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt_label.add_theme_font_size_override("font_size", 11)
	_prompt_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 0.8))
	_prompt_label.visible = false
	_try_load_font(_prompt_label, 11)
	main_vbox.add_child(_prompt_label)

	# Prompt blink tween
	var pulse := _prompt_label.create_tween().set_loops()
	pulse.tween_property(_prompt_label, "modulate:a", 0.15, 0.7)
	pulse.tween_property(_prompt_label, "modulate:a", 1.0,  0.7)

func _add_corners() -> void:
	# Tambah teks "╔ ╗ ╚ ╝" di sudut panel sebagai dekorasi retro
	var corners = [
		{"text": "◤", "h": Control.PRESET_TOP_LEFT,     "hmod": 0, "vmod": 0},
		{"text": "◥", "h": Control.PRESET_TOP_RIGHT,    "hmod": 0, "vmod": 0},
		{"text": "◣", "h": Control.PRESET_BOTTOM_LEFT,  "hmod": 0, "vmod": 0},
		{"text": "◢", "h": Control.PRESET_BOTTOM_RIGHT, "hmod": 0, "vmod": 0},
	]
	for c in corners:
		var lbl := Label.new()
		lbl.text = c["text"]
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0, 0.5))
		lbl.set_anchors_preset(c["h"])
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(lbl)

# 
#  HELPERS
# 
func _try_load_font(lbl: Label, size: int = 0) -> void:
	var font = load(PIXEL_FONT_PATH) if ResourceLoader.exists(PIXEL_FONT_PATH) else null
	if font:
		lbl.add_theme_font_override("font", font)
		if size > 0:
			lbl.add_theme_font_size_override("font_size", size)

func _get_player() -> Node:
	var scene = get_tree().current_scene
	if not scene: return null
	var p = scene.get_node_or_null("Player")
	if not p: p = scene.get_node_or_null("Player (Testing)")
	return p
