extends RefCounted

## Consequence Controller - Manages the Aswang attack sequence for Pina's House.

const SCENE_FOREST_HUB := "res://scenes/world/hub/ForestHub.tscn"

var zone: Node


func setup(owner: Node) -> void:
	zone = owner
	_hide_overlays()


func start_server() -> void:
	zone._consequence_active = true
	zone._failed = false
	zone._attack_index = 0
	zone._strikes_left = zone.MAX_ATTACKS
	zone._penalty_on_cooldown = false


func apply_penalty_server(reason: String) -> void:
	zone._apply_strike_server(reason)


func play_aswang_attack(idx: int, from_penalty: bool) -> void:
	_show_aswang_frame(idx)
	screen_shake_attack_local(from_penalty)


func fail_zone_server() -> void:
	if zone._failed:
		return
	zone._failed = true
	zone._consequence_active = false
	zone._penalty_on_cooldown = false

	zone.rpc_fail_pre_shake.rpc()
	await zone.get_tree().create_timer(0.6, true).timeout
	zone.rpc_fail_show_ui.rpc()
	zone.rpc_reset_pinas_house_progress.rpc()
	zone.rpc_lock_pinas_house_zone.rpc(30)
	await zone.get_tree().create_timer(3.0, true).timeout
	zone.rpc_kick_to_hub.rpc()


func reset_pinas_house_progress_local() -> void:
	GameState.set_puzzle_solved("pinas_house", false)
	if GameState.collected_clues.has("pinas_house"):
		GameState.collected_clues["pinas_house"]["collected"] = false

	zone._zone_active = false
	zone._tool_phase_active = false
	zone._note_phase_active = false
	zone._cabinet_phase_active = false
	zone._reward_active = false
	zone._tools_unlocked = false
	zone._tools_collected = {"pan": false, "ladle": false, "pot": false}
	zone._note_solved = false
	zone._detective_note_seen = false
	zone._note_dialogue_played = false
	zone._ledger_hint_shown = false
	zone._ledger_opened_once = false
	zone._consequence_active = false
	zone._strikes_left = zone.MAX_ATTACKS
	zone._attack_index = 0
	zone._failed = false
	zone._penalty_on_cooldown = false

	if is_instance_valid(zone.search_room_ui):
		zone.search_room_ui.visible = false

	zone._hide_note()
	zone._hide_cabinet_reward_state()
	zone.tool_hunt_controller.apply_tool_nodes()
	zone.tool_hunt_controller.apply_banner_frames()
	zone.note_controller.apply_note_interaction_gate()
	zone.note_controller.close_boards(true)
	zone.note_controller.apply_unsolved_text()


func lock_pinas_house_zone_local(duration_sec: int) -> void:
	GameState.lock_zone_temp("pinas_house", duration_sec)


func kick_to_hub_local() -> void:
	_hide_overlays()
	# Unpause the tree before changing scene so the sidekick
	# doesn't freeze mid-transition on a paused tree.
	zone.get_tree().paused = false
	await zone.get_tree().process_frame
	if zone.is_inside_tree():
		GameState.change_to_post_zone_scene(zone.get_tree())


func apply_consequence_state(attack_idx: int, strikes_left: int, failed: bool) -> void:
	zone._attack_index = attack_idx
	zone._strikes_left = strikes_left
	zone._failed = failed
	if not zone._failed:
		_show_aswang_frame(attack_idx)


func play_validation_feedback(_dialogue_id: String) -> void:
	screen_shake_extreme_local()
	zone.show_notification("Every mistake makes the Aswang grow restless.", 2.2)


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
	var strength := 10.0 if stronger else 6.0
	var original: Vector2 = zone.position
	zone.position = original + Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	var tw := zone.create_tween()
	tw.tween_property(zone, "position", original, 0.12)


func screen_shake_extreme_local() -> void:
	start_shake(0.6, 20.0, 0.02)


func screen_shake_attack_local(from_penalty: bool) -> void:
	var duration := 0.75 if from_penalty else 0.55
	var amplitude := 28.0 if from_penalty else 20.0
	start_shake(duration, amplitude, 0.02)


func _hide_overlays() -> void:
	if is_instance_valid(zone.consequence_ui):
		zone.consequence_ui.visible = false
	if is_instance_valid(zone.blackout):
		zone.blackout.visible = false
	if is_instance_valid(zone.final_aswang):
		zone.final_aswang.visible = false


func _show_aswang_frame(idx: int) -> void:
	if idx < 1 or idx > 9:
		return
	if is_instance_valid(zone.aswang_sprite):
		zone.aswang_sprite.texture = zone._aswang_window_frames[idx - 1]
		zone.aswang_sprite.visible = true
