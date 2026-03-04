extends Node
class_name DialogueSystem

signal finished(dialogue_id: String)

@export var dialogue_ui_scene: PackedScene = preload("res://scenes/ui/DialogueBox.tscn")

var _ui: CanvasLayer
var _lines: Array = []
var _index: int = 0
var _dialogue_id: String = ""
var _playing: bool = false

# Add delay for every dialogue
const OPEN_DELAY_SECONDS := 1.0

# If true, dialogue pauses gameplay while it’s open.
const PAUSE_GAME := true


func is_playing() -> bool:
	return _playing


func play(dialogue_id: String, lines: Array, skip_delay: bool = false) -> void:
	# lines format:
	# [{ "speaker": "detective"|"sidekick", "text": "..." }, ...]
	if lines.is_empty():
		return

	_dialogue_id = dialogue_id
	_lines = lines
	_index = 0
	_playing = true

	_ensure_ui()

	# Delay before showing dialogue (global behavior)
	if not skip_delay and OPEN_DELAY_SECONDS > 0.0:
		await get_tree().create_timer(OPEN_DELAY_SECONDS).timeout
	
	# Scene might be gone or dialogue may have been cancelled
	if not is_inside_tree() or not _playing:
		return

	_ui.visible = true

	if PAUSE_GAME:
		get_tree().paused = true

	_show_current()


func next() -> void:
	if not _playing:
		return

	_index += 1
	if _index >= _lines.size():
		stop()
		return

	_show_current()


func stop() -> void:
	if not _playing:
		return

	_playing = false
	_lines = []
	_index = 0

	if is_instance_valid(_ui):
		_ui.visible = false

	if PAUSE_GAME:
		get_tree().paused = false

	emit_signal("finished", _dialogue_id)
	_dialogue_id = ""


func _ensure_ui() -> void:
	if is_instance_valid(_ui):
		return

	_ui = dialogue_ui_scene.instantiate() as CanvasLayer
	get_tree().root.add_child(_ui)

	# bind system to UI so button can call next()
	if _ui.has_method("bind_system"):
		_ui.call("bind_system", self)

	_ui.visible = false


func _show_current() -> void:
	if not is_instance_valid(_ui):
		return

	var entry: Dictionary = _lines[_index]
	var speaker := String(entry.get("speaker", "detective")).to_lower()
	var text := String(entry.get("text", ""))

	if _ui.has_method("set_line"):
		_ui.call("set_line", speaker, text)


func _end_dialogue() -> void:
	_playing = false
	if is_instance_valid(_ui):
		_ui.visible = false

	if PAUSE_GAME:
		get_tree().paused = false

	emit_signal("finished", _dialogue_id)


func wait_finished(expected_id: String) -> void:
	while true:
		var id: String = await finished
		if id == expected_id:
			return
