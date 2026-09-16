extends Node2D

@onready var hud: Control = $Hud/hud
@onready var room_exit: Area2D = $RoomExit
@onready var merchant: StaticBody2D = $Merchant
@onready var bridge: StaticBody2D = $Bridge

var player: Node2D = null
var game_over := false 

func _reveal_bridge() -> void:
	bridge.reveal()
	
var enemies_alive := 0

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("Room4: No Player")
		return

	var check_timer := Timer.new()
	check_timer.wait_time = 0.3
	check_timer.timeout.connect(_check_enemies_remaining)
	add_child(check_timer)
	check_timer.start()

	player.health_changed.connect(hud.update_health)
	player.coins_changed.connect(hud.update_coins)
	player.potions_changed.connect(hud.update_potions)
	player.player_died.connect(_on_player_died)
	hud.update_potions(player.potions)


	room_exit.player_entered.connect(_on_win)

var bridge_revealed := false

func _check_enemies_remaining() -> void:
	if bridge_revealed:
		return
	if get_tree().get_nodes_in_group("BridgeGate").is_empty():
		bridge_revealed = true
		_reveal_bridge()
func _on_enemy_died() -> void:
	enemies_alive -= 1
	if enemies_alive <= 0:
		_reveal_bridge()

func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_C:
			if player != null and is_instance_valid(player):
				player.use_potion()

func _on_player_died() -> void:
	print("You died...")

func _on_win() -> void:
	if game_over:
		return
	game_over = true
	print("Congratulation")
