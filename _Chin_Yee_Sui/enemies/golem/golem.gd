class_name Golem
extends CharacterBody2D


signal health_changed(current_health: int, maximum_health: int)
signal died


const PLAYER_SCENE_PATH: String = \
	"res://_Cheok_Kai_Ren/character/player.tscn"


enum State {
	IDLE,
	CHASE,
	ATTACK,
	HIT,
	DEAD
}


# =========================================================
# HEALTH
# =========================================================

@export_category("Health")

@export var maximum_health: int = 5


# =========================================================
# MOVEMENT
# =========================================================

@export_category("Movement")

@export var move_speed: float = 45.0


# =========================================================
# VISION
# =========================================================

@export_category("Vision")

@export var detection_range: float = 180.0

@export_flags_2d_physics var vision_collision_mask: int = \
	0xFFFFFFFF


# =========================================================
# CLOSE RANGE ATTACK
# =========================================================

@export_category("Close Range Attack")

@export var attack_damage: int = 1

# Increase this in the Inspector if the Golem starts chasing
# but does not begin the attack animation.
@export var attack_range: float = 45.0

@export var attack_cooldown: float = 1.2

# Damage frames inside the attack animation.
@export var attack_hit_start_frame: int = 6
@export var attack_hit_end_frame: int = 7


# =========================================================
# LONG RANGE ROCK ATTACK
# =========================================================

@export_category("Long Range Rock Attack")

# Assign your GolemRockSpike.tscn here.
@export var rock_spike_scene: PackedScene

# The Golem creates this many rocks after every close attack.
@export var rock_count: int = 5

@export var rock_damage: int = 1

# First rock distance from the Golem.
@export var rock_start_distance: float = 32.0

# Furthest distance the rock line can reach if no wall is found.
@export var rock_max_distance: float = 180.0

# Keeps the last rock slightly away from the wall.
@export var rock_wall_padding: float = 8.0

# Delay between each rock appearing from the ground.
@export var rock_spawn_delay: float = 0.12

# Set this to your wall/world physics layer.
# Default value 2 means physics Layer 2.
@export_flags_2d_physics var rock_wall_mask: int = 2


# =========================================================
# ANIMATIONS
# =========================================================

@export_category("Animations")

@export var idle_animation: StringName = &"idle"

@export var walk_animation: StringName = &"walk"

@export var attack_animation: StringName = &"attack"

@export var hit_animation: StringName = &"hit"

@export var die_animation: StringName = &"die"


# =========================================================
# NODES
# =========================================================

@onready var animated_sprite: AnimatedSprite2D = \
	$AnimatedSprite2D

@onready var body_collision: CollisionShape2D = \
	$CollisionShape2D

@onready var do_damage: DoDamage = \
	$do_damage

@onready var take_damage_area: TakeDamage = \
	$take_damage

@onready var take_damage_collision: CollisionShape2D = \
	$take_damage/CollisionShape2D


# =========================================================
# VARIABLES
# =========================================================

var current_health: int = 0

var current_state: State = State.IDLE

var target: Node2D = null

var cooldown_remaining: float = 0.0

var attack_hitbox_active: bool = false

var last_attack_direction: Vector2 = Vector2.DOWN


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	current_health = maximum_health

	add_to_group("Enemy")

	# Same close-range attack system as the other mobs:
	# activate do_damage only on selected attack frames.
	do_damage.damage = attack_damage
	do_damage.repeat_damage = false
	do_damage.deactivate()

	if not animated_sprite.frame_changed.is_connected(
		_on_animation_frame_changed
	):
		animated_sprite.frame_changed.connect(
			_on_animation_frame_changed
		)

	if not animated_sprite.animation_finished.is_connected(
		_on_animation_finished
	):
		animated_sprite.animation_finished.connect(
			_on_animation_finished
		)

	_find_real_player()

	_change_state(State.IDLE)

	if rock_spike_scene == null:
		push_warning(
			"Golem: Assign GolemRockSpike.tscn to Rock Spike Scene."
		)

	health_changed.emit(
		current_health,
		maximum_health
	)


# =========================================================
# PHYSICS
# =========================================================

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	cooldown_remaining = maxf(
		cooldown_remaining - delta,
		0.0
	)

	if not is_instance_valid(target):
		_find_real_player()

	if not is_instance_valid(target):

		if current_state not in [
			State.HIT,
			State.ATTACK
		]:
			_change_state(State.IDLE)

		return

	# Once the close attack starts, let the animation finish.
	# Do not cancel it because the Player moved away.
	if current_state == State.ATTACK:
		velocity = Vector2.ZERO
		return

	if current_state == State.HIT:
		velocity = Vector2.ZERO
		return

	if not _can_detect_player():

		_change_state(State.IDLE)

		return

	_face_target()

	if current_state != State.CHASE:
		_change_state(State.CHASE)

	_process_chase()


# =========================================================
# FIND REAL PLAYER
# =========================================================

func _find_real_player() -> void:
	target = null

	var scene := get_tree().current_scene

	if scene == null:
		return

	target = _search_for_player_scene(scene)


func _search_for_player_scene(
	node: Node
) -> Node2D:

	if (
		node is Node2D
		and
		node.scene_file_path == PLAYER_SCENE_PATH
	):
		return node as Node2D

	for child in node.get_children():

		var result: Node2D = \
			_search_for_player_scene(child)

		if result != null:
			return result

	return null


# =========================================================
# DETECTION
# =========================================================

func _can_detect_player() -> bool:
	if not is_instance_valid(target):
		return false

	if global_position.distance_to(
		target.global_position
	) > detection_range:
		return false

	return _has_line_of_sight_to_player()


func _has_line_of_sight_to_player() -> bool:
	if not is_instance_valid(target):
		return false

	var query := \
		PhysicsRayQueryParameters2D.create(
			global_position,
			target.global_position,
			vision_collision_mask,
			_get_vision_excludes()
		)

	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result := \
		get_world_2d().direct_space_state.intersect_ray(
			query
		)

	if result.is_empty():
		return false

	var collider = result.get("collider")

	if collider == target:
		return true

	if collider is Node:

		if target.is_ancestor_of(
			collider as Node
		):
			return true

	return false


func _get_vision_excludes() -> Array[RID]:
	var excludes: Array[RID] = [
		get_rid()
	]

	for enemy in get_tree().get_nodes_in_group(
		"Enemy"
	):

		if enemy == self:
			continue

		if enemy is CollisionObject2D:

			excludes.append(
				(enemy as CollisionObject2D).get_rid()
			)

	return excludes


# =========================================================
# CHASE
# =========================================================

func _process_chase() -> void:
	if not is_instance_valid(target):
		return

	var distance := global_position.distance_to(
		target.global_position
	)

	# Only stop moving when the Golem is really starting
	# the close-range attack.
	#
	# This fixes the freeze where the Golem notices
	# the Player, enters attack range, then just stands
	# there if the cooldown / animation setup is not ready.
	if (
		distance <= attack_range
		and
		cooldown_remaining <= 0.0
		and
		_has_line_of_sight_to_player()
	):
		velocity = Vector2.ZERO
		_change_state(State.ATTACK)
		return

	var direction := global_position.direction_to(
		target.global_position
	)

	velocity = direction * move_speed

	_play_animation(walk_animation)

	move_and_slide()


# =========================================================
# FACE PLAYER
# =========================================================

func _face_target() -> void:
	if not is_instance_valid(target):
		return

	var facing_left := (
		target.global_position.x
		<
		global_position.x
	)

	animated_sprite.flip_h = facing_left


# =========================================================
# STATE
# =========================================================

func _change_state(
	new_state: State
) -> void:

	if current_state == State.DEAD:
		return

	if (
		current_state == new_state
		and
		new_state not in [
			State.ATTACK,
			State.HIT
		]
	):
		return

	current_state = new_state

	match current_state:

		State.IDLE:

			velocity = Vector2.ZERO

			_deactivate_attack_hitbox()

			_play_animation(idle_animation)


		State.CHASE:

			_deactivate_attack_hitbox()

			_play_animation(walk_animation)


		State.ATTACK:

			velocity = Vector2.ZERO

			_deactivate_attack_hitbox()

			if is_instance_valid(target):

				var direction: Vector2 = global_position.direction_to(
					target.global_position
				)

				if direction.length_squared() > 0.001:
					last_attack_direction = direction.normalized()

			_face_target()

			# If the Inspector points to the wrong animation name,
			# do not stay frozen in ATTACK forever.
			if not _play_animation(
				attack_animation,
				true
			):
				cooldown_remaining = attack_cooldown
				current_state = State.CHASE
				return


		State.HIT:

			velocity = Vector2.ZERO

			_deactivate_attack_hitbox()

			_play_animation(
				hit_animation,
				true
			)


		State.DEAD:

			_start_death()


# =========================================================
# PLAY ANIMATION
# =========================================================

func _play_animation(
	animation_name: StringName,
	restart: bool = false
) -> bool:
	if animated_sprite.sprite_frames == null:
		return false

	if not animated_sprite.sprite_frames.has_animation(
		animation_name
	):
		push_warning(
			"Missing Golem animation: %s" % animation_name
		)
		return false

	if restart:
		animated_sprite.play(animation_name)
		animated_sprite.set_frame_and_progress(
			0,
			0.0
		)
		return true

	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)

	return true


# =========================================================
# ATTACK FRAME
# =========================================================

func _on_animation_frame_changed() -> void:
	if current_state != State.ATTACK:
		return

	if animated_sprite.animation != attack_animation:
		return

	var frame := animated_sprite.frame

	if (
		frame >= attack_hit_start_frame
		and
		frame <= attack_hit_end_frame
	):
		_activate_attack_hitbox()
	else:
		_deactivate_attack_hitbox()


# =========================================================
# SAME CLOSE ATTACK SYSTEM AS OTHER MOBS
# =========================================================

func _activate_attack_hitbox() -> void:
	if attack_hitbox_active:
		return

	attack_hitbox_active = true

	do_damage.damage = attack_damage
	do_damage.repeat_damage = false
	do_damage.activate()

	# Damage the Player even if they were already overlapping
	# the hitbox when this frame started.
	do_damage.damage_current_overlaps()


func _deactivate_attack_hitbox() -> void:
	attack_hitbox_active = false

	do_damage.deactivate()


# =========================================================
# ANIMATION FINISHED
# =========================================================

func _on_animation_finished() -> void:
	match current_state:

		State.ATTACK:

			if animated_sprite.animation != attack_animation:
				return

			_deactivate_attack_hitbox()

			# Every completed close attack triggers one rock line.
			_start_rock_line_attack(last_attack_direction)

			cooldown_remaining = \
				attack_cooldown

			if _can_detect_player():
				_change_state(State.CHASE)
			else:
				_change_state(State.IDLE)


		State.HIT:

			if animated_sprite.animation != hit_animation:
				return

			if _can_detect_player():
				_change_state(State.CHASE)
			else:
				_change_state(State.IDLE)


		State.DEAD:

			if animated_sprite.animation == die_animation:
				queue_free()


# =========================================================
# LONG RANGE ROCK LINE
# =========================================================

func _start_rock_line_attack(direction: Vector2) -> void:
	if current_state == State.DEAD:
		return

	if rock_spike_scene == null:
		push_warning(
			"Golem: Rock Spike Scene is empty."
		)
		return

	if direction.length_squared() <= 0.001:
		if is_instance_valid(target):
			direction = global_position.direction_to(
				target.global_position
			)

	if direction.length_squared() <= 0.001:
		return

	_spawn_rock_line(direction.normalized())


func _spawn_rock_line(direction: Vector2) -> void:
	var count: int = maxi(rock_count, 1)

	var max_distance: float = maxf(
		rock_max_distance,
		rock_start_distance
	)

	var wall_distance: float = _get_rock_wall_distance(
		direction,
		max_distance
	)

	var start_distance: float = minf(
		maxf(rock_start_distance, 0.0),
		wall_distance
	)

	var end_distance: float = maxf(
		start_distance,
		wall_distance - maxf(rock_wall_padding, 0.0)
	)

	for index in range(count):
		if current_state == State.DEAD:
			return

		var ratio: float = 0.0

		if count > 1:
			ratio = float(index) / float(count - 1)

		var distance: float = lerpf(
			start_distance,
			end_distance,
			ratio
		)

		_spawn_single_rock(
			global_position + direction * distance
		)

		if index < count - 1:
			await get_tree().create_timer(
				maxf(rock_spawn_delay, 0.01)
			).timeout


func _get_rock_wall_distance(
	direction: Vector2,
	max_distance: float
) -> float:
	if rock_wall_mask == 0:
		return max_distance

	var start_position: Vector2 = global_position
	var end_position: Vector2 = (
		global_position + direction * max_distance
	)

	var query := PhysicsRayQueryParameters2D.create(
		start_position,
		end_position,
		rock_wall_mask,
		_get_rock_line_excludes()
	)

	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hit := get_world_2d().direct_space_state.intersect_ray(
		query
	)

	if hit.is_empty():
		return max_distance

	var wall_position: Vector2 = hit["position"]

	return maxf(
		start_position.distance_to(wall_position),
		0.0
	)


func _get_rock_line_excludes() -> Array[RID]:
	var excludes: Array[RID] = _get_vision_excludes()

	if target is CollisionObject2D:
		excludes.append(
			(target as CollisionObject2D).get_rid()
		)

	return excludes


func _spawn_single_rock(spawn_position: Vector2) -> void:
	if rock_spike_scene == null:
		return

	var level: Node = get_tree().current_scene

	if level == null:
		level = get_parent()

	if level == null:
		return

	var instance: Node = rock_spike_scene.instantiate()

	if not instance is Node2D:
		if instance != null:
			instance.queue_free()

		push_error(
			"Golem: Rock Spike Scene must have a Node2D or Area2D root."
		)
		return

	var rock: Node2D = instance as Node2D

	level.add_child(rock)

	rock.global_position = spawn_position

	rock.set("damage", rock_damage)


# =========================================================
# TAKE DAMAGE
# =========================================================

func take_damage(
	amount: int,
	source_position: Vector2 = Vector2.ZERO,
	knockback_force: float = 0.0
) -> void:

	if current_state == State.DEAD:
		return

	if amount <= 0:
		return

	current_health = maxi(
		current_health - amount,
		0
	)

	health_changed.emit(
		current_health,
		maximum_health
	)

	if current_health <= 0:

		current_state = State.DEAD

		_start_death()

		return

	_change_state(State.HIT)


# =========================================================
# DEATH
# =========================================================

func _start_death() -> void:
	died.emit()

	velocity = Vector2.ZERO

	_deactivate_attack_hitbox()

	body_collision.set_deferred(
		"disabled",
		true
	)

	take_damage_collision.set_deferred(
		"disabled",
		true
	)

	take_damage_area.set_deferred(
		"monitorable",
		false
	)

	take_damage_area.set_deferred(
		"monitoring",
		false
	)

	_play_animation(
		die_animation,
		true
	)
