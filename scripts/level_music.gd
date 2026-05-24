extends Node

@onready var battle_music: AudioStreamPlayer = $BattleMusic

func _ready() -> void:
	if battle_music:
		battle_music.play()

func stop_music() -> void:
	if battle_music and battle_music.playing:
		battle_music.stop()

func _on_battle_music_finished() -> void:
	if battle_music:
		battle_music.play()
