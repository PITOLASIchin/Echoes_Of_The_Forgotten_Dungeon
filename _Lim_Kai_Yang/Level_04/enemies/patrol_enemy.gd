extends CharacterBody2D

enum State { PATROL, CHASE, ATTACK, HIT, DEAD }

@export var patrol_speed: float = 30.0
@export var chase_speed: float = 55.0
@export var max_health: int = 3
@export var detection_radius: float = 100.0
@export var attack_radius: float = 30.0
@export var attack_cooldown: float = 1.2
@export var damage_area_duration: float = 0.2
@export var hit_stagger_duration: float = 0.15  
@export var death_fade_duration: float = 0.4    
@export var waypoints: Array[NodePath] = []

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var do_damage: DoDamage = $do_damage
@onready var take_damage_area: TakeDamage = $take_damage
@onready var player: Node2D = get_tree().get_first_node_in_group("player")
@onready var attack_sound: AudioStreamPlayer2D = $AttackSound

var state: State = State.PATROL
var health: int
var points: Array[Vector2] = []
var current_point := 0
var can_attack := true

signal died

func _ready() -> void:
	health = max_health
	add_to_group("Enemy")
	do_damage.deactivate()
	for path in waypoints:
		points.append(get_node(path).global_position)
	if points.size() < 2:
		push_warning("PatrolEnemy: If there are fewer than two patrol points, it will stand in place.")
	animated_sprite.play("idle")

func _physics_process(_delta: float) -> void:
	match state:
		State.DEAD, State.HIT, State.ATTACK:
			velocity = Vector2.ZERO
			move_and_slide()
			return
		State.PATROL:
			_do_patrol()
			_check_player_distance()
		State.CHASE:
			_do_chase()
	move_and_slide()

func _player_valid() -> bool:
	return player != null and is_instance_valid(player) and not player.is_dead

func _dist_to_player() -> float:
	return global_position.distance_to(player.global_position)

func _check_player_distance() -> void:
	if _player_valid() and _dist_to_player() <= detection_radius:
		state = State.CHASE

func _do_patrol() -> void:
	if points.size() < 2:
		velocity = Vector2.ZERO
		_play_move_or_idle(Vector2.ZERO)
		return
	var target := points[current_point]
	if global_position.distance_to(target) < 4.0:
		current_point = (current_point + 1) % points.size()
		target = points[current_point]
	var dir := global_position.direction_to(target)
	velocity = dir * patrol_speed
	_play_move_or_idle(dir)

func _do_chase() -> void:
	if not _player_valid():
		state = State.PATROL
		return
	var dist := _dist_to_player()
	if dist > detection_radius * 1.5:
		state = State.PATROL
		return
	if dist <= attack_radius and can_attack:
		_start_attack()
		return
	var dir := global_position.direction_to(player.global_position)
	velocity = dir * chase_speed
	_play_move_or_idle(dir)

func _play_move_or_idle(dir: Vector2) -> void:
	if dir.x != 0:
		animated_sprite.flip_h = dir.x < 0
		do_damage.scale.x = -1.0 if animated_sprite.flip_h else 1.0
	var anim := "move" if velocity.length() > 1.0 else "idle"
	if animated_sprite.animation != anim:
		animated_sprite.play(anim)

func _start_attack() -> void:
	state = State.ATTACK
	can_attack = false
	velocity = Vector2.ZERO
	animated_sprite.play("attack")
	attack_sound.play()
	_do_attack_damage()
	await animated_sprite.animation_finished
	if state != State.DEAD:
		state = State.CHASE
		_restart_cooldown()

func _do_attack_damage() -> void:
	do_damage.activate()
	await get_tree().physics_frame
	if state == State.DEAD:
		do_damage.deactivate()
		return
	for area in do_damage.get_overlapping_areas():
		print("Detect: ", area.name, " The: ", area.owner_entity.name if area.owner_entity else "NOthing")
	do_damage.damage_current_overlaps()
	await get_tree().create_timer(damage_area_duration).timeout
	do_damage.deactivate()

func take_damage(amount: int, _source_position: Vector2 = Vector2.ZERO, _knockback_force: float = 0.0) -> void:
	if state == State.DEAD:
		return
	health -= amount
	if health <= 0:
		_die()
		return
	_flash_hit()

func _flash_hit() -> void:
	state = State.HIT
	do_damage.deactivate()
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(1, 0.4, 0.4), 0.05)
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1), 0.1)
	await get_tree().create_timer(hit_stagger_duration).timeout
	if state != State.DEAD:
		state = State.CHASE

func _die() -> void:
	state = State.DEAD
	died.emit()
	do_damage.deactivate()
	body_collision.set_deferred("disabled", true)
	take_damage_area.get_node("CollisionShape2D").set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate:a", 0.0, death_fade_duration)
	await tween.finished
	queue_free()

func _restart_cooldown() -> void:
	await get_tree().create_timer(attack_cooldown).timeout
	if state != State.DEAD:
		can_attack = true
