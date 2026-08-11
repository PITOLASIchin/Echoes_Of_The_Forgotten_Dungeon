extends CharacterBody2D
## 可推动的箱子 —— 支援 Cheok Kai Ren 的 player.gd。
## 改用四个各自独立的方向侦测区(PushZone), 玩家从哪一侧的 zone 进来,
## 就只能往"穿过箱子"的那个方向推 —— 不再靠"箱子跟玩家的相对位置"去算方向。
## 旧算法在新角色的碰撞体积/轴心跟旧骑士不同时, 相对位置很容易在两轴之间抖动,
## 这就是"贴着不放"跟"要左右交替按才推得动"的成因。
##
## 场景树:
## PushableBox (CharacterBody2D) [挂本脚本]
## ├── Sprite2D
## ├── CollisionShape2D       (箱子本体, RectangleShape2D 14x14)
## ├── PushZoneUp    (Area2D, position = Vector2(0, -12), 贴在箱子上方)
## ├── PushZoneDown  (Area2D, position = Vector2(0, 12), 贴在箱子下方)
## ├── PushZoneLeft  (Area2D, position = Vector2(-12, 0), 贴在箱子左边)
## └── PushZoneRight (Area2D, position = Vector2(12, 0), 贴在箱子右边)
## 每个 PushZone 底下都要挂 CollisionShape2D, 用扁长方形盖住那一侧
## (Up/Down 用 RectangleShape2D 12x6, Left/Right 用 6x12)
##
## 碰撞设置(检查器):
## PushableBox 本体: Layer = 1, Mask = 1
## 每个 PushZone: Layer = 无, Mask = 1(侦测玩家所在的层)

@export var push_speed: float = 150.0
## 玩家速度朝"穿过箱子"方向的分量超过这个值才算"在推"
@export var push_threshold: float = 30.0

@onready var zone_directions: Dictionary = {
	$PushZoneUp: Vector2.DOWN,
	$PushZoneDown: Vector2.UP,
	$PushZoneLeft: Vector2.RIGHT,
	$PushZoneRight: Vector2.LEFT,
}

var occupants: Dictionary = {}  # zone(Area2D) -> 目前站在里面的玩家, 或 null

func _ready() -> void:
	for zone: Area2D in zone_directions:
		zone.body_entered.connect(_on_zone_entered.bind(zone))
		zone.body_exited.connect(_on_zone_exited.bind(zone))
		occupants[zone] = null

func _on_zone_entered(body: Node2D, zone: Area2D) -> void:
	if body.is_in_group("player"):
		occupants[zone] = body
		print("进来的是: ", body.name, " 分组: ", body.get_groups())

func _on_zone_exited(body: Node2D, zone: Area2D) -> void:
	if occupants[zone] == body:
		occupants[zone] = null

func _physics_process(_delta: float) -> void:
	velocity = Vector2.ZERO

	var move_input: Vector2 = Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)

	if move_input == Vector2.ZERO:
		move_and_slide()
		return

	for zone: Area2D in zone_directions:
		var player: Node2D = occupants[zone]
		if player == null or not is_instance_valid(player):
			continue

		var push_dir: Vector2 = zone_directions[zone]
		if move_input.dot(push_dir) > 0.5:
			velocity = push_dir * push_speed
			break

	move_and_slide()
