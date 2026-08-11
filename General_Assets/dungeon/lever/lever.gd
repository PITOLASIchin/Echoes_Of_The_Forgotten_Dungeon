extends StaticBody2D

signal toggled(active: bool)

@onready var area_2d: Area2D = $Area2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var player_near := false
var active := false

func _ready():
	area_2d.body_entered.connect(_on_body_entered)
	area_2d.body_exited.connect(_on_body_exited)

func _process(delta):
	if player_near and Input.is_action_just_pressed("interact"):
		active = !active

		if active:
			sprite.play("on")
		else:
			sprite.play("off")

		toggled.emit(active)

func _on_body_entered(body):
	if body.is_in_group("Player"):
		player_near = true

func _on_body_exited(body):
	if body.is_in_group("Player"):
		player_near = false
