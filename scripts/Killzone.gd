extends Area2D

func _on_body_entered(body: Node2D) -> void:
	print("Something touched the killzone: ", body.name)
	if body.has_method("die"):
		body.die()
