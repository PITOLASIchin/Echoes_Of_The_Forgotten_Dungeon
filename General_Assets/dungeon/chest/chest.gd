extends StaticBody2D

signal toggled(active: bool)

@export var coin_scene: PackedScene
@export var min_coins: int = 3
@export var max_coins: int = 6

@onready var interaction_area: Area2D = $Area2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var player_near: bool = false
var active: bool = false
var coins_spawned: bool = false

func _ready() -> void:
	if not interaction_area.body_entered.is_connected(
		_on_body_entered
	):
		interaction_area.body_entered.connect(
			_on_body_entered
		)

	if not interaction_area.body_exited.is_connected(
		_on_body_exited
	):
		interaction_area.body_exited.connect(
			_on_body_exited
		)

	sprite.play("closed")

func _process(_delta: float) -> void:
	if not player_near:
		return

	if not Input.is_action_just_pressed("interact"):
		return

	if active:
		return

	open_chest()

func open_chest() -> void:
	active = true

	sprite.play("open")
	toggled.emit(active)

	if not coins_spawned:
		spawn_coins()
		coins_spawned = true

func spawn_coins() -> void:
	var amount := randi_range(min_coins, max_coins)

	for index in range(amount):
		var coin := coin_scene.instantiate() as CharacterBody2D

		get_tree().current_scene.add_child(coin)

		# Random spread that still points downward.
		var spread := deg_to_rad(
			randf_range(-20.0, 20.0)
		)

		var direction := Vector2.DOWN.rotated(spread)

		coin.global_position = (
			global_position
			+ Vector2.DOWN * 10.0
		)

		coin.pop_out(direction)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") or body.is_in_group("player"):
		player_near = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player") or body.is_in_group("player"):
		player_near = false
