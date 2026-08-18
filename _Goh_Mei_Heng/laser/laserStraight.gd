extends Area2D

enum LaserColor {
	RED,
	BLUE,
	GREEN
}

# ==========================
# SETTINGS
# ==========================

@export var laser_color: LaserColor = LaserColor.RED

@export var damage: int = 1
@export var laser_thickness: float = 1.0
@export var tile_size: float = 8.0

@onready var sprite: Sprite2D = $Sprite2D

@onready var collision_shape: CollisionShape2D = (
	$CollisionShape2D
)

func _ready() -> void:
	if not body_entered.is_connected(
		_on_body_entered
	):
		body_entered.connect(
			_on_body_entered
		)

func get_laser_color() -> int:
	return laser_color

func setup_straight(
	piece_position: Vector2,
	direction: Vector2
) -> void:
	global_position = piece_position
	global_rotation = 0.0

	sprite.position = Vector2.ZERO
	sprite.scale = Vector2.ONE
	sprite.rotation = 0.0

	direction = direction.round()

	if (
		direction == Vector2.LEFT
		or direction == Vector2.RIGHT
	):
		sprite.rotation_degrees = 90.0
	else:
		sprite.rotation_degrees = 0.0

	setup_straight_collision(direction)

func setup_straight_collision(
	direction: Vector2
) -> void:
	var rectangle: RectangleShape2D = (
		RectangleShape2D.new()
	)

	if (
		direction == Vector2.LEFT
		or direction == Vector2.RIGHT
	):
		rectangle.size = Vector2(
			tile_size,
			laser_thickness
		)
	else:
		rectangle.size = Vector2(
			laser_thickness,
			tile_size
		)

	collision_shape.shape = rectangle
	collision_shape.position = Vector2.ZERO
	collision_shape.rotation = 0.0

func setup_corner(
	piece_position: Vector2,
	incoming_direction: Vector2,
	outgoing_direction: Vector2
) -> void:
	global_position = piece_position
	global_rotation = 0.0

	sprite.position = Vector2.ZERO
	sprite.scale = Vector2.ONE
	sprite.rotation = 0.0

	sprite.rotation = get_corner_rotation(
		incoming_direction,
		outgoing_direction
	)

	setup_corner_collision()

func get_corner_rotation(
	incoming_direction: Vector2,
	outgoing_direction: Vector2
) -> float:
	incoming_direction = incoming_direction.round()
	outgoing_direction = outgoing_direction.round()

	if (
		incoming_direction == Vector2.UP
		and outgoing_direction == Vector2.RIGHT
	):
		return deg_to_rad(0.0)

	if (
		incoming_direction == Vector2.LEFT
		and outgoing_direction == Vector2.DOWN
	):
		return deg_to_rad(0.0)

	if (
		incoming_direction == Vector2.RIGHT
		and outgoing_direction == Vector2.DOWN
	):
		return deg_to_rad(90.0)

	if (
		incoming_direction == Vector2.UP
		and outgoing_direction == Vector2.LEFT
	):
		return deg_to_rad(90.0)

	if (
		incoming_direction == Vector2.RIGHT
		and outgoing_direction == Vector2.UP
	):
		return deg_to_rad(180.0)

	if (
		incoming_direction == Vector2.DOWN
		and outgoing_direction == Vector2.LEFT
	):
		return deg_to_rad(180.0)

	if (
		incoming_direction == Vector2.LEFT
		and outgoing_direction == Vector2.UP
	):
		return deg_to_rad(270.0)

	if (
		incoming_direction == Vector2.DOWN
		and outgoing_direction == Vector2.RIGHT
	):
		return deg_to_rad(270.0)

	return 0.0

func setup_corner_collision() -> void:
	var rectangle: RectangleShape2D = (
		RectangleShape2D.new()
	)

	rectangle.size = Vector2(
		tile_size,
		tile_size
	)

	collision_shape.shape = rectangle
	collision_shape.position = Vector2.ZERO
	collision_shape.rotation = 0.0

func _on_body_entered(
	body: Node2D
) -> void:
	if not body.is_in_group("Player"):
		return
