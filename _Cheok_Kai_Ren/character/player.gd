extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)
signal stamina_changed(current_stamina: float, max_stamina: float)
signal coins_changed(amount: int)
signal potions_changed(amount: int)
signal player_died


# ============================================================
# MOVEMENT
# ============================================================

@export_category("Movement")

@export var movement_speed: float = 180.0
@export var sprint_speed: float = 290.0


# ============================================================
# HEALTH / ATTACK
# ============================================================

@export_category("Combat")

@export var max_health: int = 5
@export var attack_damage: int = 10
@export var sword_knockback_force: float = 210.0

@export var invulnerability_time: float = 0.8
@export var respawn_delay: float = 0.5


# ============================================================
# STAMINA
# ============================================================

@export_category("Stamina")

@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 35.0
@export var stamina_regeneration_rate: float = 25.0
@export var stamina_regeneration_delay: float = 0.8
@export var minimum_sprint_stamina: float = 5.0


# ============================================================
# KNOCKBACK
# ============================================================

@export_category("Knockback")

@export var received_knockback_decay: float = 900.0


# ============================================================
# DODGE
# ============================================================

@export_category("Dodge")

# How fast the actual dodge movement is.
@export var dodge_speed: float = 300.0

# How long the physical dodge lasts.
#
# Dodge distance is approximately:
#
# dodge_speed × dodge_duration
#
# 300 × 0.14 = around 42 pixels.
@export_range(0.05, 0.50, 0.01)
var dodge_duration: float = 0.14

@export var dodge_stamina_cost: float = 20.0

@export_range(0.0, 2.0, 0.05)
var dodge_cooldown: float = 0.25


# ============================================================
# DODGE SPRITE ALIGNMENT
# ============================================================

@export_category("Dodge Sprite Alignment")

@export var dodge_offset_down: Vector2 = Vector2(
	-8.333,
	-13.333
)

@export var dodge_offset_left: Vector2 = Vector2.ZERO

@export var dodge_offset_right: Vector2 = Vector2.ZERO

@export var dodge_offset_up: Vector2 = Vector2.ZERO


# ============================================================
# NODE REFERENCES
# ============================================================

@onready var animated_sprite: AnimatedSprite2D = (
	$AnimatedSprite2D
)

@onready var dodge_sprite: AnimatedSprite2D = (
	$DodgeSprite
)

@onready var player_collision: CollisionShape2D = (
	$CollisionShape2D
)

@onready var attack_hitbox: Area2D = (
	$AttackHitBox
)

@onready var attack_collision: CollisionShape2D = (
	$AttackHitBox/CollisionShape2D
)
@onready var potion_drink_sound: AudioStreamPlayer = $PotionDrinkSound

# ============================================================
# BASIC PLAYER STATE
# ============================================================

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


# ============================================================
# DODGE STATE
# ============================================================

var is_dodging: bool = false

var can_dodge: bool = true

var dodge_direction: Vector2 = Vector2.DOWN

var dodge_timer: float = 0.0


# The spike StaticBody2D nodes currently being ignored.
var ignored_spikes: Array[PhysicsBody2D] = []


# ============================================================
# OTHER STATE
# ============================================================

var stamina_regeneration_timer: float = 0.0

var knockback_velocity: Vector2 = Vector2.ZERO

var enemies_hit_this_attack: Array[Node2D] = []


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	current_health = max_health

	current_stamina = max_stamina

	spawn_position = global_position


	attack_collision.disabled = true


	animated_sprite.visible = true

	dodge_sprite.visible = false


	if not animated_sprite.animation_finished.is_connected(
		_on_animation_finished
	):

		animated_sprite.animation_finished.connect(
			_on_animation_finished
		)


	animated_sprite.play(
		"idle_down"
	)


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


# ============================================================
# PHYSICS PROCESS
# ============================================================

func _physics_process(
	delta: float
) -> void:

	update_knockback(
		delta
	)


	# --------------------------------------------------------
	# DEAD
	# --------------------------------------------------------

	if is_dead:

		velocity = Vector2.ZERO

		return


	# --------------------------------------------------------
	# HURT
	# --------------------------------------------------------

	if is_hurt:

		velocity = knockback_velocity

		move_and_slide()


		update_stamina(
			delta,
			false
		)


		return


	# --------------------------------------------------------
	# DODGE
	# --------------------------------------------------------

	if is_dodging:

		dodge_timer -= delta


		if dodge_timer > 0.0:

			# IMPORTANT:
			#
			# Dodge velocity completely replaces normal
			# walking velocity.
			#
			# This prevents walking momentum from adding
			# extra distance to the dodge.

			velocity = (
				dodge_direction
				* dodge_speed
			)


			move_and_slide()


			update_stamina(
				delta,
				false
			)


			return


		else:

			finish_dodge()


	# --------------------------------------------------------
	# ATTACKING
	# --------------------------------------------------------

	if is_attacking:

		velocity = knockback_velocity

		move_and_slide()


		update_stamina(
			delta,
			false
		)


		return


	# --------------------------------------------------------
	# MOVEMENT INPUT
	# --------------------------------------------------------

	var direction: Vector2 = Input.get_vector(
		"left",
		"right",
		"up",
		"down"
	)


	# --------------------------------------------------------
	# DODGE INPUT
	# --------------------------------------------------------

	if Input.is_action_just_pressed(
		"dodge"
	):

		start_dodge(
			direction
		)

		return


	# --------------------------------------------------------
	# ATTACK INPUT
	# --------------------------------------------------------

	if Input.is_action_just_pressed(
		"attack"
	):

		start_attack()

		return


	# --------------------------------------------------------
	# SPRINT
	# --------------------------------------------------------

	var wants_to_sprint: bool = false


	if InputMap.has_action(
		"sprint"
	):

		wants_to_sprint = (
			Input.is_action_pressed(
				"sprint"
			)
			and direction != Vector2.ZERO
		)


	is_sprinting = (
		wants_to_sprint
		and current_stamina
		>= minimum_sprint_stamina
	)


	var movement_velocity: Vector2 = (
		Vector2.ZERO
	)


	if is_sprinting:

		movement_velocity = (
			direction
			* sprint_speed
		)

	else:

		movement_velocity = (
			direction
			* movement_speed
		)


	velocity = (
		movement_velocity
		+ knockback_velocity
	)


	update_stamina(
		delta,
		is_sprinting
	)


	# --------------------------------------------------------
	# MOVEMENT ANIMATIONS
	# --------------------------------------------------------

	if direction != Vector2.ZERO:

		last_direction = (
			direction.normalized()
		)


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


# ============================================================
# START DODGE
# ============================================================

func start_dodge(
	input_direction: Vector2
) -> void:

	if is_dodging:
		return


	if not can_dodge:
		return


	if is_attacking:
		return


	if is_hurt:
		return


	if is_dead:
		return


	if current_stamina < dodge_stamina_cost:
		return


	# --------------------------------------------------------
	# DETERMINE DODGE DIRECTION
	# --------------------------------------------------------

	if input_direction != Vector2.ZERO:

		dodge_direction = (
			input_direction.normalized()
		)


		last_direction = (
			dodge_direction
		)


	else:

		dodge_direction = (
			last_direction.normalized()
		)


	# --------------------------------------------------------
	# VERY IMPORTANT
	# --------------------------------------------------------
	#
	# Remove any movement/knockback velocity before starting.
	#
	# This guarantees:
	#
	# standing dodge
	# and
	# walking dodge
	#
	# travel the same distance.

	velocity = Vector2.ZERO

	knockback_velocity = Vector2.ZERO


	# --------------------------------------------------------
	# STAMINA
	# --------------------------------------------------------

	current_stamina = maxf(
		current_stamina
		- dodge_stamina_cost,
		0.0
	)


	stamina_regeneration_timer = (
		stamina_regeneration_delay
	)


	stamina_changed.emit(
		current_stamina,
		max_stamina
	)


	# --------------------------------------------------------
	# DODGE STATE
	# --------------------------------------------------------

	is_dodging = true

	can_dodge = false

	is_sprinting = false


	dodge_timer = dodge_duration


	# --------------------------------------------------------
	# INVINCIBILITY
	# --------------------------------------------------------

	can_take_damage = false


	# --------------------------------------------------------
	# PASS THROUGH SPIKES
	# --------------------------------------------------------

	ignore_spike_collisions()


	# --------------------------------------------------------
	# DODGE SPRITE
	# --------------------------------------------------------

	animated_sprite.visible = false

	dodge_sprite.visible = true


	var direction_name: String = (
		get_direction_name()
	)


	dodge_sprite.position = (
		get_dodge_offset(
			direction_name
		)
	)


	# Restart from the beginning every dodge.

	dodge_sprite.stop()

	dodge_sprite.frame = 0


	dodge_sprite.play(
		"dodge_"
		+ direction_name
	)


# ============================================================
# FINISH DODGE
# ============================================================

func finish_dodge() -> void:

	if not is_dodging:
		return


	# --------------------------------------------------------
	# END PHYSICAL DODGE
	# --------------------------------------------------------

	is_dodging = false

	dodge_timer = 0.0

	velocity = Vector2.ZERO


	# --------------------------------------------------------
	# RESTORE SPIKE COLLISION
	# --------------------------------------------------------

	restore_spike_collisions()


	# --------------------------------------------------------
	# END INVINCIBILITY
	# --------------------------------------------------------

	if not is_dead and not is_hurt:

		can_take_damage = true


	# --------------------------------------------------------
	# IMPORTANT VISUAL FIX
	# --------------------------------------------------------
	#
	# Stop the dodge animation at the exact same moment
	# the physical dodge finishes.
	#
	# This prevents normal walking from happening while
	# the dodge sprite is still displayed.

	dodge_sprite.stop()

	dodge_sprite.visible = false

	animated_sprite.visible = true


	if not is_dead and not is_hurt:

		play_idle_animation()


	# Cooldown happens independently.

	start_dodge_cooldown()


# ============================================================
# DODGE COOLDOWN
# ============================================================

func start_dodge_cooldown() -> void:

	await get_tree().create_timer(
		dodge_cooldown
	).timeout


	if not is_dead:

		can_dodge = true


# ============================================================
# IGNORE SPIKES
# ============================================================

func ignore_spike_collisions() -> void:

	ignored_spikes.clear()


	var spikes: Array[Node] = (
		get_tree().get_nodes_in_group(
			"spikes"
		)
	)


	for spike: Node in spikes:

		if spike is PhysicsBody2D:

			var spike_body: PhysicsBody2D = (
				spike as PhysicsBody2D
			)


			add_collision_exception_with(
				spike_body
			)


			ignored_spikes.append(
				spike_body
			)


# ============================================================
# RESTORE SPIKES
# ============================================================

func restore_spike_collisions() -> void:

	for spike_body: PhysicsBody2D in ignored_spikes:

		if is_instance_valid(
			spike_body
		):

			remove_collision_exception_with(
				spike_body
			)


	ignored_spikes.clear()


# ============================================================
# DODGE SPRITE OFFSETS
# ============================================================

func get_dodge_offset(
	direction_name: String
) -> Vector2:

	match direction_name:

		"down":

			return dodge_offset_down


		"left":

			return dodge_offset_left


		"right":

			return dodge_offset_right


		"up":

			return dodge_offset_up


	return Vector2.ZERO


# ============================================================
# KNOCKBACK
# ============================================================

func update_knockback(
	delta: float
) -> void:

	knockback_velocity = (
		knockback_velocity.move_toward(
			Vector2.ZERO,
			received_knockback_decay
			* delta
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


# ============================================================
# STAMINA
# ============================================================

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
			- stamina_drain_rate
			* delta,
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


# ============================================================
# COINS
# ============================================================

func add_coins(
	amount: int
) -> void:

	coins += amount

	coins_changed.emit(
		coins
	)


# ============================================================
# POTIONS
# ============================================================

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true
	
func add_potions(amount: int) -> void:
	potions += amount

	potions_changed.emit(
		potions
	)

func use_potion() -> bool:

	if potions <= 0:
		print("No Potion")
		return false

	if is_dead:
		return false

	if current_health >= max_health:
		print("Blood Full")
		return false

	potions -= 1

	heal(1)
	
	potion_drink_sound.play()
	potions_changed.emit(potions)

	return true

# ============================================================
# ATTACK
# ============================================================

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


# ============================================================
# ATTACK HITBOX
# ============================================================

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


# ============================================================
# DAMAGE ENEMIES
# ============================================================

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


func damage_enemy(
	body: Node2D
) -> void:

	if body == self:
		return


	if body in enemies_hit_this_attack:
		return


	if body.has_method(
		"take_damage"
	):

		enemies_hit_this_attack.append(
			body
		)


		body.take_damage(
			attack_damage,
			global_position,
			sword_knockback_force
		)


# ============================================================
# TAKE DAMAGE
# ============================================================

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
		current_health
		- amount,
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


# ============================================================
# HURT
# ============================================================

func start_hurt() -> void:

	is_hurt = true

	is_attacking = false

	is_sprinting = false


	if is_dodging:

		is_dodging = false


	restore_spike_collisions()


	dodge_timer = 0.0


	can_take_damage = false


	dodge_sprite.stop()

	dodge_sprite.visible = false

	animated_sprite.visible = true


	attack_collision.set_deferred(
		"disabled",
		true
	)


	play_directional_animation(
		"hurt"
	)


# ============================================================
# DEATH
# ============================================================

func die() -> void:

	if is_dead:

		return


	is_dead = true

	is_hurt = false

	is_attacking = false

	is_sprinting = false


	if is_dodging:

		is_dodging = false


	restore_spike_collisions()


	dodge_timer = 0.0


	can_take_damage = false


	dodge_sprite.stop()

	dodge_sprite.visible = false

	animated_sprite.visible = true


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


# ============================================================
# RESPAWN
# ============================================================

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

	is_dodging = false


	can_dodge = true

	can_take_damage = true


	dodge_timer = 0.0


	restore_spike_collisions()


	dodge_sprite.stop()

	dodge_sprite.visible = false

	animated_sprite.visible = true


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


# ============================================================
# HEAL
# ============================================================

func heal(
	amount: int
) -> void:

	if is_dead:

		return


	if amount <= 0:

		return


	current_health = mini(
		current_health
		+ amount,
		max_health
	)


	health_changed.emit(
		current_health,
		max_health
	)


# ============================================================
# RUN ANIMATION
# ============================================================

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


# ============================================================
# WALK ANIMATION
# ============================================================

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


# ============================================================
# IDLE
# ============================================================

func play_idle_animation() -> void:

	play_directional_animation(
		"idle"
	)


# ============================================================
# DIRECTIONAL ANIMATION
# ============================================================

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


# ============================================================
# DIRECTION
# ============================================================

func get_direction_name() -> String:

	if abs(last_direction.x) > abs(last_direction.y):

		if last_direction.x > 0.0:

			return "right"


		return "left"


	if last_direction.y > 0.0:

		return "down"


	return "up"


# ============================================================
# NORMAL ANIMATION FINISHED
# ============================================================

func _on_animation_finished() -> void:

	var finished_animation: String = String(
		animated_sprite.animation
	)


	# --------------------------------------------------------
	# ATTACK
	# --------------------------------------------------------

	if finished_animation.begins_with(
		"attack_"
	):

		attack_collision.set_deferred(
			"disabled",
			true
		)


		is_attacking = false


		play_idle_animation()


	# --------------------------------------------------------
	# HURT
	# --------------------------------------------------------

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


	# --------------------------------------------------------
	# DEATH
	# --------------------------------------------------------

	elif finished_animation.begins_with(
		"death_"
	):

		respawn()
