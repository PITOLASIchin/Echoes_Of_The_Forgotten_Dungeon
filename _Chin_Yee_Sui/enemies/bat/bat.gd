class_name Bat
extends CharacterBody2D


signal health_changed(current_health: int, maximum_health: int)
signal died


# =========================================================
# REAL PLAYER
# =========================================================

const PLAYER_SCENE_PATH: String = \
	"res://_Cheok_Kai_Ren/character/player.tscn"


# =========================================================
# STATE
# =========================================================

enum State {
	IDLE,
	CHASE,
	ATTACK,
	DEAD
}


enum FacingDirection {
	FRONT,
	BACK,
	SIDE
}


# =========================================================
# HEALTH
# =========================================================

@export_category("Health")

@export var maximum_health: int = 10


# =========================================================
# MOVEMENT
# =========================================================

@export_category("Movement")

@export var move_speed: float = 70.0


# =========================================================
# VISION
# =========================================================

@export_category("Vision")

@export var detection_range: float = 200.0

@export_flags_2d_physics var vision_collision_mask: int = \
	0xFFFFFFFF


# =========================================================
# ATTACK
# =========================================================

@export_category("Attack")

@export var attack_damage: int = 1

@export var attack_range: float = 18.0

@export var attack_cancel_distance: float = 50.0

@export var attack_cooldown: float = 0.7

@export var attack_hit_start_frame: int = 2

@export var attack_hit_end_frame: int = 3


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

var facing_direction: FacingDirection = \
	FacingDirection.FRONT

var target: Node2D = null

var cooldown_remaining: float = 0.0

var attack_damage_applied: bool = false


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	current_health = maximum_health

	add_to_group("Enemy")

	# Enemy hitbox is NEVER allowed to damage random
	# TakeDamage areas.
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
		_change_state(State.IDLE)
		return

	if current_state == State.ATTACK:
		_process_attack()
		return

	# Cannot see Player.
	if not _can_detect_player():
		_change_state(State.IDLE)
		return

	# Player is visible.
	if current_state != State.CHASE:
		_change_state(State.CHASE)

	_process_chase()


# =========================================================
# FIND REAL PLAYER
# =========================================================

func _find_real_player() -> void:
	target = null

	var current_scene := get_tree().current_scene

	if current_scene == null:
		return

	target = _search_for_player_scene(
		current_scene
	)


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

		var found := _search_for_player_scene(
			child
		)

		if found != null:
			return found

	return null


# =========================================================
# PLAYER DETECTION
# =========================================================

func _can_detect_player() -> bool:
	if not is_instance_valid(target):
		return false

	var distance := global_position.distance_to(
		target.global_position
	)

	if distance > detection_range:
		return false

	return _has_line_of_sight_to_player()


# =========================================================
# LINE OF SIGHT
# =========================================================

func _has_line_of_sight_to_player() -> bool:
	if not is_instance_valid(target):
		return false

	var space_state := \
		get_world_2d().direct_space_state

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
		space_state.intersect_ray(query)

	if result.is_empty():
		return false

	var collider = result.get("collider")

	if collider == null:
		return false

	if collider == target:
		return true

	if collider is Node:

		var collider_node := collider as Node

		if target.is_ancestor_of(collider_node):
			return true

	return false


# =========================================================
# IGNORE OTHER ENEMIES IN VISION
# =========================================================

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

	var direction := global_position.direction_to(
		target.global_position
	)

	var distance := global_position.distance_to(
		target.global_position
	)

	_update_facing(direction)

	if (
		distance <= attack_range
		and
		cooldown_remaining <= 0.0
		and
		_has_line_of_sight_to_player()
	):
		_change_state(State.ATTACK)
		return

	if distance <= attack_range:
		velocity = Vector2.ZERO
		_play_animation(&"idle")
		return

	velocity = direction * move_speed

	_play_animation(&"walk")

	move_and_slide()


# =========================================================
# ATTACK
# =========================================================

func _process_attack() -> void:
	velocity = Vector2.ZERO

	if not is_instance_valid(target):
		_change_state(State.IDLE)
		return

	var distance := global_position.distance_to(
		target.global_position
	)

	if (
		distance > attack_cancel_distance
		or
		not _has_line_of_sight_to_player()
	):
		cooldown_remaining = attack_cooldown

		_change_state(State.IDLE)


# =========================================================
# FACING
# =========================================================

func _update_facing(
	direction: Vector2
) -> void:

	if direction == Vector2.ZERO:
		return

	if absf(direction.x) > absf(direction.y):

		facing_direction = FacingDirection.SIDE

		# Bat side sprite originally faces left.
		animated_sprite.flip_h = (
			direction.x > 0.0
		)

	elif direction.y < 0.0:

		facing_direction = FacingDirection.BACK

		animated_sprite.flip_h = false

	else:

		facing_direction = FacingDirection.FRONT

		animated_sprite.flip_h = false


func _get_direction_name() -> String:
	match facing_direction:

		FacingDirection.FRONT:
			return "front"

		FacingDirection.BACK:
			return "back"

		FacingDirection.SIDE:
			return "side"

	return "front"


func _get_animation_name(
	action: StringName
) -> StringName:

	var action_name := String(action)

	if action == &"attack":
		action_name = "atk"

	return StringName(
		"%s%s" % [
			action_name,
			_get_direction_name()
		]
	)


func _play_animation(
	action: StringName,
	restart: bool = false
) -> bool:

	var animation_name := \
		_get_animation_name(action)

	if not animated_sprite.sprite_frames.has_animation(
		animation_name
	):
		push_warning(
			"Bat missing animation: %s"
			% animation_name
		)

		return false

	if restart:

		animated_sprite.play(
			animation_name
		)

		animated_sprite.set_frame_and_progress(
			0,
			0.0
		)

		return true

	if animated_sprite.animation != animation_name:

		animated_sprite.play(
			animation_name
		)

	return true


# =========================================================
# CHANGE STATE
# =========================================================

func _change_state(
	new_state: State
) -> void:

	if current_state == State.DEAD:
		return

	if (
		current_state == new_state
		and
		new_state != State.ATTACK
	):
		return

	current_state = new_state

	match current_state:

		State.IDLE:

			velocity = Vector2.ZERO

			do_damage.deactivate()

			_play_animation(&"idle")


		State.CHASE:

			do_damage.deactivate()

			if is_instance_valid(target):

				var direction := \
					global_position.direction_to(
						target.global_position
					)

				_update_facing(direction)

			_play_animation(&"walk")


		State.ATTACK:

			velocity = Vector2.ZERO

			do_damage.deactivate()

			attack_damage_applied = false

			if is_instance_valid(target):

				_update_facing(
					global_position.direction_to(
						target.global_position
					)
				)

			if not _play_animation(
				&"attack",
				true
			):
				cooldown_remaining = \
					attack_cooldown

				_change_state(State.IDLE)


		State.DEAD:

			_start_death()


# =========================================================
# ATTACK FRAME
# =========================================================

func _on_animation_frame_changed() -> void:
	if current_state != State.ATTACK:
		return

	var current_frame := \
		animated_sprite.frame

	if (
		current_frame >= attack_hit_start_frame
		and
		current_frame <= attack_hit_end_frame
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

	# ONLY exact player.tscn receives damage.
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

	if not _play_animation(
		&"die",
		true
	):
		queue_free()
