extends Area2D

# CHECK THIS BOX IN THE INSPECTOR ONLY FOR THE VERY LAST PORTAL
@export var is_final_trigger: bool = false 

var triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if triggered:
		return
		
	if body.name.contains("Player"):
		triggered = true
		
		# Disable physics monitoring immediately
		set_deferred("monitoring", false)
		
		# Premium imploding fade-out micro-animation
		var visual = get_node_or_null("PortalVisual")
		if visual:
			visual.pivot_offset = visual.size / 2.0
			var tween = create_tween()
			tween.tween_property(visual, "modulate:a", 0.0, 0.4)
			tween.parallel().tween_property(visual, "scale", Vector2(1.6, 1.6), 0.4)
		
		# --- ROUTE TO THE CORRECT GLOBAL FUNCTION ---
		if get_tree().root.has_node("SceneTransition"):
			if is_final_trigger:
				# It's the end of the game! Start the reverse phase.
				get_node("/root/SceneTransition").start_reverse_sequence()
			else:
				# Normal level progression.
				get_node("/root/SceneTransition").complete_level()
