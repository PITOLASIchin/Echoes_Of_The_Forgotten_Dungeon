extends StaticBody2D
## 多按钮路障巨石:所有关联的压力板同时被压住,巨石就消失(可通行);
## 任何一块松开,巨石重新出现挡路。
## 谜题设计:两块板 → 玩家站一块 + 箱子压一块 = 核心解法。
## 和队友的 gate(RayCast 感应自动开)完全不同的机制。
##
## 场景树:
## PlateDoor (StaticBody2D) [挂本脚本]
## ├── Sprite2D              (单张贴图, 比如 Rock1.png/Rock2.png,
##                            不需要两帧, 逻辑是隐藏/显示整个 Sprite2D)
## └── CollisionShape2D      (RectangleShape2D 64x64, 整格挡住)
##
## 碰撞设置: Layer = 1, Mask = 无
##
## 连接方式: 检查器 → Plate Paths → 点 Add Element,
## 把场景里每块压力板拖进去(可以 1 块也可以多块)

@export var plate_paths: Array[NodePath] = []

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var plates: Array = []

func _ready() -> void:
	if plate_paths.is_empty():
		push_warning("PlateDoor: 没有关联任何压力板, 门永远不会开")
		return
	for path in plate_paths:
		var plate := get_node(path)
		plates.append(plate)
		plate.state_changed.connect(_on_any_plate_changed)

func _on_any_plate_changed(_pressed: bool) -> void:
	var all_pressed := true
	for plate in plates:
		if not plate.is_pressed:
			all_pressed = false
			break
	_set_open(all_pressed)

func _set_open(open: bool) -> void:
	collision.set_deferred("disabled", open)
	if sprite.hframes >= 2:
		sprite.frame = 1 if open else 0
	else:
		sprite.visible = not open
