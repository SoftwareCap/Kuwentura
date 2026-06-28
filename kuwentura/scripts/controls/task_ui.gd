## task_ui.gd
extends Node2D

signal task_completed(task_index: int, task_name: String)

const DEFAULT_PANEL_TEXTURE: Texture2D = preload("res://assets/sprites/zoneObjects/storageHut/brownTasks.png")
const OCRA_FONT: FontFile = preload("res://assets/fonts/ocraextended.ttf")
const ARABICA_FONT: FontFile = preload("res://assets/fonts/Arabica.ttf")

const PANEL_BG := Color(0.08, 0.05, 0.03, 0.88)
const PANEL_BORDER := Color(0.88, 0.72, 0.48, 0.95)
const TITLE_COLOR := Color(0.98, 0.94, 0.86, 1.0)
const TASK_COLOR := Color(0.98, 0.96, 0.90, 1.0)
const TASK_DONE_COLOR := Color(0.71, 0.78, 0.68, 1.0)
const TASK_DONE_DIM := Color(1.0, 1.0, 1.0, 0.62)
const BUTTON_BG := Color(0.20, 0.12, 0.06, 0.95)
const BUTTON_BG_HOVER := Color(0.27, 0.17, 0.08, 1.0)
const BUTTON_BG_PRESSED := Color(0.14, 0.08, 0.04, 1.0)
const BUTTON_TEXT := Color(0.99, 0.96, 0.88, 1.0)

@export var panel_title: String = "Tasks"
@export var button_text: String = "Tasks"
@export var panel_texture: Texture2D
@export var panel_size: Vector2 = Vector2(340.0, 300.0)
@export var side_margin: float = 0.0
@export var button_size: Vector2 = Vector2(52.0, 132.0)
@export var button_vertical_ratio: float = 0.5
@export var panel_gap: float = 10.0
@export var top_safe_margin: float = 72.0
@export var bottom_safe_margin: float = 72.0
@export var start_collapsed: bool = true

var _task_names: Array[String] = []
var _completed_tasks: Dictionary = {}
var _task_rows: Array[HBoxContainer] = []
var _task_status_labels: Array[Label] = []
var _task_text_labels: Array[Label] = []

var _task_canvas: CanvasLayer = null
var _task_root: Control = null
var _task_button: Button = null
var _task_button_label: Label = null
var _task_panel: Panel = null
var _title_label: Label = null
var _task_list_container: VBoxContainer = null
var _panel_background: TextureRect = null
var _legacy_panel_sprite: Sprite2D = null


func _ready() -> void:
	_ensure_ui()
	_apply_title()
	_refresh_layout()
	if start_collapsed:
		hide_tasks_panel()
	else:
		show_tasks_panel()

	var viewport := get_viewport()
	if is_instance_valid(viewport) and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)


func set_title(title: String) -> void:
	panel_title = title
	_apply_title()


func set_tasks(task_names: Array) -> void:
	_task_names.clear()
	for task_name in task_names:
		_task_names.append(str(task_name))
	_completed_tasks.clear()
	_rebuild_task_rows()


func complete_task(task_index: int) -> void:
	if task_index < 0 or task_index >= _task_names.size():
		return

	var task_name := _task_names[task_index]
	if bool(_completed_tasks.get(task_name, false)):
		return

	_completed_tasks[task_name] = true
	_update_task_row(task_index)
	task_completed.emit(task_index, task_name)


func complete_task_by_name(task_name: String) -> void:
	var task_index := _task_names.find(task_name)
	if task_index == -1:
		return
	complete_task(task_index)


func reset_tasks() -> void:
	_completed_tasks.clear()
	for i in range(_task_names.size()):
		_update_task_row(i)


func show_tasks_panel() -> void:
	if is_instance_valid(_task_panel):
		_task_panel.visible = true
		_task_panel.mouse_filter = Control.MOUSE_FILTER_STOP


func hide_tasks_panel() -> void:
	if is_instance_valid(_task_panel):
		_task_panel.visible = false
		_task_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func toggle_tasks_panel() -> void:
	if not is_instance_valid(_task_panel):
		return
	if is_instance_valid(_task_button) and _task_button.disabled:
		return
	_task_panel.visible = not _task_panel.visible
	_task_panel.mouse_filter = Control.MOUSE_FILTER_STOP if _task_panel.visible else Control.MOUSE_FILTER_IGNORE

func set_interactable(interactable: bool) -> void:
	if is_instance_valid(_task_button):
		_task_button.disabled = not interactable
		_task_button.mouse_filter = Control.MOUSE_FILTER_STOP if interactable else Control.MOUSE_FILTER_IGNORE
	if not interactable:
		hide_tasks_panel()


func set_ui_visible(ui_visible: bool) -> void:
	if not ui_visible:
		hide_tasks_panel()
	if is_instance_valid(_task_canvas):
		_task_canvas.visible = ui_visible


func _ensure_ui() -> void:
	_legacy_panel_sprite = get_node_or_null("TaskPanel") as Sprite2D
	if is_instance_valid(_legacy_panel_sprite):
		_legacy_panel_sprite.visible = false
	_task_canvas = get_node_or_null("TaskCanvas") as CanvasLayer
	if not is_instance_valid(_task_canvas):
		_task_canvas = CanvasLayer.new()
		_task_canvas.name = "TaskCanvas"
		_task_canvas.layer = 92
		add_child(_task_canvas)

	_task_root = _task_canvas.get_node_or_null("TaskRoot") as Control
	if not is_instance_valid(_task_root):
		_task_root = Control.new()
		_task_root.name = "TaskRoot"
		_task_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_task_canvas.add_child(_task_root)

	_task_button = _task_root.get_node_or_null("TaskButton") as Button
	if not is_instance_valid(_task_button):
		_task_button = Button.new()
		_task_button.name = "TaskButton"
		_task_button.mouse_filter = Control.MOUSE_FILTER_STOP
		_task_root.add_child(_task_button)

	_task_button_label = _task_button.get_node_or_null("TaskButtonLabel") as Label
	if not is_instance_valid(_task_button_label):
		_task_button_label = Label.new()
		_task_button_label.name = "TaskButtonLabel"
		_task_button_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_task_button.add_child(_task_button_label)

	_task_panel = _task_root.get_node_or_null("TaskPanel") as Panel
	if not is_instance_valid(_task_panel):
		_task_panel = Panel.new()
		_task_panel.name = "TaskPanel"
		_task_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_task_panel.clip_contents = true
		_task_root.add_child(_task_panel)

	_panel_background = _task_panel.get_node_or_null("PanelBackground") as TextureRect
	if not is_instance_valid(_panel_background):
		_panel_background = TextureRect.new()
		_panel_background.name = "PanelBackground"
		_panel_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel_background.stretch_mode = TextureRect.STRETCH_SCALE
		_task_panel.add_child(_panel_background)

	var margin := _task_panel.get_node_or_null("Margin") as MarginContainer
	if not is_instance_valid(margin):
		margin = MarginContainer.new()
		margin.name = "Margin"
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_top", 18)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_bottom", 18)
		_task_panel.add_child(margin)

	var content := margin.get_node_or_null("Content") as VBoxContainer
	if not is_instance_valid(content):
		content = VBoxContainer.new()
		content.name = "Content"
		content.add_theme_constant_override("separation", 10)
		margin.add_child(content)

	_title_label = content.get_node_or_null("TitleLabel") as Label
	if not is_instance_valid(_title_label):
		_title_label = Label.new()
		_title_label.name = "TitleLabel"
		content.add_child(_title_label)

	_task_list_container = content.get_node_or_null("TaskListContainer") as VBoxContainer
	if not is_instance_valid(_task_list_container):
		_task_list_container = VBoxContainer.new()
		_task_list_container.name = "TaskListContainer"
		_task_list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_task_list_container.add_theme_constant_override("separation", 8)
		content.add_child(_task_list_container)

	_apply_styles()
	_apply_panel_texture()
	_apply_title()

	if not _task_button.pressed.is_connected(toggle_tasks_panel):
		_task_button.pressed.connect(toggle_tasks_panel)


func _apply_styles() -> void:
	if is_instance_valid(_task_root):
		_task_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		_task_root.offset_left = 0.0
		_task_root.offset_top = 0.0
		_task_root.offset_right = 0.0
		_task_root.offset_bottom = 0.0

	if is_instance_valid(_task_button):
		_task_button.text = ""
		_task_button.focus_mode = Control.FOCUS_NONE
		_task_button.clip_contents = false

		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = BUTTON_BG
		normal_style.border_width_left = 2
		normal_style.border_width_top = 2
		normal_style.border_width_right = 2
		normal_style.border_width_bottom = 2
		normal_style.border_color = PANEL_BORDER
		normal_style.corner_radius_top_left = 0
		normal_style.corner_radius_bottom_left = 0
		normal_style.corner_radius_top_right = 14
		normal_style.corner_radius_bottom_right = 14
		_task_button.add_theme_stylebox_override("normal", normal_style)

		var hover_style := normal_style.duplicate()
		hover_style.bg_color = BUTTON_BG_HOVER
		_task_button.add_theme_stylebox_override("hover", hover_style)

		var pressed_style := normal_style.duplicate()
		pressed_style.bg_color = BUTTON_BG_PRESSED
		_task_button.add_theme_stylebox_override("pressed", pressed_style)

		var disabled_style := normal_style.duplicate()
		disabled_style.bg_color = BUTTON_BG
		_task_button.add_theme_stylebox_override("disabled", disabled_style)

	if is_instance_valid(_task_button_label):
		_task_button_label.text = button_text.to_upper()
		_task_button_label.add_theme_font_override("font", OCRA_FONT)
		_task_button_label.add_theme_font_size_override("font_size", 18)
		_task_button_label.add_theme_color_override("font_color", BUTTON_TEXT)
		_task_button_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_task_button_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	if is_instance_valid(_task_panel):
		_task_panel.clip_contents = true
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = PANEL_BG
		panel_style.border_width_left = 2
		panel_style.border_width_top = 2
		panel_style.border_width_right = 2
		panel_style.border_width_bottom = 2
		panel_style.border_color = PANEL_BORDER
		panel_style.corner_radius_top_left = 18
		panel_style.corner_radius_top_right = 18
		panel_style.corner_radius_bottom_left = 18
		panel_style.corner_radius_bottom_right = 18
		_task_panel.add_theme_stylebox_override("panel", panel_style)

	if is_instance_valid(_title_label):
		_title_label.add_theme_font_override("font", OCRA_FONT)
		_title_label.add_theme_font_size_override("font_size", 20)
		_title_label.add_theme_color_override("font_color", TITLE_COLOR)
		_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _apply_panel_texture() -> void:
	if is_instance_valid(_legacy_panel_sprite):
		_legacy_panel_sprite.visible = false

	if not is_instance_valid(_panel_background):
		return

	var texture_to_use := panel_texture
	if texture_to_use == null and is_instance_valid(_legacy_panel_sprite):
		texture_to_use = _legacy_panel_sprite.texture
	if texture_to_use == null:
		texture_to_use = DEFAULT_PANEL_TEXTURE

	_panel_background.texture = texture_to_use
	_panel_background.visible = texture_to_use != null
	_panel_background.modulate = Color(1.0, 1.0, 1.0, 0.22)
	_panel_background.position = Vector2.ZERO
	_panel_background.size = panel_size


func _apply_title() -> void:
	if is_instance_valid(_title_label):
		_title_label.text = panel_title
	if is_instance_valid(_task_button_label):
		_task_button_label.text = button_text.to_upper()


func _rebuild_task_rows() -> void:
	if not is_instance_valid(_task_list_container):
		return

	for child in _task_list_container.get_children():
		child.queue_free()

	_task_rows.clear()
	_task_status_labels.clear()
	_task_text_labels.clear()

	for task_name in _task_names:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 10)
		_task_list_container.add_child(row)
		_task_rows.append(row)

		var status_label := Label.new()
		status_label.custom_minimum_size = Vector2(28.0, 0.0)
		status_label.add_theme_font_override("font", OCRA_FONT)
		status_label.add_theme_font_size_override("font_size", 18)
		status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(status_label)
		_task_status_labels.append(status_label)

		var task_label := Label.new()
		task_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		task_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		task_label.add_theme_font_override("font", ARABICA_FONT)
		task_label.add_theme_font_size_override("font_size", 20)
		task_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(task_label)
		_task_text_labels.append(task_label)

	for i in range(_task_names.size()):
		_update_task_row(i)


func _update_task_row(task_index: int) -> void:
	if task_index < 0 or task_index >= _task_names.size():
		return
	if task_index >= _task_status_labels.size() or task_index >= _task_text_labels.size():
		return

	var task_name := _task_names[task_index]
	var completed := bool(_completed_tasks.get(task_name, false))
	var status_label := _task_status_labels[task_index]
	var task_label := _task_text_labels[task_index]

	if not is_instance_valid(status_label) or not is_instance_valid(task_label):
		return

	status_label.text = "✓" if completed else "•"
	status_label.add_theme_color_override("font_color", TASK_DONE_COLOR if completed else TITLE_COLOR)
	task_label.text = task_name
	task_label.add_theme_color_override("font_color", TASK_DONE_COLOR if completed else TASK_COLOR)
	task_label.modulate = TASK_DONE_DIM if completed else Color.WHITE


func _refresh_layout() -> void:
	if not is_instance_valid(_task_root):
		return

	var viewport_size := get_viewport_rect().size
	_task_root.size = viewport_size

	var button_y := clampf(
		(viewport_size.y - button_size.y) * button_vertical_ratio,
		top_safe_margin,
		max(top_safe_margin, viewport_size.y - button_size.y - bottom_safe_margin)
	)

	if is_instance_valid(_task_button):
		_task_button.size = button_size
		_task_button.position = Vector2(side_margin, button_y)

	if is_instance_valid(_task_button_label):
		_task_button_label.size = Vector2(button_size.y, button_size.x)
		_task_button_label.position = Vector2(
			(button_size.x - _task_button_label.size.x) * 0.5,
			(button_size.y - _task_button_label.size.y) * 0.5
		)
		_task_button_label.pivot_offset = _task_button_label.size * 0.5
		_task_button_label.rotation_degrees = -90.0

	if is_instance_valid(_task_panel):
		_task_panel.size = panel_size
		var panel_y := clampf(
			button_y + (button_size.y - panel_size.y) * 0.5,
			top_safe_margin,
			max(top_safe_margin, viewport_size.y - panel_size.y - bottom_safe_margin)
		)
		_task_panel.position = Vector2(
			side_margin + button_size.x + panel_gap,
			panel_y
		)

	if is_instance_valid(_panel_background):
		_panel_background.position = Vector2.ZERO
		_panel_background.size = panel_size

	var margin := _task_panel.get_node_or_null("Margin") as MarginContainer
	if is_instance_valid(margin):
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.offset_left = 0.0
		margin.offset_top = 0.0
		margin.offset_right = 0.0
		margin.offset_bottom = 0.0


func _on_viewport_size_changed() -> void:
	_refresh_layout()





