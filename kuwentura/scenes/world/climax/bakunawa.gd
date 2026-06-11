extends Node2D

@onready var video_player: VideoStreamPlayer = $IntroScene/VideoStreamPlayer
@onready var detective_spawn: Marker2D        = $SpawnPoints/DetectiveSpawn
@onready var sidekick_spawn: Marker2D         = $SpawnPoints/SidekickSpawn
@onready var detective_camera: Camera2D       = $DetectiveCamera
@onready var sidekick_camera: Camera2D        = $SidekickCamera
@onready var dark_mask_layer: CanvasLayer     = $DarkMaskLayer
@onready var spotlight: PointLight2D          = $DarkMaskLayer/Spotlight
@onready var darkness: ColorRect              = $DarkMaskLayer/Darkness
@onready var consequence: Node2D              = $Consequence
@onready var portal: Area2D                   = $Portal
@onready var touch_controls: TouchControls    = $TouchControls

var is_detective: bool = false
var sidekick_player_node: CharacterBody2D = null
var detective_player_node: CharacterBody2D = null

const FULLBODY_SWAP_DISTANCE: float = 300.0
const ALTAR_SCENE: String = "res://scenes/world/climax/AltarDeduction.tscn"

var players_in_portal: Array[int] = []

func _ready() -> void:
	_fit_darkness_to_screen()
	_play_intro()

func _fit_darkness_to_screen() -> void:
	var screen_size := get_viewport().get_visible_rect().size
	darkness.position = Vector2.ZERO
	darkness.size = screen_size

func _play_intro() -> void:
	_fit_video_to_screen()
	video_player.play()
	video_player.finished.connect(_on_intro_finished)

func _fit_video_to_screen() -> void:
	var screen_size := get_viewport().get_visible_rect().size
	video_player.expand = true
	video_player.anchors_preset = Control.PRESET_FULL_RECT
	video_player.offset_left = 0
	video_player.offset_top = 0
	video_player.offset_right = screen_size.x
	video_player.offset_bottom = screen_size.y
	video_player.size = screen_size
	video_player.position = Vector2.ZERO

func _on_intro_finished() -> void:
	$IntroScene.visible = false
	MusicController.play_track(MusicController.BAKUNAWA)
	_setup_touch_controls()
	_spawn_players()
	_setup_consequence()
	_setup_portal()

func _setup_touch_controls() -> void:
	touch_controls.set_button_visible("left", true)
	touch_controls.set_button_visible("right", true)
	touch_controls.set_button_visible("pause", true)
	touch_controls.set_button_visible("map", false)
	touch_controls.set_button_visible("ledger", false)
	touch_controls.set_button_visible("briefcase", false)
	touch_controls.set_button_visible("jump", true)

func _spawn_players() -> void:
	is_detective = (GameState.local_role == GameState.Role.DETECTIVE)

	if is_detective:
		var player_scene: PackedScene = preload("res://scenes/players/PlayerHost.tscn")
		var player := player_scene.instantiate() as CharacterBody2D
		player.set_multiplayer_authority(multiplayer.get_unique_id())
		player.global_position = detective_spawn.global_position
		add_child(player)
		detective_player_node = player
		_setup_detective_camera(player)
	else:
		var player_scene: PackedScene = preload("res://scenes/players/PlayerSidekick.tscn")
		var player := player_scene.instantiate() as CharacterBody2D
		player.set_multiplayer_authority(multiplayer.get_unique_id())
		player.global_position = sidekick_spawn.global_position
		add_child(player)
		sidekick_player_node = player
		_setup_sidekick_camera(player)

func _setup_detective_camera(player: CharacterBody2D) -> void:
	detective_camera.enabled = true
	sidekick_camera.enabled = false
	dark_mask_layer.visible = false
	var remote := RemoteTransform2D.new()
	remote.name = "CameraRemote"
	remote.remote_path = detective_camera.get_path()
	player.add_child(remote)

func _setup_sidekick_camera(player: CharacterBody2D) -> void:
	sidekick_camera.enabled = true
	detective_camera.enabled = false
	dark_mask_layer.visible = true
	var remote := RemoteTransform2D.new()
	remote.name = "CameraRemote"
	remote.remote_path = sidekick_camera.get_path()
	player.add_child(remote)

func _process(_delta: float) -> void:
	if not is_detective and sidekick_player_node != null:
		var vp_transform := get_viewport().get_canvas_transform()
		spotlight.position = vp_transform * sidekick_player_node.global_position

	_update_nuno_swaps()

func _update_nuno_swaps() -> void:
	var local_player := detective_player_node if is_detective else sidekick_player_node
	if local_player == null:
		return

	for i in range(1, 10):
		var suffix := "" if i == 1 else str(i)
		var head: Area2D = consequence.get_node_or_null("Head" + suffix)
		var full_body: Area2D = consequence.get_node_or_null("FullBody" + suffix)

		if head == null or full_body == null:
			continue

		var dist := local_player.global_position.distance_to(head.global_position)
		if dist <= FULLBODY_SWAP_DISTANCE:
			head.visible = false
			full_body.visible = true
		else:
			head.visible = true
			full_body.visible = false

func _setup_consequence() -> void:
	for i in range(1, 10):
		var suffix := "" if i == 1 else str(i)
		var head: Area2D = consequence.get_node_or_null("Head" + suffix)
		var full_body: Area2D = consequence.get_node_or_null("FullBody" + suffix)

		if head != null:
			head.visible = true
			head.body_entered.connect(_on_nuno_hit.bind(head))

		if full_body != null:
			full_body.visible = false
			full_body.body_entered.connect(_on_nuno_hit.bind(full_body))

func _on_nuno_hit(_body: Node2D, _nuno: Area2D) -> void:
	var local_player := detective_player_node if is_detective else sidekick_player_node
	if _body != local_player:
		return
	_snatch_artifacts()

func _snatch_artifacts() -> void:
	for zone_id in GameState.collected_clues:
		GameState.collected_clues[zone_id]["collected"] = false
	GameState.climax_triggered = false
	GameState.briefcase_updated.emit()

func _setup_portal() -> void:
	portal.body_entered.connect(_on_portal_body_entered)
	portal.body_exited.connect(_on_portal_body_exited)

func _on_portal_body_entered(body: Node2D) -> void:
	var local_player := detective_player_node if is_detective else sidekick_player_node
	if body != local_player:
		return
	var my_id := multiplayer.get_unique_id()
	if not players_in_portal.has(my_id):
		players_in_portal.append(my_id)
	_notify_portal_state.rpc(my_id, true)

func _on_portal_body_exited(body: Node2D) -> void:
	var local_player := detective_player_node if is_detective else sidekick_player_node
	if body != local_player:
		return
	var my_id := multiplayer.get_unique_id()
	players_in_portal.erase(my_id)
	_notify_portal_state.rpc(my_id, false)

@rpc("any_peer", "reliable", "call_local")
func _notify_portal_state(peer_id: int, entered: bool) -> void:
	if entered:
		if not players_in_portal.has(peer_id):
			players_in_portal.append(peer_id)
	else:
		players_in_portal.erase(peer_id)

	if players_in_portal.size() >= 2:
		_load_altar()

func _load_altar() -> void:
	get_tree().change_scene_to_file(ALTAR_SCENE)
