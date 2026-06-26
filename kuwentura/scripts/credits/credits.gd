extends Node

@onready var credits_list: VBoxContainer = $CanvasLayer/Control/CreditsList

const SCROLL_SPEED: float = 60.0
const FADE_DURATION: float = 1.5

var _scroll_pos: float = 0.0
var _max_scroll: float = 0.0
var _scrolling: bool = false

const CREDITS: Array = [
	{"role": "", "name": ""},
	{"role": "A Game By", "name": ""},
	{"role": "", "name": "Diadem Grace Arroz"},
	{"role": "BS Software Engineering", "name": ""},
	{"role": "", "name": ""},
	{"role": "", "name": "Faith Nina Marie Magsael"},
	{"role": "BS Software Engineering", "name": ""},
	{"role": "", "name": ""},
	{"role": "Story and Design", "name": ""},
	{"role": "", "name": "Diadem Grace Arroz"},
	{"role": "", "name": "Faith Nina Marie Magsael"},
	{"role": "", "name": ""},
	{"role": "Programming", "name": ""},
	{"role": "", "name": "Diadem Grace Arroz"},
	{"role": "BS Software Engineering", "name": ""},
	{"role": "", "name": ""},
	{"role": "", "name": "Faith Nina Marie Magsael"},
	{"role": "BS Software Engineering", "name": ""},
	{"role": "", "name": ""},
	{"role": "Art & Animation", "name": ""},
	{"role": "", "name": "Vhea Asesor"},
	{"role": "", "name": "Danielle Poral"},
	{"role": "", "name": ""},
	{"role": "Music", "name": ""},
	{"role": "", "name": "Diadem Grace Arroz"},
	{"role": "", "name": ""},
	{"role": "Sound Effects", "name": ""},
	{"role": "", "name": "Epidemic Sound"},
	{"role": "", "name": ""},
	{"role": "Special Thanks", "name": ""},
	{"role": "", "name": "To our family"},
	{"role": "", "name": "To our adviser"},
	{"role": "", "name": "To our panels"},
	{"role": "", "name": ""},
	{"role": "", "name": ""},
	{"role": "Thank you for playing,", "name": ""},
	{"role": "", "name": "Detective & Sidekick"},
	{"role": "", "name": ""},
	{"role": "", "name": ""},
]


func _ready() -> void:
	var canvas_layer: CanvasLayer = $CanvasLayer
	var container: Control = $CanvasLayer/Control

	# Background behind everything
	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/mainMenu.png")
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(bg)
	canvas_layer.move_child(bg, 0)

	# Make the Control container fill the screen and clip children
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.clip_contents = true

	# CreditsList centered horizontally
	credits_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits_list.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	_build_credits()

	# Wait for layout to compute
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_max_scroll = credits_list.size.y
	print("DEBUG _max_scroll = ", _max_scroll)  # should be > 0

	# Start credits below the bottom of the screen
	_scroll_pos = 0.0
	credits_list.position.y = get_viewport().size.y
	_scrolling = true
	
	MusicController.play_track(MusicController.MusicTrack.END_CREDITS)

	# Fade in from black
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 1)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new()
	cl.layer = 99
	add_child(cl)
	cl.add_child(black)
	var fade := create_tween()
	fade.tween_property(black, "color:a", 0.0, FADE_DURATION)
	await fade.finished
	cl.queue_free()


func _build_credits() -> void:
	for entry in CREDITS:
		if entry["role"] != "" and entry["name"] != "":
			credits_list.add_child(_make_role_label(entry["role"]))
			credits_list.add_child(_make_name_label(entry["name"]))
		elif entry["role"] != "":
			credits_list.add_child(_make_role_label(entry["role"]))
		elif entry["name"] != "":
			credits_list.add_child(_make_name_label(entry["name"]))
		else:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, 24)
			credits_list.add_child(spacer)


func _make_role_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl


func _make_name_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl


func _process(delta: float) -> void:
	if not _scrolling:
		return

	_scroll_pos += SCROLL_SPEED * delta
	credits_list.position.y = get_viewport().size.y - _scroll_pos

	if credits_list.position.y + _max_scroll < 0:
		_scrolling = false
		_goto_main_menu()


func _goto_main_menu() -> void:
	_scrolling = false
	MusicController.stop_music(1.5)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new()
	cl.layer = 99
	add_child(cl)
	cl.add_child(black)
	var fade := create_tween()
	fade.tween_property(black, "color:a", 1.0, 1.5)
	await fade.finished
	get_tree().change_scene_to_file("res://scenes/mainMenu/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_goto_main_menu()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_goto_main_menu()
