extends TextureRect # Works for Buttons too

@export var shift_amount: float = 10.0
@export var duration: float = 0.50

var original_position: Vector2

func _ready() -> void:
	original_position = position
	
	# Connect UI hover signals directly via code
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	var tween = create_tween()
	var target_pos = original_position + Vector2(shift_amount, 0)
	
	tween.tween_property(self, "position", target_pos, duration)

func _on_mouse_exited() -> void:
	var tween = create_tween()
	# Smoothly return to the exact starting spot
	tween.tween_property(self, "position", original_position, duration)
