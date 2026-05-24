extends Area2D

# CHECK THIS BOX IN THE INSPECTOR ONLY FOR THE VERY LAST PORTAL
@export var is_final_trigger: bool = false 

var triggered: bool = false

@onready var SFX_BALIK_WAKTU = load("res://assets/SFX/balik_waktu.mp3")

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
			
		# [REVERSE PHASE CHECKS]
		if name == "LevelFinish" and st and st.is_reversing:
			# 1. Grenade Check
			if "grenades" in body and body.grenades < 3:
				if st.has_method("show_warning"):
					st.show_warning("Need 3 grenades to complete level!")
				return
				
			# 2. Enemy Revive Check
			var enemies = get_tree().get_nodes_in_group("enemies")
			var unrevived_count = 0
			
			for enemy in enemies:
				# If is_time_reversing is true, they are a pile of scrap waiting to be revived
				if "is_time_reversing" in enemy and enemy.is_time_reversing:
					unrevived_count += 1
					
			if unrevived_count > 0:
				if st.has_method("show_warning"):
					st.show_warning("Revive " + str(unrevived_count) + " more enemies!")
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
			if st.is_reversing and get_tree().current_scene.scene_file_path.contains("level3"):
				# We are in the Finish scene and touched the finish object!
				st.is_timer_running = false
				st.is_finished = true
				st.complete_level()
			elif is_final_trigger:
				# It's the end of the game! Start the reverse phase.
				_play_sfx_detached(SFX_BALIK_WAKTU)
				st.start_reverse_sequence()
			else:
				# Normal level progression.
				st.complete_level()

func _play_sfx_detached(stream: AudioStream) -> void:
	var audio_player = AudioStreamPlayer2D.new()
	audio_player.stream = stream
	audio_player.volume_db = -6.0
	audio_player.global_position = global_position
	get_parent().add_child(audio_player)
	audio_player.play()
	audio_player.finished.connect(audio_player.queue_free)
