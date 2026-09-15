extends Area2D


@export var speed: float = 140.0
@export var damage: int = 1
@export var lifetime: float = 4.0


var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:

	$AnimatedSprite2D.play("projectile")

	get_tree().create_timer(
		lifetime
	).timeout.connect(
		queue_free
	)


func _physics_process(delta: float) -> void:

	global_position += (
		direction
		* speed
		* delta
	)


func _on_body_entered(body: Node) -> void:

	# ==========================================
	# HIT PLAYER
	# ==========================================

	if body.is_in_group("player"):

		if body.has_method("take_damage"):

			body.take_damage(damage)

		else:

			push_warning(
				"Projectile hit Player, but Player has no take_damage() function."
			)


		queue_free()

		return


	# ==========================================
	# HIT WORLD / WALL
	# ==========================================

	# Anything that is NOT the player can stop
	# the projectile, but only if you actually
	# want walls to destroy projectiles.
	#
	# Keep this section if walls should block shots.

	if body is StaticBody2D:

		queue_free()

		return
