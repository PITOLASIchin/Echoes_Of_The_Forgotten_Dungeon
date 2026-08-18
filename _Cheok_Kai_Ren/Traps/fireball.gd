extends Area2D

@export var speed: float = 260.0
@export var damage: int = 1
@export var knockback_force: float = 180.0
@export var lifetime: float = 6.0

var direction: Vector2 = Vector2.RIGHT
var has_hit_something: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = (
	$VisibleOnScreenNotifier2D
)


func _ready() -> void:
	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not screen_notifier.screen_exited.is_connected(
		_on_screen_exited
	):
		screen_notifier.screen_exited.connect(
			_on_screen_exited
		)

	animated_sprite.play("fly")

	await get_tree().create_timer(lifetime).timeout

	if is_instance_valid(self):
		queue_free()


func _physics_process(delta: float) -> void:
	if has_hit_something:
		return

	global_position += direction * speed * delta


func set_direction(new_direction: Vector2) -> void:
	if new_direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	else:
		direction = new_direction.normalized()

	rotation = (
		direction.angle()
		+ deg_to_rad(90.0)
	)


func _on_body_entered(body: Node2D) -> void:
	if has_hit_something:
		return

	has_hit_something = true

	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(
				damage,
				global_position,
				knockback_force
			)

		destroy_fireball()
		return

	# Any non-player physics body is treated as a wall or obstacle.
	destroy_fireball()


func destroy_fireball() -> void:
	if has_hit_something:
		collision_shape.set_deferred(
			"disabled",
			true
		)

		queue_free()


func _on_screen_exited() -> void:
	if is_instance_valid(self):
		queue_free()
