extends CanvasLayer

@onready var detective_dialogue: Node = $Panel/DetectiveDialogue
@onready var sidekick_dialogue: Node  = $Panel/SidekickDialogue
@onready var text_label: Label = $Panel/Text
@onready var advance_btn: TouchScreenButton = $Panel/Advance

var _system: DialogueSystem


func _ready() -> void:
	# Must still work while the game tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	advance_btn.pressed.connect(_on_advance_pressed)


func bind_system(system: DialogueSystem) -> void:
	_system = system


func set_line(speaker: String, line_text: String) -> void:
	var is_sidekick := (speaker == "sidekick")
	if is_instance_valid(detective_dialogue):
		detective_dialogue.visible = not is_sidekick
	if is_instance_valid(sidekick_dialogue):
		sidekick_dialogue.visible = is_sidekick
	text_label.text = line_text


func _on_advance_pressed() -> void:
	if _system:
		_system.next()
