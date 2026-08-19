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
# ATTACK
# =========================================================

@export_category("Attack")

@export var attack_damage: int = 1

@export var attack_range: float = 25.0

@export var attack_cooldown: float = 1.2

@export var attack_hit_start_frame: int = 6

@export var attack_hit_end_frame: int = 7


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

var attack_damage_applied: bool = false


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	current_health = maximum_health

	add_to_group("Enemy")

	# Prevent friendly fire.
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

	if current_state == State.ATTACK:
		return

	if current_state == State.HIT:
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

		var result := \
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

	if distance <= attack_range:

		velocity = Vector2.ZERO

		if (
			cooldown_remaining <= 0.0
			and
			_has_line_of_sight_to_player()
		):
			_change_state(State.ATTACK)

		else:
			animated_sprite.play(
				idle_animation
			)

		return

	var direction := global_position.direction_to(
		target.global_position
	)

	velocity = direction * move_speed

	if animated_sprite.animation != walk_animation:

		animated_sprite.play(
			walk_animation
		)

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

			do_damage.deactivate()

			animated_sprite.play(
				idle_animation
			)


		State.CHASE:

			do_damage.deactivate()

			animated_sprite.play(
				walk_animation
			)


		State.ATTACK:

			velocity = Vector2.ZERO

			do_damage.deactivate()

			attack_damage_applied = false

			_face_target()

			animated_sprite.play(
				attack_animation
			)

			animated_sprite.set_frame_and_progress(
				0,
				0.0
			)


		State.HIT:

			velocity = Vector2.ZERO

			do_damage.deactivate()

			animated_sprite.play(
				hit_animation
			)

			animated_sprite.set_frame_and_progress(
				0,
				0.0
			)


		State.DEAD:

			_start_death()


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
		_damage_real_player()


# =========================================================
# PLAYER-ONLY DAMAGE
# =========================================================

func _damage_real_player() -> void:
	if attack_damage_applied:
		return

	if not is_instance_valid(target):
		return

	if not _has_line_of_sight_to_player():
		return

	if global_position.distance_to(
		target.global_position
	) > attack_range:
		return

	if target.has_method("take_damage"):

		attack_damage_applied = true

		target.call(
			"take_damage",
			attack_damage,
			global_position,
			0.0
		)


# =========================================================
# ANIMATION FINISHED
# =========================================================

func _on_animation_finished() -> void:
	match current_state:

		State.ATTACK:

			cooldown_remaining = \
				attack_cooldown

			if _can_detect_player():
				_change_state(State.CHASE)
			else:
				_change_state(State.IDLE)


		State.HIT:

			if _can_detect_player():
				_change_state(State.CHASE)
			else:
				_change_state(State.IDLE)


		State.DEAD:

			queue_free()


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

	do_damage.deactivate()

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

	animated_sprite.play(
		die_animation
	)

	animated_sprite.set_frame_and_progress(
		0,
		0.0
	)
