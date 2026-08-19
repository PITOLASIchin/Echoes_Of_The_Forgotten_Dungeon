extends CharacterBody2D


const PLAYER_SCENE_PATH: String = \
	"res://_Cheok_Kai_Ren/character/player.tscn"


# =========================================================
# MOVEMENT
# =========================================================

@export_category("Movement")

@export var chase_speed: float = 30.0

@export var attack_move_speed: float = 65.0

@export var acceleration: float = 100.0


# =========================================================
# VISION
# =========================================================

@export_category("Vision")

@export var detection_range: float = 150.0

@export_flags_2d_physics var vision_collision_mask: int = \
	0xFFFFFFFF


# =========================================================
# ATTACK
# =========================================================

@export_category("Attack")

@export var attack_damage: int = 1

@export var attack_radius: float = 24.0

@export var attack_damage_range: float = 30.0

@export var attack_cooldown: float = 1.2


# =========================================================
# HEALTH
# =========================================================

@export_category("Health")

@export var max_health: int = 3

@export var damage_invulnerability_time: float = 0.3


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


# =========================================================
# VARIABLES
# =========================================================

var player: Node2D = null

var health: int = 0

var attack_direction: Vector2 = Vector2.RIGHT

var is_dead: bool = false

var is_attacking: bool = false

var is_taking_damage: bool = false

var can_take_damage: bool = true

var can_attack: bool = true

var attack_damage_applied: bool = false


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	health = max_health

	add_to_group("Enemy")

	do_damage.deactivate()

	if not animated_sprite.animation_finished.is_connected(
		_on_animated_sprite_2d_animation_finished
	):
		animated_sprite.animation_finished.connect(
			_on_animated_sprite_2d_animation_finished
		)

	_find_real_player()

	animated_sprite.play(&"idle")


# =========================================================
# PHYSICS
# =========================================================

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_instance_valid(player):
		_find_real_player()

	if not is_instance_valid(player):
		_stop(delta)
		return

	if is_taking_damage:
		_stop(delta)
		return

	if is_attacking:
		_process_attack_movement(delta)
		return

	if not _can_detect_player():
		_stop(delta)
		_play_idle()
		return

	var distance := global_position.distance_to(
		player.global_position
	)

	if (
		distance <= attack_radius
		and
		can_attack
	):
		_start_attack()
		return

	_chase_player(delta)


# =========================================================
# FIND PLAYER
# =========================================================

func _find_real_player() -> void:
	player = null

	var scene := get_tree().current_scene

	if scene == null:
		return

	player = _search_player(scene)


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
	if not is_instance_valid(player):
		return false

	if global_position.distance_to(
		player.global_position
	) > detection_range:
		return false

	return _has_line_of_sight_to_player()


func _has_line_of_sight_to_player() -> bool:
	if not is_instance_valid(player):
		return false

	var query := \
		PhysicsRayQueryParameters2D.create(
			global_position,
			player.global_position,
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

	if collider == player:
		return true

	if collider is Node:

		if player.is_ancestor_of(
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
# CHASE
# =========================================================

func _chase_player(delta: float) -> void:
	var direction := \
		global_position.direction_to(
			player.global_position
		)

	if direction.length_squared() <= 0.001:
		velocity = Vector2.ZERO
		return

	_update_sprite_direction(direction)

	velocity = velocity.move_toward(
		direction * chase_speed,
		acceleration * delta
	)

	move_and_slide()

	_play_idle()


# =========================================================
# ATTACK
# =========================================================

func _start_attack() -> void:
	if is_dead:
		return

	if is_attacking:
		return

	if not can_attack:
		return

	if not is_instance_valid(player):
		return

	if not _has_line_of_sight_to_player():
		return

	is_attacking = true

	can_attack = false

	attack_damage_applied = false

	attack_direction = \
		global_position.direction_to(
			player.global_position
		)

	if attack_direction.length_squared() < 0.01:
		attack_direction = Vector2.RIGHT

	_update_sprite_direction(
		attack_direction
	)

	do_damage.deactivate()

	animated_sprite.play(&"attack")

	animated_sprite.set_frame_and_progress(
		0,
		0.0
	)


func _process_attack_movement(
	delta: float
) -> void:

	velocity = velocity.move_toward(
		attack_direction * attack_move_speed,
		acceleration * delta
	)

	move_and_slide()

	if is_on_wall():
		velocity = Vector2.ZERO

	_update_sprite_direction(
		attack_direction
	)


# =========================================================
# PLAYER ONLY DAMAGE
# =========================================================

func _damage_real_player() -> void:
	if attack_damage_applied:
		return

	if not is_instance_valid(player):
		return

	if not _has_line_of_sight_to_player():
		return

	if global_position.distance_to(
		player.global_position
	) > attack_damage_range:
		return

	if player.has_method("take_damage"):

		attack_damage_applied = true

		player.call(
			"take_damage",
			attack_damage,
			global_position,
			0.0
		)


# =========================================================
# COOLDOWN
# =========================================================

func _restart_attack_cooldown() -> void:
	await get_tree().create_timer(
		attack_cooldown
	).timeout

	if not is_dead:
		can_attack = true


# =========================================================
# MOVEMENT
# =========================================================

func _stop(delta: float) -> void:
	velocity = velocity.move_toward(
		Vector2.ZERO,
		acceleration * delta
	)

	move_and_slide()


func _update_sprite_direction(
	direction: Vector2
) -> void:

	if absf(direction.x) < 0.01:
		return

	animated_sprite.flip_h = \
		direction.x < 0.0


func _play_idle() -> void:
	if is_dead:
		return

	if is_attacking:
		return

	if is_taking_damage:
		return

	if animated_sprite.animation != &"idle":

		animated_sprite.play(&"idle")


# =========================================================
# ANIMATION FINISHED
# =========================================================

func _on_animated_sprite_2d_animation_finished() -> void:
	var finished := animated_sprite.animation

	match finished:

		&"attack":

			if is_dead:
				return

			velocity = Vector2.ZERO

			_damage_real_player()

			is_attacking = false

			animated_sprite.play(&"idle")

			_restart_attack_cooldown()


		&"hit":

			if is_dead:
				return

			is_taking_damage = false

			velocity = Vector2.ZERO

			animated_sprite.play(&"idle")


		&"die":

			queue_free()


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

	health -= amount

	print(
		"Slime HP: ",
		health,
		"/",
		max_health
	)

	if health <= 0:
		_die()
		return

	can_take_damage = false

	is_taking_damage = true

	is_attacking = false

	velocity = Vector2.ZERO

	do_damage.deactivate()

	animated_sprite.play(&"hit")

	animated_sprite.set_frame_and_progress(
		0,
		0.0
	)

	_reset_damage_invulnerability()


func _reset_damage_invulnerability() -> void:
	await get_tree().create_timer(
		damage_invulnerability_time
	).timeout

	if not is_dead:
		can_take_damage = true


# =========================================================
# DEATH
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

	do_damage.deactivate()

	body_collision.set_deferred(
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

	animated_sprite.play(&"die")

	animated_sprite.set_frame_and_progress(
		0,
		0.0
	)
