@tool
extends Node2D

enum LaserDirection {
	UP,
	RIGHT,
	DOWN,
	LEFT
}

@export var laser_direction: LaserDirection = LaserDirection.UP:
	set(value):
		laser_direction = value

		if is_node_ready():
			update_direction()

@export var starts_active: bool = true:
	set(value):
		starts_active = value

		if is_node_ready():
			update_visual()

@onready var turret_sprite: AnimatedSprite2D = $TurretSprite

var is_active: bool = true


func _ready() -> void:
	update_direction()

	if Engine.is_editor_hint():
		update_visual()
		return

	if starts_active:
		turn_on()
	else:
		turn_off()


func update_direction() -> void:
	match laser_direction:
		LaserDirection.UP:
			rotation_degrees = 0.0

		LaserDirection.RIGHT:
			rotation_degrees = 90.0

		LaserDirection.DOWN:
			rotation_degrees = 180.0

		LaserDirection.LEFT:
			rotation_degrees = -90.0


func update_visual() -> void:
	if turret_sprite == null:
		return

	if starts_active:
		turret_sprite.play("active")
	else:
		turret_sprite.play("off")


func turn_on() -> void:
	is_active = true

	if turret_sprite != null:
		turret_sprite.play("active")


func turn_off() -> void:
	is_active = false

	if turret_sprite != null:
		turret_sprite.play("off")


func set_activated(active: bool) -> void:
	if active:
		turn_on()
	else:
		turn_off()


func toggle_laser() -> void:
	if is_active:
		turn_off()
	else:
		turn_on()
