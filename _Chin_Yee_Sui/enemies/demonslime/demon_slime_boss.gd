class_name DemonSlimeBoss
extends CharacterBody2D


signal health_changed(current_health: int, maximum_health: int)
signal died


const PLAYER_SCENE_PATH: String = \
	"res://_Cheok_Kai_Ren/character/player.tscn"


enum State {
	IDLE,
	CHASE,
	ATTACK,
	HURT,
	DEAD
}


# =========================================================
# HEALTH
# =========================================================

@export_category("Health")

@export var maximum_health: int = 20


# =========================================================
# MOVEMENT
# =========================================================

@export_category("Movement")

@export var move_speed: float = 45.0


# =========================================================
# VISION
# =========================================================

@export_category("Vision")

@export var detection_range: float = 300.0

@export_flags_2d_physics var vision_collision_mask: int = \
	0xFFFFFFFF


# =========================================================
# ATTACK
# =========================================================

@export_category("Attack")

@export var attack_damage: int = 1

@export var attack_range: float = 65.0

@export var attack_cancel_distance: float = 90.0

@export var attack_cooldown: float = 1.5

@export var attack_hit_start_frame: int = 9

@export var attack_hit_end_frame: int = 11


# =========================================================
# SPRITE
# =========================================================

@export_category("Sprite")

@export var sprite_faces_left: bool = true


# =========================================================
# GATE
# =========================================================

@export_category("Gate")

@export var gate_to_open: Node


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

	_enter_idle()

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
			State.ATTACK,
			State.HURT
		]:
			_enter_idle()

		return

	if current_state == State.ATTACK:
		_process_attack()
		return

	if current_state == State.HURT:
		return

	if not _can_detect_player():
		_enter_idle()
		return

	_process_chase()


# =========================================================
# REAL PLAYER
# =========================================================

func _find_real_player() -> void:
	target = null

	var scene := get_tree().current_scene

	if scene == null:
		return

	target = _search_player(scene)


func _search_player(
	node: Node
) -> Node2D:

	if (
		node is Node2D
		and
		node.scene_file_path == PLAYER_SCENE_PATH
	):
		return node as Node2D

	for child in node.get_children():

		var found := _search_player(child)

		if found != null:
			return found

	return null


# =========================================================
# VISION
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

	var hit := \
		get_world_2d().direct_space_state.intersect_ray(
			query
		)

	if hit.is_empty():
		return false

	var collider = hit.get("collider")

	if collider == target:
		return true

	if collider is Node:

		if target.is_ancestor_of(
			collider as Node
		):
			return true

	return false


func _get_vision_excludes() -> Array[RID]:
	var result: Array[RID] = [
		get_rid()
	]

	for enemy in get_tree().get_nodes_in_group(
		"Enemy"
	):

		if enemy == self:
			continue

		if enemy is CollisionObject2D:

			result.append(
				(enemy as CollisionObject2D).get_rid()
			)

	return result


# =========================================================
# IDLE
# =========================================================

func _enter_idle() -> void:
	if current_state == State.DEAD:
		return

	current_state = State.IDLE

	velocity = Vector2.ZERO

	do_damage.deactivate()

	_play_animation(&"idle")


# =========================================================
# CHASE
# =========================================================

func _process_chase() -> void:
	current_state = State.CHASE

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
	):
		_enter_attack()
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

func _enter_attack() -> void:
	if current_state == State.DEAD:
		return

	if not is_instance_valid(target):
		return

	if not _has_line_of_sight_to_player():
		return

	current_state = State.ATTACK

	velocity = Vector2.ZERO

	do_damage.deactivate()

	attack_damage_applied = false

	_update_facing(
		global_position.direction_to(
			target.global_position
		)
	)

	if not _play_animation(
		&"cleave",
		true
	):

		cooldown_remaining = attack_cooldown

		_enter_idle()


func _process_attack() -> void:
	velocity = Vector2.ZERO

	if not is_instance_valid(target):
		_enter_idle()
		return

	if (
		global_position.distance_to(
			target.global_position
		) > attack_cancel_distance
		or
		not _has_line_of_sight_to_player()
	):

		cooldown_remaining = attack_cooldown

		_enter_idle()


# =========================================================
# FACING
# =========================================================

func _update_facing(
	direction: Vector2
) -> void:

	if absf(direction.x) < 0.01:
		return

	if sprite_faces_left:

		animated_sprite.flip_h = \
			direction.x > 0.0

	else:

		animated_sprite.flip_h = \
			direction.x < 0.0


# =========================================================
# ANIMATION
# =========================================================

func _play_animation(
	animation_name: StringName,
	restart: bool = false
) -> bool:

	if not animated_sprite.sprite_frames.has_animation(
		animation_name
	):

		push_warning(
			"Missing Demon Slime animation: %s"
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
# ATTACK FRAME
# =========================================================

func _on_animation_frame_changed() -> void:
	if current_state != State.ATTACK:
		return

	if animated_sprite.animation != &"cleave":
		return

	var frame := animated_sprite.frame

	if (
		frame >= attack_hit_start_frame
		and
		frame <= attack_hit_end_frame
	):
		_damage_real_player()


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
# HURT
# =========================================================

func _enter_hurt() -> void:
	if current_state == State.DEAD:
		return

	current_state = State.HURT

	velocity = Vector2.ZERO

	do_damage.deactivate()

	if not _play_animation(
		&"take_hit",
		true
	):
		_enter_idle()


# =========================================================
# ANIMATION FINISHED
# =========================================================

func _on_animation_finished() -> void:
	match current_state:

		State.ATTACK:

			if animated_sprite.animation != &"cleave":
				return

			cooldown_remaining = \
				attack_cooldown

			if _can_detect_player():
				current_state = State.CHASE
			else:
				_enter_idle()


		State.HURT:

			if animated_sprite.animation == &"take_hit":

				if _can_detect_player():
					current_state = State.CHASE
				else:
					_enter_idle()


		State.DEAD:

			if animated_sprite.animation == &"death":

				_finish_death()


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

		_enter_dead()

	else:

		_enter_hurt()


# =========================================================
# DEATH
# =========================================================

func _enter_dead() -> void:
	if current_state == State.DEAD:
		return

	current_state = State.DEAD

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
		"monitoring",
		false
	)

	take_damage_area.set_deferred(
		"monitorable",
		false
	)

	if not _play_animation(
		&"death",
		true
	):
		_finish_death()


func _finish_death() -> void:
	_open_gate()

	died.emit()

	queue_free()


# =========================================================
# OPEN GATE
# =========================================================

func _open_gate() -> void:
	if not is_instance_valid(
		gate_to_open
	):
		return

	if gate_to_open.has_method(
		"open_gate"
	):

		gate_to_open.open_gate()
