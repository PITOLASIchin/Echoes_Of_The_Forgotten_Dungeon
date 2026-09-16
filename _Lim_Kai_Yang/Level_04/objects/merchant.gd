extends StaticBody2D

signal purchased(item_name: String, reward_type: int)
signal purchase_failed(item_name: String, reason: String)

enum RewardType { KEY, HEAL, POTION, CUSTOM }
@export var hint_text: String = "Press E to Buy"
@export var item_name: String = "Health Potion"
@export var item_cost: int = 5
@export var reward_type: RewardType = RewardType.POTION
@export var item_icon: Texture2D
@export var stock: int = -1
@export var popup_path: NodePath

@onready var interaction_area: Area2D = $Area2D
@onready var hint_label: Label = $HintLabel

var popup: Control = null
var player: Node2D = null
var player_near := false
var shop_open := false
var sold_out := false

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

	if popup_path.is_empty():
		push_warning("Merchant: popup_path havent set, popup path no show")
	else:
		popup = get_node(popup_path) as Control
		popup.close()
		
	hint_label.text = hint_text
	hint_label.global_position = global_position + Vector2(-40, -50)
	hint_label.hide()

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
	hint_label.hide()

func _close_shop() -> void:
	shop_open = false
	popup.close()

func _try_purchase() -> void:
	if player == null or not player.has_method("spend_coins"):
		push_warning("Merchant: player no spend_coins()")
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

		RewardType.POTION:
			if player.has_method("add_potions"):
				player.add_potions(1)

		RewardType.CUSTOM:
			pass

	if stock > 0:
		stock -= 1
		if stock == 0:
			sold_out = true

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		player_near = true
		hint_label.show()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_near = false
		_close_shop()
		hint_label.show() if false else hint_label.hide()
