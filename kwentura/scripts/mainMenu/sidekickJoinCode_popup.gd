extends PopupPanel

var code_input: LineEdit
var ok_button: Button
var cancel_button: Button

signal code_submitted(code: String)
signal cancelled

func _ready():
	# Find nodes safely
	code_input = find_child("LineEdit", true, false)
	ok_button = find_child("Button", true, false)
	cancel_button = find_child("Button2", true, false)
	
	# Debug print
	print("code_input found: ", code_input != null)
	print("ok_button found: ", ok_button != null)
	print("cancel_button found: ", cancel_button != null)
	
	# Connect with null checks
	if ok_button:
		ok_button.pressed.connect(_on_ok_pressed)
	else:
		push_error("ok_button (Button) not found in popup")
	
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)
	else:
		push_error("cancel_button (Button2) not found in popup")
	
	if code_input:
		code_input.text_changed.connect(_on_text_changed)
		code_input.max_length = 6
	else:
		push_error("code_input (LineEdit) not found in popup")

func _on_text_changed(new_text: String):
	if code_input:
		code_input.text = new_text.to_upper()
		code_input.caret_column = code_input.text.length()

func _on_ok_pressed():
	if not code_input:
		return
		
	var code = code_input.text.strip_edges().to_upper()
	
	if code.length() != 6:
		_show_error("Please enter 6-character code!")
		return
	
	emit_signal("code_submitted", code)
	hide()

func _on_cancel_pressed():
	emit_signal("cancelled")
	hide()

func _show_error(message: String):
	print("Error: ", message)
	if code_input:
		var tween = create_tween()
		tween.tween_property(code_input, "position:x", code_input.position.x + 5, 0.05)
		tween.tween_property(code_input, "position:x", code_input.position.x - 5, 0.05)
		tween.tween_property(code_input, "position:x", code_input.position.x, 0.05)

func reset():
	if code_input:
		code_input.text = ""
		code_input.grab_focus()
