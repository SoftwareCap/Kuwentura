extends CanvasLayer

signal pause_pressed
signal ledger_pressed
signal briefcase_pressed
signal briefcase_item_selected(item_id: String)

enum VisibilityMode {
	AUTO,
	ALWAYS_SHOW,
	ALWAYS_HIDE
}

@onready var briefcase_panel: Control = get_node_or_null("BriefcasePanel")
@onready var briefcase_texture: TextureRect = get_node_or_null("BriefcasePanel/BriefcaseTexture")
@onready var use_button: Button = get_node_or_null("BriefcasePanel/ButtonsRow/UseButton")
@onready var combine_button: Button = get_node_or_null("BriefcasePanel/ButtonsRow/CombineButton")

@onready var lighter_hotspot: Button = get_node_or_null("BriefcasePanel/LighterHotspot")

@export var visibility_mode: VisibilityMode = VisibilityMode.ALWAYS_SHOW
@export var fade_duration: float = 0.2
@export var button_scale_pressed: float = 0.9

@onready var pause_button: TouchScreenButton = $Pause
@onready var ledger_button: TouchScreenButton = get_node_or_null("Ledger")
@onready var briefcase_button: TouchScreenButton = get_node_or_null("Briefcase")

@onready var card_piece_hotspot: Button = get_node_or_null("BriefcasePanel/CardPieceHotspot")

@onready var key_fragment_1_hotspot: Button = get_node_or_null("BriefcasePanel/KeyFragment1Hotspot")
@onready var key_fragment_2_hotspot: Button = get_node_or_null("BriefcasePanel/KeyFragment2Hotspot")
@onready var key_fragment_3_hotspot: Button = get_node_or_null("BriefcasePanel/KeyFragment3Hotspot")

const ABANDONED_KEY_FRAGMENT_IDS := [
	"key_fragment_1",
	"key_fragment_2",
	"key_fragment_3"
]

const ABANDONED_COMBINED_KEY_ID := "assembled_key"

var _selected_briefcase_items: Array[String] = []

var _is_visible: bool = true
var _original_scales: Dictionary = {}

var _selected_briefcase_item: String = ""
var _armed_briefcase_item: String = ""

var _enabled: Dictionary = {}

const NORMAL_COLOR := Color(1, 1, 1, 1)
const DISABLED_COLOR := Color(0.65, 0.65, 0.65, 1.0)
const TRANSPARENT := Color(1, 1, 1, 0)

# Buttons that are only visible to the sidekick role
const SIDEKICK_ONLY := ["ledger", "briefcase"]

# Central registry — single source of truth for all button wiring
# key: id  →  { button, signal (or null), role_gated }
var _button_registry: Dictionary = {}


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for id in _button_registry:
			_disconnect_button(id)


func _ready() -> void:
	_button_registry = {
		"pause" : { "button" : pause_button, "signal" : pause_pressed, "role_gated" : false },
		"ledger" : { "button" : ledger_button, "signal" : ledger_pressed, "role_gated" : true  },
		"briefcase" : { "button" : briefcase_button, "signal" : briefcase_pressed, "role_gated" : true  },
	}

	if not briefcase_pressed.is_connected(_on_briefcase_pressed):
		briefcase_pressed.connect(_on_briefcase_pressed)

	if card_piece_hotspot and not card_piece_hotspot.pressed.is_connected(_on_card_piece_hotspot_pressed):
		card_piece_hotspot.pressed.connect(_on_card_piece_hotspot_pressed)

	if lighter_hotspot and not lighter_hotspot.pressed.is_connected(_on_lighter_hotspot_pressed):
		lighter_hotspot.pressed.connect(_on_lighter_hotspot_pressed)
	
	if use_button and not use_button.pressed.is_connected(_on_use_button_pressed):
		use_button.pressed.connect(_on_use_button_pressed)
		
	if combine_button and not combine_button.pressed.is_connected(_on_combine_button_pressed):
		combine_button.pressed.connect(_on_combine_button_pressed)

	if key_fragment_1_hotspot and not key_fragment_1_hotspot.pressed.is_connected(_on_key_fragment_1_hotspot_pressed):
		key_fragment_1_hotspot.pressed.connect(_on_key_fragment_1_hotspot_pressed)

	if key_fragment_2_hotspot and not key_fragment_2_hotspot.pressed.is_connected(_on_key_fragment_2_hotspot_pressed):
		key_fragment_2_hotspot.pressed.connect(_on_key_fragment_2_hotspot_pressed)

	if key_fragment_3_hotspot and not key_fragment_3_hotspot.pressed.is_connected(_on_key_fragment_3_hotspot_pressed):
		key_fragment_3_hotspot.pressed.connect(_on_key_fragment_3_hotspot_pressed)
		
	if briefcase_panel:
		briefcase_panel.visible = false
		
	_layout_briefcase_panel()

	if briefcase_panel and briefcase_texture and use_button and combine_button:
		refresh_abandoned_house_briefcase_ui()

		if GameState and not GameState.briefcase_updated.is_connected(refresh_abandoned_house_briefcase_ui):
			GameState.briefcase_updated.connect(refresh_abandoned_house_briefcase_ui)
	else:
		push_warning("Briefcase UI nodes not found under InsideZoneControl.")

	for id in _button_registry:
		var entry: Dictionary = _button_registry[id]
		var button: TouchScreenButton = entry.button
		_enabled[id] = true
		if button:
			_original_scales[button] = button.scale
			_connect_button(id)

	_apply_visibility_mode()


# Connection helpers
func _connect_button(id: String) -> void:
	var entry: Dictionary = _button_registry[id]
	var button: TouchScreenButton = entry.button
	if not button:
		return
	button.pressed.connect(_on_button_pressed.bind(id))
	button.released.connect(_on_button_released.bind(id))


func _disconnect_button(id: String) -> void:
	var entry: Dictionary = _button_registry[id]
	var button: TouchScreenButton = entry.button
	if not button:
		return
	if button.pressed.is_connected(_on_button_pressed):
		button.pressed.disconnect(_on_button_pressed)
	if button.released.is_connected(_on_button_released):
		button.released.disconnect(_on_button_released)


# Generic button handlers
func _on_button_pressed(id: String) -> void:
	if not _enabled.get(id, false):
		return
	var entry: Dictionary = _button_registry[id]
	_animate_button_press(entry.button, true)
	entry.signal.emit()


func _on_button_released(id: String) -> void:
	if not _enabled.get(id, false):
		return
	_animate_button_press(_button_registry[id].button, false)


# Visibility
func _apply_visibility_mode() -> void:
	match visibility_mode:
		VisibilityMode.AUTO:
			visible = _should_show_on_this_device()
		VisibilityMode.ALWAYS_SHOW:
			visible = true
		VisibilityMode.ALWAYS_HIDE:
			visible = false
	_is_visible = visible


func _should_show_on_this_device() -> bool:
	return OS.get_name() in ["Android", "iOS", "Web"]


func show_controls() -> void:
	if _is_visible:
		return
	_is_visible = true
	visible = true
	_fade_children(TRANSPARENT, NORMAL_COLOR)


func hide_controls() -> void:
	if not _is_visible:
		return
	_is_visible = false
	var tween := _fade_children(NORMAL_COLOR, TRANSPARENT)
	tween.tween_callback(func(): visible = false)


func toggle_controls() -> void:
	if _is_visible:
		hide_controls()
	else:
		show_controls()


func _fade_children(from: Color, to: Color) -> Tween:
	"""Fade all CanvasItem children from one modulate color to another."""
	for child in get_children():
		if child is CanvasItem:
			child.modulate = from
	var tween := create_tween()
	for child in get_children():
		if child is CanvasItem:
			tween.parallel().tween_property(child, "modulate", to, fade_duration)
	return tween


# Enable / disable
func set_button_enabled(id: String, enabled: bool) -> void:
	"""Enable or disable any button by id. Role-gated buttons also respect sidekick visibility."""
	if not _button_registry.has(id):
		push_warning("[HUDControls] Unknown button id: " + id)
		return

	_enabled[id] = enabled
	var entry: Dictionary = _button_registry[id]
	var button: TouchScreenButton = entry.button
	if button:
		button.modulate = NORMAL_COLOR if enabled else DISABLED_COLOR


# Convenience wrappers kept for backward compatibility with existing callers
func set_pause_enabled(enabled: bool) -> void: set_button_enabled("pause", enabled)
func set_ledger_enabled(enabled: bool) -> void: set_button_enabled("ledger", enabled)
func set_briefcase_enabled(enabled: bool) -> void: set_button_enabled("briefcase", enabled)


func set_sidekick_ui_visible(is_sidekick: bool) -> void:
	for id in SIDEKICK_ONLY:
		var entry: Dictionary = _button_registry.get(id, {})
		var button: TouchScreenButton = entry.get("button")
		if button:
			button.visible = is_sidekick

	if not is_sidekick and briefcase_panel:
		briefcase_panel.hide()


# Animation
func _animate_button_press(button: TouchScreenButton, pressed: bool) -> void:
	if not button:
		return
	var original_scale: Vector2 = _original_scales.get(button, Vector2.ONE)
	var target_scale: Vector2   = original_scale * button_scale_pressed if pressed else original_scale
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(button, "scale", target_scale, 0.05)


# Queries
func is_showing() -> bool:
	return _is_visible

func refresh_abandoned_house_briefcase_ui() -> void:
	if not briefcase_panel or not briefcase_texture or not use_button or not combine_button:
		return

	var has_key_fragment_1 := GameState.has_zone_item("abandoned_house", "key_fragment_1")
	var has_key_fragment_2 := GameState.has_zone_item("abandoned_house", "key_fragment_2")
	var has_key_fragment_3 := GameState.has_zone_item("abandoned_house", "key_fragment_3")
	var has_card_piece := GameState.has_zone_item("abandoned_house", "card_piece")
	var has_lighter := GameState.has_zone_item("abandoned_house", "light_bulb")
	var has_full_key := GameState.has_zone_item("abandoned_house", ABANDONED_COMBINED_KEY_ID)

	var mirror_lit := GameState.is_puzzle_solved("abandoned_house_mirror_lit")

	briefcase_texture.texture = GameState.get_briefcase_texture("abandoned_house")

	if card_piece_hotspot:
		card_piece_hotspot.visible = has_card_piece and not has_full_key
		card_piece_hotspot.disabled = not has_card_piece or has_full_key

	if lighter_hotspot:
		lighter_hotspot.visible = has_lighter and not mirror_lit and not has_full_key
		lighter_hotspot.disabled = not has_lighter or mirror_lit or has_full_key

	if key_fragment_1_hotspot:
		key_fragment_1_hotspot.visible = has_key_fragment_1 and not has_full_key
		key_fragment_1_hotspot.disabled = not has_key_fragment_1 or has_full_key

	if key_fragment_2_hotspot:
		key_fragment_2_hotspot.visible = has_key_fragment_2 and not has_full_key
		key_fragment_2_hotspot.disabled = not has_key_fragment_2 or has_full_key

	if key_fragment_3_hotspot:
		key_fragment_3_hotspot.visible = has_key_fragment_3 and not has_full_key
		key_fragment_3_hotspot.disabled = not has_key_fragment_3 or has_full_key

	_refresh_briefcase_item_highlights()
	_refresh_briefcase_action_buttons()
	
func _refresh_briefcase_item_highlights() -> void:
	if card_piece_hotspot:
		card_piece_hotspot.modulate = Color(1, 1, 1, 0.35) if _is_briefcase_item_selected("card_piece") else Color(1, 1, 1, 0.01)

	if lighter_hotspot:
		lighter_hotspot.modulate = Color(1, 1, 1, 0.35) if _is_briefcase_item_selected("light_bulb") else Color(1, 1, 1, 0.01)

	if key_fragment_1_hotspot:
		key_fragment_1_hotspot.modulate = Color(1, 1, 1, 0.35) if _is_briefcase_item_selected("key_fragment_1") else Color(1, 1, 1, 0.01)

	if key_fragment_2_hotspot:
		key_fragment_2_hotspot.modulate = Color(1, 1, 1, 0.35) if _is_briefcase_item_selected("key_fragment_2") else Color(1, 1, 1, 0.01)

	if key_fragment_3_hotspot:
		key_fragment_3_hotspot.modulate = Color(1, 1, 1, 0.35) if _is_briefcase_item_selected("key_fragment_3") else Color(1, 1, 1, 0.01)

func _select_briefcase_item(item_id: String) -> void:
	_toggle_briefcase_item_selection(item_id)
		
func _on_briefcase_pressed() -> void:
	if not briefcase_panel:
		push_warning("briefcase_panel is null")
		return

	if briefcase_panel.visible:
		briefcase_panel.hide()
		return

	_clear_briefcase_selection()
	refresh_abandoned_house_briefcase_ui()
	_layout_briefcase_panel()
	briefcase_panel.show()

func _layout_briefcase_panel() -> void:
	if not briefcase_panel:
		return

	var panel_size := Vector2(900, 620)
	var viewport_size := get_viewport().get_visible_rect().size

	briefcase_panel.size = panel_size
	briefcase_panel.position = (viewport_size - panel_size) / 2.0
	briefcase_panel.z_index = 100

	if briefcase_texture:
		briefcase_texture.visible = true
		briefcase_texture.position = Vector2.ZERO
		briefcase_texture.size = Vector2(900, 500)
		briefcase_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		briefcase_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var buttons_row := get_node_or_null("BriefcasePanel/ButtonsRow") as HBoxContainer
	if buttons_row:
		buttons_row.visible = true
		buttons_row.position = Vector2(170, 530)
		buttons_row.size = Vector2(560, 60)
		buttons_row.add_theme_constant_override("separation", 40)

	if use_button:
		use_button.visible = true
		use_button.text = "Use"
		use_button.custom_minimum_size = Vector2(240, 60)

	if combine_button:
		combine_button.visible = true
		combine_button.text = "Combine"
		combine_button.custom_minimum_size = Vector2(240, 60)

	if card_piece_hotspot:
		card_piece_hotspot.position = Vector2(360, 250)
		card_piece_hotspot.size = Vector2(120, 140)

	if lighter_hotspot:
		lighter_hotspot.position = Vector2(470, 250)
		lighter_hotspot.size = Vector2(120, 140)

func _on_card_piece_hotspot_pressed() -> void:
	if not GameState.has_zone_item("abandoned_house", "card_piece"):
		return

	_select_briefcase_item("card_piece")
	
func _on_use_button_pressed() -> void:
	if _selected_briefcase_items.size() != 1:
		return

	_armed_briefcase_item = _selected_briefcase_items[0]
	_selected_briefcase_item = _armed_briefcase_item
	briefcase_panel.hide()
	
func consume_armed_item(expected_item_id: String) -> bool:
	if _armed_briefcase_item != expected_item_id:
		return false

	_armed_briefcase_item = ""
	_clear_briefcase_selection()
	return true

func _on_lighter_hotspot_pressed() -> void:
	if not GameState.has_zone_item("abandoned_house", "light_bulb"):
		return

	_select_briefcase_item("light_bulb")

func _is_briefcase_item_selected(item_id: String) -> bool:
	return _selected_briefcase_items.has(item_id)


func _toggle_briefcase_item_selection(item_id: String) -> void:
	if _selected_briefcase_items.has(item_id):
		_selected_briefcase_items.erase(item_id)
	else:
		_selected_briefcase_items.append(item_id)

	_selected_briefcase_item = _selected_briefcase_items[0] if _selected_briefcase_items.size() == 1 else ""
	_armed_briefcase_item = ""

	_refresh_briefcase_item_highlights()
	_refresh_briefcase_action_buttons()
	briefcase_item_selected.emit(_selected_briefcase_item)


func _clear_briefcase_selection() -> void:
	_selected_briefcase_items.clear()
	_selected_briefcase_item = ""
	_armed_briefcase_item = ""
	_refresh_briefcase_item_highlights()
	_refresh_briefcase_action_buttons()


func _has_all_key_fragments_selected() -> bool:
	return (
		_selected_briefcase_items.size() == 3
		and _selected_briefcase_items.has("key_fragment_1")
		and _selected_briefcase_items.has("key_fragment_2")
		and _selected_briefcase_items.has("key_fragment_3")
	)


func _refresh_briefcase_action_buttons() -> void:
	if not use_button or not combine_button:
		return

	var mirror_lit := GameState.is_puzzle_solved("abandoned_house_mirror_lit")
	var has_full_key := GameState.has_zone_item("abandoned_house", ABANDONED_COMBINED_KEY_ID)

	var can_use := false
	if _selected_briefcase_items.size() == 1:
		var item_id := _selected_briefcase_items[0]
		can_use = (
			item_id == "card_piece"
			or (item_id == "light_bulb" and not mirror_lit)
			or item_id == ABANDONED_COMBINED_KEY_ID
		)

	var can_combine := _has_all_key_fragments_selected() and not has_full_key

	use_button.disabled = not can_use
	combine_button.disabled = not can_combine

	use_button.modulate = Color(1, 1, 1, 1) if can_use else Color(0.6, 0.6, 0.6, 1)
	combine_button.modulate = Color(1, 1, 1, 1) if can_combine else Color(0.6, 0.6, 0.6, 1)

func _on_key_fragment_1_hotspot_pressed() -> void:
	if not GameState.has_zone_item("abandoned_house", "key_fragment_1"):
		return
	_select_briefcase_item("key_fragment_1")


func _on_key_fragment_2_hotspot_pressed() -> void:
	if not GameState.has_zone_item("abandoned_house", "key_fragment_2"):
		return
	_select_briefcase_item("key_fragment_2")


func _on_key_fragment_3_hotspot_pressed() -> void:
	if not GameState.has_zone_item("abandoned_house", "key_fragment_3"):
		return
	_select_briefcase_item("key_fragment_3")

func _on_combine_button_pressed() -> void:
	if not _has_all_key_fragments_selected():
		return

	if GameState.has_zone_item("abandoned_house", ABANDONED_COMBINED_KEY_ID):
		return

	if GameState and GameState.has_method("grant_zone_items"):
		GameState.grant_zone_items("abandoned_house", [ABANDONED_COMBINED_KEY_ID])

	_clear_briefcase_selection()
	refresh_abandoned_house_briefcase_ui()
