extends Node

enum MusicTrack {
	MAIN_MENU,
	OPENING_CUTSCENE,
	FOREST_HUB,
	PINAS_HOUSE,
	BACKYARD_PATH,
}

# Maps each track to its resource path — single source of truth for all paths
const TRACK_PATHS: Dictionary = {
	MusicTrack.MAIN_MENU: "res://assets/audios/MainMenuBG.mp3",
	MusicTrack.OPENING_CUTSCENE: "res://assets/audios/OpeningCutsceneBG.mp3",
	MusicTrack.FOREST_HUB: "res://assets/audios/ForestBG.mp3",
	MusicTrack.PINAS_HOUSE: "res://assets/audios/PinasHouseBG.mp3",
	MusicTrack.BACKYARD_PATH: "res://assets/audios/BackyardBG.mp3",
}

@onready var _player: AudioStreamPlayer = $AudioStreamPlayer

var _tracks: Dictionary = {}

var _current_track: MusicTrack = MusicTrack.MAIN_MENU
var _is_initialized: bool = false

# Saved playback position for resuming forest music when returning from zones
var _forest_hub_playback_position: float = 0.0


func _ready() -> void:
	_ensure_music_bus()
	_load_tracks()

	if _player and not _player.playing:
		play_track(MusicTrack.MAIN_MENU, 0.0)

	_is_initialized = true


func _ensure_music_bus() -> void:
	"""Create a dedicated Music audio bus if it doesn't exist."""
	var music_bus_index := AudioServer.get_bus_index("Music")
	if music_bus_index == -1:
		AudioServer.add_bus(AudioServer.bus_count)
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_volume_db(AudioServer.bus_count - 1, 0.0)

	if _player:
		_player.bus = "Music"


func _load_tracks() -> void:
	"""Preload all music tracks defined in TRACK_PATHS."""
	for track in TRACK_PATHS:
		_load_track(track, TRACK_PATHS[track])


func _load_track(track: MusicTrack, path: String) -> void:
	"""Load a single music track, configure looping, and store it."""
	var stream := load(path)
	if not stream:
		push_warning("[AudioControl] Failed to load: " + path)
		return

	if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = true

	_tracks[track] = stream


func play_track(track: MusicTrack, fade_duration: float = 0.5) -> void:
	"""Play a music track with optional fade transition."""
	if _current_track == track and _player and _player.playing and _is_initialized:
		return

	if _player and _current_track == MusicTrack.FOREST_HUB:
		_forest_hub_playback_position = _player.get_playback_position()
		print("[AudioControl] Saved FOREST_HUB position: ", _forest_hub_playback_position)

	_current_track = track

	if _player and _player.playing and fade_duration > 0:
		_fade_volume(-40.0, fade_duration, _switch_track.bind(track, fade_duration))
	else:
		_switch_track(track, fade_duration)


func _switch_track(track: MusicTrack, fade_duration: float) -> void:
	"""Internal: switch to the specified track and fade in."""
	if not _tracks.has(track):
		push_warning("[AudioControl] Track not found: " + str(track))
		return

	if not _player:
		push_warning("[AudioControl] AudioStreamPlayer not available")
		return

	_player.stream = _tracks[track]
	_player.volume_db = -40.0 if fade_duration > 0 else 0.0

	var from_position: float = 0.0
	if track == MusicTrack.FOREST_HUB and _forest_hub_playback_position > 0:
		from_position = _forest_hub_playback_position
		print("[AudioControl] Resuming FOREST_HUB from position: ", from_position)
		_forest_hub_playback_position = 0.0

	_player.play(from_position)

	if fade_duration > 0:
		_fade_volume(0.0, fade_duration)


func _fade_volume(target_db: float, duration: float, callback: Callable = Callable()) -> void:
	"""Tween the player volume to target_db over duration, then invoke an optional callback."""
	var tween := create_tween()
	tween.tween_property(_player, "volume_db", target_db, duration)
	if callback.is_valid():
		tween.tween_callback(callback)


func stop_music(fade_duration: float = 0.5) -> void:
	"""Stop the current music with optional fade out."""
	if not _player or not _player.playing:
		return

	if fade_duration > 0:
		_fade_volume(-40.0, fade_duration, _player.stop)
	else:
		_player.stop()


func pause_music() -> void:
	"""Pause the current music playback."""
	if not _player:
		return
	_player.stream_paused = true


func resume_music() -> void:
	"""Resume the paused music playback."""
	if not _player:
		return
	_player.stream_paused = false


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
