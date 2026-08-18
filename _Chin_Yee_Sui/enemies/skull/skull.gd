extends CharacterBody2D


# ==========================
# MOVEMENT
# ==========================

@export var wander_speed: float = 20.0
@export var chase_speed: float = 30.0
@export var attack_move_speed: float = 65.0
@export var acceleration: float = 50.0

@export var detection_radius: float = 80.0
@export var attack_radius: float = 24.0

@export var wander_direction_interval: float = 2.0


# ==========================
# COMBAT
# ==========================

@export var max_health: int = 3
@export var attack_cooldown: float = 1.2
@export var damage_area_duration: float = 0.2
@export var damage_invulnerability_time: float = 0.3
@export var hit_animation_fallback_time: float = 0.5


# ==========================
# NODE REFERENCES
# ==========================

@onready var player: Node2D = get_tree().get_first_node_in_group("Player")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D

@onready var do_damage: DoDamage = $do_damage
@onready var take_damage_area: TakeDamage = $take_damage


# ==========================
# STATE
# ==========================

enum State {
	WANDER,
	CHASE,
	ATTACK
}


var state: State = State.WANDER


# ==========================
# VARIABLES
# ==========================

var health: int

var direction: Vector2 = Vector2.RIGHT
var attack_direction: Vector2 = Vector2.RIGHT

var wander_direction_timer: float = 0.0

var is_dead: bool = false
var is_attacking: bool = false
var is_attack_recovering: bool = false
var is_taking_damage: bool = false

var can_take_damage: bool = true
var can_attack: bool = true

var rng := RandomNumberGenerator.new()


# ==========================
# READY
# ==========================

func _ready() -> void:
	health = max_health

	add_to_group("Enemy")

	rng.randomize()
	choose_random_direction()

	do_damage.deactivate()

	animated_sprite.play("idle")


# ==========================
# PHYSICS
# ==========================

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if is_taking_damage:
		stop_movement(delta)
		return

	if is_attack_recovering:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_attacking:
		handle_attack_movement(delta)
		return

	update_state()

	var target_velocity := get_target_velocity()

	velocity = velocity.move_toward(
		target_velocity,
		acceleration * delta
	)

	move_and_slide()

	handle_wall_collision()
	update_sprite_direction()
	update_animation()


# ==========================
# AI
# ==========================

func update_state() -> void:
	if not is_instance_valid(player):
		state = State.WANDER
		return

	var distance_to_player := global_position.distance_to(
		player.global_position
	)

	if distance_to_player <= attack_radius and can_attack:
		start_attack()

	elif distance_to_player <= detection_radius:
		state = State.CHASE

	else:
		state = State.WANDER


func get_target_velocity() -> Vector2:
	match state:
		State.CHASE:
			if is_instance_valid(player):
				direction = global_position.direction_to(
					player.global_position
				)

			return direction * chase_speed

		State.WANDER:
			update_wander_direction()
			return direction * wander_speed

		State.ATTACK:
			return Vector2.ZERO

	return Vector2.ZERO


# ==========================
# WANDERING
# ==========================

func update_wander_direction() -> void:
	wander_direction_timer -= get_physics_process_delta_time()

	if wander_direction_timer <= 0.0:
		choose_random_direction()

		wander_direction_timer = rng.randf_range(
			wander_direction_interval * 0.5,
			wander_direction_interval * 1.5
		)


func choose_random_direction() -> void:
	var new_direction := Vector2(
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(-1.0, 1.0)
	)

	if new_direction.length_squared() < 0.01:
		new_direction = Vector2.RIGHT

	direction = new_direction.normalized()


func handle_wall_collision() -> void:
	if not is_on_wall():
		return

	var collision := get_last_slide_collision()

	if collision == null:
		return

	direction = direction.bounce(
		collision.get_normal()
	).normalized()

	if direction.length_squared() < 0.01:
		choose_random_direction()


# ==========================
# ATTACK
# ==========================

func start_attack() -> void:
	if is_dead:
		return

	if is_attacking or is_attack_recovering:
		return

	if not can_attack:
		return

	if not is_instance_valid(player):
		return

	state = State.ATTACK

	is_attacking = true
	can_attack = false

	attack_direction = global_position.direction_to(
		player.global_position
	)

	if attack_direction.length_squared() < 0.01:
		attack_direction = Vector2.RIGHT

	direction = attack_direction

	update_sprite_direction()

	do_damage.deactivate()

	animated_sprite.play("attack")


func handle_attack_movement(delta: float) -> void:
	velocity = velocity.move_toward(
		attack_direction * attack_move_speed,
		acceleration * delta
	)

	move_and_slide()

	if is_on_wall():
		velocity = Vector2.ZERO

	update_sprite_direction()


func perform_attack_damage() -> void:
	if is_dead:
		return

	do_damage.activate()

	# Wait until monitoring becomes active.
	await get_tree().physics_frame

	if is_dead or is_taking_damage:
		do_damage.deactivate()
		return

	# Deals damage even when the player was already overlapping.
	do_damage.damage_current_overlaps()

	await get_tree().create_timer(
		damage_area_duration
	).timeout

	do_damage.deactivate()


func restart_attack_cooldown() -> void:
	await get_tree().create_timer(attack_cooldown).timeout

	if not is_dead:
		can_attack = true


# ==========================
# MOVEMENT HELPERS
# ==========================

func stop_movement(delta: float) -> void:
	velocity = velocity.move_toward(
		Vector2.ZERO,
		acceleration * delta
	)

	move_and_slide()


# ==========================
# ANIMATION
# ==========================

func update_animation() -> void:
	if is_dead:
		return

	if is_attacking:
		return

	if is_attack_recovering:
		return

	if is_taking_damage:
		return

	# The slime has no separate movement animation.
	if animated_sprite.animation != "idle":
		animated_sprite.play("idle")


func update_sprite_direction() -> void:
	if direction.x == 0:
		return

	animated_sprite.flip_h = direction.x < 0

	# Flip only the attack area.
	do_damage.scale.x = (
		-1.0 if animated_sprite.flip_h else 1.0
	)


func _on_animated_sprite_2d_animation_finished() -> void:
	var finished_animation := animated_sprite.animation

	match finished_animation:
		"attack":
			velocity = Vector2.ZERO
			is_attacking = false
			is_attack_recovering = true

			await perform_attack_damage()

			if is_dead:
				return

			if is_taking_damage:
				is_attack_recovering = false
				return

			is_attack_recovering = false

			return_to_ai_state()
			restart_attack_cooldown()

		"hit":
			is_taking_damage = false
			velocity = Vector2.ZERO

			if not is_dead:
				return_to_ai_state()

		"die":
			queue_free()


func return_to_ai_state() -> void:
	if is_dead:
		return

	if not is_instance_valid(player):
		state = State.WANDER
		animated_sprite.play("idle")
		return

	var distance_to_player := global_position.distance_to(
		player.global_position
	)

	if distance_to_player <= detection_radius:
		state = State.CHASE
	else:
		state = State.WANDER

	animated_sprite.play("idle")


# ==========================
# RECEIVE DAMAGE
# ==========================

func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO, knockback_force: float = 0.0) -> void:
	if is_dead:
		return

	if not can_take_damage:
		return

	health -= amount

	print("Slime HP: ", health)

	if health <= 0:
		die()
		return

	var attack_was_interrupted := is_attacking or is_attack_recovering

	can_take_damage = false
	is_taking_damage = true
	is_attacking = false
	is_attack_recovering = false

	velocity = Vector2.ZERO

	do_damage.deactivate()

	if attack_was_interrupted:
		can_attack = false
		restart_attack_cooldown()

	animated_sprite.play("hit")

	finish_hit_after_fallback()

	await get_tree().create_timer(
		damage_invulnerability_time
	).timeout

	if not is_dead:
		can_take_damage = true


func finish_hit_after_fallback() -> void:
	await get_tree().create_timer(
		hit_animation_fallback_time
	).timeout

	if is_dead:
		return

	if is_taking_damage:
		is_taking_damage = false
		velocity = Vector2.ZERO
		return_to_ai_state()


# ==========================
# DEATH
# ==========================

func die() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	is_attack_recovering = false
	is_taking_damage = false

	can_take_damage = false
	can_attack = false

	velocity = Vector2.ZERO

	do_damage.deactivate()

	body_collision.set_deferred("disabled", true)

	take_damage_area.set_deferred("monitoring", false)
	take_damage_area.set_deferred("monitorable", false)

	animated_sprite.play("die")
