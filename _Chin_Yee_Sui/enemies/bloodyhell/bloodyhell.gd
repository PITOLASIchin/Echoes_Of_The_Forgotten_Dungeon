class_name DemonSlime
extends CharacterBody2D


signal health_changed(current_health: int, maximum_health: int)
signal died


enum State {
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
# ATTACK
# =========================================================

@export_category("Attack")
@export var attack_damage: int = 1

@export var attack_range: float = 65.0

@export var attack_cancel_distance: float = 90.0

@export var attack_cooldown: float = 1.5

# For Demon Slime "cleave" animation.
# Adjust these after testing with Visible Collision Shapes.
@export var attack_hit_start_frame: int = 9
@export var attack_hit_end_frame: int = 11

@export var attack_hitbox_distance: float = 45.0


# =========================================================
# TARGET
# =========================================================
@onready var attack_sound: AudioStreamPlayer2D = $AttackSound

@export_category("Target")
@export var player_group: StringName = &"Player"


# =========================================================
# SPRITE
# =========================================================

@export_category("Sprite")

# Demon Slime's original sprite faces LEFT.
@export var sprite_faces_left: bool = true


# =========================================================
# GATE
# =========================================================

@export_category("Gate")

# Drag the gate that should open after this enemy dies.
@export var gate_to_open: Node


# =========================================================
# NODES
# =========================================================

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var body_collision: CollisionShape2D = $CollisionShape2D

@onready var do_damage: DoDamage = $do_damage

@onready var take_damage_area: TakeDamage = $take_damage

@onready var take_damage_collision: CollisionShape2D = \
	$take_damage/CollisionShape2D


# =========================================================
# VARIABLES
# =========================================================

var current_health: int

var current_state: State = State.CHASE

var target: Node2D = null

var cooldown_remaining: float = 0.0

var attack_hitbox_active: bool = false

var facing_sign: float = 1.0

var attack_hitbox_original_y: float = 0.0


# =========================================================
# READY
# =========================================================

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


# =========================================================
# CHASE
# =========================================================

func _process_chase() -> void:
	var direction := global_position.direction_to(
		target.global_position
	)

	var distance_to_player := global_position.distance_to(
		target.global_position
	)

	_update_facing(direction)

	# -----------------------------------------------------
	# ATTACK PLAYER
	# -----------------------------------------------------

	if (
		distance_to_player <= attack_range
		and
		cooldown_remaining <= 0.0
	):
		_enter_attack_state()
		return

	# -----------------------------------------------------
	# WAIT FOR ATTACK COOLDOWN
	# -----------------------------------------------------

	if distance_to_player <= attack_range:
		velocity = Vector2.ZERO

		_play_animation(&"idle")

		return

	# -----------------------------------------------------
	# CHASE PLAYER
	# -----------------------------------------------------

	velocity = direction * move_speed

	_play_animation(&"walk")

	move_and_slide()


# =========================================================
# ATTACK PROCESS
# =========================================================

func _process_attack() -> void:
	velocity = Vector2.ZERO

	if not is_instance_valid(target):
		_enter_chase_state()
		return

	var distance_to_player := global_position.distance_to(
		target.global_position
	)

	# Player moved too far away during the attack.
	if distance_to_player > attack_cancel_distance:
		_deactivate_attack_hitbox()

		cooldown_remaining = attack_cooldown

		_enter_chase_state()


# =========================================================
# FIND PLAYER
# =========================================================

func _find_target() -> void:
	var found_target := get_tree().get_first_node_in_group(
		player_group
	)

	if found_target is Node2D:
		target = found_target as Node2D
	else:
		target = null


# =========================================================
# FACING
# =========================================================

func _update_facing(direction: Vector2) -> void:
	if absf(direction.x) < 0.01:
		return

	facing_sign = signf(direction.x)

	if sprite_faces_left:
		animated_sprite.flip_h = direction.x > 0.0
	else:
		animated_sprite.flip_h = direction.x < 0.0

	# Move attack hitbox to the same side
	# the enemy is currently facing.
	do_damage.position = Vector2(
		facing_sign * attack_hitbox_distance,
		attack_hitbox_original_y
	)


# =========================================================
# CHASE STATE
# =========================================================

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


# =========================================================
# ATTACK STATE
# =========================================================

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
		
	


# =========================================================
# HURT STATE
# =========================================================

func _enter_hurt_state() -> void:
	if current_state == State.DEAD:
		return

	current_state = State.HURT

	velocity = Vector2.ZERO

	_deactivate_attack_hitbox()

	if not _play_animation(
		&"take_hit",
		true
	):
		_enter_chase_state()


# =========================================================
# DEAD STATE
# =========================================================

func _enter_dead_state() -> void:
	if current_state == State.DEAD:
		return

	current_state = State.DEAD

	_start_death()


# =========================================================
# PLAY ANIMATION
# =========================================================

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

		animated_sprite.set_frame_and_progress(
			0,
			0.0
		)

		return true

	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)

	return true


# =========================================================
# ANIMATION FRAME CHANGED
# =========================================================

func _on_animation_frame_changed() -> void:
	if current_state != State.ATTACK:
		return

	if animated_sprite.animation != &"cleave":
		return

	var current_frame := animated_sprite.frame

	var should_activate := (
		current_frame >= attack_hit_start_frame
		and
		current_frame <= attack_hit_end_frame
	)

	if should_activate:
		_activate_attack_hitbox()
	else:
		_deactivate_attack_hitbox()


# =========================================================
# ANIMATION FINISHED
# =========================================================

func _on_animation_finished() -> void:

	match current_state:

		# -------------------------------------------------
		# ATTACK FINISHED
		# -------------------------------------------------

		State.ATTACK:

			if animated_sprite.animation != &"cleave":
				return

			_deactivate_attack_hitbox()

			cooldown_remaining = attack_cooldown

			_enter_chase_state()


		# -------------------------------------------------
		# HURT FINISHED
		# -------------------------------------------------

		State.HURT:

			if animated_sprite.animation == &"take_hit":
				_enter_chase_state()


		# -------------------------------------------------
		# DEATH FINISHED
		# -------------------------------------------------

		State.DEAD:

			if animated_sprite.animation == &"death":

				_open_gate()

				queue_free()


# =========================================================
# ACTIVATE ATTACK HITBOX
# =========================================================

func _activate_attack_hitbox() -> void:
	if attack_hitbox_active:
		return

	attack_hitbox_active = true
	do_damage.activate()

	# Important:
	# Damage player even if they were already standing
	# inside the Area2D when the sword became active.
	do_damage.damage_current_overlaps()


# =========================================================
# DEACTIVATE ATTACK HITBOX
# =========================================================

func _deactivate_attack_hitbox() -> void:
	attack_hitbox_active = false

	do_damage.deactivate()


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

	print(
		"Demon Slime HP: ",
		current_health,
		"/",
		maximum_health
	)

	if current_health <= 0:
		_enter_dead_state()
	else:
		_enter_hurt_state()


# =========================================================
# HEAL
# =========================================================

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


# =========================================================
# START DEATH
# =========================================================

func _start_death() -> void:
	died.emit()

	velocity = Vector2.ZERO

	_deactivate_attack_hitbox()

	# Stop physical collision.
	body_collision.set_deferred(
		"disabled",
		true
	)

	# Stop player attacking the dead enemy.
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

	# Play the entire death animation BEFORE
	# opening the gate.
	if not _play_animation(
		&"death",
		true
	):
		_open_gate()

		queue_free()


# =========================================================
# OPEN GATE
# =========================================================

func _open_gate() -> void:
	if not is_instance_valid(gate_to_open):
		return

	if gate_to_open.has_method("open_gate"):
		gate_to_open.open_gate()

	else:
		push_warning(
			"Demon Slime gate does not have open_gate() function."
		)
