extends CharacterBody2D


# =========================================================
# REAL PLAYER IDENTIFICATION
# =========================================================

const PLAYER_SCENE_PATH: String = \
	"res://_Cheok_Kai_Ren/character/player.tscn"


# =========================================================
# MOVEMENT
# =========================================================

@export_category("Movement")

# Choose how this Skull moves in the Inspector.
# Horizontal = left/right only.
# Vertical = up/down only.
@export_enum("Horizontal", "Vertical") var walk_axis: String = "Horizontal"

@export var patrol_speed: float = 25.0

@export var chase_speed: float = 90.0

@export var acceleration: float = 300.0

# How far the Skull patrols from its spawn position.
@export var patrol_distance: float = 80.0


# =========================================================
# VISION
# =========================================================

@export_category("Vision")

# Skull detects the Player inside this range.
# Walls do not block this detection.
@export var detection_range: float = 220.0


# =========================================================
# ATTACK
# =========================================================

@export_category("Attack")

@export var attack_damage: int = 1

@export var attack_range: float = 20.0

@export var attack_cooldown: float = 1.0

# Skull attacks only if the Player is close to its movement lane.
# For Horizontal mode, this checks Y distance.
# For Vertical mode, this checks X distance.
@export var attack_lane_tolerance: float = 18.0

# Skull's attack animation has frames 0 - 5.
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

var spawn_position: Vector2 = Vector2.ZERO

var patrol_direction: float = 1.0


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	health = max_health

	spawn_position = global_position

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

	if is_dead:
		velocity = Vector2.ZERO
		return

	if not is_instance_valid(player):
		_find_real_player()

	if not is_instance_valid(player):
		_patrol(delta)
		_play_idle()
		return

	if is_taking_damage:
		velocity = Vector2.ZERO
		return

	if is_attacking:
		velocity = Vector2.ZERO
		return

	if _can_detect_player():
		_chase_player_on_selected_axis(delta)
	else:
		_patrol(delta)

	_play_idle()


# =========================================================
# FIND REAL PLAYER
# =========================================================

func _find_real_player() -> void:

	player = null

	var current_scene := get_tree().current_scene

	if current_scene == null:
		return

	player = _search_for_player_scene(current_scene)


func _search_for_player_scene(
	node: Node
) -> Node2D:

	if node is Node2D:
		if node.scene_file_path == PLAYER_SCENE_PATH:
			return node as Node2D

	for child in node.get_children():
		var found_player := _search_for_player_scene(child)

		if found_player != null:
			return found_player

	return null


# =========================================================
# DETECTION
# =========================================================

func _can_detect_player() -> bool:

	if not is_instance_valid(player):
		return false

	var distance_to_player := global_position.distance_to(
		player.global_position
	)

	if distance_to_player > detection_range:
		return false

	# Skull can see through walls.
	# No raycast / line-of-sight check is used.
	return true


# =========================================================
# PATROL
# =========================================================

func _patrol(delta: float) -> void:

	var axis_vector: Vector2 = _get_axis_vector()

	var current_axis_position: float = _get_axis_position(
		global_position
	)

	var spawn_axis_position: float = _get_axis_position(
		spawn_position
	)

	var low_limit: float = spawn_axis_position - patrol_distance
	var high_limit: float = spawn_axis_position + patrol_distance

	if current_axis_position >= high_limit:
		patrol_direction = -1.0
	elif current_axis_position <= low_limit:
		patrol_direction = 1.0

	var target_velocity: Vector2 = (
		axis_vector * patrol_direction * patrol_speed
	)

	velocity = velocity.move_toward(
		target_velocity,
		acceleration * delta
	)

	_update_facing(velocity)

	# Move manually so the Skull can pass through walls.
	global_position += velocity * delta


# =========================================================
# CHASE PLAYER
# =========================================================

func _chase_player_on_selected_axis(
	delta: float
) -> void:

	if not is_instance_valid(player):
		return

	if _is_close_enough_to_attack():
		_start_attack()
		return

	var axis_vector: Vector2 = _get_axis_vector()
	var direction_sign: float = _get_direction_sign_to_player()

	if absf(direction_sign) <= 0.01:
		velocity = velocity.move_toward(
			Vector2.ZERO,
			acceleration * delta
		)
	else:
		var target_velocity: Vector2 = (
			axis_vector * direction_sign * chase_speed
		)

		velocity = velocity.move_toward(
			target_velocity,
			acceleration * delta
		)

	_update_facing(velocity)

	# Move manually so the Skull can pass through walls.
	global_position += velocity * delta


# =========================================================
# AXIS HELPERS
# =========================================================

func _get_axis_vector() -> Vector2:

	if walk_axis == "Vertical":
		return Vector2.DOWN

	return Vector2.RIGHT


func _get_axis_position(
	position: Vector2
) -> float:

	if walk_axis == "Vertical":
		return position.y

	return position.x


func _get_perpendicular_position(
	position: Vector2
) -> float:

	if walk_axis == "Vertical":
		return position.x

	return position.y


func _get_direction_sign_to_player() -> float:

	if not is_instance_valid(player):
		return 0.0

	var skull_axis: float = _get_axis_position(global_position)
	var player_axis: float = _get_axis_position(player.global_position)
	var difference: float = player_axis - skull_axis

	if absf(difference) < 1.0:
		return 0.0

	return signf(difference)


func _is_close_enough_to_attack() -> bool:

	if not is_instance_valid(player):
		return false

	var skull_axis: float = _get_axis_position(global_position)
	var player_axis: float = _get_axis_position(player.global_position)

	var skull_perpendicular: float = _get_perpendicular_position(
		global_position
	)

	var player_perpendicular: float = _get_perpendicular_position(
		player.global_position
	)

	var axis_distance: float = absf(player_axis - skull_axis)

	var perpendicular_distance: float = absf(
		player_perpendicular - skull_perpendicular
	)

	return (
		axis_distance <= attack_range
		and perpendicular_distance <= attack_lane_tolerance
		and can_attack
	)


# =========================================================
# UPDATE FACING
# =========================================================

func _update_facing(
	direction: Vector2
) -> void:

	if absf(direction.x) < 0.01:
		return

	animated_sprite.flip_h = direction.x < 0.0


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
		animated_sprite.play(&"idle")


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

	if not _is_close_enough_to_attack():
		return

	is_attacking = true
	can_attack = false
	velocity = Vector2.ZERO

	_deactivate_attack_hitbox()

	var direction := global_position.direction_to(
		player.global_position
	)

	_update_facing(direction)

	animated_sprite.play(&"attack")

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

	var current_frame := animated_sprite.frame

	var should_damage := (
		current_frame >= attack_hit_start_frame
		and current_frame <= attack_hit_end_frame
	)

	if should_damage:
		_activate_attack_hitbox()
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

	attack_hitbox_active = true

	do_damage.activate()

	# Damage Player even if already overlapping.
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

	var finished_animation := animated_sprite.animation

	match finished_animation:

		&"attack":

			if is_dead:
				return

			_deactivate_attack_hitbox()

			is_attacking = false

			animated_sprite.play(&"idle")

			_start_attack_cooldown()


		&"hit":

			if is_dead:
				return

			is_taking_damage = false

			velocity = Vector2.ZERO

			animated_sprite.play(&"idle")


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

	health -= amount

	print(
		"Skull HP: ",
		health,
		"/",
		max_health
	)

	if health <= 0:
		_die()
		return

	var attack_was_interrupted := is_attacking

	can_take_damage = false
	is_taking_damage = true
	is_attacking = false
	velocity = Vector2.ZERO

	_deactivate_attack_hitbox()

	if attack_was_interrupted:
		can_attack = false
		_start_attack_cooldown()

	animated_sprite.play(&"hit")

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

	body_collision.set_deferred(
		"disabled",
		true
	)

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

	animated_sprite.play(&"die")

	animated_sprite.set_frame_and_progress(
		0,
		0.0
	)
