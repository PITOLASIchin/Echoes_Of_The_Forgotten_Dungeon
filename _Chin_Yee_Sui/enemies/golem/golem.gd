class_name Golem
extends CharacterBody2D


signal health_changed(current_health: int, maximum_health: int)
signal died


enum State {
	IDLE,
	CHASE,
	ATTACK,
	HIT,
	DEAD
}


@export_category("Health")
@export var maximum_health: int = 5

@export_category("Movement")
@export var move_speed: float = 45.0

@export_category("Attack")
@export var attack_damage: int = 1
@export var attack_range: float = 25.0
@export var attack_cooldown: float = 1.2
@export var attack_hit_start_frame: int = 6
@export var attack_hit_end_frame: int = 7

@export_category("Target")
@export var player_group: StringName = &"Player"

@export_category("Animations")
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walk"
@export var attack_animation: StringName = &"attack"
@export var hit_animation: StringName = &"hit"
@export var die_animation: StringName = &"die"


@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var do_damage: DoDamage = $do_damage
@onready var take_damage_area: TakeDamage = $take_damage
@onready var take_damage_collision: CollisionShape2D = $take_damage/CollisionShape2D


var current_health: int
var current_state: State = State.IDLE
var target: Node2D
var cooldown_remaining: float = 0.0
var attack_hitbox_active: bool = false


func _ready() -> void:
	current_health = maximum_health

	do_damage.damage = attack_damage
	do_damage.repeat_damage = false
	do_damage.deactivate()

	if not animated_sprite.frame_changed.is_connected(_on_animation_frame_changed):
		animated_sprite.frame_changed.connect(_on_animation_frame_changed)

	if not animated_sprite.animation_finished.is_connected(_on_animation_finished):
		animated_sprite.animation_finished.connect(_on_animation_finished)

	_find_target()
	_change_state(State.IDLE)
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
			_change_state(State.IDLE)

		return

	_face_target()

	match current_state:
		State.IDLE:
			_change_state(State.CHASE)

		State.CHASE:
			_process_chase_state()

		State.ATTACK, State.HIT:
			velocity = Vector2.ZERO


func _process_chase_state() -> void:
	var distance_to_target := global_position.distance_to(
		target.global_position
	)

	if distance_to_target <= attack_range:
		velocity = Vector2.ZERO

		if cooldown_remaining <= 0.0:
			_change_state(State.ATTACK)
		elif animated_sprite.animation != idle_animation:
			animated_sprite.play(idle_animation)

		return

	var direction := global_position.direction_to(target.global_position)

	velocity = direction * move_speed

	if animated_sprite.animation != walk_animation:
		animated_sprite.play(walk_animation)

	move_and_slide()


func _find_target() -> void:
	var found_target := get_tree().get_first_node_in_group(player_group)

	if found_target is Node2D:
		target = found_target as Node2D
	else:
		target = null


func _face_target() -> void:
	if not is_instance_valid(target):
		return

	var facing_left := target.global_position.x < global_position.x

	animated_sprite.flip_h = facing_left

	if facing_left:
		do_damage.scale.x = -absf(do_damage.scale.x)
	else:
		do_damage.scale.x = absf(do_damage.scale.x)


func _change_state(new_state: State) -> void:
	if current_state == State.DEAD:
		return

	current_state = new_state

	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
			_deactivate_attack_hitbox()
			animated_sprite.play(idle_animation)

		State.CHASE:
			_deactivate_attack_hitbox()
			animated_sprite.play(walk_animation)

		State.ATTACK:
			velocity = Vector2.ZERO
			_deactivate_attack_hitbox()
			animated_sprite.play(attack_animation)

		State.HIT:
			velocity = Vector2.ZERO
			_deactivate_attack_hitbox()
			animated_sprite.play(hit_animation)

		State.DEAD:
			_start_death()


func _on_animation_frame_changed() -> void:
	if current_state != State.ATTACK:
		return

	if animated_sprite.animation != attack_animation:
		return

	var current_frame := animated_sprite.frame

	var should_activate := (
		current_frame >= attack_hit_start_frame
		and current_frame <= attack_hit_end_frame
	)

	if should_activate and not attack_hitbox_active:
		_activate_attack_hitbox()
	elif not should_activate and attack_hitbox_active:
		_deactivate_attack_hitbox()


func _on_animation_finished() -> void:
	match current_state:
		State.ATTACK:
			_deactivate_attack_hitbox()
			cooldown_remaining = attack_cooldown

			if is_instance_valid(target):
				_change_state(State.CHASE)
			else:
				_change_state(State.IDLE)

		State.HIT:
			if is_instance_valid(target):
				_change_state(State.CHASE)
			else:
				_change_state(State.IDLE)

		State.DEAD:
			queue_free()


func _activate_attack_hitbox() -> void:
	attack_hitbox_active = true
	do_damage.activate()
	do_damage.damage_current_overlaps()


func _deactivate_attack_hitbox() -> void:
	attack_hitbox_active = false
	do_damage.deactivate()


func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO, knockback_force: float = 0.0) -> void:
	if current_state == State.DEAD:
		return

	if amount <= 0:
		return

	current_health = maxi(current_health - amount, 0)
	health_changed.emit(current_health, maximum_health)

	if current_health <= 0:
		current_state = State.DEAD
		_start_death()
		return

	_change_state(State.HIT)


func heal(amount: int) -> void:
	if current_state == State.DEAD:
		return

	if amount <= 0:
		return

	current_health = mini(
		current_health + amount,
		maximum_health
	)

	health_changed.emit(current_health, maximum_health)


func _start_death() -> void:
	died.emit()

	velocity = Vector2.ZERO
	_deactivate_attack_hitbox()

	body_collision.set_deferred("disabled", true)
	take_damage_collision.set_deferred("disabled", true)
	take_damage_area.set_deferred("monitorable", false)
	take_damage_area.set_deferred("monitoring", false)

	animated_sprite.play(die_animation)
