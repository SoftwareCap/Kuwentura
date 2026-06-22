extends CanvasLayer

const EDGE_MARGIN: float = 4.0
const ARROW_SIZE: float = 40.0
const ARROW_COLOR: Color = Color(1.0, 0.9, 0.2, 0.98)
const ARROW_OUTLINE_COLOR: Color = Color(0.26, 0.16, 0.08, 0.88)
const PADDING: float = 48.0

var _draw_node: Node2D
var _arrow_visible: bool = false
var _arrow_screen_pos: Vector2 = Vector2.ZERO
var _arrow_angle: float = 0.0


func _ready() -> void:
	_draw_node = Node2D.new()
	_draw_node.name = "ArrowDrawNode"
	_draw_node.z_index = 10
	add_child(_draw_node)
	_draw_node.draw.connect(_on_draw)


func _process(_delta: float) -> void:
	var partner_screen_pos := _get_partner_screen_pos()
	if partner_screen_pos == Vector2.ZERO:
		_arrow_visible = false
		_draw_node.queue_redraw()
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var on_screen := (
		partner_screen_pos.x >= EDGE_MARGIN
		and partner_screen_pos.x <= viewport_size.x - EDGE_MARGIN
		and partner_screen_pos.y >= EDGE_MARGIN
		and partner_screen_pos.y <= viewport_size.y - EDGE_MARGIN
	)

	if on_screen:
		_arrow_visible = false
		_draw_node.queue_redraw()
		return

	var center := viewport_size * 0.5
	_arrow_angle = center.angle_to_point(partner_screen_pos)

	var clamped := _clamp_to_screen_edge(partner_screen_pos, viewport_size)
	_arrow_screen_pos = clamped
	_arrow_visible = true
	_draw_node.queue_redraw()


func _get_partner_screen_pos() -> Vector2:
	var my_id := multiplayer.get_unique_id()
	var partner_node: Node2D = null

	var candidates: Array[Node]
	if GameState.local_role == GameState.Role.DETECTIVE:
		candidates = get_tree().get_nodes_in_group("sidekick_player")
	else:
		candidates = get_tree().get_nodes_in_group("host_player")

	for node in candidates:
		if node is Node2D and str(node.name) != str(my_id):
			partner_node = node as Node2D
			break

	if not is_instance_valid(partner_node):
		return Vector2.ZERO

	var canvas_transform := get_viewport().get_canvas_transform()
	return canvas_transform * partner_node.global_position


func _clamp_to_screen_edge(target: Vector2, viewport_size: Vector2) -> Vector2:
	var center := viewport_size * 0.5
	var direction := (target - center).normalized()

	var min_x: float = PADDING
	var max_x: float = viewport_size.x - PADDING
	var min_y: float = PADDING
	var max_y: float = viewport_size.y - PADDING

	var t_values: Array[float] = []

	if direction.x > 0.0001:
		t_values.append((max_x - center.x) / direction.x)
	elif direction.x < -0.0001:
		t_values.append((min_x - center.x) / direction.x)

	if direction.y > 0.0001:
		t_values.append((max_y - center.y) / direction.y)
	elif direction.y < -0.0001:
		t_values.append((min_y - center.y) / direction.y)

	var t: float = INF
	for val in t_values:
		if val > 0.0 and val < t:
			t = val

	if t == INF:
		return center

	return center + direction * t


func _on_draw() -> void:
	if not _arrow_visible:
		return

	var tip := Vector2(ARROW_SIZE, 0.0).rotated(_arrow_angle)
	var base_left := Vector2(-ARROW_SIZE * 0.55, ARROW_SIZE * 0.45).rotated(_arrow_angle)
	var base_right := Vector2(-ARROW_SIZE * 0.55, -ARROW_SIZE * 0.45).rotated(_arrow_angle)

	var world_pos := _arrow_screen_pos

	var outline_points := PackedVector2Array([
		world_pos + tip * 1.16,
		world_pos + base_left * 1.16,
		world_pos + base_right * 1.16,
	])
	_draw_node.draw_colored_polygon(outline_points, ARROW_OUTLINE_COLOR)

	var fill_points := PackedVector2Array([
		world_pos + tip,
		world_pos + base_left,
		world_pos + base_right,
	])
	_draw_node.draw_colored_polygon(fill_points, ARROW_COLOR)

