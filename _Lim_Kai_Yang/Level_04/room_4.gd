extends Node2D
## Room 4 总管。玩家换成 Cheok Kai Ren 的 player.gd 之后:
## - 分组改认小写 "player"
## - 死亡不再是"game over等按E重来", 这个新角色死了会自动原地复活(player.gd 自己的 respawn()),
##   所以这里只监听 player_died 信号做个提示, 不再强制重整个场景
## - 喝药水改呼叫 player.heal(1), 因为新角色没有 .health 这个属性, 只有 current_health

@onready var hud: Control = $Hud/hud
@onready var room_exit: Area2D = $RoomExit
@onready var merchant: StaticBody2D = $Merchant

var player: Node2D = null
var game_over := false  # 现在只代表"通关了", 不再代表"死了"
var potion_count := 0

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("Room4: 场景里没有找到 player 组的节点, 先确认 Player 节点分组")
		return

	player.health_changed.connect(hud.update_health)
	player.coins_changed.connect(hud.update_coins)
	player.player_died.connect(_on_player_died)
	hud.update_potions(potion_count)

	if merchant != null:
		merchant.purchased.connect(_on_merchant_purchased)

	room_exit.player_entered.connect(_on_win)

func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_C:
			_drink_potion()

func _drink_potion() -> void:
	if potion_count <= 0:
		print("没有药水可以喝")
		return
	if player == null or not is_instance_valid(player):
		return
	if player.current_health >= player.max_health:
		print("血是满的, 先不喝")
		return

	potion_count -= 1
	hud.update_potions(potion_count)
	player.heal(1)

func _on_merchant_purchased(_item_name: String, reward_type: int) -> void:
	if reward_type == 2:  # merchant.gd 里 RewardType.POTION
		potion_count += 1
		hud.update_potions(potion_count)

func _on_player_died() -> void:
	print("你被打倒了, 复活中...")
	# 新角色会自己 respawn(), 这里不用做任何强制重来的处理

func _on_win() -> void:
	if game_over:
		return
	game_over = true
	print("通关! 按 E 再玩一次")
