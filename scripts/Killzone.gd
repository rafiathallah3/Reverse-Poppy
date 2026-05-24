extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if not body.name.contains("Player"):
		return
		
	var st = get_node_or_null("/root/SceneTransition")
	
	if st and st.is_reversing:
		var portal = get_tree().current_scene.get_node_or_null("LevelFinish")
		
		if portal:
			_teleport_player_to_portal(body, portal, st)
		else:
			if body.has_method("die"):
				body.die()
				
	else:
		if body.has_method("die"):
			body.die() 

func _teleport_player_to_portal(player: Node2D, portal: Node2D, st: Node) -> void:
	
	if "is_paused" in player:
		player.is_paused = true
	player.velocity = Vector2.ZERO
	
	if st.has_method("fade_to_black"):
		await st.fade_to_black(0.2)
		
	player.global_position = portal.global_position + Vector2(0, -10)
	
	if st.has_method("fade_from_black"):
		await st.fade_from_black(0.2)
		
	if "is_paused" in player:
		player.is_paused = false
