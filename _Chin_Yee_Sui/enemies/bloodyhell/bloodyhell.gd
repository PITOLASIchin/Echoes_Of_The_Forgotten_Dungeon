class_name BloodyHell
extends CharacterBody2D


signal health_changed(current_health: int, maximum_health: int)
signal died


enum State {
	CHASE,
	ATTACK,
	HURT,
	DEAD
}


@export_category("Health")
@export var maximum_health: int = 5

@export_category("Movement")
@export var move_speed: float = 55.0

@export_category("Attack")
@export var attack_damage: int = 1
@export var attack_range: float = 35.0
@export var attack_cancel_distance: float = 55.0
@export var attack_cooldown: float = 1.2
@export var attack_hit_start_frame: int = 2
@export var attack_hit_end_frame: int = 3
@export var attack_hitbox_distance: float = 18.0

@export_category("Target")
@export var player_group: StringName = &"Player"

@export_category("Sprite")
@export var sprite_faces_left: bool = false


@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var do_damage: DoDamage = $do_damage
@onready var take_damage_area: TakeDamage = $take_damage
@onready var take_damage_collision: CollisionShape2D = $take_damage/CollisionShape2D


var current_health: int
var current_state: State = State.CHASE
var target: Node2D = null

var cooldown_remaining: float = 0.0
var attack_hitbox_active: bool = false
var active_attack_animation: StringName = &"atk1"
var use_first_attack: bool = true
var facing_sign: float = 1.0
var attack_hitbox_original_y: float = 0.0


func _ready() -> void:
	current_health = maximum_health
	attack_hitbox_original_y = do_damage.position.y

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

	_find_target()
	_enter_chase_state()

	health_changed.emit(current_health, maximum_health)


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)

	if not is_instance_valid(target):
		_find_target()

	if not is_instance_valid(target):
		velocity = Vector2.ZERO

		if current_state == State.CHASE:
			_play_animation(&"idle")

		return

	match current_state:
		State.CHASE:
			_process_chase()

		State.ATTACK:
			_process_attack()

		State.HURT:
			velocity = Vector2.ZERO

		State.DEAD:
			velocity = Vector2.ZERO


func _process_chase() -> void:
	var direction := global_position.direction_to(
		target.global_position
	)

	var distance_to_player := global_position.distance_to(
		target.global_position
	)

	_update_facing(direction)

	if (
		distance_to_player <= attack_range
		and cooldown_remaining <= 0.0
	):
		_enter_attack_state()
		return

	if distance_to_player <= attack_range:
		velocity = Vector2.ZERO
		_play_animation(&"idle")
		return

	velocity = direction * move_speed
	_play_animation(&"walk")
	move_and_slide()


func _process_attack() -> void:
	velocity = Vector2.ZERO

	if not is_instance_valid(target):
		_enter_chase_state()
		return

	var distance_to_player := global_position.distance_to(
		target.global_position
	)

	if distance_to_player > attack_cancel_distance:
		_deactivate_attack_hitbox()
		cooldown_remaining = attack_cooldown
		_enter_chase_state()


func _find_target() -> void:
	var found_target := get_tree().get_first_node_in_group(
		player_group
	)

	if found_target is Node2D:
		target = found_target as Node2D
	else:
		target = null


func _update_facing(direction: Vector2) -> void:
	if absf(direction.x) < 0.01:
		return

	facing_sign = signf(direction.x)

	if sprite_faces_left:
		animated_sprite.flip_h = direction.x > 0.0
	else:
		animated_sprite.flip_h = direction.x < 0.0

	do_damage.position = Vector2(
		facing_sign * attack_hitbox_distance,
		attack_hitbox_original_y
	)


func _enter_chase_state() -> void:
	if current_state == State.DEAD:
		return

	current_state = State.CHASE
	velocity = Vector2.ZERO
	_deactivate_attack_hitbox()

	if not is_instance_valid(target):
		_play_animation(&"idle")
		return

	var direction := global_position.direction_to(
		target.global_position
	)

	_update_facing(direction)

	if global_position.distance_to(
		target.global_position
	) > attack_range:
		_play_animation(&"walk")
	else:
		_play_animation(&"idle")


func _enter_attack_state() -> void:
	if current_state == State.DEAD:
		return

	current_state = State.ATTACK
	velocity = Vector2.ZERO
	_deactivate_attack_hitbox()

	if is_instance_valid(target):
		_update_facing(
			global_position.direction_to(
				target.global_position
			)
		)

	if use_first_attack:
		active_attack_animation = &"atk1"
	else:
		active_attack_animation = &"atk2"

	use_first_attack = not use_first_attack

	if not _play_animation(active_attack_animation, true):
		cooldown_remaining = attack_cooldown
		_enter_chase_state()


func _enter_hurt_state() -> void:
	if current_state == State.DEAD:
		return

	current_state = State.HURT
	velocity = Vector2.ZERO
	_deactivate_attack_hitbox()

	if not _play_animation(&"hurt", true):
		_enter_chase_state()


func _enter_dead_state() -> void:
	if current_state == State.DEAD:
		return

	current_state = State.DEAD
	_start_death()


func _play_animation(
	animation_name: StringName,
	restart: bool = false
) -> bool:
	if not animated_sprite.sprite_frames.has_animation(
		animation_name
	):
		push_warning(
			"Missing animation: %s" % animation_name
		)
		return false

	if restart:
		animated_sprite.play(animation_name)
		animated_sprite.set_frame_and_progress(0, 0.0)
		return true

	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)

	return true


func _on_animation_frame_changed() -> void:
	if current_state != State.ATTACK:
		return

	if animated_sprite.animation != active_attack_animation:
		return

	var current_frame := animated_sprite.frame

	var should_activate := (
		current_frame >= attack_hit_start_frame
		and current_frame <= attack_hit_end_frame
	)

	if should_activate:
		_activate_attack_hitbox()
	else:
		_deactivate_attack_hitbox()


func _on_animation_finished() -> void:
	match current_state:
		State.ATTACK:
			if animated_sprite.animation != active_attack_animation:
				return

			_deactivate_attack_hitbox()
			cooldown_remaining = attack_cooldown
			_enter_chase_state()

		State.HURT:
			if animated_sprite.animation == &"hurt":
				_enter_chase_state()

		State.DEAD:
			if animated_sprite.animation == &"die":
				queue_free()


func _activate_attack_hitbox() -> void:
	if attack_hitbox_active:
		return

	attack_hitbox_active = true
	do_damage.activate()
	do_damage.damage_current_overlaps()


func _deactivate_attack_hitbox() -> void:
	attack_hitbox_active = false
	do_damage.deactivate()


func take_damage(amount: int) -> void:
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
		_enter_dead_state()
	else:
		_enter_hurt_state()


func heal(amount: int) -> void:
	if current_state == State.DEAD:
		return

	if amount <= 0:
		return

	current_health = mini(
		current_health + amount,
		maximum_health
	)

	health_changed.emit(
		current_health,
		maximum_health
	)


func _start_death() -> void:
	died.emit()

	velocity = Vector2.ZERO
	_deactivate_attack_hitbox()

	body_collision.set_deferred("disabled", true)
	take_damage_collision.set_deferred("disabled", true)
	take_damage_area.set_deferred("monitorable", false)
	take_damage_area.set_deferred("monitoring", false)

	if not _play_animation(&"die", true):
		queue_free()
