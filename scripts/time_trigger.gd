extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name.contains("Player"):
		var game_manager = get_tree().current_scene
		if game_manager and game_manager.has_method("on_player_entered_trigger"):
			game_manager.on_player_entered_trigger()
