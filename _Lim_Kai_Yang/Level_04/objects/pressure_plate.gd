extends Area2D
signal state_changed(is_pressed: bool)

@export var regular_texture: Texture2D
@export var pressed_texture: Texture2D
@export var hint_text: String = "Put Somethings"

@onready var sprite: Sprite2D = $Sprite2D
@onready var hint_area: Area2D = $HintArea
@onready var hint_label: Label = $HintLabel

var press_count := 0
var is_pressed: bool:
	get: return press_count > 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if regular_texture != null:
		sprite.texture = regular_texture

	hint_area.body_entered.connect(_on_hint_area_entered)
	hint_area.body_exited.connect(_on_hint_area_exited)
	hint_label.text = hint_text
	hint_label.global_position = global_position + Vector2(-40, -30)
	hint_label.hide()

func _on_body_entered(_body: Node2D) -> void:
	press_count += 1
	if press_count == 1:
		state_changed.emit(true)
		_update_visual(true)

func _on_body_exited(_body: Node2D) -> void:
	press_count = max(0, press_count - 1)
	if press_count == 0:
		state_changed.emit(false)
		_update_visual(false)

func _update_visual(pressed: bool) -> void:
	if pressed and pressed_texture != null:
		sprite.texture = pressed_texture
	elif not pressed and regular_texture != null:
		sprite.texture = regular_texture

func _on_hint_area_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_pressed:
		hint_label.show()

func _on_hint_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		hint_label.hide()
