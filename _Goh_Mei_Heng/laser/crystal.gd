extends StaticBody2D

signal crystal_activated(is_active: bool)

@export var targets: Array[Node] = []

@export var toggle_mode: bool = false

@export var deactivate_delay: float = 0.1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var laser_detector: Area2D = $LaserDetector
@onready var deactivate_timer: Timer = $DeactivateTimer

var is_active: bool = false
var lasers_touching: int = 0

func _ready() -> void:
	laser_detector.area_entered.connect(_on_laser_detector_area_entered)
	laser_detector.area_exited.connect(_on_laser_detector_area_exited)
	deactivate_timer.timeout.connect(_on_deactivate_timer_timeout)

	deactivate_timer.one_shot = true
	deactivate_timer.wait_time = deactivate_delay

	_update_visual()

func _on_laser_detector_area_entered(area: Area2D) -> void:
	if not _is_laser(area):
		return

	lasers_touching += 1
	deactivate_timer.stop()

	if toggle_mode:
		# Only toggle when the first laser enters.
		if lasers_touching == 1:
			set_crystal_active(not is_active)
	else:
		set_crystal_active(true)


func _on_laser_detector_area_exited(area: Area2D) -> void:
	if not _is_laser(area):
		return

	lasers_touching = max(lasers_touching - 1, 0)

	if not toggle_mode and lasers_touching == 0:
		deactivate_timer.start()


func _on_deactivate_timer_timeout() -> void:
	if lasers_touching == 0 and not toggle_mode:
		set_crystal_active(false)


func set_crystal_active(value: bool) -> void:
	if is_active == value:
		return

	is_active = value

	_update_visual()
	_update_targets()

	crystal_activated.emit(is_active)

func _update_targets() -> void:
	for target: Node in targets:
		if not is_instance_valid(target):
			continue

		if target.has_method("set_activated"):
			target.set_activated(is_active)

		elif is_active and target.has_method("open"):
			target.open()

		elif not is_active and target.has_method("close"):
			target.close()

		elif is_active and target.has_method("deactivate"):
			target.deactivate()

		elif not is_active and target.has_method("activate"):
			target.activate()

func _update_visual() -> void:
	if is_active:
		if animated_sprite.sprite_frames.has_animation("active"):
			animated_sprite.play("active")
	else:
		if animated_sprite.sprite_frames.has_animation("inactive"):
			animated_sprite.play("inactive")

func _is_laser(area: Area2D) -> bool:
	if area.is_in_group("laser"):
		return true

	var parent: Node = area.get_parent()

	if parent != null and parent.is_in_group("laser"):
		return true

	return false
