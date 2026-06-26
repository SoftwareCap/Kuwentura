extends Node2D

@onready var video_player: VideoStreamPlayer = $IntroScene/VideoStreamPlayer
@onready var detective_spawn: Marker2D = $SpawnPoints/DetectiveSpawn
@onready var sidekick_spawn: Marker2D = $SpawnPoints/SidekickSpawn
@onready var spotlight: PointLight2D = $Spotlight
@onready var consequence: Node2D = $Consequence
@onready var portal: Area2D = $Portal
@onready var touch_controls: TouchControls = $TouchControls
@onready var try_again_node: CanvasLayer = $TryAgain
@onready var try_again_btn: TextureButton = $TryAgain/Control/TextureButton

var is_detective: bool = false
var sidekick_player_node: CharacterBody2D = null
var detective_player_node: CharacterBody2D = null

const PLAYER_SCALE: Vector2   = Vector2(0.2, 0.2)
const ALTAR_SCENE: String     = "res://scenes/world/climax/AltarDeduction.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/mainMenu/MainMenu.tscn"
const BAKUNAWA_SCENE: String  = "res://scenes/world/climax/Bakunawa.tscn"
const NUNO_TRIGGER_DISTANCE: float = 150.0

const SPOTLIGHT_RADIUS: float   = 100.0
const SPOTLIGHT_SOFTNESS: float = 60.0

var _intro_resolved := false

var _darkness_overlay: ColorRect = null
var _overlay_material: ShaderMaterial = null
var _nuno_pairs: Array = []

var _detective_in_portal := false
var _sidekick_in_portal  := false
var _altar_loading := false

# --- You Have Failed UI ---
var _fail_audio: AudioStreamPlayer = null
var _fail_shown := false


func _ready() -> void:
	touch_controls.visible = false
	spotlight.visible = false
	try_again_node.visible = false
	try_again_btn.pressed.connect(_on_try_again_pressed)
	CutsceneHelper.prepare_mobile_video_player(video_player)
	_play_intro()

func _process(_delta: float) -> void:
	if not is_detective and sidekick_player_node != null:
		_update_overlay_spotlight()
	_check_portal_overlap()
	
func _check_portal_overlap() -> void:
	if detective_player_node == null or sidekick_player_node == null:
		return

	var bodies := portal.get_overlapping_bodies()

	var det_inside := detective_player_node in bodies
	var sid_inside := sidekick_player_node in bodies

	if det_inside != _detective_in_portal or sid_inside != _sidekick_in_portal:
		_detective_in_portal = det_inside
		_sidekick_in_portal  = sid_inside

		if _detective_in_portal and _sidekick_in_portal:
			_load_altar.rpc()

func _create_darkness_overlay() -> void:
	var shader := load("res://scenes/world/climax/darkness_overlay.gdshader") as Shader
	if shader == null:
		push_error("[Bakunawa] darkness_overlay.gdshader not found!")
		return

	_overlay_material = ShaderMaterial.new()
	_overlay_material.shader = shader
	_overlay_material.set_shader_parameter("spotlight_radius",   SPOTLIGHT_RADIUS)
	_overlay_material.set_shader_parameter("spotlight_softness", SPOTLIGHT_SOFTNESS)
	_overlay_material.set_shader_parameter("spotlight_uv",       Vector2(0.5, 0.5))

	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 10
	canvas_layer.follow_viewport_enabled = false
	add_child(canvas_layer)

	_darkness_overlay               = ColorRect.new()
	_darkness_overlay.material      = _overlay_material
	_darkness_overlay.anchor_left   = 0.0
	_darkness_overlay.anchor_top    = 0.0
	_darkness_overlay.anchor_right  = 1.0
	_darkness_overlay.anchor_bottom = 1.0
	_darkness_overlay.offset_left   = 0.0
	_darkness_overlay.offset_top    = 0.0
	_darkness_overlay.offset_right  = 0.0
	_darkness_overlay.offset_bottom = 0.0

	canvas_layer.add_child(_darkness_overlay)

func _update_overlay_spotlight() -> void:
	if _darkness_overlay == null or _overlay_material == null:
		return

	var cam_transform := get_viewport().get_canvas_transform()
	var vp_size       := get_viewport().get_visible_rect().size

	var screen_pos := cam_transform * sidekick_player_node.global_position
	var uv         := screen_pos / vp_size

	_overlay_material.set_shader_parameter("spotlight_uv", uv)


func _fit_video_to_screen() -> void:
	var screen_size := get_viewport().get_visible_rect().size
	video_player.expand = true
	video_player.set_deferred("anchors_preset", Control.PRESET_FULL_RECT)
	video_player.set_deferred("offset_left",   0)
	video_player.set_deferred("offset_top",    0)
	video_player.set_deferred("offset_right",  screen_size.x)
	video_player.set_deferred("offset_bottom", screen_size.y)
	video_player.set_deferred("size",          screen_size)
	video_player.set_deferred("position",      Vector2.ZERO)


func _play_intro() -> void:
	_fit_video_to_screen()
	$IntroScene.visible = true
	CutsceneHelper.play_with_fallback(self, video_player, _on_intro_finished, 2.5, 120.0)

func _on_intro_finished() -> void:
	if _intro_resolved:
		return
	_intro_resolved = true
	$IntroScene.visible = false
	MusicController.play_track(MusicController.MusicTrack.BAKUNAWA)
	_setup_touch_controls()
	touch_controls.visible = true
	_spawn_players()
	_setup_consequence()
	_setup_portal()


func _setup_touch_controls() -> void:
	touch_controls.set_button_visible("left",      true)
	touch_controls.set_button_visible("right",     true)
	touch_controls.set_button_visible("pause",     true)
	touch_controls.set_button_visible("map",       false)
	touch_controls.set_button_visible("ledger",    false)
	touch_controls.set_button_visible("briefcase", false)
	touch_controls.set_button_visible("jump",      true)


func _spawn_players() -> void:
	is_detective = (GameState.local_role == GameState.Role.DETECTIVE)

	var detective_scene: PackedScene = preload("res://scenes/players/PlayerHost.tscn")
	var sidekick_scene: PackedScene  = preload("res://scenes/players/PlayerSidekick.tscn")

	var detective := detective_scene.instantiate() as CharacterBody2D
	detective.avatar_scale = PLAYER_SCALE
	detective.prepare_deferred_spawn()
	detective.name = "DetectivePlayer"
	add_child(detective)
	detective.set_multiplayer_authority(1)
	await get_tree().process_frame
	detective.initialize_spawn(detective_spawn.global_position)
	detective_player_node = detective
	detective.add_to_group("detective_player")

	var sidekick := sidekick_scene.instantiate() as CharacterBody2D
	sidekick.avatar_scale = PLAYER_SCALE
	sidekick.prepare_deferred_spawn()
	sidekick.name = "SidekickPlayer"
	add_child(sidekick)
	var sidekick_authority: int = 2 if is_detective else multiplayer.get_unique_id()
	sidekick.set_multiplayer_authority(sidekick_authority)
	await get_tree().process_frame
	sidekick.initialize_spawn(sidekick_spawn.global_position)
	sidekick_player_node = sidekick
	sidekick.add_to_group("sidekick_player")

	await get_tree().process_frame

	var local_player := detective_player_node if is_detective else sidekick_player_node
	if local_player.has_method("_force_initial_sync"):
		local_player._force_initial_sync()

	if is_detective:
		_setup_detective_camera(detective)
	else:
		_setup_sidekick_camera(sidekick)

@rpc("any_peer", "reliable", "call_local")
func _register_sidekick_id(real_peer_id: int) -> void:
	if not is_detective:
		return
	if is_instance_valid(sidekick_player_node):
		sidekick_player_node.name = str(real_peer_id)
		sidekick_player_node.set_multiplayer_authority(real_peer_id)

func _setup_detective_camera(player: CharacterBody2D) -> void:
	var sidekick_cam = sidekick_player_node.get_node_or_null("Camera2D")
	if sidekick_cam != null:
		sidekick_cam.enabled = false

	var detective_cam = player.get_node_or_null("Camera2D")
	if detective_cam != null:
		detective_cam.enabled = true
		detective_cam.make_current()

func _setup_sidekick_camera(player: CharacterBody2D) -> void:
	var detective_cam = detective_player_node.get_node_or_null("Camera2D")
	if detective_cam != null:
		detective_cam.enabled = false

	var sidekick_cam = player.get_node_or_null("Camera2D")
	if sidekick_cam != null:
		sidekick_cam.enabled = true
		sidekick_cam.make_current()

	_create_darkness_overlay()


func _setup_consequence() -> void:
	for i in range(1, 10):
		var suffix        := "" if i == 1 else str(i)
		var head: Area2D      = consequence.get_node_or_null("Head"     + suffix)
		var full_body: Area2D = consequence.get_node_or_null("FullBody" + suffix)

		if head != null:
			head.visible     = true
			head.monitoring  = true
			head.monitorable = true

		if full_body != null:
			full_body.visible     = false
			full_body.monitoring  = true
			full_body.monitorable = true

		if head != null:
			var pair := { "head": head, "full_body": full_body, "triggered": false }
			_nuno_pairs.append(pair)

			var pair_ref := pair
			head.body_entered.connect(func(body: Node2D) -> void:
				_on_nuno_head_body_entered(body, pair_ref)
			)

func _on_nuno_head_body_entered(body: Node2D, pair: Dictionary) -> void:
	if body != detective_player_node and body != sidekick_player_node:
		return
	if pair["triggered"]:
		return

	pair["triggered"] = true

	var head: Area2D      = pair["head"]
	var full_body: Area2D = pair["full_body"]

	if is_instance_valid(head):
		head.visible = false

	if full_body != null and is_instance_valid(full_body):
		full_body.visible = true

	# Trigger the penalty and show the failure popup
	_trigger_penalty.rpc()
	_show_fail_popup.rpc()


@rpc("any_peer", "reliable", "call_local")
func _trigger_penalty() -> void:
	_snatch_artifacts()

func _snatch_artifacts() -> void:
	for zone_id in GameState.collected_clues:
		GameState.collected_clues[zone_id]["collected"] = false
	GameState.climax_triggered = false
	GameState.briefcase_updated.emit()


# ---------------------------------------------------------------------------
#  YOU HAVE FAILED – popup
# ---------------------------------------------------------------------------

@rpc("any_peer", "reliable", "call_local")
func _show_fail_popup() -> void:
	if _fail_shown:
		return
	_fail_shown = true

	# --- audio ---
	_fail_audio = AudioStreamPlayer.new()
	var stream := load("res://assets/audios/YouFailedBG.mp3") as AudioStream
	if stream != null:
		_fail_audio.stream = stream
		_fail_audio.autoplay = false
		add_child(_fail_audio)
		_fail_audio.play()
	else:
		push_error("[Bakunawa] YouFailedBG.mp3 not found!")

	# --- show the scene-tree node after a delay ---
	await get_tree().create_timer(2.0).timeout
	touch_controls.visible = false
	try_again_node.visible = true


func _on_try_again_pressed() -> void:
	_restart_game.rpc()

@rpc("any_peer", "reliable", "call_local")
func _restart_game() -> void:
	if _fail_audio != null and _fail_audio.playing:
		_fail_audio.stop()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


# ---------------------------------------------------------------------------
#  Portal
# ---------------------------------------------------------------------------

func _setup_portal() -> void:
	portal.monitoring = true
	portal.monitorable = true
	portal.body_entered.connect(_on_portal_body_entered)
	portal.body_exited.connect(_on_portal_body_exited)

func _on_portal_body_entered(body: Node2D) -> void:
	print("[Portal] body_entered: ", body.name, 
		" | is_detective_node: ", body == detective_player_node,
		" | is_sidekick_node: ", body == sidekick_player_node)
	if body.is_in_group("detective_player"):
		_sync_portal_state.rpc(true, true)
	elif body.is_in_group("sidekick_player"):
		_sync_portal_state.rpc(false, true)

func _on_portal_body_exited(body: Node2D) -> void:
	if body.is_in_group("detective_player"):
		_sync_portal_state.rpc(true, false)
	elif body.is_in_group("sidekick_player"):
		_sync_portal_state.rpc(false, false)

@rpc("any_peer", "reliable", "call_local")
func _sync_portal_state(is_detective_player: bool, entered: bool) -> void:
	if is_detective_player:
		_detective_in_portal = entered
	else:
		_sidekick_in_portal = entered

	if _detective_in_portal and _sidekick_in_portal:
		_load_altar.rpc()

@rpc("any_peer", "reliable", "call_local")
func _load_altar() -> void:
	if _altar_loading:
		return
	_altar_loading = true
	get_tree().call_deferred("change_scene_to_file", ALTAR_SCENE)
