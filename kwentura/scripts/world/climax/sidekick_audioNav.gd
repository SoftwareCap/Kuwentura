# scripts/climax/SidekickAudioNav.gd
extends Node

# Since sidekick sees black screen, they navigate by audio cues from detective
# This script manages the audio feedback system

@onready var left_ear = $LeftEar  # Audio player for left channel
@onready var right_ear = $RightEar  # Audio player for right channel
@onready var proximity_beep = $ProximityBeep

var danger_level: float = 0.0


func _process(_delta):
	_update_audio_cues()


func _update_audio_cues():
	# Get nearest obstacle position relative to player
	var player = get_tree().get_first_node_in_group("player")
	var nearest_obstacle = _get_nearest_obstacle()

	if nearest_obstacle and player:
		var direction = nearest_obstacle.position.x - player.position.x
		var distance = abs(direction)

		# Pan audio based on obstacle position
		if direction > 0:  # Obstacle ahead (right)
			right_ear.volume_db = linear_to_db(1.0)
			left_ear.volume_db = linear_to_db(0.3)
		else:  # Obstacle behind (left) - Nuno chasing!
			left_ear.volume_db = linear_to_db(1.0)
			right_ear.volume_db = linear_to_db(0.3)

		# Beep frequency increases as obstacle gets closer
		var beep_rate = clamp(2.0 - (distance / 300.0), 0.5, 2.0)
		proximity_beep.pitch_scale = beep_rate

		# Different tone for Nuno vs regular obstacles
		if nearest_obstacle.is_in_group("nuno"):
			proximity_beep.stream = preload("res://assets/audio/sfx/nuno_warning_beep.wav")
		else:
			proximity_beep.stream = preload("res://assets/audio/sfx/obstacle_beep.wav")


func _get_nearest_obstacle():
	var obstacles = get_tree().get_nodes_in_group("obstacles")
	var nearest = null
	var min_dist = INF

	for obs in obstacles:
		var dist = obs.global_position.distance_to(
			get_tree().get_first_node_in_group("player").global_position
		)
		if dist < min_dist:
			min_dist = dist
			nearest = obs

	return nearest


func linear_to_db(linear: float) -> float:
	if linear <= 0:
		return -80
	return 20.0 * log(linear) / log(10)
