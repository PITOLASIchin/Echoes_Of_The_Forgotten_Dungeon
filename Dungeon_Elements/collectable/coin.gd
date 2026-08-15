extends CharacterBody2D


@export var value: int = 1

@export var min_pop_speed: float = 80.0
@export var max_pop_speed: float = 120.0
@export var friction: float = 110.0
@export var bounce_strength: float = 0.90
@export var pickup_delay: float = 0.3
@export var minimum_speed: float = 3.0

@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var pickup_area: Area2D = $PickupArea
@onready var pickup_collision: CollisionShape2D = (
	$PickupArea/CollisionShape2D
)
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var collected: bool = false
var can_be_collected: bool = false

func _ready() -> void:
	if not pickup_area.body_entered.is_connected(
		_on_pickup_area_body_entered
	):
		pickup_area.body_entered.connect(
			_on_pickup_area_body_entered
		)

	if not animation_player.animation_finished.is_connected(
		_on_animation_finished
	):
		animation_player.animation_finished.connect(
			_on_animation_finished
		)

	pickup_area.set_deferred("monitoring", false)

	enable_pickup_after_delay()


func _physics_process(delta: float) -> void:
	if collected:
		return

	if velocity.length() <= minimum_speed:
		velocity = Vector2.ZERO
		return

	var collision := move_and_collide(
		velocity * delta
	)

	if collision:
		velocity = velocity.bounce(
			collision.get_normal()
		) * bounce_strength

	velocity = velocity.move_toward(
		Vector2.ZERO,
		friction * delta
	)

func pop_out(direction: Vector2) -> void:
	if direction.length_squared() < 0.01:
		direction = Vector2.DOWN

	var pop_speed := randf_range(
		min_pop_speed,
		max_pop_speed
	)

	velocity = direction.normalized() * pop_speed

	print("Coin direction: ", direction)
	print("Coin velocity: ", velocity)

func enable_pickup_after_delay() -> void:
	await get_tree().create_timer(
		pickup_delay
	).timeout

	if collected:
		return

	can_be_collected = true
	pickup_area.set_deferred("monitoring", true)

func _on_pickup_area_body_entered(
	body: Node2D
) -> void:
	if collected:
		return

	if not can_be_collected:
		return

	if not (body.is_in_group("Player") or body.is_in_group("player")):
		return

	collected = true
	can_be_collected = false
	velocity = Vector2.ZERO

	body_collision.set_deferred("disabled", true)
	pickup_collision.set_deferred("disabled", true)
	pickup_area.set_deferred("monitoring", false)

	if body.has_method("add_coins"):
		body.add_coins(value)

	animation_player.play("pickup")

func _on_animation_finished(
	animation_name: StringName
) -> void:
	if animation_name == &"pickup":
		queue_free()
