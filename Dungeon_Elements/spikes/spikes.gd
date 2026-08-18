extends StaticBody2D


@export var active_on_ready: bool = true

@export var damage: int = 1
@export var knockback_force: float = 120.0


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var damage_area: DoDamage = $do_damage


var active: bool = false


func _ready() -> void:
	# Pass spike damage settings into DoDamage.
	damage_area.damage = damage

	# If your DoDamage script has knockback support.
	if "knockback_force" in damage_area:
		damage_area.knockback_force = knockback_force

	set_spikes(active_on_ready)


# ==========================
# SPIKES
# ==========================

func set_spikes(value: bool) -> void:
	active = value

	collision.set_deferred(
		"disabled",
		not active
	)

	if active:
		damage_area.activate()
		sprite.play("up")
	else:
		damage_area.deactivate()
		sprite.play("down")


# ==========================
# LEVER
# ==========================

func _on_lever_toggled(
	lever_active: bool
) -> void:
	# Lever ON = spikes DOWN
	set_spikes(not lever_active)


# ==========================
# CRYSTAL
# ==========================

func set_activated(
	crystal_active: bool
) -> void:
	if crystal_active:
		deactivate()
	else:
		activate()


func activate() -> void:
	set_spikes(true)


func deactivate() -> void:
	set_spikes(false)
