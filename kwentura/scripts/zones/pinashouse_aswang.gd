extends Node2D

func _on_timer_timeout():
	get_node("AudioPlayer").play()
	if get_node("Timer").time_left < 5:
		get_node("AswangSprite").show()
