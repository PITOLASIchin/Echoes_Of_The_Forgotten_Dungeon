@tool
extends StaticBody2D

signal mirror_rotated

enum MirrorOrientation {
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_RIGHT,
	BOTTOM_LEFT
}

@export var can_rotate: bool = true

@export var orientation: MirrorOrientation = (
	MirrorOrientation.TOP_LEFT
):
	set(value):
		orientation = value
		update_visual()

@export_group("Mirror Textures")

@export var top_left_texture: Texture2D:
	set(value):
		top_left_texture = value
		update_visual()

@export var top_right_texture: Texture2D:
	set(value):
		top_right_texture = value
		update_visual()

@export var bottom_right_texture: Texture2D:
	set(value):
		bottom_right_texture = value
		update_visual()

@export var bottom_left_texture: Texture2D:
	set(value):
		bottom_left_texture = value
		update_visual()

@onready var sprite: Sprite2D = get_node_or_null(
	"Sprite2D"
)

@onready var interaction_area: Area2D = get_node_or_null(
	"InteractionArea"
)

var player_near: bool = false
var mirror_is_removed: bool = false

func _ready() -> void:
	update_visual()

	if Engine.is_editor_hint():
		return

	add_to_group("LaserMirror")

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

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not player_near:
		return

	if (
		can_rotate
		and not mirror_is_removed
		and Input.is_action_just_pressed("interact")
	):
		rotate_mirror()

	if Input.is_action_just_pressed("remove"):
		toggle_mirror()
	

func rotate_mirror() -> void:
	orientation = (
		orientation + 1
	) % MirrorOrientation.size()

	update_visual()
	mirror_rotated.emit()

func toggle_mirror() -> void:
	mirror_is_removed = not mirror_is_removed

	sprite.visible = not mirror_is_removed

	$CollisionShape2D.set_deferred(
		"disabled",
		mirror_is_removed
	)

	if mirror_is_removed:
		remove_from_group("LaserMirror")
	else:
		add_to_group("LaserMirror")
		update_visual()

	mirror_rotated.emit()
	
func update_visual() -> void:
	if not is_inside_tree():
		return

	if sprite == null:
		sprite = get_node_or_null("Sprite2D")

	if sprite == null:
		return

	match orientation:
		MirrorOrientation.TOP_LEFT:
			sprite.texture = top_left_texture

		MirrorOrientation.TOP_RIGHT:
			sprite.texture = top_right_texture

		MirrorOrientation.BOTTOM_RIGHT:
			sprite.texture = bottom_right_texture

		MirrorOrientation.BOTTOM_LEFT:
			sprite.texture = bottom_left_texture

func get_reflected_direction(
	incoming_direction: Vector2
) -> Vector2:
	var direction := get_cardinal_direction(
		incoming_direction
	)

	match orientation:
		MirrorOrientation.TOP_LEFT:
			return reflect_top_left(direction)

		MirrorOrientation.TOP_RIGHT:
			return reflect_top_right(direction)

		MirrorOrientation.BOTTOM_RIGHT:
			return reflect_bottom_right(direction)

		MirrorOrientation.BOTTOM_LEFT:
			return reflect_bottom_left(direction)

	return Vector2.ZERO


func get_cardinal_direction(
	direction: Vector2
) -> Vector2:
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0.0:
			return Vector2.RIGHT

		return Vector2.LEFT

	if direction.y > 0.0:
		return Vector2.DOWN

	return Vector2.UP


func reflect_top_left(
	direction: Vector2
) -> Vector2:
	# Laser enters from the right and exits upward.
	if direction == Vector2.RIGHT:
		return Vector2.DOWN

	# Laser enters from below and exits left.
	if direction == Vector2.UP:
		return Vector2.LEFT

	return Vector2.ZERO


func reflect_top_right(
	direction: Vector2
) -> Vector2:
	# Laser enters from the left and exits upward.
	if direction == Vector2.LEFT:
		return Vector2.DOWN

	# Laser enters from below and exits right.
	if direction == Vector2.UP:
		return Vector2.RIGHT

	return Vector2.ZERO


func reflect_bottom_right(
	direction: Vector2
) -> Vector2:
	# Laser enters from the left and exits downward.
	if direction == Vector2.LEFT:
		return Vector2.UP

	# Laser enters from above and exits right.
	if direction == Vector2.DOWN:
		return Vector2.RIGHT

	return Vector2.ZERO


func reflect_bottom_left(
	direction: Vector2
) -> Vector2:
	# Laser enters from the right and exits downward.
	if direction == Vector2.RIGHT:
		return Vector2.UP

	# Laser enters from above and exits left.
	if direction == Vector2.DOWN:
		return Vector2.LEFT

	return Vector2.ZERO

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_near = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_near = false
