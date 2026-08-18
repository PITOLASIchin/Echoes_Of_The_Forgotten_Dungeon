@tool
extends Area2D

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
			update_laser_shape()


@export_range(16.0, 1000.0, 8.0)
var beam_length: float = 160.0:
	set(value):
		beam_length = maxf(value, 16.0)

		if is_node_ready():
			update_laser_shape()


@export_range(2.0, 32.0, 1.0)
var beam_width: float = 6.0:
	set(value):
		beam_width = maxf(value, 2.0)

		if is_node_ready():
			update_laser_shape()


@export_range(16.0, 1000.0, 8.0)
var hitbox_length: float = 160.0:
	set(value):
		hitbox_length = maxf(value, 16.0)

		if is_node_ready():
			update_laser_shape()


@export_range(2.0, 32.0, 1.0)
var hitbox_width: float = 6.0:
	set(value):
		hitbox_width = maxf(value, 2.0)

		if is_node_ready():
			update_laser_shape()


@export var starts_active: bool = true:
	set(value):
		starts_active = value

		if is_node_ready():
			update_visual()


@export var damage: int = 1
@export var knockback_force: float = 180.0


@onready var beam_sprite: AnimatedSprite2D = $BeamSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


var is_active: bool = true
var hitbox_made_unique: bool = false


func _ready() -> void:
	# VERY IMPORTANT:
	# Give this laser instance its own RectangleShape2D.
	make_hitbox_unique()

	update_visual()
	update_laser_shape()

	if Engine.is_editor_hint():
		return

	if not body_entered.is_connected(
		_on_body_entered
	):
		body_entered.connect(
			_on_body_entered
		)

	is_active = starts_active

	collision_shape.set_deferred(
		"disabled",
		not is_active
	)


func make_hitbox_unique() -> void:
	if collision_shape == null:
		return

	if hitbox_made_unique:
		return

	var old_shape: Shape2D = collision_shape.shape

	if old_shape != null:
		var new_shape: Shape2D = old_shape.duplicate(
			true
		) as Shape2D

		collision_shape.shape = new_shape

	else:
		collision_shape.shape = RectangleShape2D.new()

	# Makes sure Godot treats this resource as local
	# to this particular laser scene instance.
	collision_shape.shape.resource_local_to_scene = true

	hitbox_made_unique = true


func update_visual() -> void:
	if beam_sprite == null:
		return

	if starts_active:
		beam_sprite.play("active")
	else:
		beam_sprite.play("off")


func update_laser_shape() -> void:
	if beam_sprite == null:
		return

	if collision_shape == null:
		return

	# Make sure this laser has its own hitbox resource.
	make_hitbox_unique()


	# --------------------------------------------
	# DIRECTION
	# --------------------------------------------

	match laser_direction:
		LaserDirection.UP:
			rotation_degrees = 0.0

		LaserDirection.RIGHT:
			rotation_degrees = 90.0

		LaserDirection.DOWN:
			rotation_degrees = 180.0

		LaserDirection.LEFT:
			rotation_degrees = -90.0


	# --------------------------------------------
	# GET ORIGINAL BEAM TEXTURE SIZE
	# --------------------------------------------

	var frame_texture: Texture2D = null

	if beam_sprite.sprite_frames != null:
		if beam_sprite.sprite_frames.has_animation(
			beam_sprite.animation
		):
			frame_texture = (
				beam_sprite.sprite_frames.get_frame_texture(
					beam_sprite.animation,
					0
				)
			)


	var original_height: float = 16.0
	var original_width: float = 4.0

	if frame_texture != null:
		original_height = float(
			frame_texture.get_height()
		)

		original_width = float(
			frame_texture.get_width()
		)

	if original_height <= 0.0:
		original_height = 16.0

	if original_width <= 0.0:
		original_width = 4.0


	# --------------------------------------------
	# VISUAL BEAM
	# --------------------------------------------

	beam_sprite.scale = Vector2(
		beam_width / original_width,
		beam_length / original_height
	)

	beam_sprite.position = Vector2(
		0.0,
		-beam_length * 0.5
	)


	# --------------------------------------------
	# HITBOX
	# --------------------------------------------

	var rectangle: RectangleShape2D = (
		collision_shape.shape as RectangleShape2D
	)

	if rectangle == null:
		rectangle = RectangleShape2D.new()
		rectangle.resource_local_to_scene = true

		collision_shape.shape = rectangle


	rectangle.size = Vector2(
		hitbox_width,
		hitbox_length
	)

	collision_shape.position = Vector2(
		0.0,
		-hitbox_length * 0.5
	)


func turn_on() -> void:
	is_active = true
	starts_active = true

	if beam_sprite != null:
		beam_sprite.play("active")

	if not Engine.is_editor_hint():
		collision_shape.set_deferred(
			"disabled",
			false
		)


func turn_off() -> void:
	is_active = false
	starts_active = false

	if beam_sprite != null:
		beam_sprite.play("off")

	if not Engine.is_editor_hint():
		collision_shape.set_deferred(
			"disabled",
			true
		)


func toggle_laser() -> void:
	if is_active:
		turn_off()
	else:
		turn_on()


func set_activated(active: bool) -> void:
	if active:
		turn_on()
	else:
		turn_off()


func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return

	if not body.is_in_group("player"):
		return

	if body.has_method("take_damage"):
		body.take_damage(
			damage,
			global_position,
			knockback_force
		)
