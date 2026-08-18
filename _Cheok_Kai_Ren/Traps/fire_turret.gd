@tool
extends Node2D

enum TurretDirection {
	RIGHT,
	DOWN,
	LEFT,
	UP
}

@export var fireball_scene: PackedScene

@export var turret_direction: TurretDirection = TurretDirection.RIGHT:
	set(value):
		turret_direction = value

		if is_node_ready():
			setup_direction()


@export var fire_interval: float = 1.5
@export var start_delay: float = 0.0
@export var active: bool = true


@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var muzzle: Marker2D = $Muzzle
@onready var shoot_timer: Timer = $ShootTimer


var firing_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	setup_direction()

	# In the editor, only update the visual direction.
	# Do not start firing fireballs.
	if Engine.is_editor_hint():
		return

	shoot_timer.wait_time = fire_interval
	shoot_timer.one_shot = false

	if not shoot_timer.timeout.is_connected(shoot):
		shoot_timer.timeout.connect(shoot)

	if not active:
		return

	if start_delay > 0.0:
		await get_tree().create_timer(
			start_delay
		).timeout

	shoot()
	shoot_timer.start()


func setup_direction() -> void:
	if animated_sprite == null:
		return

	if muzzle == null:
		return

	match turret_direction:
		TurretDirection.RIGHT:
			firing_direction = Vector2.RIGHT

			animated_sprite.rotation_degrees = 90.0

			muzzle.position = Vector2(
				12.0,
				0.0
			)


		TurretDirection.DOWN:
			firing_direction = Vector2.DOWN

			animated_sprite.rotation_degrees = 180.0

			muzzle.position = Vector2(
				0.0,
				12.0
			)


		TurretDirection.LEFT:
			firing_direction = Vector2.LEFT

			animated_sprite.rotation_degrees = -90.0

			muzzle.position = Vector2(
				-12.0,
				0.0
			)


		TurretDirection.UP:
			firing_direction = Vector2.UP

			animated_sprite.rotation_degrees = 0.0

			muzzle.position = Vector2(
				0.0,
				-12.0
			)


func shoot() -> void:
	if Engine.is_editor_hint():
		return

	if not active:
		return

	if fireball_scene == null:
		push_error(
			"FireTurret does not have a Fireball Scene assigned."
		)
		return

	var fireball: Node = fireball_scene.instantiate()

	get_tree().current_scene.add_child(
		fireball
	)

	if fireball is Node2D:
		fireball.global_position = (
			muzzle.global_position
		)

	if fireball.has_method(
		"set_direction"
	):
		fireball.set_direction(
			firing_direction
		)

	animated_sprite.play(
		"fire"
	)


func activate() -> void:
	if Engine.is_editor_hint():
		return

	active = true

	if shoot_timer.is_stopped():
		shoot()
		shoot_timer.start()


func deactivate() -> void:
	if Engine.is_editor_hint():
		return

	active = false

	shoot_timer.stop()

	animated_sprite.stop()
	animated_sprite.frame = 0
