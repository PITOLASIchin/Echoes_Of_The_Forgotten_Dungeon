class_name Bat
extends CharacterBody2D


signal health_changed(current_health: int, maximum_health: int)
signal died


enum State {
	CHASE,
	ATTACK,
	DEAD
}


enum FacingDirection {
	FRONT,
	BACK,
	SIDE
}


@export_category("Health")
@export var maximum_health: int = 3

@export_category("Movement")
@export var move_speed: float = 70.0

@export_category("Attack")
@export var attack_damage: int = 1
@export var attack_range: float = 15.0
@export var attack_cancel_distance: float = 50.0
@export var attack_cooldown: float = 0.7
@export var attack_hit_start_frame: int = 2
@export var attack_hit_end_frame: int = 4
@export var attack_hitbox_distance: float = 10.0

@export_category("Target")
@export var player_group: StringName = &"Player"


@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var do_damage: DoDamage = $do_damage
@onready var take_damage_area: TakeDamage = $take_damage
@onready var take_damage_collision: CollisionShape2D = \
	$take_damage/CollisionShape2D

var current_health: int
var current_state: State = State.CHASE
var facing_direction: FacingDirection = FacingDirection.FRONT

var target: Node2D = null
var cooldown_remaining: float = 0.0
var attack_hitbox_active: bool = false


func _ready() -> void:
	current_health = maximum_health

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
	_change_state(State.CHASE)

	health_changed.emit(
		current_health,
		maximum_health
	)


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	cooldown_remaining = maxf(
		cooldown_remaining - delta,
		0.0
	)

	if not is_instance_valid(target):
		_find_target()

	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		_play_animation(&"idle")
		return

	match current_state:
		State.CHASE:
			_process_chase()

		State.ATTACK:
			_process_attack()

		State.DEAD:
			velocity = Vector2.ZERO


func _process_chase() -> void:
	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		_play_animation(&"idle")
		return

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
		velocity = Vector2.ZERO
		_change_state(State.ATTACK)
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
		_change_state(State.CHASE)
		return

	var distance_to_player := global_position.distance_to(
		target.global_position
	)

	if distance_to_player > attack_cancel_distance:
		_deactivate_attack_hitbox()
		cooldown_remaining = attack_cooldown
		_change_state(State.CHASE)


func _find_target() -> void:
	var found_target := get_tree().get_first_node_in_group(
		player_group
	)

	if found_target is Node2D:
		target = found_target as Node2D
	else:
		target = null


func _update_facing(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return

	if absf(direction.x) > absf(direction.y):
		facing_direction = FacingDirection.SIDE

		# The original side sprite faces left.
		animated_sprite.flip_h = direction.x > 0.0

	elif direction.y < 0.0:
		facing_direction = FacingDirection.BACK
		animated_sprite.flip_h = false

	else:
		facing_direction = FacingDirection.FRONT
		animated_sprite.flip_h = false

	_update_attack_hitbox_position(direction)


func _update_attack_hitbox_position(direction: Vector2) -> void:
	match facing_direction:
		FacingDirection.FRONT:
			do_damage.position = Vector2(
				0.0,
				attack_hitbox_distance
			)

		FacingDirection.BACK:
			do_damage.position = Vector2(
				0.0,
				-attack_hitbox_distance
			)

		FacingDirection.SIDE:
			if direction.x < 0.0:
				do_damage.position = Vector2(
					-attack_hitbox_distance,
					0.0
				)
			else:
				do_damage.position = Vector2(
					attack_hitbox_distance,
					0.0
				)


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
	var animation_name := _get_animation_name(action)

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


func _change_state(new_state: State) -> void:
	if current_state == State.DEAD:
		return

	current_state = new_state

	match current_state:
		State.CHASE:
			velocity = Vector2.ZERO
			_deactivate_attack_hitbox()

			if is_instance_valid(target):
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
			else:
				_play_animation(&"idle")

		State.ATTACK:
			velocity = Vector2.ZERO
			_deactivate_attack_hitbox()

			if is_instance_valid(target):
				_update_facing(
					global_position.direction_to(
						target.global_position
					)
				)

			var attack_started := _play_animation(
				&"attack",
				true
			)

			if not attack_started:
				cooldown_remaining = attack_cooldown
				_change_state(State.CHASE)

		State.DEAD:
			_start_death()


func _on_animation_frame_changed() -> void:
	if current_state != State.ATTACK:
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
			_deactivate_attack_hitbox()
			cooldown_remaining = attack_cooldown
			_change_state(State.CHASE)

		State.DEAD:
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
		current_state = State.DEAD
		_start_death()


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

	var death_started := _play_animation(
		&"die",
		true
	)

	if not death_started:
		queue_free()
