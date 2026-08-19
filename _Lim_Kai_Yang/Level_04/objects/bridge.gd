extends StaticBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	sprite.hide()
	collision.set_deferred("disabled", false)  # 一开始挡住, 过不去

func reveal() -> void:
	sprite.show()
	collision.set_deferred("disabled", true)   # 桥出现, 移除阻挡, 可以走过去
