extends RefCounted

var zone


func setup(owner) -> void:
	zone = owner

	if is_instance_valid(zone.consequence_ui):
		zone.consequence_ui.visible = false

	if is_instance_valid(zone.blackout):
		zone.blackout.visible = false

	if is_instance_valid(zone.final_aswang):
		zone.final_aswang.visible = false


func start_server() -> void:
	zone._time_left = zone.TOTAL_TIME_SEC
	zone._attack_index = 0
	zone._failed = false
	zone._first_warning_played = false

	zone._tick_timer = Timer.new()
	zone._tick_timer.wait_time = 1.0
	zone._tick_timer.one_shot = false
	zone.add_child(zone._tick_timer)
	zone._tick_timer.timeout.connect(zone._on_tick_server)
	zone._tick_timer.start()

	zone._first_attack_timer = Timer.new()
	zone._first_attack_timer.wait_time = float(zone.FIRST_ATTACK_DELAY_SEC)
	zone._first_attack_timer.one_shot = true
	zone.add_child(zone._first_attack_timer)
	zone._first_attack_timer.timeout.connect(zone._on_first_attack_server)
	zone._first_attack_timer.start()

	zone._attack_timer = Timer.new()
	zone._attack_timer.wait_time = float(zone.ATTACK_INTERVAL_SEC)
	zone._attack_timer.one_shot = false
	zone.add_child(zone._attack_timer)
	zone._attack_timer.timeout.connect(zone._on_scheduled_attack_server)


func on_first_attack_server() -> void:
	if zone._failed:
		return

	zone._attack_index = 1
	zone.rpc_play_aswang_attack.rpc(zone._attack_index, false)

	if not zone._first_warning_played:
		zone._first_warning_played = true
		zone.rpc_play_first_attack_warning.rpc()

	if is_instance_valid(zone._attack_timer) and zone._attack_timer.is_stopped():
		zone._attack_timer.start()


func play_first_attack_warning() -> void:
	DialogueSystems.play(
		"pinas_house_first_aswang_warning",
		DialogueLibraries.PINAS_HOUSE_FIRST_ASWANG_WARNING,
		true
	)


func on_tick_server() -> void:
	if zone._failed:
		return

	zone._time_left -= 1

	if zone._time_left <= 0:
		zone._time_left = 0
		fail_zone_server()


func on_scheduled_attack_server() -> void:
	if zone._failed:
		return

	zone._attack_index += 1

	if zone._attack_index >= 10:
		fail_zone_server()
		return

	zone.rpc_play_aswang_attack.rpc(zone._attack_index, false)


func apply_penalty_server(_reason: String) -> void:
	if zone._failed:
		return

	zone._attack_index = min(zone._attack_index + 1, zone.MAX_ATTACKS)
	zone.rpc_play_aswang_attack.rpc(zone._attack_index, true)

	zone._time_left = max(0, zone._time_left - zone.PENALTY_SEC)
	if zone._time_left <= 0:
		fail_zone_server()


func play_aswang_attack(idx: int, from_penalty: bool) -> void:
	if idx <= 0:
		return

	if idx >= 10:
		return

	if is_instance_valid(zone.aswang_sprite):
		zone.aswang_sprite.texture = zone._aswang_window_frames[idx - 1]
		zone.aswang_sprite.visible = true

	screen_shake_attack_local(from_penalty)


func fail_zone_server() -> void:
	if zone._failed:
		return

	zone._failed = true

	if is_instance_valid(zone._first_attack_timer):
		zone._first_attack_timer.stop()

	if is_instance_valid(zone._tick_timer):
		zone._tick_timer.stop()

	if is_instance_valid(zone._attack_timer):
		zone._attack_timer.stop()

	zone.rpc_fail_pre_shake.rpc()
	await zone.get_tree().create_timer(0.6, true).timeout

	zone.rpc_fail_show_ui.rpc()
	zone.rpc_reset_pinas_house_progress.rpc()
	zone.rpc_lock_pinas_house_zone.rpc(180)

	await zone.get_tree().create_timer(3.0, true).timeout
	zone.rpc_kick_to_hub.rpc()


func reset_pinas_house_progress_local() -> void:
	GameState.set_puzzle_solved("pinas_house", false)

	if GameState.collected_clues.has("pinas_house"):
		GameState.collected_clues["pinas_house"]["collected"] = false

	zone._tools_unlocked = false
	zone._tools_collected = {
		"pan": false,
		"ladle": false,
		"pot": false
	}
	zone._search_mode = false
	zone._detective_note_seen = false
	zone._note_dialogue_played = false

	if is_instance_valid(zone.search_room_ui):
		zone.search_room_ui.visible = false

	if is_instance_valid(zone.search_btn_detective):
		zone.search_btn_detective.visible = false

	if is_instance_valid(zone.search_btn_sidekick):
		zone.search_btn_sidekick.visible = false

	zone.tool_hunt_controller.apply_tool_nodes()
	zone.tool_hunt_controller.apply_banner_frames()
	zone.note_controller.apply_note_interaction_gate()
	zone.note_controller.apply_close_button_visibility()
	zone.note_controller.close_boards(true)
	zone.note_controller.apply_unsolved_text()


func lock_pinas_house_zone_local(duration_sec: int) -> void:
	print("[LOCK] Setting lock pinas_house for ", duration_sec, "s on peer ", zone.multiplayer.get_unique_id())
	GameState.lock_zone_temp("pinas_house", duration_sec)


func kick_to_hub_local() -> void:
	if is_instance_valid(zone.consequence_ui):
		zone.consequence_ui.visible = false

	if is_instance_valid(zone.blackout):
		zone.blackout.visible = false

	if is_instance_valid(zone.final_aswang):
		zone.final_aswang.visible = false

	zone.get_tree().change_scene_to_file("res://scenes/world/hub/ForestHub.tscn")


func apply_penalty_attack_server() -> void:
	zone._attack_index += 1

	if zone._attack_index >= 10:
		fail_zone_server()
		return

	zone.rpc_play_aswang_attack.rpc(zone._attack_index, true)


func apply_consequence_state(attack_idx: int, time_left: int, failed: bool) -> void:
	zone._attack_index = attack_idx
	zone._time_left = time_left
	zone._failed = failed

	if zone._failed:
		return

	if zone._attack_index >= 1 and zone._attack_index <= 9 and is_instance_valid(zone.aswang_sprite):
		zone.aswang_sprite.texture = zone._aswang_window_frames[zone._attack_index - 1]
		zone.aswang_sprite.visible = true


func play_validation_feedback(dialogue_id: String) -> void:
	screen_shake_extreme_local()
	zone.tool_hunt_controller.play_validation_dialogue(dialogue_id)


func fail_pre_shake() -> void:
	screen_shake_attack_local(true)


func fail_show_ui() -> void:
	if is_instance_valid(zone.consequence_ui):
		zone.consequence_ui.visible = true
		zone.consequence_ui.layer = 100

	if is_instance_valid(zone.blackout):
		zone.blackout.visible = true
		var c: Color = zone.blackout.color
		c.a = 1.0
		zone.blackout.color = c
		zone.blackout.z_index = 0

	if is_instance_valid(zone.final_aswang):
		zone.final_aswang.visible = true
		zone.final_aswang.texture = zone._aswang_final_frame
		zone.final_aswang.z_index = 1


func start_shake(duration: float, amplitude: float, interval: float) -> void:
	zone._shake_duration = duration
	zone._shake_amplitude = amplitude
	zone._shake_elapsed = 0.0
	zone._shake_origin = zone.position

	if zone._shake_timer == null:
		zone._shake_timer = Timer.new()
		zone._shake_timer.one_shot = false
		zone._shake_timer.process_mode = Node.PROCESS_MODE_INHERIT
		zone.add_child(zone._shake_timer)
		zone._shake_timer.timeout.connect(zone._on_final_shake_tick)

	zone._shake_timer.wait_time = interval
	zone._shake_timer.start()


func on_final_shake_tick() -> void:
	zone._shake_elapsed += zone._shake_timer.wait_time

	if zone._shake_elapsed >= zone._shake_duration:
		zone.position = zone._shake_origin
		zone._shake_timer.stop()
		return

	var ox := randf_range(-zone._shake_amplitude, zone._shake_amplitude)
	var oy := randf_range(-zone._shake_amplitude, zone._shake_amplitude)
	zone.position = zone._shake_origin + Vector2(ox, oy)


func screen_shake_local(stronger: bool) -> void:
	var target: Node2D = zone
	var strength := 10.0 if stronger else 6.0

	var original := target.position
	target.position = original + Vector2(randf_range(-strength, strength), randf_range(-strength, strength))

	var tw: Tween = zone.create_tween()
	tw.tween_property(target, "position", original, 0.12)


func screen_shake_final_local() -> void:
	start_shake(5.0, 30.0, 0.03)


func screen_shake_extreme_local() -> void:
	start_shake(0.6, 20.0, 0.02)


func screen_shake_attack_local(from_penalty: bool) -> void:
	var duration := 0.55 if not from_penalty else 0.75
	var amplitude := 20.0 if not from_penalty else 28.0
	start_shake(duration, amplitude, 0.02)


func play_final_aswang_overlay() -> void:
	if is_instance_valid(zone.blackout):
		zone.blackout.visible = true
		var c: Color = zone.blackout.color
		c.a = 0.0
		zone.blackout.color = c

	if is_instance_valid(zone.final_aswang):
		zone.final_aswang.visible = true
		zone.final_aswang.texture = zone._aswang_final_frame

	var tw: Tween = zone.create_tween()
	tw.tween_property(zone.blackout, "color:a", 0.85, 0.25)

	screen_shake_local(true)
