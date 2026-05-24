extends Area2D

# CHECK THIS BOX IN THE INSPECTOR ONLY FOR THE VERY LAST PORTAL
@export var is_final_trigger: bool = false 

var triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if name == "LevelFinish":
		visible = false
		monitoring = false

func _on_body_entered(body: Node2D) -> void:
	if triggered:
		return
		
	if body.name.contains("Player"):
		var st = get_node_or_null("/root/SceneTransition")
		if name == "LevelFinish" and (not st or not st.is_reversing):
			return
			
		# Check if the player has at least 3 grenades to finish the level backward
		if name == "LevelFinish" and st and st.is_reversing:
			if "grenades" in body and body.grenades < 3:
				if st.has_method("show_warning"):
					st.show_warning("Need 3 grenades to complete level!")
				return
			
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
		if st:
			if st.is_reversing and get_tree().current_scene.scene_file_path.contains("game_manager"):
				# We are in the Finish scene and touched the finish object!
				st.is_timer_running = false
				st.is_finished = true
				st.complete_level()
			elif is_final_trigger:
				# It's the end of the game! Start the reverse phase.
				st.start_reverse_sequence()
			else:
				# Normal level progression.
				st.complete_level()
