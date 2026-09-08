extends StaticBody2D
@export var hint_text: String = "Defeat the nearby monsters"

@onready var hint_area: Area2D = $HintArea
@onready var hint_label: Label = $HintLabel
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var revealed := false

func _ready() -> void:
	sprite.hide()
	collision.set_deferred("disabled", false)
	hint_area.body_entered.connect(_on_hint_area_entered)
	hint_area.body_exited.connect(_on_hint_area_exited)

	hint_label.text = hint_text
	hint_label.global_position = global_position + Vector2(-60, -40)
	hint_label.hide()
	
func _on_hint_area_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not revealed:
		hint_label.show()

func _on_hint_area_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		hint_label.hide()

func reveal() -> void:
	revealed = true
	sprite.show()
	collision.set_deferred("disabled", true) 
	hint_label.hide()
