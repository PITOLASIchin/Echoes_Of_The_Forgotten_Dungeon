extends StaticBody2D

@export var straight_laser_scene: PackedScene
@export var corner_laser_scene: PackedScene

@export var tile_size: float = 8.0

@export var maximum_steps: int = 200

@export var maximum_reflections: int = 20

@export var active_on_ready: bool = false

@export_enum(
	"Right",
	"Down",
	"Left",
	"Up"
)
var starting_direction: int = 1

@export_flags_2d_physics var ray_collision_mask: int = 5

@onready var fire_point: Marker2D = (
	$FirePoint
)

@onready var laser_container: Node2D = (
	$LaserContainer
)

var active: bool = false
var connected_mirrors: Array[Node] = []

func _ready() -> void:
	active = active_on_ready

	call_deferred("connect_mirrors")

	if active:
		call_deferred("rebuild_laser")

func _on_lever_toggled(
	value: bool
) -> void:
	set_active(value)

func set_active(
	value: bool
) -> void:
	active = value

	if active:
		rebuild_laser()
	else:
		clear_laser()

func get_starting_direction() -> Vector2:
	match starting_direction:
		0:
			return Vector2.RIGHT

		1:
			return Vector2.DOWN

		2:
			return Vector2.LEFT

		3:
			return Vector2.UP

	return Vector2.DOWN

func snap_to_grid(
	position: Vector2
) -> Vector2:
	return Vector2(
		round(position.x / tile_size) * tile_size,
		round(position.y / tile_size) * tile_size
	)

func connect_mirrors() -> void:
	var mirrors: Array[Node] = (
		get_tree().get_nodes_in_group(
			"LaserMirror"
		)
	)

	for mirror: Node in mirrors:
		if mirror in connected_mirrors:
			continue

		if not mirror.has_signal(
			"mirror_rotated"
		):
			continue

		if not mirror.mirror_rotated.is_connected(
			_on_mirror_rotated
		):
			mirror.mirror_rotated.connect(
				_on_mirror_rotated
			)

		connected_mirrors.append(mirror)

func _on_mirror_rotated() -> void:
	if active:
		rebuild_laser()

func rebuild_laser() -> void:
	clear_laser()

	if not active:
		return

	var current_direction: Vector2 = (
		get_starting_direction()
	)

	var current_position: Vector2 = (
		snap_to_grid(
			fire_point.global_position
		)
	)

	var step_count: int = 0
	var reflection_count: int = 0

	while step_count < maximum_steps:
		var next_position: Vector2 = (
			current_position
			+ current_direction
			* tile_size
		)

		var result: Dictionary = cast_laser(
			current_position,
			next_position
		)

		# No object occupies the next tile.
		if result.is_empty():
			spawn_straight_piece(
				next_position,
				current_direction
			)

			current_position = next_position
			step_count += 1

			continue

		var collider: Node2D = (
			result.get("collider") as Node2D
		)

		if collider == null:
			break

		# Walls and other objects stop the laser.
		if not collider.is_in_group(
			"LaserMirror"
		):
			break

		if not collider.has_method(
			"get_reflected_direction"
		):
			break

		var outgoing_direction: Vector2 = (
			collider.call(
				"get_reflected_direction",
				current_direction
			) as Vector2
		)

		# This mirror orientation blocks the laser.
		if outgoing_direction == Vector2.ZERO:
			break

		var mirror_position: Vector2 = (
			snap_to_grid(
				collider.global_position
			)
		)

		# Replace the normal straight tile with
		# one corner tile at the mirror.
		spawn_corner_piece(
			mirror_position,
			current_direction,
			outgoing_direction
		)

		current_direction = (
			outgoing_direction.normalized()
		)

		# Continue from the centre of the mirror tile.
		current_position = mirror_position

		reflection_count += 1
		step_count += 1

		if reflection_count >= maximum_reflections:
			break

func cast_laser(
	start_position: Vector2,
	end_position: Vector2
) -> Dictionary:
	var ray_start: Vector2 = (
		start_position
		+ (end_position - start_position).normalized()
		* 0.1
	)

	var query: PhysicsRayQueryParameters2D = (
		PhysicsRayQueryParameters2D.create(
			ray_start,
			end_position
		)
	)

	query.collision_mask = ray_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false

	query.exclude = [
		get_rid()
	]

	return (
		get_world_2d()
		.direct_space_state
		.intersect_ray(query)
	)

func spawn_straight_piece(
	piece_position: Vector2,
	direction: Vector2
) -> void:
	var piece: Node = (
		straight_laser_scene.instantiate()
	)

	if piece == null:
		return

	laser_container.add_child(piece)

	if not piece.has_method(
		"setup_straight"
	):
		piece.queue_free()
		return

	piece.call(
		"setup_straight",
		piece_position,
		direction
	)

func spawn_corner_piece(
	piece_position: Vector2,
	incoming_direction: Vector2,
	outgoing_direction: Vector2
) -> void:
	var piece: Node = (
		corner_laser_scene.instantiate()
	)

	if piece == null:
		return

	laser_container.add_child(piece)

	if not piece.has_method(
		"setup_corner"
	):
		piece.queue_free()
		return

	piece.call(
		"setup_corner",
		piece_position,
		incoming_direction,
		outgoing_direction
	)

func clear_laser() -> void:
	for child: Node in laser_container.get_children():
		child.queue_free()
