extends Area2D

var triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if triggered:
		return
		
	if body.name.contains("Player"):
		triggered = true
		
		# Disable physics monitoring immediately to prevent double triggers
		set_deferred("monitoring", false)
		
		# Premium imploding fade-out micro-animation of the portal visual
		var visual = get_node_or_null("PortalVisual")
		if visual:
			# Enable centering for the scale tween
			visual.pivot_offset = visual.size / 2.0
			var tween = create_tween()
			tween.tween_property(visual, "modulate:a", 0.0, 0.4)
			tween.parallel().tween_property(visual, "scale", Vector2(1.6, 1.6), 0.4)
		
		# Trigger time-reverse state in game manager
		var game_manager = get_tree().current_scene
		if game_manager and game_manager.has_method("on_player_entered_trigger"):
			game_manager.on_player_entered_trigger()

