extends Area2D

signal activated(lever_id: int, is_on: bool)

@export var lever_id: int = 0
@export var starts_on: bool = false

var player_nearby: bool = false
var is_on: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_prompt: Label = $InteractionPrompt


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	is_on = starts_on
	update_visual()
	interaction_prompt.hide()


func _process(_delta: float) -> void:
	if not player_nearby:
		return

	if Input.is_action_just_pressed("interact"):
		toggle_lever()


func toggle_lever() -> void:
	is_on = not is_on
	update_visual()
	activated.emit(lever_id, is_on)


func update_visual() -> void:
	if animated_sprite == null:
		return

	if is_on:
		if animated_sprite.sprite_frames.has_animation("On"):
			animated_sprite.play("On")
		elif animated_sprite.sprite_frames.has_animation("on"):
			animated_sprite.play("on")
	else:
		if animated_sprite.sprite_frames.has_animation("Off"):
			animated_sprite.play("Off")
		elif animated_sprite.sprite_frames.has_animation("off"):
			animated_sprite.play("off")


func reset_lever() -> void:
	is_on = starts_on
	update_visual()

	if player_nearby:
		interaction_prompt.show()
	else:
		interaction_prompt.hide()


func set_state(value: bool) -> void:
	is_on = value
	update_visual()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player_nearby = true
	interaction_prompt.show()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player_nearby = false
	interaction_prompt.hide()
