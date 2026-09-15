
extends CharacterBody2D


enum State {
	WANDER,
	FLEE,
	PAUSE,
	DEAD
}


# =====================================================
# HEALTH
# =====================================================

@export_category("Health")
@export var max_health: int = 5

var current_health: int = 0
var is_dead: bool = false


# =====================================================
# MOVEMENT
# =====================================================

@export_category("Movement")

@export var wander_speed: float = 40.0
@export var flee_speed: float = 85.0

@export var wander_time_min: float = 0.8
@export var wander_time_max: float = 1.8


# =====================================================
# VISION
# =====================================================

@export_category("Vision")
@export var sight_range: float = 150.0


# =====================================================
# FLAME TRAIL
# =====================================================

@export_category("Flame Trail")

@export var flame_scene: PackedScene

@export var flame_interval: float = 0.25
@export var flame_spacing: float = 6.0

@export var flames_per_flee: int = 5
@export var pause_duration: float = 3.0


# =====================================================
# SELECTED TELEPORT POSITIONS
# =====================================================

@export_category("Teleport")

# Enter GLOBAL map coordinates in the Inspector.
# Example:
# (100, 100)
# (300, 150)
# (500, 300)
@export var teleport_positions: Array[Vector2] = []

# A destination must be this far from the Player.
@export var min_distance_from_player: float = 24.0


# =====================================================
# VISUAL
# =====================================================

@export_category("Visual")

@export var idle_animation: StringName = &"idle"
@export var run_animation: StringName = &"run"
@export var die_animation: StringName = &"die"

@export var body_color: Color = Color(1.0, 0.35, 0.1)
@export var center_color: Color = Color(1.0, 0.9, 0.3)


# =====================================================
# NODE REFERENCES
# =====================================================

@onready var animated_sprite: AnimatedSprite2D = (
	get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
)

@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var sight_ray: RayCast2D = $SightRay
@onready var trail_timer: Timer = $TrailTimer
@onready var pause_timer: Timer = $PauseTimer


# =====================================================
# VARIABLES
# =====================================================

var player: Node2D = null

var state: State = State.WANDER

var move_direction: Vector2 = Vector2.DOWN

var wander_remaining: float = 0.0

var flames_dropped_during_flee: int = 0

var last_flame_position: Vector2 = Vector2.ZERO

var teleport_pending: bool = false

var rng := RandomNumberGenerator.new()


# =====================================================
# READY
# =====================================================

func _ready() -> void:

	rng.randomize()

	current_health = max_health

	add_to_group("Enemy")

	find_player()

	sight_ray.enabled = true

	# Timers are connected in code.
	# Do not connect them again in the Signals tab.
	trail_timer.one_shot = true
	trail_timer.autostart = false

	pause_timer.one_shot = true
	pause_timer.autostart = false

	if not trail_timer.timeout.is_connected(
		_on_trail_timer_timeout
	):
		trail_timer.timeout.connect(
			_on_trail_timer_timeout
		)

	if not pause_timer.timeout.is_connected(
		_on_pause_timer_timeout
	):
		pause_timer.timeout.connect(
			_on_pause_timer_timeout
		)

	if animated_sprite != null:
		if not animated_sprite.animation_finished.is_connected(
			_on_animated_sprite_2d_animation_finished
		):
			animated_sprite.animation_finished.connect(
				_on_animated_sprite_2d_animation_finished
			)

	last_flame_position = global_position

	if flame_scene == null:
		push_warning(
			"Ember Runner: Assign Flame Scene in the Inspector."
		)

	start_wander()

	queue_redraw()


# =====================================================
# DRAW COLORED ENEMY
# =====================================================

func _draw() -> void:

	# If a real sprite has frames, use that instead.
	if animated_sprite != null:
		if animated_sprite.sprite_frames != null:
			return

	# Fallback colored diamond. No sprite required.
	var diamond := PackedVector2Array([
		Vector2(0, -12),
		Vector2(10, 0),
		Vector2(0, 12),
		Vector2(-10, 0)
	])

	draw_colored_polygon(diamond, body_color)

	draw_circle(
		Vector2.ZERO,
		4.0,
		center_color
	)


# =====================================================
# FIND PLAYER
# =====================================================

func find_player() -> void:

	var found: Node = (
		get_tree().get_first_node_in_group("player")
	)

	if found == null:
		found = get_tree().get_first_node_in_group("Player")

	player = found as Node2D


# =====================================================
# PHYSICS
# =====================================================

func _physics_process(delta: float) -> void:

	if is_dead:
		velocity = Vector2.ZERO
		return

	if not is_instance_valid(player):
		find_player()

	# While paused, nothing can restart movement.
	if state == State.PAUSE:
		velocity = Vector2.ZERO
		return

	var sees_player: bool = can_see_player()

	# =================================================
	# CHANGE BETWEEN WANDER AND FLEE
	# =================================================

	if sees_player:

		if state != State.FLEE:
			start_flee()

	else:

		if state == State.FLEE:
			start_wander()

	# =================================================
	# MOVEMENT
	# =================================================

	match state:

		State.WANDER:

			wander_remaining -= delta

			if wander_remaining <= 0.0:
				choose_wander_direction()

			velocity = move_direction * wander_speed

			move_and_slide()

			# Choose another direction if blocked.
			if get_slide_collision_count() > 0:
				choose_wander_direction()


		State.FLEE:

			if is_instance_valid(player):

				var away: Vector2 = (
					global_position - player.global_position
				)

				if away.length_squared() > 0.001:
					move_direction = away.normalized()

			velocity = move_direction * flee_speed

			move_and_slide()


		State.PAUSE:

			velocity = Vector2.ZERO


		State.DEAD:

			velocity = Vector2.ZERO


# =====================================================
# LINE OF SIGHT
# =====================================================

func can_see_player() -> bool:

	if is_dead:
		return false

	if not is_instance_valid(player):
		return false

	var distance_to_player: float = (
		global_position.distance_to(player.global_position)
	)

	if distance_to_player > sight_range:
		return false

	# Use the RayCast's local coordinates.
	sight_ray.target_position = (
		sight_ray.to_local(player.global_position)
	)

	sight_ray.force_raycast_update()

	if not sight_ray.is_colliding():
		return false

	var collider: Object = sight_ray.get_collider()

	if collider == player:
		return true

	if collider is Node:

		if collider.is_in_group("player"):
			return true

		if player.is_ancestor_of(collider):
			return true

	# A wall or another body blocked the view.
	return false


# =====================================================
# WANDER
# =====================================================

func start_wander() -> void:

	if is_dead:
		return

	state = State.WANDER

	velocity = Vector2.ZERO

	flames_dropped_during_flee = 0

	pause_timer.stop()

	choose_wander_direction()

	play_animation(idle_animation)

	# Continue leaving flames normally.
	trail_timer.start(maxf(flame_interval, 0.01))


func choose_wander_direction() -> void:

	var directions: Array[Vector2] = [
		Vector2.UP,
		Vector2.DOWN,
		Vector2.LEFT,
		Vector2.RIGHT
	]

	move_direction = directions[
		rng.randi_range(0, directions.size() - 1)
	]

	wander_remaining = rng.randf_range(
		wander_time_min,
		wander_time_max
	)


# =====================================================
# FLEE
# =====================================================

func start_flee() -> void:

	if is_dead:
		return

	if flame_scene == null:
		return

	state = State.FLEE

	velocity = Vector2.ZERO

	pause_timer.stop()

	# A new flee begins a new count of five.
	flames_dropped_during_flee = 0

	play_animation(run_animation)

	# Start dropping flames immediately.
	# If the previous flame is too close, the timer
	# will try again after the enemy has moved.
	drop_flame_if_moved()

	if state == State.FLEE:
		trail_timer.start(maxf(flame_interval, 0.01))


# =====================================================
# FLAME TIMER
# =====================================================

func _on_trail_timer_timeout() -> void:

	if is_dead:
		return

	if state != State.WANDER and state != State.FLEE:
		return

	drop_flame_if_moved()

	# Do not restart while the enemy is paused.
	if state == State.WANDER or state == State.FLEE:
		trail_timer.start(maxf(flame_interval, 0.01))


# =====================================================
# DROP FLAME ONLY AFTER MOVING
# =====================================================

func drop_flame_if_moved() -> void:

	if flame_scene == null:
		return

	var distance_moved: float = (
		global_position.distance_to(last_flame_position)
	)

	if distance_moved < flame_spacing:
		return

	if spawn_flame():

		# Only flames dropped DURING FLEE count.
		if state == State.FLEE:

			flames_dropped_during_flee += 1

			if (
				flames_dropped_during_flee
				>= max(1, flames_per_flee)
			):
				start_pause()


# =====================================================
# SPAWN FLAME
# =====================================================

func spawn_flame() -> bool:

	if flame_scene == null:
		return false

	var instance: Node = flame_scene.instantiate()

	if not instance is Node2D:

		instance.queue_free()

		push_error(
			"Flame Scene must have a Node2D root."
		)

		return false

	var flame: Node2D = instance as Node2D

	# Add to the level so flames remain behind
	# after teleporting or dying.
	var level: Node = get_tree().current_scene

	if level == null:
		level = get_parent()

	level.add_child(flame)

	flame.global_position = global_position

	last_flame_position = global_position

	return true


# =====================================================
# PAUSE AFTER FIVE FLEE FLAMES
# =====================================================

func start_pause() -> void:

	if is_dead:
		return

	state = State.PAUSE

	velocity = Vector2.ZERO

	trail_timer.stop()

	play_animation(idle_animation)

	pause_timer.start(maxf(pause_duration, 0.01))


# =====================================================
# PAUSE FINISHED
# =====================================================

func _on_pause_timer_timeout() -> void:

	if is_dead:
		return

	if state != State.PAUSE:
		return

	# Continue fleeing if the Player is still visible.
	if can_see_player():
		start_flee()
	else:
		start_wander()


# =====================================================
# ANIMATION
# =====================================================

func play_animation(animation_name: StringName) -> void:

	if animated_sprite == null:
		return

	if animated_sprite.sprite_frames == null:
		return

	if animated_sprite.sprite_frames.has_animation(
		animation_name
	):

		if (
			animated_sprite.animation != animation_name
			or not animated_sprite.is_playing()
		):
			animated_sprite.play(animation_name)


# =====================================================
# ANIMATION FINISHED
# =====================================================

func _on_animated_sprite_2d_animation_finished() -> void:

	if not is_dead:
		return

	if animated_sprite == null:
		return

	if animated_sprite.animation == die_animation:
		queue_free()


# =====================================================
# TAKE DAMAGE
# =====================================================

# Compatible with:
# take_damage(amount)
#
# and:
# take_damage(amount, hit_position, knockback_force)

func take_damage(
	amount: int,
	_hit_position = Vector2.ZERO,
	_knockback_force = 0.0
) -> void:

	if is_dead:
		return

	if amount <= 0:
		return

	current_health -= amount

	if current_health < 0:
		current_health = 0

	print(
		"Ember Runner took ",
		amount,
		" damage. HP: ",
		current_health,
		"/",
		max_health
	)

	if current_health <= 0:
		die()
		return

	# Every surviving hit requests a teleport.
	# Deferred so it is safe during physics callbacks.
	if not teleport_pending:

		teleport_pending = true

		call_deferred("_perform_teleport")


# =====================================================
# TELEPORT TO SELECTED MAP COORDINATES
# =====================================================

func _perform_teleport() -> void:

	if is_dead:
		teleport_pending = false
		return

	# No automatic random teleport positions.
	# Only use coordinates entered in the Inspector.
	if teleport_positions.is_empty():

		push_warning(
			"Ember Runner: No Teleport Positions assigned."
		)

		teleport_pending = false
		return

	var valid_positions: Array[Vector2] = []

	# Check every selected map position.
	for candidate in teleport_positions:

		# Avoid choosing the exact current position.
		if candidate.distance_to(global_position) < 4.0:
			continue

		# Avoid teleporting directly on top of Player.
		if is_instance_valid(player):

			if (
				candidate.distance_to(player.global_position)
				< min_distance_from_player
			):
				continue

		# Check whether the enemy fits at this position.
		if not is_teleport_position_free(candidate):
			continue

		valid_positions.append(candidate)

	# No selected position is safe.
	if valid_positions.is_empty():

		push_warning(
			"Ember Runner: No valid teleport position is free."
		)

		teleport_pending = false
		return

	# Choose one of the valid positions randomly.
	var random_index: int = rng.randi_range(
		0,
		valid_positions.size() - 1
	)

	var destination: Vector2 = valid_positions[random_index]

	# Stop movement before teleporting.
	velocity = Vector2.ZERO

	trail_timer.stop()
	pause_timer.stop()

	global_position = destination

	# Prevent a flame trail from connecting the old
	# position to the teleport destination.
	last_flame_position = global_position

	flames_dropped_during_flee = 0

	teleport_pending = false

	# Resume the correct behavior from the new position.
	if can_see_player():
		start_flee()
	else:
		start_wander()


# =====================================================
# CHECK IF SELECTED TELEPORT POSITION IS FREE
# =====================================================

func is_teleport_position_free(candidate: Vector2) -> bool:

	if body_collision == null:
		return false

	if body_collision.shape == null:
		return false

	var space_state: PhysicsDirectSpaceState2D = (
		get_world_2d().direct_space_state
	)

	var query := PhysicsShapeQueryParameters2D.new()

	query.shape = body_collision.shape

	# Preserve the collision shape's rotation,
	# scale, and local offset.
	var candidate_transform: Transform2D = (
		body_collision.global_transform
	)

	candidate_transform.origin += (
		candidate - global_position
	)

	query.transform = candidate_transform

	# Check against the same bodies that the
	# Ember Runner's root normally collides with.
	query.collision_mask = collision_mask

	query.collide_with_bodies = true
	query.collide_with_areas = false

	# Do not detect our own body.
	query.exclude = [get_rid()]

	var overlaps: Array[Dictionary] = (
		space_state.intersect_shape(query, 1)
	)

	return overlaps.is_empty()


# =====================================================
# DIE
# =====================================================

func die() -> void:

	if is_dead:
		return

	is_dead = true

	state = State.DEAD

	velocity = Vector2.ZERO

	trail_timer.stop()
	pause_timer.stop()

	sight_ray.enabled = false

	if body_collision != null:
		body_collision.set_deferred(
			"disabled",
			true
		)

	print("Ember Runner died!")

	# Existing flames are separate level nodes,
	# so they remain until their own lifetime ends.

	if animated_sprite != null:
		if animated_sprite.sprite_frames != null:
			if animated_sprite.sprite_frames.has_animation(
				die_animation
			):
				animated_sprite.play(die_animation)
				animated_sprite.set_frame_and_progress(
					0,
					0.0
				)
				return

	# If the die animation is missing, still remove enemy.
	queue_free()
