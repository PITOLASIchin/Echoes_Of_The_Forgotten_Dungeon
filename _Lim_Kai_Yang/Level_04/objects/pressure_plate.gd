extends Area2D
## 压力板:玩家或箱子压上去触发,离开就松开。
## 和队友的拉杆(按E交互)区分:这个是"物理压住"逻辑。
##
## 场景树:
## PressurePlate (Area2D) [挂本脚本]
## ├── Sprite2D              (贴图先随便指一张占位, Regular/Pressed 会在
## │                          _ready() 和状态变化时自动接管显示)
## └── CollisionShape2D      (RectangleShape2D 40x40, 故意比64px tile小,
##                            必须真的站上去才触发)
##
## 碰撞设置(检查器):
## Layer = 无(全部取消勾选), Mask = 1(玩家和箱子的身体都在第1层)
##
## 贴图设置(检查器里, 本脚本导出的两个字段):
## Regular Texture → SmallRedSquareButton_Regular.png (128x128, 独立文件)
## Pressed Texture → SmallRedSquareButton_Pressed.png (128x128, 独立文件)
## 这两张是两个独立png, 不是一张spritesheet, 所以是切换texture不是切换frame。
## 128px 比 64px tile 大一倍, 记得把 Sprite2D 的 Scale 设成 0.4~0.45,
## 让按钮视觉上和地板 tile 比例协调(128 × 0.4 ≈ 51px)

signal state_changed(is_pressed: bool)

@export var regular_texture: Texture2D
@export var pressed_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D

var press_count := 0

var is_pressed: bool:
	get: return press_count > 0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if regular_texture != null:
		sprite.texture = regular_texture

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
