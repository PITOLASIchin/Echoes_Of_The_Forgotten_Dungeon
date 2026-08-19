extends CharacterBody2D


# =========================================================
# REAL PLAYER IDENTIFICATION
# =========================================================

# IMPORTANT:
# The Skull DOES NOT use the "Player" group.
# It finds the exact player.tscn instance instead.
#
# This means player.gd can change and this enemy
# will still identify the correct Player.

const PLAYER_SCENE_PATH: String = \
	"res://_Cheok_Kai_Ren/character/player.tscn"


# =========================================================
# MOVEMENT
# =========================================================

@export_category("Movement")

@export var chase_speed: float = 55.0

@export var acceleration: float = 250.0


# =========================================================
# VISION
# =========================================================

@export_category("Vision")

# How far away the Skull can SEE the player.
#
# Set higher if you want Skull to notice player
# from further away.
@export var detection_range: float = 220.0

# Which physics layers can block / receive the sight ray.
#
# Default = all physics layers.
@export_flags_2d_physics var vision_collision_mask: int = \
	0xFFFFFFFF


# =========================================================
# ATTACK
# =========================================================

@export_category("Attack")

@export var attack_damage: int = 1

@export var attack_range: float = 20.0

@export var attack_cooldown: float = 1.0

# Skull's attack animation has frames 0 - 5.
#
# Damage happens only during these frames.
@export var attack_hit_start_frame: int = 2
@export var attack_hit_end_frame: int = 3


# =========================================================
# HEALTH
# =========================================================

@export_category("Health")

@export var max_health: int = 10

@export var damage_invulnerability_time: float = 0.3


# =========================================================
# NODE REFERENCES
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

var player: Node2D = null

var health: int = 0


var is_dead: bool = false

var is_attacking: bool = false

var is_taking_damage: bool = false


var can_attack: bool = true

var can_take_damage: bool = true


var attack_hitbox_active: bool = false


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	health = max_health

	add_to_group("Enemy")

	# -----------------------------------------------------
	# DAMAGE SETUP
	# -----------------------------------------------------

	do_damage.damage = attack_damage

	do_damage.repeat_damage = false

	do_damage.deactivate()


	# -----------------------------------------------------
	# ANIMATION FRAME SIGNAL
	# -----------------------------------------------------

	if not animated_sprite.frame_changed.is_connected(
		_on_animation_frame_changed
	):
		animated_sprite.frame_changed.connect(
			_on_animation_frame_changed
		)


	# -----------------------------------------------------
	# ANIMATION FINISHED SIGNAL
	#
	# skull.tscn already connects this.
	# This prevents duplicate connections.
	# -----------------------------------------------------

	if not animated_sprite.animation_finished.is_connected(
		_on_animated_sprite_2d_animation_finished
	):
		animated_sprite.animation_finished.connect(
			_on_animated_sprite_2d_animation_finished
		)


	# -----------------------------------------------------
	# FIND THE REAL PLAYER
	# -----------------------------------------------------

	_find_real_player()


	animated_sprite.play(&"idle")


# =========================================================
# PHYSICS
# =========================================================

func _physics_process(delta: float) -> void:

	# -----------------------------------------------------
	# DEAD
	# -----------------------------------------------------

	if is_dead:
		velocity = Vector2.ZERO
		return


	# -----------------------------------------------------
	# FIND PLAYER AGAIN IF PLAYER IS MISSING
	# -----------------------------------------------------

	if not is_instance_valid(player):
		_find_real_player()


	# -----------------------------------------------------
	# STILL NO PLAYER
	# -----------------------------------------------------

	if not is_instance_valid(player):

		_stop_movement(delta)

		_play_idle()

		return


	# -----------------------------------------------------
	# HURT
	# -----------------------------------------------------

	if is_taking_damage:

		_stop_movement(delta)

		return


	# -----------------------------------------------------
	# CURRENTLY ATTACKING
	# -----------------------------------------------------

	if is_attacking:

		velocity = Vector2.ZERO

		return


	# -----------------------------------------------------
	# CHECK IF PLAYER CAN ACTUALLY BE SEEN
	# -----------------------------------------------------

	if not _can_detect_player():

		_stop_movement(delta)

		_play_idle()

		return


	# -----------------------------------------------------
	# PLAYER DETECTED
	# -----------------------------------------------------

	_chase_player(delta)


# =========================================================
# FIND REAL PLAYER
# =========================================================

func _find_real_player() -> void:

	player = null


	var current_scene := get_tree().current_scene


	if current_scene == null:
		return


	player = _search_for_player_scene(
		current_scene
	)


# =========================================================
# SEARCH SCENE TREE FOR EXACT PLAYER.TSCN
# =========================================================

func _search_for_player_scene(
	node: Node
) -> Node2D:

	# -----------------------------------------------------
	# THIS IS THE IMPORTANT PART
	#
	# We do NOT check:
	#
	# node.is_in_group("Player")
	# node.has_method(...)
	# player.gd
	# class_name
	#
	# Instead we check which .tscn created the node.
	# -----------------------------------------------------

	if node is Node2D:

		if node.scene_file_path == PLAYER_SCENE_PATH:

			return node as Node2D


	# -----------------------------------------------------
	# SEARCH CHILDREN
	# -----------------------------------------------------

	for child in node.get_children():

		var found_player := \
			_search_for_player_scene(child)


		if found_player != null:

			return found_player


	return null


# =========================================================
# DETECTION
# =========================================================

func _can_detect_player() -> bool:

	if not is_instance_valid(player):

		return false


	# -----------------------------------------------------
	# DISTANCE CHECK
	# -----------------------------------------------------

	var distance_to_player := \
		global_position.distance_to(
			player.global_position
		)


	if distance_to_player > detection_range:

		return false


	# -----------------------------------------------------
	# WALL / LINE OF SIGHT CHECK
	# -----------------------------------------------------

	return _has_line_of_sight_to_player()


# =========================================================
# LINE OF SIGHT
# =========================================================

func _has_line_of_sight_to_player() -> bool:

	if not is_instance_valid(player):

		return false


	# -----------------------------------------------------
	# GET PHYSICS WORLD
	# -----------------------------------------------------

	var space_state := \
		get_world_2d().direct_space_state


	# -----------------------------------------------------
	# DO NOT LET THE RAY HIT THIS SKULL
	# -----------------------------------------------------

	var exclude_objects: Array[RID] = [
		get_rid()
	]


	# -----------------------------------------------------
	# CREATE RAY
	#
	# SKULL ----------------------------> PLAYER
	#
	# If wall is first:
	#     no vision
	#
	# If Player is first:
	#     Player detected
	# -----------------------------------------------------

	var query := \
		PhysicsRayQueryParameters2D.create(
			global_position,
			player.global_position,
			vision_collision_mask,
			exclude_objects
		)


	query.collide_with_bodies = true

	query.collide_with_areas = false


	# -----------------------------------------------------
	# FIRE RAY
	# -----------------------------------------------------

	var result := \
		space_state.intersect_ray(
			query
		)


	# -----------------------------------------------------
	# NOTHING HIT
	# -----------------------------------------------------

	if result.is_empty():

		return false


	# -----------------------------------------------------
	# GET OBJECT HIT
	# -----------------------------------------------------

	var collider = result.get(
		"collider"
	)


	if collider == null:

		return false


	# -----------------------------------------------------
	# DIRECTLY HIT THE REAL PLAYER
	# -----------------------------------------------------

	if collider == player:

		return true


	# -----------------------------------------------------
	# EXTRA CHECK
	#
	# If collision belongs to something inside
	# player.tscn, count that as Player too.
	# -----------------------------------------------------

	if collider is Node:

		var collider_node := \
			collider as Node


		if player.is_ancestor_of(
			collider_node
		):

			return true


	# -----------------------------------------------------
	# SOMETHING ELSE WAS FIRST
	#
	# Example:
	#
	# Skull ------ WALL ------ Player
	#
	# Ray hits wall first.
	# Therefore player is NOT visible.
	# -----------------------------------------------------

	return false


# =========================================================
# CHASE PLAYER
# =========================================================

func _chase_player(
	delta: float
) -> void:

	if not is_instance_valid(player):

		return


	var distance_to_player := \
		global_position.distance_to(
			player.global_position
		)


	# -----------------------------------------------------
	# ATTACK
	# -----------------------------------------------------

	if (
		distance_to_player <= attack_range
		and
		can_attack
	):

		_start_attack()

		return


	# -----------------------------------------------------
	# CHASE
	# -----------------------------------------------------

	var direction := \
		global_position.direction_to(
			player.global_position
		)


	if direction.length_squared() <= 0.001:

		velocity = Vector2.ZERO

		return


	_update_facing(
		direction
	)


	var target_velocity := \
		direction * chase_speed


	velocity = velocity.move_toward(
		target_velocity,
		acceleration * delta
	)


	move_and_slide()


	_play_idle()


# =========================================================
# STOP MOVEMENT
# =========================================================

func _stop_movement(
	delta: float
) -> void:

	velocity = velocity.move_toward(
		Vector2.ZERO,
		acceleration * delta
	)


	move_and_slide()


# =========================================================
# UPDATE FACING
# =========================================================

func _update_facing(
	direction: Vector2
) -> void:

	if absf(direction.x) < 0.01:

		return


	animated_sprite.flip_h = \
		direction.x < 0.0


# =========================================================
# IDLE
# =========================================================

func _play_idle() -> void:

	if is_dead:
		return


	if is_attacking:
		return


	if is_taking_damage:
		return


	if animated_sprite.animation != &"idle":

		animated_sprite.play(
			&"idle"
		)


# =========================================================
# START ATTACK
# =========================================================

func _start_attack() -> void:

	if is_dead:
		return


	if is_attacking:
		return


	if is_taking_damage:
		return


	if not can_attack:
		return


	if not is_instance_valid(player):
		return


	# -----------------------------------------------------
	# CHECK PLAYER IS STILL VISIBLE
	#
	# Prevent attack through walls.
	# -----------------------------------------------------

	if not _has_line_of_sight_to_player():

		return


	# -----------------------------------------------------
	# START ATTACK
	# -----------------------------------------------------

	is_attacking = true

	can_attack = false


	velocity = Vector2.ZERO


	_deactivate_attack_hitbox()


	# -----------------------------------------------------
	# FACE PLAYER
	# -----------------------------------------------------

	var direction := \
		global_position.direction_to(
			player.global_position
		)


	_update_facing(
		direction
	)


	# -----------------------------------------------------
	# PLAY ATTACK
	# -----------------------------------------------------

	animated_sprite.play(
		&"attack"
	)


	animated_sprite.set_frame_and_progress(
		0,
		0.0
	)


# =========================================================
# ATTACK FRAME CHANGED
# =========================================================

func _on_animation_frame_changed() -> void:

	if is_dead:

		return


	if not is_attacking:

		return


	if animated_sprite.animation != &"attack":

		return


	var current_frame := \
		animated_sprite.frame


	var should_damage := (
		current_frame >= attack_hit_start_frame
		and
		current_frame <= attack_hit_end_frame
	)


	# -----------------------------------------------------
	# DAMAGE ON
	# -----------------------------------------------------

	if should_damage:

		_activate_attack_hitbox()


	# -----------------------------------------------------
	# DAMAGE OFF
	# -----------------------------------------------------

	else:

		_deactivate_attack_hitbox()


# =========================================================
# ACTIVATE ATTACK HITBOX
# =========================================================

func _activate_attack_hitbox() -> void:

	if attack_hitbox_active:

		return


	if not is_instance_valid(player):

		return


	# -----------------------------------------------------
	# DON'T DAMAGE THROUGH WALLS
	# -----------------------------------------------------

	if not _has_line_of_sight_to_player():

		_deactivate_attack_hitbox()

		return


	attack_hitbox_active = true


	do_damage.activate()


	# -----------------------------------------------------
	# DAMAGE PLAYER EVEN IF ALREADY OVERLAPPING
	# -----------------------------------------------------

	do_damage.damage_current_overlaps()


# =========================================================
# DEACTIVATE ATTACK HITBOX
# =========================================================

func _deactivate_attack_hitbox() -> void:

	attack_hitbox_active = false


	do_damage.deactivate()


# =========================================================
# ANIMATION FINISHED
# =========================================================

func _on_animated_sprite_2d_animation_finished() -> void:

	var finished_animation := \
		animated_sprite.animation


	match finished_animation:


		# =================================================
		# ATTACK FINISHED
		# =================================================

		&"attack":

			if is_dead:

				return


			_deactivate_attack_hitbox()


			is_attacking = false


			animated_sprite.play(
				&"idle"
			)


			_start_attack_cooldown()


		# =================================================
		# HIT FINISHED
		# =================================================

		&"hit":

			if is_dead:

				return


			is_taking_damage = false


			velocity = Vector2.ZERO


			animated_sprite.play(
				&"idle"
			)


		# =================================================
		# DEATH FINISHED
		# =================================================

		&"die":

			queue_free()


# =========================================================
# ATTACK COOLDOWN
# =========================================================

func _start_attack_cooldown() -> void:

	await get_tree().create_timer(
		attack_cooldown
	).timeout


	if is_dead:

		return


	can_attack = true


# =========================================================
# TAKE DAMAGE
# =========================================================

func take_damage(
	amount: int,
	source_position: Vector2 = Vector2.ZERO,
	knockback_force: float = 0.0
) -> void:

	if is_dead:

		return


	if not can_take_damage:

		return


	if amount <= 0:

		return


	# -----------------------------------------------------
	# REMOVE HEALTH
	# -----------------------------------------------------

	health -= amount


	print(
		"Skull HP: ",
		health,
		"/",
		max_health
	)


	# -----------------------------------------------------
	# DEAD
	# -----------------------------------------------------

	if health <= 0:

		_die()

		return


	# -----------------------------------------------------
	# HIT
	# -----------------------------------------------------

	var attack_was_interrupted := \
		is_attacking


	can_take_damage = false


	is_taking_damage = true

	is_attacking = false


	velocity = Vector2.ZERO


	_deactivate_attack_hitbox()


	# -----------------------------------------------------
	# ATTACK WAS CANCELLED
	# -----------------------------------------------------

	if attack_was_interrupted:

		can_attack = false

		_start_attack_cooldown()


	# -----------------------------------------------------
	# PLAY HIT
	# -----------------------------------------------------

	animated_sprite.play(
		&"hit"
	)


	animated_sprite.set_frame_and_progress(
		0,
		0.0
	)


	_reset_damage_invulnerability()


# =========================================================
# RESET DAMAGE INVULNERABILITY
# =========================================================

func _reset_damage_invulnerability() -> void:

	await get_tree().create_timer(
		damage_invulnerability_time
	).timeout


	if is_dead:

		return


	can_take_damage = true


# =========================================================
# DIE
# =========================================================

func _die() -> void:

	if is_dead:

		return


	is_dead = true


	is_attacking = false

	is_taking_damage = false


	can_attack = false

	can_take_damage = false


	velocity = Vector2.ZERO


	_deactivate_attack_hitbox()


	# -----------------------------------------------------
	# REMOVE NORMAL COLLISION
	# -----------------------------------------------------

	body_collision.set_deferred(
		"disabled",
		true
	)


	# -----------------------------------------------------
	# PLAYER CANNOT ATTACK DEAD SKULL
	# -----------------------------------------------------

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


	# -----------------------------------------------------
	# DEATH ANIMATION
	# -----------------------------------------------------

	animated_sprite.play(
		&"die"
	)


	animated_sprite.set_frame_and_progress(
		0,
		0.0
	)
