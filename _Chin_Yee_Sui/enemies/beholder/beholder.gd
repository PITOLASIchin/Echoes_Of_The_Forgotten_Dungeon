extends CharacterBody2D


enum State {
	IDLE,
	WANDER,
	ATTACK,
	REPOSITION,
	HIT,
	DEAD
}


# =====================================================
# HEALTH
# =====================================================

@export_category("Health")

@export var max_health: int = 5

var current_health: int = 0
var is_dead: bool = false


# =====================================================
# MOVEMENT SETTINGS
# =====================================================

@export_category("Movement")

@export var move_speed: float = 25.0

@export var idle_time_min: float = 0.8
@export var idle_time_max: float = 2.0

@export var wander_time_min: float = 0.7
@export var wander_time_max: float = 1.6


# =====================================================
# POST ATTACK MOVEMENT
# =====================================================

@export_category("Post Attack Movement")

@export var reposition_speed: float = 35.0

@export var reposition_time_min: float = 0.4
@export var reposition_time_max: float = 0.9


# =====================================================
# VISION
# =====================================================

@export_category("Vision")

@export var sight_range: float = 140.0


# =====================================================
# ATTACK
# =====================================================

@export_category("Attack")

@export var projectile_scene: PackedScene
@export var attack_range: float = 140.0


# =====================================================
# NODE REFERENCES
# =====================================================

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var sight_ray: RayCast2D = $SightRay

@onready var behavior_timer: Timer = $BehaviorTimer

@onready var shoot_timer: Timer = $ShootTimer

@onready var muzzle: Marker2D = $Muzzle

@onready var body_collision: CollisionShape2D = $CollisionShape2D

@onready var take_damage_area: Area2D = (
	get_node_or_null("TakeDamageArea") as Area2D
)


# =====================================================
# VARIABLES
# =====================================================

var player: Node2D = null

var state: State = State.IDLE

var move_direction: Vector2 = Vector2.DOWN

var facing_direction: Vector2 = Vector2.DOWN

var rng := RandomNumberGenerator.new()


# =====================================================
# READY
# =====================================================

func _ready() -> void:

	rng.randomize()

	current_health = max_health

	player = get_tree().get_first_node_in_group("player")

	sight_ray.enabled = true

	start_idle()

	print(
		"Beholder spawned. HP: ",
		current_health,
		"/",
		max_health
	)


# =====================================================
# PHYSICS
# =====================================================

func _physics_process(_delta: float) -> void:

	if is_dead:
		velocity = Vector2.ZERO
		return


	# Try to find player again.
	if not is_instance_valid(player):

		player = get_tree().get_first_node_in_group(
			"player"
		)


	# =================================================
	# PLAYER VISION
	# =================================================

	var sees_player: bool = false


	if is_instance_valid(player):

		sees_player = can_see_player()


	# Don't interrupt reposition or hit animation.
	if (
		state != State.REPOSITION
		and state != State.HIT
	):

		if sees_player:

			if state != State.ATTACK:

				start_attack()


		else:

			if state == State.ATTACK:

				start_idle()


	# =================================================
	# STATE BEHAVIOR
	# =================================================

	match state:


		State.IDLE:

			velocity = Vector2.ZERO


		State.WANDER:

			velocity = (
				move_direction
				* move_speed
			)

			move_and_slide()


			# Hit a wall.
			if get_slide_collision_count() > 0:

				start_idle()


		State.ATTACK:

			velocity = Vector2.ZERO


			if is_instance_valid(player):

				update_facing_toward_player()


		State.REPOSITION:

			velocity = (
				move_direction
				* reposition_speed
			)

			move_and_slide()


			# Hit wall during reposition.
			if get_slide_collision_count() > 0:

				choose_reposition_direction()


		State.HIT:

			velocity = Vector2.ZERO


		State.DEAD:

			velocity = Vector2.ZERO


# =====================================================
# TAKE DAMAGE
# =====================================================

# Supports both:
#
# take_damage(amount)
#
# AND your Player's:
#
# take_damage(
#     attack_damage,
#     global_position,
#     sword_knockback_force
# )

func take_damage(
	amount: int,
	_hit_position = Vector2.ZERO,
	_knockback_force = 0.0
) -> void:

	if is_dead:
		return


	if amount <= 0:
		return


	current_health -= amount


	if current_health < 0:
		current_health = 0


	print(
		"Beholder took ",
		amount,
		" damage. HP: ",
		current_health,
		"/",
		max_health
	)


	# =================================================
	# DEAD
	# =================================================

	if current_health <= 0:

		start_death()

		return


	# =================================================
	# STILL ALIVE
	# =================================================

	start_hit()


# =====================================================
# HIT
# =====================================================

func start_hit() -> void:

	if is_dead:
		return


	state = State.HIT

	velocity = Vector2.ZERO


	# Stop random movement timer.
	behavior_timer.stop()


	# Stop the current attack animation
	# and play hit.
	animated_sprite.play("hit")


# =====================================================
# START DEATH
# =====================================================

func start_death() -> void:

	if is_dead:
		return


	is_dead = true

	state = State.DEAD

	velocity = Vector2.ZERO


	# Stop all AI timers.
	behavior_timer.stop()

	shoot_timer.stop()


	# Stop eyesight.
	sight_ray.enabled = false


	# Disable Beholder body collision.
	if is_instance_valid(body_collision):

		body_collision.set_deferred(
			"disabled",
			true
		)


	# Disable damage hurtbox so Player
	# cannot continue damaging the corpse.
	if is_instance_valid(take_damage_area):

		take_damage_area.set_deferred(
			"monitoring",
			false
		)

		take_damage_area.set_deferred(
			"monitorable",
			false
		)


	print("Beholder dying!")


	# Play death animation.
	animated_sprite.play("death")


# =====================================================
# FINISH DEATH
# =====================================================

func finish_death() -> void:

	print("Beholder died!")

	queue_free()


# =====================================================
# LINE OF SIGHT
# =====================================================

func can_see_player() -> bool:

	if is_dead:
		return false


	if not is_instance_valid(player):
		return false


	var distance_to_player: float = (
		global_position.distance_to(
			player.global_position
		)
	)


	if distance_to_player > sight_range:

		return false


	# Point ray toward Player.
	sight_ray.target_position = (
		to_local(
			player.global_position
		)
	)


	sight_ray.force_raycast_update()


	if not sight_ray.is_colliding():

		return false


	var collider: Object = (
		sight_ray.get_collider()
	)


	# Ray directly hit Player.
	if collider == player:

		return true


	# Extra Player group check.
	if collider is Node:

		if collider.is_in_group("player"):

			return true


	# Wall or another object blocked sight.
	return false


# =====================================================
# IDLE
# =====================================================

func start_idle() -> void:

	if is_dead:
		return


	state = State.IDLE

	velocity = Vector2.ZERO


	animated_sprite.play("idle")


	var duration: float = (
		rng.randf_range(
			idle_time_min,
			idle_time_max
		)
	)


	behavior_timer.start(duration)


# =====================================================
# RANDOM WANDER
# =====================================================

func start_wander() -> void:

	if is_dead:
		return


	state = State.WANDER


	move_direction = (
		get_random_cardinal_direction()
	)


	facing_direction = move_direction


	play_walk_animation()


	var duration: float = (
		rng.randf_range(
			wander_time_min,
			wander_time_max
		)
	)


	behavior_timer.start(duration)


# =====================================================
# RANDOM DIRECTION
# =====================================================

func get_random_cardinal_direction() -> Vector2:

	var directions: Array[Vector2] = [

		Vector2.UP,

		Vector2.DOWN,

		Vector2.LEFT,

		Vector2.RIGHT
	]


	var random_index: int = (
		rng.randi_range(
			0,
			directions.size() - 1
		)
	)


	return directions[random_index]


# =====================================================
# WALK ANIMATION
# =====================================================

func play_walk_animation() -> void:

	if facing_direction == Vector2.UP:

		animated_sprite.play(
			"walk_up"
		)


	elif facing_direction == Vector2.DOWN:

		animated_sprite.play(
			"walk_down"
		)


	elif facing_direction == Vector2.LEFT:

		animated_sprite.play(
			"walk_left"
		)


	elif facing_direction == Vector2.RIGHT:

		animated_sprite.play(
			"walk_right"
		)


# =====================================================
# BEHAVIOR TIMER
# =====================================================

func _on_behavior_timer_timeout() -> void:

	if is_dead:
		return


	match state:


		State.IDLE:

			start_wander()


		State.WANDER:

			start_idle()


		State.REPOSITION:

			finish_reposition()


		State.ATTACK:

			pass


		State.HIT:

			pass


		State.DEAD:

			pass


# =====================================================
# START ATTACK
# =====================================================

func start_attack() -> void:

	if is_dead:
		return


	if not is_instance_valid(player):
		return


	state = State.ATTACK

	velocity = Vector2.ZERO


	behavior_timer.stop()


	update_facing_toward_player()


	# Wait for ShootTimer.
	animated_sprite.play("idle")


# =====================================================
# FACE PLAYER
# =====================================================

func update_facing_toward_player() -> void:

	if not is_instance_valid(player):
		return


	var direction_to_player: Vector2 = (
		player.global_position
		- global_position
	)


	# Mostly horizontal.
	if (
		abs(direction_to_player.x)
		>
		abs(direction_to_player.y)
	):


		if direction_to_player.x > 0:

			facing_direction = Vector2.RIGHT


		else:

			facing_direction = Vector2.LEFT


	# Mostly vertical.
	else:


		if direction_to_player.y > 0:

			facing_direction = Vector2.DOWN


		else:

			facing_direction = Vector2.UP


# =====================================================
# SHOOT TIMER
# =====================================================

func _on_shoot_timer_timeout() -> void:

	if is_dead:
		return


	if state != State.ATTACK:
		return


	if not is_instance_valid(player):
		return


	# Make sure wall is not blocking Player.
	if not can_see_player():

		start_idle()

		return


	var distance_to_player: float = (
		global_position.distance_to(
			player.global_position
		)
	)


	if distance_to_player <= attack_range:

		shoot()


# =====================================================
# SHOOT
# =====================================================

func shoot() -> void:

	if is_dead:
		return


	if projectile_scene == null:

		push_warning(
			"Beholder has no projectile scene assigned!"
		)

		return


	if not is_instance_valid(player):
		return


	update_facing_toward_player()


	var projectile = (
		projectile_scene.instantiate()
	)


	get_tree().current_scene.add_child(
		projectile
	)


	projectile.global_position = (
		muzzle.global_position
	)


	projectile.direction = (
		global_position.direction_to(
			player.global_position
		)
	)


	play_attack_animation()


# =====================================================
# DIRECTIONAL ATTACK ANIMATION
# =====================================================

func play_attack_animation() -> void:

	if facing_direction == Vector2.UP:

		animated_sprite.play(
			"attack_up"
		)


	elif facing_direction == Vector2.DOWN:

		animated_sprite.play(
			"attack_down"
		)


	elif facing_direction == Vector2.LEFT:

		animated_sprite.play(
			"attack_left"
		)


	elif facing_direction == Vector2.RIGHT:

		animated_sprite.play(
			"attack_right"
		)


# =====================================================
# ANIMATION FINISHED
# =====================================================

func _on_animated_sprite_2d_animation_finished() -> void:

	var animation_name: StringName = (
		animated_sprite.animation
	)


	# =================================================
	# DEATH FINISHED
	# =================================================

	if animation_name == "death":

		finish_death()

		return


	# Don't process any other animation once dead.
	if is_dead:

		return


	# =================================================
	# HIT FINISHED
	# =================================================

	if animation_name == "hit":

		if (
			is_instance_valid(player)
			and can_see_player()
		):

			start_attack()


		else:

			start_idle()


		return


	# =================================================
	# ATTACK FINISHED
	# =================================================

	var finished_attack: bool = (

		animation_name == "attack_up"

		or animation_name == "attack_down"

		or animation_name == "attack_left"

		or animation_name == "attack_right"
	)


	if finished_attack:

		if state == State.ATTACK:

			start_reposition()


# =====================================================
# START POST-ATTACK MOVEMENT
# =====================================================

func start_reposition() -> void:

	if is_dead:
		return


	state = State.REPOSITION

	velocity = Vector2.ZERO


	behavior_timer.stop()


	choose_reposition_direction()


	var duration: float = (
		rng.randf_range(
			reposition_time_min,
			reposition_time_max
		)
	)


	behavior_timer.start(duration)


# =====================================================
# CHOOSE POST-ATTACK DIRECTION
# =====================================================

func choose_reposition_direction() -> void:

	if is_dead:
		return


	move_direction = (
		get_random_cardinal_direction()
	)


	facing_direction = move_direction


	play_walk_animation()


# =====================================================
# FINISH POST-ATTACK MOVEMENT
# =====================================================

func finish_reposition() -> void:

	if is_dead:
		return


	velocity = Vector2.ZERO


	if (
		is_instance_valid(player)
		and can_see_player()
	):

		start_attack()


	else:

		start_idle()
