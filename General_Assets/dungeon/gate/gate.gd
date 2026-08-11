extends StaticBody2D

signal door_opened
signal door_closed

@export var active_opens_door: bool = true

@onready var animated_sprite: AnimatedSprite2D = (
	$AnimatedSprite2D
)

@onready var collision_shape: CollisionShape2D = (
	$CollisionShape2D
)

var is_open: bool = false
var permanently_open: bool = false

func _ready() -> void:
	close()

func set_activated(active: bool) -> void:
	if permanently_open:
		return

	if active_opens_door:
		if active:
			open()
		else:
			close()
	else:
		if active:
			close()
		else:
			open()

func open() -> void:
	if is_open:
		return

	is_open = true

	collision_shape.set_deferred(
		"disabled",
		true
	)

	if animated_sprite.sprite_frames.has_animation(
		"open"
	):
		animated_sprite.play("open")

	elif animated_sprite.sprite_frames.has_animation(
		"opened"
	):
		animated_sprite.play("opened")

	door_opened.emit()

func close() -> void:
	if permanently_open:
		return

	if not is_open:
		_set_closed_state()
		return

	is_open = false

	collision_shape.set_deferred(
		"disabled",
		false
	)

	if animated_sprite.sprite_frames.has_animation(
		"close"
	):
		animated_sprite.play("close")

	elif animated_sprite.sprite_frames.has_animation(
		"closed"
	):
		animated_sprite.play("closed")

	door_closed.emit()


func _set_closed_state() -> void:
	is_open = false

	collision_shape.set_deferred(
		"disabled",
		false
	)

	if animated_sprite.sprite_frames.has_animation(
		"closed"
	):
		animated_sprite.play("closed")

	elif animated_sprite.sprite_frames.has_animation(
		"inactive"
	):
		animated_sprite.play("inactive")
