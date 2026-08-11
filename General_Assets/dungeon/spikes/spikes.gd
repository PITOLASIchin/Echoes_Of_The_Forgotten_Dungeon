extends StaticBody2D

@export var active_on_ready: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var damage_area: DoDamage = $do_damage

var active: bool = false

func _ready() -> void:
	set_spikes(active_on_ready)

func set_spikes(value: bool) -> void:
	active = value

	collision.set_deferred("disabled", not active)

	if active:
		damage_area.activate()
		sprite.play("up")
	else:
		damage_area.deactivate()
		sprite.play("down")

#toggle spikes with lever
func _on_lever_toggled(lever_active: bool) -> void:
	set_spikes(not lever_active)

#set activated or deactivated for crystal
func set_activated(active: bool) -> void:
	if active:
		deactivate()
	else:
		activate()

func activate() -> void:
	sprite.play("up")
	collision.set_deferred("disabled", false)

	if damage_area.has_method("activate"):
		damage_area.activate()


func deactivate() -> void:
	sprite.play("down")
	collision.set_deferred("disabled", true)

	if damage_area.has_method("deactivate"):
		damage_area.deactivate()
