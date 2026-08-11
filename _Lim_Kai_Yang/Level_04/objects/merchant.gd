extends StaticBody2D
## 商人 NPC:玩家靠近后按 E 打开商品弹窗, 弹窗开着时再按一次 E 购买。
## 参考 lever.gd / chest.gd 的 "Area2D + interact" 套路。
##
## 场景树:
## Merchant (StaticBody2D)
## ├── AnimatedSprite2D
## ├── CollisionShape2D      (本体, 挡路)
## └── Area2D                (侦测玩家)
##     └── CollisionShape2D
##
## popup_path 要在 Inspector 里手动指到 Room4HUD 底下的 ShopPopup,
## 比如 "../Room4HUD/ShopPopup"(实际路径依你场景摆放的层级为准)。

signal purchased(item_name: String, reward_type: int)
signal purchase_failed(item_name: String, reason: String)

enum RewardType { KEY, HEAL, POTION, CUSTOM }

@export var item_name: String = "回复药水"
@export var item_cost: int = 5
@export var reward_type: RewardType = RewardType.POTION
@export var item_icon: Texture2D
@export var stock: int = -1
@export var popup_path: NodePath

@onready var interaction_area: Area2D = $Area2D

var popup: Control = null
var player: Node2D = null
var player_near := false
var shop_open := false
var sold_out := false

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

	if popup_path.is_empty():
		push_warning("Merchant: popup_path 没设定, 商品弹窗不会显示")
	else:
		popup = get_node(popup_path) as Control
		popup.close()

func _process(_delta: float) -> void:
	if not player_near or sold_out or popup == null:
		return
	if not Input.is_action_just_pressed("interact"):
		return

	if not shop_open:
		_open_shop()
	else:
		_try_purchase()

func _open_shop() -> void:
	shop_open = true
	popup.open(item_name, item_cost, item_icon)

func _close_shop() -> void:
	shop_open = false
	popup.close()

func _try_purchase() -> void:
	if player == null or not player.has_method("spend_coins"):
		push_warning("Merchant: player 没有 spend_coins(), 先去 knight_1.gd 补上")
		return

	if not player.spend_coins(item_cost):
		popup.show_not_enough_coins()
		purchase_failed.emit(item_name, "not_enough_coins")
		return

	popup.show_purchased()
	purchased.emit(item_name, reward_type)

	match reward_type:
		RewardType.KEY:
			if player.has_method("add_keys"):
				player.add_keys(1)
		RewardType.HEAL:
			if player.has_method("heal"):
				player.heal(1)
		RewardType.POTION, RewardType.CUSTOM:
			pass # 药水数量记在 Room4 自己身上(room_4.gd), 不记进共用的 knight_1.gd

	if stock > 0:
		stock -= 1
		if stock == 0:
			sold_out = true

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		player_near = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_near = false
		_close_shop()
