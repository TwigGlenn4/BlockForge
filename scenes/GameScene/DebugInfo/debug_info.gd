extends Control

var children: Array[Node] = []

func _ready() -> void:
    children = get_children()
    set_visibility(false)

func _input(_event: InputEvent) -> void:
    if Input.is_action_just_pressed("toggle_debug_info"):
        set_visibility(!visible)

func set_visibility(visiblility: bool) -> void:
    visible = visiblility
    for child: Node in children:
        child.visible = visiblility
