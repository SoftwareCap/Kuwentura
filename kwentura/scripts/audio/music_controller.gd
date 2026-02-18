extends Node

enum MusicTrack {
	MAIN_MENU,      # Menu + Lobby music
	FOREST_HUB,     # Forest hub exploration
	GAMEPLAY,       # In-game exploration
	CLUE_FOUND,     # Short jingle (non-looping)
	PUZZLE,         # Puzzle solving tension
	CLIMAX          # Final sequence
}

@onready var _player: AudioStreamPlayer

# Preload music tracks
var _tracks: Dictionary = {}

var _current_track: MusicTrack = MusicTrack.MAIN_MENU
var _is_initialized: bool = false

func _ready() -> void:
	# Create and configure the AudioStreamPlayer
	_player = AudioStreamPlayer.new()
	_player.name = "AudioStreamPlayer"
	add_child(_player)
	
	# Ensure we have a dedicated "Music" audio bus
	_ensure_music_bus()
	
	# Load tracks
	_load_tracks()
	
	# Start playing main menu music
	play_track(MusicTrack.MAIN_MENU, 0.0)
	_is_initialized = true

func _ensure_music_bus() -> void:
	"""Create a dedicated Music audio bus if it doesn't exist."""
	var music_bus_index := AudioServer.get_bus_index("Music")
	if music_bus_index == -1:
		AudioServer.add_bus(AudioServer.bus_count)
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		# Set default volume to 0 dB (full volume)
		AudioServer.set_bus_volume_db(AudioServer.bus_count - 1, 0.0)
	_player.bus = "Music"

func _load_tracks() -> void:
	"""Preload all music tracks."""
	# Main Menu / Lobby BGM
	var main_menu_stream := load("res://audios/MainMenuBG.mp3")
	if main_menu_stream:
		# Configure for looping
		if main_menu_stream is AudioStreamMP3 or main_menu_stream is AudioStreamOggVorbis:
			main_menu_stream.loop = true
		_tracks[MusicTrack.MAIN_MENU] = main_menu_stream
	else:
		push_warning("[MusicController] Failed to load MainMenuBG.mp3")
	
	# Forest Hub BGM
	var forest_stream := load("res://audios/ForestBG.mp3")
	if forest_stream:
		if forest_stream is AudioStreamMP3 or forest_stream is AudioStreamOggVorbis:
			forest_stream.loop = true
		_tracks[MusicTrack.FOREST_HUB] = forest_stream
	else:
		push_warning("[MusicController] Failed to load ForestBG.mp3")

func play_track(track: MusicTrack, fade_duration: float = 0.5) -> void:
	"""Play a music track with optional fade transition."""
	if _current_track == track and _player.playing and _is_initialized:
		return  # Already playing this track
	
	_current_track = track
	
	# Fade out current, then fade in new
	if _player.playing and fade_duration > 0:
		var tween := create_tween()
		tween.tween_property(_player, "volume_db", -40.0, fade_duration)
		tween.tween_callback(_switch_track.bind(track, fade_duration))
	else:
		_switch_track(track, fade_duration)

func _switch_track(track: MusicTrack, fade_duration: float) -> void:
	"""Internal: Switch to the specified track."""
	if not _tracks.has(track):
		push_warning("[MusicController] Track not found: " + str(track))
		return
	
	_player.stream = _tracks[track]
	_player.stream.loop = true  # Ensure looping is enabled
	
	if fade_duration > 0:
		_player.volume_db = -40.0  # Start quiet
	else:
		_player.volume_db = 0.0
	
	_player.play()
	
	# Fade in
	if fade_duration > 0:
		var tween := create_tween()
		tween.tween_property(_player, "volume_db", 0.0, fade_duration)

func stop_music(fade_duration: float = 0.5) -> void:
	"""Stop the current music with fade out."""
	if not _player.playing:
		return
	
	if fade_duration > 0:
		var tween := create_tween()
		tween.tween_property(_player, "volume_db", -40.0, fade_duration)
		tween.tween_callback(_player.stop)
	else:
		_player.stop()

func set_volume(volume: float) -> void:
	"""Set music volume (0.0 to 1.0)."""
	var db := linear_to_db(clamp(volume, 0.0, 1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), db)

func get_volume() -> float:
	"""Get current music volume (0.0 to 1.0)."""
	var db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	return db_to_linear(db)

func is_playing() -> bool:
	"""Check if music is currently playing."""
	return _player.playing if _player else false

func get_current_track() -> MusicTrack:
	"""Get the currently playing track enum."""
	return _current_track
