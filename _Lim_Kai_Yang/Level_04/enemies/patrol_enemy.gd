extends CharacterBody2D
## 巡逻敌人:沿固定路点来回走 → 玩家靠近才追击 → 近身攻击。
## 和队友的 slime/skull(随机游荡)区分:这个有固定巡逻路线,
## 玩家可以观察规律绕过去 —— 敌人本身成为解谜元素。
##
## 复用仓库现成的伤害系统: do_damage.tscn + take_damage.tscn,
## 所以骑士的攻击能打它, 它的攻击能伤骑士, 零额外代码。
##
## ⚠ Tiny Swords 的 Units 素材只有 Idle / Run / Attack, 没有 Hit / Death 动画帧,
## 所以受击和死亡不靠切动画, 改用颜色闪烁 + 淡出实现, 见下面代码。
##
## 场景树:
## PatrolEnemy (CharacterBody2D) [挂本脚本]
## ├── AnimatedSprite2D          (动画名: idle, move, attack —— 只需要这三个
## │                              来源: Warrior_Idle.png / Warrior_Run.png /
## │                              Warrior_Attack1.png, 每帧 192x192,
## │                              attack 关掉 Loop, idle/move 保持 Loop 开)
## ├── CollisionShape2D          (CircleShape2D 半径 22, 不要用192px整张图那么大,
## │                              素材本身留白多, 判定用小一点更贴近实际身形)
## ├── do_damage                 (实例化 res://scene/do_damage.tscn,
## │                              position.x = 24, 它自带 CollisionShape 就调大小)
## └── take_damage               (实例化 res://scene/take_damage.tscn,
##                                CollisionShape 半径调到约 22, 盖住身体)
##
## 碰撞设置: 本体 Layer = 1, Mask = 1(会被墙挡)
## 巡逻路点: 在关卡场景里放几个 Marker2D, 拖进检查器的 Waypoints 数组

enum State { PATROL, CHASE, ATTACK, HIT, DEAD }

@export var patrol_speed: float = 30.0
@export var chase_speed: float = 55.0
@export var max_health: int = 3
@export var detection_radius: float = 100.0
@export var attack_radius: float = 30.0
@export var attack_cooldown: float = 1.2
@export var damage_area_duration: float = 0.2
@export var hit_stagger_duration: float = 0.15  ## 受击后短暂僵直的时间
@export var death_fade_duration: float = 0.4    ## 死亡淡出时间
## 在关卡里放 Marker2D 作为巡逻点, 按顺序拖进来(至少 2 个)
@export var waypoints: Array[NodePath] = []

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var do_damage: DoDamage = $do_damage
@onready var take_damage_area: TakeDamage = $take_damage
@onready var player: Node2D = get_tree().get_first_node_in_group("player")

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
		push_warning("PatrolEnemy: 巡逻点少于2个, 会原地站桩")
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
		# 甩开一定距离就放弃, 回去巡逻 —— 玩家可以"引开敌人"
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
		print("检测到: ", area.name, " 属于: ", area.owner_entity.name if area.owner_entity else "无主人")
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
	# 没有 hit 动画帧, 用红色闪烁代替: 短暂僵直 + 颜色变化, 结束后回到追击
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
	# 没有 die 动画帧, 用淡出代替: 停在当前帧, 透明度渐变到 0
	var tween := create_tween()
	tween.tween_property(animated_sprite, "modulate:a", 0.0, death_fade_duration)
	await tween.finished
	queue_free()

func _restart_cooldown() -> void:
	await get_tree().create_timer(attack_cooldown).timeout
	if state != State.DEAD:
		can_attack = true
