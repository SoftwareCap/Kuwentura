extends Node2D

@export var edge_margin := 4.0

var partner: Node2D
var canvas_transform: Transform2D

func _ready() -> void:
	visible = false
	var group_name := "sidekick_player" if GameState.local_role == GameState.Role.DETECTIVE else "host_player"
	var partners := get_tree().get_nodes_in_group(group_name)
	if partners.size() > 0:
		partner = partners[0]

func _process(_delta: float) -> void:
	if partner == null:
		return
	canvas_transform = get_viewport().get_canvas_transform()
	var screen_size := get_viewport_rect().size
	var partner_screen_pos := canvas_transform * partner.global_position
	var on_screen := partner_screen_pos.x > edge_margin and partner_screen_pos.x < screen_size.x - edge_margin \
		and partner_screen_pos.y > edge_margin and partner_screen_pos.y < screen_size.y - edge_margin
	visible = not on_screen
	if not visible:
		return
	var center := screen_size * 0.5
	var direction := (partner_screen_pos - center).normalized()
	var half_extent := center - Vector2(edge_margin, edge_margin)
	var dir_x: float = max(abs(direction.x), 0.0001)
	var dir_y: float = max(abs(direction.y), 0.0001)
	var t: float = min(half_extent.x / dir_x, half_extent.y / dir_y)
	position = center + direction * t
	rotation = direction.angle()

func _draw() -> void:
	var size := 22.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(size, 0),
		Vector2(-size * 0.6, size * 0.6),
		Vector2(-size * 0.6, -size * 0.6)
	]), Color.WHITE)
