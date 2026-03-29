extends PopupPanel

# CONSTANTS
const CODE_LENGTH := 6
const COLOR_ERROR := Color(1, 0, 0, 1)
const COLOR_NORMAL := Color(1, 1, 1, 1)

# SIGNALS
signal code_submitted(code: String)
signal cancelled

# NODE REFERENCES
# These rely on clearly named nodes in the scene tree.
# If this popup has no scene file, replace with explicit node construction.
var code_input: LineEdit
var ok_button: Button
var cancel_button: Button
var status_label: Label


# LIFECYCLE
func _ready() -> void:
	_resolve_nodes()
	_configure_input()
	_connect_signals()


# SETUP
func _resolve_nodes() -> void:
	"""Locate child nodes and report missing ones clearly."""
	code_input = find_child("LineEdit", true, false)
	ok_button = find_child("Button", true, false)
	cancel_button = find_child("Button2", true, false)
	status_label = find_child("StatusLabel", true, false)

	if not ok_button:
		push_error("[JoinPopup] ok_button (Button) not found")
	if not cancel_button:
		push_error("[JoinPopup] cancel_button (Button2) not found")
	if not code_input:
		push_error("[JoinPopup] code_input (LineEdit) not found")


func _configure_input() -> void:
	"""Set initial state on the code input field."""
	if not code_input:
		return
	code_input.max_length = CODE_LENGTH
	code_input.grab_focus()


func _connect_signals() -> void:
	"""Wire all button and input signals."""
	if ok_button:
		ok_button.pressed.connect(_on_ok_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	if code_input:
		code_input.text_changed.connect(_on_text_changed)


# HANDLERS
func _on_text_changed(new_text: String) -> void:
	if not code_input:
		return
	code_input.text = new_text.to_upper()
	code_input.caret_column = code_input.text.length()


func _on_ok_pressed() -> void:
	if not code_input:
		return
	var code := code_input.text.strip_edges().to_upper()
	if code.length() != CODE_LENGTH:
		_show_error("Please enter %d-character code!" % CODE_LENGTH)
		return
	code_submitted.emit(code)
	hide()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	hide()


func _input(event: InputEvent) -> void:
	if OS.is_debug_build() \
			and event is InputEventKey \
			and event.pressed \
			and event.keycode == KEY_F12:
		code_submitted.emit("LOCAL")
		hide()


# PUBLIC API
func reset() -> void:
	"""Clear input and status for reuse."""
	if code_input:
		code_input.text = ""
		code_input.grab_focus()
	if status_label:
		status_label.text = ""
		status_label.modulate = COLOR_NORMAL


# HELPERS
func _show_error(message: String) -> void:
	"""Display an error message and shake the input field."""
	if status_label:
		status_label.text = message
		status_label.modulate = COLOR_ERROR
	_shake(code_input)


func _shake(node: Control) -> void:
	"""Brief horizontal shake animation to indicate invalid input."""
	if not node:
		return
	var origin := node.position.x
	var tween := create_tween()
	tween.tween_property(node, "position:x", origin + 5, 0.05)
	tween.tween_property(node, "position:x", origin - 5, 0.05)
	tween.tween_property(node, "position:x", origin, 0.05)
