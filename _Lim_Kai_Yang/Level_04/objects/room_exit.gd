extends Area2D
## 关卡出口:玩家走进来就发出信号, 通知 Room4 总管"到达出口了"。
## 场景树:
## RoomExit (Area2D) [挂本脚本]
## ├── Sprite2D 或 AnimatedSprite2D   (出口贴图)
## └── CollisionShape2D

@export_file("*.tscn") var next_scene_path: String = ""

signal player_entered

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	player_entered.emit()
	if next_scene_path != "":
		get_tree().call_deferred("change_scene_to_file", next_scene_path)
