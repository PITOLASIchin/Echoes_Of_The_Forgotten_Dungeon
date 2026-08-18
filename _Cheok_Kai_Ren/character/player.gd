extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)
signal stamina_changed(current_stamina: float, max_stamina: float)
signal coins_changed(amount: int)
signal potions_changed(amount: int)
signal player_died

@export var movement_speed: float = 180.0
@export var sprint_speed: float = 290.0

@export var max_health: int = 5
@export var attack_damage: int = 10
@export var sword_knockback_force: float = 210.0

@export var invulnerability_time: float = 0.8
@export var respawn_delay: float = 0.5

@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 35.0
@export var stamina_regeneration_rate: float = 25.0
@export var stamina_regeneration_delay: float = 0.8
@export var minimum_sprint_stamina: float = 5.0

@export var received_knockback_decay: float = 900.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var player_collision: CollisionShape2D = $CollisionShape2D
@onready var attack_hitbox: Area2D = $AttackHitBox
@onready var attack_collision: CollisionShape2D = (
	$AttackHitBox/CollisionShape2D
)

var last_direction: Vector2 = Vector2.DOWN
var spawn_position: Vector2

var current_health: int
var current_stamina: float
var coins: int = 0
var potions: int = 0

var can_take_damage: bool = true
var is_attacking: bool = false
var is_hurt: bool = false
var is_dead: bool = false
var is_sprinting: bool = false

var stamina_regeneration_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

var enemies_hit_this_attack: Array[Node2D] = []


func _ready() -> void:
	current_health = max_health
	current_stamina = max_stamina
	spawn_position = global_position

	attack_collision.disabled = true

	if not animated_sprite.animation_finished.is_connected(
		_on_animation_finished
	):
		animated_sprite.animation_finished.connect(
			_on_animation_finished
		)

	animated_sprite.play("idle_down")

	health_changed.emit(
		current_health,
		max_health
	)

	stamina_changed.emit(
		current_stamina,
		max_stamina
	)

	coins_changed.emit(
		coins
	)

func _physics_process(delta: float) -> void:
	update_knockback(delta)

	if is_dead:
		velocity = Vector2.ZERO
		return

	if is_hurt:
		velocity = knockback_velocity
		move_and_slide()

		update_stamina(
			delta,
			false
		)

		return

	if is_attacking:
		velocity = knockback_velocity
		move_and_slide()

		update_stamina(
			delta,
			false
		)

		return


	if Input.is_action_just_pressed("attack"):
		start_attack()
		return


	# IMPORTANT:
	# These names now match your Input Map.
	var direction: Vector2 = Input.get_vector(
		"left",
		"right",
		"up",
		"down"
	)


	var wants_to_sprint: bool = false

	# Only check sprint if the action exists.
	if InputMap.has_action("sprint"):
		wants_to_sprint = (
			Input.is_action_pressed("sprint")
			and direction != Vector2.ZERO
		)


	is_sprinting = (
		wants_to_sprint
		and current_stamina >= minimum_sprint_stamina
	)


	var movement_velocity: Vector2 = Vector2.ZERO

	if is_sprinting:
		movement_velocity = (
			direction * sprint_speed
		)
	else:
		movement_velocity = (
			direction * movement_speed
		)


	velocity = (
		movement_velocity
		+ knockback_velocity
	)


	update_stamina(
		delta,
		is_sprinting
	)


	if direction != Vector2.ZERO:
		last_direction = direction.normalized()

		if is_sprinting:
			play_run_animation(
				direction
			)
		else:
			play_walk_animation(
				direction
			)

	else:
		play_idle_animation()


	move_and_slide()


func update_knockback(delta: float) -> void:
	knockback_velocity = (
		knockback_velocity.move_toward(
			Vector2.ZERO,
			received_knockback_decay * delta
		)
	)


func apply_knockback(
	source_position: Vector2,
	knockback_force: float
) -> void:

	var knockback_direction: Vector2 = (
		global_position
		- source_position
	).normalized()


	if knockback_direction == Vector2.ZERO:
		knockback_direction = (
			-last_direction.normalized()
		)


	knockback_velocity = (
		knockback_direction
		* knockback_force
	)


func update_stamina(
	delta: float,
	sprinting: bool
) -> void:

	var previous_stamina: float = (
		current_stamina
	)


	if sprinting:
		current_stamina = maxf(
			current_stamina
			- stamina_drain_rate * delta,
			0.0
		)

		stamina_regeneration_timer = (
			stamina_regeneration_delay
		)

	else:
		if stamina_regeneration_timer > 0.0:
			stamina_regeneration_timer = maxf(
				stamina_regeneration_timer
				- delta,
				0.0
			)

		else:
			current_stamina = minf(
				current_stamina
				+ stamina_regeneration_rate
				* delta,
				max_stamina
			)


	if not is_equal_approx(
		previous_stamina,
		current_stamina
	):
		stamina_changed.emit(
			current_stamina,
			max_stamina
		)

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)


func add_potions(amount: int) -> void:
	potions += amount
	potions_changed.emit(potions)


func use_potion() -> bool:
	if potions <= 0:
		return false

	potions -= 1
	potions_changed.emit(potions)

	return true

func start_attack() -> void:
	if is_attacking:
		return

	if is_hurt:
		return

	if is_dead:
		return


	is_attacking = true
	is_sprinting = false

	velocity = Vector2.ZERO

	enemies_hit_this_attack.clear()

	position_attack_hitbox()

	play_directional_animation(
		"attack"
	)

	attack_collision.set_deferred(
		"disabled",
		false
	)

	await get_tree().physics_frame

	damage_overlapping_enemies()


func position_attack_hitbox() -> void:
	var direction_name: String = (
		get_direction_name()
	)


	match direction_name:
		"right":
			attack_hitbox.position = Vector2(
				25.0,
				7.0
			)

		"left":
			attack_hitbox.position = Vector2(
				-25.0,
				7.0
			)

		"down":
			attack_hitbox.position = Vector2(
				0.0,
				28.0
			)

		"up":
			attack_hitbox.position = Vector2(
				0.0,
				-15.0
			)


func damage_overlapping_enemies() -> void:
	if not is_attacking:
		return


	var overlapping_bodies: Array[Node2D] = (
		attack_hitbox.get_overlapping_bodies()
	)


	for body: Node2D in overlapping_bodies:
		damage_enemy(
			body
		)


func damage_enemy(body: Node2D) -> void:
	if body == self:
		return


	if body in enemies_hit_this_attack:
		return


	if body.has_method("take_damage"):
		enemies_hit_this_attack.append(
			body
		)

		body.take_damage(
			attack_damage,
			global_position,
			sword_knockback_force
		)


func take_damage(
	amount: int,
	source_position: Vector2 = Vector2.ZERO,
	knockback_force: float = 0.0
) -> void:

	if not can_take_damage:
		return

	if is_dead:
		return

	if amount <= 0:
		return


	current_health = maxi(
		current_health - amount,
		0
	)


	health_changed.emit(
		current_health,
		max_health
	)


	if knockback_force > 0.0:
		apply_knockback(
			source_position,
			knockback_force
		)


	if current_health <= 0:
		die()
		return


	start_hurt()


func start_hurt() -> void:
	is_hurt = true
	is_attacking = false
	is_sprinting = false
	can_take_damage = false


	attack_collision.set_deferred(
		"disabled",
		true
	)


	play_directional_animation(
		"hurt"
	)


func die() -> void:
	if is_dead:
		return


	is_dead = true
	is_hurt = false
	is_attacking = false
	is_sprinting = false
	can_take_damage = false


	attack_collision.set_deferred(
		"disabled",
		true
	)


	player_collision.set_deferred(
		"disabled",
		true
	)


	play_directional_animation(
		"death"
	)


	player_died.emit()


func respawn() -> void:
	await get_tree().create_timer(
		respawn_delay
	).timeout


	global_position = spawn_position

	current_health = max_health
	current_stamina = max_stamina

	is_dead = false
	is_hurt = false
	is_attacking = false
	is_sprinting = false
	can_take_damage = true

	knockback_velocity = Vector2.ZERO

	stamina_regeneration_timer = 0.0


	player_collision.set_deferred(
		"disabled",
		false
	)


	attack_collision.set_deferred(
		"disabled",
		true
	)


	play_idle_animation()


	health_changed.emit(
		current_health,
		max_health
	)


	stamina_changed.emit(
		current_stamina,
		max_stamina
	)


func heal(amount: int) -> void:
	if is_dead:
		return

	if amount <= 0:
		return


	current_health = mini(
		current_health + amount,
		max_health
	)


	health_changed.emit(
		current_health,
		max_health
	)


func play_run_animation(
	direction: Vector2
) -> void:

	if abs(direction.x) > abs(direction.y):
		if direction.x > 0.0:
			animated_sprite.play(
				"run_right"
			)
		else:
			animated_sprite.play(
				"run_left"
			)

	else:
		if direction.y > 0.0:
			animated_sprite.play(
				"run_down"
			)
		else:
			animated_sprite.play(
				"run_up"
			)


func play_walk_animation(
	direction: Vector2
) -> void:

	if abs(direction.x) > abs(direction.y):
		if direction.x > 0.0:
			animated_sprite.play(
				"walk_right"
			)
		else:
			animated_sprite.play(
				"walk_left"
			)

	else:
		if direction.y > 0.0:
			animated_sprite.play(
				"walk_down"
			)
		else:
			animated_sprite.play(
				"walk_up"
			)


func play_idle_animation() -> void:
	play_directional_animation(
		"idle"
	)


func play_directional_animation(
	prefix: String
) -> void:

	var direction_name: String = (
		get_direction_name()
	)


	var animation_name: StringName = (
		StringName(
			prefix
			+ "_"
			+ direction_name
		)
	)


	if animated_sprite.sprite_frames.has_animation(
		animation_name
	):
		animated_sprite.play(
			animation_name
		)


func get_direction_name() -> String:
	if abs(last_direction.x) > abs(last_direction.y):

		if last_direction.x > 0.0:
			return "right"

		return "left"


	if last_direction.y > 0.0:
		return "down"


	return "up"


func _on_animation_finished() -> void:
	var finished_animation: String = String(
		animated_sprite.animation
	)


	if finished_animation.begins_with(
		"attack_"
	):
		attack_collision.set_deferred(
			"disabled",
			true
		)

		is_attacking = false

		play_idle_animation()


	elif finished_animation.begins_with(
		"hurt_"
	):
		is_hurt = false

		play_idle_animation()


		await get_tree().create_timer(
			invulnerability_time
		).timeout


		if not is_dead:
			can_take_damage = true


	elif finished_animation.begins_with(
		"death_"
	):
		respawn()
