extends Node2D

const FOREST_HUB_SCENE_PATH := "res://scenes/world/hub/ForestHub.tscn"

const ZONE_ID := "abandoned_house"
const SUB_PUZZLE_ID := "abandoned_house_books"

const BOOK_ORDER_TOP_TO_BOTTOM := ["book_4", "book_3", "book_2", "book_1"]
const BOOK_START_ORDER := ["book_2", "book_4", "book_1", "book_3"]
const REWARD_ITEMS := ["key_fragment_1", "card_piece"]

const MEMORY_PUZZLE_ID := "abandoned_house_memory"
const MEMORY_FACE_IDS := ["face_1", "face_2", "face_3", "face_4", "face_5", "face_6"]
const MEMORY_REWARD_ITEMS := ["key_fragment_2", "light_bulb"]

# Keeps the puzzle more responsive on different screen sizes.
const BOOK_WIDTH_RATIOS := {
	"book_1": 0.58,
	"book_2": 0.51,
	"book_3": 0.44,
	"book_4": 0.37
}

const BOOK_STACK_GAP := 6.0

const BOOK_CROP_REGIONS := {
	"book_1": Rect2(101, 801, 1719, 172),
	"book_2": Rect2(174, 635, 1599, 215),
	"book_3": Rect2(241, 492, 1466, 145),
	"book_4": Rect2(322, 312, 1304, 182)
}

@export var key_fragment_2_texture: Texture2D
@export var lighter_texture: Texture2D

@export var book_1_texture: Texture2D
@export var book_2_texture: Texture2D
@export var book_3_texture: Texture2D
@export var book_4_texture: Texture2D

@export var memory_card_back_texture: Texture2D
@export var memory_card_1_texture: Texture2D
@export var memory_card_2_texture: Texture2D
@export var memory_card_3_texture: Texture2D
@export var memory_card_4_texture: Texture2D
@export var memory_card_5_texture: Texture2D
@export var memory_card_6_texture: Texture2D

@export var key_fragment_1_texture: Texture2D
@export var card_piece_texture: Texture2D

@export var mirror_not_lighted_texture: Texture2D
@export var mirror_lighted_with_fp_texture: Texture2D
@export var mirror_lighted_no_fp_texture: Texture2D
@export var lighted_room_texture: Texture2D

@onready var mirror_area: Area2D = $InteractiveLayer/MirrorArea
@onready var bedroom_background: Sprite2D = $BackgroundLayer/BedroomBackground

@onready var mirror_puzzle_panel: PanelContainer = $PuzzleCanvasLayer/Dimmer/MirrorPuzzlePanel
@onready var mirror_instruction_label: Label = $PuzzleCanvasLayer/Dimmer/MirrorPuzzlePanel/MarginContainer/VBoxContainer/InstructionLabel
@onready var mirror_texture_rect: TextureRect = $PuzzleCanvasLayer/Dimmer/MirrorPuzzlePanel/MarginContainer/VBoxContainer/MirrorHolder/MirrorTexture
@onready var lamp_hotspot: TextureButton = $PuzzleCanvasLayer/Dimmer/MirrorPuzzlePanel/MarginContainer/VBoxContainer/MirrorHolder/LampHotspot
@onready var close_mirror_button: Button = $PuzzleCanvasLayer/Dimmer/MirrorPuzzlePanel/MarginContainer/VBoxContainer/BottomBar/CloseMirrorButton

@onready var inside_zone_control = $InsideZoneControl

@onready var puzzle_area: Area2D = $InteractiveLayer/PuzzleArea

@onready var memory_puzzle_panel: PanelContainer = $PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel
@onready var memory_instruction_label: Label = $PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel/MarginContainer/VBoxContainer/InstructionLabel
@onready var missing_card_preview: TextureRect = $PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel/MarginContainer/VBoxContainer/MissingRow/MissingCardPreview
@onready var memory_grid: GridContainer = $PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel/MarginContainer/VBoxContainer/MemoryGrid
@onready var close_memory_button: Button = $PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel/MarginContainer/VBoxContainer/CloseMemoryButton
@onready var missing_row: HBoxContainer = get_node_or_null("PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel/MarginContainer/VBoxContainer/MissingRow")

@onready var role_label: Label = %RoleLabel
@onready var back_button: Button = $BackButton
@onready var notification_label: Label = $NotificationLabel

@onready var books_area: Area2D = $InteractiveLayer/BooksArea

@onready var dimmer: ColorRect = $PuzzleCanvasLayer/Dimmer
@onready var books_puzzle_panel: PanelContainer = $PuzzleCanvasLayer/Dimmer/BooksPuzzlePanel
@onready var instruction_label: Label = $PuzzleCanvasLayer/Dimmer/BooksPuzzlePanel/MarginContainer/VBoxContainer/InstructionLabel
@onready var puzzle_board: Control = $PuzzleCanvasLayer/Dimmer/BooksPuzzlePanel/MarginContainer/VBoxContainer/PuzzleBoard
@onready var close_puzzle_button: Button = $PuzzleCanvasLayer/Dimmer/BooksPuzzlePanel/MarginContainer/VBoxContainer/ClosePuzzleButton

@onready var reward_dimmer: ColorRect = $RewardCanvasLayer/RewardDimmer
@onready var reward_panel: PanelContainer = $RewardCanvasLayer/RewardPanel
@onready var reward_title_label: Label = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer/RewardTitleLabel
@onready var reward_body_label: Label = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer/RewardBodyLabel
@onready var collect_reward_button: Button = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer/CollectClueButton

@onready var reward_vbox: VBoxContainer = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer
@onready var reward_items_row: HBoxContainer = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer/RewardItemsRow
@onready var key_item: VBoxContainer = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer/RewardItemsRow/KeyItem
@onready var key_texture_rect: TextureRect = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer/RewardItemsRow/KeyItem/KeyTexture
@onready var card_item: VBoxContainer = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer/RewardItemsRow/CardItem
@onready var card_texture_rect: TextureRect = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer/RewardItemsRow/CardItem/CardTexture
@onready var collect_clue_button: Button = $RewardCanvasLayer/RewardPanel/MarginContainer/VBoxContainer/CollectClueButton

const MIRROR_PUZZLE_ID := "abandoned_house_mirror_lit"

var _mirror_lit: bool = false
var _default_room_texture: Texture2D

var _book_textures: Dictionary = {}
var _book_nodes: Dictionary = {}
var _book_order: Array[String] = []

var _books_solved: bool = false

var _pending_reward_items: Array[String] = []

var _drag_book_id: String = ""
var _drag_pointer_offset_y: float = 0.0
var _notification_token: int = 0

var _memory_face_textures: Dictionary = {}
var _memory_deck: Array[String] = []
var _memory_buttons: Array[TextureButton] = []
var _memory_selected_indices: Array[int] = []
var _memory_matched_indices: Dictionary = {}
var _memory_busy: bool = false
var _memory_unlocked: bool = false
var _memory_solved: bool = false

func _ready() -> void:
	_book_textures = {
		"book_1": book_1_texture,
		"book_2": book_2_texture,
		"book_3": book_3_texture,
		"book_4": book_4_texture,
	}
	
	_memory_face_textures = {
		"face_1": memory_card_1_texture,
		"face_2": memory_card_2_texture,
		"face_3": memory_card_3_texture,
		"face_4": memory_card_4_texture,
		"face_5": memory_card_5_texture,
		"face_6": memory_card_6_texture,
	}
	
	_setup_ui()
	_setup_reward_preview()
	_setup_memory_ui()
	_connect_signals()
	_refresh_role_label()
	_load_books_progress()
	_load_memory_progress()
	
	_default_room_texture = bedroom_background.texture
	_setup_mirror_ui()
	_load_mirror_progress()

	await get_tree().process_frame
	_resize_books_popup()
	_prepare_books()

func _setup_ui() -> void:
	if has_node("TestLabel"):
		$TestLabel.visible = false

	notification_label.visible = false

	instruction_label.text = "Drag the books to arrange them by width.\nNarrowest should be on top and widest should be at the bottom."

	dimmer.visible = false
	books_puzzle_panel.visible = false
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	books_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	reward_dimmer.visible = false
	reward_panel.visible = false
	reward_items_row.visible = false
	reward_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _setup_reward_preview() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	var panel_width: float = clampf(viewport_size.x * 0.42, 480.0, 620.0)
	var panel_height: float = clampf(viewport_size.y * 0.40, 300.0, 380.0)

	reward_panel.set_anchors_preset(Control.PRESET_CENTER)
	reward_panel.size = Vector2(panel_width, panel_height)
	reward_panel.position = (viewport_size - reward_panel.size) * 0.5

	reward_items_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_items_row.add_theme_constant_override("separation", 16)

	key_item.custom_minimum_size = Vector2(140, 100)
	card_item.custom_minimum_size = Vector2(140, 140)

	key_item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	key_item.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_item.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_item.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_fit_reward_texture(key_texture_rect, Vector2(110, 70))
	_fit_reward_texture(card_texture_rect, Vector2(110, 110))

	if key_fragment_1_texture:
		key_texture_rect.texture = _make_cropped_key_texture(key_fragment_1_texture)

	if card_piece_texture:
		card_texture_rect.texture = card_piece_texture


func _connect_signals() -> void:
	if not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)

	if not books_area.input_event.is_connected(_on_books_area_input_event):
		books_area.input_event.connect(_on_books_area_input_event)

	if not close_puzzle_button.pressed.is_connected(_on_close_puzzle_button_pressed):
		close_puzzle_button.pressed.connect(_on_close_puzzle_button_pressed)

	if not collect_reward_button.pressed.is_connected(_on_collect_reward_button_pressed):
		collect_reward_button.pressed.connect(_on_collect_reward_button_pressed)
		
	if not puzzle_area.input_event.is_connected(_on_puzzle_area_input_event):
		puzzle_area.input_event.connect(_on_puzzle_area_input_event)

	if not close_memory_button.pressed.is_connected(_on_close_memory_button_pressed):
		close_memory_button.pressed.connect(_on_close_memory_button_pressed)

	if not mirror_area.input_event.is_connected(_on_mirror_area_input_event):
		mirror_area.input_event.connect(_on_mirror_area_input_event)

	if not close_mirror_button.pressed.is_connected(_on_close_mirror_button_pressed):
		close_mirror_button.pressed.connect(_on_close_mirror_button_pressed)

	if not lamp_hotspot.pressed.is_connected(_on_lamp_hotspot_pressed):
		lamp_hotspot.pressed.connect(_on_lamp_hotspot_pressed)

func _refresh_role_label() -> void:
	var role_text := "Unknown"

	match GameState.local_role:
		GameState.Role.DETECTIVE:
			role_text = "DETECTIVE (Host)"
		GameState.Role.SIDEKICK:
			role_text = "SIDEKICK (Client)"
		_:
			role_text = "NO ROLE ASSIGNED"

	role_label.text = "Role: " + role_text

	if inside_zone_control and inside_zone_control.has_method("set_sidekick_ui_visible"):
		inside_zone_control.set_sidekick_ui_visible(_is_local_sidekick())


func _load_books_progress() -> void:
	if GameState and GameState.has_method("is_puzzle_solved"):
		_books_solved = GameState.is_puzzle_solved(SUB_PUZZLE_ID)
	else:
		_books_solved = false


func _prepare_books() -> void:
	if _book_order.is_empty():
		var source_order: Array = BOOK_ORDER_TOP_TO_BOTTOM if _books_solved else BOOK_START_ORDER
		_set_book_order_from(source_order)

	_build_book_nodes()
	_layout_books()

func _build_book_nodes() -> void:
	if not _book_nodes.is_empty():
		return

	for raw_book_id in BOOK_ORDER_TOP_TO_BOTTOM:
		var book_id: String = str(raw_book_id)
		var texture: Texture2D = _create_cropped_book_texture(book_id)

		if texture == null:
			push_warning("[AbandonedHouse] Missing texture for %s" % book_id)
			continue

		var book_rect: TextureRect = TextureRect.new()
		book_rect.name = book_id
		book_rect.texture = texture
		book_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		book_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		book_rect.stretch_mode = TextureRect.STRETCH_SCALE
		book_rect.gui_input.connect(_on_book_gui_input.bind(book_id))

		puzzle_board.add_child(book_rect)
		_book_nodes[book_id] = book_rect

func _create_cropped_book_texture(book_id: String) -> Texture2D:
	var source_texture: Texture2D = _book_textures.get(book_id, null) as Texture2D
	if source_texture == null:
		return null

	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = source_texture
	atlas.region = BOOK_CROP_REGIONS[book_id] as Rect2
	return atlas

func _refresh_books_view_state() -> void:
	if GameState and GameState.has_method("is_puzzle_solved"):
		_books_solved = GameState.is_puzzle_solved(SUB_PUZZLE_ID)

	if _books_solved:
		_set_book_order_from(BOOK_ORDER_TOP_TO_BOTTOM)
	else:
		_set_book_order_from(BOOK_START_ORDER)

	_layout_books()

func _on_books_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _is_primary_press_event(event):
		return

	_refresh_books_view_state()
	_open_books_panel()

	if not _books_solved and not _is_local_detective():
		_show_notification("Only the Detective can rearrange these books.")

func _refresh_books_panel_for_role() -> void:
	instruction_label.visible = _is_local_detective() and not _books_solved

	if _is_local_detective():
		close_puzzle_button.text = "Back"
	else:
		close_puzzle_button.text = "Close"

func _open_books_panel() -> void:
	_set_books_panel_visible(true)
	_refresh_books_panel_for_role()
	await get_tree().process_frame
	_resize_books_popup()
	await get_tree().process_frame
	_layout_books()


func _close_books_panel() -> void:
	if _drag_book_id != "":
		_finish_drag()

	_set_books_panel_visible(false)


func _set_books_panel_visible(visible_state: bool) -> void:
	dimmer.visible = visible_state
	books_puzzle_panel.visible = visible_state

	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP if visible_state else Control.MOUSE_FILTER_IGNORE
	books_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_STOP if visible_state else Control.MOUSE_FILTER_IGNORE


func _on_close_puzzle_button_pressed() -> void:
	_close_books_panel()


func _on_book_gui_input(event: InputEvent, book_id: String) -> void:
	if _books_solved:
		return

	if not _is_local_detective():
		return

	if not books_puzzle_panel.visible:
		return

	if _is_primary_press_event(event):
		_begin_drag(book_id, _get_event_position(event))


func _input(event: InputEvent) -> void:
	if _drag_book_id == "":
		return

	if event is InputEventScreenDrag:
		_update_drag(event.position)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_drag(event.position)
	elif event is InputEventScreenTouch and not event.pressed:
		_finish_drag()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag()


func _begin_drag(book_id: String, screen_position: Vector2) -> void:
	if not _book_nodes.has(book_id):
		return

	var book_node: TextureRect = _book_nodes[book_id]
	_drag_book_id = book_id

	var local_pointer := book_node.get_global_transform_with_canvas().affine_inverse() * screen_position
	_drag_pointer_offset_y = local_pointer.y

	book_node.z_index = 50
	book_node.modulate = Color(1.0, 0.96, 0.86, 1.0)
	book_node.move_to_front()

func _update_drag(screen_position: Vector2) -> void:
	if _drag_book_id == "":
		return

	var book_node: TextureRect = _book_nodes[_drag_book_id] as TextureRect
	var board_local: Vector2 = puzzle_board.get_global_transform_with_canvas().affine_inverse() * screen_position

	var clamped_y: float = clampf(
		board_local.y - _drag_pointer_offset_y,
		0.0,
		maxf(0.0, puzzle_board.size.y - book_node.size.y)
	)

	book_node.position.y = clamped_y
	book_node.position.x = _get_centered_x(book_node.size.x)


func _finish_drag() -> void:
	if _drag_book_id == "":
		return

	var dragged_id: String = _drag_book_id
	var dragged_node: TextureRect = _book_nodes[dragged_id] as TextureRect

	var target_index: int = _get_nearest_slot_index(dragged_node.position.y + (dragged_node.size.y * 0.5))
	var current_index: int = _book_order.find(dragged_id)

	if current_index != -1 and target_index != -1 and current_index != target_index:
		_book_order.remove_at(current_index)
		_book_order.insert(target_index, dragged_id)

	dragged_node.z_index = 0
	dragged_node.modulate = Color.WHITE

	_drag_book_id = ""
	_drag_pointer_offset_y = 0.0

	_layout_books()
	_check_books_solution()
	
func _layout_books() -> void:
	var current_y: float = _get_stack_start_y()

	for i in range(_book_order.size()):
		var book_id: String = _book_order[i]
		if not _book_nodes.has(book_id):
			continue

		var book_node: TextureRect = _book_nodes[book_id] as TextureRect
		var target_size: Vector2 = _get_book_display_size(book_id)

		book_node.size = target_size
		book_node.position = Vector2(
			_get_centered_x(target_size.x),
			current_y
		)

		if _drag_book_id != book_id:
			book_node.z_index = i

		current_y += target_size.y + BOOK_STACK_GAP

func _get_book_display_size(book_id: String) -> Vector2:
	var crop_region: Rect2 = BOOK_CROP_REGIONS[book_id] as Rect2
	var board_width: float = maxf(1.0, _get_effective_board_size().x)
	var target_width: float = board_width * float(BOOK_WIDTH_RATIOS[book_id])
	var aspect_ratio: float = crop_region.size.y / crop_region.size.x
	var target_height: float = target_width * aspect_ratio

	return Vector2(target_width, target_height)


func _get_centered_x(content_width: float) -> float:
	return (_get_effective_board_size().x - content_width) * 0.5

func _get_slot_top_y(index: int, _book_height: float) -> float:
	var y: float = _get_stack_start_y()

	for i in range(index):
		var previous_id: String = _book_order[i]
		y += _get_book_display_size(previous_id).y + BOOK_STACK_GAP

	return y

func _get_nearest_slot_index(book_center_y: float) -> int:
	var nearest_index: int = 0
	var nearest_distance: float = INF

	for i in range(_book_order.size()):
		var slot_book_id: String = _book_order[i]
		var slot_size: Vector2 = _get_book_display_size(slot_book_id)
		var slot_center_y: float = _get_slot_top_y(i, slot_size.y) + (slot_size.y * 0.5)
		var distance_to_slot: float = absf(book_center_y - slot_center_y)

		if distance_to_slot < nearest_distance:
			nearest_distance = distance_to_slot
			nearest_index = i

	return nearest_index


func _check_books_solution() -> void:
	if _book_order.size() != BOOK_ORDER_TOP_TO_BOTTOM.size():
		return

	for i in range(BOOK_ORDER_TOP_TO_BOTTOM.size()):
		if _book_order[i] != BOOK_ORDER_TOP_TO_BOTTOM[i]:
			return

	_complete_books_puzzle()


func _complete_books_puzzle() -> void:
	if _books_solved:
		return

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_sync_books_puzzle_solved_rpc.rpc()
	else:
		_apply_books_puzzle_solved()


@rpc("authority", "reliable", "call_local")
func _sync_books_puzzle_solved_rpc() -> void:
	_apply_books_puzzle_solved()


func _apply_books_puzzle_solved() -> void:
	if _books_solved:
		return

	_books_solved = true
	_set_book_order_from(BOOK_ORDER_TOP_TO_BOTTOM)
	_layout_books()

	if GameState and GameState.has_method("set_puzzle_solved"):
		GameState.set_puzzle_solved(SUB_PUZZLE_ID, true)

	# IMPORTANT:
	# Do NOT grant the reward items here anymore.
	# We only grant them after the sidekick presses Collect Clue.

	_close_books_panel()
	_show_books_reward_panel()


func _resize_books_popup() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size

	var panel_width: float = clampf(viewport_size.x * 0.62, 700.0, 980.0)
	var panel_height: float = clampf(viewport_size.y * 0.58, 360.0, 620.0)

	books_puzzle_panel.size = Vector2(panel_width, panel_height)
	books_puzzle_panel.position = (viewport_size - books_puzzle_panel.size) * 0.5

	var board_width: float = panel_width - 80.0
	var board_height: float = panel_height - 170.0

	puzzle_board.custom_minimum_size = Vector2(
		maxf(560.0, board_width),
		maxf(180.0, board_height)
	)

func _show_books_reward_panel() -> void:
	_pending_reward_items.clear()
	_pending_reward_items.append_array(REWARD_ITEMS)
	reward_title_label.text = "Puzzle Solved"
	reward_body_label.text = "You found Key Fragment 1 and the Card Piece."

	reward_items_row.visible = true
	key_texture_rect.visible = true
	card_texture_rect.visible = true

	if key_fragment_1_texture:
		key_texture_rect.texture = _make_cropped_key_texture(key_fragment_1_texture)

	if card_piece_texture:
		card_texture_rect.texture = card_piece_texture

	collect_reward_button.text = "Collect Clue"
	collect_reward_button.visible = _is_local_sidekick()

	reward_dimmer.visible = true
	reward_panel.visible = true

	reward_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func _hide_reward_panel() -> void:
	_pending_reward_items.clear()
	reward_dimmer.visible = false
	reward_panel.visible = false
	reward_items_row.visible = false

	reward_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _auto_close_reward_panel() -> void:
	await get_tree().create_timer(1.5).timeout

	if _is_local_detective() and reward_panel.visible:
		_hide_reward_panel()


func _on_collect_reward_button_pressed() -> void:
	if not _is_local_sidekick():
		return

	if _pending_reward_items.is_empty():
		_hide_reward_panel()
		return

	if multiplayer.has_multiplayer_peer():
		_collect_reward_items_rpc.rpc(_pending_reward_items)
	else:
		_collect_reward_items_rpc(_pending_reward_items)

@rpc("any_peer", "reliable", "call_local")
func _collect_reward_items_rpc(item_ids: Array) -> void:
	if GameState and GameState.has_method("grant_zone_items"):
		GameState.grant_zone_items(ZONE_ID, item_ids)

	_hide_reward_panel()

@rpc("any_peer", "reliable", "call_local")
func _collect_books_reward_rpc() -> void:
	if GameState and GameState.has_method("grant_zone_items"):
		GameState.grant_zone_items(ZONE_ID, REWARD_ITEMS)

	_hide_reward_panel()


func _show_notification(message: String, duration: float = 1.8) -> void:
	_notification_token += 1
	var token := _notification_token

	notification_label.text = message
	notification_label.visible = true

	await get_tree().create_timer(duration).timeout

	if token == _notification_token and is_instance_valid(notification_label):
		notification_label.visible = false


func _is_local_detective() -> bool:
	if not GameState:
		return false

	return GameState.local_role == GameState.Role.DETECTIVE

func _is_local_sidekick() -> bool:
	if not GameState:
		return false

	return GameState.local_role == GameState.Role.SIDEKICK

func _is_primary_press_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_LEFT and event.pressed

	if event is InputEventScreenTouch:
		return event.pressed

	return false


func _get_event_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return event.position

	if event is InputEventScreenTouch:
		return event.position

	if event is InputEventScreenDrag:
		return event.position

	if event is InputEventMouseMotion:
		return event.position

	return Vector2.ZERO


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(FOREST_HUB_SCENE_PATH)

func _set_book_order_from(source_order: Array) -> void:
	_book_order.clear()

	for item in source_order:
		_book_order.append(str(item))

func _get_effective_board_size() -> Vector2:
	if puzzle_board.size.x > 0.0 and puzzle_board.size.y > 0.0:
		return puzzle_board.size

	return puzzle_board.custom_minimum_size
	
func _get_stack_start_y() -> float:
	var total_height: float = 0.0

	for raw_book_id in _book_order:
		var book_id: String = str(raw_book_id)
		total_height += _get_book_display_size(book_id).y

	if _book_order.size() > 1:
		total_height += BOOK_STACK_GAP * float(_book_order.size() - 1)

	var board_height: float = _get_effective_board_size().y
	return maxf(12.0, (board_height - total_height) * 0.5)
	
func _fit_reward_texture(texture_rect: TextureRect, target_size: Vector2) -> void:
	texture_rect.custom_minimum_size = target_size
	texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _make_cropped_key_texture(source_texture: Texture2D) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = source_texture
	atlas.region = Rect2(40, 370, 760, 420)
	return atlas

func _setup_memory_ui() -> void:
	if not memory_puzzle_panel:
		push_warning("MemoryPuzzlePanel not found.")
		return

	memory_puzzle_panel.visible = false
	memory_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := get_node_or_null("PuzzleCanvasLayer/Dimmer/MemoryPuzzlePanel/MarginContainer") as MarginContainer
	if margin:
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_bottom", 8)

	if memory_instruction_label:
		memory_instruction_label.visible = false

	if memory_grid:
		memory_grid.columns = 4
		memory_grid.visible = true
		memory_grid.add_theme_constant_override("h_separation", 4)
		memory_grid.add_theme_constant_override("v_separation", 4)

	if close_memory_button:
		close_memory_button.visible = true
		close_memory_button.text = "Back"
		close_memory_button.custom_minimum_size = Vector2(170, 42)
	
func _load_memory_progress() -> void:
	if GameState and GameState.has_method("is_puzzle_solved"):
		_memory_solved = GameState.is_puzzle_solved(MEMORY_PUZZLE_ID)
	else:
		_memory_solved = false

	_memory_unlocked = _memory_solved
	
func _on_puzzle_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _is_primary_press_event(event):
		return

	if not _is_local_sidekick():
		_show_notification("Only the Sidekick can solve this card puzzle.")
		return

	_open_memory_panel()
	
func _open_memory_panel() -> void:
	_set_memory_panel_visible(true)
	_refresh_memory_panel_state()
	await get_tree().process_frame
	_resize_memory_popup()

	if _memory_unlocked:
		_rebuild_memory_grid_unlocked()
	else:
		_rebuild_memory_grid_locked()
		
func _close_memory_panel() -> void:
	_set_memory_panel_visible(false)
	
func _set_memory_panel_visible(visible_state: bool) -> void:
	dimmer.visible = visible_state
	memory_puzzle_panel.visible = visible_state

	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP if visible_state else Control.MOUSE_FILTER_IGNORE
	memory_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_STOP if visible_state else Control.MOUSE_FILTER_IGNORE
	
func _on_close_memory_button_pressed() -> void:
	_close_memory_panel()

func _refresh_memory_panel_state() -> void:
	if _memory_solved:
		memory_instruction_label.text = "You already solved this card puzzle."
		if memory_grid:
			memory_grid.visible = true
		return

	if _memory_unlocked:
		memory_instruction_label.text = "Flip the cards and match each pair."
		if memory_grid:
			memory_grid.visible = true
		return

	memory_instruction_label.text = "Open the briefcase, select the Card Piece, press Use, then tap the empty slot."

	if memory_grid:
		memory_grid.visible = true

func _resize_memory_popup() -> void:
	if not memory_puzzle_panel:
		return

	var viewport_size: Vector2 = get_viewport_rect().size

	# Square container for mobile landscape
	var panel_side: float = clampf(minf(viewport_size.x, viewport_size.y) * 0.72, 520.0, 620.0)

	memory_puzzle_panel.size = Vector2(panel_side, panel_side)
	memory_puzzle_panel.position = (viewport_size - memory_puzzle_panel.size) * 0.5

	if memory_grid:
		var card_w := 88.0
		var card_h := 118.0
		var h_sep := 4.0
		var v_sep := 4.0

		var grid_width := (card_w * 4.0) + (h_sep * 3.0)
		var grid_height := (card_h * 3.0) + (v_sep * 2.0)

		memory_grid.custom_minimum_size = Vector2(grid_width, grid_height)
		memory_grid.size = Vector2(grid_width, grid_height)
		memory_grid.position = Vector2(
			(panel_side - grid_width) * 0.5,
			28.0
		)

	if close_memory_button:
		var button_size := Vector2(170, 42)
		close_memory_button.size = button_size
		close_memory_button.position = Vector2(
			(panel_side - button_size.x) * 0.5,
			panel_side - button_size.y - 18.0
		)
	
func _has_card_piece() -> bool:
	return GameState and GameState.has_method("has_zone_item") and GameState.has_zone_item(ZONE_ID, "card_piece")
	
func _clear_memory_grid() -> void:
	for child in memory_grid.get_children():
		child.queue_free()

	_memory_buttons.clear()
	
	
func _rebuild_memory_grid_locked() -> void:
	_clear_memory_grid()

	if memory_grid:
		memory_grid.columns = 4

	for i in range(12):
		if i == 0:
			var missing_slot := TextureButton.new()
			missing_slot.custom_minimum_size = Vector2(105, 145)
			missing_slot.ignore_texture_size = true
			missing_slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			missing_slot.texture_normal = null
			missing_slot.texture_pressed = null
			missing_slot.texture_hover = null
			missing_slot.modulate = Color(1, 1, 1, 0.0)
			missing_slot.focus_mode = Control.FOCUS_NONE
			missing_slot.pressed.connect(_on_missing_slot_pressed)
			memory_grid.add_child(missing_slot)
		else:
			var locked_card := TextureButton.new()
			locked_card.custom_minimum_size = Vector2(105, 145)
			locked_card.ignore_texture_size = true
			locked_card.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			locked_card.texture_normal = memory_card_back_texture
			locked_card.disabled = true
			locked_card.focus_mode = Control.FOCUS_NONE
			memory_grid.add_child(locked_card)
			
func _rebuild_memory_grid_unlocked() -> void:
	_clear_memory_grid()

	if memory_grid:
		memory_grid.columns = 4

	if _memory_deck.size() != 12:
		_build_shuffled_memory_deck()

	for i in range(_memory_deck.size()):
		var button := TextureButton.new()
		button.custom_minimum_size = Vector2(105, 145)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.texture_normal = memory_card_back_texture
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_memory_card_pressed.bind(i))
		memory_grid.add_child(button)
		_memory_buttons.append(button)

		_refresh_memory_card_visual(i)
		
func _build_shuffled_memory_deck() -> void:
	_memory_deck.clear()

	for face_id in MEMORY_FACE_IDS:
		_memory_deck.append(face_id)
		_memory_deck.append(face_id)

	_memory_deck.shuffle()
	
func _on_memory_card_pressed(index: int) -> void:
	if _memory_busy or _memory_solved or not _memory_unlocked:
		return

	if _memory_matched_indices.has(index):
		return

	if _memory_selected_indices.has(index):
		return

	_memory_selected_indices.append(index)
	_refresh_memory_card_visual(index)

	if _memory_selected_indices.size() < 2:
		return

	_memory_busy = true
	await get_tree().create_timer(0.6).timeout

	var first_index := _memory_selected_indices[0]
	var second_index := _memory_selected_indices[1]

	if _memory_deck[first_index] == _memory_deck[second_index]:
		_memory_matched_indices[first_index] = true
		_memory_matched_indices[second_index] = true
	else:
		_memory_selected_indices.clear()
		_refresh_memory_card_visual(first_index)
		_refresh_memory_card_visual(second_index)

	if _memory_matched_indices.size() == _memory_deck.size():
		_complete_memory_puzzle()
	else:
		_memory_selected_indices.clear()

	_memory_busy = false
	
func _refresh_memory_card_visual(index: int) -> void:
	if index < 0 or index >= _memory_buttons.size():
		return

	var button: TextureButton = _memory_buttons[index]
	var face_id: String = _memory_deck[index]
	var face_texture: Texture2D = _memory_face_textures.get(face_id, null) as Texture2D

	var should_show_face := _memory_solved or _memory_matched_indices.has(index) or _memory_selected_indices.has(index)

	button.texture_normal = face_texture if should_show_face else memory_card_back_texture
	button.modulate = Color.WHITE if should_show_face else Color(1, 1, 1, 1)
	
func _reset_memory_round() -> void:
	_memory_selected_indices.clear()
	_memory_matched_indices.clear()
	_memory_busy = false
	
func _complete_memory_puzzle() -> void:
	if _memory_solved:
		return

	if multiplayer.has_multiplayer_peer():
		_sync_memory_puzzle_solved_rpc.rpc()
	else:
		_apply_memory_puzzle_solved()

@rpc("any_peer", "reliable", "call_local")
func _sync_memory_puzzle_solved_rpc() -> void:
	_apply_memory_puzzle_solved()

func _apply_memory_puzzle_solved() -> void:
	if _memory_solved:
		return

	_memory_solved = true
	_memory_busy = false
	_memory_selected_indices.clear()

	if GameState and GameState.has_method("set_puzzle_solved"):
		GameState.set_puzzle_solved(MEMORY_PUZZLE_ID, true)

	for i in range(_memory_buttons.size()):
		_refresh_memory_card_visual(i)

	memory_instruction_label.text = "All pairs matched. Puzzle solved!"
	_close_memory_panel()
	_show_memory_reward_panel()
	_show_notification("Card puzzle solved.")

func _show_memory_reward_panel() -> void:
	_pending_reward_items.clear()
	_pending_reward_items.append_array(MEMORY_REWARD_ITEMS)
	reward_title_label.text = "Puzzle Solved"
	reward_body_label.text = "You found Key Fragment 2 and the Lighter."

	reward_items_row.visible = true
	key_texture_rect.visible = true
	card_texture_rect.visible = true

	if key_fragment_2_texture:
		key_texture_rect.texture = key_fragment_2_texture

	if lighter_texture:
		card_texture_rect.texture = lighter_texture

	collect_reward_button.text = "Collect Clue"
	collect_reward_button.visible = _is_local_sidekick()

	reward_dimmer.visible = true
	reward_panel.visible = true

	reward_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	reward_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_missing_slot_pressed() -> void:
	if _memory_unlocked or _memory_solved:
		return

	if not _is_local_sidekick():
		return

	if not inside_zone_control:
		return

	if not inside_zone_control.has_method("consume_armed_item"):
		return

	var used: bool = inside_zone_control.consume_armed_item("card_piece")
	if not used:
		_show_notification("Open the briefcase, select the Card Piece, press Use, then tap the empty slot.")
		return

	_memory_unlocked = true
	_reset_memory_round()
	_build_shuffled_memory_deck()
	_refresh_memory_panel_state()
	_rebuild_memory_grid_unlocked()
	_show_notification("Card Piece inserted.")

func _setup_mirror_ui() -> void:
	if mirror_puzzle_panel:
		mirror_puzzle_panel.visible = false
		mirror_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _load_mirror_progress() -> void:
	if GameState and GameState.has_method("is_puzzle_solved"):
		_mirror_lit = GameState.is_puzzle_solved(MIRROR_PUZZLE_ID)
	else:
		_mirror_lit = false

	_refresh_room_lighting()


func _on_mirror_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not _is_primary_press_event(event):
		return

	_open_mirror_panel()


func _open_mirror_panel() -> void:
	_close_books_panel()
	_close_memory_panel()

	dimmer.visible = true
	mirror_puzzle_panel.visible = true

	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	mirror_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	_refresh_mirror_panel_state()


func _close_mirror_panel() -> void:
	mirror_puzzle_panel.visible = false
	mirror_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not books_puzzle_panel.visible and not memory_puzzle_panel.visible:
		dimmer.visible = false
		dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_close_mirror_button_pressed() -> void:
	_close_mirror_panel()


func _refresh_mirror_panel_state() -> void:
	if _mirror_lit:
		if _is_local_sidekick():
			mirror_texture_rect.texture = mirror_lighted_no_fp_texture
		else:
			mirror_texture_rect.texture = mirror_lighted_with_fp_texture

		mirror_instruction_label.text = "The lamp is lit."
		lamp_hotspot.visible = false
		lamp_hotspot.disabled = true
	else:
		mirror_texture_rect.texture = mirror_not_lighted_texture

		if _is_local_sidekick():
			mirror_instruction_label.text = "Tap the lamp."
			lamp_hotspot.visible = true
			lamp_hotspot.disabled = false
		else:
			mirror_instruction_label.text = "Wait for the Sidekick to light the lamp."
			lamp_hotspot.visible = false
			lamp_hotspot.disabled = true

func _on_lamp_hotspot_pressed() -> void:
	if _mirror_lit:
		return

	if not _is_local_sidekick():
		return

	if not inside_zone_control or not inside_zone_control.has_method("consume_armed_item"):
		return

	var used: bool = inside_zone_control.consume_armed_item("light_bulb")
	if not used:
		mirror_instruction_label.text = "Light this lamp. Open the briefcase, select the Lighter, press Use, then tap the lamp."
		_show_notification("Light this lamp.")
		return

	if multiplayer.has_multiplayer_peer():
		_sync_mirror_lit_rpc.rpc()
	else:
		_apply_mirror_lit()


@rpc("any_peer", "reliable", "call_local")
func _sync_mirror_lit_rpc() -> void:
	_apply_mirror_lit()


func _apply_mirror_lit() -> void:
	if _mirror_lit:
		return

	_mirror_lit = true

	if GameState and GameState.has_method("set_puzzle_solved"):
		GameState.set_puzzle_solved(MIRROR_PUZZLE_ID, true)

	if GameState and GameState.has_signal("briefcase_updated"):
		GameState.briefcase_updated.emit()

	_refresh_room_lighting()
	_refresh_mirror_panel_state()
	_show_notification("The lamp is lit.")


func _refresh_room_lighting() -> void:
	if _mirror_lit and lighted_room_texture:
		bedroom_background.texture = lighted_room_texture
	elif _default_room_texture:
		bedroom_background.texture = _default_room_texture
		
func _close_puzzle_panel() -> void:
	books_puzzle_panel.visible = false
	books_puzzle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not memory_puzzle_panel.visible and not mirror_puzzle_panel.visible:
		dimmer.visible = false
		dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
