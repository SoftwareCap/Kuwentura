##cutscene_helper.gd
## Shared cutscene playback helpers — OGV/Theora video is unreliable on mobile.
class_name CutsceneHelper
extends RefCounted

const MOBILE_OS_NAMES: Array[String] = ["Android", "iOS"]

static func is_mobile_platform() -> bool:
	var os_name := OS.get_name()
	if os_name in MOBILE_OS_NAMES:
		return true
	if os_name == "Web" and DisplayServer.is_touchscreen_available():
		return true
	return false

static func video_supported(player: VideoStreamPlayer) -> bool:
	if is_mobile_platform():
		return false
	return is_instance_valid(player) and player.stream != null


static func prepare_mobile_video_player(player: VideoStreamPlayer) -> void:
	if not is_mobile_platform() or not is_instance_valid(player):
		return
	player.stop()
	player.stream = null
	player.visible = false

## Play a zone-ending (or similar) cutscene with mobile fallback and safety timeout.
static func play_with_fallback(
	owner: Node,
	player: VideoStreamPlayer,
	on_finished: Callable,
	fallback_seconds: float = 3.0,
	max_seconds: float = 90.0
) -> void:
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		on_finished.call()
		return

	var done: Array[bool] = [false]
	var finish := func() -> void:
		if done[0]:
			return
		done[0] = true
		if is_instance_valid(player):
			player.stop()
		on_finished.call()

	if not is_instance_valid(player):
		finish.call()
		return

	if not video_supported(player):
		player.visible = false
		owner.get_tree().create_timer(fallback_seconds).timeout.connect(finish, CONNECT_ONE_SHOT)
		return

	player.play()
	if not player.finished.is_connected(finish):
		player.finished.connect(finish, CONNECT_ONE_SHOT)
	owner.get_tree().create_timer(max_seconds).timeout.connect(finish, CONNECT_ONE_SHOT)

	# If the decoder never starts (common when OGV fails silently), skip quickly.
	# poll_ref[0] holds the lambda so the lambda can reference itself via poll_ref[0].
	var started_ms := Time.get_ticks_msec()
	var poll_ref: Array[Callable] = [Callable()]
	poll_ref[0] = func() -> void:
		if done[0] or not is_instance_valid(player):
			return
		if player.is_playing():
			return
		if Time.get_ticks_msec() - started_ms > 2500:
			finish.call()
			return
		owner.get_tree().create_timer(0.25).timeout.connect(poll_ref[0], CONNECT_ONE_SHOT)
	owner.get_tree().create_timer(0.25).timeout.connect(poll_ref[0], CONNECT_ONE_SHOT)

## Opening-cutscene scene 4: wait for video, skip, or timeout.
static func wait_for_video_or_skip(
	owner: Node,
	player: VideoStreamPlayer,
	is_skip_pressed: Callable,
	fallback_seconds: float = 1.5,
	max_seconds: float = 15.0
) -> void:
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		return

	if not video_supported(player):
		player.visible = false
		await owner.get_tree().create_timer(fallback_seconds).timeout
		return

	player.play()
	var start_ms := Time.get_ticks_msec()
	while true:
		if is_skip_pressed.call():
			break
		if Time.get_ticks_msec() - start_ms > int(max_seconds * 1000.0):
			break
		if not player.is_playing():
			if Time.get_ticks_msec() - start_ms > 2500:
				break
			if player.stream_position > 0.0:
				break
		await owner.get_tree().process_frame
	player.stop()
