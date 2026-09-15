class_name DemonSlimeBoss
extends CharacterBody2D


signal health_changed(current_health: int, maximum_health: int)
signal died


const PLAYER_SCENE_PATH: String = \
	"res://_Cheok_Kai_Ren/character/player.tscn"


enum State {
	IDLE,
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
# VISION
# =========================================================

@export_category("Vision")

@export var detection_range: float = 300.0

@export_flags_2d_physics var vision_collision_mask: int = \
	0xFFFFFFFF


# =========================================================
# ATTACK
# =========================================================

@export_category("Attack")

@export var attack_damage: int = 1

@export var attack_range: float = 65.0

@export var attack_cancel_distance: float = 90.0

@export var attack_cooldown: float = 1.5

@export var attack_hit_start_frame: int = 9

@export var attack_hit_end_frame: int = 11


# =========================================================
# RADIAL PROJECTILE ATTACK
# =========================================================

const RADIAL_PROJECTILE_COUNT: int = 12

@export_category("Radial Projectile Attack")

# Assign the existing BeholderProjectile scene here.
@export var projectile_scene: PackedScene

# Delay starts when the cleave animation finishes.
@export var volley_delay: float = 1.0

# Distance from the boss center to each projectile spawn point.
@export var projectile_spawn_radius: float = 32.0


# =========================================================
# CLEAVE FIRE TRAIL
# =========================================================

@export_category("Cleave Fire Trail")

# Assign the Ember Runner fire trail scene here.
@export var flame_trail_scene: PackedScene

# Number of flames placed in a straight line.
@export var fire_trail_count: int = 5

# Distance from the boss center where the first flame appears.
@export var fire_trail_start_offset: float = 32.0

# Maximum distance the fire line can search for a wall.
@export var fire_trail_max_distance: float = 240.0

# Keeps the final flame slightly away from the wall.
@export var fire_trail_wall_padding: float = 10.0

# Set this to your wall/world physics layer.
# Default value 2 means physics Layer 2.
@export_flags_2d_physics var fire_trail_wall_mask: int = 2


# =========================================================
# DEATH FIRE TRAIL RING
# =========================================================

@export_category("Death Fire Trail Ring")

# Uses the same Ember Runner fire trail scene.
# Set this to 8 or 10 in the Inspector.
@export var death_fire_trail_count: int = 10

# Distance from the boss death position.
@export var death_fire_trail_radius: float = 52.0

# Optional rotation for the fire ring.
@export var death_fire_trail_angle_offset_degrees: float = 0.0


# =========================================================
# SKULL SUMMON
# =========================================================

@export_category("Skull Summon")

# Assign your existing Skull enemy scene here.
@export var skull_scene: PackedScene

# Boss must keep detecting the Player for this long
# before the first skull wave appears.
@export var skull_summon_detection_delay: float = 5.0

# After the first wave, spawn another wave every this many seconds
# while the boss can still detect the Player.
@export var skull_summon_interval: float = 5.0

# Number of skulls spawned each wave.
@export var skulls_per_summon: int = 2

# Distance from the boss center where skulls appear.
@export var skull_spawn_radius: float = 56.0

# Optional angle adjustment for the spawn circle.
# Leave at 0 unless the skulls spawn in bad positions.
@export var skull_spawn_angle_offset_degrees: float = 0.0


# =========================================================
# SPRITE
# =========================================================

@export_category("Sprite")

@export var sprite_faces_left: bool = true


# =========================================================
# GATE
# =========================================================

@export_category("Gate")

@export var gate_to_open: Node


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

@onready var take_damage_collision: CollisionShape2D = \
	$take_damage/CollisionShape2D


# =========================================================
# VARIABLES
# =========================================================

var current_health: int = 0

var current_state: State = State.IDLE

var target: Node2D = null

var cooldown_remaining: float = 0.0

var attack_damage_applied: bool = false

var last_attack_direction: Vector2 = Vector2.DOWN


# Each queued volley has its own remaining delay.
# This prevents a later attack from cancelling an earlier volley.
var pending_volleys: Array[float] = []

# Counts how long the boss has continuously detected the Player.
var skull_detection_time: float = 0.0

# Counts the repeat interval after the first skull summon.
var skull_repeat_time: float = 0.0

# Prevents the first 5-second summon from firing more than once.
var first_skull_wave_spawned: bool = false


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	current_health = maximum_health

	add_to_group("Enemy")

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

	_find_real_player()

	_enter_idle()

	if projectile_scene == null:
		push_warning(
			"Demon Slime Boss: Assign the Beholder projectile scene."
		)

	if flame_trail_scene == null:
		push_warning(
			"Demon Slime Boss: Assign the Ember Runner fire trail scene."
		)

	if skull_scene == null:
		push_warning(
			"Demon Slime Boss: Assign your Skull enemy scene."
		)

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

	_process_pending_volleys(delta)

	cooldown_remaining = maxf(
		cooldown_remaining - delta,
		0.0
	)

	if not is_instance_valid(target):
		_find_real_player()

	if not is_instance_valid(target):

		_reset_skull_summon_timer()

		if current_state not in [
			State.ATTACK,
			State.HURT
		]:
			_enter_idle()

		return

	_process_skull_summon(delta)

	if current_state == State.ATTACK:
		_process_attack()
		return

	if current_state == State.HURT:
		return

	if not _can_detect_player():
		_enter_idle()
		return

	_process_chase()


# =========================================================
# REAL PLAYER
# =========================================================

func _find_real_player() -> void:
	target = null

	var scene := get_tree().current_scene

	if scene == null:
		return

	target = _search_player(scene)


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
	if not is_instance_valid(target):
		return false

	if global_position.distance_to(
		target.global_position
	) > detection_range:
		return false

	return _has_line_of_sight_to_player()


func _has_line_of_sight_to_player() -> bool:
	if not is_instance_valid(target):
		return false

	var query := \
		PhysicsRayQueryParameters2D.create(
			global_position,
			target.global_position,
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

	if collider == target:
		return true

	if collider is Node:

		if target.is_ancestor_of(
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
# IDLE
# =========================================================

func _enter_idle() -> void:
	if current_state == State.DEAD:
		return

	current_state = State.IDLE

	velocity = Vector2.ZERO

	do_damage.deactivate()

	_play_animation(&"idle")


# =========================================================
# CHASE
# =========================================================

func _process_chase() -> void:
	current_state = State.CHASE

	var direction := global_position.direction_to(
		target.global_position
	)

	var distance := global_position.distance_to(
		target.global_position
	)

	_update_facing(direction)

	if (
		distance <= attack_range
		and
		cooldown_remaining <= 0.0
	):
		_enter_attack()
		return

	if distance <= attack_range:

		velocity = Vector2.ZERO

		_play_animation(&"idle")

		return

	velocity = direction * move_speed

	_play_animation(&"walk")

	move_and_slide()


# =========================================================
# ATTACK
# =========================================================

func _enter_attack() -> void:
	if current_state == State.DEAD:
		return

	if not is_instance_valid(target):
		return

	if not _has_line_of_sight_to_player():
		return

	current_state = State.ATTACK

	velocity = Vector2.ZERO

	do_damage.deactivate()

	attack_damage_applied = false

	var attack_direction: Vector2 = global_position.direction_to(
		target.global_position
	)

	if attack_direction.length_squared() > 0.001:
		last_attack_direction = attack_direction.normalized()

	_update_facing(last_attack_direction)

	if not _play_animation(
		&"cleave",
		true
	):

		cooldown_remaining = attack_cooldown

		_enter_idle()


func _process_attack() -> void:
	# Once the boss has committed to the cleave,
	# do not cancel the animation just because the
	# Player moves away or breaks line of sight.
	#
	# Player detection is still used BEFORE starting
	# the attack inside _enter_attack().
	# The actual melee damage check still happens in
	# _damage_real_player(), so the Player can dodge
	# out of range and avoid the hit.
	velocity = Vector2.ZERO


# =========================================================
# SKULL SUMMON
# =========================================================

func _process_skull_summon(delta: float) -> void:
	if current_state == State.DEAD:
		return

	if skull_scene == null:
		_reset_skull_summon_timer()
		return

	if not is_instance_valid(target):
		_reset_skull_summon_timer()
		return

	# Keep using the boss's normal detection system.
	# If the Player is no longer detected, the 5-second timer resets.
	if not _can_detect_player():
		_reset_skull_summon_timer()
		return

	if not first_skull_wave_spawned:

		skull_detection_time += delta

		if skull_detection_time >= maxf(
			skull_summon_detection_delay,
			0.0
		):
			_spawn_skull_wave()
			first_skull_wave_spawned = true
			skull_repeat_time = 0.0

		return

	# After the first summon, keep summoning every interval
	# while the boss still detects the Player.
	skull_repeat_time += delta

	if skull_repeat_time >= maxf(
		skull_summon_interval,
		0.1
	):
		skull_repeat_time = 0.0
		_spawn_skull_wave()


func _reset_skull_summon_timer() -> void:
	skull_detection_time = 0.0
	skull_repeat_time = 0.0
	first_skull_wave_spawned = false


func _spawn_skull_wave() -> void:
	if current_state == State.DEAD:
		return

	if skull_scene == null:
		return

	var level: Node = get_tree().current_scene

	if level == null:
		level = get_parent()

	if level == null:
		return

	var count: int = maxi(skulls_per_summon, 1)
	var radius: float = maxf(skull_spawn_radius, 0.0)

	# Spawn direction is based on the boss-to-player direction.
	# For 2 skulls, they appear to the left and right side of that line.
	var base_direction: Vector2 = Vector2.RIGHT

	if is_instance_valid(target):
		var direction_to_player: Vector2 = global_position.direction_to(
			target.global_position
		)

		if direction_to_player.length_squared() > 0.001:
			base_direction = direction_to_player.normalized()

	var base_angle: float = (
		base_direction.angle()
		+ deg_to_rad(skull_spawn_angle_offset_degrees)
	)

	for index in range(count):
		var angle: float = base_angle + TAU * (
			float(index) / float(count)
		)

		# With 2 skulls, rotate 90 degrees so they do not spawn
		# directly on top of the Player or directly behind the boss.
		if count == 2:
			angle += PI * 0.5

		var spawn_direction: Vector2 = Vector2.RIGHT.rotated(angle)
		var spawn_position: Vector2 = (
			global_position + spawn_direction * radius
		)

		_spawn_single_skull(spawn_position)


func _spawn_single_skull(spawn_position: Vector2) -> void:
	if skull_scene == null:
		return

	var level: Node = get_tree().current_scene

	if level == null:
		level = get_parent()

	if level == null:
		return

	var instance: Node = skull_scene.instantiate()

	if not instance is Node2D:
		if instance != null:
			instance.queue_free()

		push_error(
			"Demon Slime Boss: Skull scene must have a Node2D root."
		)
		return

	var skull: Node2D = instance as Node2D

	level.add_child(skull)

	skull.global_position = spawn_position


# =========================================================
# DELAYED RADIAL VOLLEY
# =========================================================

func _queue_radial_volley() -> void:
	if current_state == State.DEAD:
		return

	if projectile_scene == null:
		return

	pending_volleys.append(maxf(volley_delay, 0.0))


func _process_pending_volleys(delta: float) -> void:
	# Count down every attack independently. A later melee attack
	# does not reset the delay of a previously scheduled volley.
	for index in range(pending_volleys.size() - 1, -1, -1):
		pending_volleys[index] -= delta

		if pending_volleys[index] <= 0.0:
			pending_volleys.remove_at(index)
			_fire_radial_volley()


func _fire_radial_volley() -> void:
	if current_state == State.DEAD:
		return

	if projectile_scene == null:
		return

	var level: Node = get_tree().current_scene

	if level == null:
		level = get_parent()

	if level == null:
		return

	var angle_step: float = TAU / float(RADIAL_PROJECTILE_COUNT)
	var spawn_radius: float = maxf(projectile_spawn_radius, 0.0)

	for index in range(RADIAL_PROJECTILE_COUNT):
		var instance: Node = projectile_scene.instantiate()

		if not instance is Area2D:
			if instance != null:
				instance.queue_free()

			push_error(
				"Demon Slime Boss: Projectile scene must have an Area2D root."
			)
			return

		var projectile: Area2D = instance as Area2D

		# Twelve evenly spaced directions around the boss.
		var angle: float = float(index) * angle_step
		var direction: Vector2 = Vector2.RIGHT.rotated(angle)

		# The existing Beholder projectile script owns movement,
		# collision, damage, animation, and lifetime.
		projectile.set("direction", direction)

		level.add_child(projectile)

		projectile.global_position = (
			global_position + direction * spawn_radius
		)


# =========================================================
# CLEAVE FIRE TRAIL
# =========================================================

func _spawn_cleave_fire_trail() -> void:
	if current_state == State.DEAD:
		return

	if flame_trail_scene == null:
		return

	var direction: Vector2 = last_attack_direction

	if (
		direction.length_squared() <= 0.001
		and
		is_instance_valid(target)
	):
		direction = global_position.direction_to(
			target.global_position
		)

	if direction.length_squared() <= 0.001:
		return

	direction = direction.normalized()

	var max_distance: float = maxf(
		fire_trail_max_distance,
		fire_trail_start_offset
	)

	var wall_distance: float = _get_fire_trail_wall_distance(
		direction,
		max_distance
	)

	if wall_distance <= 0.0:
		return

	var start_distance: float = minf(
		maxf(fire_trail_start_offset, 0.0),
		wall_distance
	)

	var end_distance: float = maxf(
		start_distance,
		wall_distance - maxf(fire_trail_wall_padding, 0.0)
	)

	var count: int = maxi(fire_trail_count, 1)

	for index in range(count):
		var ratio: float = 0.0

		if count > 1:
			ratio = float(index) / float(count - 1)

		var distance: float = lerpf(
			start_distance,
			end_distance,
			ratio
		)

		_spawn_single_flame_trail(
			global_position + direction * distance
		)


func _get_fire_trail_wall_distance(
	direction: Vector2,
	max_distance: float
) -> float:

	# If no wall mask is assigned, use the maximum distance.
	if fire_trail_wall_mask == 0:
		return max_distance

	var start_position: Vector2 = global_position
	var end_position: Vector2 = (
		global_position + direction * max_distance
	)

	var query := PhysicsRayQueryParameters2D.create(
		start_position,
		end_position,
		fire_trail_wall_mask,
		_get_fire_trail_excludes()
	)

	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hit := get_world_2d().direct_space_state.intersect_ray(
		query
	)

	if hit.is_empty():
		return max_distance

	var wall_position: Vector2 = hit["position"]

	return maxf(
		start_position.distance_to(wall_position),
		0.0
	)


func _get_fire_trail_excludes() -> Array[RID]:
	var result: Array[RID] = _get_vision_excludes()

	# The line should pass through the Player and continue
	# until the wall/world layer blocks it.
	if target is CollisionObject2D:
		result.append(
			(target as CollisionObject2D).get_rid()
		)

	return result


func _spawn_single_flame_trail(
	spawn_position: Vector2
) -> void:

	if flame_trail_scene == null:
		return

	var level: Node = get_tree().current_scene

	if level == null:
		level = get_parent()

	if level == null:
		return

	var instance: Node = flame_trail_scene.instantiate()

	if not instance is Node2D:
		if instance != null:
			instance.queue_free()

		push_error(
			"Demon Slime Boss: Flame trail scene must have a Node2D root."
		)
		return

	var flame: Node2D = instance as Node2D

	level.add_child(flame)

	flame.global_position = spawn_position


# =========================================================
# DEATH FIRE TRAIL RING
# =========================================================

func _spawn_death_fire_ring() -> void:
	if flame_trail_scene == null:
		push_warning(
			"Demon Slime Boss: Assign the Ember Runner fire trail scene."
		)
		return

	var count: int = maxi(death_fire_trail_count, 1)
	var radius: float = maxf(death_fire_trail_radius, 0.0)
	var angle_offset: float = deg_to_rad(
		death_fire_trail_angle_offset_degrees
	)

	for index in range(count):
		var angle: float = angle_offset + TAU * (
			float(index) / float(count)
		)

		var spawn_position: Vector2 = (
			global_position
			+ Vector2.RIGHT.rotated(angle) * radius
		)

		_spawn_single_flame_trail(spawn_position)


# =========================================================
# FACING
# =========================================================

func _update_facing(
	direction: Vector2
) -> void:

	if absf(direction.x) < 0.01:
		return

	if sprite_faces_left:

		animated_sprite.flip_h = \
			direction.x > 0.0

	else:

		animated_sprite.flip_h = \
			direction.x < 0.0


# =========================================================
# ANIMATION
# =========================================================

func _play_animation(
	animation_name: StringName,
	restart: bool = false
) -> bool:

	if not animated_sprite.sprite_frames.has_animation(
		animation_name
	):

		push_warning(
			"Missing Demon Slime animation: %s"
			% animation_name
		)

		return false

	if restart:

		animated_sprite.play(
			animation_name
		)

		animated_sprite.set_frame_and_progress(
			0,
			0.0
		)

		return true

	if animated_sprite.animation != animation_name:

		animated_sprite.play(
			animation_name
		)

	return true


# =========================================================
# ATTACK FRAME
# =========================================================

func _on_animation_frame_changed() -> void:
	if current_state != State.ATTACK:
		return

	if animated_sprite.animation != &"cleave":
		return

	var frame := animated_sprite.frame

	if (
		frame >= attack_hit_start_frame
		and
		frame <= attack_hit_end_frame
	):
		_damage_real_player()


func _damage_real_player() -> void:
	if attack_damage_applied:
		return

	if not is_instance_valid(target):
		return

	if not _has_line_of_sight_to_player():
		return

	if global_position.distance_to(
		target.global_position
	) > attack_range:
		return

	if target.has_method("take_damage"):

		attack_damage_applied = true

		target.call(
			"take_damage",
			attack_damage,
			global_position,
			0.0
		)


# =========================================================
# HURT
# =========================================================

func _enter_hurt() -> void:
	if current_state == State.DEAD:
		return

	current_state = State.HURT

	velocity = Vector2.ZERO

	do_damage.deactivate()

	if not _play_animation(
		&"take_hit",
		true
	):
		_enter_idle()


# =========================================================
# ANIMATION FINISHED
# =========================================================

func _on_animation_finished() -> void:
	match current_state:

		State.ATTACK:

			if animated_sprite.animation != &"cleave":
				return

			# One second after this completed melee attack,
			# fire one round of twelve projectiles.
			_queue_radial_volley()

			# Also create five Ember Runner fire trails
			# in the cleave direction toward the wall.
			_spawn_cleave_fire_trail()

			cooldown_remaining = \
				attack_cooldown

			if _can_detect_player():
				current_state = State.CHASE
			else:
				_enter_idle()


		State.HURT:

			if animated_sprite.animation == &"take_hit":

				if _can_detect_player():
					current_state = State.CHASE
				else:
					_enter_idle()


		State.DEAD:

			if animated_sprite.animation == &"death":

				_finish_death()


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

	if current_health <= 0:

		_enter_dead()

	else:

		_enter_hurt()


# =========================================================
# DEATH
# =========================================================

func _enter_dead() -> void:
	if current_state == State.DEAD:
		return

	current_state = State.DEAD

	velocity = Vector2.ZERO

	# Cancel any delayed volleys and skull summoning when the boss dies.
	pending_volleys.clear()
	_reset_skull_summon_timer()

	do_damage.deactivate()

	# Spawn 8 or 10 Ember Runner fire trails around
	# the exact place where the boss died.
	_spawn_death_fire_ring()

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

	if not _play_animation(
		&"death",
		true
	):
		_finish_death()


func _finish_death() -> void:
	_open_gate()

	died.emit()

	queue_free()


# =========================================================
# OPEN GATE
# =========================================================

func _open_gate() -> void:
	if not is_instance_valid(
		gate_to_open
	):
		return

	if gate_to_open.has_method(
		"open_gate"
	):

		gate_to_open.open_gate()
