extends StaticBody2D


signal crystal_activated(is_active: bool)


# ==========================
# CRYSTAL COLOR
# ==========================

enum CrystalColor {
	RED,
	BLUE,
	GREEN
}


# ==========================
# SETTINGS
# ==========================

@export var crystal_color: CrystalColor = CrystalColor.RED

@export var targets: Array[Node] = []

# false = active while laser is touching the crystal
# true = every new laser hit toggles the crystal
@export var toggle_mode: bool = false

@export var deactivate_delay: float = 0.1


# ==========================
# REFERENCES
# ==========================

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var laser_detector: Area2D = $LaserDetector
@onready var deactivate_timer: Timer = $DeactivateTimer


# ==========================
# STATE
# ==========================

var is_active: bool = false
var lasers_touching: int = 0


# ==========================
# READY
# ==========================

func _ready() -> void:
	laser_detector.area_entered.connect(
		_on_laser_detector_area_entered
	)

	laser_detector.area_exited.connect(
		_on_laser_detector_area_exited
	)

	deactivate_timer.timeout.connect(
		_on_deactivate_timer_timeout
	)

	deactivate_timer.one_shot = true
	deactivate_timer.wait_time = deactivate_delay

	_update_visual()


# ==========================
# LASER ENTER
# ==========================

func _on_laser_detector_area_entered(
	area: Area2D
) -> void:
	if not _is_laser(area):
		return

	if not _is_matching_color(area):
		return

	lasers_touching += 1
	deactivate_timer.stop()

	if toggle_mode:
		if lasers_touching == 1:
			set_crystal_active(
				not is_active
			)
	else:
		set_crystal_active(true)


# ==========================
# LASER EXIT
# ==========================

func _on_laser_detector_area_exited(
	area: Area2D
) -> void:
	if not _is_laser(area):
		return

	if not _is_matching_color(area):
		return

	lasers_touching = max(
		lasers_touching - 1,
		0
	)

	if (
		not toggle_mode
		and lasers_touching == 0
	):
		deactivate_timer.start()


# ==========================
# DEACTIVATE TIMER
# ==========================

func _on_deactivate_timer_timeout() -> void:
	if (
		lasers_touching == 0
		and not toggle_mode
	):
		set_crystal_active(false)


# ==========================
# CRYSTAL STATE
# ==========================

func set_crystal_active(
	value: bool
) -> void:
	if is_active == value:
		return

	is_active = value

	_update_visual()
	_update_targets()

	crystal_activated.emit(
		is_active
	)


# ==========================
# TARGETS
# ==========================

func _update_targets() -> void:
	for target: Node in targets:
		if not is_instance_valid(target):
			continue

		if target.has_method(
			"set_activated"
		):
			target.set_activated(
				is_active
			)

		elif (
			is_active
			and target.has_method("open")
		):
			target.open()

		elif (
			not is_active
			and target.has_method("close")
		):
			target.close()

		elif (
			is_active
			and target.has_method(
				"deactivate"
			)
		):
			target.deactivate()

		elif (
			not is_active
			and target.has_method(
				"activate"
			)
		):
			target.activate()


# ==========================
# VISUAL
# ==========================

func _update_visual() -> void:
	if is_active:
		if animated_sprite.sprite_frames.has_animation(
			"active"
		):
			animated_sprite.play(
				"active"
			)
	else:
		if animated_sprite.sprite_frames.has_animation(
			"inactive"
		):
			animated_sprite.play(
				"inactive"
			)


# ==========================
# CHECK IF AREA IS LASER
# ==========================

func _is_laser(
	area: Area2D
) -> bool:
	if area.is_in_group("laser"):
		return true

	var parent: Node = area.get_parent()

	if (
		parent != null
		and parent.is_in_group("laser")
	):
		return true

	return false


# ==========================
# CHECK LASER COLOR
# ==========================

func _is_matching_color(
	area: Area2D
) -> bool:
	var laser_node: Node = area

	# First check the Area2D itself.
	if laser_node.has_method(
		"get_laser_color"
	):
		return (
			laser_node.get_laser_color()
			== crystal_color
		)

	# If the laser script is attached
	# to the parent instead.
	var parent: Node = area.get_parent()

	if parent == null:
		return false

	if parent.has_method(
		"get_laser_color"
	):
		return (
			parent.get_laser_color()
			== crystal_color
		)

	return false
